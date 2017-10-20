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
#import "NavUtil.h"
#import "NavDataStore.h"
#import "NavDataSource.h"
#import "HLPFingerprint.h"
#import "BlindViewController.h"
#import "ServerConfig+Preview.h"
#import "ExpConfig.h"

@interface SettingViewController ()

@end

@implementation SettingViewController {
}

static HLPSettingHelper *userSettingHelper;
static HLPSettingHelper *routeOptionsSettingHelper;
static HLPSettingHelper *expSettingHelper;
static NavDestinationDataSource *destSource;
static HLPSettingHelper *areaSettingHelper;
static NSDictionary<NSString*, NavDestination*> *destMap;

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
    if ([self.restorationIdentifier isEqualToString:@"exp_settings"]) {
        [SettingViewController setupExpSettings];
        helper = expSettingHelper;
        self.navigationItem.title = @"Select a route";
    }
    if ([self.restorationIdentifier isEqualToString:@"area_selection"]) {
        destSource = [[NavDestinationDataSource alloc] init];
        destSource.showBuilding = YES;
        [destSource update:nil];
        [SettingViewController setupAreaSettings];
        helper = areaSettingHelper;
        self.navigationItem.title = @"Select an area";
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configChanged:) name:EXP_ROUTES_CHANGED_NOTIFICATION object:nil];
    
    if (helper) {
        helper.delegate = self;
        self.tableView.delegate = helper;
        self.tableView.dataSource = helper;
    }
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
    if ([self.restorationIdentifier isEqualToString:@"exp_settings"]) {
        if ([[ExpConfig sharedConfig] expUserRoutes] == nil ){
            [self performSegueWithIdentifier:@"show_exp_view" sender:self];
        }
    }
}

- (void) configChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [SettingViewController setupExpSettings];
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
    if ([self.restorationIdentifier isEqualToString:@"exp_settings"]) {
        
        NSArray *routes = [[ExpConfig sharedConfig] expUserRoutes];
        
        for(NSDictionary *route in routes) {
            if ([route[@"name"] isEqualToString:setting.name]) {
                [self requestRoute:route];
            }
        }
    }

    if ([setting.name isEqualToString:@"help_preview"]) {
        NSString *lang = [@"-" stringByAppendingString:[[NavDataStore sharedDataStore] userLanguage]];
        if ([lang isEqualToString:@"-en"]) { lang = @""; }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://hulop.github.io/help_preview%@", lang]];
        [NavUtil openURL:url onViewController:self];
    }
    
    if ([self.restorationIdentifier isEqualToString:@"area_selection"]) {
        NSDictionary* filter = destMap[setting.name].filter;
        if ([filter[@"building"] isEqual:[NSNull null]]) {
            filter = @{@"building":@""};
        }
        [[NSUserDefaults standardUserDefaults] setObject:filter forKey:PREVIEW_SELECTED_FILTER];
        [self performSegueWithIdentifier:@"unwind_to_search" sender:self];
    }
}

