import Foundation

enum ArchiveError: LocalizedError, Equatable {
    case invalidSelection(String)
    case invalidArchive
    case unsafePath(String)
    case duplicatePath(String)
    case passwordRequired
    case badPassword
    case missingVolumes(String)
    case damagedArchive(String)
    case permissionDenied
    case diskFull
    case cancelled
    case writeFailed(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidSelection(let detail): return detail
        case .invalidArchive: return "This file is not a readable RAR4 or RAR5 archive."
        case .unsafePath(let path): return "The archive contains an unsafe path: \(path)"
        case .duplicatePath(let path): return "The archive contains conflicting entries for \(path)."
        case .passwordRequired: return "A password is required to read or extract this archive."
        case .badPassword: return "The archive password is incorrect."
        case .missingVolumes(let detail): return detail
        case .damagedArchive(let detail): return detail
        case .permissionDenied: return "Unravel no longer has permission to read a required archive volume."
        case .diskFull: return "There is not enough free storage to extract the selected files."
        case .cancelled: return "Extraction cancelled."
        case .writeFailed(let detail): return "Unravel could not save the extracted data. \(detail)"
        case .readFailed(let detail): return detail
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .passwordRequired, .badPassword:
            return "Enter the password supplied by the archive sender, then try again."
        case .missingVolumes:
            return "Open the first volume together with every other volume, or grant the containing folder. For name.part1.rar, include all name.partN.rar files. For name.rar, include name.r00, name.r01, and any remaining numbered volumes."
        case .permissionDenied:
            return "Close the archive and select all volumes again so iOS can grant access for the entire operation."
        case .diskFull:
            return "Free some device storage or select fewer files, then try again."
        case .damagedArchive:
            return "Download the archive and all of its volumes again. A missing or altered volume can also cause this error."
        case .unsafePath, .duplicatePath:
            return "Nothing was exported. Ask the archive sender for a copy with safe, unique relative paths."
        case .cancelled:
            return "Partial temporary output was removed. You can extract again when ready."
        default:
            return nil
        }
    }

    static func map(_ error: Error, cancelled: Bool = false) -> ArchiveError {
        if let archiveError = error as? ArchiveError { return archiveError }
        if cancelled || error is CancellationError { return .cancelled }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteOutOfSpaceError, NSFileWriteVolumeReadOnlyError: return .diskFull
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError: return .permissionDenied
            case NSUserCancelledError: return .cancelled
            default: break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            if nsError.code == ENOSPC { return .diskFull }
            if nsError.code == EACCES || nsError.code == EPERM { return .permissionDenied }
        }
        if nsError.domain == "URKErrorDomain" {
            switch nsError.code {
            case 22: return .passwordRequired
            case 23: return .badPassword
            case 11, 12, 13, 14:
                return .damagedArchive("The archive is damaged, truncated, or uses an unsupported RAR structure.")
            case 15, 18, 101:
                return .missingVolumes("A required archive volume is missing or could not be opened.")
            case 102: return .cancelled
            case 16, 19: return .writeFailed(nsError.localizedDescription)
            default: break
            }
        }
        let text = (nsError.localizedDescription + " " + nsError.userInfo.description).lowercased()
        if text.contains("password") { return text.contains("bad") || text.contains("incorrect") ? .badPassword : .passwordRequired }
        if text.contains("space") || text.contains("disk full") { return .diskFull }
        if text.contains("permission") || text.contains("not permitted") { return .permissionDenied }
        if text.contains("crc") || text.contains("bad data") || text.contains("corrupt") {
            return .damagedArchive("The archive data failed its integrity check or is corrupted.")
        }
        return .readFailed(nsError.localizedDescription)
    }
}
