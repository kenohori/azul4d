// azul4d
// Copyright © 2016 Ken Arroyo Ohori
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Metal
import MetalKit

struct RenderingConstants {
  var modelViewProjectionMatrix = matrix_identity_float4x4
}

struct ProjectionParameters {
  var transformationMatrix = matrix_identity_float4x4
}

struct Vertex {
  var position: float4
  var colour: float4
}

class MetalView: MTKView {
  
  var commandQueue: MTLCommandQueue?
  var computePipelineState: MTLComputePipelineState?
  var renderPipelineState: MTLRenderPipelineState?
  var depthStencilState: MTLDepthStencilState?
  
  var eye = float3(0.0, 0.0, 0.0)
  var centre = float3(0.0, 0.0, 5.0)
  var fieldOfView: Float = 1.047197551196598
  
  var modifierKey: Int = 0
  
  var modelMatrix = matrix_identity_float4x4
  var viewMatrix = matrix_identity_float4x4
  var projectionMatrix = matrix_identity_float4x4
  
  var renderingConstants = RenderingConstants()
  var projectionParameters = ProjectionParameters()
  var faces = [Vertex]()
  var edges = [Vertex]()
  var edgeVerticesCount = [UInt]()
  var vertices = [Vertex]()
  var faces4DBuffer: MTLBuffer?
  var faces3DBuffer: MTLBuffer?
  var edges4DBuffer: MTLBuffer?
  var edges3DBuffer: MTLBuffer?
  var edgesEdgesBuffer: MTLBuffer?
  var vertices4DBuffer: MTLBuffer?
  var vertices3DBuffer: MTLBuffer?
  var verticesFacesBuffer: MTLBuffer?
  
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
    
    // Library
    let library = device!.makeDefaultLibrary()!
    
    // Compute pipeline
    let projectionFunction = library.makeFunction(name: "stereographicProjection")
//    let projectionFunction = library.makeFunction(name: "orthographicProjection")
//    let projectionFunction = library.makeFunction(name: "longAxisProjection")
    do {
      computePipelineState = try device!.makeComputePipelineState(function: projectionFunction!)
    } catch {
      Swift.print("Unable to create compute pipeline state")
    }
    
    // Render pipeline
    let vertexFunction = library.makeFunction(name: "vertexLit")
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
    
    renderingConstants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
    
    // Create data
    let cppLink = CppLinkWrapperWrapper()!
//    cppLink.makeTesseract()
    cppLink.makeHouse()
//    cppLink.makeCorridor()
    
    // Get faces
    cppLink.initialiseFacesIterator()
    while !cppLink.facesIteratorEnded() {
      cppLink.initialiseFaceTrianglesIterator()
      let firstColourComponent = cppLink.currentFaceColour()
      let colourBuffer = UnsafeBufferPointer(start: firstColourComponent, count: 4)
      let colourArray = ContiguousArray(colourBuffer)
      let colour = [Float](colourArray)
      while !cppLink.faceTrianglesIteratorEnded() {
        for pointIndex in 0..<3 {
          let firstPointCoordinate = cppLink.currentFaceTriangleVertex(pointIndex)
          let pointCoordinatesBuffer = UnsafeBufferPointer(start: firstPointCoordinate, count: 4)
          let pointCoordinatesArray = ContiguousArray(pointCoordinatesBuffer)
          let pointCoordinates = [Float](pointCoordinatesArray)
//          Swift.print(pointCoordinates)
          faces.append(Vertex(position: float4(pointCoordinates[0], pointCoordinates[1], pointCoordinates[2], pointCoordinates[3]),
                              colour: float4(colour[0], colour[1], colour[2], colour[3])))
        }
        cppLink.advanceFaceTrianglesIterator()
      }
      cppLink.advanceFacesIterator()
    }
    Swift.print("\(faces.count) face vertices")
    faces4DBuffer = device!.makeBuffer(bytes: faces, length: MemoryLayout<Vertex>.size*faces.count, options: [])
    faces3DBuffer = device!.makeBuffer(length: MemoryLayout<Vertex>.size*faces.count, options: [])
    
