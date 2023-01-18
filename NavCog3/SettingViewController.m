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
#import "SettingViewController.h"
#import "NavNavigator.h"
#import "ConfigManager.h"
#import "LocationEvent.h"
#import "NavDebugHelper.h"
#import "NavDeviceTTS.h"
#import "NavDataStore.h"
#import "AuthManager.h"
#import "NavUtil.h"
#import "Logging.h"
#import "ScreenshotHelper.h"
#import <SSZipArchive.h>
#import "WebViewController.h"
#import "ServerConfig.h"

@import HLPDialog;

@interface SettingViewController ()

@end

@implementation SettingViewController {
}

static HLPSettingHelper *userSettingHelper;
static HLPSettingHelper *detailSettingHelper;
static HLPSettingHelper *blelocppSettingHelper;
static HLPSettingHelper *blindnaviSettingHelper;
static HLPSettingHelper *mapSettingHelper;
static HLPSettingHelper *configSettingHelper;
static HLPSettingHelper *logSettingHelper;
static HLPSettingHelper *routeOptionsSettingHelper;
static HLPSettingHelper *reportIssueSettingHelper;

static HLPSetting *speechLabel, *speechSpeedSetting, *vibrateSetting, *soundEffectSetting;
static HLPSetting *previewSpeedSetting, *previewWithActionSetting;
static HLPSetting *boneConductionSetting, *exerciseLabel, *exerciseAction, *resetLocation;
static HLPSetting *mapLabel, *initialZoomSetting, *unitLabel, *unitMeter, *unitFeet, *idLabel;
static HLPSetting *advancedLabel, *advancedMenu;
static HLPSetting *ignoreFacility, *showPOI;
static HLPSetting *userModeLabel, *userBlindLabel, *userWheelchairLabel, *userStrollerLabel, *userGeneralLabel;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    
    UILabel *titleView = [[UILabel alloc] init];
    titleView.text = NSLocalizedString(@"Settings", @"");
    titleView.accessibilityLabel = @"( )";
    titleView.isAccessibilityElement = NO;
    self.navigationItem.titleView = titleView;

    [self.backButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Back", @"BlindView", @"")];

    HLPSettingHelper *helper;
    
    if ([self.restorationIdentifier isEqualToString:@"developer_settings"] ||
        [self.restorationIdentifier isEqualToString:@"advanced_settings"]
        ) {
        helper = detailSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"user_settings"] ||
        [self.restorationIdentifier isEqualToString:@"blind_settings"]
        ) {
        [SettingViewController setupUserSettings];
        helper = userSettingHelper;
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:@"speech_speed"
                                                   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                                   context:nil];
    }
    if ([self.restorationIdentifier isEqualToString:@"adjust_blelocpp"]) {
        helper = blelocppSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"adjust_blind_navi"]) {
        helper = blindnaviSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"choose_map"]) {
        [SettingViewController setupMapSettingHelper];
        helper = mapSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"choose_config"]) {
        [SettingViewController setupConfigSettingHelper];
        helper = configSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"choose_log"]) {
        [SettingViewController setupLogSettingHelper];
        helper = logSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"route_options_setting"]) {
        helper = routeOptionsSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"report_issue"]) {
        [SettingViewController setupReportIssueSettingHelper];
        helper = reportIssueSettingHelper;
    }

    

    if (helper) {
        helper.delegate = self;
        self.tableView.delegate = helper;
        self.tableView.dataSource = helper;
    }
    [self updateView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configChanged:) name:DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];

    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) configChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateView];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"%@,%@,%@", keyPath, object, change);
    //[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:@"speech_speed"] && change[@"new"] && change[@"old"]) {
            if ([change[@"new"] doubleValue] != [change[@"old"] doubleValue]) {
                double value = [change[@"new"] doubleValue];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *string = NSLocalizedString(@"SPEECH_SPEED_CHECK", "");
                    [[NavDeviceTTS sharedTTS] speak:[NSString stringWithFormat:string, value]
                                        withOptions:@{@"force":@(YES)} completionHandler:nil];
                });
            }
        }
    }
}

- (void) updateView
{
    [self.tableView reloadData];
    
    BOOL dialog = [[DialogManager sharedManager] isAvailable];
    if (self.dialogSearchCell) {
        self.dialogSearchCell.selectionStyle = dialog?UITableViewCellSelectionStyleGray:UITableViewCellSelectionStyleNone;
        self.dialogSearchCell.textLabel.enabled = dialog;
    }
}

