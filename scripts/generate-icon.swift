#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? ".build/AppIcon-1024.png"
let size = CGSize(width: 1024, height: 1024)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create bitmap.\n", stderr)
    exit(1)
}

bitmap.size = size

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor.clear.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

let cardRect = CGRect(x: 34, y: 46, width: 956, height: 936)
let card = NSBezierPath(roundedRect: cardRect, xRadius: 112, yRadius: 112)

let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.18, alpha: 0.26)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.set()

NSColor(calibratedWhite: 0.902, alpha: 1).setFill()
card.fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let purple = NSColor(
    calibratedRed: 149.0 / 255.0,
    green: 61.0 / 255.0,
    blue: 150.0 / 255.0,
    alpha: 1
)

func drawRing(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) {
    purple.setFill()
    NSBezierPath(
        ovalIn: CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        )
    ).fill()

    NSColor(calibratedWhite: 0.902, alpha: 1).setFill()
    NSBezierPath(
        ovalIn: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
    ).fill()
}

func drawDot(center: CGPoint, radius: CGFloat) {
    purple.setFill()
    NSBezierPath(
        ovalIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    ).fill()
}

let leftTop = CGPoint(x: 202, y: 727)
let rightTop = CGPoint(x: 790, y: 727)
let bottom = CGPoint(x: 496, y: 322)

drawRing(center: leftTop, outerRadius: 116, innerRadius: 54)
drawRing(center: rightTop, outerRadius: 116, innerRadius: 54)
drawRing(center: bottom, outerRadius: 116, innerRadius: 54)

for x in [384.0, 456.0, 528.0, 600.0] {
    drawDot(center: CGPoint(x: x, y: 727), radius: 30)
}

for point in [
    CGPoint(x: 304, y: 579),
    CGPoint(x: 365, y: 500),
    CGPoint(x: 426, y: 419),
    CGPoint(x: 688, y: 579),
    CGPoint(x: 627, y: 500),
    CGPoint(x: 566, y: 419)
] {
    drawDot(center: point, radius: 28)
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode PNG.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)

print(outputURL.path)
