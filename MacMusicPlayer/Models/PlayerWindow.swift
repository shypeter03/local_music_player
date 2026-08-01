import AppKit

final class PlayerWindow: NSWindow {

    /// 外部设置快捷键处理
    var shortcutHandler: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {

        if shortcutHandler?(event) == true {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
enum PlayerAction {
    case playPause
    case seekForward
    case seekBackward
}

extension PlayerWindow {
    // 辅助函数：将 event 映射为你的业务动作
    func mapToPlayerAction(event: NSEvent) -> PlayerAction? {
        switch event.keyCode {
        case 49: return .playPause
        case 124: return .seekForward
        case 123: return .seekBackward
        default: return nil
        }
    }
}