-(void)actionPerformed:(HLPSetting*)setting
{
    if ([setting.name isEqualToString:@"report_issue"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logging_to_file"] == NO) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Report Issue" message:@"\"Record log\" setting should be on for reporting issue." preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            }]];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Turn On",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:@"logging_to_file"];
                    [self updateView];
                });
            }]];
            [self presentViewController:alert animated:YES completion:nil];
            
            return;
        }
        if([MFMailComposeViewController canSendMail] == NO) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Need email setting"
                                                                           message:@"Please set up email account"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        [self performSegueWithIdentifier:setting.name sender:self];
    } else if ([setting.name hasPrefix:@"report_issue_"]) {
        NSString *log = [setting.name stringByReplacingOccurrencesOfString:@"report_issue_" withString:@""];
        [Logging stopLog];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Report Issue"
                                                                       message:@"Please describe issue"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        }];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                      NSString *desc = alert.textFields[0].text;
                                                      [self sendReportWithLog:log description:desc];
                                                  }]];
        
        [self presentViewController:alert animated:YES completion:nil];
        
    } else if ([setting.name isEqualToString:@"save_setting"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Save setting" message:@"Input setting name" preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            if([configSettingHelper.settings count] > 3) {
                textField.text = [[configSettingHelper.settings[3] name] stringByDeletingPathExtension];
            }
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *name = alert.textFields[0].text;
            if (name && [name length] > 0) {
                NSMutableDictionary *dic = [@{} mutableCopy];
                [userSettingHelper exportSetting:dic];
                [detailSettingHelper exportSetting:dic];
                [blelocppSettingHelper exportSetting:dic];
                [blindnaviSettingHelper exportSetting:dic];
                [mapSettingHelper exportSetting:dic];
                [routeOptionsSettingHelper exportSetting:dic];
                if (![ConfigManager saveConfig:dic withName:name Force:NO]) {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Overwrite?"
                                                                                   message:[NSString stringWithFormat:@"Are you sure to overwrite %@?", name]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    }]];
                    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                        [ConfigManager saveConfig:dic withName:name Force:YES];
                    }]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
                [SettingViewController setupConfigSettingHelper];
                [self.tableView reloadData];
            }
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([setting.name hasSuffix:@".plist"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Load setting"
                                                                       message:[NSString stringWithFormat:@"Are you sure to load %@?", setting.name]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel",@"HLPSettingView",@"cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [ConfigManager loadConfig:setting.name];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([setting.name hasSuffix:@".log"]) {
        NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString* path = [documentsPath stringByAppendingPathComponent:setting.name];
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY object:self userInfo:@{@"path":path}];
        
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if ([setting.name isEqualToString:@"launch_exercise"]) {
        [[NavDataStore sharedDataStore] startExercise];
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if ([setting.name isEqualToString:@"Reset_Location"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_UNKNOWN object:self];
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if ([setting.name isEqualToString:@"OpenHelp"]) {
        NSURL *url = [WebViewController hulopHelpPageURLwithType:@"help" languageDetection:YES];
        __weak typeof(self) weakself = self;
        [WebViewController checkHttpStatusWithURL:url completionHandler:^(NSURL * _Nonnull url, NSInteger statusCode) {
            __weak NSURL *weakurl = url;
            dispatch_async(dispatch_get_main_queue(), ^{
                WebViewController *vc = [WebViewController getInstance];
                if (statusCode == 200) {
                    vc.url = weakurl;
                } else {
                    vc.url = [WebViewController hulopHelpPageURLwithType:@"help" languageDetection:NO];
                }
                vc.title = NSLocalizedString(@"help", @"");
                [weakself.navigationController showViewController:vc sender:weakself];
            });
        }];
    } else if ([setting.name isEqualToString:@"OpenInstructions"]) {
        NSURL *url = [WebViewController hulopHelpPageURLwithType:@"instructions" languageDetection:YES];
        __weak typeof(self) weakself = self;
        [WebViewController checkHttpStatusWithURL:url completionHandler:^(NSURL * _Nonnull url, NSInteger statusCode) {
            __weak NSURL *weakurl = url;
            dispatch_async(dispatch_get_main_queue(), ^{
                WebViewController *vc = [WebViewController getInstance];
                if (statusCode == 200) {
                    vc.url = weakurl;
                } else {
                    vc.url = [WebViewController hulopHelpPageURLwithType:@"instructions" languageDetection:NO];
                }
                vc.title = NSLocalizedString(@"Instructions", @"");
                [weakself.navigationController showViewController:vc sender:weakself];
            });
        }];
    } else if ([setting.name hasPrefix:@"Open:"]) {
        ServerConfig *sc  = [ServerConfig sharedConfig];
        NSString *path = [setting.name substringFromIndex:@"Open:".length];
        NSURL *url = [sc.selected URLWithPath:path];
        __weak typeof(self) weakself = self;
        [WebViewController checkHttpStatusWithURL:url completionHandler:^(NSURL * _Nonnull url, NSInteger statusCode) {
            __weak NSURL *weakurl = url;
            dispatch_async(dispatch_get_main_queue(), ^{
                WebViewController *vc = [WebViewController getInstance];
                if (statusCode == 200) {
                    vc.url = weakurl;
                }
                vc.title = @"";
                [weakself.navigationController showViewController:vc sender:weakself];
            });
        }];
    } else if ([setting.name isEqualToString:@"back_to_mode_selection"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_UNLOAD_VIEW object:self];
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if ([setting.name isEqualToString:@"send_feedback"]) {
        NSString *subject = [NSString stringWithFormat:NSLocalizedString(@"feedbackSubject", @""), [NavDataStore sharedDataStore].userID];
        NSString *body = NSLocalizedString(@"feedbackBody", @"");
        [self composeEmailSubject:subject Body:body withAttachment:nil];
    } else {
        [self performSegueWithIdentifier:setting.name sender:self];
    }
}

- (void) sendReportWithLog:(NSString*)log description:(NSString*)description
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [documentsPath stringByAppendingPathComponent:[log stringByDeletingPathExtension]];
    [fm createDirectoryAtPath:dir withIntermediateDirectories:NO attributes:nil error:nil];

    NSString* plist = [[log stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
    NSString* cereal = [[log stringByDeletingPathExtension] stringByAppendingPathExtension:@"cereal"];
    NSString* zip = [[log stringByDeletingPathExtension] stringByAppendingPathExtension:@"zip"];
    NSString* mapName = [[NSUserDefaults standardUserDefaults] stringForKey:@"bleloc_map_data"];
    NSString* desc = [[log stringByDeletingPathExtension] stringByAppendingPathExtension:@"txt"];
    
    NSMutableDictionary *dic = [@{} mutableCopy];
    [userSettingHelper exportSetting:dic];
    [detailSettingHelper exportSetting:dic];
    [blelocppSettingHelper exportSetting:dic];
    [blindnaviSettingHelper exportSetting:dic];
    [mapSettingHelper exportSetting:dic];
    [routeOptionsSettingHelper exportSetting:dic];
    [ConfigManager saveConfig:dic withName:[log stringByDeletingPathExtension] Force:YES];

    NSString* lpath = [documentsPath stringByAppendingPathComponent:log];
    NSString* ppath = [documentsPath stringByAppendingPathComponent:plist];
    NSString* cpath = [documentsPath stringByAppendingPathComponent:cereal];
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_SERIALIZE object:self userInfo:@{@"filePath":cpath}];

    NSString* mpath = [documentsPath stringByAppendingPathComponent:mapName];
    NSString* dpath = [dir stringByAppendingPathComponent:desc];
    [description writeToFile:dpath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSArray* screenshots = [[ScreenshotHelper sharedHelper] screenshotsFromLog:lpath];
    NSArray* files = [screenshots arrayByAddingObjectsFromArray:@[lpath,ppath,mpath,cpath]];
    NSString* zpath = [documentsPath stringByAppendingPathComponent:zip];

    for(NSString *file in files) {
        NSError *error;
        NSString *dest = [dir stringByAppendingPathComponent:[file lastPathComponent]];
        [fm copyItemAtPath:file toPath:dest error:&error];
        if (error) {
            fprintf(stdout, "%s", error.description.UTF8String);
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil showModalWaitingWithMessage:@"creating zip file..."];
        dispatch_async(dispatch_get_main_queue(), ^{
            [SSZipArchive createZipFileAtPath:zpath withContentsOfDirectory:dir keepParentDirectory:YES withPassword:nil andProgressHandler:^(NSUInteger entryNumber, NSUInteger total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NavUtil showModalWaitingWithMessage:[NSString stringWithFormat:@"creating zip file... %ld%%",entryNumber*100/total]];
                    fprintf(stdout, "%ld/%ld\n", entryNumber, total);
                    if (entryNumber == total) {
                        [NavUtil hideModalWaiting];
                        [fm removeItemAtPath:dir error:nil];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSString* subject = [NSString stringWithFormat:@"Report Issue (%@)", [[zpath lastPathComponent] stringByDeletingPathExtension]];
                            [self composeEmailSubject:subject Body:description withAttachment:zpath];
                        });
                    }
                });
            }];
        });
    });
}

