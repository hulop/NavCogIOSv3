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


#import "NavJSNativeHandler.h"

@interface WebViewWrapper: NSObject <UIWebViewDelegate> {
}
@property (weak) UIWebView *webview;
@property (weak) NSObject<UIWebViewDelegate> *chain;
- (id) initWithWebView: (UIWebView*)webview;
@end
@implementation WebViewWrapper
- (id)initWithWebView:(UIWebView *)webview
{
    self = [super init];
    self.webview = webview;
    self.chain = webview.delegate;
    return self;
}
@end

@implementation NavJSNativeHandler

- (id) init
{
    self = [super init];
    self.funcs = [[NSMutableDictionary alloc] init];
    self.callbacks = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) prepareForDealloc
{
    for(int i = 0; i < [self.webViews count]; i++) {
        WebViewWrapper *temp = [self.webViews objectAtIndex:i];
        temp.webview.delegate = nil;
        temp.chain = nil;
        [self.webViews removeObjectAtIndex:i];
    }
    
    [self.funcs removeAllObjects];
    [self.callbacks removeAllObjects];
}

- (void) registerWebView:(UIWebView *)webView
{
    if (!self.webViews) {
        self.webViews = [[NSMutableArray alloc] init];
        self.defaultWebView = webView;
    }
    WebViewWrapper *wrapper = [[WebViewWrapper alloc] initWithWebView:webView];
    wrapper.webview.delegate = self;
    [self.webViews addObject:wrapper];
}

- (void)unregisterWebView:(UIWebView *)webView
{
    [self removeWrapper: webView];
}

- (long) browserCount
{
    return (unsigned long)[self.webViews count];
}

- (WebViewWrapper*) findWrapper: (UIWebView*) webView
{
    for(WebViewWrapper *wvw in self.webViews) {
        if (wvw.webview == webView) return wvw;
    }
    return nil;
}

