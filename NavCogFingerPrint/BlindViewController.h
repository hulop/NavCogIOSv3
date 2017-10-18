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
#import <NavWebView/NavWebView.h>
#import "NavCoverView.h"
#import "FingerprintManager.h"
#import "POIManager.h"

typedef NS_ENUM(NSInteger, FPMode) {
    FPModeFingerprint,
    FPModeBeacon,
    FPModeID,
    FPModePOI
};

@interface BlindViewController : UIViewController <NavWebviewHelperDelegate, FingerprintManagerDelegate, POIManagerDelegate, UIGestureRecognizerDelegate, UITabBarDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *searchButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *micButton;
@property (weak, nonatomic) IBOutlet UIButton *retryButton;
@property (weak, nonatomic) IBOutlet UILabel *errorMessage;

@property (weak, nonatomic) IBOutlet NavCoverView *cover;
@property (weak, nonatomic) IBOutlet UIButton *devLeft;
@property (weak, nonatomic) IBOutlet UIButton *devRight;
@property (weak, nonatomic) IBOutlet UIButton *devGo;
@property (weak, nonatomic) IBOutlet UIButton *devAuto;
@property (weak, nonatomic) IBOutlet UIButton *devReset;
@property (weak, nonatomic) IBOutlet UIButton *devMarker;
@property (weak, nonatomic) IBOutlet UIButton *devUp;
@property (weak, nonatomic) IBOutlet UIButton *devDown;
@property (weak, nonatomic) IBOutlet UIButton *devNote;
@property (weak, nonatomic) IBOutlet UIButton *devRestart;

@property (weak, nonatomic) IBOutlet UILabel *commitLabel;

@end
