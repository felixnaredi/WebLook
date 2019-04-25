//
//  Decode.swift
//  WebLook
//
//  Created by Felix Naredi on 2019-04-25.
//

import Foundation
import simd

/// Returns a value that is guaranted to be a multiple of `multiple`. The returned value will be in
/// the range `[value, value + multiple)`.
///
/// - Parameter value: The least value that can be returned.
/// - Parameter multiple: The returned value is guaranteed to be a multiple of this value.
fileprivate func align(_ value: Int, toMultiple multiple: Int) -> Int {
  return value + multiple - value % multiple
}

/// Invokes a given closure over a chunk of allocated memory. The memory is released after the
/// closure returns.
///
/// - Parameter size: Size of the allocated memory.
/// - Parameter body: Closure that takes the allocated memory as argument.
fileprivate func alloca<T, Result>(size: Int, _ body: (UnsafeMutablePointer<T>) -> Result) -> Result
{
  let memory = UnsafeMutablePointer<T>.allocate(capacity: size)
  let result = body(memory)
  memory.deallocate()
  return result
}

public struct WEBLDecoderDescriptor {
  public let imageSize: simd_float2
  public let corners: simd_float2x2
  public let colorspace: WEBP_CSP_MODE

  public var imageWidth: simd_float1 { return imageSize[0] }
  public var imageHeight: simd_float1 { return imageSize[1] }
  public var bottomLeftCorner: simd_float2 { return corners[0] }
  public var topRightCorner: simd_float2 { return corners[1] }
  public var visableWidth: simd_float1 { return (topRightCorner.x - bottomLeftCorner.x) }
  public var visableHeight: simd_float1 { return (topRightCorner.y - bottomLeftCorner.y) }

  public init(imageSize: simd_float2, corners: simd_float2x2, colorspace: WEBP_CSP_MODE = MODE_BGRA)
  {
    assert(colorspace == MODE_BGRA)

    self.imageSize = imageSize
    self.corners = corners
    self.colorspace = colorspace
  }

  public init(size: simd_float2, colorspace: WEBP_CSP_MODE = MODE_BGRA) {
    assert(colorspace == MODE_BGRA)

    self.init(imageSize: size, corners: simd_float2x2([0, 0], size), colorspace: colorspace)
  }

  private func withAllocatedBuffer<Result>(
    scanline: Int, _ body: (UnsafeMutablePointer<UInt8>) -> Result
  )
    -> Result
  {
    assert(colorspace == MODE_BGRA)

    return alloca(size: align(scanline * Int(imageHeight), toMultiple: 4096)) {
      (memory: UnsafeMutablePointer<UInt8>) in
      return body(memory)
    }
  }

  private func shouldUseScaling(features: WebPBitstreamFeatures) -> Bool {
    return Int32(imageWidth) != features.width || Int32(imageHeight) != features.height
  }

  private func decoderOptions(features: WebPBitstreamFeatures) -> WebPDecoderOptions {
    let useScaling = shouldUseScaling(features: features)
    return WebPDecoderOptions(
      bypass_filtering: 0,
      no_fancy_upsampling: 0,
      use_cropping: 0,
      crop_left: 0,
      crop_top: 0,
      crop_width: 0,
      crop_height: 0,
      use_scaling: useScaling ? 1 : 0,
      scaled_width: useScaling ? Int32(visableWidth) : 0,
      scaled_height: useScaling ? Int32(visableHeight) : 0,
      use_threads: 0,
      dithering_strength: 0,
      flip: 0,
      alpha_dithering_strength: 0,
      pad: (0, 0, 0, 0, 0))
  }

  fileprivate func withContext<Result>(
    features: WebPBitstreamFeatures, scanlineAlignment: Int,
    _ body: (inout WebPDecoderConfig) -> Result
  ) -> Result {
    assert(colorspace == MODE_BGRA)

    let scanline = align(Int(imageWidth) * 4, toMultiple: scanlineAlignment)
    return withAllocatedBuffer(scanline: scanline) { buffer in
      var context = WebPDecoderConfig(
        input: features,
        output: WebPDecBuffer(
          colorspace: colorspace,
          width: 0,
          height: 0,
          is_external_memory: 1,
          u: WebPDecBuffer.__Unnamed_union_u.init(
            RGBA: WebPRGBABuffer(
              rgba: buffer,
              stride: Int32(scanline),
              size: scanline * Int(imageHeight))),
          pad: (0, 0, 0, 0),
          private_memory: nil),
        options: decoderOptions(features: features))
      return body(&context)
    }
  }
}

/// Decodes the features of a WebP bitstream, i.e width and height of the image and if it has a
/// alpha channel.
///
/// - Parameter data: WebP encoded data.
/// - Parameter size: Size of the data.
fileprivate func decodeFeatures(data: UnsafePointer<UInt8>, size: Int) -> WebPBitstreamFeatures {
  var features = WebPBitstreamFeatures()
  WebPGetFeatures(data, size, &features)
  return features
}

/// Decodes a byte buffer containing data encoded in WebP and returns a tranformation of the
/// decoded data.
///
/// - Parameter data: Byte buffer containing the data.
/// - Parameter configureDecoding: Configures how the data should be decoded.
/// - Parameter transform: Transforms a buffer of decoded pixels from the WebP image.
public func WEBLDecodeWebP<Result>(
  _ data: Data, configureDecoding: (WebPBitstreamFeatures) -> WEBLDecoderDescriptor,
  transform: (WebPDecBuffer) -> Result
) -> Result? {
  return data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Result? in
    let features = decodeFeatures(data: bytes, size: data.count)
    let descriptor = configureDecoding(features)
    return descriptor.withContext(
      features: features, scanlineAlignment: 512,
      { config -> Result? in
        if WebPDecode(bytes, data.count, &config) != VP8_STATUS_OK { return nil }
        return transform(config.output)
      })
  }
}

/// Decodes a stream of WebP data and returnes a tranformation of it.
///
/// - Parameter stream: Stream of WebP data.
/// - Parameter bufferSize: Max amount of bytes that will be allocated when reading the stream.
/// - Parameter configureDecoding: Configures how the data should be decoded.
/// - Parameter transform: Transforms a buffer of decoded pixels from the WebP image.
public func WEBLDecodeWebP<Result>(
  _ stream: InputStream, bufferSize: Int = 65536,
  configureDecoding: (WebPBitstreamFeatures) -> WEBLDecoderDescriptor,
  transform: (WebPDecBuffer) -> Result
) -> Result? {
  return alloca(
    size: bufferSize,
    { (buffer: UnsafeMutablePointer<UInt8>) in
      stream.read(buffer, maxLength: bufferSize)
      let features = decodeFeatures(data: buffer, size: bufferSize)
      return configureDecoding(features).withContext(
        features: features, scanlineAlignment: 512,
        { config in
          let decoder = WebPIDecode(nil, 0, &config)
          repeat {
            let status = WebPIAppend(decoder, buffer, bufferSize)
            if status != VP8_STATUS_OK && status != VP8_STATUS_SUSPENDED { return nil }
          } while stream.read(buffer, maxLength: bufferSize) > 0
          WebPIDelete(decoder)
          return transform(config.output)
        })
    })
}
