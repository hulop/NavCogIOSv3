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


#import "WelcomViewController.h"
#import "ServerConfig.h"
#import "AuthManager.h"
#import "LocationEvent.h"
#import "Logging.h"

@interface WelcomViewController ()

@end

@implementation WelcomViewController {
    BOOL first;
    int agreementCount;
    int retryCount;
    BOOL networkError;
}

- (void)viewDidLoad {
    [super viewDidLoad];
 
    agreementCount = 0;
    first = YES;
    
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
    // TODO set serverlist address
    if (first) {
        first = NO;
        [self checkConfig];
    }
    self.navigationItem.hidesBackButton = YES;
}

- (void)updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (networkError) {
            self.statusLabel.text = NSLocalizedString(@"checkNetworkConnection",@"");
        } else {
            self.statusLabel.text = @"";
        }
        self.retryButton.hidden = !networkError;
    });
}

- (void)didNetworkError
{
    networkError = YES;
    [self updateView];
}

- (IBAction)retry:(id)sender {
    networkError = NO;
    retryCount = 0;
    agreementCount = 0;
    [self updateView];
    [self checkConfig];
}

- (void) checkConfig
{
    if (self.presentedViewController) {
        //NSLog(@"Presenting: %@", self.presentedViewController);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1f*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self checkConfig];
        });
        return;
    }
    
    /*
    if ([[AuthManager sharedManager] isDeveloperAuthorized]) {
        [self performSegueWithIdentifier:@"show_mode_selection" sender:self];
        return;
    }
     */
    
    if (retryCount > 3) {
        [self didNetworkError];
        return;
    }
    retryCount++;
    
    ServerConfig *config = [ServerConfig sharedConfig];

    if (!config.selected) {
        if (config.serverList) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSegueWithIdentifier:@"show_server_selection" sender:self];
            });
        } else {
            NSLog(@"loading serverlist.json");
            self.statusLabel.text = NSLocalizedString(@"CheckServerList", @"");
            [[ServerConfig sharedConfig] requestServerList:@"" withComplete:^(NSDictionary *config) {
                [self checkConfig];
                if (config) { retryCount = 0; }
            }];
        }

        return;
    }
    
    
    if (config.selected) {
        if (config.agreementConfig) {
            BOOL agreed = [config.agreementConfig[@"agreed"] boolValue];
            if (agreed) {
                NSLog(@"no check agreement");
                // noop
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"show_agreement" sender:self];
                });
                return;
            }
        } else {
            NSLog(@"check agreement");
            
            self.statusLabel.text = NSLocalizedString(@"CheckAgreement", @"");
            [[ServerConfig sharedConfig] checkAgreement:^(NSDictionary* config) {
                [self checkConfig];
                if (config) { retryCount = 0; }
            }];
            return;
        }
        
        if (config.selectedServerConfig) {
            NSArray *files = [config checkDownloadFiles];
            if ([files count] > 0) {
                NSLog(@"check download files");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"show_download" sender:self];
                });
            } else {
                NSLog(@"file downloaded");
                NSArray *files = config.downloadConfig[@"map_files"];
                NSFileManager *fm = [NSFileManager defaultManager];

                NSError *error;
                NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
                for(NSString *path in files) {
                    NSString *toPath = [path lastPathComponent];
                    toPath = [docPath stringByAppendingPathComponent:toPath];
                    [fm removeItemAtPath:toPath error:nil];
                    [fm copyItemAtPath:path toPath:toPath error:&error];
                    
                    NSString *filename = [toPath lastPathComponent];
                    [[NSUserDefaults standardUserDefaults] setObject:filename forKey:@"bleloc_map_data"];
                }
                NSString *presetsDir = [docPath stringByAppendingPathComponent:@"presets"];
                [fm createDirectoryAtPath:presetsDir withIntermediateDirectories:YES attributes:nil error:nil];

                if (config.downloadConfig[@"preset_for_blind"]) {
                    [fm removeItemAtPath:[presetsDir stringByAppendingPathComponent:@"blind.plist"] error:nil];
                    [fm copyItemAtPath:config.downloadConfig[@"preset_for_blind"]
                                toPath:[presetsDir stringByAppendingPathComponent:@"blind.plist"] error:&error];
                }
                if (config.downloadConfig[@"preset_for_sighted"]) {
                    [fm removeItemAtPath:[presetsDir stringByAppendingPathComponent:@"general.plist"] error:nil];
                    [fm copyItemAtPath:config.downloadConfig[@"preset_for_sighted"]
                                toPath:[presetsDir stringByAppendingPathComponent:@"general.plist"] error:&error];
                }
                if (config.downloadConfig[@"preset_for_wheelchair"]) {
                    [fm removeItemAtPath:[presetsDir stringByAppendingPathComponent:@"wheelchair.plist"] error:nil];
                    [fm copyItemAtPath:config.downloadConfig[@"preset_for_wheelchair"]
                                toPath:[presetsDir stringByAppendingPathComponent:@"wheelchair.plist"] error:&error];
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CONFIG_CHANGED_NOTIFICATION
                                                                    object:self
                                                                  userInfo:config.selectedServerConfig];

                [Logging stopLog];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logging_to_file"]) {
                    [Logging startLog];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *hostname = config.selected[@"hostname"];
                    [[NSUserDefaults standardUserDefaults] setObject:hostname forKey:@"selected_hokoukukan_server"];
                    [self performSegueWithIdentifier:@"show_mode_selection" sender:self];
                });
            }
        } else {
            NSLog(@"check server config");
            //self.statusLabel.text = NSLocalizedString(@"CheckServerConfig", @"");   // changed by Dragan I think ...
            [[ServerConfig sharedConfig] requestServerConfig:^(NSDictionary *config) {
                [self checkConfig];
                if (config) { retryCount = 0; }
            }];
            return;
        }
    }
}

- (IBAction)returnActionForSegue:(UIStoryboardSegue *)segue
{
    [self checkConfig];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}


@end
