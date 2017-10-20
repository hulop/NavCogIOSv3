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

#import "NavCoverView.h"

@implementation NavCoverView {
    UITapGestureRecognizer *tap1f, *tap2f, *tap3f, *tap4f;
    UITapGestureRecognizer *doubleTap1f;
    UISwipeGestureRecognizer *swipeLeft1f, *swipeRight1f;
    UISwipeGestureRecognizer *swipeLeft2f, *swipeRight2f;
    UISwipeGestureRecognizer *swipeLeft3f, *swipeRight3f;
    UISwipeGestureRecognizer *swipeUp1f, *swipeUp2f, *swipeUp3f;
    UISwipeGestureRecognizer *swipeDown1f, *swipeDown2f, *swipeDown3f;
    
    UIGestureRecognizer *active;
    CGPoint begin;
    CGPoint current;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if (motion == UIEventSubtypeMotionShake) {
        [_delegate quit];
    }
}

#pragma mark - UIAccessibility override

- (BOOL)isAccessibilityElement
{
    return YES;
}

- (NSString *)accessibilityLabel
{
    return nil;
}

- (BOOL)isUserInteractionEnabled
{
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    if (self.accessibilityElementIsFocused) {
        return UIAccessibilityTraitAllowsDirectInteraction | UIAccessibilityTraitUpdatesFrequently;
    } else {
        return UIAccessibilityTraitNone;
    }
}

- (void)accessibilityElementDidBecomeFocused
{
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)accessibilityElementDidLoseFocus
{
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

#pragma mark - main

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    tap1f = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap1f:)];
    tap1f.numberOfTapsRequired = 1;
    tap1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:tap1f];
    
    tap2f = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap2f:)];
    tap2f.numberOfTapsRequired = 1;
    tap2f.numberOfTouchesRequired = 2;
    [self addGestureRecognizer:tap2f];
    
    tap3f = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap3f:)];
    tap3f.numberOfTapsRequired = 1;
    tap3f.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:tap3f];
    
    tap4f = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap4f:)];
    tap4f.numberOfTapsRequired = 1;
    tap4f.numberOfTouchesRequired = 4;
    [self addGestureRecognizer:tap4f];
    
    doubleTap1f = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap1f:)];
    doubleTap1f.numberOfTapsRequired = 2;
    doubleTap1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:doubleTap1f];
    
    [tap1f requireGestureRecognizerToFail:doubleTap1f];
    
    swipeLeft1f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeLeft1f:)];
    swipeLeft1f.direction = UISwipeGestureRecognizerDirectionLeft;
    swipeLeft1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:swipeLeft1f];
    
    swipeRight1f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeRight1f:)];
    swipeRight1f.direction = UISwipeGestureRecognizerDirectionRight;
    swipeRight1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:swipeRight1f];
    
    swipeLeft2f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeLeft1f:)];
    swipeLeft2f.direction = UISwipeGestureRecognizerDirectionLeft;
    swipeLeft2f.numberOfTouchesRequired = 2;
    [self addGestureRecognizer:swipeLeft2f];
    
    swipeRight2f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeRight1f:)];
    swipeRight2f.direction = UISwipeGestureRecognizerDirectionRight;
    swipeRight2f.numberOfTouchesRequired = 2;
    [self addGestureRecognizer:swipeRight2f];
    
    swipeLeft3f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeLeft1f:)];
    swipeLeft3f.direction = UISwipeGestureRecognizerDirectionLeft;
    swipeLeft3f.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:swipeLeft3f];
    
    swipeRight3f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeRight1f:)];
    swipeRight3f.direction = UISwipeGestureRecognizerDirectionRight;
    swipeRight3f.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:swipeRight3f];
    
    swipeUp1f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeUp1f:)];
    swipeUp1f.direction = UISwipeGestureRecognizerDirectionUp;
    swipeUp1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:swipeUp1f];
    
    swipeUp2f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeUp2f:)];
    swipeUp2f.direction = UISwipeGestureRecognizerDirectionUp;
    swipeUp2f.numberOfTouchesRequired = 2;
    swipeUp2f.cancelsTouchesInView = NO;
    [self addGestureRecognizer:swipeUp2f];

    swipeUp3f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeUp3f:)];
    swipeUp3f.direction = UISwipeGestureRecognizerDirectionUp;
    swipeUp3f.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:swipeUp3f];
    
    swipeDown1f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown1f:)];
    swipeDown1f.direction = UISwipeGestureRecognizerDirectionDown;
    swipeDown1f.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:swipeDown1f];
    
    swipeDown2f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown2f:)];
    swipeDown2f.direction = UISwipeGestureRecognizerDirectionDown;
    swipeDown2f.numberOfTouchesRequired = 2;
    [self addGestureRecognizer:swipeDown2f];
    
    swipeDown3f = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didSwipeDown3f:)];
    swipeDown3f.direction = UISwipeGestureRecognizerDirectionDown;
    swipeDown3f.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:swipeDown3f];
    
    return self;
}

