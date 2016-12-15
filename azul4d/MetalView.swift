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
  var colour: float4
}

class MetalView: MTKView {
  
  var commandQueue: MTLCommandQueue?
  var renderPipelineState: MTLRenderPipelineState?
  var depthStencilState: MTLDepthStencilState?
  
  var eye = float3(0.0, 0.0, 0.0)
  var centre = float3(0.0, 0.0, 5.0)
  var fieldOfView: Float = 1.047197551196598
  
  var modifierKey: Bool = false
  
  var transformationMatrix = matrix_identity_float4x4
  
  var modelMatrix = matrix_identity_float4x4
  var viewMatrix = matrix_identity_float4x4
  var projectionMatrix = matrix_identity_float4x4
  
  var constants = Constants()
  
  var vertices4D = [Vertex]()
  var vertices3D = [Vertex]()
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
    renderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
    renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
    renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
    renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
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
//    depthSencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device!.makeDepthStencilState(descriptor: depthSencilDescriptor)
    
    // Matrices
    modelMatrix = matrix4x4_translation(shift: centre)
    viewMatrix = matrix4x4_look_at(eye: eye, centre: centre, up: float3(0.0, 1.0, 0.0))
    projectionMatrix = matrix4x4_perspective(fieldOfView: fieldOfView, aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.01, farZ: 10.0)
    
    constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
    
