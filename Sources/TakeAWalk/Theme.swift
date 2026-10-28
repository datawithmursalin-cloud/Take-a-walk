import AppKit

@MainActor
enum Theme {
    static let navy = NSColor(calibratedRed: 0.055, green: 0.083, blue: 0.145, alpha: 1)
    static let raised = NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.22, alpha: 1)
    static let orange = NSColor(calibratedRed: 1, green: 0.51, blue: 0.27, alpha: 1)
    static let white = NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.93, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.63, green: 0.69, blue: 0.79, alpha: 1)

    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
                      color: NSColor = white) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        field.maximumNumberOfLines = 0
        return field
    }

    static func window(title: String, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = navy
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()
        return window
    }
}

/// Retains native NSButton keyboard and accessibility behavior with our palette.
final class ActionButton: NSButton {
    var secondary = false

    override func draw(_ dirtyRect: NSRect) {
        let fill = secondary ? Theme.raised : Theme.orange
        (isHighlighted ? fill.withAlphaComponent(0.75) : fill).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 13, yRadius: 13).fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: secondary ? Theme.white : Theme.navy,
            .paragraphStyle: paragraph
        ]
        let textHeight = (title as NSString).size(withAttributes: attributes).height
        (title as NSString).draw(in: NSRect(x: 0, y: (bounds.height - textHeight) / 2,
                                          width: bounds.width, height: textHeight + 2),
                                withAttributes: attributes)
        if window?.firstResponder === self {
            Theme.orange.withAlphaComponent(0.6).setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 11, yRadius: 11)
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}
