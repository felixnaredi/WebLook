//
//  Renderer.swift
//  macOS
//
//  Created by Felix Naredi on 2019-04-23.
//

import Foundation
import Metal

fileprivate func unsafeWebPDecodeBGRA<Result>(
  with data: Data, _ body: @escaping (UnsafeBufferPointer<UInt8>, Int, Int) -> Result
) -> Result {
  return
    data.withUnsafeBytes({ (pointer: UnsafePointer<UInt8>) -> Result in
    var width = Int32(0)
    var height = Int32(0)
    let content = WebPDecodeBGRA(pointer, data.count, &width, &height)

    let result = body(
      UnsafeBufferPointer(start: content, count: Int(width * height)), Int(width), Int(height))

    WebPFree(content)
    return result
  })
}

func makeWebPTexture(with device: MTLDevice, data: Data) -> MTLTexture {
  return unsafeWebPDecodeBGRA(
    with: data,
    { (buffer, width, height) -> MTLTexture in
      let textureDescriptor = MTLTextureDescriptor()
      textureDescriptor.pixelFormat = .bgra8Unorm
      textureDescriptor.width = width
      textureDescriptor.height = height

      let texture = device.makeTexture(descriptor: textureDescriptor)!
      texture.replace(
        region: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0,
        withBytes: buffer.baseAddress!,
        bytesPerRow: width * 4)
      return texture
    })
}
