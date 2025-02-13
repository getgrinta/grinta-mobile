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

/// Takes a snapshot of a WKWebView and calculates the average color of a specified region.
@MainActor
struct WebViewAverageColorCalculator {
    private let averageColorCalculator = AverageColorCalculator()

    func calculateAverageColor(for webView: WKWebView, in region: WebViewRegion, completion: @escaping (Result<UIColor, WebViewColorCalculatorError>) -> Void) {
        let config = WKSnapshotConfiguration()

        webView.takeSnapshot(with: config) { image, error in
            guard let image else {
                completion(.failure(.snapshotFailed(error: error)))
                return
            }

            guard let ciImage = CIImage(image: image) else {
                completion(.failure(.ciImageConversionFailed))
                return
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

            let result = averageColorCalculator.calculateAverageColor(for: ciImage, in: regionRect)
            completion(result)
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
