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
#import <HLPWebView/HLPWebView.h>
#import "SettingViewController.h"
#import "LocationEvent.h"
#import "NavDeviceTTS.h"
#import "NavDataStore.h"
#import "NavUtil.h"

@interface SettingViewController ()

@end

@implementation SettingViewController {
}

static HLPSettingHelper *userSettingHelper;

static HLPSetting *speechLabel, *speechSpeedSetting, *vibrateSetting, *soundEffectSetting;
static HLPSetting *previewSpeedSetting, *previewWithActionSetting;
static HLPSetting *boneConductionSetting, *exerciseLabel, *exerciseAction, *resetLocation;
static HLPSetting *mapLabel, *initialZoomSetting, *unitLabel, *unitMeter, *unitFeet, *idLabel;
static HLPSetting *advancedLabel, *advancedMenu;


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    
    HLPSettingHelper *helper;
    
    if ([self.restorationIdentifier isEqualToString:@"user_settings"]) {
        [SettingViewController setupUserSettings];
        helper = userSettingHelper;
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:@"speech_speed"
                                                   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                                   context:nil];
    }

    

    if (helper) {
        helper.delegate = self;
        self.tableView.delegate = helper;
        self.tableView.dataSource = helper;
    }
    [self updateView];
    
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
}

-(void)actionPerformed:(HLPSetting*)setting
{
    if ([setting.name isEqualToString:@"save_setting"]) {
    } else if ([setting.name isEqualToString:@"Reset_Location"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_UNKNOWN object:self];
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if ([setting.name isEqualToString:@"OpenHelp"]) {
        NSString *lang = [@"-" stringByAppendingString:[[NavDataStore sharedDataStore] userLanguage]];
        if ([lang isEqualToString:@"-en"]) { lang = @""; }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://hulop.github.io/help%@", lang]];
        [NavUtil openURL:url onViewController:self];
    } else {
        [self performSegueWithIdentifier:setting.name sender:self];
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
}

+ (void)setupUserSettings
{
    if (userSettingHelper) {
        BOOL blindMode = NO;
        //[speechLabel setVisible:blindMode];
        //[speechSpeedSetting setVisible:blindMode];
        [previewSpeedSetting setVisible:blindMode];
        [previewWithActionSetting setVisible:blindMode];
        [vibrateSetting setVisible:blindMode];
        [soundEffectSetting setVisible:blindMode];
        [boneConductionSetting setVisible:blindMode];
        [exerciseLabel setVisible:blindMode];
        [exerciseAction setVisible:blindMode];
        //[mapLabel setVisible:blindMode];
        //[initialZoomSetting setVisible:blindMode];
        [resetLocation setVisible:!blindMode];
        [unitLabel setVisible:blindMode];
        [unitMeter setVisible:blindMode];
        [unitFeet setVisible:blindMode];
        
        idLabel.label = [NavDataStore sharedDataStore].userID;
        BOOL isDeveloperAuthorized = NO;
        [idLabel setVisible:isDeveloperAuthorized];
        [advancedLabel setVisible:isDeveloperAuthorized];
        [advancedMenu setVisible:isDeveloperAuthorized];
        
        return;
    }
    userSettingHelper = [[HLPSettingHelper alloc] init];

    
    speechLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Speech_Sound", @"label for tts options")];
    speechSpeedSetting = [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Speech speed", @"label for speech speed option")
                                     Name:@"speech_speed" DefaultValue:@(0.55) Min:0.1 Max:1 Interval:0.05];
    previewSpeedSetting = [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Preview speed", @"") Name:@"preview_speed" DefaultValue:@(1) Min:1 Max:10 Interval:1];
    previewWithActionSetting = [userSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Preview with action", @"") Name:@"preview_with_action" DefaultValue:@(NO) Accept:nil];
    vibrateSetting = [userSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"vibrateSetting", @"") Name:@"vibrate" DefaultValue:@(YES) Accept:nil];
    soundEffectSetting = [userSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"soundEffectSetting", @"") Name:@"sound_effect" DefaultValue:@(YES) Accept:nil];
    boneConductionSetting = [userSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"for_bone_conduction_headset",@"") Name:@"for_bone_conduction_headset" DefaultValue:@(NO) Accept:nil];

    
    exerciseLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Exercise", @"label for exercise options")];
    exerciseAction = [userSettingHelper addActionTitle:NSLocalizedString(@"Launch Exercise", @"") Name:@"launch_exercise"];
    
    mapLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Map", @"label for map")];
    mapLabel.visible = NO;
    initialZoomSetting = [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Initial zoom level for navigation", @"") Name:@"zoom_for_navigation" DefaultValue:@(20) Min:15 Max:22 Interval:1];
    initialZoomSetting.visible = NO;
    
    resetLocation = [userSettingHelper addActionTitle:NSLocalizedString(@"Reset_Location", @"") Name:@"Reset_Location"];
    

    unitLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Distance unit", @"label for distance unit option")];
    unitMeter = [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Meter", @"meter distance unit label")
                                     Name:@"unit_meter" Group:@"distance_unit" DefaultValue:@(YES) Accept:nil];
    unitFeet = [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Feet", @"feet distance unit label")
                                     Name:@"unit_feet" Group:@"distance_unit" DefaultValue:@(NO) Accept:nil];
    
    [userSettingHelper addSectionTitle:NSLocalizedString(@"Help", @"")];
    [userSettingHelper addActionTitle:NSLocalizedString(@"OpenHelp", @"") Name:@"OpenHelp"];

    NSString *versionNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"version: %@ (%@)", versionNo, buildNo]];
    idLabel = [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"%@", [NavDataStore sharedDataStore].userID]];
    
    advancedLabel = [userSettingHelper addSectionTitle:NSLocalizedString(@"Advanced", @"")];
    advancedMenu = [userSettingHelper addActionTitle:NSLocalizedString(@"Advanced Setting", @"") Name:@"advanced_settings"];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *id = [[tableView cellForRowAtIndexPath:indexPath] reuseIdentifier];
    if ([id isEqualToString:@"search_option"]) {
        [self.webViewHelper triggerWebviewControl:WebviewControlRouteSearchOptionButton];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"search_route"]) {
        [self.webViewHelper triggerWebviewControl:WebviewControlRouteSearchButton];
        [self.navigationController popViewControllerAnimated:YES];
    }
    if ([id isEqualToString:@"end_navigation"]) {
        [self.webViewHelper triggerWebviewControl:WebviewControlEndNavigation];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [super tableView:tableView heightForHeaderInSection:section];
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
