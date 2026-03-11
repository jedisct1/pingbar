import Cocoa

/// Renders a combined menu bar icon as a programmatic NSImage.
/// Inner filled circle represents latency status; outer ring represents packet loss level.
struct StatusIconRenderer {

    /// Render the combined status icon.
    /// - Parameters:
    ///   - latencyMs: Current latency in milliseconds, or nil if network is down.
    ///   - lossLevel: Current packet loss classification.
    ///   - pingStatus: Current ping status (good/warning/bad/captivePortal).
    ///   - hasEnoughLossSamples: Whether enough samples exist for a meaningful loss reading.
    /// - Returns: An NSImage suitable for the menu bar status item.
    static func render(
        latencyMs: Int?,
        lossLevel: LossTracker.LossLevel,
        pingStatus: PingManager.PingStatus,
        hasEnoughLossSamples: Bool
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let outerRadius: CGFloat = 7.0
            let ringWidth: CGFloat = 2.0
            let gap: CGFloat = 0.5
            let innerRadius = outerRadius - ringWidth - gap

            // Draw outer ring (packet loss)
            let ringColor = self.ringColor(for: lossLevel, hasEnoughSamples: hasEnoughLossSamples)
            let ringPath = NSBezierPath()
            ringPath.appendArc(withCenter: center, radius: outerRadius - ringWidth / 2, startAngle: 0, endAngle: 360)
            ringColor.setStroke()
            ringPath.lineWidth = ringWidth
            ringPath.stroke()

            // Draw inner filled circle (latency)
            let fillColor = self.fillColor(for: pingStatus, latencyMs: latencyMs)
            let innerPath = NSBezierPath()
            innerPath.appendArc(withCenter: center, radius: innerRadius, startAngle: 0, endAngle: 360)
            fillColor.setFill()
            innerPath.fill()

            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Color Mapping

    /// Maps latency to a fill color using 6 discrete bands.
    private static func fillColor(for status: PingManager.PingStatus, latencyMs: Int?) -> NSColor {
        switch status {
        case .captivePortal:
            return NSColor.systemPurple
        case .bad:
            return NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // dark gray
        case .good, .warning:
            guard let ms = latencyMs else {
                return NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
            }
            return latencyBandColor(ms: ms)
        }
    }

    /// 6-band latency color gradient.
    private static func latencyBandColor(ms: Int) -> NSColor {
        switch ms {
        case ..<50:
            return NSColor.systemGreen
        case 50..<100:
            return interpolate(from: NSColor.systemGreen, to: NSColor.systemYellow, fraction: Double(ms - 50) / 50.0)
        case 100..<200:
            return interpolate(from: NSColor.systemYellow, to: NSColor.systemOrange, fraction: Double(ms - 100) / 100.0)
        case 200..<400:
            return interpolate(from: NSColor.systemOrange, to: NSColor.systemRed, fraction: Double(ms - 200) / 200.0)
        default:
            return NSColor.systemRed
        }
    }

    /// Maps packet loss level to ring color. Neutral gray while collecting.
    private static func ringColor(for level: LossTracker.LossLevel, hasEnoughSamples: Bool) -> NSColor {
        guard hasEnoughSamples else {
            return NSColor(calibratedRed: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        }
        switch level {
        case .good:
            return NSColor.systemGreen
        case .warning:
            return NSColor.systemYellow
        case .bad:
            return NSColor.systemRed
        }
    }

    /// Linear interpolation between two NSColors in sRGB space.
    private static func interpolate(from: NSColor, to: NSColor, fraction: Double) -> NSColor {
        let f = max(0, min(1, fraction))
        guard let fromRGB = from.usingColorSpace(.sRGB),
              let toRGB = to.usingColorSpace(.sRGB) else {
            return from
        }
        let r = fromRGB.redComponent + CGFloat(f) * (toRGB.redComponent - fromRGB.redComponent)
        let g = fromRGB.greenComponent + CGFloat(f) * (toRGB.greenComponent - fromRGB.greenComponent)
        let b = fromRGB.blueComponent + CGFloat(f) * (toRGB.blueComponent - fromRGB.blueComponent)
        let a = fromRGB.alphaComponent + CGFloat(f) * (toRGB.alphaComponent - fromRGB.alphaComponent)
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
