import Foundation

struct NotesStore {
    private let fileManager: FileManager
    private let appDirectoryName: String
    private let fileName: String

    init(
        fileManager: FileManager = .default,
        appDirectoryName: String = "TopMemo",
        fileName: String = "notes.json"
    ) {
        self.fileManager = fileManager
        self.appDirectoryName = appDirectoryName
        self.fileName = fileName
    }

    func load() throws -> [MemoItem] {
        let fileURL = try storageFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        return try decodeNotes(from: fileURL)
    }

    func save(_ notes: [MemoItem]) throws {
        let fileURL = try storageFileURL()
        let directoryURL = fileURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let data = try JSONEncoder.memoEncoder.encode(notes)
        try data.write(to: fileURL, options: .atomic)
    }

    func export(_ notes: [MemoItem]) throws -> URL {
        let downloadsURL = try fileManager.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportURL = downloadsURL.appendingPathComponent(Self.exportFileName(for: Date()))
        let payload = NotesBackupPayload(notes: notes)
        let data = try JSONEncoder.memoEncoder.encode(payload)

        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }

    func restore(from fileURL: URL) throws -> [MemoItem] {
        let didAccessSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()

        defer {
            if didAccessSecurityScopedResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return try decodeNotes(from: fileURL)
    }

    func storageFileURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent(appDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private func decodeNotes(from fileURL: URL) throws -> [MemoItem] {
        let data = try Data(contentsOf: fileURL)

        guard !data.isEmpty else {
            return []
        }

        if let payload = try? JSONDecoder.memoDecoder.decode(NotesBackupPayload.self, from: data) {
            guard payload.schemaVersion == NotesBackupPayload.currentSchemaVersion else {
                throw NotesStoreError.unsupportedBackupVersion(payload.schemaVersion)
            }

            return payload.notes
        }

        if let notes = try? JSONDecoder.memoDecoder.decode([MemoItem].self, from: data) {
            return notes
        }

        throw NotesStoreError.invalidBackupFile
    }
}

private extension NotesStore {
    static func exportFileName(for date: Date) -> String {
        "topmemo-notes-\(exportDateFormatter.string(from: date)).json"
    }

    static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private struct NotesBackupPayload: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let notes: [MemoItem]

    init(
        schemaVersion: Int = currentSchemaVersion,
        exportedAt: Date = Date(),
        notes: [MemoItem]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.notes = notes
    }
}

private enum NotesStoreError: LocalizedError {
    case invalidBackupFile
    case unsupportedBackupVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidBackupFile:
            return "TopMemo에서 내보낸 JSON 백업 파일이 아니어서 복원할 수 없습니다."
        case .unsupportedBackupVersion(let version):
            return "이 백업 파일 버전(\(version))은 현재 앱에서 지원하지 않습니다."
        }
    }
}

private extension JSONEncoder {
    static var memoEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var memoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
