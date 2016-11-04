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
#import "LocationEvent.h"

@implementation NavCoverView {
    NSArray *elements;
    NSArray *speaks;
    UIAccessibilityElement *first;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(speak:) name:SPEAK_TEXT_QUEUEING object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:NAV_ROUTE_CHANGED_NOTIFICATION object:nil];
    
    first = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    first.accessibilityLabel = NSLocalizedString(@"Navigation", @"");
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)clear:(NSNotification*)notification
{
    @synchronized (self) {
        speaks = nil;
        elements = @[first];
    }
}

- (void)speak:(NSNotification*)notification
{
    BOOL flag = NO;
    @synchronized (self) {
        NSDictionary *dict = [notification object];
        NSString *text = dict[@"text"];
        
        if (!speaks) {
            speaks = @[text];
            flag = YES;
        } else {
            speaks = [speaks arrayByAddingObject:text];
            if ([speaks count] > 10) {
                speaks = [speaks subarrayWithRange:NSMakeRange(1, [speaks count]-1)];
            }
        }

        NSMutableArray *temp = [@[first] mutableCopy];
        for(int i = 0 ; i < [speaks count]; i++) {
            NSString *s = speaks[i];
            BOOL last = (i == [speaks count] - 1);
            UIAccessibilityElement *e = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
            
            e.accessibilityLabel = s;
            if (last) {
                e.accessibilityFrame = self.frame;
            }
            [temp addObject:e];
        }
        elements = temp;
    }
    if (flag) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, elements[0]);
    }
}

- (BOOL)isAccessibilityElement
{
    @synchronized (self) {
        return NO;
    }
}

- (NSArray *)accessibilityElements
{
    @synchronized (self) {
        return elements;
    }
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    @synchronized (self) {
        return [elements indexOfObject:element];
    }
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
    @synchronized (self) {
        return [elements objectAtIndex:index];
    }
}

- (NSInteger)accessibilityElementCount
{
    @synchronized (self) {
        return [elements count];
    }
}


/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end
