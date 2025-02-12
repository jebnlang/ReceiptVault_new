import UIKit
import GoogleSignIn

class SettingsViewController: UIViewController {
    
    // MARK: - Properties
    private let googleDriveService = GoogleDriveService.shared
    private var isAuthenticated: Bool {
        return GIDSignIn.sharedInstance.currentUser != nil
    }
    
    // MARK: - UI Elements
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.backgroundColor
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "הגדרות"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "נהל את החיבור שלך לגוגל דרייב"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private lazy var containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppTheme.padding
        stack.layoutMargins = UIEdgeInsets(top: AppTheme.padding, 
                                         left: AppTheme.padding, 
                                         bottom: AppTheme.padding, 
                                         right: AppTheme.padding)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()
    
    private lazy var signInButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.styleCard(button)
        button.contentHorizontalAlignment = .center
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        // Add Google logo
        if let googleLogo = UIImage(named: "google-logo")?.withRenderingMode(.alwaysOriginal) {
            button.setImage(googleLogo, for: .normal)
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        }
        
        button.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
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
        view.backgroundColor = AppTheme.backgroundColor
        navigationItem.largeTitleDisplayMode = .never
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        view.addSubview(containerStackView)
        containerStackView.addArrangedSubview(signInButton)
        
        [headerView, titleLabel, subtitleLabel, containerStackView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: AppTheme.padding),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: AppTheme.padding),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -AppTheme.padding),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: AppTheme.padding),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -AppTheme.padding),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -AppTheme.padding),
            
            containerStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        updateButtonStates()
    }
    
    private func updateButtonStates() {
        if isAuthenticated {
            signInButton.setTitle("מחובר לגוגל דרייב - לחץ להתנתק", for: .normal)
            signInButton.backgroundColor = AppTheme.accentColor
            signInButton.tintColor = .white
            signInButton.setTitleColor(.white, for: .normal)
        } else {
            signInButton.setTitle("התחבר עם גוגל", for: .normal)
            signInButton.backgroundColor = AppTheme.cardBackgroundColor
            signInButton.tintColor = .label
            signInButton.setTitleColor(.label, for: .normal)
        }
    }
    
    // MARK: - Actions
    @objc private func signInButtonTapped() {
        if isAuthenticated {
            GIDSignIn.sharedInstance.signOut()
            NotificationCenter.default.post(name: .googleSignInStatusChanged, object: nil)
            updateButtonStates()
        } else {
            googleDriveService.authenticate(from: self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.updateButtonStates()
                        NotificationCenter.default.post(name: .googleSignInStatusChanged, object: nil)
                    case .failure(let error):
                        print("Failed to authenticate with Google Drive: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
} 