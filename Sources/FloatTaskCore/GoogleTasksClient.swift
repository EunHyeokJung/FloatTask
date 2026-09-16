import Foundation

public struct GoogleSyncSummary: Codable, Equatable, Sendable {
    public var listsDiscovered = 0
    public var listsCreated = 0
    public var tasksDownloaded = 0
    public var tasksUploaded = 0
    public var tasksUpdatedRemotely = 0

    public init() {}
}

public enum GoogleTasksError: LocalizedError {
    case invalidResponse
    case http(status: Int, message: String)
    case missingAccessToken
    case concurrentLocalChange

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Google Tasks returned an invalid response"
        case .http(let status, let message):
            return "Google Tasks request failed (\(status)): \(message)"
        case .missingAccessToken:
            return "Google Tasks access token is required"
        case .concurrentLocalChange:
            return "Local tasks changed during sync; run sync again"
        }
    }
}

public final class GoogleTasksClient: @unchecked Sendable {
    private let accessToken: String
    private let session: URLSession
    private let baseURL = URL(string: "https://tasks.googleapis.com/tasks/v1")!

    public init(accessToken: String, session: URLSession = .shared) throws {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw GoogleTasksError.missingAccessToken }
        self.accessToken = token
        self.session = session
    }

    public func sync(store: TaskFileStore) async throws -> GoogleSyncSummary {
        var database = try store.load()
        let originalRevision = database.revision
        var summary = GoogleSyncSummary()
        var remoteLists = try await listTaskLists()

        for projectIndex in database.projects.indices where database.projects[projectIndex].googleTaskListID == nil {
            let created = try await createTaskList(title: database.projects[projectIndex].title)
            database.projects[projectIndex].googleTaskListID = created.id
            remoteLists.append(created)
            summary.listsCreated += 1
        }

        for remoteList in remoteLists {
            summary.listsDiscovered += 1
            let projectIndex: Int
            if let existing = database.projects.firstIndex(where: { $0.googleTaskListID == remoteList.id }) {
                projectIndex = existing
            } else {
                database.projects.append(TaskProject(
                    title: remoteList.title,
                    sortOrder: database.projects.count,
                    googleTaskListID: remoteList.id
                ))
                projectIndex = database.projects.count - 1
            }

            let remoteTasks = try await listTasks(taskListID: remoteList.id)
            for remoteTask in remoteTasks where remoteTask.deleted != true {
                let remoteDate = Self.parseGoogleDate(remoteTask.updated) ?? .distantPast
                if let localIndex = database.projects[projectIndex].tasks.firstIndex(
                    where: { $0.googleTaskID == remoteTask.id }
                ) {
                    let local = database.projects[projectIndex].tasks[localIndex]
                    if local.updatedAt.timeIntervalSince(remoteDate) > 2 {
                        let updated = try await updateTask(
                            taskListID: remoteList.id,
                            taskID: remoteTask.id,
                            title: local.title,
                            completed: local.isCompleted
                        )
                        database.projects[projectIndex].tasks[localIndex].googleUpdatedAt =
                            Self.parseGoogleDate(updated.updated)
                        summary.tasksUpdatedRemotely += 1
                    } else {
                        database.projects[projectIndex].tasks[localIndex].title = remoteTask.title
                        database.projects[projectIndex].tasks[localIndex].isCompleted = remoteTask.status == "completed"
                        database.projects[projectIndex].tasks[localIndex].completedAt =
                            Self.parseGoogleDate(remoteTask.completed)
                        database.projects[projectIndex].tasks[localIndex].updatedAt = remoteDate
                        database.projects[projectIndex].tasks[localIndex].googleUpdatedAt = remoteDate
                        summary.tasksDownloaded += 1
                    }
                } else {
                    database.projects[projectIndex].tasks.append(TaskItem(
                        title: remoteTask.title,
                        isCompleted: remoteTask.status == "completed",
                        sortOrder: database.projects[projectIndex].tasks.count,
                        createdAt: remoteDate == .distantPast ? Date() : remoteDate,
                        updatedAt: remoteDate == .distantPast ? Date() : remoteDate,
                        completedAt: Self.parseGoogleDate(remoteTask.completed),
                        googleTaskID: remoteTask.id,
                        googleUpdatedAt: remoteDate == .distantPast ? nil : remoteDate
                    ))
                    summary.tasksDownloaded += 1
                }
            }

            for localIndex in database.projects[projectIndex].tasks.indices
            where database.projects[projectIndex].tasks[localIndex].googleTaskID == nil {
                let local = database.projects[projectIndex].tasks[localIndex]
                let created = try await createTask(
                    taskListID: remoteList.id,
                    title: local.title,
                    completed: local.isCompleted
                )
                database.projects[projectIndex].tasks[localIndex].googleTaskID = created.id
                database.projects[projectIndex].tasks[localIndex].googleUpdatedAt =
                    Self.parseGoogleDate(created.updated)
                summary.tasksUploaded += 1
            }
        }

        database.lastGoogleSyncAt = Date()
        _ = try store.update { current in
            guard current.revision == originalRevision else {
                throw GoogleTasksError.concurrentLocalChange
            }
            current = database
        }
        return summary
    }

    private func listTaskLists() async throws -> [GoogleTaskList] {
        var result: [GoogleTaskList] = []
        var pageToken: String?
        repeat {
            var query = [URLQueryItem(name: "maxResults", value: "100")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: GoogleTaskListPage = try await request(
                method: "GET",
                path: "/users/@me/lists",
                query: query
            )
            result.append(contentsOf: page.items ?? [])
            pageToken = page.nextPageToken
        } while pageToken != nil
        return result
    }

    private func listTasks(taskListID: String) async throws -> [GoogleTask] {
        var result: [GoogleTask] = []
        var pageToken: String?
        repeat {
            var query = [
                URLQueryItem(name: "maxResults", value: "100"),
                URLQueryItem(name: "showCompleted", value: "true"),
                URLQueryItem(name: "showHidden", value: "true")
            ]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            let page: GoogleTaskPage = try await request(
                method: "GET",
                path: "/lists/\(Self.pathComponent(taskListID))/tasks",
                query: query
            )
            result.append(contentsOf: page.items ?? [])
            pageToken = page.nextPageToken
        } while pageToken != nil
        return result
    }

    private func createTaskList(title: String) async throws -> GoogleTaskList {
        try await request(
            method: "POST",
            path: "/users/@me/lists",
            body: ["title": title]
        )
    }

    private func createTask(taskListID: String, title: String, completed: Bool) async throws -> GoogleTask {
        var body: [String: Any] = [
            "title": title,
            "status": completed ? "completed" : "needsAction"
        ]
        if completed { body["completed"] = Self.googleDate(Date()) }
        return try await request(
            method: "POST",
            path: "/lists/\(Self.pathComponent(taskListID))/tasks",
            jsonObject: body
        )
    }

    private func updateTask(
        taskListID: String,
        taskID: String,
        title: String,
        completed: Bool
    ) async throws -> GoogleTask {
        let body: [String: Any] = [
            "title": title,
            "status": completed ? "completed" : "needsAction",
            "completed": completed ? Self.googleDate(Date()) : NSNull()
        ]
        return try await request(
            method: "PATCH",
            path: "/lists/\(Self.pathComponent(taskListID))/tasks/\(Self.pathComponent(taskID))",
            jsonObject: body
        )
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: [String: String]? = nil
    ) async throws -> Response {
        let data = body.map { try? JSONEncoder().encode($0) } ?? nil
        return try await request(method: method, path: path, query: query, bodyData: data)
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        jsonObject: [String: Any]
    ) async throws -> Response {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        return try await request(method: method, path: path, query: query, bodyData: data)
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = query.isEmpty ? nil : query
        guard let url = components?.url else { throw GoogleTasksError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if bodyData != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleTasksError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleTasksError.http(status: http.statusCode, message: message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private static func pathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-._~")
        )) ?? value
    }

    private static func googleDate(_ date: Date) -> String {
        googleDateFormatter.string(from: date)
    }

    private static func parseGoogleDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return googleDateFormatter.date(from: value) ?? fallbackDateFormatter.date(from: value)
    }

    private static let googleDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct GoogleTaskListPage: Decodable {
    let items: [GoogleTaskList]?
    let nextPageToken: String?
}

private struct GoogleTaskPage: Decodable {
    let items: [GoogleTask]?
    let nextPageToken: String?
}

private struct GoogleTaskList: Codable {
    let id: String
    let title: String
}

private struct GoogleTask: Codable {
    let id: String
    let title: String
    let status: String?
    let updated: String?
    let completed: String?
    let deleted: Bool?
}
