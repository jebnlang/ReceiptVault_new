import UIKit
import VisionKit
import GoogleSignIn
import UniformTypeIdentifiers

class MainViewController: UIViewController {
    // MARK: - Properties
    private let googleDriveService = GoogleDriveService.shared
    private var isAuthenticated: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    weak var delegate: MainViewControllerDelegate?
    
    // MARK: - UI Elements
    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var scanButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let cameraImage = UIImage(systemName: "camera.fill", withConfiguration: config)
        button.setImage(cameraImage, for: .normal)
        button.backgroundColor = AppTheme.primaryColor
        button.tintColor = .white
        button.layer.cornerRadius = 50
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        
        // Add subtle gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            AppTheme.primaryColor.cgColor,
            AppTheme.secondaryColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 50
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        return button
    }()
    
    private lazy var uploadButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let uploadImage = UIImage(systemName: "square.and.arrow.up", withConfiguration: config)
        button.setImage(uploadImage, for: .normal)
        button.setTitle("העלה קבלה מהמכשיר", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = AppTheme.cardBackgroundColor
        button.tintColor = AppTheme.primaryColor
        button.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.styleCard(button)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var connectionStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = AppTheme.cornerRadius
        return view
    }()
    
    private lazy var statusIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var scanInstructionLabel: UILabel = {
        let label = UILabel()
        label.text = "לחץ על הכפתור לסריקת קבלה חדשה"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Ensure we're on the main thread for UI work
        DispatchQueue.main.async { [weak self] in
            self?.configureInitialState()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradientLayer = scanButton.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = scanButton.bounds
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateConnectionStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            view.backgroundColor = AppTheme.backgroundColor
            title = "הוספת קבלה"
            
            view.addSubview(logoImageView)
            view.addSubview(scanButton)
            view.addSubview(uploadButton)
            view.addSubview(scanInstructionLabel)
            view.addSubview(connectionStatusView)
            
            connectionStatusView.addSubview(statusIndicator)
            connectionStatusView.addSubview(statusLabel)
            
            [scanButton, uploadButton, connectionStatusView].forEach {
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
            
            NSLayoutConstraint.activate([
                // Logo constraints
                logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.padding * 2),
                logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                logoImageView.widthAnchor.constraint(equalToConstant: 120),
                logoImageView.heightAnchor.constraint(equalToConstant: 120),
                
                // Scan button constraints
                scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                scanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                scanButton.widthAnchor.constraint(equalToConstant: 100),
                scanButton.heightAnchor.constraint(equalToConstant: 100),
                
                // Upload button constraints
                uploadButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: AppTheme.padding * 2),
                uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.padding),
                uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.padding),
                uploadButton.heightAnchor.constraint(equalToConstant: 50),
                
                // Scan instruction label
                scanInstructionLabel.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: AppTheme.padding),
                scanInstructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.padding),
                scanInstructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.padding),
                
                // Connection status view - now more subtle and below buttons
                connectionStatusView.topAnchor.constraint(equalTo: scanInstructionLabel.bottomAnchor, constant: AppTheme.padding),
                connectionStatusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                connectionStatusView.heightAnchor.constraint(equalToConstant: 24),
                
                // Status indicator constraints - smaller and centered
                statusIndicator.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor),
                statusIndicator.leadingAnchor.constraint(equalTo: connectionStatusView.leadingAnchor),
                statusIndicator.widthAnchor.constraint(equalToConstant: 6),
                statusIndicator.heightAnchor.constraint(equalToConstant: 6),
                
                // Status label constraints - closer to indicator
                statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 4),
                statusLabel.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor),
                statusLabel.trailingAnchor.constraint(equalTo: connectionStatusView.trailingAnchor)
            ])
            
            updateConnectionStatus()
        }
    }
    
    private func configureInitialState() {
        // Move any initial setup here
    }
    
    // Handle cleanup when view is dismissed
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            delegate?.mainViewControllerDidFinish()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoogleSignInStatusChanged),
            name: .googleSignInStatusChanged,
            object: nil
        )
        
        // Check for existing session
        Task {
            if let currentUser = GIDSignIn.sharedInstance.currentUser,
               !currentUser.accessToken.tokenString.isEmpty,
               let expirationDate = currentUser.accessToken.expirationDate,
               expirationDate > Date() {
                DispatchQueue.main.async {
                    self.updateConnectionStatus()
                }
            }
        }
    }
    
    private func updateConnectionStatus() {
        Task { @MainActor in
            let currentUser = GIDSignIn.sharedInstance.currentUser
            let isTokenValid = currentUser?.accessToken.tokenString.isEmpty == false &&
                             (currentUser?.accessToken.expirationDate ?? Date()) > Date()
            
            if isTokenValid {
                self.statusIndicator.backgroundColor = .systemGreen.withAlphaComponent(0.8)
                self.statusLabel.text = "מחובר ל-Google"
                self.statusLabel.textColor = .secondaryLabel
            } else {
                // Try to restore the session
                do {
                    _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                    // Check again after restore attempt
                    if GIDSignIn.sharedInstance.currentUser != nil {
                        self.statusIndicator.backgroundColor = .systemGreen.withAlphaComponent(0.8)
                        self.statusLabel.text = "מחובר ל-Google"
                        self.statusLabel.textColor = .secondaryLabel
                    } else {
                        self.statusIndicator.backgroundColor = .systemGray.withAlphaComponent(0.8)
                        self.statusLabel.text = "לא מחובר"
                        self.statusLabel.textColor = .secondaryLabel
                    }
                } catch {
                    print("Error restoring session: \(error)")
                    self.statusIndicator.backgroundColor = .systemGray.withAlphaComponent(0.8)
                    self.statusLabel.text = "לא מחובר"
                    self.statusLabel.textColor = .secondaryLabel
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func handleGoogleSignInStatusChanged() {
        updateConnectionStatus()
    }
    
    @objc private func scanButtonTapped() {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(title: "לא נתמך", message: "סריקת מסמכים אינה נתמכת במכשיר זה")
            return
        }
        
        let scanVC = VNDocumentCameraViewController()
        scanVC.delegate = self
        present(scanVC, animated: true)
    }
    
    @objc private func uploadButtonTapped() {
        let supportedTypes: [UTType] = [.pdf, .jpeg, .png, .heic]
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        present(documentPicker, animated: true)
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If there's already a presented view controller, dismiss it first
            if let presentedVC = self.presentedViewController {
                presentedVC.dismiss(animated: true) { [weak self] in
                    guard let self = self else { return }
                    self.presentNewAlert(title: title, message: message)
                }
            } else {
                self.presentNewAlert(title: title, message: message)
            }
        }
    }
    
    private func presentNewAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        self.present(alert, animated: true)
    }
    
    private func processUploadedFile(at url: URL) {
        print("\n=== Processing Uploaded File ===")
        print("File URL: \(url)")
        print("File name: \(url.lastPathComponent)")
        print("File type: \(url.pathExtension)")
        
        // Create a copy of the file in a temporary location
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        print("Temporary location: \(tempURL)")
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                print("Removing existing temp file")
                try FileManager.default.removeItem(at: tempURL)
            }
            
            print("Copying file to temp location")
            try FileManager.default.copyItem(at: url, to: tempURL)
            print("✓ File copied successfully")
            
            // Get file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            print("\nFile Details:")
            print("Size: \(attributes[.size] ?? "Unknown") bytes")
            print("Created: \(attributes[.creationDate] ?? "Unknown")")
            print("Modified: \(attributes[.modificationDate] ?? "Unknown")")
            print("Type: \(attributes[.type] ?? "Unknown")")
            
            // Handle based on file type
            if url.pathExtension.lowercased() == "pdf" {
                print("\nProcessing as PDF")
                handlePDFUpload(at: tempURL)
            } else {
                print("\nProcessing as Image")
                handleImageUpload(at: tempURL)
            }
        } catch {
            print("❌ Error processing file:")
            print("Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("Domain: \(nsError.domain)")
                print("Code: \(nsError.code)")
                print("User Info: \(nsError.userInfo)")
            }
            showAlert(title: "שגיאה", message: "שגיאה בהעלאת הקובץ: \(error.localizedDescription)")
        }
    }
    
    private func handleImageUpload(at url: URL) {
        print("\n=== Handling Image Upload ===")
        print("Loading image from: \(url.path)")
        
        guard let image = UIImage(contentsOfFile: url.path) else {
            print("❌ Failed to load image")
            print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
            print("File readable: \(FileManager.default.isReadableFile(atPath: url.path))")
            self.showAlert(title: "שגיאה", message: "לא ניתן לטעון את התמונה")
            return
        }
        
        print("✓ Image loaded successfully")
        print("Image size: \(image.size)")
        print("Scale: \(image.scale)")
        print("Orientation: \(image.imageOrientation.rawValue)")
        
        // Show loading UI
        let loadingVC = LoadingViewController()
        loadingVC.modalPresentationStyle = .overFullScreen
        loadingVC.modalTransitionStyle = .crossDissolve
        present(loadingVC, animated: true)
        
        Task {
            do {
                // Update to preparing stage
                loadingVC.updateStage(.preparing, withProgress: 0.0)
                
                print("\nStarting AI extraction...")
                loadingVC.updateStage(.analyzingReceipt, withProgress: 0.2)
                let extractedData = try await AzureDocumentService.shared.extractReceiptData(from: image)
                print("✓ AI extraction complete")
                print("Extracted data: \(extractedData)")
                
                let monthName: String
                if let dateStr = extractedData["תאריך"] {
                    print("\nAttempting to parse date: \(dateStr)")
                    if let date = self.parseReceiptDate(dateStr) {
                        monthName = self.formatMonthYear(from: date)
                        print("✓ Using extracted date for month: \(monthName)")
                    } else {
                        monthName = self.getCurrentMonthName()
                        print("⚠️ Could not parse date, using current month: \(monthName)")
                    }
                } else {
                    monthName = self.getCurrentMonthName()
                    print("⚠️ No date found, using current month: \(monthName)")
                }
                
                loadingVC.updateStage(.creatingPDF, withProgress: 0.4)
                print("\nCreating PDF from image...")
                if let pdfData = self.createPDFFromImage(image) {
                    let fileName = "Receipt_\(self.formatDate()).pdf"
                    print("✓ PDF created: \(fileName)")
                    
                    print("\nSaving to local storage...")
                    if LocalFileManager.shared.saveReceipt(pdfData: pdfData, fileName: fileName, monthName: monthName) {
                        print("✓ Saved to local storage")
                        
                        if self.isAuthenticated {
                            loadingVC.updateStage(.uploadingToDrive, withProgress: 0.6)
                            print("\nUploading to Google Drive...")
                            try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: extractedData)
                            print("✓ Uploaded to Google Drive")
                            
                            loadingVC.updateStage(.updatingSheet, withProgress: 0.8)
                            // Wait for sheet update
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                            
                            loadingVC.updateStage(.complete, withProgress: 1.0)
                        } else {
                            print("⚠️ Not authenticated, skipping Google Drive upload")
                            loadingVC.updateStage(.complete, withProgress: 1.0)
                        }
                    } else {
                        print("❌ Failed to save locally")
                        self.showAlert(title: "שגיאה", message: "שגיאה בשמירת הקבלה")
                    }
                } else {
                    print("❌ Failed to create PDF")
                    self.showAlert(title: "שגיאה", message: "שגיאה ביצירת קובץ PDF")
                }
            } catch {
                print("\n❌ Error in upload process:")
                print("Error type: \(type(of: error))")
                print("Error description: \(error.localizedDescription)")
                if let azureError = error as? AzureError {
                    print("Azure error type: \(azureError)")
                }
                loadingVC.dismiss(animated: true) {
                    self.handleAzureError(error)
                }
            }
        }
    }
    
    private func handlePDFUpload(at url: URL) {
        // Create a processing queue to handle long-running operations
        let processingQueue = DispatchQueue(label: "com.receiptvault.pdfprocessing")
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try Data(contentsOf: url)
                guard let image = self.convertPDFToImage(data: data) else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showAlert(title: "שגיאה", message: "לא ניתן להמיר את הקובץ")
                    }
                    return
                }
                
                print("Successfully converted PDF to image")
                print("Image size: \(image.size)")
                print("Image scale: \(image.scale)")
                
                // Handle the Azure Document Intelligence request with retry logic
                Task {
                    do {
                        var retryCount = 0
                        var extractedData: [String: String]? = nil
                        
                        while retryCount < 3 && extractedData == nil {
                            do {
                                extractedData = try await AzureDocumentService.shared.extractReceiptData(from: image)
                                print("AI extraction completed")
                            } catch {
                                retryCount += 1
                                if retryCount < 3 {
                                    // Wait before retrying with exponential backoff
                                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                                    continue
                                }
                                throw error
                            }
                        }
                        
                        guard let finalExtractedData = extractedData else {
                            throw NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract data after retries"])
                        }
                        
                        // Process the extracted data
                        let monthName = await self.determineMonthName(from: finalExtractedData, pdfData: data)
                        let fileName = "Receipt_\(self.formatDate()).pdf"
                        
                        // Save locally first
                        if LocalFileManager.shared.saveReceipt(pdfData: data, fileName: fileName, monthName: monthName) {
                            if self.isAuthenticated {
                                // Upload to Google Drive
                                try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: finalExtractedData)
                                await self.showSuccessAlert(isUploaded: true)
                            } else {
                                await self.showSuccessAlert(isUploaded: false)
                            }
                        }
                    } catch {
                        print("Error in PDF processing: \(error)")
                        await self.handleProcessingError(error)
                    }
                }
            } catch {
                print("Error reading PDF file: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showAlert(title: "שגיאה", message: "שגיאה בקריאת הקבלה: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func determineMonthName(from extractedData: [String: String], pdfData: Data) async -> String {
        if let dateStr = extractedData["תאריך"],
           let date = self.parseReceiptDate(dateStr) {
            return self.formatMonthYear(from: date)
        }
        
        // Try to extract date from PDF text as fallback
        if let pdfText = extractTextFromPDF(data: pdfData),
           let date = findDateInText(pdfText),
           let parsedDate = self.parseReceiptDate(date) {
            return self.formatMonthYear(from: parsedDate)
        }
        
        return self.getCurrentMonthName()
    }
    
    private func showSuccessAlert(isUploaded: Bool) async {
        await MainActor.run {
            let message = isUploaded ? 
                "הקבלה נשמרה בהצלחה והועלתה ל-Google Drive" :
                "הקבלה נשמרה בהצלחה במכשיר"
            self.showAlert(title: "הצלחה", message: message)
        }
    }
    
    private func handleProcessingError(_ error: Error) async {
        await MainActor.run {
            if let azureError = error as? AzureError {
                self.handleAzureError(azureError)
            } else {
                self.showAlert(title: "שגיאה", 
                             message: "שגיאה בעיבוד הקבלה: \(error.localizedDescription)")
            }
        }
    }
    
    private func extractTextFromPDF(data: Data) -> String? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let page = pdfDoc.page(at: 1) else {
            return nil
        }
        
        let pageRect = page.getBoxRect(.mediaBox)
        
        // Create PDF context
        let pdfContext = CGContext(data: nil,
                                 width: Int(pageRect.width),
                                 height: Int(pageRect.height),
                                 bitsPerComponent: 8,
                                 bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        pdfContext?.drawPDFPage(page)
        
        return extractTextFromPDFPage(page)
    }
    
    private func extractTextFromPDFPage(_ page: CGPDFPage) -> String {
        let pageDict = page.dictionary
        var text = ""
        
        var contentObject: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(pageDict!, "Contents", &contentObject) {
            var stream: CGPDFStreamRef?
            if CGPDFObjectGetValue(contentObject!, .stream, &stream) {
                var format: CGPDFDataFormat = .raw
                if let data = CGPDFStreamCopyData(stream!, &format),
                   let streamText = String(data: data as Data, encoding: .utf8) {
                    text = streamText
                }
            }
        }
        
        return text
    }
    
    private func findDateInText(_ text: String) -> String? {
        // Enhanced patterns for different date formats
        let patterns = [
            "\\b\\d{1,2}/\\d{1,2}/\\d{4}\\b",     // DD/MM/YYYY or D/M/YYYY
            "\\b\\d{1,2}\\.\\d{1,2}\\.\\d{4}\\b",  // DD.MM.YYYY or D.M.YYYY
            "\\b\\d{1,2}-\\d{1,2}-\\d{4}\\b"      // DD-MM-YYYY or D-M-YYYY
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        
        return nil
    }
    
    private func parseReceiptDate(_ dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        
        // Try different date formats
        let dateFormats = [
            "dd/MM/yyyy",
            "d/M/yyyy",
            "dd.MM.yyyy",
            "d.M.yyyy",
            "dd-MM-yyyy",
            "d-M-yyyy"
        ]
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateStr) {
                return date
            }
        }
        
        // Try to clean the string and parse again
        let cleanedStr = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: cleanedStr) {
                return date
            }
        }
        
        print("⚠️ Failed to parse date: \(dateStr) with any format")
        return nil
    }
    
    private func formatMonthYear(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: date)
    }
    
    private func convertPDFToImage(data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let pdfPage = pdfDoc.page(at: 1) else {
            return nil
        }
        
        let pageRect = pdfPage.getBoxRect(.mediaBox)
        
        // Increase resolution for better text recognition
        let scale: CGFloat = 2.0  // Doubled resolution
        let scaledSize = CGSize(width: pageRect.size.width * scale, 
                              height: pageRect.size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        
        let image = renderer.image { ctx in
            // Set white background
            UIColor.white.set()
            ctx.fill(pageRect.applying(CGAffineTransform(scaleX: scale, y: scale)))
            
            // Configure rendering for better quality
            let context = ctx.cgContext
            context.setRenderingIntent(.defaultIntent)
            context.interpolationQuality = .high
            context.setShouldAntialias(true)
            context.setShouldSmoothFonts(true)
            
            context.translateBy(x: 0.0, y: scaledSize.height)
            context.scaleBy(x: scale, y: -scale)
            
            // Use better quality PDF rendering
            context.setAllowsAntialiasing(true)
            context.setShouldSubpixelQuantizeFonts(true)
            
            context.drawPDFPage(pdfPage)
        }
        
        print("Generated image size: \(image.size)")
        print("Generated image scale: \(image.scale)")
        
        return image
    }
    
    private func handleAzureError(_ error: Error) {
        let errorMessage: String
        
        if let azureError = error as? AzureError {
            switch azureError {
            case .invalidConfiguration:
                errorMessage = "שגיאת תצורה. אנא נסה שוב."
            case .networkError(let message):
                errorMessage = "שגיאת רשת: \(message)"
            case .invalidResponse:
                errorMessage = "התקבלה תשובה לא תקינה מהשרת"
            case .authenticationError:
                errorMessage = "שגיאת אימות. אנא נסה שוב."
            case .processingError(let message):
                errorMessage = "שגיאה בעיבוד: \(message)"
            case .noDataExtracted:
                errorMessage = "לא זוהו נתונים בקבלה. האם הקבלה ברורה וקריאה?"
            }
        } else if let urlError = error as? URLError {
            errorMessage = "שגיאת רשת: \(urlError.localizedDescription)"
        } else {
            errorMessage = "שגיאה לא צפויה: \(error.localizedDescription)"
        }
        
        showAlert(title: "שגיאה", message: errorMessage)
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension MainViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        print("\n=== Starting Document Camera Processing ===")
        print("Number of pages scanned: \(scan.pageCount)")
        
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else {
                print("❌ Self was deallocated during camera dismissal")
                return
            }
            
            print("📸 Camera UI dismissed successfully")
            
            // Show loading UI
            let loadingVC = LoadingViewController()
            loadingVC.modalPresentationStyle = .overFullScreen
            loadingVC.modalTransitionStyle = .crossDissolve
            self.present(loadingVC, animated: true)
            
            // Handle multiple pages
            let pageCount = scan.pageCount
            var allImages: [UIImage] = []
            
            loadingVC.updateStage(.preparing, withProgress: 0.0)
            print("📄 Processing \(pageCount) scanned pages...")
            
            // Collect all scanned pages
            for pageIndex in 0..<pageCount {
                print("  - Processing page \(pageIndex + 1)")
                let image = scan.imageOfPage(at: pageIndex)
                print("    ✓ Image size: \(image.size)")
                print("    ✓ Scale: \(image.scale)")
                print("    ✓ Orientation: \(image.imageOrientation.rawValue)")
                allImages.append(image)
            }
            
            Task {
                do {
                    print("\n=== Starting Batch Processing ===")
                    // Process each image
                    for (index, image) in allImages.enumerated() {
                        let progress = Float(index) / Float(allImages.count)
                        print("\n📝 Processing Receipt \(index + 1) of \(allImages.count)")
                        
                        loadingVC.updateStage(.analyzingReceipt, withProgress: 0.2 + progress * 0.2)
                        print("🔍 Starting Azure AI analysis...")
                        let extractedData = try await AzureDocumentService.shared.extractReceiptData(from: image)
                        print("✓ AI Analysis complete")
                        print("📋 Extracted data: \(extractedData)")
                        
                        // Get the month from the extracted date or use current date as fallback
                        let monthName: String
                        if let dateStr = extractedData["תאריך"] {
                            print("📅 Found date in receipt: \(dateStr)")
                            if let date = self.parseReceiptDate(dateStr) {
                                monthName = self.formatMonthYear(from: date)
                                print("✓ Using extracted date: \(monthName)")
                            } else {
                                monthName = self.getCurrentMonthName()
                                print("⚠️ Could not parse date, using current month: \(monthName)")
                            }
                        } else {
                            monthName = self.getCurrentMonthName()
                            print("⚠️ No date found, using current month: \(monthName)")
                        }
                        
                        loadingVC.updateStage(.creatingPDF, withProgress: 0.4 + progress * 0.2)
                        print("\n💾 Creating PDF...")
                        if let pdfData = self.createPDFFromImage(image) {
                            let fileName = "Receipt_\(self.formatDate())_\(index + 1).pdf"
                            print("✓ PDF created: \(fileName) - Size: \(pdfData.count) bytes")
                            
                            print("📁 Saving to local storage...")
                            if LocalFileManager.shared.saveReceipt(pdfData: pdfData, fileName: fileName, monthName: monthName) {
                                print("✓ Saved locally")
                                
                                if self.isAuthenticated {
                                    loadingVC.updateStage(.uploadingToDrive, withProgress: 0.6 + progress * 0.2)
                                    print("\n☁️ Starting Google Drive upload...")
                                    print("Token status: \(String(describing: GIDSignIn.sharedInstance.currentUser?.accessToken))")
                                    try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: extractedData)
                                    print("✓ Uploaded to Google Drive")
                                    
                                    loadingVC.updateStage(.updatingSheet, withProgress: 0.8 + progress * 0.2)
                                    // Wait for sheet update
                                    try await Task.sleep(nanoseconds: 1_000_000_000)
                                } else {
                                    print("ℹ️ Skipping Google Drive upload - Not authenticated")
                                }
                            } else {
                                print("❌ Failed to save locally")
                                loadingVC.dismiss(animated: true) {
                                    self.showAlert(title: "שגיאה", message: "שגיאה בשמירת הקבלה \(index + 1)")
                                }
                                return
                            }
                        } else {
                            print("❌ Failed to create PDF")
                            loadingVC.dismiss(animated: true) {
                                self.showAlert(title: "שגיאה", message: "שגיאה ביצירת קובץ PDF")
                            }
                            return
                        }
                    }
                    
                    print("\n=== Batch Processing Complete ===")
                    loadingVC.updateStage(.complete, withProgress: 1.0)
                } catch {
                    print("\n❌ Error in batch processing:")
                    print("Error type: \(type(of: error))")
                    print("Error description: \(error.localizedDescription)")
                    
                    loadingVC.dismiss(animated: true) {
                        // Enhanced error handling with type safety
                        switch error {
                        case let azureError as AzureError:
                            print("Azure error details: \(azureError)")
                            self.handleAzureError(azureError)
                        case let urlError as URLError:
                            print("Network error: \(urlError.localizedDescription)")
                            self.showAlert(title: "שגיאה", message: "שגיאת רשת: \(urlError.localizedDescription)")
                        default:
                            // Handle NSError properties if available
                            let nsError = error as NSError
                            print("Domain: \(nsError.domain)")
                            print("Code: \(nsError.code)")
                            print("User Info: \(nsError.userInfo)")
                            
                            // Generic error handling
                            let errorMessage = nsError.localizedDescription
                            self.showAlert(title: "שגיאה", message: "שגיאה לא צפויה: \(errorMessage)")
                        }
                    }
                }
            }
        }
    }
    
    private func createPDFFromImage(_ image: UIImage) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            context.beginPage()
            image.draw(in: pageRect)
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
        dateFormatter.dateFormat = "dd-MM-yyyy_HH-mm-ss"
        return dateFormatter.string(from: Date())
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print("Camera error: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            controller.dismiss(animated: true) {
                self.showAlert(title: "שגיאה", message: "שגיאה בסריקה: \(error.localizedDescription)")
            }
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension MainViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Security check: make sure we can access the file
        guard url.startAccessingSecurityScopedResource() else {
            showAlert(title: "שגיאה", message: "אין גישה לקובץ")
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Verify file exists and is readable
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            showAlert(title: "שגיאה", message: "לא ניתן לקרוא את הקובץ")
            return
        }
        
        // Verify file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let maxSize: Int64 = 10 * 1024 * 1024 // 10MB
            
            guard fileSize <= maxSize else {
                showAlert(title: "שגיאה", message: "הקובץ גדול מדי. הגודל המקסימלי הוא 10MB")
                return
            }
            
            processUploadedFile(at: url)
        } catch {
            showAlert(title: "שגיאה", message: "שגיאה בקריאת הקובץ: \(error.localizedDescription)")
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
} 