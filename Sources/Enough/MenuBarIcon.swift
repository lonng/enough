import AppKit

enum MenuBarIcon {
    static let appIcon: NSImage = {
        let size = CGFloat(256)
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { bounds in
            let tile = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), xRadius: 54, yRadius: 54)
            NSGraphicsContext.current?.saveGraphicsState()
            tile.addClip()

            let gradient = NSGradient(colors: [
                NSColor(srgbRed: 0.22, green: 0.86, blue: 0.56, alpha: 1),
                NSColor(srgbRed: 0.04, green: 0.42, blue: 0.28, alpha: 1)
            ])!
            gradient.draw(in: bounds, angle: 35)

            let highlight = NSBezierPath(roundedRect: NSRect(x: 8, y: 126, width: 240, height: 130),
                                         xRadius: 54, yRadius: 54)
            NSColor.white.withAlphaComponent(0.12).setFill()
            highlight.fill()

            let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 8.5, dy: 8.5), xRadius: 53, yRadius: 53)
            border.lineWidth = 3
            NSColor.black.withAlphaComponent(0.16).setStroke()
            border.stroke()

            NSGraphicsContext.current?.restoreGraphicsState()

            let checks = NSBezierPath()
            checks.lineWidth = 20
            checks.lineCapStyle = .round
            checks.lineJoinStyle = .round
            checks.move(to: NSPoint(x: 57, y: 126))
            checks.line(to: NSPoint(x: 87, y: 96))
            checks.line(to: NSPoint(x: 126, y: 140))
            checks.move(to: NSPoint(x: 111, y: 112))
            checks.line(to: NSPoint(x: 126, y: 97))
            checks.line(to: NSPoint(x: 197, y: 166))
            NSColor.white.withAlphaComponent(0.96).setStroke()
            checks.stroke()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "Enough"
        return image
    }()

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
