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

#import <UIKit/UIKit.h>
#import <HLPWebView/HLPWebView.h>

@class WebViewController;

@protocol WebViewControllerDelegate
@required
- (void)webViewControllerClosed:(WebViewController*)controller;
@end

@interface WebViewController : UIViewController <WKNavigationDelegate, HLPTTSProtocol>

@property NSURL* url;
@property HLPWebView *webview;
@property (weak) id<WebViewControllerDelegate> delegate;

+ (instancetype) getInstance;
+ (NSURL*) hulopHelpPageURLwithType:(NSString*)helpType;

@end
