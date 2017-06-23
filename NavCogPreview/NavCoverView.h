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

#import <UIKit/UIKit.h>

/*
 1 finger swipe up   : next step
 1 finger swipe down : prev step
 2 finger swipe up   : auto step (adjust speed by keeping touch after a swipe and move up/down)
 2 finger swipe down : nothing
 3 finger swipe up   : next intersection
 3 finger swipe down : prev intersection
 
 1 finger swipe left  : next path in unti clock wise
 1 finger swipe right : next path in clock wise
 
 1 finger tap : speak POI at the finger location
 2 finger tap : stop speaking
 3 finger tap : speak current position
 4 finger tap : go to end (upper screen) / go to start (lower screen)
 
 1 finger double tap : select current POI
 
 shake : quit preview
*/


@class NavCoverView;

#define PreviewGestureSpeedUnit 100

@protocol PreviewCommandDelegate
- (void)speakAtPoint:(CGPoint)point;
- (void)stopSpeaking;
- (void)speakCurrentPOI;
- (void)selectCurrentPOI;
- (void)autoStepForwardSpeed:(double)speed Active:(BOOL)active;
//- (void)autoStepBackward;
- (void)quit; // quit preview
@end

@protocol PreviewTraverseDelegate
- (void)gotoBegin;
- (void)gotoEnd;
- (void)stepForward;
- (void)stepBackward;
- (void)jumpForward;
- (void)jumpBackward;
- (void)faceRight;
- (void)faceLeft; // choose previous
@end


@interface NavCoverView : UIView <UIGestureRecognizerDelegate>

@property (weak) id<PreviewCommandDelegate, PreviewTraverseDelegate> delegate;

@end
