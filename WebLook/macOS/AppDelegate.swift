//
//  AppDelegate.swift
//  macOS
//
//  Created by Felix Naredi on 2019-04-23.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  private var imageWindows = [NSWindow]()
  private let renderer = try! Renderer(with: .bgra8Unorm)

  @IBAction func openButtonClicked(_ sender: Any?) {
    let openPanel = NSOpenPanel()
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.canChooseFiles = true
    openPanel.allowedFileTypes = ["webp"]

    openPanel.begin(completionHandler: { response in
      if response != .OK { return }

      let device = self.renderer.device
      let colorPixelFormat = self.renderer.colorPixelFormat

      let url = openPanel.url!
      let texture = makeWebPTexture(with: device, data: try! Data(contentsOf: url))
      let width = texture.width
      let height = texture.height

      let view = Renderer.View(frame: NSRect(x: 0, y: 0, width: width, height: height))
      view.delegate = self.renderer
      view.device = device
      view.colorPixelFormat = colorPixelFormat
      view.texture = texture

      let window = NSWindow(
        contentRect: NSRect(x: 100, y: 100, width: width, height: height),
        styleMask: [.titled, .closable], backing: .buffered, defer: false)
      window.contentView = view
      window.makeKeyAndOrderFront(self)
      window.title = url.lastPathComponent

      // TODO: Remove windows from array when closed.
      self.imageWindows.append(window)
    })
  }

}

