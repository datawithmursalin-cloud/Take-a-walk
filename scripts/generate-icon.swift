// Run with: swift -module-cache-path .build/module-cache scripts/generate-icon.swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources")
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// Original vector paths recreated from the user's walking-figure reference.
// Coordinates use a 78-point canvas with the origin at the top left.
let strokes: [(CGFloat, [CGPoint])] = [
    (4.4, [.init(x: 39.0, y: 28.5), .init(x: 30.4, y: 32.9), .init(x: 27.0, y: 41.4)]),
    (4.4, [.init(x: 40.5, y: 29.2), .init(x: 46.7, y: 36.1), .init(x: 53.0, y: 36.1)]),
    (5.4, [.init(x: 40.0, y: 28.9), .init(x: 36.8, y: 40.8), .init(x: 39.0, y: 45.0)]),
    (4.5, [.init(x: 37.5, y: 44.0), .init(x: 33.8, y: 53.0), .init(x: 26.0, y: 61.0)]),
    (4.5, [.init(x: 38.5, y: 44.2), .init(x: 43.7, y: 52.0), .init(x: 51.0, y: 61.5)])
]
let reference = NSBitmapImageRep(data: try Data(contentsOf: resources.appendingPathComponent("Brand/Reference.png")))!
let navy = reference.colorAt(x: 0, y: 0)!.usingColorSpace(.sRGB)!
let orange = reference.colorAt(x: 40, y: 18)!.usingColorSpace(.sRGB)!
func hex(_ color: NSColor) -> String {
    String(format: "#%02X%02X%02X", Int((color.redComponent * 255).rounded()),
           Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.setAllowsAntialiasing(true)
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: CGFloat(size))
    transform.scaleX(by: CGFloat(size) / 78, yBy: -CGFloat(size) / 78)
    transform.concat()
    navy.setFill()
    NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 70, height: 70), xRadius: 15.5, yRadius: 15.5).fill()
    orange.setFill()
    orange.setStroke()
    NSBezierPath(ovalIn: NSRect(x: 35.9, y: 13.6, width: 9.2, height: 9.2)).fill()
    for (width, points) in strokes {
        let path = NSBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let png = render(size: 1024)
try png.write(to: resources.appendingPathComponent("AppIcon.png"))
for size in [16, 32, 128, 256, 512] {
    try render(size: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
let svgPaths = strokes.map { width, points in
    let commands = points.enumerated().map { index, point in "\(index == 0 ? "M" : "L")\(point.x) \(point.y)" }.joined(separator: " ")
    return "  <path d=\"\(commands)\" fill=\"none\" stroke=\"\(hex(orange))\" stroke-width=\"\(width)\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
}.joined(separator: "\n")
let svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 78 78" role="img" aria-label="Take a Walk logo">
  <rect x="4" y="4" width="70" height="70" rx="15.5" fill="\(hex(navy))"/>
  <circle cx="40.5" cy="18.2" r="4.6" fill="\(hex(orange))"/>
\(svgPaths)
</svg>

"""
try svg.write(to: resources.appendingPathComponent("Brand/Logo.svg"), atomically: true, encoding: .utf8)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("Could not create AppIcon.icns. Try running iconutil outside a restricted sandbox.\n".utf8))
    exit(1)
}
print("Created AppIcon.png, AppIcon.icns, and Brand/Logo.svg using colors \(hex(navy)) and \(hex(orange)).")
