import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Original geometry, not an SF Symbol or a font glyph. Apple masks the square.
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 0.055, green: 0.455, blue: 0.408, alpha: 1),
              CGColor(red: 0.024, green: 0.267, blue: 0.259, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.saveGState()
context.drawLinearGradient(gradient, start: CGPoint(x: 120, y: 940), end: CGPoint(x: 890, y: 80), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
context.restoreGState()
context.setStrokeColor(CGColor(red: 0.973, green: 0.973, blue: 0.933, alpha: 1))
context.setLineWidth(88)
context.setLineCap(.round)
context.setLineJoin(.round)
let arch = CGMutablePath()
arch.move(to: CGPoint(x: 270, y: 280))
arch.addCurve(to: CGPoint(x: 486, y: 715), control1: CGPoint(x: 337, y: 454), control2: CGPoint(x: 412, y: 626))
arch.addCurve(to: CGPoint(x: 538, y: 715), control1: CGPoint(x: 500, y: 750), control2: CGPoint(x: 524, y: 750))
arch.addCurve(to: CGPoint(x: 754, y: 280), control1: CGPoint(x: 612, y: 626), control2: CGPoint(x: 687, y: 454))
context.addPath(arch)
context.strokePath()
context.setLineWidth(54)
let tide = CGMutablePath()
tide.move(to: CGPoint(x: 372, y: 403))
tide.addCurve(to: CGPoint(x: 652, y: 403), control1: CGPoint(x: 445, y: 443), control2: CGPoint(x: 579, y: 443))
context.addPath(tide)
context.strokePath()
context.setFillColor(CGColor(red: 0.957, green: 0.745, blue: 0.373, alpha: 1))
context.fillEllipse(in: CGRect(x: 737, y: 743, width: 70, height: 70))
let image = context.makeImage()!
let output = CommandLine.arguments[1]
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
precondition(CGImageDestinationFinalize(destination))