- (void)composeEmailSubject:(NSString*)subject Body:(NSString*)body withAttachment:(NSString*)path
{
    if([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailCont = [[MFMailComposeViewController alloc] init];
        mailCont.mailComposeDelegate = self;
        
        [mailCont setSubject:subject];
        [mailCont setToRecipients:[NSArray arrayWithObject:@"hulop.contact@gmail.com"]];
        [mailCont setMessageBody:body isHTML:NO];
        if (path) {
            [mailCont addAttachmentData:[NSData dataWithContentsOfFile:path] mimeType:@"application/zip" fileName:[path lastPathComponent]];
        }
        
        [self presentViewController:mailCont animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Need email setting"
                                                                       message:@"Please set up email account"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK",@"HLPSettingView",@"ok") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];            
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"logging_to_file"]) {
        BOOL sensor = [[NSUserDefaults standardUserDefaults] boolForKey:@"logging_sensor"];
        [Logging startLog:sensor];
    }
}


- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(NSDictionary *)info
{
    return YES;
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc
{
    @try {
        [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"speech_speed"];
    } @catch(NSException *e) {
    }
}

+ (void)setup
{
    [SettingViewController setupUserSettings];
    [SettingViewController setupDeveloperSettings];
    [SettingViewController setupBlelocppSettings];
    [SettingViewController setupBlindNaviSettings];
    [SettingViewController setupRouteOptionsSettings];
}

+ (void)setupUserSettings
{
    userSettingHelper = [[HLPSettingHelper alloc] init];

//    [userSettingHelper addSectionTitle:NSLocalizedString(@"Help", @"")];
//    [userSettingHelper addActionTitle:NSLocalizedString(@"OpenInstructions", @"") Name:@"OpenInstructions"];
//    [userSettingHelper addActionTitle:NSLocalizedString(@"OpenHelp", @"") Name:@"OpenHelp"];
//    [userSettingHelper addActionTitle:NSLocalizedString(@"Send Feedback", @"") Name:@"send_feedback"];
    
//    [userSettingHelper addSectionTitle:NSLocalizedString(@"Mode", @"")];
//    [userSettingHelper addActionTitle:NSLocalizedString(@"Back to mode selection", @"") Name:@"back_to_mode_selection"];
    
    speechLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Speech_Sound", @"label for tts options")];
    speechSpeedSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:NSLocalizedString(@"Speech speed", @"label for speech speed option")
                                     Name:@"speech_speed" DefaultValue:@(0.55) Min:0.1 Max:1 Interval:0.05];
    previewSpeedSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:NSLocalizedString(@"Preview speed", @"") Name:@"preview_speed" DefaultValue:@(1) Min:1 Max:10 Interval:1];
    previewWithActionSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Preview with action", @"") Name:@"preview_with_action" DefaultValue:@(NO) Accept:nil];
    ignoreFacility = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Ignore facility info.", @"") Name:@"ignore_facility" DefaultValue:@(NO) Accept:nil];
    showPOI = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Show POI with Action", @"") Name:@"show_poi_with_action" DefaultValue:@(NO) Accept:nil];
    vibrateSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"vibrateSetting", @"") Name:@"vibrate" DefaultValue:@(YES) Accept:nil];
    soundEffectSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"soundEffectSetting", @"") Name:@"sound_effect" DefaultValue:@(YES) Accept:nil];
    boneConductionSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"for_bone_conduction_headset",@"") Name:@"for_bone_conduction_headset" DefaultValue:@(NO) Accept:nil];

    unitLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Distance unit", @"label for distance unit option")];
    unitMeter = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"Meter", @"meter distance unit label")
                                                 Name:@"unit_meter" Group:@"distance_unit" DefaultValue:@(YES) Accept:nil];
    unitFeet = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"Feet", @"feet distance unit label")
                                                Name:@"unit_feet" Group:@"distance_unit" DefaultValue:@(NO) Accept:nil];
    
