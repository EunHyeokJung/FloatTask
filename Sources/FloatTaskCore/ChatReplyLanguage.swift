import Foundation

public enum ChatReplyLanguage: String, CaseIterable, Sendable {
    case korean = "ko"
    case english = "en"

    public var title: String {
        switch self {
        case .korean: "Korean"
        case .english: "English"
        }
    }

    var promptInstruction: String {
        "Answer in concise, neutral \(title). Preserve project names, task titles, and quoted user content in their original language."
    }

    public var noChangesReply: String {
        self == .korean ? "처리할 변경이 없습니다." : "No changes to apply."
    }

    public var stoppedReply: String {
        self == .korean ? "응답을 중지했습니다." : "Response stopped."
    }

    func actionSummary(_ type: CodexTaskAction.ActionType, title: String, completed: Bool = false) -> String {
        let action: String
        switch type {
        case .addProject: action = self == .korean ? "프로젝트 추가" : "Project added"
        case .renameProject: action = self == .korean ? "프로젝트 수정" : "Project renamed"
        case .deleteProject: action = self == .korean ? "프로젝트 삭제" : "Project deleted"
        case .addTask: action = self == .korean ? "작업 추가" : "Task added"
        case .renameTask: action = self == .korean ? "작업 수정" : "Task renamed"
        case .setTaskCompletion:
            action = self == .korean
                ? (completed ? "작업 완료" : "작업 재개")
                : (completed ? "Task completed" : "Task reopened")
        case .deleteTask: action = self == .korean ? "작업 삭제" : "Task deleted"
        }
        return "\(action) · \(title)"
    }
}
