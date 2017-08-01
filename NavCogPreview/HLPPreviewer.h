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
#import "HLPGeoJSON.h"

@interface HLPPreviewEvent : NSObject <NSCopying>
@property (readonly) HLPLink *link;
@property (readonly) HLPLink *routeLink;
@property (readonly) HLPLocation *location;
@property (readonly) double orientation;
@property (readonly) double distanceMoved;
@property (readonly) HLPPreviewEvent* prev;

- (HLPLocationObject*) target;
- (HLPNode*) targetNode;
- (HLPNode*) targetIntersection;
- (NSArray<HLPLocationObject*>*) targetPOIs;
- (NSArray<HLPLink*>*) intersectionLinks;

- (HLPLink*) rightLink;
- (HLPLink*) leftLink;

- (HLPPreviewEvent*) next;
- (HLPPreviewEvent*) right;
- (HLPPreviewEvent*) left;
- (HLPPreviewEvent*) nextAction;

- (BOOL) isOnRoute;
- (BOOL) isGoingToBeOffRoute;
- (BOOL) isGoingBackward;
- (BOOL) isArrived;

@end


@protocol HLPPreviewerDelegate
-(void)previewStarted:(HLPPreviewEvent*)event;
-(void)previewUpdated:(HLPPreviewEvent*)event;
-(void)userMoved:(double)distance;
-(void)userLocation:(HLPLocation*)location;
-(void)remainingDistance:(double)distance;
-(void)previewStopped:(HLPPreviewEvent*)event;
@end

@interface HLPPreviewer : NSObject

@property (readonly) HLPPreviewEvent *event;
@property (weak) id<HLPPreviewerDelegate> delegate;
@property (readonly) BOOL isActive;

- (void)startAt:(HLPLocation*)loc;
- (void)stop;

- (void)gotoBegin;
- (void)gotoEnd;
- (void)stepForward;
- (void)stepBackward;
- (void)jumpForward;
- (void)jumpBackward;
- (void)faceRight;
- (void)faceLeft;
- (void)autoStepForwardSpeed:(double)speed Active:(BOOL)active;

@end
