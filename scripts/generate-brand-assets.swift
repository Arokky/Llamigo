import AppKit
import Foundation

let repoRoot = URL(fileURLWithPath: "/Users/michael/LlamaBarn-external-models", isDirectory: true)
let brandingSource = repoRoot.appendingPathComponent("Branding/Llamigo-v1.svg")
let appIconDir = repoRoot.appendingPathComponent("LlamaBarn/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let menuIconDir = repoRoot.appendingPathComponent("LlamaBarn/Assets.xcassets/MenuIcon.imageset", isDirectory: true)

struct Palette {
  static let background = NSColor(calibratedRed: 0.93, green: 0.95, blue: 0.94, alpha: 1)
}

func run(_ launchPath: String, _ arguments: [String]) throws {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: launchPath)
  task.arguments = arguments
  try task.run()
  task.waitUntilExit()
  if task.terminationStatus != 0 {
    throw NSError(
      domain: "Branding",
      code: Int(task.terminationStatus),
      userInfo: [NSLocalizedDescriptionKey: "Command failed: \(launchPath) \(arguments.joined(separator: " "))"]
    )
  }
}

func renderedSourcePNG() throws -> URL {
  let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  try run("/usr/bin/qlmanage", ["-t", "-s", "1024", "-o", tempDir.path, brandingSource.path])
  return tempDir.appendingPathComponent("\(brandingSource.lastPathComponent).png")
}

func pngData(from image: NSImage) -> Data? {
  guard let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff)
  else { return nil }
  return rep.representation(using: .png, properties: [:])
}

func cleanedSourceImage(from source: NSImage) -> NSImage {
  guard let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    return source
  }
  let rep = NSBitmapImageRep(cgImage: cgImage)

  let width = rep.pixelsWide
  let height = rep.pixelsHigh
  guard let bitmap = rep.bitmapData else { return source }
  let bytesPerPixel = rep.bitsPerPixel / 8
  let bytesPerRow = rep.bytesPerRow

  for x in 0..<width {
    for y in 0..<height {
      let offset = y * bytesPerRow + x * bytesPerPixel
      let red = CGFloat(bitmap[offset]) / 255
      let green = CGFloat(bitmap[offset + 1]) / 255
      let blue = CGFloat(bitmap[offset + 2]) / 255
      let alpha = bytesPerPixel > 3 ? CGFloat(bitmap[offset + 3]) / 255 : 1

      let brightness = (red + green + blue) / 3
      let maxChannel = max(red, green, blue)
      let minChannel = min(red, green, blue)
      let saturation = maxChannel - minChannel

      if alpha > 0.01 && brightness > 0.95 && saturation < 0.08 {
        bitmap[offset] = 0
        bitmap[offset + 1] = 0
        bitmap[offset + 2] = 0
        if bytesPerPixel > 3 {
          bitmap[offset + 3] = 0
        }
      }
    }
  }

  let image = NSImage(size: NSSize(width: width, height: height))
  image.addRepresentation(rep)
  return image
}

func makeAppIcon(from source: NSImage, size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  defer { image.unlockFocus() }

  let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
  NSColor.clear.setFill()
  rect.fill()

  let inset = size * 0.04
  let bgRect = rect.insetBy(dx: inset, dy: inset)
  let bg = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.22, yRadius: size * 0.22)
  Palette.background.setFill()
  bg.fill()

  let logoSize = size * 0.72
  let logoRect = CGRect(
    x: (size - logoSize) / 2,
    y: (size - logoSize) / 2 - size * 0.01,
    width: logoSize,
    height: logoSize
  )
  source.draw(in: logoRect)
  return image
}

func makeMenuTemplate(from source: NSImage, size: CGFloat) -> NSImage {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  defer { image.unlockFocus() }

  let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
  NSColor.clear.setFill()
  rect.fill()

  let logoSize = size * 0.90
  let logoRect = CGRect(
    x: (size - logoSize) / 2,
    y: (size - logoSize) / 2,
    width: logoSize,
    height: logoSize
  )

  NSColor.black.setFill()
  logoRect.fill()
  source.draw(in: logoRect, from: .zero, operation: .destinationIn, fraction: 1)
  return image
}

func writePDF(image: NSImage, to destination: URL) throws {
  var mediaBox = CGRect(origin: .zero, size: image.size)
  let data = NSMutableData()
  guard let consumer = CGDataConsumer(data: data as CFMutableData),
    let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
  else {
    throw NSError(domain: "Branding", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create PDF context"])
  }

  context.beginPDFPage(nil)
  let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphicsContext
  image.draw(in: mediaBox)
  NSGraphicsContext.restoreGraphicsState()
  context.endPDFPage()
  context.closePDF()
  try (data as Data).write(to: destination)
}

let sourcePNGURL = try renderedSourcePNG()
guard let rawSourceImage = NSImage(contentsOf: sourcePNGURL) else {
  throw NSError(domain: "Branding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load rendered source logo"])
}
let sourceImage = cleanedSourceImage(from: rawSourceImage)

let appIconSizes: [(String, CGFloat)] = [
  ("icon_16x16.png", 16),
  ("icon_16x16@2x.png", 32),
  ("icon_32x32.png", 32),
  ("icon_32x32@2x.png", 64),
  ("icon_128x128.png", 128),
  ("icon_128x128@2x.png", 256),
  ("icon_256x256.png", 256),
  ("icon_256x256@2x.png", 512),
  ("icon_512x512.png", 512),
  ("icon_512x512@2x.png", 1024),
]

for (filename, size) in appIconSizes {
  let image = makeAppIcon(from: sourceImage, size: size)
  let data = pngData(from: image)
  try data?.write(to: appIconDir.appendingPathComponent(filename))
}

let menuIcon = makeMenuTemplate(from: sourceImage, size: 64)
try writePDF(image: menuIcon, to: menuIconDir.appendingPathComponent("MenuIcon.pdf"))

let contents = """
{
  "images": [
    {
      "filename": "MenuIcon.pdf",
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  },
  "properties": {
    "template-rendering-intent": "template"
  }
}
"""
try contents.write(to: menuIconDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("Generated Llamigo brand assets from \(brandingSource.path)")
