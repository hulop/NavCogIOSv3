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


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define IRTCF_DEBUG NO

@interface NavJSNativeHandler : NSObject <UIWebViewDelegate> {
}
@property (weak) UIWebView *defaultWebView;
@property NSMutableArray *webViews;
@property NSMutableDictionary *funcs;
@property NSMutableDictionary *callbacks;


- (id) init;
- (void) prepareForDealloc;
- (void) registerWebView: (UIWebView*)webView;
- (void) unregisterWebView: (UIWebView*)webView;
- (long) browserCount;

- (void) callback:(NSString*) name withJSON: (NSObject*) obj;
- (void) callback:(NSString*) name withJSONStr: (NSString*) jsonStr;
- (void) callback:(NSString*) name withString: (NSString*) str;
- (void) callback:(NSString*) name withBool: (BOOL) result;
- (void) callback:(NSString*) name withScriptString:(NSString *)str;
- (void) callback:(NSString*) name withJSONStr: (NSString*) jsonStr forWebView: (UIWebView*) webView;
- (void) callback:(NSString*) name withCallbackStr: (NSString*) callback withJSON: (NSObject*) obj;

- (void) registerFunc: (void (^)(NSDictionary *param, UIWebView *webView))func withName: (NSString*) name inComponent: (NSString*) component;

@end
