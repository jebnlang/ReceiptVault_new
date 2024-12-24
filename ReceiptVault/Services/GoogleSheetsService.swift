import Foundation
import GoogleAPIClientForREST_Sheets
import GoogleAPIClientForREST_Drive
import GoogleSignIn

class GoogleSheetsService {
    static let shared = GoogleSheetsService()
    private let sheetsService = GTLRSheetsService()
    
    private init() {
        sheetsService.authorizer = GIDSignIn.sharedInstance.currentUser?.fetcherAuthorizer
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
        let sheetTitle = "סיכום הוצאות - \(hebrewMonths[month - 1]) \(year)"
        
        // Check if sheet exists
        let existingFile = try await GoogleDriveService.shared.searchFile(name: sheetTitle, in: folderId)
        if let fileId = existingFile?.identifier {
            return fileId
        }
        
        // Create new sheet
        let spreadsheet = GTLRSheets_Spreadsheet()
        spreadsheet.properties = GTLRSheets_SpreadsheetProperties()
        spreadsheet.properties?.title = sheetTitle
        spreadsheet.properties?.locale = "iw"
        
        let createRequest = GTLRSheetsQuery_SpreadsheetsCreate.query(withObject: spreadsheet)
        let response: GTLRSheets_Spreadsheet = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GTLRSheets_Spreadsheet, Error>) in
            sheetsService.executeQuery(createRequest) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let spreadsheet = result as? GTLRSheets_Spreadsheet {
                    continuation.resume(returning: spreadsheet)
                } else {
                    continuation.resume(throwing: NSError(domain: "GoogleSheetsService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
                }
            }
        }
        
        guard let spreadsheetId = response.spreadsheetId else {
            throw NSError(domain: "GoogleSheetsService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create spreadsheet"])
        }
        
        // Move to correct folder
        try await GoogleDriveService.shared.moveFile(fileId: spreadsheetId, to: folderId)
        
        // Setup headers and formatting
        try await setupSheetHeaders(spreadsheetId: spreadsheetId)
        
        return spreadsheetId
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
    func addReceiptData(to spreadsheetId: String, extractedData: [String: String]) async throws {
        // Map extracted data to columns
        let rowData = columnHeaders.map { header in
            return extractedData[header] ?? ""
        }
        
        let valueRange = GTLRSheets_ValueRange()
        valueRange.values = [rowData]
        
        let appendRequest = GTLRSheetsQuery_SpreadsheetsValuesAppend.query(
            withObject: valueRange,
            spreadsheetId: spreadsheetId,
            range: "A:J")
        appendRequest.valueInputOption = "USER_ENTERED"
        appendRequest.insertDataOption = "INSERT_ROWS"
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sheetsService.executeQuery(appendRequest) { (ticket, result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
} 