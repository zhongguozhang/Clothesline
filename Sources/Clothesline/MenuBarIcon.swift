import AppKit

/// A compact vector silhouette, independent of the full-color application icon.
enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let rope = NSBezierPath()
            rope.move(to: NSPoint(x: 1, y: 15.5))
            rope.curve(to: NSPoint(x: 19, y: 15.5),
                       controlPoint1: NSPoint(x: 7, y: 14),
                       controlPoint2: NSPoint(x: 13, y: 14))
            rope.lineWidth = 1.5
            rope.lineCapStyle = .round
            rope.stroke()

            let shirt = NSBezierPath()
            shirt.move(to: NSPoint(x: 6, y: 14))
            for point in [NSPoint(x: 2, y: 10), NSPoint(x: 4.5, y: 7.5),
                          NSPoint(x: 6, y: 9), NSPoint(x: 6, y: 2),
                          NSPoint(x: 14, y: 2), NSPoint(x: 14, y: 9),
                          NSPoint(x: 15.5, y: 7.5), NSPoint(x: 18, y: 10),
                          NSPoint(x: 14, y: 14), NSPoint(x: 12, y: 14)] {
                shirt.line(to: point)
            }
            shirt.curve(to: NSPoint(x: 8, y: 14),
                        controlPoint1: NSPoint(x: 12, y: 11),
                        controlPoint2: NSPoint(x: 8, y: 11))
            shirt.close()
            shirt.lineWidth = 1.6
            shirt.lineJoinStyle = .round
            shirt.stroke()
            for x in [6.0, 14.0] {
                NSBezierPath(roundedRect: NSRect(x: x - 0.8, y: 13, width: 1.6, height: 4),
                             xRadius: 0.8, yRadius: 0.8).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Clothesline"
        return image
    }
}
