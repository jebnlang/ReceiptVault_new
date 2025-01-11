import Foundation
import GoogleSignIn
import UIKit
import PDFKit
import GoogleAPIClientForREST_Drive

class GoogleDriveService {
    // MARK: - Properties
    static let shared = GoogleDriveService()
    private let rootFolderName = "ReceiptVault"
    private let clientID = "634293998454-apeckjpcu9tcgqg2t6td9jne5d18187h.apps.googleusercontent.com"
    private let driveAPI = "https://www.googleapis.com/drive/v3"  // Base URL for regular operations
    private let uploadAPI = "https://www.googleapis.com/upload/drive/v3"  // Base URL for uploads
    
    private init() {
        // Configure GIDSignIn on initialization
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    // MARK: - Authentication
    func authenticate(from viewController: UIViewController, completion: @escaping (Result<Void, Error>) -> Void) {
        let scopes = [
            "https://www.googleapis.com/auth/drive.file",
            "https://www.googleapis.com/auth/drive.metadata",
            "https://www.googleapis.com/auth/drive.appdata"
        ]
        
        print("Requesting scopes: \(scopes)")
        
        // Ensure we're on the main thread for UI operations
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.authenticate(from: viewController, completion: completion)
            }
            return
        }
        
        Task { @MainActor in
            do {
                // First try to restore previous sign-in
                if let currentUser = try? await GIDSignIn.sharedInstance.restorePreviousSignIn() {
                    print("Restored previous sign-in")
                if Set(currentUser.grantedScopes ?? []).isSuperset(of: scopes) {
                        print("✓ Previous session has all required scopes")
                        await self.handleAuthenticationSuccess(with: currentUser, completion: completion)
                    return
                } else {
                        print("Previous session missing required scopes")
                    }
                }
                
                // If restore failed or missing scopes, try new sign in
                print("Attempting new sign in")
                let signInResult = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: viewController,
                    hint: nil,
                    additionalScopes: scopes
                )
                
                print("New sign-in successful")
                print("Granted scopes: \(signInResult.user.grantedScopes ?? [])")
                await self.handleAuthenticationSuccess(with: signInResult.user, completion: completion)
                
            } catch let error as NSError {
                print("Authentication error: \(error.localizedDescription)")
                print("Error domain: \(error.domain)")
                print("Error code: \(error.code)")
                
                if error.code == GIDSignInError.canceled.rawValue {
                    completion(.failure(NSError(
                        domain: "com.receiptvault",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "ההתחברות בוטלה"]
                    )))
                } else if error.code == GIDSignInError.hasNoAuthInKeychain.rawValue {
                    completion(.failure(NSError(
                        domain: "com.receiptvault",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "נדרשת התחברות מחדש"]
                    )))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func handleAuthenticationSuccess(with user: GIDGoogleUser, completion: @escaping (Result<Void, Error>) -> Void) async {
        // Check if token needs refresh
        let currentDate = Date()
        if let expirationDate = user.accessToken.expirationDate,
           expirationDate.compare(currentDate) == .orderedAscending {
                do {
                    try await user.refreshTokensIfNeeded()
                    print("Successfully refreshed tokens")
                } catch {
                    print("Error refreshing tokens: \(error.localizedDescription)")
                await MainActor.run {
                        completion(.failure(error))
                    }
                    return
            }
        }
        
        let accessToken = user.accessToken.tokenString
        
        // Create root folder if it doesn't exist
        do {
            let _ = try await createRootFolderIfNeeded()
            await MainActor.run {
                    completion(.success(()))
            }
        } catch {
            print("Error creating root folder: \(error.localizedDescription)")
            await MainActor.run {
                    completion(.failure(error))
            }
        }
    }
    
