import UIKit
import PDFKit

class MonthReceiptsViewController: UIViewController {
    
    // MARK: - Properties
    private let monthName: String
    private let fileManager = LocalFileManager.shared
    private var receipts: [(url: URL, name: String, date: Date)] = []
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
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["רשימה", "תצוגה מקדימה"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(viewModeChanged(_:)), for: .valueChanged)
        return control
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "ReceiptCell")
        table.delegate = self
        table.dataSource = self
        return table
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 16
        let width = (UIScreen.main.bounds.width - spacing * 4) / 3
        layout.itemSize = CGSize(width: width, height: width * 1.4)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(ReceiptCollectionViewCell.self, forCellWithReuseIdentifier: "ReceiptCell")
        collection.delegate = self
        collection.dataSource = self
        collection.backgroundColor = .systemBackground
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
        updateViewMode()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = monthName
        
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(collectionView)
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadReceipts() {
        receipts = fileManager.getReceiptsInMonth(monthName)
    }
    
    // MARK: - Actions
    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        viewMode = sender.selectedSegmentIndex == 0 ? .list : .grid
    }
    
    private func updateViewMode() {
        switch viewMode {
        case .list:
            tableView.isHidden = false
            collectionView.isHidden = true
            tableView.reloadData()
        case .grid:
            tableView.isHidden = true
            collectionView.isHidden = false
            collectionView.reloadData()
        }
    }
    
    private func showReceipt(at url: URL) {
        let pdfVC = PDFViewController(fileURL: url)
        navigationController?.pushViewController(pdfVC, animated: true)
    }
    
    // MARK: - Context Menu
    private func makeContextMenu(for receipt: (url: URL, name: String, date: Date)) -> UIContextMenuConfiguration {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let share = UIAction(title: "שתף", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareReceipt(at: receipt.url)
            }
            
            let delete = UIAction(title: "מחק", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteReceipt(named: receipt.name)
            }
            
            return UIMenu(title: "", children: [share, delete])
        }
    }
    
    private func shareReceipt(at url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
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
                self.updateViewMode()
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension MonthReceiptsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return receipts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReceiptCell", for: indexPath)
        let receipt = receipts[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = receipt.name
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        content.secondaryText = dateFormatter.string(from: receipt.date)
        
        cell.contentConfiguration = content
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
extension MonthReceiptsViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return receipts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReceiptCell", for: indexPath) as! ReceiptCollectionViewCell
        let receipt = receipts[indexPath.row]
        
        cell.configure(with: receipt.url, fileManager: fileManager)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let receipt = receipts[indexPath.row]
        showReceipt(at: receipt.url)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return makeContextMenu(for: receipts[indexPath.row])
    }
} 