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
        // Using comprehensive scopes for testing
        let scopes = [
            "https://www.googleapis.com/auth/drive.file",     // For files created by the app
            "https://www.googleapis.com/auth/drive.metadata", // For updating metadata
            "https://www.googleapis.com/auth/drive.appdata"   // For application data folder
        ]
        
        print("Requesting scopes: \(scopes)")
        
        // First check if we already have a valid session
        if let currentUser = GIDSignIn.sharedInstance.currentUser,
           !currentUser.accessToken.tokenString.isEmpty,
           let expirationDate = currentUser.accessToken.expirationDate,
           expirationDate > Date(),
           Set(currentUser.grantedScopes ?? []).isSuperset(of: scopes) {
            print("Found valid existing session")
            handleAuthenticationSuccess(with: currentUser, completion: completion)
            return
        }
        
        // If no valid session, try to restore previous sign-in
        Task { @MainActor in  // Ensure we're on the main thread
            do {
                let currentUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                // Check if we have all required scopes
                if Set(currentUser.grantedScopes ?? []).isSuperset(of: scopes) {
                    print("Restored previous sign-in with correct scopes")
                    print("Granted scopes: \(currentUser.grantedScopes ?? [])")
                    handleAuthenticationSuccess(with: currentUser, completion: completion)
                    return
                } else {
                    print("Missing required scopes. Need to request additional permissions.")
                    print("Current scopes: \(currentUser.grantedScopes ?? [])")
                    print("Required scopes: \(scopes)")
                }
            } catch {
                print("No previous sign-in to restore or error: \(error.localizedDescription)")
            }
            
            // If we get here, we need a new sign-in
            do {
                let signInResult = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: viewController,
                    hint: nil,
                    additionalScopes: scopes
                )
                print("New sign-in successful")
                handleAuthenticationSuccess(with: signInResult.user, completion: completion)
            } catch {
                print("Authentication error: \(error.localizedDescription)")
                if let error = error as? NSError {
                    print("Error domain: \(error.domain)")
                    print("Error code: \(error.code)")
                    print("Error user info: \(error.userInfo)")
                }
                
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Sign-in was canceled"])))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func handleAuthenticationSuccess(with user: GIDGoogleUser, completion: @escaping (Result<Void, Error>) -> Void) {
        // Check if token needs refresh
        let currentDate = Date()
        if let expirationDate = user.accessToken.expirationDate,
           expirationDate.compare(currentDate) == .orderedAscending {
            Task {
                do {
                    try await user.refreshTokensIfNeeded()
                    print("Successfully refreshed tokens")
                } catch {
                    print("Error refreshing tokens: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
            }
        }
        
        let accessToken = user.accessToken.tokenString
        
        // Create root folder if it doesn't exist
        createRootFolderIfNeeded(accessToken: accessToken) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Upload Methods
    func uploadReceipt(image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            }
            return
        }
        
        Task {
            do {
                // Extract all receipt data using Gemini
                let extractedData = try await GeminiService.shared.extractReceiptData(from: image)
                print("Extracted receipt data: \(extractedData)")
                
                // Convert image to JPEG data
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                
                // Convert JPEG to PDF
                guard let pdfData = createPDFFromImageData(imageData) else {
                    throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF"])
                }
                
                print("PDF creation successful. Size: \(pdfData.count) bytes")
                
                // Get current month folder
                let monthFolderName = getCurrentMonthName()
                
                // Create root folder if needed
                let rootFolderId = try await withCheckedThrowingContinuation { continuation in
                    createRootFolderIfNeeded(accessToken: accessToken) { result in
                        continuation.resume(with: result)
                    }
                }
                
                print("Root folder ID: \(rootFolderId)")
                
                // Create month folder if needed
                let monthFolderId = try await withCheckedThrowingContinuation { continuation in
                    createMonthFolderIfNeeded(accessToken: accessToken, monthName: monthFolderName, parentId: rootFolderId) { result in
                        continuation.resume(with: result)
                    }
                }
                
                print("Month folder ID: \(monthFolderId)")
                
                // Ensure monthly summary sheet exists and get its ID
                let currentDate = Date()
                let calendar = Calendar.current
                let month = calendar.component(.month, from: currentDate)
                let year = calendar.component(.year, from: currentDate)
                
                let sheetId = try await GoogleSheetsService.shared.ensureMonthlySheet(
                    in: monthFolderId,
                    month: month,
                    year: year
                )
                
                print("Sheet ID: \(sheetId)")
                
                // Upload the PDF
                try await withCheckedThrowingContinuation { continuation in
                    uploadPDF(
                        accessToken: accessToken,
                        pdfData: pdfData,
                        businessName: extractedData["שם העסק"] ?? "Unknown",
                        folderId: monthFolderId
                    ) { result in
                        continuation.resume(with: result)
                    }
                }
                
                // Add the extracted data to the sheet
                try await GoogleSheetsService.shared.addReceiptData(
                    to: sheetId,
                    extractedData: extractedData
                )
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("Error in upload process: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
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
    
    private func uploadPDF(accessToken: String, pdfData: Data, businessName: String, folderId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Use 'Receipt' as the prefix if business name is unknown
        let filePrefix = businessName == "Unknown" ? "Receipt" : businessName
        let fileName = "\(filePrefix)_\(formatDate()).pdf"
        
        // Step 1: Create empty file with metadata
        createEmptyFile(name: fileName, folderId: folderId, accessToken: accessToken) { [weak self] result in
            switch result {
            case .success(let fileId):
                print("Empty file created with ID: \(fileId)")
                // Step 2: Upload the actual content
                self?.uploadContent(fileId: fileId, pdfData: pdfData, accessToken: accessToken, completion: completion)
            case .failure(let error):
                print("Failed to create empty file: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func createEmptyFile(name: String, folderId: String, accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "\(driveAPI)/files"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/pdf",
            "parents": [folderId]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            request.httpBody = jsonData
            
            print("Creating empty file with name: \(name)")
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network error creating file: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Create file response status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("No data in create file response")
                    completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "No response data"])))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let fileId = json?["id"] as? String {
                        print("File created successfully")
                        completion(.success(fileId))
                    } else {
                        print("No file ID in response")
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Response: \(responseString)")
                        }
                        completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get file ID"])))
                    }
                } catch {
                    print("Failed to parse create file response: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    completion(.failure(error))
                }
            }
            task.resume()
        } catch {
            print("Failed to create metadata JSON: \(error)")
            completion(.failure(error))
        }
    }
    
    private func uploadContent(fileId: String, pdfData: Data, accessToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Debug: Print current user's scopes
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            print("Current user email: \(currentUser.profile?.email ?? "No email")")
            print("Granted scopes: \(currentUser.grantedScopes ?? [])")
            print("Access token: \(String(describing: currentUser.accessToken))")
            if let expirationDate = currentUser.accessToken.expirationDate {
                print("Has expired: \(expirationDate < Date())")
            } else {
                print("No expiration date available")
            }
        }
        
        // Step 1: Get upload URL
        let urlString = "\(uploadAPI)/files/\(fileId)?uploadType=resumable"  // Using uploadAPI base URL
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/pdf", forHTTPHeaderField: "X-Upload-Content-Type")
        request.setValue("\(pdfData.count)", forHTTPHeaderField: "X-Upload-Content-Length")
        request.timeoutInterval = 30
        
        // Add metadata in the request body
        let metadata: [String: Any] = [
            "mimeType": "application/pdf"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            request.httpBody = jsonData
            
            print("Initiating resumable upload for file ID: \(fileId)")
            print("Using URL: \(urlString)")
            print("Content length: \(pdfData.count)")
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("Failed to initiate resumable upload: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response type")
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
                    }
                    return
                }
                
                print("Resumable upload initiation status: \(httpResponse.statusCode)")
                print("Response headers:")
                httpResponse.allHeaderFields.forEach { key, value in
                    print("\(key): \(value)")
                }
                
                guard let uploadURL = httpResponse.allHeaderFields["Location"] as? String else {
                    print("No upload URL in response")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseString)")
                    }
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "No upload URL provided"])))
                    }
                    return
                }
                
                print("Got upload URL: \(uploadURL)")
                self?.performResumableUpload(uploadURL: uploadURL, pdfData: pdfData, completion: completion)
            }
            task.resume()
        } catch {
            print("Failed to create metadata JSON: \(error)")
            completion(.failure(error))
        }
    }
    
    private func performResumableUpload(uploadURL: String, pdfData: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: uploadURL) else {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue("\(pdfData.count)", forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 30 // Standard 30 second timeout
        
        print("Starting resumable upload of \(pdfData.count) bytes")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 60 // 1 minute total timeout
        configuration.timeoutIntervalForRequest = 30 // 30 seconds per request
        
        let session = URLSession(configuration: configuration)
        
        let task = session.uploadTask(with: request, from: pdfData) { data, response, error in
            if let error = error {
                print("Resumable upload failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Resumable upload response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("Resumable upload successful")
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                    return
                }
            }
            
            if let data = data,
               let responseString = String(data: data, encoding: .utf8) {
                print("Upload response: \(responseString)")
            }
            
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "Failed to upload content"])))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Helper Methods
    private func createRootFolderIfNeeded(accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        // First check if folder exists
        let query = "mimeType='application/vnd.google-apps.folder' and name='\(rootFolderName)' and trashed=false"
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if let existingFolder = files.first,
               let folderId = existingFolder["id"] as? String {
                completion(.success(folderId))
                return
            }
            
            // Folder doesn't exist, create it
            self?.createFolder(name: self?.rootFolderName ?? "ReceiptVault", parentId: nil, accessToken: accessToken, completion: completion)
        }
        task.resume()
    }
    
    private func createMonthFolderIfNeeded(accessToken: String, monthName: String, parentId: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Check if month folder exists
        let query = "mimeType='application/vnd.google-apps.folder' and name='\(monthName)' and '\(parentId)' in parents and trashed=false"
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [[String: Any]] else {
                completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if let existingFolder = files.first,
               let folderId = existingFolder["id"] as? String {
                completion(.success(folderId))
                return
            }
            
            // Folder doesn't exist, create it
            self?.createFolder(name: monthName, parentId: parentId, accessToken: accessToken, completion: completion)
        }
        task.resume()
    }
    
    private func createFolder(name: String, parentId: String?, accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "\(driveAPI)/files"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        
        if let parentId = parentId {
            metadata["parents"] = [parentId]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: metadata)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let folderId = json["id"] as? String else {
                    completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create folder"])))
                    return
                }
                
                completion(.success(folderId))
            }
            task.resume()
        } catch {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Failed to create folder metadata"])))
        }
    }
    
    private func getCurrentMonthName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: Date())
    }
    
    private func formatDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "dd-MM-yyyy"
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - File Operations
    func searchFile(name: String, in folderId: String) async throws -> GTLRDrive_File? {
        let searchQuery = "name='\(name)' and '\(folderId)' in parents and trashed=false"
        let driveService = GTLRDriveService()
        driveService.authorizer = GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer
        
        let query = GTLRDriveQuery_FilesList.query()
        query.q = searchQuery
        query.fields = "files(id, name)"
        
        let result: GTLRDrive_File? = try await withCheckedThrowingContinuation { continuation in
            driveService.executeQuery(query) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let fileList = result as? GTLRDrive_FileList,
                   let files = fileList.files,
                   let file = files.first {
                    continuation.resume(returning: file)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        return result
    }
    
    func moveFile(fileId: String, to folderId: String) async throws {
        let driveService = GTLRDriveService()
        driveService.authorizer = GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer
        
        // Create an empty file object since we're only moving it
        let file = GTLRDrive_File()
        
        let query = GTLRDriveQuery_FilesUpdate.query(withObject: file, fileId: fileId, uploadParameters: nil)
        query.addParents = folderId
        query.removeParents = "root"  // Remove from root if it's there
        query.fields = "id, parents"
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            driveService.executeQuery(query) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    func getRootFolderId(completion: @escaping (Result<String, Error>) -> Void) {
        guard let accessToken = GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString else {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        let query = "name='\(rootFolderName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        let urlString = "\(driveAPI)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&fields=files(id)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let files = json?["files"] as? [[String: Any]], let firstFile = files.first, let id = firstFile["id"] as? String {
                    completion(.success(id))
                } else {
                    completion(.failure(NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Folder not found"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
} 