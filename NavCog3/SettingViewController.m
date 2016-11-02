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
#import "NavNavigator.h"
#import "ConfigManager.h"
#import "LocationEvent.h"

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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    
    HLPSettingHelper *helper;
    
    if ([self.restorationIdentifier isEqualToString:@"developer_settings"] ||
        [self.restorationIdentifier isEqualToString:@"advanced_settings"]
        ) {
        helper = detailSettingHelper;
    }
    if ([self.restorationIdentifier isEqualToString:@"user_settings"] ||
        [self.restorationIdentifier isEqualToString:@"blind_settings"]
        ) {
        helper = userSettingHelper;
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

    

    if (helper) {
        helper.delegate = self;
        self.tableView.delegate = helper;
        self.tableView.dataSource = helper;
        [self.tableView reloadData];
    }
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

-(void)actionPerformed:(HLPSetting*)setting
{
    if ([setting.name isEqualToString:@"save_setting"]) {
        
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
                //[userSettingHelper exportSetting:dic];
                [detailSettingHelper exportSetting:dic];
                [blelocppSettingHelper exportSetting:dic];
                [blindnaviSettingHelper exportSetting:dic];
                [mapSettingHelper exportSetting:dic];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY object:path];
        
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else {
        [self performSegueWithIdentifier:setting.name sender:self];
    }
}

- (void)dealloc
{
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
    if (userSettingHelper) {
        return;
    }
    userSettingHelper = [[HLPSettingHelper alloc] init];
    
    [userSettingHelper addSectionTitle:NSLocalizedString(@"Speech", @"label for tts options")];
    [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Speech speed", @"label for speech speed option")
                                     Name:@"speech_speed" DefaultValue:@(0.6) Min:0 Max:1 Interval:0.05];
    [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Preview speed", @"") Name:@"preview_speed" DefaultValue:@(1) Min:1 Max:10 Interval:1];
    [userSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Preview with action", @"") Name:@"preview_with_action" DefaultValue:@(NO) Accept:nil];
    
    [userSettingHelper addSectionTitle:NSLocalizedString(@"Map", @"label for map")];
    [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Initial zoom level for navigation", @"") Name:@"zoom_for_navigation" DefaultValue:@(17) Min:15 Max:22 Interval:1];
    

    [userSettingHelper addSectionTitle:NSLocalizedString(@"Distance unit", @"label for distance unit option")];
    [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Meter", @"meter distance unit label")
                                     Name:@"unit_meter" Group:@"distance_unit" DefaultValue:@(YES) Accept:nil];
    [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Feet", @"feet distance unit label")
                                     Name:@"unit_feet" Group:@"distance_unit" DefaultValue:@(NO) Accept:nil];
    
    [userSettingHelper addSectionTitle:NSLocalizedString(@"Advanced", @"")];
    [userSettingHelper addActionTitle:NSLocalizedString(@"Advanced Setting", @"") Name:@"advanced_settings"];
    
}

+ (void)setupDeveloperSettings
{
    if (detailSettingHelper) {
        return;
    }

    // detail settings will not be localized
    
    detailSettingHelper = [[HLPSettingHelper alloc] init];
    
    [detailSettingHelper addSectionTitle:@"Setting Preset"];
    [detailSettingHelper addActionTitle:@"Setting Preset" Name:@"choose_config"];
    
    [detailSettingHelper addSectionTitle:@"Data"];
    [detailSettingHelper addActionTitle:@"Choose map" Name:@"choose_map"];
    [detailSettingHelper addActionTitle:@"Log replay" Name:@"choose_log"];
    
    
    [detailSettingHelper addSectionTitle:@"Developer mode"];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Developer mode" Name:@"developer_mode" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Preview speed", @"") Name:@"preview_speed" DefaultValue:@(1) Min:1 Max:100 Interval:1];

    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Record logs" Name:@"logging_to_file" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Cache clear for next launch" Name:@"cache_clear" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addActionTitle:@"Adjust blelocpp" Name:@"adjust_blelocpp"];
    [detailSettingHelper addActionTitle:@"Adjust blind navi" Name:@"adjust_blind_navi"];

    [detailSettingHelper addSectionTitle:@"Navigation server"];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Use HTTPS" Name:@"https_connection" DefaultValue:@(YES) Accept:nil];
    [detailSettingHelper addSettingWithType:HOST_PORT Label:@"Server" Name:@"hokoukukan_server" DefaultValue:@[@"hokoukukan.mybluemix.net"] Accept:nil];
    [detailSettingHelper addSettingWithType:TEXTINPUT Label:@"Context" Name:@"hokoukukan_server_context" DefaultValue:@"" Accept:nil];

    [detailSettingHelper addSectionTitle:NSLocalizedString(@"UI_Mode", @"")];
    [detailSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"UI_WHEELCHAIR", @"") Name:@"UI_WHEELCHAIR" Group:@"ui_mode" DefaultValue:@(YES) Accept:nil];
    [detailSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"UI_BLIND", @"") Name:@"UI_BLIND" Group:@"ui_mode" DefaultValue:@(NO) Accept:nil];

    [detailSettingHelper addSectionTitle:@"For WoW"];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Reset bleloc at start" Name:@"reset_as_start_point" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Hide \"Current Location\"" Name:@"hide_current_location_from_start" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Hide \"Facility\"" Name:@"hide_facility_from_to" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Accuracy for wow" Name:@"accuracy_for_wow" DefaultValue:@(NO) Accept:nil];
    
    [detailSettingHelper addSectionTitle:@"Test"];
    [detailSettingHelper addSettingWithType:BOOLEAN Label:@"Send beacon data" Name:@"send_beacon_data" DefaultValue:@(NO) Accept:nil];
    [detailSettingHelper addSettingWithType:TEXTINPUT Label:@"Server" Name:@"beacon_data_server" DefaultValue:@"192.168.1.1:8080" Accept:nil];
}

