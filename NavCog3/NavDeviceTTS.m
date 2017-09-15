/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
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

#import "NavDeviceTTS.h"
#import <UIKit/UIKit.h>
#import "LocationEvent.h"
#import "NavDebugHelper.h"

@implementation HLPSpeechEntry

@end

@implementation NavDeviceTTS {
    NSTimeInterval expire;
}

static NavDeviceTTS *instance = nil;

+ (instancetype)sharedTTS
{
    if (!instance) {
        instance = [[NavDeviceTTS alloc] init];
    }
    return instance;
}

- (instancetype) init
{
    self = [super init];
    
    expire = NAN;

    /*
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChanged)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    */
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(voiceOverStatusChanged)
                                                 name:UIAccessibilityVoiceOverStatusChanged
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(voiceOverDidFinishAnnouncing:)
                                                 name:UIAccessibilityAnnouncementDidFinishNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(speakFromNotification:)
                                                 name:SPEAK_TEXT_QUEUEING
                                               object:[NavDebugHelper sharedHelper]];
    
    [self reset];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    voice.delegate = nil;
    voice = nil;
}

- (void)voiceOverStatusChanged
{
    
}

- (void)reset
{
    speaking = [[NSMutableArray alloc] init];
    processing = [[NSMutableDictionary alloc] init];
    isSpeaking = NO;
    voice = [[AVSpeechSynthesizer alloc] init];
    voice.delegate = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        speakTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(processSpeak:) userInfo:nil repeats:YES];
    });
}

- (void) routeChanged
{
    NSLog(@"Routing Changed");
    if (voice) {
        voice.delegate = nil;
    }
    voice = [[AVSpeechSynthesizer alloc] init];
    voice.delegate = self;
}

- (void) stop:(BOOL) immediate
{
    if (isSpeaking) {
        isSpeaking = NO;
        [voice stopSpeakingAtBoundary:immediate?AVSpeechBoundaryImmediate:AVSpeechBoundaryWord];
    }
}

- (BOOL)isSpeaking
{
    return isSpeaking;
}

+ (AVSpeechSynthesisVoice*)getVoice {
    // From http://stackoverflow.com/a/23826135/427299
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    NSString *voiceLangCode = [AVSpeechSynthesisVoice currentLanguageCode];
    if (![voiceLangCode hasPrefix:language]) {
        // the default voice can't speak the language the text is localized to;
        // switch to a compatible voice:
        NSArray *speechVoices = [AVSpeechSynthesisVoice speechVoices];
        for (AVSpeechSynthesisVoice *speechVoice in speechVoices) {
            if ([speechVoice.language hasPrefix:language]) {
                voiceLangCode = speechVoice.language;
                break;
            }
        }
    }
    return [AVSpeechSynthesisVoice voiceWithLanguage:voiceLangCode];
}


+ (AVSpeechSynthesisVoice*)getVoiceOfLang:(NSString *)language {

    NSString *voiceLangCode;
    NSArray *speechVoices = [AVSpeechSynthesisVoice speechVoices];
    for (AVSpeechSynthesisVoice *speechVoice in speechVoices) {
        NSLog(@"%@", speechVoice.language);
        if ([speechVoice.language hasPrefix:language]) {
            voiceLangCode = speechVoice.language;
            break;
        }
    }
    return [AVSpeechSynthesisVoice voiceWithLanguage:voiceLangCode];
}

- (void) pause:(double)duration
{
    HLPSpeechEntry *se = [[HLPSpeechEntry alloc] init];
    se.pauseDuration = duration;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SPEAK_TEXT_QUEUEING object:self userInfo:
     @{@"pause":@(YES),@"duration":@(duration)}];
    
    @synchronized(speaking) {
        [speaking addObject:se];
    }
}

- (void)speakFromNotification:(NSNotification*)note
{
    NSDictionary *param = note.userInfo;
    BOOL pause = [param[@"pause"] boolValue];
    if (pause) {
        double duration = [param[@"duration"] doubleValue];
        [self pause:duration];
    } else {
        NSString *text = param[@"text"];
        BOOL force = [param[@"force"] boolValue];
        [self speak:text withOptions:@{@"force":@(force), @"nohistory":@(YES)} completionHandler:nil];
    }
}

- (AVSpeechUtterance *)speak:(NSString *)text withOptions:(NSDictionary *)options completionHandler:(void (^)())handler
{
    BOOL force = [options[@"force"] boolValue];
    BOOL selfspeak = [options[@"selfspeak"] boolValue];
    BOOL nohistory = [options[@"nohistory"] boolValue];
    BOOL quickAnswer = [options[@"quickAnswer"] boolValue];
    AVSpeechSynthesisVoice *aVoice = nil;
    if (options[@"lang"]) {
        aVoice = [NavDeviceTTS getVoiceOfLang:options[@"lang"]];
    }
    
    return [self _speak:text force:force selfvoicing:selfspeak nohistory:nohistory quickAnswer:quickAnswer voice:aVoice completionHandler:handler];
}

