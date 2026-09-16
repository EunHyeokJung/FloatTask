import Darwin
import Foundation

public final class TaskFileStore: @unchecked Sendable {
    public let fileURL: URL
    private let lockURL: URL

    public init(fileURL: URL? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else if let override = environment["FLOATTASK_DATA_FILE"], !override.isEmpty {
            self.fileURL = URL(fileURLWithPath: override).standardizedFileURL
        } else {
            guard let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw TaskDataError.invalidStore("Application Support directory is unavailable")
            }
            self.fileURL = applicationSupport
                .appendingPathComponent("FloatTask", isDirectory: true)
                .appendingPathComponent("tasks.json", isDirectory: false)
        }
        self.lockURL = self.fileURL.appendingPathExtension("lock")
    }

    public func ensureExists() throws {
        try withLock(exclusive: true) {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try writeUnlocked(.starter)
            }
        }
    }

    public func load() throws -> TaskDatabase {
        try withLock(exclusive: false) {
            try loadUnlocked()
        }
    }

    @discardableResult
    public func update(_ mutation: (inout TaskDatabase) throws -> Void) throws -> TaskDatabase {
        try withLock(exclusive: true) {
            var database = try loadUnlocked()
            try mutation(&database)
            database.normalize()
            database.revision += 1
            try writeUnlocked(database)
            return database
        }
    }

    public static func prettyJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = makeEncoder(pretty: true)
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TaskDataError.invalidStore("Unable to encode UTF-8 JSON")
        }
        return string
    }

    private func loadUnlocked() throws -> TaskDatabase {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .starter }
        do {
            let data = try Data(contentsOf: fileURL)
            return try Self.makeDecoder().decode(TaskDatabase.self, from: data)
        } catch {
            throw TaskDataError.invalidStore(error.localizedDescription)
        }
    }

    private func writeUnlocked(_ database: TaskDatabase) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder(pretty: true).encode(database)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func withLock<T>(exclusive: Bool, _ operation: () throws -> T) throws -> T {
        let directory = lockURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw TaskDataError.invalidStore("Unable to open lock file")
        }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, exclusive ? LOCK_EX : LOCK_SH) == 0 else {
            throw TaskDataError.invalidStore("Unable to lock task store")
        }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }

    private static func makeEncoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : []
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
