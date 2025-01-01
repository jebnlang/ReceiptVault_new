import UIKit
import PDFKit

class LocalStorageViewController: UIViewController {
    
    // MARK: - Properties
    private let fileManager = LocalFileManager.shared
    private var months: [String] = []
    
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
        
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        view.addSubview(tableView)
        
        [headerView, titleLabel, subtitleLabel, tableView].forEach {
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
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadMonths() {
        months = fileManager.getAllMonths()
        tableView.reloadData()
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