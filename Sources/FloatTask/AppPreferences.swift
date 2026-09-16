import Combine
import FloatTaskCore
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private enum Key {
        static let showInMenuBar = "FloatTask.showInMenuBar"
        static let keepOnTop = "FloatTask.floats"
        static let replyLanguage = "FloatTask.chatReplyLanguage"
    }

    private let defaults: UserDefaults

    @Published var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: Key.showInMenuBar) }
    }
    @Published var keepOnTop: Bool {
        didSet { defaults.set(keepOnTop, forKey: Key.keepOnTop) }
    }
    @Published var replyLanguage: ChatReplyLanguage {
        didSet { defaults.set(replyLanguage.rawValue, forKey: Key.replyLanguage) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showInMenuBar = defaults.bool(forKey: Key.showInMenuBar)
        keepOnTop = defaults.object(forKey: Key.keepOnTop) == nil || defaults.bool(forKey: Key.keepOnTop)
        replyLanguage = defaults.string(forKey: Key.replyLanguage).flatMap(ChatReplyLanguage.init(rawValue:)) ?? .korean
    }
}
