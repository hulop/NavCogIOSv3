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

#import "ExpViewController.h"
#import "ExpConfig.h"
#import "NavUtil.h"
#import "NavDataStore.h"
#import "LocationEvent.h"

@interface ExpViewController ()

@end

@implementation ExpViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.errorLabel.hidden = YES;
    self.emailInput.delegate = self;
    
    NSString *user_id = [[NSUserDefaults standardUserDefaults] stringForKey:@"exp_user_id"];
    if (user_id) {
        self.emailInput.text = user_id;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationsChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];

    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.emailInput) {
        [self submit];
        return NO;
    }
    return YES;
}

- (IBAction)submit:(id)sender {
    [_emailInput resignFirstResponder];
    [self submit];
}

- (void)submit
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.errorLabel.text = @" ";
        [NavUtil showModalWaitingWithMessage:@"Checking email address..."];
    });
    
    [[NavDataStore sharedDataStore] reloadDestinations:YES];
}

- (void)loadUserInfo
{
    NSString *user_id = self.emailInput.text;
    
    [[ExpConfig sharedConfig] requestUserInfo:user_id withComplete:^(NSDictionary * info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideModalWaiting];
            self.errorLabel.hidden = (info != nil);
            
            if (info == nil) { // error
                self.errorLabel.text = @"invalid email address";
            } else {
                self.errorLabel.text = @" ";
                [[NSUserDefaults standardUserDefaults] setObject:user_id forKey:@"exp_user_id"];
                [self loadRoutes];
            }
        });        
    }];
}

- (void)loadRoutes
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.errorLabel.text = @" ";
        [NavUtil showModalWaitingWithMessage:@"Loading..."];
    });
        
    [[ExpConfig sharedConfig] requestRoutesConfig:^(NSDictionary * routes) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideModalWaiting];
            self.errorLabel.hidden = (routes != nil);
            
            if (routes == nil) {
                self.errorLabel.text = @"no routes info";
            } else {
                self.errorLabel.text = @" ";
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self dismissViewControllerAnimated:YES completion:nil];
                });
            }
        });
    }];

}

- (void) destinationsChanged:(NSNotification*)note
{
    [NavUtil hideModalWaiting];
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if ([[nds destinations] count] == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                       message:@"No destinations"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                      dispatch_async(dispatch_get_main_queue(), ^(void){
                                                          [self dismissViewControllerAnimated:YES completion:nil];
                                                      });
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alert animated:YES completion:nil];
        });
    } else {
        [self loadUserInfo];
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

@end
