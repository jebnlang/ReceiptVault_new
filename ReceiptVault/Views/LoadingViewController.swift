import UIKit

class LoadingViewController: UIViewController {
    
    // MARK: - Properties
    private var currentStage: UploadStage = .preparing {
        didSet {
            updateUI()
        }
    }
    
    private var progress: Float = 0 {
        didSet {
            updateProgress()
        }
    }
    
    enum UploadStage {
        case preparing
        case analyzingReceipt
        case creatingPDF
        case uploadingToDrive
        case updatingSheet
        case complete
        
        var title: String {
            switch self {
            case .preparing: return "מכין את הקבלה..."
            case .analyzingReceipt: return "מנתח את הקבלה..."
            case .creatingPDF: return "יוצר קובץ PDF..."
            case .uploadingToDrive: return "מעלה ל-Google Drive..."
            case .updatingSheet: return "מעדכן את הגיליון..."
            case .complete: return "הסתיים בהצלחה!"
            }
        }
        
        var systemImage: String {
            switch self {
            case .preparing: return "doc.text.viewfinder"
            case .analyzingReceipt: return "doc.text.magnifyingglass"
            case .creatingPDF: return "doc.badge.gearshape"
            case .uploadingToDrive: return "icloud.and.arrow.up"
            case .updatingSheet: return "tablecells"
            case .complete: return "checkmark.circle.fill"
            }
        }
    }
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.cardBackgroundColor
        view.layer.cornerRadius = 20
        AppTheme.applyShadow(to: view)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        imageView.preferredSymbolConfiguration = config
        imageView.tintColor = AppTheme.primaryColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.trackTintColor = .systemGray5
        progress.progressTintColor = AppTheme.primaryColor
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startLoadingAnimation()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(equalToConstant: 180),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            progressView.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        updateUI()
    }
    
    private func updateUI() {
        titleLabel.text = currentStage.title
        iconImageView.image = UIImage(systemName: currentStage.systemImage)
    }
    
    private func updateProgress() {
        UIView.animate(withDuration: 0.2) {
            self.progressView.setProgress(self.progress, animated: true)
        }
    }
    
    private func startLoadingAnimation() {
        iconImageView.transform = .identity
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .autoreverse]) {
            self.iconImageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }
    }
    
    // MARK: - Public Methods
    func updateStage(_ stage: UploadStage, withProgress progress: Float) {
        self.currentStage = stage
        self.progress = progress
        
        if stage == .complete {
            iconImageView.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.3) {
                self.iconImageView.transform = .identity
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.dismiss(animated: true)
            }
        }
    }
} 