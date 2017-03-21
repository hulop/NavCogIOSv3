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

#import "BlindViewController.h"

#import "NavSound.h"

#import "LocationEvent.h"
#import "NavUtil.h"

#import "ServerConfig.h"

@import JavaScriptCore;
@import CoreMotion;


@interface BlindViewController () {
    NavWebviewHelper *helper;
    
    ViewState state;
}

@end

@implementation BlindViewController

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    _settingButton = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    state = ViewStateLoading;

    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
}

- (void)viewDidDisappear:(BOOL)animated
{
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL fpMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"finger_printing_mode"];

        self.devFingerprint.hidden = NO;

        self.navigationItem.rightBarButtonItem = nil;
        self.navigationItem.leftBarButtonItem = _settingButton;
        
        self.navigationItem.title = @"Fingerprint";
    });
}

- (void) startLoading {
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void) loaded {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

- (void)checkConnection {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)doFingerprint:(id)sender {
    NSLog(@"doFingerprint");
}


- (void)vibrate
{
    [[NavSound sharedInstance] vibrate:nil];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [segue destinationViewController].restorationIdentifier = segue.identifier;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
    });
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if ([sender isKindOfClass:NSArray.class]) {
            NSArray *temp = [sender copy];
            if ([temp count] > 0) {
                NSString *name = temp[0];
                temp = [temp subarrayWithRange:NSMakeRange(1, [temp count]-1)];
                [[segue destinationViewController] performSegueWithIdentifier:name sender:temp];
            }
        }
    });
}

@end
