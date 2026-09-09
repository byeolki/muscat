import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

/// A colour pulled out of a piece of artwork, already conditioned for use as a
/// background wash.
///
/// Stored as components rather than as a `Color` so it can cross actor
/// boundaries and sit in a cache without dragging SwiftUI along.
public struct ArtworkPalette: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// Derives the dominant colour of a cover so Now Playing can be lit by the
/// artwork instead of sitting on flat black.
///
/// Deliberately tiny: the image is decoded straight to a 32px thumbnail by
/// ImageIO, so this never holds a full-size cover in memory, and results are
/// cached per URL because the same artwork is asked for on every track change.
public actor ArtworkPaletteLoader {
    public static let shared = ArtworkPaletteLoader()

    private var cache: [URL: ArtworkPalette] = [:]
    private var inFlight: [URL: Task<ArtworkPalette?, Never>] = [:]

    /// Bounded so a long listening session can't accumulate every cover's colour.
    private static let cacheLimit = 200

    public init() {}

    public func palette(for url: URL) async -> ArtworkPalette? {
        if let cached = cache[url] { return cached }
        if let running = inFlight[url] { return await running.value }

        let task = Task<ArtworkPalette?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url) else { return nil }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            return Self.dominantColor(of: data)
        }
        inFlight[url] = task

        let result = await task.value
        inFlight[url] = nil
        if let result {
            if cache.count >= Self.cacheLimit { cache.removeAll(keepingCapacity: true) }
            cache[url] = result
        }
        return result
    }

    /// Averages the thumbnail's pixels, weighted by saturation, then forces the
    /// result to a fixed saturation and brightness.
    ///
    /// The weighting is what stops a cover that is mostly white or mostly black
    /// from averaging out to grey — the few coloured pixels are the ones that
    /// identify the artwork. Normalising afterwards is what makes the result
    /// usable as a background at all: raw dominant colours range from
    /// near-black to blinding, and the screen behind them has to stay dark
    /// enough to read white text on.
    nonisolated static func dominantColor(of data: Data) -> ArtworkPalette? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: side, height: side))

        var totalWeight = 0.0
        var sum = (r: 0.0, g: 0.0, b: 0.0)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.1 else { continue }
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255

            let maxC = max(r, g, b), minC = min(r, g, b)
            let saturation = maxC <= 0 ? 0 : (maxC - minC) / maxC
            // A floor rather than zero, so a genuinely monochrome cover still
            // produces a colour instead of nothing at all.
            let weight = (0.05 + saturation) * alpha
            sum.r += r * weight
            sum.g += g * weight
            sum.b += b * weight
            totalWeight += weight
        }
        guard totalWeight > 0 else { return nil }

        let (h, _, _) = Self.hsb(r: sum.r / totalWeight, g: sum.g / totalWeight, b: sum.b / totalWeight)
        let (r, g, b) = Self.rgb(h: h, s: 0.55, v: 0.42)
        return ArtworkPalette(red: r, green: g, blue: b)
    }

    private nonisolated static func hsb(r: Double, g: Double, b: Double) -> (Double, Double, Double) {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        var hue = 0.0
        if delta > 0 {
            if maxC == r { hue = (g - b) / delta }
            else if maxC == g { hue = 2 + (b - r) / delta }
            else { hue = 4 + (r - g) / delta }
            hue *= 60
            if hue < 0 { hue += 360 }
        }
        return (hue, maxC <= 0 ? 0 : delta / maxC, maxC)
    }

    private nonisolated static func rgb(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (r + m, g + m, b + m)
    }
}
