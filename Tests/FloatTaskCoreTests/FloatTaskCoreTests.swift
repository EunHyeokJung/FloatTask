import Foundation
import XCTest
@testable import FloatTaskCore

final class FloatTaskCoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FloatTaskTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directory.appendingPathComponent("tasks.json")
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    func testStoreCreatesStarterDataAndPersistsMutation() throws {
        let store = try TaskFileStore(fileURL: fileURL)
        try store.ensureExists()

        let initial = try store.load()
        XCTAssertEqual(initial.projects.count, 1)
        XCTAssertEqual(initial.projects[0].tasks.count, 2)

        let projectID = initial.projects[0].id
        let updated = try store.update { database in
            _ = try database.addTask(projectID: projectID, title: "Write tests")
        }

        XCTAssertEqual(updated.revision, initial.revision + 1)
        XCTAssertEqual(try store.load().projects[0].tasks.last?.title, "Write tests")
    }

    func testTaskLifecycleAndCompletedOrdering() throws {
        var database = TaskDatabase(projects: [TaskProject(title: "Build")])
        let projectID = database.projects[0].id
        let first = try database.addTask(projectID: projectID, title: "First")
        let second = try database.addTask(projectID: projectID, title: "Second")

        try database.renameTask(id: second.id, title: "Renamed")
        try database.setTaskCompletion(id: first.id, completed: true)
        database.normalize()

        XCTAssertEqual(database.projects[0].tasks.map(\.title), ["Renamed", "First"])
        XCTAssertTrue(database.projects[0].tasks[1].isCompleted)

        try database.deleteTask(id: second.id)
        XCTAssertEqual(database.projects[0].tasks.map(\.id), [first.id])
    }

    func testTaskCanBeInsertedAfterAnExistingTask() throws {
        var database = TaskDatabase(projects: [TaskProject(title: "Build")])
        let projectID = database.projects[0].id
        let first = try database.addTask(projectID: projectID, title: "First")
        _ = try database.addTask(projectID: projectID, title: "Third")

        let second = try database.addTask(
            projectID: projectID,
            title: "Second",
            afterTaskID: first.id
        )
        database.normalize()

        XCTAssertEqual(database.projects[0].tasks.map(\.title), ["First", "Second", "Third"])
        XCTAssertEqual(database.projects[0].tasks.map(\.sortOrder), [0, 1, 2])
        XCTAssertEqual(database.projects[0].tasks[1].id, second.id)
    }

    func testUniqueIDPrefixResolution() throws {
        let database = TaskDatabase.starter
        let projectID = database.projects[0].id
        let prefix = String(projectID.uuidString.prefix(8))
        XCTAssertEqual(try database.projectID(matching: prefix), projectID)
        XCTAssertThrowsError(try database.projectID(matching: "missing"))
    }

    func testEmptyTitlesAreRejected() throws {
        var database = TaskDatabase.starter
        XCTAssertThrowsError(try database.addProject(title: "   "))
        XCTAssertThrowsError(try database.addTask(projectID: database.projects[0].id, title: "\n"))
    }

    func testGoogleSyncUploadsUnmappedLocalData() async throws {
        let store = try TaskFileStore(fileURL: fileURL)
        try store.ensureExists()
        var createdTaskCount = 0

        MockURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"
            let body: String
            switch (method, path) {
            case ("GET", "/tasks/v1/users/@me/lists"):
                body = #"{"items":[]}"#
            case ("POST", "/tasks/v1/users/@me/lists"):
                body = #"{"id":"google-list","title":"Project"}"#
            case ("GET", "/tasks/v1/lists/google-list/tasks"):
                body = #"{"items":[]}"#
            case ("POST", "/tasks/v1/lists/google-list/tasks"):
                createdTaskCount += 1
                body = "{\"id\":\"google-task-\(createdTaskCount)\",\"title\":\"Task\",\"status\":\"needsAction\",\"updated\":\"2026-09-14T05:00:00.000Z\"}"
            default:
                XCTFail("Unexpected request: \(method) \(path)")
                body = #"{}"#
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = try GoogleTasksClient(accessToken: "test-token", session: session)
        let summary = try await client.sync(store: store)
        let synced = try store.load()

        XCTAssertEqual(summary.listsCreated, 1)
        XCTAssertEqual(summary.tasksUploaded, 2)
        XCTAssertEqual(synced.projects[0].googleTaskListID, "google-list")
        XCTAssertEqual(synced.projects[0].tasks.compactMap(\.googleTaskID).count, 2)
        XCTAssertNotNil(synced.lastGoogleSyncAt)
    }

    func testCodexActionsCreateProjectThenTaskByTitle() throws {
        var database = TaskDatabase(projects: [])
        let actions = [
            CodexTaskAction(type: .addProject, title: "Launch"),
            CodexTaskAction(type: .addTask, projectTitle: "Launch", title: "Write brief")
        ]

        let summaries = try CodexTaskActionApplier.apply(
            actions,
            to: &database,
            originalRequest: "Launch 프로젝트 만들고 Write brief 작업 추가"
        )

        XCTAssertEqual(database.projects.map(\.title), ["Launch"])
        XCTAssertEqual(database.projects[0].tasks.map(\.title), ["Write brief"])
        XCTAssertEqual(summaries, ["Project added · Launch", "Task added · Write brief"])
    }

    func testAppliedChangesReplaceProposalReply() {
        let displayText = CodexTaskReplyFormatter.format(
            "프로젝트 추가를 제안합니다.",
            appliedChanges: ["Project added · Launch"]
        )

        XCTAssertEqual(displayText, "Project added · Launch")
        XCTAssertFalse(displayText.contains("제안"))
    }

    func testEmptyReplyUsesEnglishFallback() {
        XCTAssertEqual(CodexTaskReplyFormatter.format("  \n", appliedChanges: []), "No changes to apply.")
    }

    func testKoreanReplyFallbackAndActionSummaries() throws {
        XCTAssertEqual(CodexTaskReplyFormatter.format("", appliedChanges: [], replyLanguage: .korean), "처리할 변경이 없습니다.")
        XCTAssertEqual(ChatReplyLanguage.korean.stoppedReply, "응답을 중지했습니다.")
        XCTAssertEqual(ChatReplyLanguage.english.stoppedReply, "Response stopped.")

        let examples: [(CodexTaskAction.ActionType, String)] = [
            (.addProject, "프로젝트 추가"), (.renameProject, "프로젝트 수정"), (.deleteProject, "프로젝트 삭제"),
            (.addTask, "작업 추가"), (.renameTask, "작업 수정"), (.deleteTask, "작업 삭제")
        ]
        for (type, phrase) in examples {
            XCTAssertEqual(ChatReplyLanguage.korean.actionSummary(type, title: "Launch 발표"), "\(phrase) · Launch 발표")
        }
        XCTAssertEqual(ChatReplyLanguage.korean.actionSummary(.setTaskCompletion, title: "발표", completed: true), "작업 완료 · 발표")
        XCTAssertEqual(ChatReplyLanguage.korean.actionSummary(.setTaskCompletion, title: "발표", completed: false), "작업 재개 · 발표")

        var database = TaskDatabase(projects: [])
        let summaries = try CodexTaskActionApplier.apply(
            [.init(type: .addProject, title: "Launch"), .init(type: .addTask, projectTitle: "Launch", title: "발표")],
            to: &database, originalRequest: "Launch 프로젝트와 발표 작업 추가", replyLanguage: .korean
        )
        XCTAssertEqual(summaries, ["프로젝트 추가 · Launch", "작업 추가 · 발표"])
        XCTAssertEqual(database.projects[0].tasks[0].title, "발표")
        XCTAssertEqual(CodexTaskReplyFormatter.format("Ignored", appliedChanges: summaries, replyLanguage: .korean), summaries.joined(separator: "\n"))
    }

    func testSelectedReplyLanguageReachesEveryRequest() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for language in ChatReplyLanguage.allCases {
            let executable = directory.appendingPathComponent("language-\(language.rawValue)-codex")
            let reply = language == .korean ? "작업을 확인했습니다." : "Tasks reviewed."
            let script = """
            #!/bin/sh
            response_file=""
            while [ "$#" -gt 0 ]; do
              if [ "$1" = "--output-last-message" ]; then
                shift
                response_file="$1"
              fi
              shift
            done
            /usr/bin/grep -Fq 'Answer in concise, neutral \(language.title).' || exit 1
            /usr/bin/printf '%s' '{"reply":"\(reply)","actions":[]}' > "$response_file"
            """
            try script.write(to: executable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            let agent = CodexTaskAgent(timeout: 5, environment: ["FLOATTASK_CODEX_PATH": executable.path])
            let response = try await agent.respond(
                to: "프로젝트 확인", history: [.init(role: "assistant", content: "Previous English reply")],
                database: .starter, replyLanguage: language
            )
            XCTAssertEqual(response.reply, reply)
        }
    }

    func testEnglishActionSummariesPreserveUserTitles() throws {
        var database = TaskDatabase(projects: [])
        func apply(_ actions: [CodexTaskAction]) throws -> [String] {
            try CodexTaskActionApplier.apply(actions, to: &database, originalRequest: "추가 수정 완료 재개 삭제")
        }

        XCTAssertEqual(try apply([.init(type: .addProject, title: "기획")]), ["Project added · 기획"])
        let projectID = database.projects[0].id.uuidString
        XCTAssertEqual(try apply([.init(type: .renameProject, projectId: projectID, title: "출시")]), ["Project renamed · 출시"])
        XCTAssertEqual(try apply([.init(type: .addTask, projectId: projectID, title: "초안")]), ["Task added · 초안"])
        let taskID = database.projects[0].tasks[0].id.uuidString
        XCTAssertEqual(try apply([.init(type: .renameTask, taskId: taskID, title: "검토")]), ["Task renamed · 검토"])
        XCTAssertEqual(try apply([.init(type: .setTaskCompletion, taskId: taskID, completed: true)]), ["Task completed · 검토"])
        XCTAssertEqual(try apply([.init(type: .setTaskCompletion, taskId: taskID, completed: false)]), ["Task reopened · 검토"])
        XCTAssertEqual(database.projects[0].title, "출시")
        XCTAssertEqual(database.projects[0].tasks[0].title, "검토")
        XCTAssertEqual(try apply([.init(type: .deleteTask, taskId: taskID)]), ["Task deleted · 검토"])
        XCTAssertEqual(try apply([.init(type: .deleteProject, projectId: projectID)]), ["Project deleted · 출시"])
    }

    func testCodexDeletionRequiresExplicitIntent() throws {
        var database = TaskDatabase.starter
        let projectID = database.projects[0].id.uuidString

        XCTAssertThrowsError(
            try CodexTaskActionApplier.apply(
                [CodexTaskAction(type: .deleteProject, projectId: projectID)],
                to: &database,
                originalRequest: "Project 정리해줘"
            )
        )
        XCTAssertEqual(database.projects.count, 1)
    }

    func testCodexActionBatchIsNotPersistedWhenValidationFails() throws {
        let store = try TaskFileStore(fileURL: fileURL)
        try store.ensureExists()
        let before = try store.load()
        let projectID = before.projects[0].id.uuidString
        let actions = [
            CodexTaskAction(type: .renameProject, projectId: projectID, title: "Renamed"),
            CodexTaskAction(type: .renameTask, taskId: "missing", title: "Invalid")
        ]

        XCTAssertThrowsError(
            try store.update { database in
                _ = try CodexTaskActionApplier.apply(
                    actions,
                    to: &database,
                    originalRequest: "프로젝트와 작업 이름 변경"
                )
            }
        )

        XCTAssertEqual(try store.load(), before)
    }

    func testCodexRequestCancellationStopsRunningProcess() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executableURL = directory.appendingPathComponent("slow-codex")
        try "#!/bin/sh\n/bin/sleep 10\n".write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)
        let agent = CodexTaskAgent(
            timeout: 30,
            environment: ["FLOATTASK_CODEX_PATH": executableURL.path]
        )
        let request = Task {
            try await agent.respond(to: "프로젝트 확인", history: [], database: .starter)
        }

        try await Task.sleep(for: .milliseconds(150))
        request.cancel()

        do {
            _ = try await request.value
            XCTFail("Cancelled request unexpectedly completed")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testCodexJSONLEventsDriveRealActivityStates() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executableURL = directory.appendingPathComponent("event-codex")
        let script = #"""
        #!/bin/sh
        response_file=""
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--output-last-message" ]; then
            shift
            response_file="$1"
          fi
          shift
        done
        /usr/bin/grep -q 'Answer in concise, neutral English' || exit 1
        /usr/bin/printf '%s\n' '{"type":"turn.started"}'
        /usr/bin/printf '%s\n' '{"type":"item.started","item":{"type":"mcp_tool_call"}}'
        /usr/bin/printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution"}}'
        /usr/bin/printf '%s' '{"reply":"Done","actions":[]}' > "$response_file"
        """#
        try script.write(to: executableURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        let recorder = ActivityRecorder()
        let agent = CodexTaskAgent(
            timeout: 5,
            environment: ["FLOATTASK_CODEX_PATH": executableURL.path]
        )
        let response = try await agent.respond(
            to: "프로젝트 확인",
            history: [],
            database: .starter,
            onActivity: { activity in recorder.record(activity) }
        )

        XCTAssertEqual(response.reply, "Done")
        XCTAssertEqual(recorder.values, [.thinking, .looking, .working])
    }
}

private final class ActivityRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var activities: [CodexTaskAgentActivity] = []

    var values: [CodexTaskAgentActivity] {
        lock.lock()
        defer { lock.unlock() }
        return activities
    }

    func record(_ activity: CodexTaskAgentActivity) {
        lock.lock()
        activities.append(activity)
        lock.unlock()
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
