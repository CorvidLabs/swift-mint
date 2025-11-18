import Foundation

// MARK: - Mint Errors

/// Errors that can occur during minting operations
public enum MintError: Error, LocalizedError, Sendable {
    case invalidCID(String)
    case invalidMetadata(String)
    case transactionFailed(String)
    case networkError(String)
    case notAuthorized(String)
    case assetNotFound(UInt64)
    case pinningFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCID(let message):
            return "Invalid CID: \(message)"
        case .invalidMetadata(let message):
            return "Invalid metadata: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .notAuthorized(let message):
            return "Not authorized: \(message)"
        case .assetNotFound(let id):
            return "Asset not found: \(id)"
        case .pinningFailed(let message):
            return "Pinning failed: \(message)"
        }
    }
}