//    exerciseLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Exercise", @"label for exercise options")];
//    exerciseAction = [userSettingHelper addActionTitle:NSLocalizedString(@"Launch Exercise", @"") Name:@"launch_exercise"];
    
    mapLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Map", @"label for map")];
    mapLabel.visible = NO;
    initialZoomSetting = [userSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:NSLocalizedString(@"Initial zoom level for navigation", @"") Name:@"zoom_for_navigation" DefaultValue:@(20) Min:15 Max:22 Interval:1];
    initialZoomSetting.visible = NO;
    
    resetLocation = [userSettingHelper addActionTitle:NSLocalizedString(@"Reset_Location", @"") Name:@"Reset_Location"];
    
    userModeLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Mode", @"label for user mode")];
    userBlindLabel = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"user_blind", @"user blind label")
                                                 Name:@"user_blind" Group:@"user_mode" DefaultValue:@(NO) Accept:nil];
    userWheelchairLabel = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"user_wheelchair", @"user wheelchair label")
                                                Name:@"user_wheelchair" Group:@"user_mode" DefaultValue:@(NO) Accept:nil];
    userStrollerLabel = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"user_stroller", @"user stroller label")
                                                Name:@"user_stroller" Group:@"user_mode" DefaultValue:@(NO) Accept:nil];
    userGeneralLabel = [userSettingHelper addSettingWithType:NavCogSettingTypeOption Label:NSLocalizedString(@"user_general", @"user general label")
                                                Name:@"user_general" Group:@"user_mode" DefaultValue:@(NO) Accept:nil];

    NavDataStore *nds = [NavDataStore sharedDataStore];
    [[ServerConfig sharedConfig].extraMenuList enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj[@"section_title"] && obj[@"menus"]) {
            I18nStrings* section_title = [[I18nStrings alloc] initWithDictionary:obj[@"section_title"]];
            
            [userSettingHelper addSectionTitle:[section_title stringByLanguage:nds.userLanguage]];
            [obj[@"menus"] enumerateObjectsUsingBlock:^(NSDictionary* obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj[@"title"] && obj[@"content"]) {
                    I18nStrings* title = [[I18nStrings alloc] initWithDictionary:obj[@"title"]];
                    I18nStrings* content = [[I18nStrings alloc] initWithDictionary:obj[@"content"]];
                    
                    [userSettingHelper addActionTitle:[title stringByLanguage:nds.userLanguage]
                                                 Name:[NSString stringWithFormat:@"Open:%@", [content stringByLanguage:nds.userLanguage]]];
                }
            }];
        }
    }];

    NSString *versionNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"version: %@ (%@)", versionNo, buildNo]];
    idLabel = [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"%@", [NavDataStore sharedDataStore].userID]];
    
    advancedLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Advanced", @"")];
    advancedMenu = [userSettingHelper addActionTitle:NSLocalizedString(@"Advanced Setting", @"") Name:@"advanced_settings"];
    
    if (userSettingHelper) {
        BOOL blindMode = [[[NSUserDefaults standardUserDefaults] stringForKey:@"user_mode"] isEqualToString:@"user_blind"];
        BOOL isPreviewDisabled = [[ServerConfig sharedConfig] isPreviewDisabled];
        //[speechLabel setVisible:blindMode];
        //[speechSpeedSetting setVisible:blindMode];
        
        [previewSpeedSetting setVisible:blindMode && (!isPreviewDisabled)];
        [previewWithActionSetting setVisible:blindMode && (!isPreviewDisabled)];
        [ignoreFacility setVisible:blindMode];
        [showPOI setVisible:blindMode];
        [vibrateSetting setVisible:blindMode];
        [soundEffectSetting setVisible:blindMode];
        [boneConductionSetting setVisible:blindMode];
        
        [unitLabel setVisible:blindMode];
        [unitMeter setVisible:blindMode];
        [unitFeet setVisible:blindMode];
        
        [exerciseLabel setVisible:blindMode];
        [exerciseAction setVisible:blindMode];
        //[mapLabel setVisible:blindMode];
        //[initialZoomSetting setVisible:blindMode];
        [resetLocation setVisible:!blindMode];
        
        idLabel.label = [NavDataStore sharedDataStore].userID;
        BOOL isDeveloperAuthorized = [[AuthManager sharedManager] isDeveloperAuthorized];
        [idLabel setVisible:isDeveloperAuthorized];
        [advancedLabel setVisible:isDeveloperAuthorized];
        [advancedMenu setVisible:isDeveloperAuthorized];

        [userModeLabel setVisible:blindMode];
        [userBlindLabel setVisible:blindMode];
        [userWheelchairLabel setVisible:blindMode];
        [userStrollerLabel setVisible:blindMode];
        [userGeneralLabel setVisible:blindMode];

        return;
    }
}

