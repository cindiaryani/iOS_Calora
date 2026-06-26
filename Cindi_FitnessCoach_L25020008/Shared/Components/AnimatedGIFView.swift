import SwiftUI
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

/// Plays a remote animated GIF using only system frameworks (URLSession + ImageIO) —
/// no third-party dependencies. Decoded GIFs are cached in memory by URL so scrolling a
/// list doesn't re-download or re-decode the same clip.
struct AnimatedGIFView: View {
    let urlString: String
    var headers: [String: String] = [:]
    var contentMode: ContentMode = .fit

    var body: some View {
        #if canImport(UIKit)
        GIFRepresentable(urlString: urlString, headers: headers, contentMode: contentMode)
        #else
        Color.appSurfaceMuted
        #endif
    }
}

#if canImport(UIKit)
private enum GIFCache {
    static let images = NSCache<NSString, UIImage>()
}

private struct GIFRepresentable: UIViewRepresentable {
    let urlString: String
    let headers: [String: String]
    let contentMode: ContentMode

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = contentMode == .fit ? .scaleAspectFit : .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        let key = urlString as NSString

        if let cached = GIFCache.images.object(forKey: key) {
            uiView.image = cached
            return
        }

        // Skip if we're already loading this exact URL into this view.
        guard context.coordinator.loadingURL != urlString,
              let url = URL(string: urlString) else { return }
        context.coordinator.loadingURL = urlString

        var request = URLRequest(url: url)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        Task {
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let image = Self.animatedImage(from: data) else { return }
            GIFCache.images.setObject(image, forKey: key)
            await MainActor.run { uiView.image = image }
        }
    }

    final class Coordinator {
        var loadingURL: String?
    }

    private static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDuration(source: source, index: index)
        }

        return UIImage.animatedImage(
            with: frames,
            duration: duration > 0 ? duration : Double(count) / 20.0
        )
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let delay = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gif[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}
#endif
