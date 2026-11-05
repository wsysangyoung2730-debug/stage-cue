import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.263, green: 0.294, blue: 0.800, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 180, y: 255, width: 664, height: 540), xRadius: 148, yRadius: 148).fill()
let tail = NSBezierPath()
tail.move(to: NSPoint(x: 285, y: 300))
tail.line(to: NSPoint(x: 285, y: 170))
tail.line(to: NSPoint(x: 440, y: 300))
tail.close()
tail.fill()
NSColor(calibratedRed: 0.263, green: 0.294, blue: 0.800, alpha: 1).setFill()
for x: CGFloat in [336, 546] {
    NSBezierPath(ovalIn: NSRect(x: x, y: 506, width: 142, height: 142)).fill()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x + 122, y: 540))
    path.curve(to: NSPoint(x: x + 40, y: 410), controlPoint1: NSPoint(x: x + 150, y: 466), controlPoint2: NSPoint(x: x + 88, y: 428))
    path.lineWidth = 42
    path.lineCapStyle = .round
    path.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
