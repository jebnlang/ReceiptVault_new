import UIKit

class MonthCollectionCell: UICollectionViewCell {
    
    // MARK: - UI Elements
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.cardBackgroundColor
        view.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.styleCard(view)
        return view
    }()
    
    private lazy var monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()
    
    private lazy var iconImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        let image = UIImage(systemName: "folder.fill", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = AppTheme.primaryColor
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(monthLabel)
        containerView.addSubview(countLabel)
        
        [containerView, iconImageView, monthLabel, countLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppTheme.padding),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            
            monthLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: AppTheme.padding),
            monthLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            monthLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppTheme.padding),
            
            countLabel.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 4),
            countLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            countLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppTheme.padding),
            countLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -AppTheme.padding)
        ])
    }
    
    // MARK: - Configuration
    func configure(monthName: String, receiptCount: Int) {
        monthLabel.text = monthName
        countLabel.text = "\(receiptCount) קבלות"
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        monthLabel.text = nil
        countLabel.text = nil
    }
} 