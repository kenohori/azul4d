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
- (void) initialiseTesseract;
- (void) advancePolygonIterator;
- (BOOL) polygonIteratorEnded;
- (void) initialisePointIterator;
- (void) advancePointIterator;
- (BOOL) pointIteratorEnded;
- (const float *)currentPoint;
- (void) dealloc;

@end

#endif /* CppLinkWrapperWrapper_h */
