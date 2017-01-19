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
#import "NavDeviceTTS.h"

@interface NavAnnounceItem: UIAccessibilityElement
@end

@implementation NavAnnounceItem

- (void)accessibilityElementDidBecomeFocused
{
    NSString *text = self.accessibilityLabel;
    NSLog(@"accessibilityElementDidBecomeFocused:%@", text);
    [[NSNotificationCenter defaultCenter] postNotificationName:SPEAK_TEXT_QUEUEING object:self userInfo:
     @{@"text":text,@"force":@(YES),@"debug":@(YES)}];
}

@end

@interface NavCurrentStatusItem: NavAnnounceItem
@end

@implementation NavCurrentStatusItem {
    NSTimeInterval lastCall;
}

- (void)accessibilityElementDidBecomeFocused
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
}

- (NSString*)accessibilityLabel
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.accessibilityElementIsFocused && now - lastCall > 0.5) {
        // hack code
        // speak request navigation status if the user tap screen
        // accessibilityLabel is called twice for each tap
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
    }
    lastCall = now;
    return @"";
}

@end

@implementation NavCoverView {
    NSArray *elements;
    NSArray *speaks;
    UIAccessibilityElement *first;
    long currentIndex;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enqueueSpokenText:) name:SPEAK_TEXT_HISTORY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:NAV_ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteControl:) name:REMOTE_CONTROL_EVENT object:nil];
    
    first = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
    first.accessibilityLabel = NSLocalizedString(@"Navigation", @"");
    first.accessibilityTraits = UIAccessibilityTraitStaticText | UIAccessibilityTraitHeader;
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)resetCurrentIndex
{
    currentIndex = (speaks==nil)?0:[speaks count];
}

- (void)incrementCurrentIndex
{
    currentIndex = MIN([elements count]-1, currentIndex+1);
}

- (void)decrementCurrentIndex
{
    currentIndex = MAX(0, currentIndex-1);
}

- (void)jumpToLast
{
    currentIndex = [elements count]-1;
}

- (void)jumpToFirst
{
    currentIndex = 0;
}

- (void)speakCurrentElement
{
    if (!elements) {
        return;
    }
    if (currentIndex < 0 || [elements count] <= currentIndex) {
        return;
    }
    
    UIAccessibilityElement *element = elements[currentIndex];
    
    if (speaks && [speaks count] == currentIndex) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
        return;
    }
    
    NSString *text = element.accessibilityLabel;
    if (!text) {
        return;
    }
    
    if (UIAccessibilityIsVoiceOverRunning()) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    } else {
        [[NavDeviceTTS sharedTTS] selfspeak:text force:YES completionHandler:^{
        }];
    }    
}

- (void)remoteControl:(NSNotification*)note
{
    if (![note userInfo]) {
        return;
    }
    
    UIEvent *event = [note userInfo][@"event"];
    NSLog(@"remote,%ld",event.subtype);
    
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause: // 103
            [self resetCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlNextTrack: // 104
            [self incrementCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack: // 105
            [self decrementCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingBackward: // 106
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_END object:self];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingForward: // 108
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_START object:self];
            break;
        case UIEventSubtypeRemoteControlEndSeekingBackward: // 107
        case UIEventSubtypeRemoteControlEndSeekingForward: // 109
            return;
        default:
            return;
    }
    [self speakCurrentElement];
}

- (void)clear:(NSNotification*)note
{
    @synchronized (self) {
        speaks = nil;
        elements = @[];
    }
}

// update spoken text list
- (void)enqueueSpokenText:(NSNotification*)note
{
    BOOL flag = NO;
    @synchronized (self) {
        NSDictionary *dict = [note userInfo];
        
        // not record as history if debug == YES
        BOOL debug = [dict[@"debug"] boolValue];
        if (debug) {
            return;
        }
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
            UIAccessibilityElement *e = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
            
            e.accessibilityLabel = s;
            [temp addObject:e];
        }
        
        UIAccessibilityElement *e = [[NavCurrentStatusItem alloc] initWithAccessibilityContainer:self];
        e.accessibilityFrame = self.frame;
        [temp addObject:e];

        
        // future summary
        if (_fsSource) {
            // use flat structure for non-voiceover usage
            UIAccessibilityElement *header = [[UIAccessibilityElement alloc] initWithAccessibilityContainer:self];
            header.accessibilityTraits = UIAccessibilityTraitHeader | UIAccessibilityTraitStaticText;
            header.accessibilityLabel = NSLocalizedStringFromTable(@"SummaryHeader",@"BlindView",@"");
            [temp addObject:header];

            for(int i = 0 ; i < [_fsSource numberOfSummary]; i++) {
                NSString *str = [_fsSource summaryAtIndex:i];
                UIAccessibilityElement *e = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
                e.accessibilityLabel = [NavDeviceTTS removeDots:str];

                [temp addObject:e];
            }
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
