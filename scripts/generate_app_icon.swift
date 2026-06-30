// Generates the DailyFitness app icon — the Calm Strength flow mark.
//
// Two balanced arcs (a forest cap, a sage smile) on a deep-forest gradient,
// echoing DFFlowMark in the app. Deliberately abstract: no barbell, no body.
// Run:  swift scripts/generate_app_icon.swift <output.png>
//
// macOS / AppKit, y-up coordinate space.

import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

let dim: CGFloat = 1024
let rect = CGRect(x: 0, y: 0, width: dim, height: dim)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

// Calm Strength palette
let forestTop = rgb(0.220, 0.360, 0.300)   // #38..  lighter forest
let forestBottom = rgb(0.137, 0.235, 0.196) // #233D32 deep forest
let stone = rgb(0.957, 0.945, 0.925)        // warm near-white
let sage = rgb(0.510, 0.682, 0.604)         // muted sage (brightened)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
// noneSkipLast => fully opaque, no alpha channel (App Store rejects alpha icons).
guard let ctx = CGContext(
    data: nil,
    width: Int(dim),
    height: Int(dim),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("ctx") }

// Background gradient (top -> bottom)
let grad = CGGradient(
    colorsSpace: cs,
    colors: [forestTop, forestBottom] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: dim),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Soft tonal disc behind the mark for depth
let center = CGPoint(x: dim / 2, y: dim / 2)
ctx.saveGState()
ctx.setFillColor(CGColor(srgbRed: 0.510, green: 0.682, blue: 0.604, alpha: 0.12))
ctx.addArc(center: center, radius: 360, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()
ctx.restoreGState()

func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

let arcRadius: CGFloat = 300
let lineWidth: CGFloat = 78
ctx.setLineCap(.round)
ctx.setLineWidth(lineWidth)

// Rotate the whole mark a touch so it reads as motion, not a static ring.
ctx.translateBy(x: center.x, y: center.y)
ctx.rotate(by: deg(-18))
ctx.translateBy(x: -center.x, y: -center.y)

// Cap arc (top) — warm stone, spans 15°..165° through the top (90°)
ctx.setStrokeColor(stone)
ctx.addArc(center: center, radius: arcRadius, startAngle: deg(15), endAngle: deg(165), clockwise: false)
ctx.strokePath()

// Smile arc (bottom) — sage, spans 195°..345° through the bottom (270°)
ctx.setStrokeColor(sage)
ctx.addArc(center: center, radius: arcRadius, startAngle: deg(195), endAngle: deg(345), clockwise: false)
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath) (\(Int(dim))x\(Int(dim)))")