    // MARK: - Upload Methods
    func uploadReceipt(image: UIImage) async throws {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Extract all receipt data using AzureDocumentService
        let extractedData = try await AzureDocumentService.shared.extractReceiptData(from: image)
                print("Extracted receipt data: \(extractedData)")
                
        // Use the uploadReceiptWithData method which is already async
        try await uploadReceiptWithData(image: image, extractedData: extractedData)
    }
    
    func uploadReceiptWithData(image: UIImage, extractedData: [String: String]) async throws {
        print("\n=== Starting Google Drive Upload Process ===")
        
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            print("❌ No access token available")
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        print("✓ Access token available")
        
        do {
            // Convert image to JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("❌ Failed to convert image to JPEG")
                throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
            }
            
            print("✓ Image converted to JPEG - Size: \(imageData.count) bytes")
            
            // Convert JPEG to PDF
            guard let pdfData = createPDFFromImageData(imageData) else {
                print("❌ Failed to create PDF from image")
                throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF"])
            }
            
            print("✓ PDF created - Size: \(pdfData.count) bytes")
            
            // Get month and year
            print("\n📅 Processing date information...")
            let (month, year, monthNum, yearNum) = extractDateInfo(from: extractedData)
            
            print("\n📁 Creating folder structure...")
            // Create month folder if needed
            print("Ensuring month folder exists...")
            let monthFolderId = try await ensureMonthFolder(accessToken: accessToken, month: month, year: year)
            print("✓ Month folder ID: \(monthFolderId)")
            
            // Ensure monthly sheet exists and get its ID
            print("\n📊 Setting up Google Sheet...")
            let sheetId: String
            do {
                sheetId = try await GoogleSheetsService.shared.ensureMonthlySheet(
                    in: monthFolderId,
                    month: monthNum,
                    year: yearNum
                )
                print("✓ Sheet ID: \(sheetId)")
            } catch {
                print("❌ Failed to ensure monthly sheet: \(error)")
                throw GoogleDriveError.sheetCreationFailed(error)
            }
            
            // Upload the PDF first
            print("\n📤 Uploading PDF...")
            do {
                try await uploadPDF(
                    accessToken: accessToken,
                    pdfData: pdfData,
                    businessName: extractedData["שם העסק"] ?? "Unknown",
                    folderId: monthFolderId
                )
                print("✓ PDF uploaded successfully")
            } catch {
                print("❌ Failed to upload PDF: \(error)")
                throw GoogleDriveError.uploadFailed
            }
            
            // Add the extracted data to the sheet
            print("\n📝 Updating Google Sheet...")
            do {
                try await GoogleSheetsService.shared.addReceiptData(
                    to: sheetId,
                    extractedData: extractedData
                )
                print("✓ Sheet updated successfully")
            } catch {
                print("❌ Failed to update sheet: \(error)")
                throw GoogleDriveError.sheetUpdateFailed(error)
            }
            
            print("\n=== Google Drive Upload Process Complete ===")
        } catch {
            print("❌ Upload process failed: \(error)")
            throw error
        }
    }
    
    private func parseReceiptDate(_ dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.date(from: dateStr)
    }
    
    private func createPDFFromImageData(_ imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        
        let pageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            image.draw(in: pageRect)
        }
        
        print("Created PDF with size: \(data.count) bytes")
        return data
    }
    
    private func uploadPDF(accessToken: String, pdfData: Data, businessName: String, folderId: String) async throws {
        print("Starting PDF upload process...")
        
        // Step 1: Create metadata for the file
        let metadata: [String: Any] = [
            "name": "\(businessName)_\(Date().timeIntervalSince1970).pdf",
            "mimeType": "application/pdf",
            "parents": [folderId]
        ]
        
        // Step 2: Get upload URL
        let uploadURL = "\(uploadAPI)/files?uploadType=resumable"
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200,
              let location = httpResponse.allHeaderFields["Location"] as? String else {
            throw NSError(domain: "com.receiptvault", code: httpResponse.statusCode, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get upload URL"])
        }
        
        // Step 3: Perform the actual upload
        var uploadRequest = URLRequest(url: URL(string: location)!)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("\(pdfData.count)", forHTTPHeaderField: "Content-Length")
        
        let (_, uploadResponse) = try await URLSession.shared.upload(for: uploadRequest, from: pdfData)
        
        guard let uploadHttpResponse = uploadResponse as? HTTPURLResponse else {
            throw NSError(domain: "com.receiptvault", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid upload response"])
        }
        
        guard uploadHttpResponse.statusCode == 200 || uploadHttpResponse.statusCode == 201 else {
            throw NSError(domain: "com.receiptvault", code: uploadHttpResponse.statusCode, 
                         userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(uploadHttpResponse.statusCode)"])
        }
        
        print("PDF upload completed successfully")
    }
    
    // MARK: - Helper Methods
    private func createRootFolderIfNeeded() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw GoogleDriveError.notAuthenticated
        }
        
        // Check if root folder exists
        if let existingFolderId = UserDefaults.standard.string(forKey: "rootFolderId") {
            // Verify the folder still exists and is accessible
            let (folderExists, _) = try await checkFolderExists(folderId: existingFolderId, accessToken: currentUser.accessToken.tokenString)
            if folderExists {
                return existingFolderId
            }
        }
        
        // Create root folder if it doesn't exist
        let folderId = try await createFolder(name: rootFolderName, parentId: nil, accessToken: currentUser.accessToken.tokenString)
        UserDefaults.standard.set(folderId, forKey: "rootFolderId")
        
        return folderId
    }
    
    private func checkFolderExists(folderId: String, accessToken: String) async throws -> (Bool, String?) {
        let urlString = "\(driveAPI)/files/\(folderId)?fields=id,name,mimeType"
        guard let url = URL(string: urlString) else {
            throw GoogleDriveError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                return (false, nil)
            }
            
            if httpResponse.statusCode == 404 {
                return (false, nil)
            }
            
            guard httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String,
                  let mimeType = json["mimeType"] as? String,
                  mimeType == "application/vnd.google-apps.folder" else {
                return (false, nil)
            }
            
            return (true, id)
        } catch {
            return (false, nil)
        }
    }
    
    private func createFolder(name: String, parentId: String?, accessToken: String) async throws -> String {
        let createURL = URL(string: "\(driveAPI)/files")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        
        if let parentId = parentId {
            metadata["parents"] = [parentId]
        }
        
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        
        guard let createHttpResponse = createResponse as? HTTPURLResponse else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard createHttpResponse.statusCode == 200 else {
            throw NSError(domain: "com.receiptvault", code: createHttpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create folder"])
        }
        
        let createJson = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        guard let folderId = createJson?["id"] as? String else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return folderId
    }
    
    private func createMonthFolderIfNeeded(accessToken: String, monthName: String, parentId: String) async throws -> String {
        // Check if month folder exists
        let query = "mimeType='application/vnd.google-apps.folder' and name='\(monthName)' and '\(parentId)' in parents and trashed=false"
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.receiptvault", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let files = json?["files"] as? [[String: Any]], let firstFile = files.first, let id = firstFile["id"] as? String {
            return id
        }
        
        // Create folder if it doesn't exist
        let createURL = URL(string: "\(driveAPI)/files")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = [
            "name": monthName,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [parentId]
        ]
        
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        
        guard let createHttpResponse = createResponse as? HTTPURLResponse else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        guard createHttpResponse.statusCode == 200 else {
            throw NSError(domain: "com.receiptvault", code: createHttpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create folder"])
        }
        
        let createJson = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        guard let folderId = createJson?["id"] as? String else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return folderId
    }
    
    private func ensureMonthFolder(accessToken: String, month: String, year: String) async throws -> String {
        // First get root folder ID
        let rootFolderId = try await createRootFolderIfNeeded()
        
        // Then check/create month folder
        return try await createMonthFolderIfNeeded(
            accessToken: accessToken,
            monthName: "\(month) \(year)",
            parentId: rootFolderId
        )
    }
    
    private func getCurrentMonthName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: Date())
    }
    
    private func extractDateInfo(from extractedData: [String: String]) -> (month: String, year: String, monthNum: Int, yearNum: Int) {
        if let dateStr = extractedData["תאריך"] {
            print("Found date string: \(dateStr)")
            if let date = parseReceiptDate(dateStr) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
                dateFormatter.dateFormat = "MMMM"
                let month = dateFormatter.string(from: date)
                dateFormatter.dateFormat = "yyyy"
                let year = dateFormatter.string(from: date)
                
                let calendar = Calendar.current
                let monthNum = calendar.component(.month, from: date)
                let yearNum = calendar.component(.year, from: date)
                print("✓ Successfully parsed date - Month: \(month), Year: \(year)")
                return (month, year, monthNum, yearNum)
            }
        }
        
        // Fallback to current date
        print("⚠️ Using current date")
        let currentDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "MMMM"
        let month = dateFormatter.string(from: currentDate)
        dateFormatter.dateFormat = "yyyy"
        let year = dateFormatter.string(from: currentDate)
        
        let calendar = Calendar.current
        let monthNum = calendar.component(.month, from: currentDate)
        let yearNum = calendar.component(.year, from: currentDate)
        
        return (month, year, monthNum, yearNum)
    }
    
    func getRootFolderId() async throws -> String {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let query = "name='\(rootFolderName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&fields=files(id)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get folder ID"])
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]],
              let firstFile = files.first,
              let id = firstFile["id"] as? String else {
            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Folder not found"])
        }
        
        return id
    }
    
    // MARK: - File Operations
    func searchFile(name: String, mimeType: String? = nil, parentId: String? = nil) async throws -> (exists: Bool, id: String?) {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.notAuthenticated
        }
        
        var queryParts = ["name='\(name)'", "trashed=false"]
        if let mimeType = mimeType {
            queryParts.append("mimeType='\(mimeType)'")
        }
        if let parentId = parentId {
            queryParts.append("'\(parentId)' in parents")
        }
        
        let query = queryParts.joined(separator: " and ")
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        
        guard let url = URL(string: urlString) else {
            throw GoogleDriveError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GoogleDriveError.requestFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [[String: Any]] else {
            throw GoogleDriveError.invalidResponse
        }
        
        if let firstFile = files.first, let id = firstFile["id"] as? String {
            return (true, id)
        }
        
        return (false, nil)
    }
    
    func moveFile(fileId: String, toFolder folderId: String) async throws {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.notAuthenticated
        }
        
        // Get current parents
        let getUrl = URL(string: "\(driveAPI)/files/\(fileId)?fields=parents")!
        var getRequest = URLRequest(url: getUrl)
        getRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: getRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let previousParents = json["parents"] as? [String] else {
            throw GoogleDriveError.requestFailed
        }
        
        // Update file with new parent
        let updateUrl = URL(string: "\(driveAPI)/files/\(fileId)?addParents=\(folderId)&removeParents=\(previousParents.joined(separator: ","))")!
        var updateRequest = URLRequest(url: updateUrl)
        updateRequest.httpMethod = "PATCH"
        updateRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, updateResponse) = try await URLSession.shared.data(for: updateRequest)
        
        guard let updateHttpResponse = updateResponse as? HTTPURLResponse,
              updateHttpResponse.statusCode == 200 else {
            throw GoogleDriveError.requestFailed
        }
    }
    
    // MARK: - Error Handling
    enum GoogleDriveError: Error {
        case notAuthenticated
        case invalidURL
        case requestFailed
        case invalidResponse
        case folderNotFound
        case uploadFailed
        case sheetCreationFailed(Error)
        case sheetUpdateFailed(Error)
    }
} 