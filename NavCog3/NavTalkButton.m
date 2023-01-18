//
//
//  NavTalkButton.m
//  NavCog3
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation
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

#import "NavTalkButton.h"

@implementation NavTalkButton

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self drawRect:frame];
        [self setImage:frame];
        [self setAccessibilityLabel:NSLocalizedStringFromTable(@"DialogSearch", @"BlindView", @"")];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextBeginTransparencyLayer(context, nil);
    CGContextBeginPath(context);

    float startAngle = 0;
    float endAngle = startAngle + (M_PI * 2.0);

    CGContextMoveToPoint(context, self.frame.size.width / 2, self.frame.size.height / 2);
    CGContextAddArc(context, self.frame.size.width / 2, self.frame.size.height / 2, self.frame.size.width / 2, startAngle, endAngle, 0);
    CGContextClosePath(context);
    UIColor *color = [UIColor colorWithRed: 50.0/255.0 green:92.0/255.0 blue:128.0/255.0 alpha:1];
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextDrawPath(context, kCGPathFill);

    CGContextMoveToPoint(context, self.frame.size.width / 2, self.frame.size.height / 2);
    CGContextAddArc(context, self.frame.size.width / 2, self.frame.size.height / 2, self.frame.size.width / 2 - 8, startAngle, endAngle, 0);
    CGContextClosePath(context);
    UIColor *color2 = [UIColor  colorWithRed: 243.5/255.0 green:243.5/255.0 blue:243.5/255.0 alpha:1];
    CGContextSetFillColorWithColor(context, color2.CGColor);
    CGContextDrawPath(context, kCGPathFill);

    CGContextEndTransparencyLayer(context);
}

- (void)setImage:(CGRect)rect
{
    UIImage *aImage = [UIImage imageNamed:@"icons8-microphone"];

    aImage = [aImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *aImageView = [[UIImageView alloc] initWithImage:aImage];

    aImageView.tintColor = [UIColor colorWithRed: 50.0/255.0 green:92.0/255.0 blue:128.0/255.0 alpha:1];
    aImageView.center = CGPointMake(rect.size.width  / 2,
                                    rect.size.height / 2);
    [self addSubview:aImageView];
}

@end
