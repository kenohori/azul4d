//
//  MetalView.swift
//  azul4d
//
//  Created by Ken Arroyo Ohori on 16/11/16.
//  Copyright © 2016 Ken Arroyo Ohori. All rights reserved.
//

import Metal
import MetalKit

struct Constants {
  var modelViewProjectionMatrix = matrix_identity_float4x4
}

struct Vertex {
  var position: float4
  var colour: float3
}

class MetalView: MTKView {
  
  var commandQueue: MTLCommandQueue?
  var renderPipelineState: MTLRenderPipelineState?
  var depthStencilState: MTLDepthStencilState?
  
  var eye = float3(0.0, 0.0, 0.0)
  var centre = float3(0.0, 0.0, -1.0)
  var fieldOfView: Float = 1.047197551196598
  
  var modelMatrix = matrix_identity_float4x4
  var viewMatrix = matrix_identity_float4x4
  var projectionMatrix = matrix_identity_float4x4
  
  var constants = Constants()
  var verticesBuffer: MTLBuffer?
  
  required init(coder: NSCoder) {
    
    super.init(coder: coder)
    
    // Device
    device = MTLCreateSystemDefaultDevice()
    
    // View
    clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1)
    colorPixelFormat = .bgra8Unorm
    depthStencilPixelFormat = .depth32Float
    
    // Command queue
    commandQueue = device!.makeCommandQueue()
    
    // Render pipeline
    let library = device!.newDefaultLibrary()!
    let vertexFunction = library.makeFunction(name: "vertexTransform")
    let fragmentFunction = library.makeFunction(name: "fragmentLit")
    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = vertexFunction
    renderPipelineDescriptor.fragmentFunction = fragmentFunction
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
    renderPipelineDescriptor.depthAttachmentPixelFormat = depthStencilPixelFormat
    do {
      renderPipelineState = try device!.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    } catch {
      Swift.print("Unable to compile render pipeline state")
      return
    }
    
    // Depth stencil
    let depthSencilDescriptor = MTLDepthStencilDescriptor()
    depthSencilDescriptor.depthCompareFunction = .less
    depthSencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device!.makeDepthStencilState(descriptor: depthSencilDescriptor)
    
    // Matrices
    modelMatrix = matrix4x4_translation(shift: centre)
    viewMatrix = matrix4x4_look_at(eye: eye, centre: centre, up: float3(0.0, 1.0, 0.0))
    projectionMatrix = matrix4x4_perspective(fieldOfView: fieldOfView, aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.01, farZ: 10.0)
    constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
    
    // Data
    let vertices = createTesseract()
//    let vertices: [Vertex] = [Vertex(position: float3(-1.0, -1.0, -1.0), colour: float3(1.0, 0.0, 0.0)),
//                              Vertex(position: float3(-1.0, 1.0, -1.0), colour: float3(0.0, 1.0, 0.0)),
//                              Vertex(position: float3(1.0, 1.0, -1.0), colour: float3(0.0, 0.0, 1.0))]
    verticesBuffer = device!.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.size*vertices.count, options: [])
  }
  
  override func draw(_ dirtyRect: NSRect) {
//    Swift.print("MetalView.draw(NSRect)")
    
    let commandBuffer = commandQueue!.makeCommandBuffer()
    let renderPassDescriptor = currentRenderPassDescriptor!
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    
    renderEncoder.setFrontFacing(.counterClockwise)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setRenderPipelineState(renderPipelineState!)
    
    let colour = sin(CACurrentMediaTime())
    clearColor = MTLClearColorMake(colour, colour, colour, 1.0)
    
    renderEncoder.setVertexBuffer(verticesBuffer, offset: 0, at: 0)
    renderEncoder.setVertexBytes(&constants, length: MemoryLayout<Constants>.size, at: 1)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    
    renderEncoder.endEncoding()
    let drawable = currentDrawable!
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  func triangulatePolygon(vertices: [Vertex]) -> [Vertex] {
    var triangulatedPolygon = [Vertex]()
    
    // Compute centroid
    var sumPosition = float4(0.0, 0.0, 0.0, 0.0)
    var sumColour = float3(0.0, 0.0, 0.0)
    for vertex in vertices {
      sumPosition += vertex.position
      sumColour += vertex.colour
    }
    let centroid = Vertex(position: float4(sumPosition.x/Float(vertices.count), sumPosition.y/Float(vertices.count), sumPosition.z/Float(vertices.count), sumPosition.w/Float(vertices.count)),
                          colour: float3(sumColour.x/Float(vertices.count), sumColour.y/Float(vertices.count), sumColour.z/Float(vertices.count)))
    
    // Generate triangles
    for vertexIndex in 1..<vertices.count {
      triangulatedPolygon.append(contentsOf: [vertices[vertexIndex-1], vertices[vertexIndex], centroid])
    }
    
    return triangulatedPolygon
  }
  
  func createTesseract() -> [Vertex] {
    let point_0000 = Vertex(position: float4(-1, -1, -1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_0001 = Vertex(position: float4(-1, -1, -1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_0010 = Vertex(position: float4(-1, -1, +1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_0011 = Vertex(position: float4(-1, -1, +1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_0100 = Vertex(position: float4(-1, +1, -1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_0101 = Vertex(position: float4(-1, +1, -1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_0110 = Vertex(position: float4(-1, +1, +1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_0111 = Vertex(position: float4(-1, +1, +1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_1000 = Vertex(position: float4(+1, -1, -1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_1001 = Vertex(position: float4(+1, -1, -1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_1010 = Vertex(position: float4(+1, -1, +1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_1011 = Vertex(position: float4(+1, -1, +1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_1100 = Vertex(position: float4(+1, +1, -1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_1101 = Vertex(position: float4(+1, +1, -1, +1), colour: float3(0.5, 0.5, 1.0))
    let point_1110 = Vertex(position: float4(+1, +1, +1, -1), colour: float3(0.5, 0.5, 1.0))
    let point_1111 = Vertex(position: float4(+1, +1, +1, +1), colour: float3(0.5, 0.5, 1.0))
    
    var tesseract = [Vertex]()
    
    // ffvv
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_0000, point_0001, point_0011, point_0010]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_0100, point_0101, point_0111, point_0110]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_1000, point_1001, point_1011, point_1010]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_1100, point_1101, point_1111, point_1110]))
    
    // fvfv
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_0000, point_0001, point_0101, point_0100]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_0010, point_0011, point_0111, point_0110]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_1000, point_1001, point_1101, point_1100]))
    tesseract.append(contentsOf: triangulatePolygon(vertices: [point_1010, point_1011, point_1111, point_1110]))
    
    return tesseract
  }
}