- (void)requestRoute:(NSDictionary*)route
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil showModalWaitingWithMessage:@"Loading, please wait..."];
    });
    [ExpConfig sharedConfig].currentRoute = route;
    NSString *from = route[@"from_id"];
    NSString *to = route[@"to_id"];
    NSDictionary *options = route[@"options"];
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    nds.from = [nds destinationByID:from];
    nds.to = [nds destinationByID:to];
    
    [[NavDataStore sharedDataStore] requestRouteFrom:from To:to withPreferences:options complete:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.navigationController popViewControllerAnimated:YES];
            [NavUtil hideModalWaiting];
        });
    }];
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
  
    [userSettingHelper addSectionTitle:@"Help"];
    [userSettingHelper addActionTitle:@"Help" Name:@"help_preview"];
    
    [userSettingHelper addSectionTitle:NSLocalizedString(@"Distance unit", @"label for distance unit option")];
    [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Meter", @"meter distance unit label")
                                     Name:@"unit_meter" Group:@"distance_unit" DefaultValue:@(NO) Accept:nil];
    [userSettingHelper addSettingWithType:OPTION Label:NSLocalizedString(@"Feet", @"feet distance unit label")
                                     Name:@"unit_feet" Group:@"distance_unit" DefaultValue:@(YES) Accept:nil];

    
    [[userSettingHelper addSectionTitle:@"Forward Direction"] setVisible:NO];
    [[userSettingHelper addSettingWithType:OPTION Label:@"Up - Forward" Name:@"UpForward" Group:@"forwardDirection" DefaultValue:@(YES) Accept:nil] setVisible:NO];
    [[userSettingHelper addSettingWithType:OPTION Label:@"Down - Forward" Name:@"DownForward" Group:@"forwardDirection" DefaultValue:@(YES) Accept:nil] setVisible:NO];

    [userSettingHelper addSectionTitle:@"Preview Parameters"];
    [userSettingHelper addSettingWithType:DOUBLE Label:NSLocalizedString(@"Speech speed", @"label for speech speed option")
                                     Name:@"speech_speed" DefaultValue:@(0.55) Min:0.1 Max:1 Interval:0.05];

    [[userSettingHelper addSettingWithType:DOUBLE Label:@"Step Length" Name:@"preview_step_length" DefaultValue:@(0.75)Min:0.25 Max:1.5 Interval:0.05] setVisible:NO];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Prevent Offroute" Name:@"prevent_offroute" DefaultValue:@(YES) Accept:nil];
    
    [userSettingHelper addSectionTitle:@"Preview Jump"];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Step sound for jump" Name:@"step_sound_for_jump" DefaultValue:@(YES) Accept:nil];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Ignore facility info. for jump" Name:@"ignore_facility_for_jump2" DefaultValue:@(YES) Accept:nil];
    
    [userSettingHelper addSectionTitle:@"Preview Walk"];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Step sound for walk" Name:@"step_sound_for_walk" DefaultValue:@(YES) Accept:nil];
    [userSettingHelper addSettingWithType:BOOLEAN Label:@"Ignore facility info. for walk" Name:@"ignore_facility_for_walk2" DefaultValue:@(YES) Accept:nil];

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


+ (void)setupExpSettings
{
    if (!expSettingHelper) {
        expSettingHelper = [[HLPSettingHelper alloc] init];
    }
    [expSettingHelper removeAllSetting];
    
    NSArray *routes = [[ExpConfig sharedConfig] expUserRoutes];
    if (routes == nil) {
        return;
    }
    for(NSDictionary *route in routes) {
        double limit = [route[@"limit"] doubleValue];
        double elapsed_time = [[ExpConfig sharedConfig] elapsedTimeForRoute:route];
        
        NSString *title = [NSString stringWithFormat:@"%@  [%.0f of %.0f minutes]", route[@"name"], floor(elapsed_time / 60), round(limit / 60)];
        
        HLPSetting *setting = [expSettingHelper addActionTitle:title Name:route[@"name"]];        
        setting.disabled = (elapsed_time > limit);
    }
}

+ (void)setupAreaSettings
{
    if (!areaSettingHelper) {
        areaSettingHelper = [[HLPSettingHelper alloc] init];
    }
    [areaSettingHelper removeAllSetting];
    [areaSettingHelper addSectionTitle:@"Select an area"];
    
    UITableView *view = [[UITableView alloc] init];
    NSInteger rows = [destSource tableView:view numberOfRowsInSection:0];
    NSMutableDictionary *temp = [@{} mutableCopy];
    for(long i = 0; i < rows; i++) {
        NSIndexPath *index = [NSIndexPath indexPathForRow:i inSection:0];
        NavDestination *dest = [destSource destinationForRowAtIndexPath:index];
        NSString *title = dest.filter[@"building"];
        if ([title isEqual:[NSNull null]]) {
            title = @"NOAREA";
        }
        [areaSettingHelper addActionTitle:title Name:title];
        temp[title] = dest;
    }
    destMap = temp;
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
