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


#import "NavWebviewHelper.h"

#define LOADING_TIMEOUT 30

#define UI_PAGE @"%@://%@/%@mobile.jsp?noheader&noclose&id=%@"
//#define UI_PAGE @"%@://%@/%@mobile.html?noheader" // for backward compatibility
// does not work with old server


// override UIWebView accessibility to prevent reading Map contents
@implementation NavWebView

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (NSArray *)accessibilityElements
{
    return nil;
}

- (NSInteger)accessibilityElementCount
{
    return 0;
}

@end

@interface NavWebviewHelper ()

@property (nonatomic) UIWebView *webView;
@property (nonatomic) NavJSNativeHandler *handler;
@property (nonatomic, copy) NSString *callback;

@property (nonatomic) NSTimeInterval lastRequestTime;

@property (nonatomic) NSURLRequest *currentRequest;

@property (nonatomic, copy) NSString *selectedHokoukukanServer;
@property (nonatomic, copy) NSString *hokoukukanServerContext;
@property (nonatomic, getter=isUsesHttps) BOOL usesHttps;

@end

@implementation NavWebviewHelper

- (void)dealloc {
    _webView = nil;
    _handler = nil;
    _callback = nil;
    
    _currentRequest = nil;
    
    _selectedHokoukukanServer = nil;
    _hokoukukanServerContext = nil;
    
    _developerMode = nil;
    _userMode = nil;
}

- (void)prepareForDealloc
{
    [_handler prepareForDealloc];
}

- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server
                         context:(NSString *)serverContext
                       usesHttps:(BOOL)usesHttps
                     clearsCache:(BOOL)clearsCache {
    self = [super init];
    
    if (clearsCache) {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    }
    
    _isReady = NO;
    
    _webView = view;
    _webView.delegate = self;
    _webView.scrollView.bounces = NO;
    _webView.suppressesIncrementalRendering = YES;
    //_webView.scrollView.scrollEnabled = NO;
    
    _selectedHokoukukanServer = server;
    _hokoukukanServerContext = serverContext;
    _usesHttps = usesHttps;
    
    _developerMode = @(NO);
    _userMode = @"user_general";
    
    [self loadUIPage];
    
    _handler = [[NavJSNativeHandler alloc] init];
    [_handler registerWebView:_webView];
    
    [_handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        NSString *text = [param objectForKey:@"text"];
        BOOL flush = [[param objectForKey:@"flush"] boolValue];
        [self.delegate speak:text withOptions:@{@"force":@(flush)}];
    } withName:@"speak" inComponent:@"SpeechSynthesizer"];
    
    [_handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        NSString *result = [self.delegate isSpeaking]?@"true":@"false";
        NSString *name = param[@"callbackname"];
        [wv stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@.%@(%@)", _callback, name, result]];
    } withName:@"isSpeaking" inComponent:@"SpeechSynthesizer"];
    [_handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        if ([param objectForKey:@"value"]) {
            _callback = [param objectForKey:@"value"];
            //NSLog(@"callback method is %@", callback);
            [self updatePreferences];
        }
    } withName:@"callback" inComponent:@"Property"];
    [_handler registerFunc:^(NSDictionary *param, UIWebView *wv) {
        [self.delegate manualLocationChangedWithOptions:param];
    } withName:@"mapCenter" inComponent:@"Property"];
    
    [_handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        NSString *text = param[@"text"];
        //NSLog(@"%@", text);
        
        if ([text rangeOfString:@"buildingChanged,"].location == 0) {
            NSData *data = [[text substringFromIndex:[@"buildingChanged," length]] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            [self.delegate buildingChangedWithOptions:param];
        }
        if ([text rangeOfString:@"stateChanged,"].location == 0) {
            NSData *data = [[text substringFromIndex:[@"stateChanged," length]] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            [self.delegate wcuiStateChangedWithOptions:param];
        }
        if ([text rangeOfString:@"navigationFinished,"].location == 0) {
            NSData *data = [[text substringFromIndex:[@"navigationFinished," length]] dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *param = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            [self.delegate requestRatingWithOptions:param];
        }
        NSLog(@"%@", text);
    } withName:@"log" inComponent:@"System"];
    
    [_handler registerFunc:^(NSDictionary *param, UIWebView *webView) {
        [self.delegate vibrateOnAudioServices];
    } withName:@"vibrate" inComponent:@"AudioServices"];
    
    return self;
}

- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server
                         context:(NSString *)serverContext {
    return [self initWithWebview:view
                          server:server
                         context:serverContext
                       usesHttps:YES
                     clearsCache:NO];
}

- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server {
    return [self initWithWebview:view
                          server:server
                         context:@""
                       usesHttps:YES
                     clearsCache:NO];
}


# pragma mark - private methods

- (void)loadUIPage {
    NSLog(@"loadUIPage");
    NSString *server = self.selectedHokoukukanServer;
    NSString *context = self.hokoukukanServerContext;
    NSString *https = self.isUsesHttps?@"https":@"http";
    NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:UI_PAGE, https, server, context, device_id]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [_webView loadRequest: request];
    _currentRequest = request;
    _lastRequestTime = [[NSDate date] timeIntervalSince1970];
}

- (void)loadUIPageWithHash:(NSString*)hash {
    NSString *script = [NSString stringWithFormat:@"location.hash=\"%@\"", hash];
    [self evalScript:script];
}

