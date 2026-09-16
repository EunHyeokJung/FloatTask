import Darwin
import Foundation
import FloatTaskCore

@main
struct FloatTaskCLI {
    static func main() async {
        do {
            var arguments = Arguments(Array(CommandLine.arguments.dropFirst()))
            let dataFile = arguments.takeOption("--data-file").map {
                URL(fileURLWithPath: $0).standardizedFileURL
            }
            let json = arguments.takeFlag("--json")
            let store = try TaskFileStore(fileURL: dataFile)
            try store.ensureExists()

            guard let scope = arguments.popFirst() else {
                printHelp()
                return
            }

            switch scope {
            case "help", "--help", "-h":
                printHelp()
            case "dump":
                try printJSON(store.load())
            case "projects", "project":
                try handleProjects(arguments: &arguments, store: store, json: json)
            case "tasks", "task":
                try handleTasks(arguments: &arguments, store: store, json: json)
            case "google":
                try await handleGoogle(arguments: &arguments, store: store, json: json)
            default:
                throw CLIError.usage("Unknown command: \(scope)")
            }
        } catch {
            fputs("floattaskctl: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func handleProjects(
        arguments: inout Arguments,
        store: TaskFileStore,
        json: Bool
    ) throws {
        let action = arguments.popFirst() ?? "list"
        switch action {
        case "list":
            let projects = try store.load().projects
            if json { try printJSON(projects) } else { printProjects(projects) }
        case "add":
            let title = try arguments.requiredOption("--title")
            var newID: UUID?
            let database = try store.update { newID = try $0.addProject(title: title).id }
            let project = database.projects.first { $0.id == newID }!
            if json { try printJSON(project) } else { print("\(project.id.uuidString)\t\(project.title)") }
        case "rename":
            guard let rawID = arguments.popFirst() else { throw CLIError.usage("Project ID is required") }
            let title = try arguments.requiredOption("--title")
            let before = try store.load()
            let id = try before.projectID(matching: rawID)
            let database = try store.update { try $0.renameProject(id: id, title: title) }
            let project = database.projects.first { $0.id == id }!
            if json { try printJSON(project) } else { print("\(project.id.uuidString)\t\(project.title)") }
        case "delete":
            guard let rawID = arguments.popFirst() else { throw CLIError.usage("Project ID is required") }
            let before = try store.load()
            let id = try before.projectID(matching: rawID)
            _ = try store.update { try $0.deleteProject(id: id) }
            print(json ? "{\"deleted\":\"\(id.uuidString)\"}" : id.uuidString)
        default:
            throw CLIError.usage("Unknown project action: \(action)")
        }
    }

    private static func handleTasks(
        arguments: inout Arguments,
        store: TaskFileStore,
        json: Bool
    ) throws {
        let action = arguments.popFirst() ?? "list"
        switch action {
        case "list":
            let database = try store.load()
            if let rawProjectID = arguments.takeOption("--project") {
                let id = try database.projectID(matching: rawProjectID)
                let project = database.projects.first { $0.id == id }!
                if json { try printJSON(project.tasks) } else { printTaskRows(project.tasks) }
            } else if json {
                try printJSON(database.projects)
            } else {
                printProjects(database.projects)
            }
        case "add":
            let rawProjectID = try arguments.requiredOption("--project")
            let title = try arguments.requiredOption("--title")
            let before = try store.load()
            let projectID = try before.projectID(matching: rawProjectID)
            var newID: UUID?
            let database = try store.update {
                newID = try $0.addTask(projectID: projectID, title: title).id
            }
            let task = database.projects.flatMap(\.tasks).first { $0.id == newID }!
            if json { try printJSON(task) } else { print("\(task.id.uuidString)\t\(task.title)") }
        case "rename":
            guard let rawID = arguments.popFirst() else { throw CLIError.usage("Task ID is required") }
            let title = try arguments.requiredOption("--title")
            let before = try store.load()
            let id = try before.taskID(matching: rawID)
            let database = try store.update { try $0.renameTask(id: id, title: title) }
            let task = database.projects.flatMap(\.tasks).first { $0.id == id }!
            if json { try printJSON(task) } else { print("\(task.id.uuidString)\t\(task.title)") }
        case "complete", "reopen":
            guard let rawID = arguments.popFirst() else { throw CLIError.usage("Task ID is required") }
            let before = try store.load()
            let id = try before.taskID(matching: rawID)
            let database = try store.update {
                try $0.setTaskCompletion(id: id, completed: action == "complete")
            }
            let task = database.projects.flatMap(\.tasks).first { $0.id == id }!
            if json { try printJSON(task) } else { print("\(task.id.uuidString)\t\(task.isCompleted ? "done" : "open")") }
        case "delete":
            guard let rawID = arguments.popFirst() else { throw CLIError.usage("Task ID is required") }
            let before = try store.load()
            let id = try before.taskID(matching: rawID)
            _ = try store.update { try $0.deleteTask(id: id) }
            print(json ? "{\"deleted\":\"\(id.uuidString)\"}" : id.uuidString)
        default:
            throw CLIError.usage("Unknown task action: \(action)")
        }
    }

    private static func handleGoogle(
        arguments: inout Arguments,
        store: TaskFileStore,
        json: Bool
    ) async throws {
        let action = arguments.popFirst() ?? "sync"
        guard action == "sync" else { throw CLIError.usage("Unknown Google action: \(action)") }
        let token = arguments.takeOption("--token") ?? ProcessInfo.processInfo.environment["GOOGLE_TASKS_ACCESS_TOKEN"]
        guard let token else { throw GoogleTasksError.missingAccessToken }
        let client = try GoogleTasksClient(accessToken: token)
        let summary = try await client.sync(store: store)
        if json {
            try printJSON(summary)
        } else {
            print("lists \(summary.listsDiscovered), created \(summary.listsCreated), downloaded \(summary.tasksDownloaded), uploaded \(summary.tasksUploaded), updated \(summary.tasksUpdatedRemotely)")
        }
    }

    private static func printProjects(_ projects: [TaskProject]) {
        for project in projects {
            print("\(project.title)\t\(project.id.uuidString)")
            printTaskRows(project.tasks)
        }
    }

    private static func printTaskRows(_ tasks: [TaskItem]) {
        for task in tasks {
            print("  [\(task.isCompleted ? "x" : " ")] \(task.title)\t\(task.id.uuidString)")
        }
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        print(try TaskFileStore.prettyJSON(value))
    }

    private static func printHelp() {
        print("""
        floattaskctl — FloatTask agent interface

        floattaskctl projects list [--json]
        floattaskctl project add --title <title> [--json]
        floattaskctl project rename <id> --title <title> [--json]
        floattaskctl project delete <id> [--json]
        floattaskctl tasks list [--project <id>] [--json]
        floattaskctl task add --project <id> --title <title> [--json]
        floattaskctl task rename <id> --title <title> [--json]
        floattaskctl task complete|reopen|delete <id> [--json]
        floattaskctl google sync [--token <access-token>] [--json]
        floattaskctl dump

        Global: --data-file <path>
        """)
    }
}

private struct Arguments {
    private var values: [String]

    init(_ values: [String]) { self.values = values }

    mutating func popFirst() -> String? {
        guard !values.isEmpty else { return nil }
        return values.removeFirst()
    }

    mutating func takeFlag(_ flag: String) -> Bool {
        guard let index = values.firstIndex(of: flag) else { return false }
        values.remove(at: index)
        return true
    }

    mutating func takeOption(_ option: String) -> String? {
        guard let index = values.firstIndex(of: option), values.indices.contains(index + 1) else { return nil }
        values.remove(at: index)
        return values.remove(at: index)
    }

    mutating func requiredOption(_ option: String) throws -> String {
        guard let value = takeOption(option) else { throw CLIError.usage("\(option) is required") }
        return value
    }
}

private enum CLIError: LocalizedError {
    case usage(String)

    var errorDescription: String? {
        switch self {
        case .usage(let message): return message
        }
    }
}
