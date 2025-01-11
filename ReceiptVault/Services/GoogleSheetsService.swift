import Foundation
import GoogleAPIClientForREST_Sheets
import GoogleAPIClientForREST_Drive
import GoogleSignIn

class GoogleSheetsService {
    static let shared = GoogleSheetsService()
    private let sheetsService = GTLRSheetsService()
    
    private init() {
        print("Initializing GoogleSheetsService...")
        updateAuthorizer()
    }
    
    private func updateAuthorizer() {
        if let authorizer = GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer {
            sheetsService.authorizer = authorizer
            print("✓ Sheets service authorizer updated")
        } else {
            print("⚠️ No authorizer available for sheets service")
        }
    }
    
    // Ensure service is properly authorized
    private func ensureAuthorized() throws {
        if sheetsService.authorizer == nil {
            print("Attempting to update authorizer...")
            updateAuthorizer()
            
            if sheetsService.authorizer == nil {
                print("❌ Still no authorizer available")
                throw GoogleSheetsError.notAuthorized
            }
        }
    }
    
    // Hebrew month names
    private let hebrewMonths = [
        "ינואר", "פברואר", "מרץ", "אפריל", "מאי", "יוני",
        "יולי", "אוגוסט", "ספטמבר", "אוקטובר", "נובמבר", "דצמבר"
    ]
    
    // Column headers in Hebrew
    private let columnHeaders = [
        "שם העסק",
        "תאריך",
        "כתובת",
        "טלפון",
        "ח.פ",
        "מה נרכש",
        "מחיר סך הכל",
        "מע״מ",
        "אמצעי תשלום",
        "ארבע ספרות אחרונות של כרטיס האשראי"
    ]
    
