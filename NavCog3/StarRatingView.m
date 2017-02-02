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

#import "StarRatingView.h"

@implementation StarRatingView {
    CGFloat iconSize;
    CGFloat iconMargin;
    int _stars;
    BOOL _disabled;
}

- (instancetype) init
{
    self = [super init];
    if (self) {
        [self initView];
    }
    return self;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initView];
    }
    return self;
}

- (instancetype) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initView];
    }
    return self;
}

- (void) initView
{
    CGSize size = self.bounds.size;
    //iconSize = floor(size.height * 0.9 / 8) * 8;
    iconSize = 24;    
    iconMargin = MIN(24, (size.width-iconSize*5)/4);

    _stars = 0;
}

- (int) stars{
    return _stars;
}

- (void) setStars:(int)stars
{
    int temp = MAX(0,MIN(5,stars));
    if (_stars != temp) {
        [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
        [self setNeedsDisplay];
        [_delegate didChangeStarRating:self];
    }
    _stars = temp;
}

- (BOOL) disabled{
    return _disabled;
}

- (void) setDisabled:(BOOL)disabled
{
    _disabled = disabled;
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (_disabled) {
        return;
    }
    [self checkTouches:touches];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (_disabled) {
        return;
    }
    [self checkTouches:touches];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (_disabled) {
        return;
    }
    [self checkTouches:touches];
}

- (void)checkTouches:(NSSet<UITouch *> *)touches
{
    CGPoint p = [[touches anyObject] locationInView:self];
    CGSize size = self.bounds.size;

    CGFloat center = size.width/2;
    int temp = floor((p.x - center + iconMargin) / (iconSize+iconMargin)) + 3;
    
    if (temp <= 5) {
        [self setStars:temp];
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    CGSize size = self.bounds.size;
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    if (_disabled) {
        CGContextSetAlpha(context, 0.5);
    }
    
    CGImageRef star = [[UIImage imageNamed:@"star"] CGImage];
    CGImageRef nostar = [[UIImage imageNamed:@"nostar"] CGImage];
    
    for(int i = 0; i < 5; i++) {
        CGFloat center = size.width/2;
        CGFloat x = center + (i-2.5)*iconSize + (i-2)*iconMargin;
        CGFloat y = size.height/2 - iconSize/2;
        CGRect iconRect = CGRectMake(x, y, iconSize, iconSize);
        CGImageRef image = i < _stars ? star : nostar;
        CGContextDrawImage(context, iconRect, image);
    }
    CGContextRestoreGState(context);
}

- (BOOL) isAccessibilityElement
{
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    return UIAccessibilityTraitAdjustable;
}

- (NSString *)accessibilityValue
{
    if (_stars == 0) {
        return NSLocalizedString(@"NotSpecified", @"");
    }
    return [@(_stars) stringValue];
}

- (void)accessibilityIncrement
{
    [self setStars: MIN(5, _stars+1)];
}

- (void)accessibilityDecrement
{
    [self setStars: MAX(1, _stars-1)];
}

@end