    // Data
    let cppLink = CppLinkWrapperWrapper()!
    cppLink.makeTesseract()
    cppLink.initialiseMeshIterator()
    while !cppLink.meshIteratorEnded() {
      cppLink.initialiseTriangleIterator()
      let firstColourComponent = cppLink.currentMeshColour()
      let colourBuffer = UnsafeBufferPointer(start: firstColourComponent, count: 4)
      let colourArray = ContiguousArray(colourBuffer)
      let colour = [Float](colourArray)
      while !cppLink.triangleIteratorEnded() {
        for pointIndex in 0..<3 {
          let firstPointCoordinate = cppLink.currentTriangleVertex(pointIndex)
          let pointCoordinatesBuffer = UnsafeBufferPointer(start: firstPointCoordinate, count: 4)
          let pointCoordinatesArray = ContiguousArray(pointCoordinatesBuffer)
          let pointCoordinates = [Float](pointCoordinatesArray)
//          Swift.print(pointCoordinates)
          vertices4D.append(Vertex(position: float4(pointCoordinates[0], pointCoordinates[1], pointCoordinates[2], pointCoordinates[3]),
                                   colour: float4(colour[0], colour[1], colour[2], colour[3])))
        }
        cppLink.advanceTriangleIterator()
      }
      cppLink.advanceMeshIterator()
    }
    transformVertices()
  }
  
  override var acceptsFirstResponder: Bool {
    return true
  }
  
  func transformVertices() {
    
    vertices3D.removeAll()
    for vertex in vertices4D {
      
      // Apply 4D transformation
      let transformedVertex: float4 = matrix_multiply(transformationMatrix, vertex.position)
      
      // Project from R4 to S3
      let r: Float = sqrt(transformedVertex.x*transformedVertex.x+transformedVertex.y*transformedVertex.y+transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w)
      var point_s3: float3 = float3(0.0, 0.0, 0.0)
      
      if r != 0.0 {
        point_s3.x = acos(transformedVertex.x/r)
      } else {
        if transformedVertex.x >= 0.0 {
          point_s3.x = 0.0
        } else {
          point_s3.x = 3.141592653589793
        }
      }
      
      if transformedVertex.y*transformedVertex.y+transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w != 0 {
        point_s3.y = acos(transformedVertex.y/sqrt(transformedVertex.y*transformedVertex.y+transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w))
      } else {
        if transformedVertex.y >= 0.0 {
          point_s3.y = 0.0
        } else {
          point_s3.y = 3.141592653589793
        }
      }
      
      if transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w != 0 {
        if transformedVertex.w >= 0.0 {
          point_s3.z = acos(transformedVertex.z/sqrt(transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w))
        } else {
          point_s3.z = -acos(transformedVertex.z/sqrt(transformedVertex.z*transformedVertex.z+transformedVertex.w*transformedVertex.w))
        }
      } else {
        if transformedVertex.w >= 0.0 {
          point_s3.z = 0.0
        } else {
          point_s3.z = 3.141592653589793
        }
      }
      
      // Project from S3 to R4
      var point_r4: float4 = float4(0.0, 0.0, 0.0, 0.0)
      point_r4.x = cos(point_s3.x)
      point_r4.y = sin(point_s3.x)*cos(point_s3.y)
      point_r4.z = sin(point_s3.x)*sin(point_s3.y)*cos(point_s3.z)
      point_r4.w = sin(point_s3.x)*sin(point_s3.y)*sin(point_s3.z)
      
      // Project from R4 to R3
      var point_r3: float3 = float3(0.0, 0.0, 0.0)
      point_r3.x = point_r4.x/(point_r4.w-1)
      point_r3.y = point_r4.y/(point_r4.w-1)
      point_r3.z = point_r4.z/(point_r4.w-1)
      
      vertices3D.append(Vertex(position: float4(point_r3.x, point_r3.y, point_r3.z, 1.0), colour: vertex.colour))
    }
    
    // Load into buffer
    verticesBuffer = device!.makeBuffer(bytes: vertices3D, length: MemoryLayout<Vertex>.size*vertices3D.count, options: [])
  }
  
  override func draw(_ dirtyRect: NSRect) {
//    Swift.print("MetalView.draw(NSRect)")
    
    let commandBuffer = commandQueue!.makeCommandBuffer()
    let renderPassDescriptor = currentRenderPassDescriptor!
    let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    
    renderEncoder.setFrontFacing(.counterClockwise)
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setRenderPipelineState(renderPipelineState!)
    
//    let colour = sin(CACurrentMediaTime())
//    clearColor = MTLClearColorMake(colour, colour, colour, 1.0)
    
    renderEncoder.setVertexBuffer(verticesBuffer, offset: 0, at: 0)
    renderEncoder.setVertexBytes(&constants, length: MemoryLayout<Constants>.size, at: 1)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verticesBuffer!.length/MemoryLayout<Vertex>.size)
    
    renderEncoder.endEncoding()
    let drawable = currentDrawable!
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    projectionMatrix = matrix4x4_perspective(fieldOfView: fieldOfView, aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.001, farZ: 100.0)
    constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
    needsDisplay = true
  }
  
  override func scrollWheel(with event: NSEvent) {
    //    Swift.print("MetalView.scrollWheel()")
    //    Swift.print("Scrolled X: \(event.scrollingDeltaX) Y: \(event.scrollingDeltaY)")
    
    // Motion according to trackpad
    let scrollingSensitivity: Float = 0.003*(fieldOfView/(3.141519/4.0))
    let motionInCameraCoordinates = float3(scrollingSensitivity*Float(event.scrollingDeltaX), -scrollingSensitivity*Float(event.scrollingDeltaY), 0.0)
    let cameraToObject = matrix_invert(matrix_upper_left_3x3(matrix: matrix_multiply(viewMatrix, modelMatrix)))
    let motionInObjectCoordinates = matrix_multiply(cameraToObject, motionInCameraCoordinates)
    modelMatrix = matrix_multiply(modelMatrix, matrix4x4_translation(shift: motionInObjectCoordinates))
    
    // Put model matrix in arrays and render
    constants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
  }
  
  override func mouseDragged(with event: NSEvent) {
    let viewFrameInWindowCoordinates = convert(bounds, to: nil)
    
    // Compute the current and last mouse positions
    let currentX: Float = Float((window!.mouseLocationOutsideOfEventStream.x-viewFrameInWindowCoordinates.origin.x) / bounds.size.width)
    let currentY: Float = Float((window!.mouseLocationOutsideOfEventStream.y-viewFrameInWindowCoordinates.origin.y) / bounds.size.height)
    let lastX: Float = Float(((window!.mouseLocationOutsideOfEventStream.x-viewFrameInWindowCoordinates.origin.x)-event.deltaX) / bounds.size.width)
    let lastY: Float = Float(((window!.mouseLocationOutsideOfEventStream.y-viewFrameInWindowCoordinates.origin.y)+event.deltaY) / bounds.size.height)
    if currentX == lastX && currentY == lastY {
      return
    }
    
    // Compute the motions and apply them
    if !modifierKey {
      let angleX = currentX-lastX
      let rotationXY = matrix_from_columns(vector4(cos(angleX), -sin(angleX), 0.0, 0.0),
                                           vector4(sin(angleX), cos(angleX), 0.0, 0.0),
                                           vector4(0.0, 0.0, 1.0, 0.0),
                                           vector4(0.0, 0.0, 0.0, 1.0))
      let angleY = currentY-lastY
      let rotationZW = matrix_from_columns(vector4(1.0, 0.0, 0.0, 0.0),
                                           vector4(0.0, 1.0, 0.0, 0.0),
                                           vector4(0.0, 0.0, cos(angleY), -sin(angleY)),
                                           vector4(0.0, 0.0, sin(angleY), cos(angleY)))
      transformationMatrix = matrix_multiply(rotationXY, transformationMatrix)
      transformationMatrix = matrix_multiply(rotationZW, transformationMatrix)
    } else {
      let angleX = currentX-lastX
      let rotationYZ = matrix_from_columns(vector4(1.0, 0.0, 0.0, 0.0),
                                           vector4(0.0, cos(angleX), -sin(angleX), 0.0),
                                           vector4(0.0, sin(angleX), cos(angleX), 0.0),
                                           vector4(0.0, 0.0, 0.0, 1.0))
      let angleY = currentY-lastY
      let rotationWX = matrix_from_columns(vector4(cos(angleY), 0.0, 0.0, sin(angleY)),
                                           vector4(0.0, 1.0, 0.0, 0.0),
                                           vector4(0.0, 0.0, 1.0, 0.0),
                                           vector4(-sin(angleY), 0.0, 0.0, cos(angleY)))
      transformationMatrix = matrix_multiply(rotationYZ, transformationMatrix)
      transformationMatrix = matrix_multiply(rotationWX, transformationMatrix)
    }
    transformVertices()
  }
  
  override func flagsChanged(with event: NSEvent) {
    Swift.print("Flags changed: \(event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift))")
    if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift) {
      modifierKey = true
    } else {
      modifierKey = false
    }
  }
}
