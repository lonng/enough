import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()

    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    let tile = NSBezierPath(roundedRect: canvas.insetBy(dx: 32, dy: 32), xRadius: 216, yRadius: 216)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.22, green: 0.86, blue: 0.56, alpha: 1),
        NSColor(srgbRed: 0.04, green: 0.42, blue: 0.28, alpha: 1)
    ])!
    gradient.draw(in: canvas, angle: 35)

    let highlight = NSBezierPath(roundedRect: NSRect(x: 32, y: 504, width: 960, height: 520),
                                 xRadius: 216, yRadius: 216)
    NSColor.white.withAlphaComponent(0.12).setFill()
    highlight.fill()
    NSGraphicsContext.restoreGraphicsState()

    let border = NSBezierPath(roundedRect: canvas.insetBy(dx: 34, dy: 34), xRadius: 212, yRadius: 212)
    border.lineWidth = 12
    NSColor.black.withAlphaComponent(0.16).setStroke()
    border.stroke()

    NSColor.white.withAlphaComponent(0.96).setStroke()
    let check = NSBezierPath()
    check.lineWidth = 80
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: NSPoint(x: 228, y: 504))
    check.line(to: NSPoint(x: 348, y: 384))
    check.line(to: NSPoint(x: 504, y: 560))
    check.move(to: NSPoint(x: 444, y: 448))
    check.line(to: NSPoint(x: 504, y: 388))
    check.line(to: NSPoint(x: 788, y: 664))
    check.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let path = directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: path)
}
