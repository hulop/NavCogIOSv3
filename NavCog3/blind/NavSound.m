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
#import "LocationEvent.h"
#import "NavDebugHelper.h"

@implementation NavSound {
    SystemSoundID successSoundID;
    SystemSoundID AnnounceNotificationSoundID;
    SystemSoundID VoiceRecoStartSoundID;
    SystemSoundID VoiceRecoEndSoundID;
    SystemSoundID failSoundID;
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
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"for_bone_conduction_headset"
                                               options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playSystemSoundFromNote:)
                                                 name:PLAY_SYSTEM_SOUND
                                               object:[NavDebugHelper sharedHelper]];
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"for_bone_conduction_headset"]) {
        [self loadAudio];
    }
}


- (void) loadAudio
{
    BOOL for_bone_conduction_headset = [[NSUserDefaults standardUserDefaults] boolForKey:@"for_bone_conduction_headset"];
    
    void(^loadSound)(NSString*,SystemSoundID*) = ^(NSString *name, SystemSoundID *soundIDRef) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"file:///System/Library/Audio/UISounds/%@", name]];
        AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url,soundIDRef);
    };
    
    if (for_bone_conduction_headset) {
        loadSound(@"Modern/calendar_alert_chord.caf", &successSoundID);
        loadSound(@"RingerChanged.caf", &AnnounceNotificationSoundID);
        loadSound(@"Tink.caf", &VoiceRecoStartSoundID);
        loadSound(@"RingerChanged.caf", &VoiceRecoEndSoundID);
        loadSound(@"SIMToolkitNegativeACK.caf", &failSoundID);
    } else {
        loadSound(@"Modern/calendar_alert_chord.caf", &successSoundID);
        loadSound(@"nano/3rdParty_Success_Haptic.caf", &AnnounceNotificationSoundID);
        loadSound(@"nano/3rdParty_Start_Haptic.caf", &VoiceRecoStartSoundID);
        loadSound(@"nano/3rdParty_Stop_Haptic.caf", &VoiceRecoEndSoundID);
        loadSound(@"SIMToolkitNegativeACK.caf", &failSoundID);
    }
}

-(void)playSystemSoundFromNote:(NSNotification*)note
{
    NSDictionary *info = note.userInfo;
    NSString *name = info[@"sound"];
    if ([name isEqualToString:@"vibrate"]) {
        [self vibrate:info[@"param"]];
    } else {
        SEL sel = NSSelectorFromString(name);
        if ([self respondsToSelector:sel]) {
            [self performSelector:sel];
        }
    }
}

-(BOOL)_playSystemSound:(SystemSoundID)soundID
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"sound_effect"]) {
        AudioServicesPlaySystemSound(soundID);
        return YES;
    }
    return NO;
}

-(BOOL)playSuccess
{
    if ([self _playSystemSound:successSoundID]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                            object:self userInfo:@{@"sound":@"playSuccess"}];
        return YES;
    }
    return NO;
}

- (BOOL)playFail
{
    if ([self _playSystemSound:failSoundID]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                            object:self userInfo:@{@"sound":@"playFail"}];
        return YES;
    }
    return NO;
}

-(BOOL)playAnnounceNotification
{
    if ([self _playSystemSound:AnnounceNotificationSoundID]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                            object:self userInfo:@{@"sound":@"playAnnounceNotification"}];
        return YES;
    }
    return NO;
}

- (BOOL)playVoiceRecoStart
{
    if ([self _playSystemSound:VoiceRecoStartSoundID]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                            object:self userInfo:@{@"sound":@"playVoiceRecoStart"}];
        return YES;
    }
    return NO;
}

- (BOOL)playVoiceRecoEnd
{
    if ([self _playSystemSound:VoiceRecoEndSoundID]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                            object:self userInfo:@{@"sound":@"playVoiceRecoEnd"}];
        return YES;
    }
    return NO;
}

-(BOOL)vibrate:(NSDictionary*)param
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        if (param) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                                object:self userInfo:@{@"sound":@"vibrate", @"param":param}];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:PLAY_SYSTEM_SOUND
                                                                object:self userInfo:@{@"sound":@"vibrate"}];            
        }
        return YES;
    }
    return NO;
}

@end