    /// Creates a new monthly summary sheet if it doesn't exist
    func ensureMonthlySheet(in folderId: String, month: Int, year: Int) async throws -> String {
        let sheetName = String(format: "Receipts_%02d_%d", month, year)
        
        // First, check if the sheet already exists in the folder
        let (exists, existingId) = try await GoogleDriveService.shared.searchFile(
            name: sheetName,
            mimeType: "application/vnd.google-apps.spreadsheet",
            parentId: folderId
        )
        
        if exists, let id = existingId {
            return id
        }
        
        // If not exists, create new sheet
        let spreadsheet = GTLRSheets_Spreadsheet()
        spreadsheet.properties = GTLRSheets_SpreadsheetProperties()
        spreadsheet.properties?.title = sheetName
        
        let createRequest = GTLRSheetsQuery_SpreadsheetsCreate.query(withObject: spreadsheet)
        let (sheetId, _) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, GTLRSheets_Spreadsheet), Error>) in
            sheetsService.executeQuery(createRequest) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let spreadsheet = result as? GTLRSheets_Spreadsheet,
                      let spreadsheetId = spreadsheet.spreadsheetId else {
                    continuation.resume(throwing: NSError(domain: "com.receiptvault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }
                
                continuation.resume(returning: (spreadsheetId, spreadsheet))
            }
        }
        
        // Move the sheet to the correct folder
        try await GoogleDriveService.shared.moveFile(fileId: sheetId, toFolder: folderId)
        
        // Set up headers and formatting for the new sheet
        try await setupSheetHeaders(spreadsheetId: sheetId)
        
        return sheetId
    }
    
    /// Sets up the sheet headers and initial formatting
    private func setupSheetHeaders(spreadsheetId: String) async throws {
        // Add headers
        let headerRange = "A1:J1"
        let headerValues = [columnHeaders]
        
        let valueRange = GTLRSheets_ValueRange()
        valueRange.values = headerValues
        
        let updateRequest = GTLRSheetsQuery_SpreadsheetsValuesUpdate.query(
            withObject: valueRange,
            spreadsheetId: spreadsheetId,
            range: headerRange)
        updateRequest.valueInputOption = "RAW"
        
        // First, update the headers
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sheetsService.executeQuery(updateRequest) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        
        // Then apply formatting
        let requests = [
            // Make headers bold
            GTLRSheets_Request.init(json: [
                "repeatCell": [
                    "range": [
                        "sheetId": 0,
                        "startRowIndex": 0,
                        "endRowIndex": 1,
                        "startColumnIndex": 0,
                        "endColumnIndex": columnHeaders.count
                    ],
                    "cell": [
                        "userEnteredFormat": [
                            "textFormat": ["bold": true],
                            "horizontalAlignment": "RIGHT",  // Ensure headers are RTL aligned
                            "borders": [
                                "bottom": [
                                    "style": "SOLID",
                                    "width": 2,
                                    "color": ["red": 0, "green": 0, "blue": 0, "alpha": 1]
                                ]
                            ]
                        ]
                    ],
                    "fields": "userEnteredFormat(textFormat.bold,horizontalAlignment,borders)"
                ]
            ]),
            // Set currency format for price columns
            GTLRSheets_Request.init(json: [
                "repeatCell": [
                    "range": [
                        "sheetId": 0,
                        "startRowIndex": 1,
                        "startColumnIndex": 6,  // Total Price column
                        "endColumnIndex": 8     // Including VAT column
                    ],
                    "cell": [
                        "userEnteredFormat": [
                            "numberFormat": [
                                "type": "CURRENCY",
                                "pattern": "₪#,##0.00"
                            ]
                        ]
                    ],
                    "fields": "userEnteredFormat.numberFormat"
                ]
            ]),
            // Set RTL alignment for all cells
            GTLRSheets_Request.init(json: [
                "repeatCell": [
                    "range": [
                        "sheetId": 0,
                        "startRowIndex": 0,
                        "startColumnIndex": 0,
                        "endColumnIndex": columnHeaders.count
                    ],
                    "cell": [
                        "userEnteredFormat": [
                            "horizontalAlignment": "RIGHT"
                        ]
                    ],
                    "fields": "userEnteredFormat.horizontalAlignment"
                ]
            ]),
            // Auto-resize columns to fit content
            GTLRSheets_Request.init(json: [
                "autoResizeDimensions": [
                    "dimensions": [
                        "sheetId": 0,
                        "dimension": "COLUMNS",
                        "startIndex": 0,
                        "endIndex": columnHeaders.count
                    ]
                ]
            ])
        ]
        
        let batchUpdateRequest = GTLRSheets_BatchUpdateSpreadsheetRequest()
        batchUpdateRequest.requests = requests
        
        let formatRequest = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(
            withObject: batchUpdateRequest,
            spreadsheetId: spreadsheetId)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sheetsService.executeQuery(formatRequest) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Adds a new row of data extracted from a receipt
    func addReceiptData(to sheetId: String, extractedData: [String: String]) async throws {
        print("\n=== Starting Sheet Update Process ===")
        
        do {
            try ensureAuthorized()
            
            // Map extracted data to columns
            print("Mapping extracted data to columns...")
            let rowData = columnHeaders.map { header in
                let value = extractedData[header] ?? ""
                print("Column '\(header)': \(value)")
                return value
            }
            
            let valueRange = GTLRSheets_ValueRange()
            valueRange.values = [rowData]
            
            print("Preparing append request...")
            let appendRequest = GTLRSheetsQuery_SpreadsheetsValuesAppend.query(
                withObject: valueRange,
                spreadsheetId: sheetId,
                range: "A:J")
            appendRequest.valueInputOption = "USER_ENTERED"
            appendRequest.insertDataOption = "INSERT_ROWS"
            
            print("Executing append request...")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                sheetsService.executeQuery(appendRequest) { (ticket, result, error) in
                    if let error = error {
                        print("❌ Sheet update failed: \(error)")
                        continuation.resume(throwing: GoogleSheetsError.appendFailed(error))
                    } else {
                        print("✓ Sheet update successful")
                        continuation.resume(returning: ())
                    }
                }
            }
            
            print("=== Sheet Update Process Complete ===")
        } catch {
            print("❌ Sheet update process failed: \(error)")
            throw error
        }
    }
    
    enum GoogleSheetsError: Error {
        case notAuthorized
        case appendFailed(Error)
        case invalidResponse
        case sheetCreationFailed
    }
} 