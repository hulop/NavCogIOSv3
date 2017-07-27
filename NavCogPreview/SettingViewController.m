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

#import "SettingViewController.h"
#import "ConfigManager.h"
#import "LocationEvent.h"
#import "AuthManager.h"
#import "ServerConfig+FingerPrint.h"
#import "NavUtil.h"
#import "NavDataStore.h"
#import "HLPFingerprint.h"
#import "BlindViewController.h"

@interface SettingViewController ()

@end

@implementation SettingViewController {
}

static HLPSettingHelper *userSettingHelper;
static HLPSettingHelper *routeOptionsSettingHelper;

static HLPSetting *idLabel;


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
    if ([self.restorationIdentifier isEqualToString:@"route_options_setting"]) {
        helper = routeOptionsSettingHelper;
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
}

+ (void)setup
{
    [SettingViewController setupUserSettings];
    [SettingViewController setupRouteOptionsSettings];
}

+ (void)setupUserSettings
{
    if (userSettingHelper) {
        idLabel.label = [NavDataStore sharedDataStore].userID;
        
        return;
    }
    userSettingHelper = [[HLPSettingHelper alloc] init];
  
    [userSettingHelper addSectionTitle:@"Forward Direction"];
    [userSettingHelper addSettingWithType:OPTION Label:@"Up - Forward" Name:@"UpForward" Group:@"forwardDirection" DefaultValue:@(YES) Accept:nil];
    [userSettingHelper addSettingWithType:OPTION Label:@"Down - Forward" Name:@"DownForward" Group:@"forwardDirection" DefaultValue:@(YES) Accept:nil];

    [userSettingHelper addSectionTitle:@"Preview Parameters"];
    [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Speech speed", @"label for speech speed option")
                                     Name:@"speech_speed" DefaultValue:@(0.55) Min:0.1 Max:1 Interval:0.05];

    [userSettingHelper addSettingWithType:DOUBLE Label:@"Step Length" Name:@"preview_step_length" DefaultValue:@(0.75)Min:0.25 Max:1.5 Interval:0.05];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Step sound for jump" Name:@"step_sound_for_jump" DefaultValue:@(YES) Accept:nil];

    
    [[userSettingHelper addSettingWithType:BOOLEAN Label:@"Use HTTPS" Name:@"https_connection" DefaultValue:@(YES) Accept:nil] setVisible:NO];
    [[userSettingHelper addSettingWithType:TEXTINPUT Label:@"Server Host" Name:@"hokoukukan_server" DefaultValue:@"" Accept:nil] setVisible:NO];
    [[userSettingHelper addSettingWithType:TEXTINPUT Label:@"Context" Name:@"hokoukukan_server_context" DefaultValue:@"" Accept:nil] setVisible:NO];


    NSString *versionNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildNo = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"version: %@ (%@)", versionNo, buildNo]];
    idLabel = [userSettingHelper addSectionTitle:[NSString stringWithFormat:@"%@", [NavDataStore sharedDataStore].userID]];
    
}

+ (void)setupRouteOptionsSettings
{
    if (routeOptionsSettingHelper) {
        return;
    }
    routeOptionsSettingHelper = [[HLPSettingHelper alloc] init];
    
    
    [routeOptionsSettingHelper addSettingWithType:BOOLEAN Label:NSLocalizedString(@"Prefer Tactile Paving", @"")
                                             Name:@"route_tactile_paving" DefaultValue:@(YES) Accept:nil];
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
