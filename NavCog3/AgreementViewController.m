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


#import "AgreementViewController.h"
#import "NavDataStore.h"
#import "ServerConfig.h"
#import "NavUtil.h"

@interface AgreementViewController ()

@end

@implementation AgreementViewController {
    int count; // temporary
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    conf.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    // add script to manage viewport equivalent to UIWebView
    NSString *jScript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport');"
        "meta.setAttribute('content', 'width=device-width');"
        "document.getElementsByTagName('head')[0].appendChild(meta);";

    WKUserScript *wkUScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES];
    WKUserContentController *wkUController = [[WKUserContentController alloc] init];
    [wkUController addUserScript:wkUScript];

    conf.userContentController = wkUController;

    _webview = [[HLPWebView alloc] initWithFrame:CGRectMake(0,0,0,0) configuration:conf];

    [self.view addSubview:_webview];
    _webview.navigationDelegate = self;
    [_webview setFullScreenForView:self.view];
    _webview.isAccessible = YES;
    _webview.delegate = self;

}

- (void)viewDidAppear:(BOOL)animated
{
    if (count++ == 0) {
        NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
        NSURL *url = [[ServerConfig sharedConfig].selected agreementURLWithIdentifier:device_id];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        request.timeoutInterval = 30;
        [self.webview loadRequest:request];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.webview evaluateJavaScript:@"stopAll();" completionHandler:nil];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{

    NSURL *url = [NSURL URLWithString:[[[navigationAction.request URL] standardizedURL] absoluteString]];
    if ([[url path] hasSuffix:@"/finish_agreement.jsp"]) { // check if finish page is tryed to be loaded
        NSString *identifier = [[NavDataStore sharedDataStore] userID];
        [[ServerConfig sharedConfig] checkAgreementForIdentifier:identifier withCompletion:^(NSDictionary* config) {
            BOOL agreed = [config[@"agreed"] boolValue];
            if (agreed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"unwind_agreement" sender:self];
                });
            } else {
                [[ServerConfig sharedConfig] clear];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"unwind_agreement" sender:self];
                });
            }
        }];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    [NavUtil showModalWaitingWithMessage:NSLocalizedString(@"Loading, please wait", @"")];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [NavUtil hideModalWaiting];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
}

- (void)didEnterBackground:(NSNotification*)note
{
    [self.webview evaluateJavaScript:@"stopAll();" completionHandler:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
