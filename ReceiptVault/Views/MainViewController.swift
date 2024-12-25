import UIKit
import VisionKit
import GoogleSignIn

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
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        let cameraImage = UIImage(systemName: "camera.fill", withConfiguration: config)
        button.setImage(cameraImage, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 40
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var connectionStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()
    
    private lazy var statusIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        return view
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
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
        view.backgroundColor = .systemBackground
        title = "סריקה"
        
        view.addSubview(logoImageView)
        view.addSubview(scanButton)
        view.addSubview(connectionStatusView)
        
        connectionStatusView.addSubview(statusIndicator)
        connectionStatusView.addSubview(statusLabel)
        
        [logoImageView, scanButton, connectionStatusView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        [statusIndicator, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            // Logo constraints
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 100),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            
            // Scan button constraints
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanButton.widthAnchor.constraint(equalToConstant: 80),
            scanButton.heightAnchor.constraint(equalToConstant: 80),
            
            // Connection status view constraints
            connectionStatusView.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 32),
            connectionStatusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            connectionStatusView.heightAnchor.constraint(equalToConstant: 36),
            connectionStatusView.widthAnchor.constraint(equalToConstant: 200),
            
            // Status indicator constraints
            statusIndicator.leadingAnchor.constraint(equalTo: connectionStatusView.leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: connectionStatusView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Status label constraints
            statusLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: connectionStatusView.trailingAnchor, constant: -12),
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
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "אישור", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate
extension MainViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            // Get the first page
            let image = scan.imageOfPage(at: 0)
            
            // Save locally first
            if let pdfData = self.createPDFFromImage(image) {
                let monthName = self.getCurrentMonthName()
                let fileName = "Receipt_\(self.formatDate()).pdf"
                
                if LocalFileManager.shared.saveReceipt(pdfData: pdfData, fileName: fileName, monthName: monthName) {
                    print("Receipt saved locally")
                    
                    // Only try to upload if authenticated
                    if self.isAuthenticated {
                        // Upload to Google Drive
                        self.googleDriveService.uploadReceipt(image: image) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success:
                                    self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה והועלתה ל-Google Drive")
                                case .failure(let error):
                                    self.showAlert(title: "שמירה חלקית", message: "הקבלה נשמרה במכשיר, אך לא הועלתה ל-Google Drive: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else {
                        self.showAlert(title: "הצלחה", message: "הקבלה נשמרה בהצלחה במכשיר")
                    }
                } else {
                    self.showAlert(title: "שגיאה", message: "שגיאה בשמירת הקבלה")
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