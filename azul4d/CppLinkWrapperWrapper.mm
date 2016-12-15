//
//  CppLinkWrapperWrapper.m
//  azul4d
//
//  Created by Ken Arroyo Ohori on 05/12/16.
//  Copyright © 2016 Ken Arroyo Ohori. All rights reserved.
//

#import "CppLinkWrapperWrapper.h"
#import "CppLink.hpp"

struct CppLinkWrapper {
  CppLink *cppLink;
};

@implementation CppLinkWrapperWrapper

- (id) init {
  if (self = [super init]) {
    cppLinkWrapper = new CppLinkWrapper();
    cppLinkWrapper->cppLink = new CppLink();
  } return self;
}

- (void) makeTesseract {
  cppLinkWrapper->cppLink->makeTesseract();
}

- (void) iterateOverFaces {
  cppLinkWrapper->cppLink->currentModelPart = cppLinkWrapper->cppLink->currentModelFaces;
}

- (void) iterateOverEdges {
  cppLinkWrapper->cppLink->currentModelPart = cppLinkWrapper->cppLink->currentModelEdges;
}

- (void) iterateOverVertices {
  cppLinkWrapper->cppLink->currentModelPart = cppLinkWrapper->cppLink->currentModelVertices;
}

- (void) initialiseMeshIterator {
  cppLinkWrapper->cppLink->currentMesh = cppLinkWrapper->cppLink->currentModelPart.begin();
}

- (void) advanceMeshIterator {
  ++cppLinkWrapper->cppLink->currentMesh;
}

- (BOOL) meshIteratorEnded {
  return cppLinkWrapper->cppLink->currentMesh == cppLinkWrapper->cppLink->currentModelPart.end();
}

- (void) initialiseTriangleIterator {
  cppLinkWrapper->cppLink->currentTriangle = cppLinkWrapper->cppLink->currentMesh->triangles.begin();
}

- (void) advanceTriangleIterator {
  ++cppLinkWrapper->cppLink->currentTriangle;
}

- (BOOL) triangleIteratorEnded {
  return cppLinkWrapper->cppLink->currentTriangle == cppLinkWrapper->cppLink->currentMesh->triangles.end();
}

- (const float *)currentTriangleVertex: (long)index {
  for (unsigned int i = 0; i < 4; ++i) {
    cppLinkWrapper->cppLink->currentPointCoordinates[i] = cppLinkWrapper->cppLink->currentTriangle->vertices[index].cartesian(i);
  } return cppLinkWrapper->cppLink->currentPointCoordinates; 
}

- (const float *)currentMeshColour {
  return cppLinkWrapper->cppLink->currentMesh->colour;
}

- (void) dealloc {
  delete cppLinkWrapper->cppLink;
  delete cppLinkWrapper;
}

@end
