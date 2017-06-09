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
#import "NavWebviewHelper.h"
#import "ConfigManager.h"
#import "LocationEvent.h"
#import "AuthManager.h"
#import "ServerConfig+FingerPrint.h"
#import "NavUtil.h"
#import "NavDataStore.h"
#import "FingerprintManager.h"
#import "HLPFingerprint.h"
#import "BlindViewController.h"

@interface SettingViewController ()

@end

@implementation SettingViewController {
}

static HLPSettingHelper *userSettingHelper;
static HLPSettingHelper *refpointSettingHelper;
static HLPSetting *idLabel, *refpointLabel;
static HLPSetting *chooseConfig, *fingerprintLabel, *beaconUUID, *duration;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    
    HLPSettingHelper *helper;
    
    if ([self.restorationIdentifier isEqualToString:@"user_settings"] ||
        [self.restorationIdentifier isEqualToString:@"blind_settings"]
        ) {
        [SettingViewController setupUserSettings];
        helper = userSettingHelper;
    }
    
    if ([self.restorationIdentifier isEqualToString:@"choose_config"]) {
        [SettingViewController setupRefpointSettingHelper];
        helper = refpointSettingHelper;
    }

    if (helper) {
        helper.delegate = self;
        self.tableView.delegate = helper;
        self.tableView.dataSource = helper;
    }
    
    [self updateView];
}

- (void) configChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateView];
    });
}

- (void) updateView
{
    [self.tableView reloadData];
    
}

- (void)dealloc
{
    
}

- (void)actionPerformed:(HLPSetting *)setting
{
    if ([setting.name isEqualToString:@"choose_config"]) {
        [self performSegueWithIdentifier:setting.name sender:self];
    } else {
        HLPRefpoint *rp;
        for(rp in [FingerprintManager sharedManager].refpoints) {
            if ([rp._id[@"$oid"] isEqualToString:setting.name]) {
                break;
            }
        }
        if (rp) {
            [[FingerprintManager sharedManager] select:rp];
        }
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

+ (void)setup
{
    [SettingViewController setupUserSettings];
}

+ (void)setupUserSettings
{
    if (userSettingHelper) {
        idLabel.label = [NavDataStore sharedDataStore].userID;
        refpointLabel.label = [NSString stringWithFormat:@"Refpoint: %@", [FingerprintManager sharedManager].selectedRefpoint.floor];
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        ServerConfig *sc = [ServerConfig sharedConfig];
        NSArray *uuids = [ud arrayForKey:@"finger_printing_beacon_uuid_list"];
        NSString *uuid = [sc fingerPrintingBeaconUUID];
        if (uuid) {
            if ([uuids indexOfObject:uuid] == NSNotFound) {
                NSMutableArray *temp = [uuids mutableCopy];
                [temp addObject:uuid];
                [ud setObject:temp forKey:@"finger_printing_beacon_uuid_list"];
            }
            [ud setObject:uuid forKey:@"selected_finger_printing_beacon_uuid"];
        }
        
        return;
    }
    userSettingHelper = [[HLPSettingHelper alloc] init];

    refpointLabel = [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"Refpoint: %@", [FingerprintManager sharedManager].selectedRefpoint.floor]];
    chooseConfig = [userSettingHelper addActionTitle:@"Select Refpoint" Name:@"choose_config"];

    fingerprintLabel = [userSettingHelper addSectionTitle:@"Finger Printing"];
    beaconUUID = [userSettingHelper addSettingWithType:UUID_TYPE Label:@"Beacon UUID" Name:@"finger_printing_beacon_uuid" DefaultValue:@[] Accept:nil];
    duration = [userSettingHelper addSettingWithType:DOUBLE Label:@"Duration" Name:@"finger_printing_duration" DefaultValue:@(5) Min:1 Max:30 Interval:1];

    [[userSettingHelper addSettingWithType:BOOLEAN Label:@"Use HTTPS" Name:@"https_connection" DefaultValue:@(YES) Accept:nil] setVisible:NO];
    [[userSettingHelper addSettingWithType:TEXTINPUT Label:@"Context" Name:@"hokoukukan_server_context" DefaultValue:@"" Accept:nil] setVisible:NO];

    NSString *versionNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"version: %@ (%@)", versionNo, buildNo]];
    idLabel = [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"%@", [NavDataStore sharedDataStore].userID]];
    
}

+ (void)setupRefpointSettingHelper
{
    if (!refpointSettingHelper) {
        refpointSettingHelper = [[HLPSettingHelper alloc] init];
    }
    
    [refpointSettingHelper removeAllSetting];
    
    [refpointSettingHelper addSectionTitle:@"Refpoints"];
    
    NSArray *refpoints = [FingerprintManager sharedManager].refpoints;
    refpoints = [refpoints sortedArrayUsingComparator:^NSComparisonResult(HLPRefpoint*  _Nonnull obj1, HLPRefpoint*  _Nonnull obj2) {
        return [obj1.floor compare:obj2.floor];
    }];

    for(HLPRefpoint* rp in refpoints) {
        [refpointSettingHelper addActionTitle:rp._metadata[@"name"] Name:rp._id[@"$oid"]];
    }
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
    
    [segue destinationViewController].restorationIdentifier = segue.identifier;
    
//    if ([sender isKindOfClass:UITableViewCell.class]) {
//        [segue destinationViewController].restorationIdentifier = ((UITableViewCell*)sender).restorationIdentifier;
//    }
}


@end
