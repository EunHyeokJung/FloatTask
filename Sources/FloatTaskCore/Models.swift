import Foundation

public struct TaskDatabase: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var revision: Int
    public var projects: [TaskProject]
    public var lastGoogleSyncAt: Date?

    public init(
        schemaVersion: Int = 1,
        revision: Int = 0,
        projects: [TaskProject] = [],
        lastGoogleSyncAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.projects = projects
        self.lastGoogleSyncAt = lastGoogleSyncAt
    }

    public static var starter: TaskDatabase {
        let now = Date()
        return TaskDatabase(projects: [
            TaskProject(
                title: "Project",
                tasks: [
                    TaskItem(title: "Task", sortOrder: 0, createdAt: now, updatedAt: now),
                    TaskItem(title: "Task", sortOrder: 1, createdAt: now, updatedAt: now)
                ],
                sortOrder: 0,
                createdAt: now,
                updatedAt: now
            )
        ])
    }

    public mutating func normalize() {
        projects.sort { $0.sortOrder == $1.sortOrder ? $0.createdAt < $1.createdAt : $0.sortOrder < $1.sortOrder }
        for projectIndex in projects.indices {
            projects[projectIndex].sortOrder = projectIndex
            projects[projectIndex].tasks.sort {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
            for taskIndex in projects[projectIndex].tasks.indices {
                projects[projectIndex].tasks[taskIndex].sortOrder = taskIndex
            }
        }
    }
}

public struct TaskProject: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var tasks: [TaskItem]
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var googleTaskListID: String?

    public init(
        id: UUID = UUID(),
        title: String,
        tasks: [TaskItem] = [],
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        googleTaskListID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.tasks = tasks
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.googleTaskListID = googleTaskListID
    }
}

public struct TaskItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var googleTaskID: String?
    public var googleUpdatedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        googleTaskID: String? = nil,
        googleUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.googleTaskID = googleTaskID
        self.googleUpdatedAt = googleUpdatedAt
    }
}

public enum TaskDataError: LocalizedError, Equatable {
    case projectNotFound(String)
    case taskNotFound(String)
    case ambiguousID(String)
    case emptyTitle
    case invalidStore(String)

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let id): return "Project not found: \(id)"
        case .taskNotFound(let id): return "Task not found: \(id)"
        case .ambiguousID(let id): return "ID prefix is ambiguous: \(id)"
        case .emptyTitle: return "Title must not be empty"
        case .invalidStore(let reason): return "Task store is invalid: \(reason)"
        }
    }
}

public extension TaskDatabase {
    @discardableResult
    mutating func addProject(title: String) throws -> TaskProject {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskDataError.emptyTitle }
        let project = TaskProject(title: cleanTitle, sortOrder: projects.count)
        projects.append(project)
        return project
    }

    mutating func renameProject(id: UUID, title: String) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskDataError.emptyTitle }
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw TaskDataError.projectNotFound(id.uuidString)
        }
        projects[index].title = cleanTitle
        projects[index].updatedAt = Date()
    }

    mutating func deleteProject(id: UUID) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw TaskDataError.projectNotFound(id.uuidString)
        }
        projects.remove(at: index)
    }

    @discardableResult
    mutating func addTask(
        projectID: UUID,
        title: String,
        afterTaskID: UUID? = nil
    ) throws -> TaskItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskDataError.emptyTitle }
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectID }) else {
            throw TaskDataError.projectNotFound(projectID.uuidString)
        }

        let insertionIndex: Int
        if let afterTaskID {
            guard let anchorIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == afterTaskID }) else {
                throw TaskDataError.taskNotFound(afterTaskID.uuidString)
            }
            insertionIndex = anchorIndex + 1
        } else {
            insertionIndex = projects[projectIndex].tasks.count
        }

        let task = TaskItem(title: cleanTitle, sortOrder: insertionIndex)
        projects[projectIndex].tasks.insert(task, at: insertionIndex)
        for taskIndex in projects[projectIndex].tasks.indices {
            projects[projectIndex].tasks[taskIndex].sortOrder = taskIndex
        }
        projects[projectIndex].updatedAt = Date()
        return task
    }

    mutating func renameTask(id: UUID, title: String) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskDataError.emptyTitle }
        let location = try taskLocation(id: id)
        projects[location.project].tasks[location.task].title = cleanTitle
        projects[location.project].tasks[location.task].updatedAt = Date()
        projects[location.project].updatedAt = Date()
    }

    mutating func setTaskCompletion(id: UUID, completed: Bool) throws {
        let location = try taskLocation(id: id)
        projects[location.project].tasks[location.task].isCompleted = completed
        projects[location.project].tasks[location.task].completedAt = completed ? Date() : nil
        projects[location.project].tasks[location.task].updatedAt = Date()
        projects[location.project].updatedAt = Date()
    }

    mutating func deleteTask(id: UUID) throws {
        let location = try taskLocation(id: id)
        projects[location.project].tasks.remove(at: location.task)
        projects[location.project].updatedAt = Date()
    }

    func projectID(matching value: String) throws -> UUID {
        try uniqueID(value, in: projects.map(\.id), missing: TaskDataError.projectNotFound(value))
    }

    func taskID(matching value: String) throws -> UUID {
        try uniqueID(value, in: projects.flatMap { $0.tasks.map(\.id) }, missing: TaskDataError.taskNotFound(value))
    }

    private func taskLocation(id: UUID) throws -> (project: Int, task: Int) {
        for projectIndex in projects.indices {
            if let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == id }) {
                return (projectIndex, taskIndex)
            }
        }
        throw TaskDataError.taskNotFound(id.uuidString)
    }

    private func uniqueID(_ value: String, in ids: [UUID], missing: TaskDataError) throws -> UUID {
        if let uuid = UUID(uuidString: value), ids.contains(uuid) { return uuid }
        let needle = value.lowercased()
        let matches = ids.filter { $0.uuidString.lowercased().hasPrefix(needle) }
        if matches.count == 1, let match = matches.first { return match }
        if matches.count > 1 { throw TaskDataError.ambiguousID(value) }
        throw missing
    }
}
