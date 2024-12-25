import Foundation
import UIKit
import PDFKit

class LocalFileManager {
    static let shared = LocalFileManager()
    private let fileManager = FileManager.default
    
    private var rootFolderURL: URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent("ReceiptVault", isDirectory: true)
    }
    
    private init() {
        createRootFolderIfNeeded()
    }
    
    // MARK: - Folder Management
    private func createRootFolderIfNeeded() {
        guard let rootURL = rootFolderURL else { return }
        
        if !fileManager.fileExists(atPath: rootURL.path) {
            do {
                try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating root folder: \(error)")
            }
        }
    }
    
    func createMonthFolderIfNeeded(monthName: String) -> URL? {
        guard let rootURL = rootFolderURL else { return nil }
        let monthURL = rootURL.appendingPathComponent(monthName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: monthURL.path) {
            do {
                try fileManager.createDirectory(at: monthURL, withIntermediateDirectories: true)
                return monthURL
            } catch {
                print("Error creating month folder: \(error)")
                return nil
            }
        }
        
        return monthURL
    }
    
    // MARK: - File Operations
    func saveReceipt(pdfData: Data, fileName: String, monthName: String) -> Bool {
        guard let monthURL = createMonthFolderIfNeeded(monthName: monthName) else { return false }
        let fileURL = monthURL.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            return true
        } catch {
            print("Error saving receipt: \(error)")
            return false
        }
    }
    
    func deleteReceipt(fileName: String, monthName: String) -> Bool {
        guard let monthURL = rootFolderURL?.appendingPathComponent(monthName) else { return false }
        let fileURL = monthURL.appendingPathComponent(fileName)
        
        do {
            try fileManager.removeItem(at: fileURL)
            return true
        } catch {
            print("Error deleting receipt: \(error)")
            return false
        }
    }
    
    // MARK: - Fetching
    func getAllMonths() -> [String] {
        guard let rootURL = rootFolderURL else { return [] }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
            return contents
                .filter { $0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .sorted(by: >)  // Sort in descending order
        } catch {
            print("Error fetching months: \(error)")
            return []
        }
    }
    
    func getReceiptsInMonth(_ monthName: String) -> [(url: URL, name: String, date: Date)] {
        guard let monthURL = rootFolderURL?.appendingPathComponent(monthName) else { return [] }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: monthURL, includingPropertiesForKeys: [.creationDateKey])
            return contents
                .filter { $0.pathExtension == "pdf" }
                .compactMap { url -> (URL, String, Date)? in
                    if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                       let creationDate = attributes[.creationDate] as? Date {
                        return (url, url.deletingPathExtension().lastPathComponent, creationDate)
                    }
                    return nil
                }
                .sorted { $0.date > $1.date }  // Sort by date descending
        } catch {
            print("Error fetching receipts: \(error)")
            return []
        }
    }
    
    // MARK: - Thumbnail Generation
    func generateThumbnail(for pdfURL: URL, size: CGSize) -> UIImage? {
        guard let document = PDFDocument(url: pdfURL),
              let page = document.page(at: 0) else {
            return nil
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let thumbnail = renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: size))
            
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            
            let scale = min(size.width / pageRect.width, size.height / pageRect.height)
            context.cgContext.scaleBy(x: scale, y: scale)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return thumbnail
    }
} 