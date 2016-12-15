//
//  CppLinkWrapperWrapper.h
//  azul4d
//
//  Created by Ken Arroyo Ohori on 05/12/16.
//  Copyright © 2016 Ken Arroyo Ohori. All rights reserved.
//

#ifndef CppLinkWrapperWrapper_h
#define CppLinkWrapperWrapper_h

#import <Cocoa/Cocoa.h>

struct CppLinkWrapper;

@interface CppLinkWrapperWrapper: NSObject {
  struct CppLinkWrapper *cppLinkWrapper;
}

- (id) init;
- (void) makeTesseract;
- (void) iterateOverFaces;
- (void) iterateOverEdges;
- (void) iterateOverVertices;
- (void) initialiseMeshIterator;
- (void) advanceMeshIterator;
- (BOOL) meshIteratorEnded;
- (void) initialiseTriangleIterator;
- (void) advanceTriangleIterator;
- (BOOL) triangleIteratorEnded;
- (const float *)currentTriangleVertex: (long)index;
- (const float *)currentMeshColour;
- (void) dealloc;

@end

#endif /* CppLinkWrapperWrapper_h */
