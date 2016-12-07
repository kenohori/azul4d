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

- (void) initialiseTesseract {
  cppLinkWrapper->cppLink->makeTesseract();
  cppLinkWrapper->cppLink->currentPolygon = cppLinkWrapper->cppLink->currentModel.begin();
}

- (void) advancePolygonIterator {
  ++cppLinkWrapper->cppLink->currentPolygon;
}

- (BOOL) polygonIteratorEnded {
  return cppLinkWrapper->cppLink->currentPolygon == cppLinkWrapper->cppLink->currentModel.end();
}

- (void) initialisePointIterator {
  cppLinkWrapper->cppLink->currentPoint = cppLinkWrapper->cppLink->currentPolygon->points.begin();
}

- (void) advancePointIterator {
  ++cppLinkWrapper->cppLink->currentPoint;
}

- (BOOL) pointIteratorEnded {
  return cppLinkWrapper->cppLink->currentPoint == cppLinkWrapper->cppLink->currentPolygon->points.end();
}

- (const float *)currentPoint {
  for (unsigned int i = 0; i < 4; ++i) {
    cppLinkWrapper->cppLink->currentPointCoordinates[i] = cppLinkWrapper->cppLink->currentPoint->cartesian(i);
  } return cppLinkWrapper->cppLink->currentPointCoordinates;
}

- (void) dealloc {
  delete cppLinkWrapper->cppLink;
  delete cppLinkWrapper;
}

@end