- (AVSpeechUtterance *)selfspeak:(NSString *)text completionHandler:(void (^)())handler
{
    return [self selfspeak:text force:NO completionHandler:handler];
}

- (AVSpeechUtterance *)selfspeak:(NSString *)text force:(BOOL)flag completionHandler:(void (^)())handler
{
    return [self _speak:text force:flag selfvoicing:YES nohistory:YES quickAnswer:NO voice:nil completionHandler:handler];
}

- (AVSpeechUtterance*) speak: (NSString*) text completionHandler:(void (^)())handler
{
    return [self speak:text force:NO completionHandler:handler];
}

- (AVSpeechUtterance*) speak:(NSString*)text force:(BOOL)flag completionHandler:(void (^)())handler
{
    return [self _speak:text force:flag selfvoicing:NO nohistory:NO quickAnswer:NO voice:nil completionHandler:handler];
}

- (AVSpeechUtterance*) _speak:(NSString*)text
                        force:(BOOL)flag
                  selfvoicing:(BOOL)selfvoicing
                    nohistory:(BOOL)nohistory
                  quickAnswer:(BOOL)quickAnswer
                        voice:(AVSpeechSynthesisVoice*)voice_
            completionHandler:(void (^)())handler
{
    if (text == nil) {
        handler();
        return nil;
    }
    if (voice_ == nil) {
        voice_ = [NavDeviceTTS getVoice];
    }
    
    // check pause
    int keep = 0;
    int start = 0;
    BOOL isFirst = YES;
    NSString *pauseStr = NSLocalizedStringFromTable(@"TTS_PAUSE_CHAR", @"BlindView", @"");
    for(int i = 0; i < [text length]; i++) {
        if ([[text substringWithRange:NSMakeRange(i, 1)] isEqualToString:pauseStr]) {
            keep++;
        } else if ([[text substringWithRange:NSMakeRange(i, 1)] isEqualToString:@" "]) {
        } else {
            if (keep >= 3) {
                [self _speak:[text substringWithRange:NSMakeRange(start, i-keep)] force:flag && isFirst selfvoicing:selfvoicing nohistory:nohistory quickAnswer:quickAnswer voice:nil completionHandler:nil];
                [self pause:0.1*keep];
                text = [text substringFromIndex:i];
                flag = NO;
                i = 0;
            }
            keep = 0;
        }
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:SPEAK_TEXT_QUEUEING object:self userInfo:
     @{@"text":text,@"force":@(flag)}];

    if (!nohistory) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPEAK_TEXT_HISTORY object:self userInfo:
         @{@"text":text,@"force":@(flag)}];
    }
    
    double speechRate = [[NSUserDefaults standardUserDefaults] doubleForKey:SPEECH_SPEED];
    
    NSLog(@"speak_queue,%@,%@,%f", text, flag?@"Force":@"", NSDate.date.timeIntervalSince1970);
    HLPSpeechEntry *se = [[HLPSpeechEntry alloc] init];
    se.ut = [AVSpeechUtterance speechUtteranceWithString:[NavDeviceTTS removeDots:text]];
    se.ut.volume = 1.0;
    se.ut.rate = speechRate;
    se.ut.voice = voice_;
    se.selfvoicing = selfvoicing;
    se.issued = [[NSDate date] timeIntervalSince1970];
    se.quickAnswer = quickAnswer;
    
    se.completionHandler = handler;
    
    if (flag) {
        [voice stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        @synchronized(speaking) {
            speaking = [[speaking objectsAtIndexes:[speaking indexesOfObjectsPassingTest:^BOOL(HLPSpeechEntry *se, NSUInteger idx, BOOL * _Nonnull stop) {
                return idx == 0 && se.pauseDuration > 0;
            }]] mutableCopy];
            //[speaking removeAllObjects];
            [speaking addObject:se];
        }
        isSpeaking = NO;
        isProcessing = NO;
        return se.ut;
    }
    
    @synchronized(speaking) {
        [speaking addObject:se];
    }
    
    return se.ut;
}