+ (void)setupBlelocppSettings
{
    if (blelocppSettingHelper) {
        return;
    }
    
    blelocppSettingHelper = [[HLPSettingHelper alloc] init];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp mode"];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"No tracking (oneshot)" Name:@"oneshot" Group:@"location_tracking" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"Tracking (PDR)" Name:@"tracking" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"Tracking (Random walk)" Name:@"randomwalker" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"Tracking (Weak Pose Random Walker)" Name:@"weak_pose_random_walker" Group:@"location_tracking" DefaultValue:@(NO) Accept:nil];
    
    [blelocppSettingHelper addSectionTitle:@"blelocpp representative location definition"];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"mean" Name:@"mean" Group:@"rep_location" DefaultValue:@(YES) Accept:nil];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"densest" Name:@"densest" Group:@"rep_location" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:OPTION Label:@"closest to mean" Name:@"closest_mean" Group:@"rep_location" DefaultValue:@(NO) Accept:nil];

    
    [blelocppSettingHelper addSectionTitle:@"blelocpp params"];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Webview update min interval" Name:@"webview_update_min_interval" DefaultValue:@(0.5) Min:0 Max:3.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:BOOLEAN Label:@"Show states" Name:@"show_states" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:BOOLEAN Label:@"Use blelocpp accuracy" Name:@"use_blelocpp_acc" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"blelocpp accuracy sigma" Name:@"blelocpp_accuracy_sigma" DefaultValue:@(3) Min:1 Max:6 Interval:1];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"nSmooth" Name:@"nSmooth" DefaultValue:@(2) Min:1 Max:10 Interval:1];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"nSmoothTracking" Name:@"nSmoothTracking" DefaultValue:@(3) Min:1 Max:10 Interval:1];

    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"nStates" Name:@"nStates" DefaultValue:@(500) Min:100 Max:2000 Interval:100];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"nEffective (recommended gt or eq nStates/2)" Name:@"nEffective" DefaultValue:@(250) Min:50 Max:2000 Interval:50];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"alphaWeaken" Name:@"alphaWeaken" DefaultValue:@(0.3)  Min:0 Max:1.0 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"RSSI bias" Name:@"rssi_bias" DefaultValue:@(0)  Min:-10 Max:10 Interval:0.5];
    [blelocppSettingHelper addSettingWithType:BOOLEAN Label:@"Use wheelchair PDR threthold" Name:@"wheelchair_pdr" DefaultValue:@(NO) Accept:nil];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Mix probability from likelihood" Name:@"mixProba" DefaultValue:@(0) Min:0 Max:0.01 Interval:0.001];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Mix reject distance [m]" Name:@"rejectDistance" DefaultValue:@(5) Min:5 Max:100 Interval:5];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Mix reject floor difference" Name:@"rejectFloorDifference" DefaultValue:@(0.95) Min:0 Max:1 Interval:0.05];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Orientation bias diffusion" Name:@"diffusionOrientationBias" DefaultValue:@(10) Min:0 Max:90 Interval:1];
    
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Initial walking speed" Name:@"meanVelocity" DefaultValue:@(1.0) Min:0.25 Max:1.5 Interval:0.05];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Half life of hitting wall" Name:@"weightDecayHalfLife" DefaultValue:@(5) Min:1 Max:10 Interval:1];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Resampling lower bound 2D [m]" Name:@"locLB" DefaultValue:@(0.5) Min:0 Max:2 Interval:0.1];
    [blelocppSettingHelper addSettingWithType:DOUBLE Label:@"Resampling lower bound floor [floor]" Name:@"floorLB" DefaultValue:@(0.1) Min:0.0 Max:1 Interval:0.1];
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
        [blindnaviSettingHelper addSettingWithType:DOUBLE
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
        [mapSettingHelper addSettingWithType:OPTION Label:[map stringByDeletingPathExtension] Name:map Group:@"bleloc_map_data" DefaultValue:@(NO) Accept:nil];
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
    [logSettingHelper addSettingWithType:BOOLEAN Label:@"Replay in realtime" Name:@"replay_in_realtime" DefaultValue:@(NO) Accept:nil];
    [logSettingHelper addSettingWithType:BOOLEAN Label:@"Use sensor log" Name:@"replay_sensor" DefaultValue:@(NO) Accept:nil];
    [logSettingHelper addSettingWithType:BOOLEAN Label:@"Use reset in sensor log" Name:@"replay_with_reset" DefaultValue:@(YES) Accept:nil];
    [logSettingHelper addSettingWithType:BOOLEAN Label:@"Use navigation log" Name:@"replay_navigation" DefaultValue:@(YES) Accept:nil];
    
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
    
    [routeOptionsSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Use Elevator", @"")
                                             Name:@"route_use_elevator" DefaultValue:@(YES) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Use Escalator", @"")
                                             Name:@"route_use_escalator" DefaultValue:@(NO) Accept:nil];
    [routeOptionsSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Use Stairs", @"")
                                             Name:@"route_use_stairs" DefaultValue:@(YES) Accept:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *id = [[tableView cellForRowAtIndexPath:indexPath] reuseIdentifier];
    if ([id isEqualToString:@"search_option"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:@{@"control":ROUTE_SEARCH_OPTION_BUTTON}];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"search_route"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:@{@"control":ROUTE_SEARCH_BUTTON}];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"end_navigation"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:@{@"control":END_NAVIGATION}];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (BOOL) isBlindMode
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    return [[ud stringForKey:@"ui_mode"] isEqualToString:@"UI_BLIND"];
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