    // Get edges
    cppLink.initialiseEdgesIterator()
    while !cppLink.edgesIteratorEnded() {
      cppLink.initialiseEdgeVerticesIterator()
      var verticesInEdgeCount: UInt = 0
      while !cppLink.edgeVerticesIteratorEnded() {
        let firstPointCoordinate = cppLink.currentEdgeVertex()
        let pointCoordinatesBuffer = UnsafeBufferPointer(start: firstPointCoordinate, count: 4)
        let pointCoordinatesArray = ContiguousArray(pointCoordinatesBuffer)
        let pointCoordinates = [Float](pointCoordinatesArray)
        edges.append(Vertex(position: float4(pointCoordinates[0], pointCoordinates[1], pointCoordinates[2], pointCoordinates[3]),
                            colour: float4(0.0, 0.0, 0.0, 1.0)))
//        Swift.print(edges.last!)
        verticesInEdgeCount += 1
        cppLink.advanceEdgeVerticesIterator()
      }
      edgeVerticesCount.append(verticesInEdgeCount)
      cppLink.advanceEdgesIterator()
    }
//    Swift.print(edgeVerticesCount)
    edges4DBuffer = device!.makeBuffer(bytes: edges, length: MemoryLayout<Vertex>.size*edges.count, options: [])
    edges3DBuffer = device!.makeBuffer(length: MemoryLayout<Vertex>.size*edges.count, options: [])
    
