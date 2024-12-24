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
    private lazy var scanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("סרוק קבלה", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateButtonStates()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "קופת קבלות"
        
        view.addSubview(scanButton)
        view.addSubview(signInButton)
        
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            scanButton.heightAnchor.constraint(equalToConstant: 50),
            
            signInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signInButton.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 20),
            signInButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            signInButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        scanButton.isEnabled = isAuthenticated
        scanButton.alpha = isAuthenticated ? 1.0 : 0.5
        
        if isAuthenticated {
            signInButton.setTitle("מחובר ל-Google", for: .normal)
            signInButton.backgroundColor = .systemGreen.withAlphaComponent(0.1)
            signInButton.setTitleColor(.systemGreen, for: .normal)
            signInButton.layer.borderColor = UIColor.systemGreen.cgColor
        } else {
            signInButton.setTitle("התחבר עם Google", for: .normal)
            signInButton.backgroundColor = .white
            signInButton.setTitleColor(.systemBlue, for: .normal)
            signInButton.layer.borderColor = UIColor.systemBlue.cgColor
        }
    }
    
    // MARK: - Actions
    @objc private func signInButtonTapped() {
        if isAuthenticated {
            // Show sign out confirmation
            let alert = UIAlertController(title: "התנתקות", message: "האם אתה בטוח שברצונך להתנתק?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
            alert.addAction(UIAlertAction(title: "התנתק", style: .destructive) { [weak self] _ in
                GIDSignIn.sharedInstance.signOut()
                self?.updateButtonStates()
            })
            present(alert, animated: true)
        } else {
            authenticateWithGoogle()
        }
    }
    
    private func authenticateWithGoogle() {
        googleDriveService.authenticate(from: self) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.updateButtonStates()
                case .failure(let error):
                    self?.showAlert(title: "שגיאה", message: "שגיאה בהתחברות: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func scanButtonTapped() {
        guard isAuthenticated else {
            showAlert(title: "לא מחובר", message: "יש להתחבר לחשבון Google לפני סריקת קבלות")
            return
        }
        
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
            
            // Upload to Google Drive
            self.googleDriveService.uploadReceipt(image: image) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.showAlert(title: "הצלחה", message: "הקבלה הועלתה בהצלחה")
                    case .failure(let error):
                        self.showAlert(title: "שגיאה", message: "שגיאה בהעלאת הקבלה: \(error.localizedDescription)")
                    }
                }
            }
        }
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