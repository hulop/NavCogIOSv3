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


#import "NavSound.h"
#import <AVFoundation/AVFoundation.h>

@implementation NavSound {
    SystemSoundID successSoundID;
    SystemSoundID AnnounceNotificationSoundID;
    SystemSoundID failSoundID;
    SystemSoundID stepRID;
    SystemSoundID stepLID;
    SystemSoundID noStepID;
    BOOL stepLR;
}

static NavSound *instance;

+ (instancetype)sharedInstance
{
    if (!instance) {
        instance = [[NavSound alloc] init];
    }
    return instance;
}

- (instancetype)init
{
    self = [super init];
    
    [self loadAudio];
    return self;
}


- (void) loadAudio
{
    NSURL *url;

    url = [[NSBundle mainBundle] URLForResource:@"footstep-r" withExtension:@"aiff"];
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url,&stepRID);

    url = [[NSBundle mainBundle] URLForResource:@"footstep-l" withExtension:@"aiff"];
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url,&stepLID);
    
    void(^loadSound)(NSString*,SystemSoundID*) = ^(NSString *name, SystemSoundID *soundIDRef) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"file:///System/Library/Audio/UISounds/%@", name]];
        AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url,soundIDRef);
    };
    
    loadSound(@"nano/VoiceOver_Click_Haptic.caf", &noStepID);
    loadSound(@"Modern/calendar_alert_chord.caf", &successSoundID);
    loadSound(@"SIMToolkitNegativeACK.caf", &failSoundID);
    loadSound(@"nano/3rdParty_Success_Haptic.caf", &AnnounceNotificationSoundID);
}

-(void)_playSystemSound:(SystemSoundID)soundID
{
    AudioServicesPlaySystemSound(soundID);
}

-(void)playStep:(NSDictionary*)param
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    if (stepLR) {
        [self _playSystemSound:stepRID];
    } else {
        [self _playSystemSound:stepLID];
    }
    stepLR = !stepLR;

    if (param) {
        int repeat = [param[@"repeat"] intValue];
        if (repeat > 1) {
            double interval = param[@"interval"]?[param[@"interval"] doubleValue]:0.5;
            [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
                [self vibrate:@{@"repeat":@(repeat-1),@"interval":@(interval)}];
            }];
        }
    }
}

- (void)playNoStep
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self _playSystemSound:noStepID];
}

-(void)playSuccess
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self _playSystemSound:successSoundID];
}

- (void)playFail
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self _playSystemSound:failSoundID];
}

- (void)playAnnounceNotification
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [self _playSystemSound:AnnounceNotificationSoundID];
}

-(void)vibrate:(NSDictionary*)param
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        NSLog(@"%@", NSStringFromSelector(_cmd));
        if (param) {
            int repeat = [param[@"repeat"] intValue];
            if (repeat > 1) {
                double interval = param[@"interval"]?[param[@"interval"] doubleValue]:0.5;
                [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer * _Nonnull timer) {
                    [self vibrate:@{@"repeat":@(repeat-1),@"interval":@(interval)}];
                }];
            }
        }
    }
}

@end
