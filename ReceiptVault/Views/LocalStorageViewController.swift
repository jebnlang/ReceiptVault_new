import UIKit
import PDFKit

class LocalStorageViewController: UIViewController {
    
    // MARK: - Properties
    private let fileManager = LocalFileManager.shared
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
        label.text = "אחסון מקומי"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .right
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "כל הקבלות שלך מאורגנות לפי חודשים"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(MonthCell.self, forCellReuseIdentifier: "MonthCell")
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = AppTheme.backgroundColor
        table.separatorStyle = .none
        table.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: AppTheme.padding, right: 0)
        return table
    }()
    
    private lazy var viewModeSegmentedControl: UISegmentedControl = {
        let items = ["רשימה", "רשת"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(viewModeChanged), for: .valueChanged)
        return control
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = AppTheme.padding
        layout.minimumLineSpacing = AppTheme.padding
        layout.sectionInset = UIEdgeInsets(top: AppTheme.padding, left: AppTheme.padding, bottom: AppTheme.padding, right: AppTheme.padding)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = AppTheme.backgroundColor
        collection.register(MonthCollectionCell.self, forCellWithReuseIdentifier: "MonthCollectionCell")
        collection.delegate = self
        collection.dataSource = self
        collection.isHidden = true
        return collection
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMonths()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadMonths()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = AppTheme.backgroundColor
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.titleView = viewModeSegmentedControl
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        view.addSubview(tableView)
        view.addSubview(collectionView)
        
        [headerView, titleLabel, subtitleLabel, tableView, collectionView].forEach {
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
            
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: AppTheme.padding),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: AppTheme.padding),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        updateViewMode()
    }
    
    private func loadMonths() {
        months = fileManager.getAllMonths()
        tableView.reloadData()
    }
    
    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        viewMode = sender.selectedSegmentIndex == 0 ? .list : .grid
    }
    
    private func updateViewMode() {
        tableView.isHidden = viewMode == .grid
        collectionView.isHidden = viewMode == .list
        
        if viewMode == .grid {
            let width = (view.bounds.width - (AppTheme.padding * 3)) / 2
            if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.itemSize = CGSize(width: width, height: width * 1.2)
            }
            collectionView.reloadData()
        } else {
            tableView.reloadData()
        }
    }
    
    // Add support for device-specific actions
    private func showOptionsMenu(for month: String) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "שתף", style: .default) { [weak self] _ in
            self?.shareMonth(month)
        })
        
        alert.addAction(UIAlertAction(title: "מחק", style: .destructive) { [weak self] _ in
            self?.deleteMonth(month)
        })
        
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        
        // Configure for iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func shareMonth(_ month: String) {
        let receipts = fileManager.getReceiptsInMonth(month)
        let urls = receipts.map { $0.url }
        
        let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        
        // Configure for iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func deleteMonth(_ month: String) {
        let alert = UIAlertController(
            title: "מחיקת חודש",
            message: "האם אתה בטוח שברצונך למחוק את כל הקבלות מחודש \(month)?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "מחק", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // Get all receipts for the month
            let receipts = self.fileManager.getReceiptsInMonth(month)
            var deletionError = false
            
            // Delete each receipt
            for receipt in receipts {
                do {
                    try FileManager.default.removeItem(at: receipt.url)
                } catch {
                    print("Error deleting receipt: \(error)")
                    deletionError = true
                }
            }
            
            // Try to remove the month directory if it's empty
            if let monthURL = self.fileManager.getMonthDirectory(for: month) {
                do {
                    try FileManager.default.removeItem(at: monthURL)
                } catch {
                    print("Error deleting month directory: \(error)")
                    deletionError = true
                }
            }
            
            self.loadMonths()
            
            // Show feedback to user
            if deletionError {
                self.showAlert(title: "שגיאה", message: "חלק מהקבלות לא נמחקו בהצלחה")
            }
        })
        
        alert.addAction(UIAlertAction(title: "ביטול", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "אישור", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension LocalStorageViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return months.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MonthCell", for: indexPath) as! MonthCell
        let month = months[indexPath.row]
        let receipts = fileManager.getReceiptsInMonth(month)
        cell.configure(monthName: month, receiptCount: receipts.count)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let month = months[indexPath.row]
        let monthReceiptsVC = MonthReceiptsViewController(monthName: month)
        navigationController?.pushViewController(monthReceiptsVC, animated: true)
    }
}

// MARK: - UICollectionViewDelegate & DataSource
extension LocalStorageViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return months.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MonthCollectionCell", for: indexPath) as! MonthCollectionCell
        let month = months[indexPath.row]
        let receipts = fileManager.getReceiptsInMonth(month)
        cell.configure(monthName: month, receiptCount: receipts.count)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let month = months[indexPath.row]
        let monthReceiptsVC = MonthReceiptsViewController(monthName: month)
        navigationController?.pushViewController(monthReceiptsVC, animated: true)
    }
}

// Add long press gesture for options menu
extension LocalStorageViewController {
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let month = months[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let share = UIAction(title: "שתף", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareMonth(month)
            }
            
            let delete = UIAction(title: "מחק", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteMonth(month)
            }
            
            return UIMenu(children: [share, delete])
        }
    }
} 