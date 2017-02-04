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

#import "RatingViewController.h"
#import "HLPDataUtil.h"
#import "NavUtil.h"
#import "ServerConfig.h"

@interface RatingViewController ()

@end

@implementation RatingViewController {
    BOOL submitting;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    _freeComment.delegate = self;
    _scrollView.delegate = self;
    _overallStars.delegate = self;
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];

    [self updateView];
}

- (void)cancel:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.submitButton.enabled = _overallStars.stars > 0;

        self.overallStars.disabled = submitting;
        self.q1Stars.disabled = submitting;
        self.q2Stars.disabled = submitting;
        self.q3Stars.disabled = submitting;
        self.q4Stars.disabled = submitting;
        self.freeComment.editable = !submitting;
    });
}

- (void)didChangeStarRating:(StarRatingView *)sender
{
    [self updateView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [_freeComment resignFirstResponder];
}

- (void)viewWillLayoutSubviews
{
    _freeComment.layer.cornerRadius = 5.0f;
    _freeComment.layer.masksToBounds = NO;
    _freeComment.layer.borderWidth = .5f;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    _bottomConst.constant = keyboardFrame.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
    CGRect frame = _freeComment.frame;
    frame.size.height += keyboardFrame.size.height;
    [_scrollView scrollRectToVisible:frame animated:NO];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    _bottomConst.constant = 0;
    
    [UIView animateWithDuration:duration animations:^{
        [self.view layoutIfNeeded];
    }];
}

#define API_ENQUETE @"%@://%@/%@api/enquete"

- (IBAction)submitRating:(id)sender {
    submitting = YES;
    [self updateView];
    [NavUtil showModalWaitingWithMessage:NSLocalizedString(@"THANKYOU_SENDING", @"")];
    
    NSDictionary *answers =
    @{
      @"from": _from?_from:@"unknown", @"to": _to?_to:@"unknown",
      @"start": @((long)(_start*1000)), @"end": @((long)(_end*1000)),
      @"device_id": _device_id?_device_id:@"unknown",
      @"type": @"application",
      @"total": @(_overallStars.stars),
      @"q1": @(_q1Stars.stars),
      @"q2": @(_q2Stars.stars),
      @"q3": @(_q3Stars.stars),
      @"q4": @(_q4Stars.stars),
      @"comment": _freeComment.text?_freeComment.text:@""
      };
    NSData *answersData = [NSJSONSerialization dataWithJSONObject:answers options:0 error:nil];
    NSString *answersStr = [[NSString alloc] initWithData:answersData encoding:NSUTF8StringEncoding];
    NSDictionary *data =
    @{
      @"answers": answersStr
      };

    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    NSString *context = [[NSUserDefaults standardUserDefaults] stringForKey:@"hokoukukan_server_context"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:API_ENQUETE, https, server, context]];

    [HLPDataUtil postRequest:url withData:data callback:^(NSData *response) {
        [[ServerConfig sharedConfig] completeRating];

        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 2.0*NSEC_PER_SEC);
        dispatch_after(delay, dispatch_get_main_queue(), ^{
            [NavUtil hideModalWaiting];
            [self.navigationController popViewControllerAnimated:YES];
        });
    }];
}

@end