- (void) updatePreferences
{
    if (_callback == nil) {
        return;
    }
    
    NSMutableDictionary *data = [@{} mutableCopy];
    data[@"developer_mode"] = _developerMode;
    data[@"user_mode"] = _userMode;
    NSString *jsonstr = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:data options:0 error:nil]encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"%@.onPreferences(%@);", _callback, jsonstr];
    //NSLog(@"%@", script);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView stringByEvaluatingJavaScriptFromString:script];
    });
}


#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *server = self.selectedHokoukukanServer;
    NSRange range = [request.URL.absoluteString rangeOfString:server];
    if (range.location == NSNotFound) {
        [self.delegate requestOpenURL:request.URL];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    NSLog(@"webViewDidStartLoad");
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(waitForReady:) userInfo:nil repeats:YES];
    [self.delegate startLoading];
}

- (void) waitForReady:(NSTimer*)timer
{
    NSString *ret = [_webView stringByEvaluatingJavaScriptFromString:@"(function(){return window.$hulop.mobile_ready != undefined && document.readyState != 'loading'})();"];
    
    if ([ret isEqualToString:@"true"]) {
        [timer invalidate];
        [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(insertBridge:) userInfo:nil repeats:YES];
        return;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastRequestTime > LOADING_TIMEOUT) {
        [timer invalidate];
        [_webView stopLoading];
        [self.delegate checkConnection];
    }
}

- (void) insertBridge:(NSTimer*)timer
{
    NSLog(@"insertBridge,%@", _callback);
    if (_callback != nil) { // check if "callback" string is available
        [timer invalidate];
        if ([self.delegate respondsToSelector:@selector(bridgeInserted)]) {
            [self.delegate bridgeInserted];
        }
    }
    
    NSBundle *bundle = [NSBundle bundleForClass:[NavWebviewHelper class]];
    NSString *path = [bundle pathForResource:@"ios_bridge" ofType:@"js"];
    NSString *script = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    [_webView stringByEvaluatingJavaScriptFromString:script];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView2
{
    int status = [[[webView2 request] valueForHTTPHeaderField:@"Status"] intValue];
    
    NSLog(@"webViewDidFinishLoad %d %@", status, webView2.request.URL.absoluteString);
    if (status == 404) {
    }
    [self.delegate loaded];
    _isReady = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"%@", error);
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self loadUIPage];
    });
}


# pragma mark - public methods

- (void) triggerWebviewControl:(WebviewControl) control
{
    switch (control) {
        case WebviewControlRouteSearchOptionButton:
            [self evalScript:@"$('a[href=\"#settings\"]').click()"];
            break;
        case WebviewControlRouteSearchButton:
            [self evalScript:@"$('a[href=\"#control\"]').click()"];
            break;
        case WebviewControlDoneButton:
            [self evalScript:@"$('div[role=banner]:visible a').click()"];
            break;
        case WebviewControlEndNavigation:
            [self evalScript:@"$('#end_navi').click()"];
            break;
        case WebviewControlBackToControl:
            [self evalScript:@"$('div[role=banner]:visible a').click()"];
            break;
        default:
            [self evalScript:@"$hulop.map.resetState()"];
            //[self evalScript:@"$('a[href=\"#map-page\"]:visible').click()"];
            break;
    }
}

- (NSObject*) removeNaNValue:(NSObject*)obj
{
    NSObject* newObj;
    if ([obj isKindOfClass:NSArray.class]) {
        NSArray* arr = (NSArray*) obj;
        NSMutableArray* newArr = [arr mutableCopy];
        for(int i=0; i<[arr count]; i++){
            NSObject* tmp = arr[i];
            newArr[i] = [self removeNaNValue:tmp];
        }
        newObj = (NSObject*) newArr;
    }else if ([obj isKindOfClass:NSDictionary.class]) {
        NSDictionary* dict = (NSDictionary*) obj;
        NSMutableDictionary* newDict = [dict mutableCopy];
        for(id key in [dict keyEnumerator]){
            NSObject* val = dict[key];
            if([val isKindOfClass:NSNumber.class]){
                double dVal = [(NSNumber*) val doubleValue];
                if(isnan(dVal)){
                    [newDict removeObjectForKey:key];
                }
            }
        }
        newObj = (NSObject*) newDict;
    }
    return newObj;
}

- (void) sendData:(NSObject*)data withName:(NSString*) name
{
    if (_callback == nil) {
        return;
    }
    
    data = [self removeNaNValue:data];
    
    NSString *jsonstr = [[NSString alloc] initWithData: [NSJSONSerialization dataWithJSONObject:data options:0 error:nil]encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"%@.onData('%@',%@);", _callback, name, jsonstr];
    //NSLog(@"%@", script);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView stringByEvaluatingJavaScriptFromString:script];
    });
}

- (void)setBrowserHash:(NSString *)hash
{
    [self loadUIPageWithHash:hash];
}

- (NSString *)evalScript:(NSString *)script
{
    //NSLog(@"evalScript(%@)", script);
    return [_webView stringByEvaluatingJavaScriptFromString:script];
}

- (void)retry
{
    [self loadUIPage];
}

- (NSDictionary*) getState
{
    NSString *state = [self evalScript:@"(function(){return JSON.stringify($hulop.map.getState());})()"];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[state dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (json) {
        return json;
    } else {
        NSLog(@"%@", error.localizedDescription);
    }
    return nil;
}

- (void)setDeveloperMode:(NSNumber *)developerMode
{
    _developerMode = developerMode;
    [self updatePreferences];
}

- (void)setUserMode:(NSString *)userMode
{
    _userMode = userMode;
    [self updatePreferences];
}

@end
