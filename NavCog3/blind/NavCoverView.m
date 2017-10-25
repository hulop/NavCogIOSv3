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
#import "NavCog3-Swift.h"


@implementation NavAnnounceItem

- (void)accessibilityElementDidBecomeFocused
{
    NSString *text = self.accessibilityLabel;
    if (text != nil) {
        NSLog(@"accessibilityElementDidBecomeFocused:%@", text);
        [[NSNotificationCenter defaultCenter] postNotificationName:SPEAK_TEXT_QUEUEING object:self userInfo:
         @{@"text":text,@"force":@(YES),@"debug":@(YES)}];
    }
    [self.delegate didBecomeFocused:self];
}

@end

@interface NavCurrentStatusItem: NavAnnounceItem
@property BOOL noSpeak;
@end

@implementation NavCurrentStatusItem {
    NSTimeInterval lastCall;
}

- (void)accessibilityElementDidBecomeFocused
{
    if (!_noSpeak) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
    }
    [self.delegate didBecomeFocused:self];
}

// this hack code causes repeating announcement because voiceover might detect
// screen change based on rendering on webview
// this hack is no longer used and another hack code is implemented
//- (NSString*)accessibilityLabel
//{
//    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
//    if (self.accessibilityElementIsFocused && now - lastCall > 0.5) {
//        // first hack code
//        // speak request navigation status if the user tap screen
//        // accessibilityLabel is called twice for each tap
//        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
//    }
//    lastCall = now;
//    return @"";
//}

@end

@implementation NavCoverView {
    NSMutableArray *elements;
    NSMutableArray *speaks;
    NSArray *summary;
    NavAnnounceItem *first;
    NavCurrentStatusItem *currentStatusItem;
    NavCurrentStatusItem *currentStatusItem2; // for hack
    NavAnnounceItem *header;
    long currentIndex;
    BOOL preventCurrentStatus;
}

- (void) setPreventCurrentStatus:(BOOL)preventCurrentStatus_
{
    preventCurrentStatus = preventCurrentStatus_;
    if (currentStatusItem) {
        currentStatusItem.noSpeak = preventCurrentStatus;
    }
    if (currentStatusItem2) {
        currentStatusItem2.noSpeak = preventCurrentStatus;
    }
}

- (BOOL) preventCurrentStatus
{
    return preventCurrentStatus;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enqueueSpokenText:) name:SPEAK_TEXT_HISTORY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:NAV_ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(remoteControl:) name:REMOTE_CONTROL_EVENT object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear:) name:DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    
    first = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
    first.delegate = self;
    first.accessibilityLabel = NSLocalizedString(@"Navigation", @"");
    first.accessibilityTraits = UIAccessibilityTraitStaticText | UIAccessibilityTraitHeader;
    first.accessibilityFrame = CGRectMake(0,0,1,1);
    
    header = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
    header.delegate = self;
    header.accessibilityTraits = UIAccessibilityTraitHeader | UIAccessibilityTraitStaticText;
    header.accessibilityLabel = NSLocalizedStringFromTable(@"SummaryHeader",@"BlindView",@"");
    header.accessibilityFrame = CGRectMake(0,0,1,1);

    
    speaks = [@[] mutableCopy];
    elements = [@[] mutableCopy];

    if (!currentStatusItem) {
        currentStatusItem = [[NavCurrentStatusItem alloc] initWithAccessibilityContainer:self];
        currentStatusItem.accessibilityFrame = self.window.frame;
        currentStatusItem.delegate = self;
        
        currentStatusItem2 = [[NavCurrentStatusItem alloc] initWithAccessibilityContainer:self];
        currentStatusItem2.accessibilityFrame = CGRectMake(0, 0, 1, 1);
        currentStatusItem2.delegate = self;
    }

    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [elements removeAllObjects];
    [elements addObject:first];
    [elements addObject:currentStatusItem];
    currentStatusItem.accessibilityFrame = self.window.frame;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, first);
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

