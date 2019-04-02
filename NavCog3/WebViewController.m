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

#import "WebViewController.h"
#import "NavDataStore.h"
#import "ServerConfig.h"
#import "NavUtil.h"
#import "NavDeviceTTS.h"

@interface WebViewController ()

@end

@implementation WebViewController {
    BOOL initialFocused;
    BOOL initialRead;
    BOOL webpageReady;
    BOOL pageClosed;
    UILabel *titleView;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeFocused:) name:AccessibilityElementDidBecomeFocused object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didBecomeFocused:(NSNotificationCenter*)note
{
    if (webpageReady && initialRead == NO) {
        initialRead = YES;
        [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            if (pageClosed) {
                [timer invalidate];
                return;
            }
            if (webpageReady) {
                UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _webview);
                [timer invalidate];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSLog(@"$hulop.read_to_read is called");
                    NSString *script = @"(function (){if(window.$hulop && $hulop.ready_to_read) {$hulop.ready_to_read();} else {setTimeout(arguments.callee,100)}})()";
                    [_webview evaluateJavaScript:script completionHandler:^(id _Nullable res, NSError * _Nullable error) {
                        if (error) {
                            NSLog(@"%@", error.description);
                        }
                    }];
                });
            }
        }];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /* init webview */

    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    conf.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    
    _webview = [[HLPWebView alloc] initWithFrame:CGRectMake(0,0,0,0) configuration:conf];

    [self.view addSubview:_webview];
    _webview.navigationDelegate = self;
    [_webview setFullScreenForView:self.view];
    _webview.isAccessible = YES;
    _webview.delegate = self;
    _webview.tts = self;
    /* end init webview */
    
    NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
    [self.webview loadRequest:request];
    
    titleView = [[UILabel alloc] init];
    titleView.text = self.title;
    self.navigationItem.titleView = titleView;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"WEB_PAGE,%@,%@,open,%ld", self.title, self.url, (long)([[NSDate date] timeIntervalSince1970]*1000));
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    webpageReady = YES;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, titleView);
}

- (void)didEnterBackground:(NSNotification*)note
{
    [self.webview evaluateJavaScript:@"stopAll();" completionHandler:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"WEB_PAGE,%@,%@,close,%ld", self.title, self.url, (long)([[NSDate date] timeIntervalSince1970]*1000));
    pageClosed = YES;
    [self.webview evaluateJavaScript:@"stopAll();" completionHandler:nil];
    if (self.delegate) {
        [self.delegate webViewControllerClosed:self];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

+ (instancetype)getInstance
{
    WebViewController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"web_view"];
    return vc;
}

+ (NSURL*) hulopHelpPageURLwithType:(NSString*)helpType languageDetection:(BOOL)languageDetection
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];

    NSString *lang = [[NavDataStore sharedDataStore] userLanguage];
    if (languageDetection) {
        // is server supported user lang
        if ([[ServerConfig sharedConfig].selected.name stringByLanguage:lang] == nil) {
            lang = @"en";
        }
        lang = [@"-" stringByAppendingString:lang];
        if ([lang isEqualToString:@"-en"]) { lang = @""; }
    } else {
        lang = @"";
    }
    NSString *base = @"https://hulop.github.io/";
    NSString *url = nil;
    if ([appName isEqualToString:@"NavCog3"]) {
        url = [NSString stringWithFormat:@"%@%@%@",base, helpType, lang];
    } else if ([appName isEqualToString:@"NavCogPreview"]) {
        url = [NSString stringWithFormat:@"%@%@_preview%@",base, helpType, lang];
    }
    NSLog(@"%@", url);
    return [NSURL URLWithString:url];
}

+ (void) checkHttpStatusWithURL:(NSURL *)url completionHandler:(void (^)(NSURL * _Nonnull url, NSInteger statusCode))completion
{
    @try {
        NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                            timeoutInterval:60.0];

        NSLog(@"Requesting %@", url);

        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithRequest:request
                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
              @try {
                  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                  NSInteger statusCode = [httpResponse statusCode];
                  if (!error) {
                      completion(url, statusCode);
                  } else {
                      completion(url, 0);
                      NSLog(@"Error: %@", [error localizedDescription]);
                  }
              } @catch (NSException *exception) {
                  NSLog(@"%@", [exception debugDescription]);
              }
          }] resume];
    } @catch (NSException *exception) {
        NSLog(@"%@", [exception debugDescription]);
        completion(url, 0);
    }
}

- (void)speak:(NSString *)text force:(BOOL)isForce completionHandler:(void (^)(void))completion
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force":@(isForce),@"nohistory": @(YES)} completionHandler:completion];
}

- (BOOL)isSpeaking
{
    return [[NavDeviceTTS sharedTTS] isSpeaking];
}

- (void)vibrate
{
    //
}

@end
