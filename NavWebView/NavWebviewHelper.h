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
#import "NavJSNativeHandler.h"

typedef NS_ENUM(NSInteger, ViewState) {
    ViewStateMap,
    ViewStateSearch,
    ViewStateSearchDetail,
    ViewStateSearchSetting,
    ViewStateRouteConfirm,
    ViewStateNavigation,
    ViewStateTransition,
    ViewStateRouteCheck,
    ViewStateLoading
};

typedef NS_ENUM(NSInteger, WebviewControl) {
    WebviewControlRouteSearchOptionButton,
    WebviewControlRouteSearchButton,
    WebviewControlDoneButton,
    WebviewControlEndNavigation,
    WebviewControlBackToControl,
    WebviewControlNone,
};

@interface NavWebView : UIWebView

@end

@protocol NavWebviewHelperDelegate <NSObject>
- (void) startLoading;
- (void) loaded;
- (void) bridgeInserted;
- (void) checkConnection;

- (void) speak:(NSString*)text withOptions:(NSDictionary*)options;
- (BOOL) isSpeaking;

- (void) vibrateOnAudioServices;

- (void) manualLocationChangedWithOptions:(NSDictionary*)options;
- (void) buildingChangedWithOptions:(NSDictionary*)options;
- (void) wcuiStateChangedWithOptions:(NSDictionary*)options;
- (void) requestRatingWithOptions:(NSDictionary*)options;
- (void) requestOpenURL:(NSURL*)url;
@end

@interface NavWebviewHelper : NSObject <UIWebViewDelegate>

@property (nonatomic, weak) id<NavWebviewHelperDelegate> delegate;
@property (readonly) BOOL isReady;

@property (nonatomic) NSNumber *developerMode;
@property (nonatomic) NSString *userMode;

- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server
                         context:(NSString *)serverContext
                       usesHttps:(BOOL)usesHttps
                     clearsCache:(BOOL)clearsCache;
- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server
                         context:(NSString *)serverContext;
- (instancetype) initWithWebview:(UIWebView *)view
                          server:(NSString *)server;
- (void) prepareForDealloc;

- (void) triggerWebviewControl:(WebviewControl) control;
- (void) sendData:(NSObject*)data withName:(NSString*) name;
- (void) setBrowserHash:(NSString*) hash;
- (NSString*) evalScript:(NSString*) script;
- (NSDictionary*) getState;
- (void) retry;
@end
