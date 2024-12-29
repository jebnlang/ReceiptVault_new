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
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.styleCard(view)
        return view
    }()
    
    private lazy var statusIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        return view
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
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
        setupNotifications()
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
        view.backgroundColor = AppTheme.backgroundColor
        title = "סריקה"
        
        view.addSubview(logoImageView)
        view.addSubview(scanButton)
        view.addSubview(uploadButton)
        view.addSubview(connectionStatusView)
        view.addSubview(scanInstructionLabel)
        
        connectionStatusView.addSubview(statusIndicator)
        connectionStatusView.addSubview(statusLabel)
        
        [scanButton, uploadButton, connectionStatusView, statusIndicator, statusLabel].forEach {
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
            
            // Connection status view constraints
            connectionStatusView.topAnchor.constraint(equalTo: scanInstructionLabel.bottomAnchor, constant: AppTheme.padding * 2),
            connectionStatusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectionStatusView.heightAnchor.constraint(equalToConstant: 44),
            connectionStatusView.widthAnchor.constraint(equalToConstant: 200),
            
            // Status indicator constraints
            statusIndicator.leadingAnchor.constraint(equalTo: connectionStatusView.leadingAnchor, constant: AppTheme.padding),
            statusIndicator.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Status label constraints
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: AppTheme.smallPadding),
            statusLabel.trailingAnchor.constraint(equalTo: connectionStatusView.trailingAnchor, constant: -AppTheme.padding),
            statusLabel.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor)
        ])
        
        updateConnectionStatus()
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
        if isAuthenticated {
            statusIndicator.backgroundColor = .systemGreen
            statusLabel.text = "מחובר ל-Google"
            statusLabel.textColor = .systemGreen
            connectionStatusView.layer.borderColor = UIColor.systemGreen.cgColor
        } else {
            statusIndicator.backgroundColor = .systemGray
            statusLabel.text = "לא מחובר"
            statusLabel.textColor = .systemGray
            connectionStatusView.layer.borderColor = UIColor.systemGray.cgColor
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
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "אישור", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    private func processUploadedFile(at url: URL) {
        // Create a copy of the file in a temporary location
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            
            // Handle based on file type
            if url.pathExtension.lowercased() == "pdf" {
                handlePDFUpload(at: tempURL)
            } else {
                handleImageUpload(at: tempURL)
            }
        } catch {
            showAlert(title: "שגיאה", message: "שגיאה בהעלאת הקובץ: \(error.localizedDescription)")
        }
    }
    
    private func handleImageUpload(at url: URL) {
        guard let image = UIImage(contentsOfFile: url.path) else {
            self.showAlert(title: "שגיאה", message: "לא ניתן לטעון את התמונה")
            return
        }
        
        Task {
            do {
                // Extract receipt data once using AI
                let extractedData = try await GeminiService.shared.extractReceiptData(from: image)
                print("Extracted data: \(extractedData)")
                
                // Get the month from the extracted date or use current date as fallback
                let monthName: String
                if let dateStr = extractedData["תאריך"] {
                    print("Found date string: \(dateStr)")
                    if let date = self.parseReceiptDate(dateStr) {
                        print("Parsed date: \(date)")
                        monthName = self.formatMonthYear(from: date)
                        print("Formatted month name: \(monthName)")
                    } else {
                        print("Failed to parse date string: \(dateStr)")
                        monthName = self.getCurrentMonthName()
                        print("Using current month: \(monthName)")
                    }
                } else {
                    print("No date found in extracted data")
                    monthName = self.getCurrentMonthName()
                    print("Using current month: \(monthName)")
                }
                
                if let pdfData = self.createPDFFromImage(image) {
                    let fileName = "Receipt_\(self.formatDate()).pdf"
                    
                    // Save locally
                    if LocalFileManager.shared.saveReceipt(pdfData: pdfData, fileName: fileName, monthName: monthName) {
                        if self.isAuthenticated {
                            // Upload to Google Drive with extracted data
                            try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: extractedData)
                            DispatchQueue.main.async {
                                self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה והועלתה ל-Google Drive")
                            }
                        } else {
                            self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה במכשיר")
                        }
                    }
                }
            } catch {
                self.showAlert(title: "שגיאה", message: "שגיאה בעיבוד הקבלה: \(error.localizedDescription)")
            }
        }
    }
    
    private func handlePDFUpload(at url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if let image = convertPDFToImage(data: data) {
                print("Successfully converted PDF to image")
                print("Image size: \(image.size)")
                print("Image scale: \(image.scale)")
                print("Image orientation: \(image.imageOrientation.rawValue)")
                
                Task {
                    do {
                        print("Starting AI extraction...")
                        // Extract receipt data once using AI
                        var extractedData = try await GeminiService.shared.extractReceiptData(from: image)
                        print("AI extraction completed")
                        print("Raw extracted data: \(extractedData)")
                        
                        // Check if all fields are empty
                        let allFieldsEmpty = extractedData.values.allSatisfy { $0.isEmpty }
                        if allFieldsEmpty {
                            print("Warning: AI extraction returned all empty fields")
                            
                            // Try to extract date from PDF text
                            if let pdfText = extractTextFromPDF(data: data),
                               let date = findDateInText(pdfText) {
                                print("Found date in PDF text: \(date)")
                                extractedData["תאריך"] = date
                            } else {
                                print("No date found in PDF text")
                                self.showAlert(title: "אזהרה", message: "לא זוהו פרטים בקבלה. האם הקבלה ברורה וקריאה?")
                                return
                            }
                        }
                        
                        // Get the month from the extracted date or use current date as fallback
                        let monthName: String
                        if let dateStr = extractedData["תאריך"] {
                            print("Found date string from PDF: \(dateStr)")
                            if let date = self.parseReceiptDate(dateStr) {
                                print("Parsed date from PDF: \(date)")
                                monthName = self.formatMonthYear(from: date)
                                print("Formatted month name from PDF: \(monthName)")
                            } else {
                                print("Failed to parse date string from PDF: \(dateStr)")
                                monthName = self.getCurrentMonthName()
                                print("Using current month for PDF: \(monthName)")
                            }
                        } else {
                            print("No date found in extracted data from PDF")
                            monthName = self.getCurrentMonthName()
                            print("Using current month for PDF: \(monthName)")
                        }
                        
                        let fileName = "Receipt_\(self.formatDate()).pdf"
                        
                        // Save locally
                        if LocalFileManager.shared.saveReceipt(pdfData: data, fileName: fileName, monthName: monthName) {
                            if self.isAuthenticated {
                                // Upload to Google Drive with extracted data
                                try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: extractedData)
                                DispatchQueue.main.async {
                                    self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה והועלתה ל-Google Drive")
                                }
                            } else {
                                self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה במכשיר")
                            }
                        }
                    } catch {
                        self.showAlert(title: "שגיאה", message: "שגיאה בעיבוד הקבלה: \(error.localizedDescription)")
                    }
                }
            } else {
                self.showAlert(title: "שגיאה", message: "לא ניתן להמיר את הקובץ")
            }
        } catch {
            self.showAlert(title: "שגיאה", message: "שגיאה בשמירת הקבלה: \(error.localizedDescription)")
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
        // Regular expression pattern for DD/MM/YYYY format
        let pattern = "\\b\\d{2}/\\d{2}/\\d{4}\\b"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            return String(text[Range(match.range, in: text)!])
        }
        
        return nil
    }
    
    private func parseReceiptDate(_ dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "he")
        dateFormatter.dateFormat = "dd/MM/yyyy"
        return dateFormatter.date(from: dateStr)
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
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension MainViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            // Get the first page
            let image = scan.imageOfPage(at: 0)
            
            Task {
                do {
                    // Extract receipt data once using AI
                    let extractedData = try await GeminiService.shared.extractReceiptData(from: image)
                    
                    // Get the month from the extracted date or use current date as fallback
                    let monthName: String
                    if let dateStr = extractedData["תאריך"],
                       let date = self.parseReceiptDate(dateStr) {
                        monthName = self.formatMonthYear(from: date)
                    } else {
                        monthName = self.getCurrentMonthName()
                    }
                    
                    // Save locally first
                    if let pdfData = self.createPDFFromImage(image) {
                        let fileName = "Receipt_\(self.formatDate()).pdf"
                        
                        if LocalFileManager.shared.saveReceipt(pdfData: pdfData, fileName: fileName, monthName: monthName) {
                            print("Receipt saved locally")
                            
                            // Only try to upload if authenticated
                            if self.isAuthenticated {
                                // Upload to Google Drive with extracted data
                                try await self.googleDriveService.uploadReceiptWithData(image: image, extractedData: extractedData)
                                DispatchQueue.main.async {
                                    self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה והועלתה ל-Google Drive")
                                }
                            } else {
                                self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה במכשיר")
                            }
                        } else {
                            self.showAlert(title: "שגיאה", message: "שגיאה בשמירת הקבלה")
                        }
                    }
                } catch {
                    self.showAlert(title: "שגיאה", message: "שגיאה בעיבוד הקבלה: \(error.localizedDescription)")
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
        controller.dismiss(animated: true) { [weak self] in
            self?.showAlert(title: "שגיאה", message: "שגיאה בסריקה: \(error.localizedDescription)")
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