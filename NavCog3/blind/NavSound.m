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
    SystemSoundID VoiceRecoStartSoundID;
    SystemSoundID VoiceRecoEndSoundID;
    NSURL *url1, *url2, *url3, *url4;
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
    
    url1 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/Modern/calendar_alert_chord.caf"];
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url1,&successSoundID);
    
    //url2 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/nano/3rdParty_Success_Haptic.caf"];
    url2 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/RingerChanged.caf"]; // for bone condaction head set
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url2,&AnnounceNotificationSoundID);

    //url3 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/nano/3rdParty_Start_Haptic.caf"];
    url3 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/Tink.caf"]; // for bone condaction head set
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url3,&VoiceRecoStartSoundID);

    //url4 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/nano/3rdParty_Stop_Haptic.caf"];
    url4 = [NSURL URLWithString:@"file:///System/Library/Audio/UISounds/RingerChanged.caf"]; // for bone condaction head set
    AudioServicesCreateSystemSoundID((__bridge_retained CFURLRef)url4,&VoiceRecoEndSoundID);
    
    return self;
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
    return [self _playSystemSound:successSoundID];
}

-(BOOL)playAnnounceNotification
{
    return [self _playSystemSound:AnnounceNotificationSoundID];
}

- (BOOL)playVoiceRecoStart
{
    return [self _playSystemSound:VoiceRecoStartSoundID];
}

- (BOOL)playVoiceRecoEnd
{
    return [self _playSystemSound:VoiceRecoEndSoundID];
}

-(BOOL)vibrate:(NSDictionary*)param
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"vibrate"]) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        return YES;
    }
    return NO;
}

@end
