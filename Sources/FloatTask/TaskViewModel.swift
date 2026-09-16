import Foundation
import FloatTaskCore

@MainActor
final class TaskViewModel: ObservableObject {
    @Published private(set) var database: TaskDatabase = .starter
    @Published private(set) var errorMessage: String?

    private let store: TaskFileStore
    private var pollTimer: Timer?

    init() {
        do {
            let store = try TaskFileStore()
            self.store = store
            try store.ensureExists()
            self.database = try store.load()
        } catch {
            fatalError("Unable to initialize FloatTask: \(error.localizedDescription)")
        }
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    func addProject(title: String = "Project") -> UUID? {
        var createdID: UUID?
        mutate { database in
            createdID = try database.addProject(title: title).id
        }
        return createdID
    }

    func renameProject(_ id: UUID, title: String) {
        mutate { try $0.renameProject(id: id, title: title) }
    }

    func deleteProject(_ id: UUID) {
        mutate { try $0.deleteProject(id: id) }
    }

    func addTask(projectID: UUID, title: String, afterTaskID: UUID? = nil) -> UUID? {
        var createdID: UUID?
        mutate { database in
            createdID = try database.addTask(
                projectID: projectID,
                title: title,
                afterTaskID: afterTaskID
            ).id
        }
        return createdID
    }

    func renameTask(_ id: UUID, title: String) {
        mutate { try $0.renameTask(id: id, title: title) }
    }

    func setTaskCompletion(_ id: UUID, completed: Bool) {
        mutate { try $0.setTaskCompletion(id: id, completed: completed) }
    }

    func deleteTask(_ id: UUID) {
        mutate { try $0.deleteTask(id: id) }
    }

    func clearError() {
        errorMessage = nil
    }

    func applyCodexActions(
        _ actions: [CodexTaskAction],
        originalRequest: String,
        replyLanguage: ChatReplyLanguage
    ) throws -> [String] {
        var summaries: [String] = []
        do {
            database = try store.update { database in
                summaries = try CodexTaskActionApplier.apply(
                    actions,
                    to: &database,
                    originalRequest: originalRequest,
                    replyLanguage: replyLanguage
                )
            }
            errorMessage = nil
            return summaries
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func mutate(_ mutation: (inout TaskDatabase) throws -> Void) {
        do {
            database = try store.update(mutation)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reloadIfChanged() }
        }
    }

    private func reloadIfChanged() {
        do {
            let fresh = try store.load()
            if fresh.revision != database.revision {
                database = fresh
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
