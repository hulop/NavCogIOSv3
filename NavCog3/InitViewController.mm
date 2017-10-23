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

#import "InitViewController.h"
#import "ConfigManager.h"
#import "LocationManager.h"
#import "NavUtil.h"
#import "ServerConfig.h"
#import "AuthManager.h"

@interface InitViewController ()

@end

@implementation InitViewController {
    BOOL first;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    first = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void) updateView
{
    self.blindButton.enabled = NO;
    //self.wcButton.enabled = NO;
    //self.gpButton.enabled = NO;
    
    NSDictionary *config = [ServerConfig sharedConfig].selectedServerConfig;
    
    if (config[@"key_for_blind"]) {
        BOOL blind_authorized = [[AuthManager sharedManager] isAuthorizedForName:@"blind" withKey:config[@"key_for_blind"]];
        self.blindButton.enabled = blind_authorized;
    } else {
        self.blindButton.enabled = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    NSDictionary *config = [ServerConfig sharedConfig].selectedServerConfig;
    if (config[@"default_mode"] && first) {
        first = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:config[@"default_mode"] sender:self];
        });
    }
}


- (void)infoButtonPushed:(NSObject*)sender
{
    NSURL *url = [NSURL URLWithString:@"https://hulop.github.io/"];
    [NavUtil openURL:url onViewController:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"user_blind"]) {
        [ConfigManager loadConfig:@"presets/blind.plist"];
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_BLIND" forKey:@"ui_mode"];
    }
    else if ([segue.identifier isEqualToString:@"user_wheelchair"]) {
        [ConfigManager loadConfig:@"presets/wheelchair.plist"];
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_WHEELCHAIR" forKey:@"ui_mode"];
    }
    else if ([segue.identifier isEqualToString:@"user_general"]) {
        [ConfigManager loadConfig:@"presets/general.plist"];
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_WHEELCHAIR" forKey:@"ui_mode"];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:segue.identifier forKey:@"user_mode"];
    
    LocationManager *manager = [LocationManager sharedManager];
    manager.isReadyToStart = YES;
    [manager start];

}

- (IBAction)backPerformed:(id)sender {
    [[ServerConfig sharedConfig] clear];
    [self performSegueWithIdentifier:@"unwind_init" sender:self];
}

@end
