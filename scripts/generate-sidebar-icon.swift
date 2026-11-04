#!/usr/bin/env swift
import AppKit
import Foundation

enum IconError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        switch self { case .message(let text): return text }
    }
}

func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw IconError.message("\(executable) failed (\(process.terminationStatus))")
    }
}

func writePNG(_ image: NSImage, pixels: Int, to url: URL, monochrome: Bool = false) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError.message("Cannot create \(pixels)-pixel bitmap")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    bounds.fill(using: .copy)
    let inset = monochrome ? max(1.0, Double(pixels) / 16.0) : 0.0
    let available = bounds.insetBy(dx: inset, dy: inset)
    let aspect = image.size.width / image.size.height
    let width = min(available.width, available.height * aspect)
    let height = width / aspect
    let destination = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                             width: width, height: height)
    image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
    if monochrome {
        NSColor.black.setFill()
        bounds.fill(using: .sourceIn)
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.message("Cannot encode \(url.lastPathComponent)")
    }
    try data.write(to: url)
}

func iconElements(_ data: Data, startingAt start: Int) throws -> [String: Data] {
    var result: [String: Data] = [:]
    var offset = start
    while offset < data.count {
        guard data.count - offset >= 8,
              let type = String(data: data.subdata(in: offset..<(offset + 4)), encoding: .ascii) else {
            throw IconError.message("Malformed ICNS element header")
        }
        let length = data[(offset + 4)..<(offset + 8)].reduce(0) { ($0 << 8) | Int($1) }
        guard length >= 8, length <= data.count - offset else {
            throw IconError.message("Malformed ICNS element length")
        }
        result[type] = data.subdata(in: (offset + 8)..<(offset + length))
        offset += length
    }
    return result
}

func verifySidebarTemplates(at url: URL) throws {
    let data = try Data(contentsOf: url)
    guard data.count >= 8, String(data: data.prefix(4), encoding: .ascii) == "icns",
          let template = try iconElements(data, startingAt: 8)["sbtp"] else {
        throw IconError.message("iconutil did not embed the sidebar template family")
    }
    // The sbtp payload contains ICNS elements directly, without another icns
    // header. iconutil maps 18-point templates to the legacy icsb/icsB types.
    let elements = try iconElements(template, startingAt: 0)
    let required = Set(["ic04", "ic11", "icsb", "icsB", "ic05", "ic12"])
    let missing = required.subtracting(elements.keys)
    guard missing.isEmpty else {
        throw IconError.message("Missing sidebar representations: \(missing.sorted().joined(separator: ", "))")
    }
}

func main() throws {
    guard CommandLine.arguments.count == 3 else {
        throw IconError.message("Usage: generate-sidebar-icon.swift INPUT.icns OUTPUT.icns")
    }
    let source = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
    let output = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
    guard let appIcon = NSImage(contentsOf: source),
          let symbol = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil) else {
        throw IconError.message("Cannot read app icon or externaldrive SF Symbol")
    }
    let temporary = FileManager.default.temporaryDirectory
        .appendingPathComponent("OpenInTerminal-sidebar-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let iconset = temporary.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    try run("/usr/bin/iconutil", ["-c", "iconset", "-o", iconset.path, source.path])

    // Include every standard representation even when actool emitted a sparse
    // ICNS. Retain the app's blue artwork, and add separate sidebar templates.
    let appVariants = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32),
                       ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                       ("256x256", 256), ("256x256@2x", 512),
                       ("512x512", 512), ("512x512@2x", 1024)]
    for (name, pixels) in appVariants {
        let url = iconset.appendingPathComponent("icon_\(name).png")
        if !FileManager.default.fileExists(atPath: url.path) {
            try writePNG(appIcon, pixels: pixels, to: url)
        }
    }
    let sidebarVariants = [("16x16", 16), ("16x16@2x", 32),
                           ("18x18", 18), ("18x18@2x", 36),
                           ("32x32", 32), ("32x32@2x", 64)]
    for (name, pixels) in sidebarVariants {
        try writePNG(symbol, pixels: pixels,
                     to: iconset.appendingPathComponent("sidebar_\(name).png"), monochrome: true)
    }
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try run("/usr/bin/iconutil", ["-c", "icns", "-o", output.path, iconset.path])
    try verifySidebarTemplates(at: output)
    print(output.path)
}

do {
    try main()
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
