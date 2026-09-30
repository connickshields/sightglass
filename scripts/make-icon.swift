// Renders Support/AppIcon.svg into the app icon (Support/AppIcon.icns) and
// the GitHub images (docs/images/icon.png, docs/images/social-preview.png).
//
// Usage, from the repo root: make icon
import AppKit

let master = "Support/AppIcon.svg"
let icns = "Support/AppIcon.icns"
let readmeIcon = "docs/images/icon.png"
let socialPreview = "docs/images/social-preview.png"

// Social preview (1280x640, uploaded in the repo's Settings > General).
// Colors follow the icon: a charcoal body with a mint (#5ce6c8) trace.
let previewBackgroundTop = NSColor(srgbRed: 0.075, green: 0.086, blue: 0.118, alpha: 1)
let previewBackgroundBottom = NSColor(srgbRed: 0.031, green: 0.035, blue: 0.051, alpha: 1)
let previewGlow = NSColor(srgbRed: 0.361, green: 0.902, blue: 0.784, alpha: 0.28)
let previewTitleColor = NSColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1)
let previewTaglineColor = NSColor(srgbRed: 0.62, green: 0.66, blue: 0.74, alpha: 1)
let previewTagline = "Watch long-running jobs\nfrom the macOS menu bar"

guard let icon = NSImage(contentsOf: URL(fileURLWithPath: master)) else {
    FileHandle.standardError.write(Data("make-icon: can't read \(master)\n".utf8))
    exit(1)
}

/// Draws into a new sRGB bitmap of the given pixel size and returns it as PNG data.
func png(width: Int, height: Int, _ draw: (NSRect) -> Void) -> Data {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

func write(_ data: Data, to path: String) {
    let url = URL(fileURLWithPath: path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(path)")
}

// App icon, then iconutil. The 1x 16 and 32 pt images are left out: iconutil
// stores them as legacy types, and macOS 26 and later then draws the icon on a
// gray tile at those sizes instead of scaling down the larger images.
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(getpid()).iconset")
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] where !(scale == 1 && points <= 32) {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let data = png(width: points * scale, height: points * scale) { icon.draw(in: $0) }
        try! data.write(to: iconset.appendingPathComponent(name))
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("wrote \(icns)")

// README icon.
write(png(width: 512, height: 512) { icon.draw(in: $0) }, to: readmeIcon)

// Social preview: icon on the left, name and tagline on the right.
write(png(width: 1280, height: 640) { bounds in
    NSGradient(starting: previewBackgroundTop, ending: previewBackgroundBottom)!.draw(in: bounds, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = previewGlow
    glow.shadowBlurRadius = 90
    glow.set()
    icon.draw(in: NSRect(x: 96, y: 128, width: 384, height: 384))
    NSGraphicsContext.restoreGraphicsState()
    let title = NSAttributedString(string: "Sightglass", attributes: [
        .font: NSFont.systemFont(ofSize: 104, weight: .semibold),
        .foregroundColor: previewTitleColor,
    ])
    title.draw(at: NSPoint(x: 520, y: 318))
    let tagline = NSAttributedString(string: previewTagline, attributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .regular),
        .foregroundColor: previewTaglineColor,
    ])
    tagline.draw(in: NSRect(x: 524, y: 188, width: 700, height: 110))
}, to: socialPreview)
