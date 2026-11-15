import AppKit

enum MenuBarIcon {
    static let automaticApproval: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let circle = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16))
            circle.lineWidth = 1.35
            circle.stroke()
            let checks = NSBezierPath()
            checks.lineWidth = 1.45
            checks.lineCapStyle = .round
            checks.lineJoinStyle = .round
            checks.move(to: NSPoint(x: 4, y: 8.5))
            checks.line(to: NSPoint(x: 6.4, y: 6.1))
            checks.line(to: NSPoint(x: 10.6, y: 11.2))
            checks.move(to: NSPoint(x: 8.7, y: 7.2))
            checks.line(to: NSPoint(x: 9.8, y: 6.1))
            checks.line(to: NSPoint(x: 14, y: 11.2))
            checks.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Enough: \(L10n.text("Automation"))"
        return image
    }()
}
