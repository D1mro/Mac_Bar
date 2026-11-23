import AppKit

/// Акцентный цвет плеера из обложки альбома.
enum ArtworkPalette {
    /// Самый насыщенный из доминирующих цветов обложки (k-means на 32×32).
    /// `nil`, если обложка почти серая.
    static func accentColor(of image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        // 1. Уменьшаем до 32×32 и читаем пиксели.
        let side = 32
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                          bitsPerComponent: 8, bytesPerRow: side * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        // 2. Отбрасываем почти чёрные, белые и серые пиксели.
        var samples: [SIMD3<Double>] = []
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = SIMD3(Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])) / 255
            let (_, saturation, brightness) = hsb(rgb)
            if saturation < 0.25 || brightness < 0.18 { continue }
            samples.append(rgb)
        }
        guard samples.count >= 24 else { return nil }

        // 3. k-means: 5 кластеров, 10 итераций. Начальные центры — равномерно по выборке.
        let k = 5
        var centers = (0..<k).map { samples[$0 * samples.count / k] }
        var counts = [Int](repeating: 0, count: k)
        for _ in 0..<10 {
            var sums = [SIMD3<Double>](repeating: .zero, count: k)
            counts = [Int](repeating: 0, count: k)
            for sample in samples {
                let nearest = (0..<k).min { distance(sample, centers[$0]) < distance(sample, centers[$1]) }!
                sums[nearest] += sample
                counts[nearest] += 1
            }
            for c in 0..<k where counts[c] > 0 {
                centers[c] = sums[c] / Double(counts[c])
            }
        }

        // 4. Из заметных кластеров (≥ 10% пикселей) берём самый насыщенный.
        let dominant = (0..<k).filter { Double(counts[$0]) >= Double(samples.count) * 0.1 }
        guard let best = dominant.max(by: { hsb(centers[$0]).1 < hsb(centers[$1]).1 }) else { return nil }

        // На чёрном фоне цвет должен быть достаточно светлым.
        let (hue, saturation, brightness) = hsb(centers[best])
        return NSColor(hue: hue, saturation: saturation, brightness: max(brightness, 0.7), alpha: 1)
    }

    /// Фирменный цвет приложения, если обложка серая или её нет.
    static func brandColor(for bundleID: String?) -> NSColor {
        let id = bundleID?.lowercased() ?? ""
        if id.contains("yandex") { return NSColor(hex: 0xFFCC00) }
        if id == "com.spotify.client" { return NSColor(hex: 0x1DB954) }
        if id == "com.apple.music" { return NSColor(hex: 0xFA2D48) }
        return NSColor(hex: 0xFF9F0A)
    }

    private static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b
        return (d * d).sum()
    }

    private static func hsb(_ rgb: SIMD3<Double>) -> (Double, Double, Double) {
        let color = NSColor(srgbRed: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1)
        return (color.hueComponent, color.saturationComponent, color.brightnessComponent)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
