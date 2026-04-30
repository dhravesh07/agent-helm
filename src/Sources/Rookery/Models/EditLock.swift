import Foundation
import CryptoKit

/// Snapshot of a file's identity at the moment editing was enabled.
/// Used to detect concurrent writes (e.g., a running agent editing the
/// same file) before save-back overwrites them blindly.
struct EditLockBaseline: Equatable {
    let path: String
    let size: UInt64
    let mtime: Date?
    let sha256: String
    let lockedAt: Date

    static func make(path: String, contents: Data, meta: RemoteFileMetadata) -> EditLockBaseline {
        let digest = SHA256.hash(data: contents)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return EditLockBaseline(
            path: path,
            size: meta.size,
            mtime: meta.mtime,
            sha256: hex,
            lockedAt: Date()
        )
    }
}

enum EditLockState: Equatable {
    case readOnly
    case locked(EditLockBaseline)
}

enum SaveConflict: Equatable {
    /// Remote file changed while we held the lock. The user needs to
    /// decide: overwrite, reload-and-redo, or open a 3-way diff.
    case remoteDrift(
        baseline: EditLockBaseline,
        currentSize: UInt64,
        currentMtime: Date?,
        currentSha256: String
    )
}
