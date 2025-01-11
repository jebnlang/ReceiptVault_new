import Foundation
import UIKit


class AzureDocumentService {
    static let shared = AzureDocumentService()
    
    private let endpoint = "https://receiptvault.cognitiveservices.azure.com/"
    private let apiKey = "3lj22vhRkh9O2clNcsPHAatAeyf2yIKarWeBc3kaKXaFe74HGkWrJQQJ99BAACYeBjFXJ3w3AAALACOG0nvh"
    
    private init() {}
    
    func extractReceiptData(from image: UIImage) async throws -> [String: String] {
        let maxRetries = 3
        var lastError: Error? = nil
        
        for attempt in 1...maxRetries {
            do {
                print("Attempt \(attempt) to extract data from Azure...")
                return try await performExtraction(from: image)
            } catch {
                lastError = error
                print("Error details: \(error.localizedDescription)")
                if attempt < maxRetries {
                    print("Extraction attempt \(attempt) failed, retrying after delay...")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    continue
                }
            }
        }
        
        throw lastError ?? AzureError.processingError("Failed after \(maxRetries) attempts")
    }
    
    private func performExtraction(from image: UIImage) async throws -> [String: String] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AzureError.processingError("Failed to convert image to JPEG")
        }
        
        let urlString = "\(endpoint)formrecognizer/documentModels/prebuilt-receipt:analyze?api-version=2023-07-31"
        guard let url = URL(string: urlString) else {
            throw AzureError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.timeoutInterval = 30 // 30 second timeout
        
        print("Sending request to URL: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.upload(for: request, from: imageData)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AzureError.invalidResponse
            }
            
            print("Azure API Response Status: \(httpResponse.statusCode)")
            print("Response Headers: \(httpResponse.allHeaderFields)")
            
            switch httpResponse.statusCode {
            case 200...299:
                // 1) Use value(forHTTPHeaderField:) to get operation location case-insensitively
                guard let operationLocation = httpResponse.value(forHTTPHeaderField: "Operation-Location") else {
                    throw AzureError.invalidResponse
                }
                
                print("Operation Location: \(operationLocation)")
                return try await pollForResults(operationLocation: operationLocation)
                
            case 401:
                throw AzureError.authenticationError
            case 404:
                throw AzureError.processingError("Service endpoint not found. URL: \(urlString)")
            case 429:
                throw AzureError.processingError("Rate limit exceeded")
            default:
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString)")
                }
                throw AzureError.processingError("HTTP Status: \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            print("URLError: \(error.localizedDescription)")
            print("Error Code: \(error.code)")
            print("Failed URL: \(error.failureURLString ?? "unknown")")
            
            let errorMessage: String
            switch error.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection"
            case .timedOut:
                errorMessage = "Request timed out"
            case .cannotFindHost:
                errorMessage = "Cannot find Azure service"
            case .cannotConnectToHost:
                errorMessage = "Cannot connect to Azure service"
            default:
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            throw AzureError.processingError(errorMessage)
        } catch {
            print("Unexpected error: \(error)")
            throw error
        }
    }
    
    // 2) Updated polling logic checks the "status" field.
    private func pollForResults(operationLocation: String) async throws -> [String: String] {
        guard let url = URL(string: operationLocation) else {
            throw AzureError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.timeoutInterval = 10 // 10 second timeout for polling requests
        
        var delay = 0.5
        let maxDelay = 4.0
        let timeout = 30.0
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AzureError.invalidResponse
                }
                
                print("Poll Response Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Convert the response to a dictionary
                    guard
                        let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let status = jsonObject["status"] as? String
                    else {
                        throw AzureError.invalidResponse
                    }
                    
                    print("Poll Response: \(jsonObject)")
                    
                    switch status {
                    case "running", "notStarted":
                        // Still processing — keep polling
                        delay = min(delay * 1.5, maxDelay)
                        
                    case "succeeded":
                        // Now it's done: parse the final fields
                        return try parseAzureResponse(data)
                        
                    case "failed":
                        // The analysis failed on Azure's side
                        throw AzureError.processingError("Azure reported that the document analysis failed.")
                        
                    default:
                        // Unexpected status
                        throw AzureError.invalidResponse
                    }
                    
                } else if httpResponse.statusCode == 429 {
                    // Rate limit exceeded
                    delay = min(delay * 2, maxDelay)
                } else {
                    // Some other HTTP error
                    delay = min(delay * 1.5, maxDelay)
                }
                
                // Sleep before next attempt
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch let error as URLError {
                print("Poll URLError: \(error.localizedDescription)")
                delay = min(delay * 2, maxDelay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw AzureError.processingError("Analysis timed out after \(Int(timeout)) seconds")
    }
    
    private func parseAzureResponse(_ data: Data) throws -> [String: String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let analyzeResult = json["analyzeResult"] as? [String: Any],
              let documents = analyzeResult["documents"] as? [[String: Any]],
              let firstDocument = documents.first,
              let fields = firstDocument["fields"] as? [String: Any],
              let content = analyzeResult["content"] as? String else {
            throw AzureError.invalidResponse
        }
        
        var extractedData: [String: String] = [:]
        
        // Extract structured fields
        if let merchantName = fields["MerchantName"] as? [String: Any],
           let value = merchantName["valueString"] as? String {
            extractedData["שם העסק"] = value
        }
        
        if let total = fields["Total"] as? [String: Any],
           let value = total["valueNumber"] as? Double {
            extractedData["מחיר סך הכל"] = String(format: "₪%.2f", value)
        }
        
        if let tax = fields["TotalTax"] as? [String: Any],
           let value = tax["valueNumber"] as? Double {
            extractedData["מע״מ"] = String(format: "₪%.2f", value)
        }
        
        // Extract date with fallback
        if let transactionDate = fields["TransactionDate"] as? [String: Any],
           let value = transactionDate["valueDate"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: value) {
                dateFormatter.dateFormat = "dd/MM/yyyy"
                extractedData["תאריך"] = dateFormatter.string(from: date)
            }
        }
        
        // If no date was extracted, use current date
        if extractedData["תאריך"] == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "he")
            dateFormatter.dateFormat = "dd/MM/yyyy"
            extractedData["תאריך"] = dateFormatter.string(from: Date())
            print("⚠️ No date found in receipt, using current date")
        }
        
        // Extract additional fields from raw content using regex
        let patterns: [(field: String, pattern: String)] = [
            ("כתובת", "כתובת: ([^\n]+)"),
            ("טלפון", "נייד:[ ]*(\\d+)"),
            ("ח.פ", "ע.מ/ח.פ:[ ]*(\\d+)")
        ]
        
        for (field, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)) {
                if let range = Range(match.range(at: 1), in: content) {
                    extractedData[field] = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // Extract payment method and last 4 digits
        if let paymentInfo = content.range(of: "ישראכרט \\d{4}", options: .regularExpression) {
            extractedData["אמצעי תשלום"] = "ישראכרט"
            let cardNumber = String(content[paymentInfo]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            extractedData["ארבע ספרות אחרונות של כרטיס האשראי"] = cardNumber
        }
        
        // Extract purchased items
        if let items = fields["Items"] as? [String: Any],
           let itemsArray = items["valueArray"] as? [[String: Any]] {
            let itemDescriptions = itemsArray.compactMap { item -> String? in
                guard let itemObject = item["valueObject"] as? [String: Any],
                      let description = itemObject["Description"] as? [String: Any],
                      let value = description["valueString"] as? String else {
                    return nil
                }
                return value
            }
            extractedData["מה נרכש"] = itemDescriptions.joined(separator: ", ")
        }
        
        return extractedData
    }
}