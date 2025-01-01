import Foundation
import UIKit

enum GeminiError: Error {
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case apiError(String)
    case parsingError
}

class GeminiService {
    static let shared = GeminiService()
    private let apiKey = "AIzaSyB2l2XCXgM98bhNj0b7i_cOAIUQ4_ySa8Y"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-2.0-flash-exp"
    
    private init() {}
    
    func extractBusinessName(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        print("\n=== Starting Gemini API Request ===")
        print("Model: \(model)")
        print("Base URL: \(baseURL)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG data")
            completion(.failure(GeminiError.networkError("Failed to convert image to data")))
            return
        }
        
        print("✓ Image converted to JPEG - Size: \(imageData.count) bytes")
        let base64Image = imageData.base64EncodedString()
        print("✓ Image converted to base64")
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Extract ONLY the business/store name from this receipt header. Return ONLY the name, no additional text. If no name found, return 'Unknown'."
                        ],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "topP": 0.1,
                "topK": 1
            ]
        ]
        
        let urlString = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
        print("\n🌐 Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Failed to create URL")
            completion(.failure(NSError(domain: "com.receiptvault", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        print("\n📤 Request Headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("\(key): \(value)")
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            if let requestString = String(data: jsonData, encoding: .utf8) {
                print("\n📦 Request Body:")
                print(requestString)
            }
            
            print("\n⏳ Starting network request...")
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                print("\n=== Received API Response ===")
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status Code: \(httpResponse.statusCode)")
                    
                    // Check for rate limiting
                    if httpResponse.statusCode == 429 {
                        completion(.failure(GeminiError.rateLimitExceeded))
                        return
                    }
                    
                    // Check for other error status codes
                    if httpResponse.statusCode != 200 {
                        completion(.failure(GeminiError.apiError("HTTP Status: \(httpResponse.statusCode)")))
                        return
                    }
                    
                    print("\n📥 Response Headers:")
                    httpResponse.allHeaderFields.forEach { key, value in
                        print("\(key): \(value)")
                    }
                }
                
                if let error = error {
                    print("❌ Network Error: \(error.localizedDescription)")
                    let nsError = error as NSError
                    print("Domain: \(nsError.domain)")
                    print("Code: \(nsError.code)")
                    print("User Info: \(nsError.userInfo)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "com.receiptvault", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    }
                    return
                }
                
                print("\n📦 Response Body:")
                if let responseString = String(data: data, encoding: .utf8) {
                    print(responseString)
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("\n🔍 Parsing JSON response:")
                        print("Keys found: \(json.keys.joined(separator: ", "))")
                        
                        if let error = json["error"] as? [String: Any] {
                            let errorMessage = error["message"] as? String ?? "Unknown API error"
                            completion(.failure(GeminiError.apiError(errorMessage)))
                            return
                        }
                        
                        if let candidates = json["candidates"] as? [[String: Any]] {
                            print("✓ Found \(candidates.count) candidates")
                            if let firstCandidate = candidates.first,
                               let content = firstCandidate["content"] as? [String: Any],
                               let parts = content["parts"] as? [[String: Any]],
                               let firstPart = parts.first,
                               let businessName = firstPart["text"] as? String {
                                
                                let trimmedName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
                                print("✅ Successfully extracted business name: \(trimmedName)")
                                DispatchQueue.main.async {
                                    completion(.success(trimmedName))
                                }
                            } else {
                                print("⚠️ Could not extract business name from candidates")
                                DispatchQueue.main.async {
                                    completion(.success("Unknown"))
                                }
                            }
                        } else {
                            print("⚠️ No candidates found in response")
                            DispatchQueue.main.async {
                                completion(.success("Unknown"))
                            }
                        }
                    }
                } catch {
                    print("❌ JSON Parsing Error: \(error)")
                    let jsonError = error as NSError
                    print("Domain: \(jsonError.domain)")
                    print("Code: \(jsonError.code)")
                    print("User Info: \(jsonError.userInfo)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
            task.resume()
            print("✓ Request sent")
            
        } catch {
            print("❌ Request Creation Error: \(error)")
            completion(.failure(error))
        }
    }
    
    func extractReceiptData(from image: UIImage) async throws -> [String: String] {
        print("\n=== Starting Gemini API Request for Full Receipt Data ===")
        print("Model: \(model)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG data")
            throw NSError(domain: "com.receiptvault", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        print("✓ Image converted to JPEG - Size: \(imageData.count) bytes")
        let base64Image = imageData.base64EncodedString()
        
        let prompt = """
        Extract the following information from this receipt. Return a JSON object with these keys in Hebrew:
        - שם העסק (Business Name)
        - תאריך (Date in DD/MM/YYYY format)
        - כתובת (Address)
        - טלפון (Phone Number)
        - ח.פ (Business ID Number)
        - מה נרכש (Brief description of purchases)
        - מחיר סך הכל (Total Price)
        - מע״מ (VAT Amount)
        - אמצעי תשלום (Payment Method)
        - ארבע ספרות אחרונות של כרטיס האשראי (Last 4 digits of credit card if available)
        
        If any field is not found, leave it empty. Format numbers without commas.
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "topP": 0.1,
                "topK": 1
            ]
        ]
        
        let urlString = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "com.receiptvault", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // Longer timeout for full extraction
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let extractedText = firstPart["text"] as? String else {
            throw NSError(domain: "com.receiptvault", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response"])
        }
        
        // Try to parse the JSON response from the model
        if let jsonStart = extractedText.firstIndex(of: "{"),
           let jsonEnd = extractedText.lastIndex(of: "}"),
           let jsonData = String(extractedText[jsonStart...jsonEnd]).data(using: .utf8),
           let extractedData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
            return extractedData
        }
        
        // If JSON parsing fails, return empty values
        return [
            "שם העסק": "",
            "תאריך": "",
            "כתובת": "",
            "טלפון": "",
            "ח.פ": "",
            "מה נרכש": "",
            "מחיר סך הכל": "",
            "מע״מ": "",
            "אמצעי תשלום": "",
            "ארבע ספרות אחרונות של כרטיס האשראי": ""
        ]
    }
} 