+ (void)setupDeveloperSettings
{
    if (detailSettingHelper) {
        return;
    }

    // detail settings will not be localized
    
    detailSettingHelper = [[HLPSettingHelper alloc] init];
    
    [detailSettingHelper addSectionTitle:@"Report Issue"];
    [detailSettingHelper addActionTitle:@"Report Issue" Name:@"report_issue"];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Record logs" Name:@"logging_to_file" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Record screenshots" Name:@"record_screenshots" DefaultValue:@(NO) Accept:nil];
    
    [detailSettingHelper addSectionTitle:@"Background"];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Background Mode" Name:@"background_mode" DefaultValue:@(NO) Accept:nil];
    
    [detailSettingHelper addSectionTitle:@"Setting Preset"];
    [detailSettingHelper addActionTitle:@"Setting Preset" Name:@"choose_config"];
    
    [detailSettingHelper addSectionTitle:@"Data"];
    [detailSettingHelper addActionTitle:@"Choose map" Name:@"choose_map"];
    [detailSettingHelper addActionTitle:@"Log replay" Name:@"choose_log"];
    
    
    [detailSettingHelper addSectionTitle:@"Developer mode"];
    
    [detailSettingHelper addSectionTitle:@"Detail Settings"];
    [detailSettingHelper addActionTitle:@"Adjust blelocpp" Name:@"adjust_blelocpp"];
    [detailSettingHelper addActionTitle:@"Adjust blind navi" Name:@"adjust_blind_navi"];

    [detailSettingHelper addSectionTitle:@"Navigation server"];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Cache clear for next launch" Name:@"cache_clear" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use HTTPS" Name:@"https_connection" DefaultValue:@(YES) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeHostPort Label:@"Server" Name:@"hokoukukan_server" DefaultValue:@[@""] Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeSubtitle Label:@"Server" Name:@"selected_hokoukukan_server" DefaultValue:@"" Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeTextInput Label:@"Context" Name:@"hokoukukan_server_context" DefaultValue:@"" Accept:nil];

    [detailSettingHelper addSectionTitle:@"For Demo"];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use compass" Name:@"use_compass" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Reset as start location" Name:@"reset_as_start_point" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Reset as start heading" Name:@"reset_as_start_heading" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Reset std dev" Name:@"reset_std_dev" DefaultValue:@(1.0) Min:0 Max:3 Interval:0.5];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Reset at elevator" Name:@"reset_at_elevator" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Reset at elevator continuously" Name:@"reset_at_elevator_continuously" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Stabilize localize on elevator" Name:@"stabilize_localize_on_elevator" DefaultValue:@(NO) Accept:nil];
    
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Hide \"Current Location\"" Name:@"hide_current_location_from_start" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Hide \"Facility\"" Name:@"hide_facility_from_to" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Accuracy for demo" Name:@"accuracy_for_demo" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Bearing for demo" Name:@"bearing_for_demo" DefaultValue:@(NO) Accept:nil];
    
    [detailSettingHelper addSectionTitle:@"Test"];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Send beacon data" Name:@"send_beacon_data" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:NavCogSettingTypeTextInput Label:@"Server" Name:@"beacon_data_server" DefaultValue:@"192.168.1.1:8080" Accept:nil];
}

