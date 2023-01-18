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
#import "NavDataStore.h"

@interface WelcomViewController ()

@end

@implementation WelcomViewController {
    BOOL first;
    int agreementCount;
    int retryCount;
    BOOL networkError;
    CBCentralManager *bluetoothManager;
    CLLocationManager *locationManager;
    BOOL isLocationAlert;
}

- (void)viewDidLoad {
    [super viewDidLoad];
 
    agreementCount = 0;
    first = YES;
    isLocationAlert = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataInitializeRestart:) name:DATA_INITIALIZE_RESTART object:nil];
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (first) {
        first = NO;
//        [self checkConfig];
        [self detectBluetooth];
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

- (void) dataInitializeRestart:(NSNotification*) note
{
    [self detectBluetooth];
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
    [[ServerConfig sharedConfig] clear];
    [self updateView];
    [self checkConfig];
}

- (void) checkConfig
{
    if (retryCount > 3) {
        [self didNetworkError];
        return;
    }
    retryCount++;
    
    ServerConfig *config = [ServerConfig sharedConfig];

    if (config.selected == nil) {
        if (config.serverList == nil) { // load server list
            NSLog(@"loading serverlist.json");
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = NSLocalizedString(@"CheckServerList", @"");
            });
            [[ServerConfig sharedConfig] requestServerList:^(ServerList *list) {
                config.selected = list.firstObject;
                [self checkConfig];
                if (list) { retryCount = 0; }
            }];
        }
        return;
    } else {
        if (config.agreementConfig == nil) {
            NSLog(@"check agreement");
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = NSLocalizedString(@"CheckAgreement", @"");
            });
            NSString *identifier = [[NavDataStore sharedDataStore] userID];
            [[ServerConfig sharedConfig] checkAgreementForIdentifier:identifier withCompletion:^(NSDictionary* config) {
                [self checkConfig];
                if (config) { retryCount = 0; }
            }];
            return;
        }
        
        if (config.selectedServerConfig == nil) {
            NSLog(@"check server config");
            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = NSLocalizedString(@"CheckServerConfig", @"");
            });
            [[ServerConfig sharedConfig] requestServerConfig:^(NSDictionary *config) {
                [self checkConfig];
                if (config) { retryCount = 0; }
            }];
            return;
        } else {
            NSArray *files = [config checkDownloadFiles];
            if ([files count] > 0) {
                NSLog(@"check download files");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"show_download" sender:self];
                });
            } else {
                NSLog(@"file downloaded");
                [config setDataDownloaded:true];
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_INIT object:nil];

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
                
                // copy preset files
                NSString *presetsDir = [docPath stringByAppendingPathComponent:@"presets"];
                [fm createDirectoryAtPath:presetsDir withIntermediateDirectories:YES attributes:nil error:nil];
                
                [config enumerateModes:^(id _Nonnull mode, id  _Nonnull obj) {
                    NSString *name = [NSString stringWithFormat:@"%@.plist", mode];
                    NSString *path = [presetsDir stringByAppendingPathComponent:name];
                    [fm removeItemAtPath:path error:nil];
                    [fm copyItemAtPath:obj toPath:path error:nil];
                }];                
                
                [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CONFIG_CHANGED_NOTIFICATION
                                                                    object:self
                                                                  userInfo:config.selectedServerConfig];
                
                NSString *hostname = config.selected.hostname;
                [[NSUserDefaults standardUserDefaults] setObject:hostname forKey:@"selected_hokoukukan_server"];
                
                NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                
                NSString *mode = [ud stringForKey:@"RouteMode"];
                if (mode.length == 0) {
                    mode = @"user_general";
                }

                [ud setObject:mode forKey:@"user_mode"];

                [Logging stopLog];
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logging_to_file"]) {
                    BOOL sensor = [[NSUserDefaults standardUserDefaults] boolForKey:@"logging_sensor"];
                    [Logging startLog:sensor];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"show_mode_selection" sender:self];
                });
            }
        }
    }
}

#pragma mark - Bluetooth
- (void)detectBluetooth
{
    if(!bluetoothManager)
    {
        bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    }
    [self centralManagerDidUpdateState:bluetoothManager];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (bluetoothManager.state == CBManagerStatePoweredOff) {
        NSString *title = NSLocalizedString(@"BluetoothOffAlertTitle", @"");
        NSString *message = NSLocalizedString(@"BluetoothOffAlertMessage", @"");
        NSString *okay = NSLocalizedString(@"OK", @"");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:okay
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self detectLocationManager];
        }]];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[self topMostController] presentViewController:alert animated:YES completion:nil];
        });
    } else if (bluetoothManager.state != CBManagerStateUnknown) {
        [self detectLocationManager];
    }
}

#pragma mark - Location
- (void)detectLocationManager
{
    if (isLocationAlert) {
        isLocationAlert = NO;
        [self requestLocalNotificationPermission];
        return;
    }

    if(!locationManager)
    {
        locationManager = [[CLLocationManager alloc] init];
    }
    locationManager.delegate = self;
    [locationManager requestWhenInUseAuthorization];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusDenied) {
        NSString *title = NSLocalizedString(@"LocationNotAllowedTitle", @"");
        NSString *message = NSLocalizedString(@"LocationNotAllowedMessage", @"");
        NSString *setting = NSLocalizedString(@"SETTING", @"");
        NSString *cancel = NSLocalizedString(@"CANCEL", @"");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:setting
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                      NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                                                      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:cancel
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self requestLocalNotificationPermission];
        }]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[self topMostController] presentViewController:alert animated:YES completion:nil];
        });
        isLocationAlert = YES;
    } else if (status != kCLAuthorizationStatusNotDetermined) {
        [self requestLocalNotificationPermission];
    }
}

#pragma mark - Notification
- (void)requestLocalNotificationPermission {
    [[UNUserNotificationCenter currentNotificationCenter]
     requestAuthorizationWithOptions:(UNAuthorizationOptionAlert |
                                      UNAuthorizationOptionSound |
                                      UNAuthorizationOptionBadge )
     completionHandler:^(BOOL granted, NSError * _Nullable error) {
        NSLog(@"Authorization granted: %d", granted);
        if (error != nil) {
            NSLog(@"Error %@", [error description]);
        }
        [self checkConfig];
     }];
}

#pragma mark -
// 必要かどうか不明
- (UIViewController*) topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].windows.firstObject.rootViewController;

    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (IBAction)returnActionForSegue:(UIStoryboardSegue *)segue
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self checkConfig];
    });
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
