// Run on macOS: swiftc -O scripts/image-adapter-benchmark.swift -o /tmp/cy-image-bench && /tmp/cy-image-bench
// Measures the old adapter (NSImage -> TIFF -> PNG -> view decode) against original data -> view decode.
// The Kingfisher decode common to both paths is excluded. Not an end-to-end or iOS benchmark.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let width = 3840
let height = 2160
var pixels = [UInt8](repeating: 255, count: width * height * 4)
var seed: UInt32 = 42
for y in 0..<height {
    for x in 0..<width {
        seed = 1664525 &* seed &+ 1013904223
        let noise = Int(seed >> 28)
        let index = (y * width + x) * 4
        pixels[index] = UInt8(min(255, x * 220 / width + noise))
        pixels[index + 1] = UInt8(min(255, y * 220 / height + noise))
        pixels[index + 2] = UInt8(100 + noise)
    }
}
let provider = CGDataProvider(data: Data(pixels) as CFData)!
let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
let jpeg = NSMutableData()
let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
precondition(CGImageDestinationFinalize(destination))
let original = jpeg as Data
let decoded = NSImage(data: original)!
var bounds = CGRect(x: 0, y: 0, width: width, height: height)
_ = decoded.cgImage(forProposedRect: &bounds, context: nil, hints: nil)

func forceDecode(_ image: NSImage) {
    var rect = bounds
    let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cgImage, in: bounds)
}
forceDecode(decoded)

func oldAdapter() -> Int {
    let bitmap = NSBitmapImageRep(data: decoded.tiffRepresentation!)!
    let png = bitmap.representation(using: .png, properties: [:])!
    let view = NSImage(data: png)!
    forceDecode(view)
    return png.count
}

func newAdapter() -> Int {
    let view = NSImage(data: original)!
    forceDecode(view)
    return original.count
}

func measure(_ operation: () -> Int) -> (Double, Int) {
    var samples: [Double] = []
    var bytes = 0
    for index in 0..<8 {
        autoreleasepool {
            let start = CFAbsoluteTimeGetCurrent()
            bytes = operation()
            if index > 0 { samples.append((CFAbsoluteTimeGetCurrent() - start) * 1000) }
        }
    }
    return (samples.sorted()[samples.count / 2], bytes)
}
let old = measure(oldAdapter)
let new = measure(newAdapter)
print("Generated JPEG: \(width)x\(height), \(original.count) bytes")
print("Old adapter median ms: \(old.0), returned PNG bytes: \(old.1)")
print("New adapter median ms: \(new.0), returned original bytes: \(new.1)")
