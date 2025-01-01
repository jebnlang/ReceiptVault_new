import Foundation
import UIKit
import PDFKit

class LocalFileManager {
    static let shared = LocalFileManager()
    private let fileManager = FileManager.default
    
    private var rootFolderURL: URL? {
        print("\n=== Getting Root Folder URL ===")
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Error: Could not get documents URL")
            return nil
        }
        print("✓ Documents URL: \(documentsURL.path)")
        let url = documentsURL.appendingPathComponent("ReceiptVault", isDirectory: true)
        print("✓ Root folder URL: \(url.path)")
        return url
    }
    
    private init() {
        print("\n=== LocalFileManager Initialization ===")
        createRootFolderIfNeeded()
        print("✓ Initialization complete")
        
        // Debug: List contents of documents directory
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("\n=== Contents of Documents Directory ===")
            do {
                let contents = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                print("Found \(contents.count) items:")
                contents.forEach { print("- \($0.lastPathComponent)") }
            } catch {
                print("❌ Error listing documents directory: \(error)")
            }
        }
    }
    
    // MARK: - Folder Management
    private func createRootFolderIfNeeded() {
        print("\n=== Creating Root Folder ===")
        guard let rootURL = rootFolderURL else {
            print("❌ Error: Could not get root folder URL")
            return
        }
        
        print("Checking if root folder exists at: \(rootURL.path)")
        if !fileManager.fileExists(atPath: rootURL.path) {
            do {
                print("Creating root folder at: \(rootURL.path)")
                try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
                print("✓ Successfully created root folder")
                
                // Debug: Verify creation
                if fileManager.fileExists(atPath: rootURL.path) {
                    print("✓ Verified: Root folder exists after creation")
                } else {
                    print("❌ Error: Root folder not found after creation attempt")
                }
            } catch {
                print("❌ Error creating root folder: \(error)")
            }
        } else {
            print("✓ Root folder already exists")
        }
    }
    
    func createMonthFolderIfNeeded(monthName: String) -> URL? {
        print("Attempting to create/get month folder: \(monthName)")
        guard let rootURL = rootFolderURL else {
            print("Error: Could not get root folder URL for month creation")
            return nil
        }
        let monthURL = rootURL.appendingPathComponent(monthName, isDirectory: true)
        print("Month folder URL: \(monthURL.path)")
        
        if !fileManager.fileExists(atPath: monthURL.path) {
            do {
                print("Creating month folder at: \(monthURL.path)")
                try fileManager.createDirectory(at: monthURL, withIntermediateDirectories: true)
                print("Successfully created month folder")
                return monthURL
            } catch {
                print("Error creating month folder: \(error)")
                return nil
            }
        } else {
            print("Month folder already exists")
        }
        
        return monthURL
    }
    
    // MARK: - File Operations
    func saveReceipt(pdfData: Data, fileName: String, monthName: String) -> Bool {
        print("\n=== Saving Receipt ===")
        print("📄 File: \(fileName)")
        print("📅 Month: \(monthName)")
        print("📦 Data size: \(pdfData.count) bytes")
        
        guard let monthURL = createMonthFolderIfNeeded(monthName: monthName) else {
            print("❌ Error: Could not create/get month folder")
            return false
        }
        let fileURL = monthURL.appendingPathComponent(fileName)
        print("💾 Saving to: \(fileURL.path)")
        
        do {
            try pdfData.write(to: fileURL)
            print("✓ Successfully saved receipt")
            
            // Debug: Verify file was saved
            if fileManager.fileExists(atPath: fileURL.path) {
                print("✓ Verified: File exists after saving")
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                    print("📊 Saved file size: \(attributes[.size] ?? 0) bytes")
                }
            } else {
                print("❌ Error: File not found after saving")
            }
            return true
        } catch {
            print("❌ Error saving receipt: \(error)")
            return false
        }
    }
    
    func deleteReceipt(fileName: String, monthName: String) -> Bool {
        print("Attempting to delete receipt: \(fileName) from month: \(monthName)")
        guard let monthURL = rootFolderURL?.appendingPathComponent(monthName) else {
            print("Error: Could not get month folder URL for deletion")
            return false
        }
        let fileURL = monthURL.appendingPathComponent(fileName)
        print("Deleting receipt at: \(fileURL.path)")
        
        do {
            try fileManager.removeItem(at: fileURL)
            print("Successfully deleted receipt")
            return true
        } catch {
            print("Error deleting receipt: \(error)")
            return false
        }
    }
    
    // MARK: - Fetching
    func getAllMonths() -> [String] {
        print("\n=== Getting All Months ===")
        guard let rootURL = rootFolderURL else {
            print("❌ Error: Could not get root folder URL for fetching months")
            return []
        }
        print("📂 Looking for months in: \(rootURL.path)")
        
        do {
            // First check if root folder exists
            if !fileManager.fileExists(atPath: rootURL.path) {
                print("❌ Root folder does not exist, creating it...")
                try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
                print("✓ Created root folder")
            }
            
            // Get contents of root folder
            let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
            print("📝 Raw contents: \(contents.map { $0.lastPathComponent })")
            
            let months = contents
                .filter { $0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .sorted(by: >)
            
            print("✓ Found \(months.count) months: \(months)")
            return months
        } catch {
            print("❌ Error fetching months: \(error)")
            return []
        }
    }
    
    func getReceiptsInMonth(_ monthName: String) -> [(url: URL, name: String, date: Date)] {
        print("Fetching receipts for month: \(monthName)")
        guard let monthURL = rootFolderURL?.appendingPathComponent(monthName) else {
            print("Error: Could not get month folder URL for fetching receipts")
            return []
        }
        print("Looking for receipts in: \(monthURL.path)")
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: monthURL, includingPropertiesForKeys: [.creationDateKey])
            let receipts = contents
                .filter { $0.pathExtension == "pdf" }
                .compactMap { (url: URL) -> (url: URL, name: String, date: Date)? in
                    if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                       let creationDate = attributes[.creationDate] as? Date {
                        return (url: url, name: url.deletingPathExtension().lastPathComponent, date: creationDate)
                    }
                    return nil
                }
                .sorted { $0.date > $1.date }
            print("Found \(receipts.count) receipts")
            return receipts
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