// second hack code
// switch between two accessibility element to detect tap on screen
- (void)didBecomeFocused:(NavAnnounceItem *)item
{
    NSLog(@"focused:%@", item);
    if (item == currentStatusItem) {
        currentStatusItem.accessibilityFrame = CGRectMake(0,0,1,1);
        currentStatusItem2.accessibilityFrame = self.window.frame;
        [elements addObject: currentStatusItem2];
    } else if (item == currentStatusItem2) {
        NSInteger index = [elements indexOfObject:currentStatusItem];
        elements[index] = currentStatusItem2;
        elements[[elements count] - 1] = currentStatusItem;
        NavCurrentStatusItem *temp = currentStatusItem;
        currentStatusItem = currentStatusItem2;
        currentStatusItem2 = temp;
        currentStatusItem.accessibilityFrame = CGRectMake(0,0,1,1);
        currentStatusItem2.accessibilityFrame = self.window.frame;
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, item);
    } else {
        currentStatusItem.accessibilityFrame = self.window.frame;
        if ([elements lastObject] == currentStatusItem2) {
            [elements removeLastObject];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, item);
        }
    }
    NSLog(@"%@", elements);
}

- (void)speakCurrentElement
{
    if (speaks && [speaks count] == currentIndex) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_STATUS object:self];
        return;
    }

    if (!elements) {
        return;
    }
    if (currentIndex < 0 || [elements count] <= currentIndex) {
        return;
    }
    UIAccessibilityElement *element = elements[currentIndex];
    
    NSString *text = element.accessibilityLabel;
    if (!text) {
        return;
    }
    
    if (UIAccessibilityIsVoiceOverRunning()) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    } else {
        [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"selfspeak":@(YES), @"force":@(YES)} completionHandler:^{
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
    
    BOOL isDialogActive = [DialogManager sharedManager].isActive;
    
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlTogglePlayPause: // 103
            if (isDialogActive) [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_ACTION object:self];
            if (!isDialogActive) [self resetCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlNextTrack: // 104
            if (!isDialogActive) [self incrementCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack: // 105
            if (!isDialogActive) [self decrementCurrentIndex];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingBackward: // 106
            if (isDialogActive) [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_END object:self];
            if (!isDialogActive) [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_HANDLE_LOCATION_UNKNOWN object:self];
            return;
        case UIEventSubtypeRemoteControlBeginSeekingForward: // 108
            if (!isDialogActive) [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_START object:self];
            return;
        case UIEventSubtypeRemoteControlEndSeekingBackward: // 107
        case UIEventSubtypeRemoteControlEndSeekingForward: // 109
            return;
        default:
            return;
    }
    if (!isDialogActive) [self speakCurrentElement];
}

- (void)clear:(NSNotification*)note
{
    @synchronized (self) {
        [speaks removeAllObjects];
        [elements removeAllObjects];
        summary = nil;
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
        
        if ([speaks count] == 0) {
            flag = YES;
        }
        NavAnnounceItem *e = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
        e.delegate = self;
        e.accessibilityLabel = text;
        e.accessibilityFrame = CGRectMake(0,0,1,1);
        [speaks addObject:e];
        
        BOOL contains2 = ([elements lastObject] == currentStatusItem2);

        [elements removeAllObjects];
        [elements addObject:first];
        for(int i = 0 ; i < [speaks count]; i++) {
            [elements addObject:speaks[i]];
        }
        
        [elements addObject:currentStatusItem];
        if (!contains2) {
            currentStatusItem.accessibilityFrame = self.window.frame;
        }
        
        // future summary
        if (_fsSource) {
            if (summary == nil) {
                NSMutableArray *temp = [@[] mutableCopy];
                
                for(int i = 0 ; i < [_fsSource numberOfSummary]; i++) {
                    NSString *str = [_fsSource summaryAtIndex:i];
                    NavAnnounceItem *e = [[NavAnnounceItem alloc] initWithAccessibilityContainer:self];
                    e.delegate = self;
                    e.accessibilityLabel = [NavDeviceTTS removeDots:str];
                    e.accessibilityFrame = CGRectMake(0,0,1,1);
                    [temp addObject:e];
                }
                summary = temp;
            }

            // use flat structure for non-voiceover usage
            [elements addObject:header];
            
            for(long i = [_fsSource currentIndex]; i < [summary count]; i++) {
                [elements addObject:summary[i]];
            }
        }
        
        if (contains2) {
            [elements addObject:currentStatusItem2];
            //currentStatusItem2.accessibilityFrame = CGRectMake(0, 0, 1, 1);
        }
        
        
        // check focused element
        UIAccessibilityElement *focusedElement = nil;
        for(int i = 0; i < [elements count]; i++) {
            UIAccessibilityElement *e = elements[i];
            if (e.accessibilityElementIsFocused) {
                focusedElement = e;
            }
        }
        if (focusedElement) {
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, focusedElement);
        }
        NSLog(@"focusedElement:%@", focusedElement);
        NSLog(@"%@", elements);
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

- (void)focusFirst
{
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end
