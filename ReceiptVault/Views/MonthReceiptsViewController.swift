import UIKit
import PDFKit

class MonthReceiptsViewController: UIViewController {
    
    // MARK: - Properties
    private let fileManager = LocalFileManager.shared
    private let monthName: String
    private var receipts: [(url: URL, name: String, date: Date)] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
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
        label.text = monthName
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "הקבלות שלך מחודש \(monthName)"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["רשימה", "תצוגה מקדימה"])
        control.selectedSegmentIndex = 0
        control.backgroundColor = .clear
        control.selectedSegmentTintColor = AppTheme.primaryColor
        control.setTitleTextAttributes([.foregroundColor: UIColor.secondaryLabel], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.addTarget(self, action: #selector(viewModeChanged(_:)), for: .valueChanged)
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(ReceiptCell.self, forCellReuseIdentifier: "ReceiptCell")
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = AppTheme.backgroundColor
        table.separatorStyle = .none
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.padding, right: 0)
        return table
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = AppTheme.padding
        layout.minimumInteritemSpacing = AppTheme.padding
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = AppTheme.backgroundColor
        collection.register(ReceiptPreviewCell.self, forCellWithReuseIdentifier: "ReceiptPreviewCell")
        collection.delegate = self
        collection.dataSource = self
        collection.contentInset = UIEdgeInsets(top: AppTheme.padding, left: AppTheme.padding, bottom: AppTheme.padding, right: AppTheme.padding)
        collection.isHidden = true
        return collection
    }()
    
    // MARK: - Initialization
    init(monthName: String) {
        self.monthName = monthName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadReceipts()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadReceipts()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = AppTheme.backgroundColor
        navigationItem.largeTitleDisplayMode = .never
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(collectionView)
        
        [headerView, titleLabel, subtitleLabel, segmentedControl, tableView, collectionView].forEach {
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
            
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: AppTheme.padding),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.padding),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.padding),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: AppTheme.padding),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: AppTheme.padding),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadReceipts() {
        receipts = fileManager.getReceiptsInMonth(monthName)
        tableView.reloadData()
        collectionView.reloadData()
    }
    
    // MARK: - Actions
    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        viewMode = sender.selectedSegmentIndex == 0 ? .list : .grid
    }
    
    private func updateViewMode() {
        UIView.animate(withDuration: 0.3) {
            self.tableView.isHidden = self.viewMode == .grid
            self.collectionView.isHidden = self.viewMode == .list
        }
    }
    
    private func showReceipt(at url: URL) {
        let pdfVC = PDFViewController(fileURL: url)
        navigationController?.pushViewController(pdfVC, animated: true)
    }
    
    private func shareReceipt(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func deleteReceipt(named fileName: String) {
        let alert = UIAlertController(
            title: "מחיקת קבלה",
            message: "האם אתה בטוח שברצונך למחוק את הקבלה?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        alert.addAction(UIAlertAction(title: "מחק", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if self.fileManager.deleteReceipt(fileName: fileName, monthName: self.monthName) {
                self.loadReceipts()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func makeContextMenu(for receipt: (url: URL, name: String, date: Date)) -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            // Return a preview view controller
            let pdfVC = PDFViewController(fileURL: receipt.url)
            return pdfVC
        }) { _ in
            let preview = UIAction(title: "תצוגה מקדימה", image: UIImage(systemName: "eye.fill")) { [weak self] _ in
                self?.showReceipt(at: receipt.url)
            }
            
            let share = UIAction(title: "שתף", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareReceipt(at: receipt.url)
            }
            
            let delete = UIAction(title: "מחק", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteReceipt(named: receipt.name)
            }
            
            return UIMenu(title: "", children: [preview, share, delete])
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension MonthReceiptsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return receipts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiptCell", for: indexPath) as! ReceiptCell
        let receipt = receipts[indexPath.row]
        cell.configure(name: receipt.name, date: receipt.date)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let receipt = receipts[indexPath.row]
        showReceipt(at: receipt.url)
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return makeContextMenu(for: receipts[indexPath.row])
    }
}

// MARK: - UICollectionViewDelegate & DataSource
extension MonthReceiptsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return receipts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReceiptPreviewCell", for: indexPath) as! ReceiptPreviewCell
        let receipt = receipts[indexPath.row]
        
        if let thumbnail = fileManager.generateThumbnail(for: receipt.url, size: CGSize(width: 200, height: 280)) {
            cell.configure(with: thumbnail, title: receipt.name, subtitle: dateFormatter.string(from: receipt.date))
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - AppTheme.padding * 3) / 2
        return CGSize(width: width, height: width * 1.4)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let receipt = receipts[indexPath.row]
        showReceipt(at: receipt.url)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return makeContextMenu(for: receipts[indexPath.row])
    }
}

// MARK: - ReceiptCell
class ReceiptCell: UITableViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = AppTheme.cardBackgroundColor
        view.layer.cornerRadius = AppTheme.cornerRadius
        AppTheme.applyShadow(to: view)
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .right
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
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
        containerView.addSubview(nameLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(chevronImageView)
        
        [containerView, nameLabel, dateLabel, chevronImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.padding),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.padding),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: AppTheme.padding),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            dateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: AppTheme.padding),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            dateLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -AppTheme.padding),
            
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -AppTheme.padding),
            chevronImageView.widthAnchor.constraint(equalToConstant: 8),
            chevronImageView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
    
    func configure(name: String, date: Date) {
        nameLabel.text = name
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = formatter.string(from: date)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        containerView.backgroundColor = AppTheme.cardBackgroundColor
        AppTheme.applyShadow(to: containerView)
    }
}

// MARK: - ReceiptPreviewCell
class ReceiptPreviewCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = AppTheme.cornerRadius
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .right
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        [imageView, titleLabel, subtitleLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1.3),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with image: UIImage, title: String, subtitle: String) {
        imageView.image = image
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
} 