#!/usr/bin/env swift
// Generates Resources/AppIcon.icns — a teal→amber squircle with an owl.
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
let resources = root.appendingPathComponent("Resources")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

func render(_ size: CGFloat) -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Squircle background inset slightly, as macOS icons are.
    let inset = size * 0.08
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.55, alpha: 1),
        NSColor(calibratedRed: 0.16, green: 0.78, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.22, alpha: 1),
    ], atLocations: [0.0, 0.55, 1.0], colorSpace: .deviceRGB)!
    gradient.draw(in: rect, angle: -60)

    // Soft inner highlight.
    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(ovalIn: CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height)).fill()

    // Owl glyph.
    let owl = "🦉" as NSString
    let fontSize = size * 0.56
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize)
    ]
    let textSize = owl.size(withAttributes: attrs)
    let point = NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2 - size * 0.01)
    owl.draw(at: point, withAttributes: attrs)

    image.unlockFocus()

    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in sizes {
    try render(size).write(to: iconset.appendingPathComponent(name))
}

// Build the .icns via iconutil.
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try proc.run()
proc.waitUntilExit()
print("AppIcon.icns:", proc.terminationStatus == 0 ? "ok" : "FAILED (\(proc.terminationStatus))")