- (void) removeWrapper: (UIWebView*) webView
{
    WebViewWrapper *w = [self findWrapper:webView];
    if (w) {
        for(int i = 0; i < [self.webViews count]; i++) {
            if ([self.webViews objectAtIndex:i] == w) {
                WebViewWrapper *temp = [self.webViews objectAtIndex:i];
                temp.webview.delegate = nil;
                [self.webViews removeObjectAtIndex:i];
            }
        }
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    WebViewWrapper *wvw = [self findWrapper:webView];
    [wvw.chain webViewDidStartLoad:webView];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    WebViewWrapper *wvw = [self findWrapper:webView];
    [wvw.chain webViewDidFinishLoad:webView];
}

- (void)registerFunc:(void (^)(NSDictionary *, UIWebView *))func withName:(NSString *)name inComponent:(NSString *)component {
    [self.funcs setObject:[func copy] forKey:[NSString stringWithFormat:@"%@.%@", component, name]];
    
    if (IRTCF_DEBUG) NSLog(@"Register %@.%@",component, name);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = [request URL];
    if (IRTCF_DEBUG) NSLog(@"%@", url);
    
    if ([@"about:blank" isEqualToString:[url absoluteString]]) {
        return NO;
    }
    else if ([@"native" isEqualToString:[url scheme]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [webView stringByEvaluatingJavaScriptFromString:@"$IOS.readyForNext=true;"];
        });
        NSString *component = [url host];
        NSString *func = [[url pathComponents] objectAtIndex:1];
        NSString *paramString = [url query];
        
        NSMutableDictionary *param = [[NSMutableDictionary alloc] init];
        NSArray *keyValues = [paramString componentsSeparatedByString:@"&"];
        for(int i = 0; i < [keyValues count]; i++) {
            NSArray *keyValue = [[keyValues objectAtIndex:i] componentsSeparatedByString:@"="];
            ////NSLog(@"%@", keyValue);
            if ([keyValue count] == 2) {
                NSString *key = [keyValue objectAtIndex:0];
                NSString *value = [[keyValue objectAtIndex:1] stringByRemovingPercentEncoding];
                ////NSLog(@"%@=%@", key, value);
                [param setObject:value forKey:key];
            }
        }
        NSString *name = [NSString stringWithFormat:@"%@.%@", component, func];
        NSString *name2 = [NSString stringWithFormat:@"%@.%@.webview", component, func];
        NSString *callbackStr = [param objectForKey:@"callback"];
        if (callbackStr) {
            [self.callbacks setObject:callbackStr forKey:name];
            [self.callbacks setObject:webView forKey:name2];
        }
        void (^f)(NSDictionary*,UIWebView*) = (void (^)(NSDictionary*,UIWebView*)) [self.funcs objectForKey:name];
        if (f) {
            f(param, webView);
        } else {
            if (IRTCF_DEBUG) NSLog(@"No function for %@.%@", component, func);
        }
        
        return NO;
    }
    WebViewWrapper *wvw = [self findWrapper:webView];

    return [wvw.chain webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
;
}

-(void) _callback:(NSString *)name withScript: (NSString*)str
{
    NSString *name2 = [NSString stringWithFormat:@"%@.webview", name];
    UIWebView *webView = [self.callbacks objectForKey:name2];
    [self _callback:name withScript:str forWebView:webView];
}

-(void) _callback:(NSString *)name withScript: (NSString*)str forWebView:(UIWebView*) webView;
{
    NSString *callbackStr = [self.callbacks objectForKey:name];
    
    [self _callback:name withCallbackStr:callbackStr withScript:str forWebView:webView];
}


-(void) _callback:(NSString *)name withCallbackStr:(NSString*)callbackStr withScript: (NSString*)str forWebView:(UIWebView*) webView
{
    if (callbackStr) {
        NSString *script = [NSString stringWithFormat:@"setTimeout(function(){(%@)(%@)},0)", callbackStr, str];
        if (IRTCF_DEBUG) NSLog(@"call %@", script);
        dispatch_async(dispatch_get_main_queue(), ^{
            [webView stringByEvaluatingJavaScriptFromString: script];
        });
    }
}

- (void) callback:(NSString *)name withCallbackStr:(NSString *)callback withJSON:(NSObject *)obj {
    
    NSString *name2 = [NSString stringWithFormat:@"%@.webview", name];
    UIWebView *webView = [self.callbacks objectForKey:name2];
    NSString *json = obj?[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil] encoding:NSUTF8StringEncoding]:@"null";
    [self _callback:name withCallbackStr:callback withScript:json forWebView:webView];
}

-(void) callback:(NSString *)name withJSONStr: (NSString*) jsonStr
{
    NSObject *obj = [NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    [self callback:name withJSON:obj];
}

-(void) callback:(NSString *)name withJSONStr: (NSString*) jsonStr forWebView:(UIWebView *)webView
{
    NSObject *obj = [NSJSONSerialization JSONObjectWithData:[jsonStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    [self callback:name withJSON:obj forWebView: webView];
}

-(void) callback:(NSString *)name withJSON:(NSObject*)obj
{
    NSString *json = obj?[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil] encoding:NSUTF8StringEncoding]:@"null";
    [self _callback:name withScript:json];
}

-(void) callback:(NSString *)name withJSON:(NSObject*)obj forWebView:(UIWebView*) webView
{
    NSString *json = obj?[[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil] encoding:NSUTF8StringEncoding]:@"null";
    [self _callback:name withScript:json forWebView:webView];
}

-(void) callback:(NSString *)name withString:(NSString *)str
{
    str = [str stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
    [self _callback:name withScript:[NSString stringWithFormat:@"\"%@\"",str]];
}

-(void) callback:(NSString *)name withScriptString:(NSString *)str
{
    [self _callback:name withScript:str];
}

- (void)callback:(NSString *)name withBool:(BOOL)result
{
    [self _callback:name withScript:result?@"true":@"false"];
}




@end
