import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import WebKit

enum WebViewColorCalculatorError: Error {
    case snapshotFailed(error: Error?)
    case ciImageConversionFailed
    case filterOutputImageFailed
}

enum WebViewRegion {
    case top(CGFloat)
    case bottom(CGFloat)
}

@MainActor
struct WebViewAverageColorCalculator {
    private let averageColorCalculator = AverageColorCalculator()

    func calculateAverageColor(for webView: WKWebView,
                               in region: WebViewRegion) async -> Result<UIColor, WebViewColorCalculatorError>
    {
        let config = WKSnapshotConfiguration()
        // Snapshot must be taken on the main thread.
        let (image, error) = await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, error in
                continuation.resume(returning: (image, error))
            }
        }

        guard let image else {
            return .failure(.snapshotFailed(error: error))
        }

        guard let ciImage = CIImage(image: image) else {
            return .failure(.ciImageConversionFailed)
        }

        let imageExtent = ciImage.extent
        let imageOrigin = imageExtent.origin
        let imageHeight = imageExtent.height
        let imageWidth = imageExtent.width

        let regionRect = switch region {
        case let .top(height):
            CGRect(x: imageOrigin.x,
                   y: imageOrigin.y + imageHeight - height,
                   width: imageWidth,
                   height: height)
        case let .bottom(height):
            CGRect(x: imageOrigin.x,
                   y: imageOrigin.y,
                   width: imageWidth,
                   height: height)
        }

        // Offload the average color calculation to a background thread.
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) { [image] in
                let result = averageColorCalculator.calculateAverageColor(for: CIImage(image: image)!, in: regionRect)
                // Resume on the main actor
                await MainActor.run {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

/// Calculates the average color of a given region from a CIImage.
struct AverageColorCalculator {
    func calculateAverageColor(for image: CIImage, in region: CGRect) -> Result<UIColor, WebViewColorCalculatorError> {
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = region

        guard let outputImage = filter.outputImage else {
            return .failure(.filterOutputImageFailed)
        }

        // Render the 1x1 pixel output image into a small bitmap.
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        let alpha = CGFloat(bitmap[3]) / 255.0

        return .success(UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }
}
