import Foundation

enum AzureError: Error {
    case invalidConfiguration
    case networkError(String)
    case invalidResponse
    case authenticationError
    case processingError(String)
    case noDataExtracted
    
    var localizedDescription: String {
        switch self {
        case .invalidConfiguration:
            return "Azure configuration is invalid or missing"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from Azure service"
        case .authenticationError:
            return "Failed to authenticate with Azure"
        case .processingError(let message):
            return "Processing error: \(message)"
        case .noDataExtracted:
            return "No data could be extracted from the document"
        }
    }
} 