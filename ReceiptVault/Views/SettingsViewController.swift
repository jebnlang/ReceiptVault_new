import UIKit
import GoogleSignIn

class SettingsViewController: UIViewController {
    
    // MARK: - Properties
    private let googleDriveService = GoogleDriveService.shared
    private var isAuthenticated: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    // MARK: - UI Elements
    private lazy var signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        // Add Google logo
        if let googleLogo = UIImage(named: "google-logo")?.withRenderingMode(.alwaysOriginal) {
            button.setImage(googleLogo, for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        }
        
        button.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var folderButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let folderImage = UIImage(systemName: "folder.fill", withConfiguration: config)
        button.setImage(folderImage, for: .normal)
        button.setTitle("פתח תיקייה בגוגל דרייב", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.backgroundColor = .systemGreen
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.1
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.isEnabled = false
        button.alpha = 0.5
        button.addTarget(self, action: #selector(folderButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateButtonStates()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "הגדרות"
        
        view.addSubview(signInButton)
        view.addSubview(folderButton)
        
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            signInButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            signInButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            signInButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            signInButton.heightAnchor.constraint(equalToConstant: 44),
            
            folderButton.topAnchor.constraint(equalTo: signInButton.bottomAnchor, constant: 16),
            folderButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            folderButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            folderButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        folderButton.isEnabled = isAuthenticated
        folderButton.alpha = isAuthenticated ? 1.0 : 0.5
        
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
                NotificationCenter.default.post(name: .googleSignInStatusChanged, object: nil)
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
                    NotificationCenter.default.post(name: .googleSignInStatusChanged, object: nil)
                case .failure(let error):
                    self?.showAlert(title: "שגיאה", message: "שגיאה בהתחברות: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func folderButtonTapped() {
        guard isAuthenticated else { return }
        
        googleDriveService.getRootFolderId { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let folderId):
                    if let url = URL(string: "https://drive.google.com/drive/folders/\(folderId)") {
                        UIApplication.shared.open(url)
                    }
                case .failure(let error):
                    self?.showAlert(title: "שגיאה", message: "לא ניתן לפ��וח את התיקייה: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
} 