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
    NSColor(srgbRed: 0.075, green: 0.29, blue: 0.19, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 194, yRadius: 194).fill()
    NSColor(srgbRed: 0.88, green: 0.95, blue: 0.85, alpha: 1).setStroke()
    let check = NSBezierPath()
    check.lineWidth = 90
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: NSPoint(x: 280, y: 500))
    check.line(to: NSPoint(x: 445, y: 345))
    check.line(to: NSPoint(x: 750, y: 690))
    check.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let path = directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: path)
}
