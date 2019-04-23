//
//  Renderer.swift
//  macOS
//
//  Created by Felix Naredi on 2019-04-23.
//

import MetalKit
import simd

fileprivate func quadVerticesBuffer(with device: MTLDevice) -> MTLBuffer {
  return [
    WEBLVertex(position: float2(1, -1), textureCoordinate: float2(1, 1)),
    WEBLVertex(position: float2(-1, -1), textureCoordinate: float2(0, 1)),
    WEBLVertex(position: float2(-1, 1), textureCoordinate: float2(0, 0)),
    WEBLVertex(position: float2(1, -1), textureCoordinate: float2(1, 1)),
    WEBLVertex(position: float2(-1, 1), textureCoordinate: float2(0, 0)),
    WEBLVertex(position: float2(1, 1), textureCoordinate: float2(1, 0)),
  ].withUnsafeBytes({ (buffer) -> MTLBuffer in
    return device.makeBuffer(
      bytes: buffer.baseAddress!, length: MemoryLayout<WEBLVertex>.stride * buffer.count,
      options: .storageModeManaged)!
  })
}

class Renderer: NSObject, MTKViewDelegate {
  enum Error: Swift.Error {
    case failedToCreateMetalDevice
    case failedToCreateMetalObject(_ object: Any, device: MTLDevice)
  }

  class View: MTKView {
    var texture: MTLTexture?
  }

  let device: MTLDevice
  let colorPixelFormat: MTLPixelFormat
  private let commandQueue: MTLCommandQueue
  private let pipelineState: MTLRenderPipelineState
  private let vertexBuffer: MTLBuffer

  init(with colorPixelFormat: MTLPixelFormat) throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw Error.failedToCreateMetalDevice }
    self.device = device

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let library = device.makeDefaultLibrary()!
    pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")!
    pipelineDescriptor.fragmentFunction = library.makeFunction(name: "samplingsShader")!
    pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat

    self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

    self.commandQueue = device.makeCommandQueue()!
    self.vertexBuffer = quadVerticesBuffer(with: device)
    self.colorPixelFormat = colorPixelFormat
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    let view = view as! View
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let renderPassDescriptor = view.currentRenderPassDescriptor!

    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    renderEncoder.setFragmentTexture(view.texture!, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    renderEncoder.endEncoding()

    commandBuffer.present(view.currentDrawable!)
    commandBuffer.commit()
  }

}

