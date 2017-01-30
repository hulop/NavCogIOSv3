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
#import "ServerConfig.h"

@interface AgreementViewController ()

@end

@implementation AgreementViewController {
    int count; // temporary
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.webView.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated
{
    if (count++ == 0) {
        NSString *server_host = [[ServerConfig sharedConfig].selected objectForKey:@"hostname"];
        NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
        NSDictionary *config = [ServerConfig sharedConfig].agreementConfig;
        NSString *agreementPath = config[@"path"];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@?id=%@",server_host, agreementPath, device_id]];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
        request.timeoutInterval = 30;
        [self.webView loadRequest:request];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // TODO: arrow only our content
    NSURL *url = [NSURL URLWithString:[[[request URL] standardizedURL] absoluteString]];
    if ([[url path] isEqualToString:@"/finish_agreement.jsp"]) { // check if finish page is tryed to be loaded
        [[ServerConfig sharedConfig] checkAgreement:^(NSDictionary* config) {
            BOOL agreed = [config[@"agreed"] boolValue];
            if (agreed) {
                [self performSegueWithIdentifier:@"unwind_agreement" sender:self];
            } else {
                [[ServerConfig sharedConfig] clear];
                [self performSegueWithIdentifier:@"unwind_agreement" sender:self];
            }
        }];
        return NO;
    }
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.waitIndicator.hidden = NO;
        [self.waitIndicator startAnimating];
    });
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.waitIndicator.hidden = YES;
        [self.waitIndicator stopAnimating];
    });
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
