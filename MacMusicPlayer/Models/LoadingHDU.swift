import AppKit

final class LoadingHUD {

    static let shared = LoadingHUD()

    private var panel: NSPanel?
    private let indicator = NSProgressIndicator()
    private let label = NSTextField(labelWithString: "")

    private init() {}
    func show(_ text: String = "内容正在加载中...") {

        DispatchQueue.main.async {

            if self.panel == nil {

                let panel = NSPanel(
                    contentRect: NSRect(x: 0, y: 0, width: 220, height: 90),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )

                panel.isOpaque = false
                panel.backgroundColor = NSColor.black.withAlphaComponent(0.75)
                panel.hasShadow = true
                panel.level = .floating

                self.indicator.style = .spinning
                self.indicator.startAnimation(nil)

                self.indicator.translatesAutoresizingMaskIntoConstraints = false
                self.label.translatesAutoresizingMaskIntoConstraints = false

                panel.contentView?.addSubview(self.indicator)
                panel.contentView?.addSubview(self.label)

                NSLayoutConstraint.activate([
                    self.indicator.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
                    self.indicator.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 18),

                    self.label.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
                    self.label.topAnchor.constraint(equalTo: self.indicator.bottomAnchor, constant: 10)
                ])

                self.panel = panel
            }

            self.label.stringValue = text

            if let window = NSApp.keyWindow {

                let frame = window.frame

                self.panel?.setFrameOrigin(NSPoint(
                    x: frame.midX - 110,
                    y: frame.midY - 45
                ))

            }

            self.panel?.orderFront(nil)
        }
    }
    func hide() {

        DispatchQueue.main.async {

            self.panel?.orderOut(nil)

        }
    }
}