    // Get vertices
    cppLink.initialiseVerticesIterator()
    while !cppLink.verticesIteratorEnded() {
      let firstPointCoordinate = cppLink.currentVertex()
      let pointCoordinatesBuffer = UnsafeBufferPointer(start: firstPointCoordinate, count: 4)
      let pointCoordinatesArray = ContiguousArray(pointCoordinatesBuffer)
      let pointCoordinates = [Float](pointCoordinatesArray)
      vertices.append(Vertex(position: float4(pointCoordinates[0], pointCoordinates[1], pointCoordinates[2], pointCoordinates[3]),
                             colour: float4(0.0, 0.0, 0.0, 1.0)))
      cppLink.advanceVerticesIterator()
    }
    vertices4DBuffer = device!.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.size*vertices.count, options: [])
    vertices3DBuffer = device!.makeBuffer(length: MemoryLayout<Vertex>.size*vertices.count, options: [])
    
    
    // Project faces
    let facesCommandBuffer = commandQueue!.makeCommandBuffer()
    let facesComputeCommandEncoder = facesCommandBuffer!.makeComputeCommandEncoder()
    facesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    facesComputeCommandEncoder!.setBuffer(faces4DBuffer, offset: 0, index: 0)
    facesComputeCommandEncoder!.setBuffer(faces3DBuffer, offset: 0, index: 1)
    facesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let facesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let facesNumThreadGroups = MTLSize(width: faces.count/facesThreadsPerGroup.width, height: 1, depth: 1)
    facesComputeCommandEncoder!.dispatchThreadgroups(facesNumThreadGroups, threadsPerThreadgroup: facesThreadsPerGroup)
    facesComputeCommandEncoder!.endEncoding()
    facesCommandBuffer!.commit()
    
    // Project edges
    let edgesCommandBuffer = commandQueue!.makeCommandBuffer()
    let edgesComputeCommandEncoder = edgesCommandBuffer!.makeComputeCommandEncoder()
    edgesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    edgesComputeCommandEncoder!.setBuffer(edges4DBuffer, offset: 0, index: 0)
    edgesComputeCommandEncoder!.setBuffer(edges3DBuffer, offset: 0, index: 1)
    edgesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let edgesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let edgesNumThreadGroups = MTLSize(width: edges.count/edgesThreadsPerGroup.width, height: 1, depth: 1)
    edgesComputeCommandEncoder!.dispatchThreadgroups(edgesNumThreadGroups, threadsPerThreadgroup: edgesThreadsPerGroup)
    edgesComputeCommandEncoder!.endEncoding()
    edgesCommandBuffer!.commit()
    
    // Project vertices
    let verticesCommandBuffer = commandQueue!.makeCommandBuffer()
    let verticesComputeCommandEncoder = verticesCommandBuffer!.makeComputeCommandEncoder()
    verticesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    verticesComputeCommandEncoder!.setBuffer(vertices4DBuffer, offset: 0, index: 0)
    verticesComputeCommandEncoder!.setBuffer(vertices3DBuffer, offset: 0, index: 1)
    verticesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let verticesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let verticesNumThreadGroups = MTLSize(width: vertices.count/verticesThreadsPerGroup.width, height: 1, depth: 1)
    verticesComputeCommandEncoder!.dispatchThreadgroups(verticesNumThreadGroups, threadsPerThreadgroup: verticesThreadsPerGroup)
    verticesComputeCommandEncoder!.endEncoding()
    verticesCommandBuffer!.commit()
  }
  
  func generateVertices() {
    let radius: Float = 0.02
    let refinements: UInt = 1
    
    let vertexData = NSData(bytesNoCopy: vertices3DBuffer!.contents(), length: MemoryLayout<Vertex>.size*vertices.count, freeWhenDone: false)
    var projectedVertices = [Vertex](vertices)
    vertexData.getBytes(&projectedVertices, length: MemoryLayout<Vertex>.size*vertices.count)
    let goldenRatio: Float = (1.0+sqrtf(5.0))/2.0;
    let normalisingFactor: Float = sqrtf(goldenRatio*goldenRatio+1.0);
    
    var icosahedronVertices = [float4]()
    icosahedronVertices.append(float4(-1.0/normalisingFactor,  goldenRatio/normalisingFactor, 0.0, 0.0))
    icosahedronVertices.append(float4( 1.0/normalisingFactor,  goldenRatio/normalisingFactor, 0.0, 0.0))
    icosahedronVertices.append(float4(-1.0/normalisingFactor, -goldenRatio/normalisingFactor, 0.0, 0.0))
    icosahedronVertices.append(float4( 1.0/normalisingFactor, -goldenRatio/normalisingFactor, 0.0, 0.0))
    icosahedronVertices.append(float4(0.0, -1.0/normalisingFactor,  goldenRatio/normalisingFactor, 0.0))
    icosahedronVertices.append(float4(0.0,  1.0/normalisingFactor,  goldenRatio/normalisingFactor, 0.0))
    icosahedronVertices.append(float4(0.0, -1.0/normalisingFactor, -goldenRatio/normalisingFactor, 0.0))
    icosahedronVertices.append(float4(0.0,  1.0/normalisingFactor, -goldenRatio/normalisingFactor, 0.0))
    icosahedronVertices.append(float4( goldenRatio/normalisingFactor, 0.0, -1.0/normalisingFactor, 0.0))
    icosahedronVertices.append(float4( goldenRatio/normalisingFactor, 0.0,  1.0/normalisingFactor, 0.0))
    icosahedronVertices.append(float4(-goldenRatio/normalisingFactor, 0.0, -1.0/normalisingFactor, 0.0))
    icosahedronVertices.append(float4(-goldenRatio/normalisingFactor, 0.0,  1.0/normalisingFactor, 0.0))
    
    var verticesVertices = [Vertex]()
    for vertex in projectedVertices {
//      Swift.print(vertex)
      var vertexVertices = [Vertex]()
      
//      Swift.print("Vertex: \(vertex.position)")
//      Swift.print("Ico: \(vertex.position+icosahedronVertices[0])")
      vertexVertices.append(Vertex(position: icosahedronVertices[0], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[11], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[5], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[0], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[5], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[1], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[0], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[1], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[7], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[0], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[7], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[10], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[0], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[10], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[11], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[1], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[5], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[9], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[5], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[11], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[4], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[11], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[10], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[2], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[10], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[7], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[6], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[7], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[1], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[8], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[3], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[9], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[4], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[3], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[4], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[2], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[3], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[2], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[6], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[3], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[6], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[8], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[3], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[8], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[9], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[4], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[9], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[5], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[2], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[4], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[11], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[6], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[2], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[10], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[8], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[6], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[7], colour: vertex.colour))
      
      vertexVertices.append(Vertex(position: icosahedronVertices[9], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[8], colour: vertex.colour))
      vertexVertices.append(Vertex(position: icosahedronVertices[1], colour: vertex.colour))
      
      for _ in 0..<refinements {
        var vertexVerticesRefined = [Vertex]()
        
        for currentVertexVerticesIndex in 0..<vertexVertices.count/3 {
          let currentVertex0 = vertexVertices[3*currentVertexVerticesIndex]
          let currentVertex1 = vertexVertices[3*currentVertexVerticesIndex+1]
          let currentVertex2 = vertexVertices[3*currentVertexVerticesIndex+2]
          
          var midPoint01 = Vertex(position: 0.5*(currentVertex0.position+currentVertex1.position), colour: currentVertex0.colour)
          var midPoint12 = Vertex(position: 0.5*(currentVertex1.position+currentVertex2.position), colour: currentVertex1.colour)
          var midPoint20 = Vertex(position: 0.5*(currentVertex2.position+currentVertex0.position), colour: currentVertex2.colour)
          
          let midPointDistanceToOrigin: Float = sqrtf(midPoint01.position.x*midPoint01.position.x+midPoint01.position.y*midPoint01.position.y+midPoint01.position.z*midPoint01.position.z)
          midPoint01.position *= 1.0/midPointDistanceToOrigin
          midPoint12.position *= 1.0/midPointDistanceToOrigin
          midPoint20.position *= 1.0/midPointDistanceToOrigin
          
          vertexVerticesRefined.append(currentVertex0)
          vertexVerticesRefined.append(midPoint01)
          vertexVerticesRefined.append(midPoint20)
          
          vertexVerticesRefined.append(currentVertex1)
          vertexVerticesRefined.append(midPoint12)
          vertexVerticesRefined.append(midPoint01)
          
          vertexVerticesRefined.append(currentVertex2)
          vertexVerticesRefined.append(midPoint20)
          vertexVerticesRefined.append(midPoint12)
          
          vertexVerticesRefined.append(midPoint01)
          vertexVerticesRefined.append(midPoint12)
          vertexVerticesRefined.append(midPoint20)
        }
        
        vertexVertices = vertexVerticesRefined
      }
      
      var vertexVerticesTranslated = [Vertex]()
      for vertexVertex in vertexVertices {
        vertexVerticesTranslated.append(Vertex(position: vertex.position+(radius*vertexVertex.position), colour: vertex.colour))
      }
      
      verticesVertices.append(contentsOf: vertexVerticesTranslated)
    }
    
    verticesFacesBuffer = device!.makeBuffer(bytes: verticesVertices, length: MemoryLayout<Vertex>.size*verticesVertices.count, options: [])
  }
  
  func generateEdges() {
    
    let edgeData = NSData(bytesNoCopy: edges3DBuffer!.contents(), length: MemoryLayout<Vertex>.size*edges.count, freeWhenDone: false)
    var projectedEdges = [Vertex](edges)
    edgeData.getBytes(&projectedEdges, length: MemoryLayout<Vertex>.size*edges.count)
    
    var startIndex: Int = 0
    var edgeEdges = [Vertex]()
    for verticesCountInCurrentEdge in edgeVerticesCount {
      let endIndex: Int = startIndex+Int(verticesCountInCurrentEdge)-1
//      Swift.print("Start: \(startIndex) End: \(endIndex)")
      
      for startSubindex in startIndex..<endIndex {
        let endSubindex: Int = startSubindex+1
        
        edgeEdges.append(projectedEdges[startSubindex])
        edgeEdges.append(projectedEdges[endSubindex])
      }
      
      startIndex += Int(verticesCountInCurrentEdge)
    }
    
    edgesEdgesBuffer = device!.makeBuffer(bytes: edgeEdges, length: MemoryLayout<Vertex>.size*edgeEdges.count, options: [])
  }
  
  override var acceptsFirstResponder: Bool {
    return true
  }
  
  override func draw(_ dirtyRect: NSRect) {
//    Swift.print("MetalView.draw(NSRect)")
    
    let commandBuffer = commandQueue!.makeCommandBuffer()
    let renderPassDescriptor = currentRenderPassDescriptor!
    let renderEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    
    renderEncoder!.setFrontFacing(.counterClockwise)
    renderEncoder!.setDepthStencilState(depthStencilState)
    renderEncoder!.setRenderPipelineState(renderPipelineState!)
    
//    let colour = sin(CACurrentMediaTime())
//    clearColor = MTLClearColorMake(colour, colour, colour, 1.0)
    
    if verticesFacesBuffer != nil {
      renderEncoder!.setVertexBuffer(verticesFacesBuffer, offset: 0, index: 0)
      renderEncoder!.setVertexBytes(&renderingConstants, length: MemoryLayout<RenderingConstants>.size, index: 1)
      renderEncoder!.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: verticesFacesBuffer!.length/MemoryLayout<Vertex>.size)
    }
    
    if edgesEdgesBuffer != nil {
      renderEncoder!.setVertexBuffer(edgesEdgesBuffer, offset: 0, index: 0)
      renderEncoder!.setVertexBytes(&renderingConstants, length: MemoryLayout<RenderingConstants>.size, index: 1)
      renderEncoder!.drawPrimitives(type: .line, vertexStart: 0, vertexCount: edgesEdgesBuffer!.length/MemoryLayout<Vertex>.size)
    }
    
    renderEncoder!.setVertexBuffer(faces3DBuffer, offset: 0, index: 0)
    renderEncoder!.setVertexBytes(&renderingConstants, length: MemoryLayout<RenderingConstants>.size, index: 1)
    renderEncoder!.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: faces3DBuffer!.length/MemoryLayout<Vertex>.size)
    
    renderEncoder!.endEncoding()
    let drawable = currentDrawable!
    commandBuffer!.present(drawable)
    commandBuffer!.commit()
    
    generateVertices()
    generateEdges()
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    projectionMatrix = matrix4x4_perspective(fieldOfView: fieldOfView, aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.001, farZ: 100.0)
    renderingConstants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
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
    renderingConstants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
  }
  
  override func magnify(with event: NSEvent) {
    //    Swift.print("MetalView.magnify()")
    //    Swift.print("Pinched: \(event.magnification)")
    let magnification: Float = 1.0+Float(event.magnification)
    fieldOfView = 2.0*atanf(tanf(0.5*fieldOfView)/magnification)
    //    Swift.print("Field of view: \(fieldOfView)")
    projectionMatrix = matrix4x4_perspective(fieldOfView: fieldOfView, aspectRatio: Float(bounds.size.width / bounds.size.height), nearZ: 0.001, farZ: 100.0)
    
    // Put model matrix in arrays and render
    renderingConstants.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
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
    if modifierKey == 0 {
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
      projectionParameters.transformationMatrix = matrix_multiply(rotationXY, projectionParameters.transformationMatrix)
      projectionParameters.transformationMatrix = matrix_multiply(rotationZW, projectionParameters.transformationMatrix)
    } else if modifierKey == 1 {
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
      projectionParameters.transformationMatrix = matrix_multiply(rotationYZ, projectionParameters.transformationMatrix)
      projectionParameters.transformationMatrix = matrix_multiply(rotationWX, projectionParameters.transformationMatrix)
    } else {
      let angleX = currentX-lastX
      let rotationXZ = matrix_from_columns(vector4(cos(angleX), 0.0, -sin(angleX), 0.0),
                                           vector4(0.0, 1.0, 0.0, 0.0),
                                           vector4(sin(angleX), 0.0, cos(angleX), 0.0),
                                           vector4(0.0, 0.0, 0.0, 1.0))
      let angleY = currentY-lastY
      let rotationYW = matrix_from_columns(vector4(1.0, 0.0, 0.0, 0.0),
                                           vector4(0.0, cos(angleY), 0.0, sin(angleY)),
                                           vector4(0.0, 0.0, 1.0, 0.0),
                                           vector4(0.0, -sin(angleY), 0.0, cos(angleY)))
      projectionParameters.transformationMatrix = matrix_multiply(rotationXZ, projectionParameters.transformationMatrix)
      projectionParameters.transformationMatrix = matrix_multiply(rotationYW, projectionParameters.transformationMatrix)
    }

    // Project faces
    let facesCommandBuffer = commandQueue!.makeCommandBuffer()
    let facesComputeCommandEncoder = facesCommandBuffer!.makeComputeCommandEncoder()
    facesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    facesComputeCommandEncoder!.setBuffer(faces4DBuffer, offset: 0, index: 0)
    facesComputeCommandEncoder!.setBuffer(faces3DBuffer, offset: 0, index: 1)
    facesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let facesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let facesNumThreadGroups = MTLSize(width: faces.count/facesThreadsPerGroup.width, height: 1, depth: 1)
    facesComputeCommandEncoder!.dispatchThreadgroups(facesNumThreadGroups, threadsPerThreadgroup: facesThreadsPerGroup)
    facesComputeCommandEncoder!.endEncoding()
    facesCommandBuffer!.commit()
    
    // Project edges
    let edgesCommandBuffer = commandQueue!.makeCommandBuffer()
    let edgesComputeCommandEncoder = edgesCommandBuffer!.makeComputeCommandEncoder()
    edgesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    edgesComputeCommandEncoder!.setBuffer(edges4DBuffer, offset: 0, index: 0)
    edgesComputeCommandEncoder!.setBuffer(edges3DBuffer, offset: 0, index: 1)
    edgesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let edgesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let edgesNumThreadGroups = MTLSize(width: edges.count/edgesThreadsPerGroup.width, height: 1, depth: 1)
    edgesComputeCommandEncoder!.dispatchThreadgroups(edgesNumThreadGroups, threadsPerThreadgroup: edgesThreadsPerGroup)
    edgesComputeCommandEncoder!.endEncoding()
    edgesCommandBuffer!.commit()
    
    // Project vertices
    let verticesCommandBuffer = commandQueue!.makeCommandBuffer()
    let verticesComputeCommandEncoder = verticesCommandBuffer!.makeComputeCommandEncoder()
    verticesComputeCommandEncoder!.setComputePipelineState(computePipelineState!)
    verticesComputeCommandEncoder!.setBuffer(vertices4DBuffer, offset: 0, index: 0)
    verticesComputeCommandEncoder!.setBuffer(vertices3DBuffer, offset: 0, index: 1)
    verticesComputeCommandEncoder!.setBytes(&projectionParameters, length: MemoryLayout<ProjectionParameters>.size, index: 2)
    let verticesThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
    let verticesNumThreadGroups = MTLSize(width: vertices.count/verticesThreadsPerGroup.width, height: 1, depth: 1)
    verticesComputeCommandEncoder!.dispatchThreadgroups(verticesNumThreadGroups, threadsPerThreadgroup: verticesThreadsPerGroup)
    verticesComputeCommandEncoder!.endEncoding()
    verticesCommandBuffer!.commit()
  }
  
  override func flagsChanged(with event: NSEvent) {
    Swift.print("Flags changed: \(event.modifierFlags.contains(.command) || event.modifierFlags.contains(.shift))")
    if event.modifierFlags.contains(.command) {
      modifierKey = 1
    } else if event.modifierFlags.contains(.shift) {
      modifierKey = 2
    } else {
      modifierKey = 0
    }
  }
}
