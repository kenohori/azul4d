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

- (void) makeHouse {
  cppLinkWrapper->cppLink->makeHouse();
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
