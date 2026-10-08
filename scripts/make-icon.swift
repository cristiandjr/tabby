import AppKit
import CoreGraphics

let arguments = CommandLine.arguments
guard arguments.count == 3,
      let source = NSImage(contentsOfFile: arguments[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    print("usage: make-icon <source.png> <output-1024.png>")
    exit(1)
}

let width = source.width
let height = source.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let bounds: CGRect? = pixels.withUnsafeMutableBytes { buffer in
    guard let context = CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    let bytes = buffer.bindMemory(to: UInt8.self)
    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0
    for row in 0..<height {
        for column in 0..<width {
            let offset = (row * width + column) * 4
            let brightest = max(bytes[offset], bytes[offset + 1], bytes[offset + 2])
            let darkest = min(bytes[offset], bytes[offset + 1], bytes[offset + 2])
            let isBackground = bytes[offset + 3] < 10 || (darkest > 170 && brightest - darkest < 30)
            guard !isBackground else { continue }
            minX = min(minX, column)
            maxX = max(maxX, column)
            minY = min(minY, row)
            maxY = max(maxY, row)
        }
    }
    guard maxX > minX, maxY > minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

guard let bounds, let artwork = source.cropping(to: bounds) else {
    print("could not find the icon shape")
    exit(1)
}

let canvas = 1024
let shape = CGRect(x: 100, y: 100, width: 824, height: 824)
let radius = shape.width * 0.235
guard let output = CGContext(
    data: nil,
    width: canvas,
    height: canvas,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let path = CGPath(roundedRect: shape, cornerWidth: radius, cornerHeight: radius, transform: nil)
output.saveGState()
output.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
output.addPath(path)
output.setFillColor(CGColor(srgbRed: 0.04, green: 0.3, blue: 0.85, alpha: 1))
output.fillPath()
output.restoreGState()
output.saveGState()
output.addPath(path)
output.clip()
output.interpolationQuality = .high
output.draw(artwork, in: shape.insetBy(dx: -3, dy: -3))
output.restoreGState()

guard let image = output.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: arguments[2]))
print("icon: \(arguments[2]) (artwork \(Int(bounds.width))x\(Int(bounds.height)))")
