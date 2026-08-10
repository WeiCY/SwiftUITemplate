#if os(iOS) || os(tvOS)
import UIKit

extension UIImage {

    // MARK: - Resize

    public func resized(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    public func resizedToFit(in maxSize: CGSize) -> UIImage {
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return resized(to: newSize)
    }

    // MARK: - Crop

    public func cropped(to rect: CGRect) -> UIImage {
        guard let cgImage = cgImage?.cropping(to: rect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    public func croppedToSquare() -> UIImage {
        let side = min(size.width, size.height)
        let x = (size.width - side) / 2
        let y = (size.height - side) / 2
        return cropped(to: CGRect(x: x * scale, y: y * scale, width: side * scale, height: side * scale))
    }

    // MARK: - Rotation

    public func rotated(by degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: radians)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    // MARK: - Format Conversion

    public func toPNG() -> Data? { pngData() }

    public func toJPEG(quality: CGFloat = 0.8) -> Data? { jpegData(compressionQuality: quality) }

    public func toHEIC(quality: CGFloat = 0.8) -> Data? {
        guard let cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.heic" as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Color Overlay

    public func withTintColor(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.setBlendMode(.normal)
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.clip(to: rect, mask: cgImage!)
            ctx.cgContext.fill(rect)
        }
    }

    // MARK: - Blur

    public func blurred(radius: CGFloat) -> UIImage {
        let ciImage = CIImage(image: self)
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter?.outputImage else { return self }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: ciImage?.extent ?? .zero) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
#endif
