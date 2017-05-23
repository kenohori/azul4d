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

#ifndef CppLinkWrapperWrapper_h
#define CppLinkWrapperWrapper_h

#import <Cocoa/Cocoa.h>

struct CppLinkWrapper;

@interface CppLinkWrapperWrapper: NSObject {
  struct CppLinkWrapper *cppLinkWrapper;
}

- (id) init;
- (void) makeTesseract;
- (void) makeHouse;
- (void) makeCorridor;

- (void) initialiseFacesIterator;
- (void) advanceFacesIterator;
- (BOOL) facesIteratorEnded;
- (const float *)currentFaceColour;
- (void) initialiseFaceTrianglesIterator;
- (void) advanceFaceTrianglesIterator;
- (BOOL) faceTrianglesIteratorEnded;
- (const float *)currentFaceTriangleVertex: (long)index;

- (void) initialiseEdgesIterator;
- (void) advanceEdgesIterator;
- (BOOL) edgesIteratorEnded;
- (void) initialiseEdgeVerticesIterator;
- (BOOL) edgeVerticesIteratorEnded;
- (void) advanceEdgeVerticesIterator;
- (const float *)currentEdgeVertex;

- (void) initialiseVerticesIterator;
- (void) advanceVerticesIterator;
- (BOOL) verticesIteratorEnded;
- (const float *)currentVertex;

- (void) dealloc;

@end

#endif /* CppLinkWrapperWrapper_h */