+ (void)setupBlelocppSettings
{
    if (blelocppSettingHelper) {
        return;
    }
    
    blelocppSettingHelper = [[HLPSettingHelper alloc] init];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp mode"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"No tracking (oneshot)" Name:@"oneshot" Group:@"location_tracking" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"Tracking (PDR)" Name:@"tracking" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"Tracking (Random walk)" Name:@"randomwalker" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"Tracking (Weak Pose Random Walker)" Name:@"weak_pose_random_walker" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp representative location definition"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"mean" Name:@"mean" Group:@"rep_location" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"densest" Name:@"densest" Group:@"rep_location" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeOption Label:@"closest to mean" Name:@"closest_mean" Group:@"rep_location" DefaultValue:@(NO) Accept:nil];

    
    [blelocppSettingHelper addSectionTitle:@"blelocpp params"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Record sensor" Name:@"logging_sensor" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Webview update min interval" Name:@"webview_update_min_interval" DefaultValue:@(0.5) Min:0 Max:3.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Show states" Name:@"show_states" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use blelocpp accuracy" Name:@"use_blelocpp_acc" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"blelocpp accuracy sigma" Name:@"blelocpp_accuracy_sigma" DefaultValue:@(3) Min:1 Max:6 Interval:1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"nSmooth" Name:@"nSmooth" DefaultValue:@(3) Min:1 Max:10 Interval:1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"nSmoothTracking" Name:@"nSmoothTracking" DefaultValue:@(1) Min:1 Max:10 Interval:1];

    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"nStates" Name:@"nStates" DefaultValue:@(500) Min:100 Max:2000 Interval:100];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"nEffective (recommended gt or eq nStates/2)" Name:@"nEffective" DefaultValue:@(250) Min:50 Max:2000 Interval:50];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"alphaWeaken" Name:@"alphaWeaken" DefaultValue:@(0.3)  Min:0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"RSSI bias (old)" Name:@"rssi_bias" DefaultValue:@(0)  Min:-10 Max:10 Interval:0.5];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use RSSI bias for models" Name:@"rssi_bias_model_used" DefaultValue:@(YES) Accept:nil];
    NSString *deviceModel = [NavUtil deviceModel];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble
                                        Label:[NSString stringWithFormat:@"RSSI bias (%@)", deviceModel]
                                         Name:[@"rssi_bias_m_" stringByAppendingString:deviceModel]
                                 DefaultValue:@(0)  Min:-10 Max:10 Interval:0.5];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Stdev coefficient for different floor" Name:@"coeffDiffFloorStdev" DefaultValue:@(5)  Min:1 Max:10000 Interval:1];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use wheelchair PDR threthold" Name:@"wheelchair_pdr" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Mix probability from likelihood" Name:@"mixProba" DefaultValue:@(0) Min:0 Max:0.01 Interval:0.001];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Mix reject distance [m]" Name:@"rejectDistance" DefaultValue:@(5) Min:0 Max:30 Interval:1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Mix reject floor difference" Name:@"rejectFloorDifference" DefaultValue:@(0.95) Min:0 Max:1 Interval:0.05];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Mix minimum number of beacons" Name:@"nBeaconsMinimum" DefaultValue:@(3) Min:0 Max:10 Interval:1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Orientation bias diffusion" Name:@"diffusionOrientationBias" DefaultValue:@(10) Min:0 Max:90 Interval:1];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Initial walking speed" Name:@"meanVelocity" DefaultValue:@(1.0) Min:0.25 Max:1.5 Interval:0.05];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Half life of hitting wall" Name:@"weightDecayHalfLife" DefaultValue:@(5) Min:1 Max:10 Interval:1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Resampling lower bound 2D [m]" Name:@"locLB" DefaultValue:@(0.5) Min:0 Max:2 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Resampling lower bound floor [floor]" Name:@"floorLB" DefaultValue:@(0.1) Min:0.0 Max:1 Interval:0.1];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Confidence of heading for initialization" Name:@"headingConfidenceInit" DefaultValue:@(0.0) Min:0.0 Max:1.0 Interval:0.05];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Orientation accuracy threshold for reliable orientation [degree]" Name:@"oriAccThreshold" DefaultValue:@(22.5) Min:0.0 Max:120 Interval:2.5];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Initial location search radius in 2D [m]" Name:@"initialSearchRadius2D" DefaultValue:@(10) Min:5 Max:50 Interval:1];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Apply yaw drift smoothing" Name:@"applyYawDriftSmoothing" DefaultValue:@(NO) Accept:nil] setVisible: YES];

    
    // Parameters for status monitoring
    [blelocppSettingHelper addSectionTitle:@"blelocpp params (location status monitoring)"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Activate location status monitoring" Name:@"activatesStatusMonitoring" DefaultValue:@(YES) Accept:nil];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Location status monitoring interval [ms]" Name:@"statusMonitoringIntervalMS" DefaultValue:@(0) Min:0 Max:10000 Interval:1000] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Enter locating radius [m]" Name:@"enterLocating" DefaultValue:@(3.5) Min:0 Max:20 Interval:0.5] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Exit locating radius [m]" Name:@"exitLocating" DefaultValue:@(5.0) Min:0 Max:20 Interval:0.5] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Enter stable radius [m]" Name:@"enterStable" DefaultValue:@(3.5) Min:0 Max:20 Interval:0.5] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Exit stable radius [m]" Name:@"exitStable" DefaultValue:@(5.0) Min:0 Max:20 Interval:0.5] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Exponent n of minimum weight stable (w=10^n)" Name:@"exponentMinWeightStable" DefaultValue:@(-4) Min:-9 Max:-1 Interval:1] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Min unstable loop" Name:@"minUnstableLoop" DefaultValue:@(5) Min:1 Max:10 Interval:1] setVisible:YES];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp params (floor transition)"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use altimeter for floor trans support" Name:@"use_altimeter" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Mix probability for floor trans area" Name:@"mixtureProbabilityFloorTransArea" DefaultValue:@(0.25) Min:0.0 Max:1.0 Interval:0.05];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Weight multiplier for floor trans area" Name:@"weightFloorTransArea" DefaultValue:@(4) Min:1 Max:5 Interval:0.1] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Reject distance for floor trans area" Name:@"rejectDistanceFloorTrans" DefaultValue:@(10) Min:0.0 Max:25.0 Interval:1] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Duration allowing force floor update" Name:@"durationAllowForceFloorUpdate" DefaultValue:@(1) Min:1 Max:20 Interval:1] setVisible:YES];
    
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Window for altimeter manager" Name:@"windowAltitudeManager" DefaultValue:@(3) Min:1 Max:10 Interval:1] setVisible:YES];
    [[blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Stdev threshold for altimeter manager" Name:@"stdThresholdAltitudeManager" DefaultValue:@(0.15) Min:0.0 Max:2.0 Interval:0.05] setVisible:YES];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp params (prediction)"];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Sigma stop for random walker" Name:@"sigmaStopRW" DefaultValue:@(0.2) Min:0.0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Sigma move for random walker" Name:@"sigmaMoveRW" DefaultValue:@(1.0) Min:0.0 Max:3.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Pose random walk rate for WPRW" Name:@"poseRandomWalkRate" DefaultValue:@(1.0) Min:0.0 Max:2.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Random walk rate for WPRW" Name:@"randomWalkRate" DefaultValue:@(0.2) Min:0.0 Max:2.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Probability orientation offset jump for WPRW" Name:@"probaOriBiasJump" DefaultValue:@(0.0) Min:0.0 Max:0.5 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"relativeVelocityEscalator" Name:@"relativeVelocityEscalator" DefaultValue:@(0.5) Min:0.1 Max:1.0 Interval:0.1];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Probability backward move for WPRW" Name:@"probaBackwardMove" DefaultValue:@(0.0) Min:0.0 Max:0.5 Interval:0.1];
    
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Stdev velocity" Name:@"stdVelocity" DefaultValue:@(0.3) Min:0.0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Diffusion velocity" Name:@"diffusionVelocity" DefaultValue:@(0.1) Min:0.0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Minimum velocity" Name:@"minVelocity" DefaultValue:@(0.1) Min:0.0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:NavCogSettingTypeDouble Label:@"Maximum velocity" Name:@"maxVelocity" DefaultValue:@(1.5) Min:0.0 Max:3.0 Interval:0.1];    
}


