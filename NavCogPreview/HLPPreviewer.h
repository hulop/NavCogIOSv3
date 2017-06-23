/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import <Foundation/Foundation.h>
#import "NavCoverView.h"
#import "HLPGeoJSON.h"

@interface HLPPreviewEvent : NSObject
@property (readonly) HLPLink *link;
@property (readonly) HLPLink *rightLink;
@property (readonly) HLPLink *leftLink;
@property (readonly) NSArray<HLPLink*>* linksToNextIntersection;
@property (readonly) NSArray<HLPLink*>* linksToPrevIntersection;
@property (readonly) HLPLocation *location;
@property (readonly) double orientation;
@property (readonly) HLPObject *target;
@property (readonly) HLPObject *nextTarget;
@property (readonly) HLPObject *prevTarget;
@property (readonly) HLPNode *intersection;
@property (readonly) NSArray<HLPFacility*> *pois;

- (HLPLocation*) nextTargetLocation;
- (double) distanceToNextTarget;
- (double) distanceToNextIntersection;
- (HLPLocation*) prevTargetLocation;
- (double) distanceToPrevTarget;
- (double) distanceToPrevIntersection;
@end


@protocol HLPPreviewerDelegate
-(void)previewStarted:(HLPPreviewEvent*)event;
-(void)previewUpdated:(HLPPreviewEvent*)event;
-(void)userMoved:(double)distance;
-(void)previewStopped:(HLPPreviewEvent*)event;
@end

@interface HLPPreviewer : NSObject <PreviewTraverseDelegate>

@property (readonly) HLPPreviewEvent *event;
@property (weak) id<HLPPreviewerDelegate> delegate;

- (void)startAt:(HLPLocation*)loc;
- (void)stop;

@end
