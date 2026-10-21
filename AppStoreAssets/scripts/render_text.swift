// Renders text blocks to transparent PNGs with CoreText, so every script
// (Arabic/Hebrew shaping and RTL, Thai, Devanagari, CJK, Cyrillic...) lays out
// correctly. Used by render_store_assets.py.
//
//   render_text <manifest.json>
//
// Manifest: [{ "out": "path.png", "text": "line1\nline2", "kind": "display|text|kicker",
//              "size": 130, "minSize": 40, "maxWidth": 1100, "color": [242,245,241],
//              "rtl": false, "lineSpacing": 4, "latin": true }]
// "latin" selects Avenir Next (Condensed for display) when it covers every glyph;
// otherwise the system font (SF + automatic script fallback) is used.
import AppKit
import CoreText
import Foundation

struct Item: Decodable {
    let out: String
    let text: String
    let kind: String
    let size: Double
    let minSize: Double?
    let maxWidth: Double
    let color: [Int]
    let rtl: Bool?
    let lineSpacing: Double?
    let latin: Bool?
    let maxLines: Int?
}

func covers(_ font: NSFont, _ text: String) -> Bool {
    let ctFont = font as CTFont
    for scalar in text.unicodeScalars where !scalar.properties.isWhitespace {
        var glyph: CGGlyph = 0
        var char = UniChar(scalar.value & 0xFFFF)
        if scalar.value > 0xFFFF { return false }
        if !CTFontGetGlyphsForCharacters(ctFont, &char, &glyph, 1) || glyph == 0 { return false }
    }
    return true
}

func makeFont(kind: String, size: Double, text: String, latin: Bool) -> NSFont {
    let system: NSFont
    switch kind {
    case "display": system = NSFont.systemFont(ofSize: size, weight: .heavy)
    case "kicker": system = NSFont.systemFont(ofSize: size, weight: .bold)
    default: system = NSFont.systemFont(ofSize: size, weight: .medium)
    }
    guard latin else { return system }
    let name: String
    switch kind {
    case "display": name = "AvenirNextCondensed-Heavy"
    case "kicker": name = "AvenirNext-DemiBold"
    default: name = "AvenirNext-Medium"
    }
    if let font = NSFont(name: name, size: size), covers(font, text) { return font }
    return system
}

func layout(_ item: Item, size: Double) -> (NSAttributedString, CGSize) {
    let font = makeFont(kind: item.kind, size: size, text: item.text, latin: item.latin ?? true)
    let style = NSMutableParagraphStyle()
    style.alignment = (item.rtl ?? false) ? .right : .left
    style.baseWritingDirection = (item.rtl ?? false) ? .rightToLeft : .leftToRight
    style.lineSpacing = item.lineSpacing ?? 0
    style.lineBreakMode = .byWordWrapping
    let color = NSColor(
        calibratedRed: CGFloat(item.color[0]) / 255, green: CGFloat(item.color[1]) / 255,
        blue: CGFloat(item.color[2]) / 255, alpha: 1)
    let attributed = NSAttributedString(string: item.text, attributes: [
        .font: font, .foregroundColor: color, .paragraphStyle: style,
    ])
    let frameSetter = CTFramesetterCreateWithAttributedString(attributed)
    let fit = CTFramesetterSuggestFrameSizeWithConstraints(
        frameSetter, CFRange(location: 0, length: 0), nil,
        CGSize(width: item.maxWidth, height: .greatestFiniteMagnitude), nil)
    return (attributed, fit)
}

func widestLine(_ attributed: NSAttributedString, maxWidth: Double) -> Double {
    let frameSetter = CTFramesetterCreateWithAttributedString(attributed)
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: maxWidth, height: 100_000), transform: nil)
    let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
    let lines = CTFrameGetLines(frame) as! [CTLine]
    return lines.map { CTLineGetTypographicBounds($0, nil, nil, nil) }.max() ?? 0
}

func render(_ item: Item) {
    var size = item.size
    let minSize = item.minSize ?? size * 0.5
    var (attributed, fit) = layout(item, size: size)
    // Shrink until no explicit line needs wrapping (headlines are authored as 2 lines).
    let expectedLines = item.text.split(separator: "\n", omittingEmptySubsequences: false).count
    func lineCount(_ attributed: NSAttributedString) -> Int {
        let frameSetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: item.maxWidth, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
        return (CTFrameGetLines(frame) as NSArray).count
    }
    let allowedLines = item.maxLines ?? (item.kind == "display" ? expectedLines : Int.max)
    while size > minSize && lineCount(attributed) > allowedLines {
        size -= 2
        (attributed, fit) = layout(item, size: size)
    }
    _ = widestLine

    let width = Int(ceil(item.maxWidth)) + 8
    let height = Int(ceil(fit.height)) + 16
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fputs("context failed for \(item.out)\n", stderr); return }
    context.setShouldAntialias(true)
    context.setShouldSmoothFonts(false)
    let frameSetter = CTFramesetterCreateWithAttributedString(attributed)
    let path = CGPath(rect: CGRect(x: 4, y: 8, width: item.maxWidth, height: fit.height), transform: nil)
    let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
    CTFrameDraw(frame, context)
    guard let image = context.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: image)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: item.out))
}

guard CommandLine.arguments.count > 1,
      let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let items = try? JSONDecoder().decode([Item].self, from: data)
else { fputs("usage: render_text manifest.json\n", stderr); exit(2) }
for item in items { render(item) }