+ (void)setupBlindNaviSettings
{
    if (blindnaviSettingHelper) {
        return;
    }
    
    blindnaviSettingHelper = [[HLPSettingHelper alloc] init];

    [blindnaviSettingHelper addSectionTitle:@"Blind Navigation Constants"];
    NSDictionary *defaults = [NavNavigatorConstants defaults];
    NSArray *names = [NavNavigatorConstants propertyNames];
    for(NSString *name in names) {
        NSArray *val = defaults[name];
        [blindnaviSettingHelper addSettingWithType:NavCogSettingTypeDouble
                                          Label:[NSString stringWithFormat:@"%@(%@)", name, val[0]]
                                           Name:name
                                   DefaultValue:val[0]
                                            Min:[val[1] doubleValue]
                                            Max:[val[2] doubleValue]
                                       Interval:[val[3] doubleValue]];
    }
    
}

+ (void)setupMapSettingHelper
{
    if (!mapSettingHelper) {
        mapSettingHelper = [[HLPSettingHelper alloc] init];
    }
    
    [mapSettingHelper removeAllSetting];
    
    [mapSettingHelper addSectionTitle:@"2D localization data"];

    for(NSString *map in [ConfigManager filenamesWithSuffix:@"json"]) {
        [mapSettingHelper addSettingWithType:NavCogSettingTypeOption Label:[map stringByDeletingPathExtension] Name:map Group:@"bleloc_map_data" DefaultValue:@(NO) Accept:nil];
    }

}