- (void) processSpeak:(NSTimer*) timer
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (!isnan(expire) && now > expire) {
        isProcessing = isSpeaking = NO;
        expire = NAN;
    }
    if (!speaking || [speaking count] == 0 || isProcessing) {
        return;
    }
    isProcessing = YES;
    HLPSpeechEntry *se = nil;
    @synchronized(speaking) {
        se = [speaking firstObject];
        [speaking removeObjectAtIndex:0];
    }
    if (se.pauseDuration > 0) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(se.pauseDuration * NSEC_PER_SEC));
        //NSLog(@"speak_pause(%.2f)", se.pauseDuration);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            isProcessing = NO;
        });
        return;
    }
    
    [processing setObject:se forKey:se.ut.speechString];
    se.speakStart = [[NSDate date] timeIntervalSince1970];
    isSpeaking = YES;
    double(^estimatedDuration)(HLPSpeechEntry *) = ^(HLPSpeechEntry* se) {
        double r = se.ut.rate;
        double r2 = r*r+0.23*r+0.1; // based on an experiment, estimated speech speed
        double safe_rate = 1.5;
        
        double languageRate = 20; // en
        NSString *lang = AVSpeechSynthesisVoice.currentLanguageCode;
        if ([lang isEqualToString:@"ja-JP"]) {
            languageRate = 10;
        }
        return se.ut.speechString.length / languageRate / r2 * safe_rate;
    };
    double duration = estimatedDuration(se);
    expire = now + duration;

    if (!se.selfvoicing && [self speakWithVoiceOver:se.ut.speechString]) {
        return;
    }
    NSLog(@"speak,%@,%f,%f", se.ut.speechString, duration, NSDate.date.timeIntervalSince1970);
    
    [voice speakUtterance:se.ut];
}


-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    isSpeaking = NO;
    isProcessing = NO;
    expire = NAN;
    
    HLPSpeechEntry *se = [processing objectForKey:utterance.speechString];
    se.speakFinish = [[NSDate date] timeIntervalSince1970];
    NSLog(@"speak_cancel,%.2f,%.2f,%f", se.speakStart - se.issued, se.speakFinish - se.speakStart, NSDate.date.timeIntervalSince1970);
    [processing removeObjectForKey:utterance.speechString];
    
    if (se && se.completionHandler) {
        se.completionHandler();
    }
}


- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    //isSpeaking = YES;
}

-(void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer willSpeakRangeOfSpeechString:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance
{
    HLPSpeechEntry *se = [processing objectForKey:utterance.speechString];
    if (se && se.quickAnswer) {
        long len = [se.ut.speechString length];
        if (len - characterRange.location < 8) {
            isSpeaking = NO;
            isProcessing = NO;
            expire = NAN;
            
            se.speakFinish = [[NSDate date] timeIntervalSince1970];
            NSLog(@"speak_finish,%.2f,%.2f,%f", se.speakStart - se.issued, se.speakFinish - se.speakStart, NSDate.date.timeIntervalSince1970);
            [processing removeObjectForKey:utterance.speechString];
            
            if (se && se.completionHandler) {
                se.completionHandler();
            }
        }
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    isSpeaking = NO;
    isProcessing = NO;
    expire = NAN;
    
    HLPSpeechEntry *se = [processing objectForKey:utterance.speechString];
    if (se) {
        se.speakFinish = [[NSDate date] timeIntervalSince1970];
        NSLog(@"speak_finish,%.2f,%.2f,%f", se.speakStart - se.issued, se.speakFinish - se.speakStart, NSDate.date.timeIntervalSince1970);
        [processing removeObjectForKey:utterance.speechString];
        
        if (se.completionHandler) {
            se.completionHandler();
        }
    }
}

- (void)voiceOverDidFinishAnnouncing:(NSNotification*)note
{
    NSDictionary *userInfo = [note userInfo];
    NSString *speechString = userInfo[UIAccessibilityAnnouncementKeyStringValue];
    
    HLPSpeechEntry *se = [processing objectForKey:speechString];
    se.speakFinish = [[NSDate date] timeIntervalSince1970];
    NSLog(@"speak_finish_vo,%.2f,%.2f,%f", se.speakStart - se.issued, se.speakFinish - se.speakStart, NSDate.date.timeIntervalSince1970);
    [processing removeObjectForKey:speechString];
    
    if (se) {
        isSpeaking = NO;
        isProcessing = NO;
        expire = NAN;
        if (se.completionHandler) {
            se.completionHandler();
        }
    }    
}

- (BOOL) speakWithVoiceOver:(NSString*)str
{
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];

    
    if ([str length] == 0 || !UIAccessibilityIsVoiceOverRunning() ||
        applicationState == UIApplicationStateBackground) {
        return NO;
    }
    
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, str);
    NSLog(@"speak_vo,%@,%f", str, NSDate.date.timeIntervalSince1970);
    return YES;
}

+ (NSString *)removeDots:(NSString *)str
{
    long len;
    
    do {
        len = [str length];
        str = [str stringByReplacingOccurrencesOfString:@"。。" withString:@"。"];
        str = [str stringByReplacingOccurrencesOfString:@".." withString:@"."];
    } while(len != [str length]);
    
    return str;
}



@end
