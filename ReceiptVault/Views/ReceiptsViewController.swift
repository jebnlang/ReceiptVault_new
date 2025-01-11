import UIKit
import PDFKit
import GoogleSignIn

class ReceiptsViewController: UIViewController {
    
    // MARK: - Properties
    private let fileManager = LocalFileManager.shared
    private let googleDriveService = GoogleDriveService.shared
    private var months: [String] = []
    private var viewMode: ViewMode = .list {
        didSet {
            updateViewMode()
        }
    }
    
    private enum ViewMode {
        case list
        case grid
    }
    
    // MARK: - UI Elements
    private lazy var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.backgroundColor
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "קבלות"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "בחר מקור אחסון"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private lazy var storageOptionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppTheme.padding
        stack.distribution = .fillEqually
        return stack
    }()
    
    private lazy var googleDriveButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let driveImage = UIImage(systemName: "cloud.fill", withConfiguration: config)
        button.setImage(driveImage, for: .normal)
        button.setTitle("Google Drive", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.applyShadow(to: button)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.isEnabled = GIDSignIn.sharedInstance.currentUser != nil
        button.alpha = GIDSignIn.sharedInstance.currentUser != nil ? 1 : 0.5
        button.addTarget(self, action: #selector(googleDriveButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var localStorageButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let folderImage = UIImage(systemName: "folder.fill", withConfiguration: config)
        button.setImage(folderImage, for: .normal)
        button.setTitle("אחסון מקומי", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.backgroundColor = .systemGreen
        button.tintColor = .white
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.applyShadow(to: button)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: #selector(localStorageButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(MonthCell.self, forCellReuseIdentifier: "MonthCell")
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("\n=== ReceiptsViewController: viewDidLoad ===")
        setupUI()
        setupTableView()
        loadMonths()
        setupNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("\n=== ReceiptsViewController: viewWillAppear ===")
        loadMonths()
        updateFolderButtonState()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = AppTheme.backgroundColor
        navigationItem.largeTitleDisplayMode = .never
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(storageOptionsStackView)
        
        storageOptionsStackView.addArrangedSubview(googleDriveButton)
        storageOptionsStackView.addArrangedSubview(localStorageButton)
        
        [headerView, titleLabel, subtitleLabel, storageOptionsStackView].forEach {
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
            
            storageOptionsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: AppTheme.padding * 1.5),
            storageOptionsStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: AppTheme.padding),
            storageOptionsStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -AppTheme.padding),
            storageOptionsStackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -AppTheme.padding)
        ])
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadMonths() {
        loadReceipts()
    }
    
    // MARK: - Actions
    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        viewMode = sender.selectedSegmentIndex == 0 ? .list : .grid
    }
    
    @objc private func googleDriveButtonTapped() {
        if GIDSignIn.sharedInstance.currentUser == nil { return }
        
        // Get the root folder ID and open its URL
        Task {
            do {
                let folderId = try await GoogleDriveService.shared.getRootFolderId()
                if let url = URL(string: "https://drive.google.com/drive/folders/\(folderId)") {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                print("Failed to get root folder ID: \(error)")
                // Fallback to opening the main Drive URL
                if let url = URL(string: "https://drive.google.com") {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    @objc private func localStorageButtonTapped() {
        let localStorageVC = LocalStorageViewController()
        navigationController?.pushViewController(localStorageVC, animated: true)
    }
    
    private func updateViewMode() {
        // Will be implemented when showing receipts
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoogleSignInStatusChanged),
            name: .googleSignInStatusChanged,
            object: nil
        )
    }
    
    @objc private func handleGoogleSignInStatusChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateFolderButtonState()
        }
    }
    
    private func updateFolderButtonState() {
        let isAuthenticated = GIDSignIn.sharedInstance.currentUser != nil
        googleDriveButton.isEnabled = isAuthenticated
        googleDriveButton.alpha = isAuthenticated ? 1 : 0.5
    }
    
    // Add property to track reload state
    private var needsReload: Bool = true
    
    private func loadReceipts() {
        Task { @MainActor in
            print("\n=== Loading Months ===")
            let months = fileManager.getAllMonths()
            print("Found months: \(months)")
            self.months = months
            self.tableView.reloadData()
            self.needsReload = false
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension ReceiptsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("\n=== Table View Data Source ===")
        print("Number of months: \(months.count)")
        print("Months: \(months)")
        return months.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MonthCell", for: indexPath) as! MonthCell
        let month = months[indexPath.row]
        let receipts = fileManager.getReceiptsInMonth(month)
        print("Configuring cell for month: \(month)")
        print("Found \(receipts.count) receipts")
        cell.configure(monthName: month, receiptCount: receipts.count)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let month = months[indexPath.row]
        print("Selected month: \(month)")
        let receiptsVC = MonthReceiptsViewController(monthName: month)
        navigationController?.pushViewController(receiptsVC, animated: true)
    }
}

// MARK: - MonthCell
class MonthCell: UITableViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.cardBackgroundColor
        view.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.applyShadow(to: view)
        return view
    }()
    
    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        return label
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let chevronImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = UIImage(systemName: "chevron.right", withConfiguration: config)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .tertiaryLabel
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(containerView)
        containerView.addSubview(monthLabel)
        containerView.addSubview(countLabel)
        containerView.addSubview(chevronImageView)
        
        [containerView, monthLabel, countLabel, chevronImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.padding),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.padding),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            monthLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppTheme.padding),
            monthLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            monthLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            countLabel.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: 4),
            countLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            countLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            countLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -AppTheme.padding),
            
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppTheme.padding),
            chevronImageView.widthAnchor.constraint(equalToConstant: 8),
            chevronImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    func configure(monthName: String, receiptCount: Int) {
        monthLabel.text = monthName
        countLabel.text = "\(receiptCount) קבלות"
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        containerView.backgroundColor = AppTheme.cardBackgroundColor
        AppTheme.applyShadow(to: containerView)
    }
} 