+ (void)setupConfigSettingHelper
{
    if (!configSettingHelper) {
        configSettingHelper = [[HLPSettingHelper alloc] init];
    }

    [configSettingHelper removeAllSetting];
    
    [configSettingHelper addSectionTitle:@"Settings"];
    [configSettingHelper addActionTitle:@"Save Setting" Name:@"save_setting"];
    
    [configSettingHelper addSectionTitle:@"Choose Setting"];
    for(NSString *plist in [ConfigManager filenamesWithSuffix:@"plist"]) {
        [configSettingHelper addActionTitle:[plist stringByDeletingPathExtension] Name:plist];
    }
}
+ (void)setupLogSettingHelper
{
    if (!logSettingHelper) {
        logSettingHelper = [[HLPSettingHelper alloc] init];
    }
    
    [logSettingHelper removeAllSetting];
    
    [logSettingHelper addSectionTitle:@"Log Replay"];
    [logSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Replay in realtime" Name:@"replay_in_realtime" DefaultValue:@(NO) Accept:nil];
    [logSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use sensor log" Name:@"replay_sensor" DefaultValue:@(NO) Accept:nil];
    [logSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Show sensor log" Name:@"replay_show_sensor_log" DefaultValue:@(NO) Accept:nil];
    [logSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use reset in sensor log" Name:@"replay_with_reset" DefaultValue:@(YES) Accept:nil];
    [logSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:@"Use navigation log" Name:@"replay_navigation" DefaultValue:@(YES) Accept:nil];
    
    [logSettingHelper addSectionTitle:@"Choose Log"];
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray *logs = [ConfigManager filenamesWithSuffix:@"log"];
    logs = [logs sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj2 compare:obj1 options:0];
    }];
    for(NSString *log in logs) {
        NSString* path = [documentsPath stringByAppendingPathComponent:log];

        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
        
        [logSettingHelper addActionTitle:[NSString stringWithFormat:@"%@ %.1fMB", [log stringByDeletingPathExtension], fileSize/1024.0/1024.0] Name:log];
    }

}

+ (void)setupRouteOptionsSettings
{
    if (routeOptionsSettingHelper) {
        return;
    }
    routeOptionsSettingHelper = [[HLPSettingHelper alloc] init];
    
    
    [routeOptionsSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Prefer Tactile Paving", @"")
                                             Name:@"route_tactile_paving" DefaultValue:@(YES) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Use Elevator", @"")
                                             Name:@"route_use_elevator" DefaultValue:@(YES) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Use Escalator", @"")
                                             Name:@"route_use_escalator" DefaultValue:@(NO) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Use Moving Walkway", @"")
                                             Name:@"route_use_moving_walkway" DefaultValue:@(NO) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:NavCogSettingTypeBoolean Label:NSLocalizedString(@"Use Stairs", @"")
                                             Name:@"route_use_stairs" DefaultValue:@(NO) Accept:nil];
}

+ (void)setupReportIssueSettingHelper {
    if (!reportIssueSettingHelper) {
        reportIssueSettingHelper = [[HLPSettingHelper alloc] init];
    }
    
    [reportIssueSettingHelper removeAllSetting];
    
    [reportIssueSettingHelper addSectionTitle:@"Choose Log"];
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString* documentsPath = [dirs objectAtIndex:0];
    NSArray *logs = [ConfigManager filenamesWithSuffix:@"log"];
    logs = [logs sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
        return [obj2 compare:obj1 options:0];
    }];
    int count = 0;
    for(NSString *log in logs) {
        NSString* path = [documentsPath stringByAppendingPathComponent:log];
        
        unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
        
        NSString *label = [NSString stringWithFormat:@"%@ %.1fMB", [log stringByDeletingPathExtension], fileSize/1024.0/1024.0];
        NSString *name = [NSString stringWithFormat:@"report_issue_%@", log];
        [reportIssueSettingHelper addActionTitle:label Name:name];
        count++;
        if (count >= 10) {
            //break;
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions
- (IBAction)doBack:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *id = [[tableView cellForRowAtIndexPath:indexPath] reuseIdentifier];
    if ([id isEqualToString:@"search_option"]) {
        [self.webView triggerWebviewControl:HLPWebviewControlRouteSearchOptionButton];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"search_route"]) {
        [self.webView triggerWebviewControl:HLPWebviewControlRouteSearchButton];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"end_navigation"]) {
        [self.webView triggerWebviewControl:HLPWebviewControlEndNavigation];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (BOOL)tableView:(UITableView *)tableView canFocusRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *id = [[tableView cellForRowAtIndexPath:indexPath] reuseIdentifier];
    if ([id isEqualToString:@"dialog_search"]) {
        return [[DialogManager sharedManager] isAvailable];
    }
    return YES;
}

- (BOOL) isBlindMode
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return [[ud stringForKey:@"user_mode"] isEqualToString:@"user_blind"];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && [self isBlindMode]) {
        cell.hidden = YES;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && [self isBlindMode]) {
        return 0;
    } else {
        return [super tableView:tableView heightForRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0 && [self isBlindMode]) {
        return 0;
    } else {
        return [super tableView:tableView heightForHeaderInSection:section];
    }
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_dialog_wc"]) {
        return [[DialogManager sharedManager] isAvailable];
    }
    return YES;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    
    [segue destinationViewController].restorationIdentifier = segue.identifier;
    
//    if ([sender isKindOfClass:UITableViewCell.class]) {
//        [segue destinationViewController].restorationIdentifier = ((UITableViewCell*)sender).restorationIdentifier;
//    }
}


@end