#pragma mark - private functions

- (CGPoint)centerOfTouches:(NSSet<UITouch *> *)touches
{
    CGFloat x = 0, y = 0;
    NSUInteger N = [touches count];
    for (UITouch *t in [touches allObjects]) {
        CGPoint p = [t locationInView:self];
        x += p.x;
        y += p.y;
    }
    return CGPointMake(x/N, y/N);
}

- (CGPoint)centerOfGesture:(UIGestureRecognizer*)sender
{
    CGFloat x = 0, y = 0;
    NSUInteger N = [sender numberOfTouches];
    for (NSUInteger i = 0; i < N; i++) {
        CGPoint p = [sender locationOfTouch:i inView:self];
        x += p.x;
        y += p.y;
    }
    return CGPointMake(x/N, y/N);
}

- (CGFloat)distanceFrom:(CGPoint)a To:(CGPoint)b
{
    return sqrt(pow(a.x-b.x,2)+pow(a.y-b.y,2));
}


#pragma mark - UIResponder override

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    //NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    if ([touches count] > 0) {
        begin = [self centerOfTouches:touches];
    }
}

- (double)previewSpeed
{
    CGFloat STEPS = 8;
    CGFloat dist = [self distanceFrom:begin To:current] / PreviewGestureSpeedUnit;
    dist = begin.y - current.y >= 0 ? dist : 0;
    dist = MIN(MAX(dist-1, -1),3);
    dist = round(dist*STEPS)/STEPS;
    return pow(2,dist);
}

#pragma mark - gesture handler

- (void) didTap1f:(UITapGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    CGPoint p = [self centerOfGesture:sender];
    //NSLog(@"%f, %f", p.x, p.y);
    [_delegate speakAtPoint:p];
}

- (void) didTap2f:(UITapGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate stopSpeaking];
}

- (void) didTap3f:(UITapGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate speakCurrentPOI];
}

- (void) didTap4f:(UITapGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    CGPoint p = [self centerOfGesture:sender];
    CGFloat h = self.bounds.size.height;
    if (h*0.4 > p.y) { // upper
        [_delegate gotoEnd];
    }
    if (h*0.6 < p.y) { // lower
        [_delegate gotoBegin];
    }
}

- (void)didDoubleTap1f:(UITapGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate selectCurrentPOI];
}

- (void)didSwipeLeft1f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate faceLeft];
}

- (void)didSwipeRight1f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate faceRight];
}

- (void)didSwipeUp1f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate stepForward];
}

- (void)didSwipeUp2f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate autoStepForwardUp];
}

- (void)didSwipeUp3f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate jumpForward];
}

- (void)didSwipeDown1f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate stepBackward];
}

- (void)didSwipeDown2f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate autoStepForwardDown];
}

- (void)didSwipeDown3f:(UISwipeGestureRecognizer*)sender
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    [_delegate jumpBackward];
}



/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
