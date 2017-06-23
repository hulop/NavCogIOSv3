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

#import "SearchViewController.h"
#import "NavDataSource.h"
#import "NavUtil.h"
#import "LocationEvent.h"
#import "DestinationTableViewController.h"
@import AVFoundation;

@interface NavSearchHistoryDataSource2: NavSearchHistoryDataSource
@end

@implementation NavSearchHistoryDataSource2

- (BOOL)isKnownHist:(NSDictionary*)dic
{
    NavDestination *from = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"from"]];
    NavDestination *to = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"to"]];
    if (to.type == NavDestinationTypeSelectDestination) {
        return [[NavDataStore sharedDataStore] isKnownDestination:from];
    }
    return [[NavDataStore sharedDataStore] isKnownDestination:from] &&
    [[NavDataStore sharedDataStore] isKnownDestination:to];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"historyCell";
    //UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    NSArray *hist = [[NavDataStore sharedDataStore] searchHistory];
    NSDictionary *dic = hist[indexPath.row];
    BOOL isKnown = [self isKnownHist:dic];
    
    NavDestination *from = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"from"]];
    NavDestination *to = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"to"]];
    
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    cell.textLabel.text = from.name;
    cell.textLabel.accessibilityLabel = isKnown?from.namePron:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Disabled", @"BlindView", @""), from.namePron];
    
    if (to.type == NavDestinationTypeSelectDestination) {
        cell.detailTextLabel.text = nil;
        cell.detailTextLabel.accessibilityLabel = nil;
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"to: %@", @"BlindView", @""), to.name];
        cell.detailTextLabel.accessibilityLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"to: %@", @"BlindView", @""), to.namePron];
    }
    
    cell.contentView.layer.opacity = isKnown?1.0:0.5;
    
    return cell;
}

@end

@interface SearchViewController () {
    BOOL updated;
    BOOL actionEnabled;
    NSString *lastIdentifier;
}

@end

@implementation SearchViewController {
    NavSearchHistoryDataSource *historySource;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.fromButton.titleLabel.numberOfLines = 1;
    self.fromButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.fromButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    
    self.toButton.titleLabel.numberOfLines = 1;
    self.toButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.toButton.titleLabel.lineBreakMode = NSLineBreakByClipping;
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    if (nds.from == nil && nds.to == nil) {
        nds.from = [NavDataStore destinationForCurrentLocation];
        nds.to = [NavDestination selectDestination];
    }
    self.useDestination.on = !(nds.to == nil || nds.to._id == nil);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationsChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartNavigation:) name:REQUEST_START_NAVIGATION object:nil];


    historySource = [[NavSearchHistoryDataSource2 alloc] init];
    _historyView.dataSource = historySource;
    _historyView.delegate = self;
    [_historyView reloadData];
    [self loadDestinations:NO];
    
    actionEnabled = NO;
    
    // Do any additional setup after loading the view.
}

- (void)requestStartNavigation:(NSNotification*)note
{
    NSDictionary *param = [note userInfo];
    NSString *toID = param[@"toID"];
    NSString *fromID = param[@"fromID"];
    NSArray *toIDs = [toID componentsSeparatedByString:@"|"];
    
    if (fromID) {
        NavDestination *from = [[NavDataStore sharedDataStore] destinationByID:fromID];
        if (from) {
            NavDataStore *nds = [NavDataStore sharedDataStore];
            nds.from = from;
            [self updateViewWithFlag:YES];
        }
    }
    if (toID) {
        NavDestination *dest = [[NavDataStore sharedDataStore] destinationByIDs:toIDs];
        if (dest) {
            [NavDataStore sharedDataStore].to = dest;
            [self updateViewWithFlag:YES];
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NavDataStore *nds = [NavDataStore sharedDataStore];
                nds.previewMode = YES;
                nds.exerciseMode = NO;
                
                NSMutableDictionary *override = [@{} mutableCopy];
                if (param[@"use_stair"]) {
                  override[@"stairs"] = [param[@"use_stair"] boolValue]?@"9":@"1";
                }
                if (param[@"use_elevator"]) {
                    override[@"elv"] = [param[@"use_elevator"] boolValue]?@"9":@"1";
                }
                if (param[@"use_escalator"]) {
                    override[@"esc"] = [param[@"use_escalator"] boolValue]?@"9":@"1";
                }
                
                [self _startNavigation:override];
            });
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateViewWithFlag:YES];
}

- (IBAction)refreshDestinations:(id)sender {
    updated = false;
    [self loadDestinations:YES];
}

- (void) loadDestinations:(BOOL) force
{
    if (!updated) {
        if ([[NavDataStore sharedDataStore] reloadDestinations:force]) {
            actionEnabled = NO;
            [self updateViewWithFlag:NO];
            [NavUtil showModalWaitingWithMessage:NSLocalizedString(@"Loading, please wait",@"")];
            return;
        }
    }
    actionEnabled = YES;
    [self updateViewWithFlag:NO];
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
                                                          [self.navigationController popViewControllerAnimated:YES];
                                                      });
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alert animated:YES completion:nil];
        });

    }
    updated = YES;
    actionEnabled = YES;
    [self.historyView reloadData];
    [self updateViewWithFlag:NO];
}

- (void) locationChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavDataStore *nds = [NavDataStore sharedDataStore];
        HLPLocation *loc = [nds currentLocation];
        BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
    });
}

- (IBAction)valueChanged:(id)sender
{
    if (self.useDestination.on == NO) {
        [NavDataStore sharedDataStore].to = [NavDestination selectDestination];
    }
    [self updateViewWithFlag:NO];
}


- (void) updateViewWithFlag:(BOOL)voiceoverNotificationFlag
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.hidesBackButton = !updated || !actionEnabled;
        if (!updated || !actionEnabled) {
            self.navigationItem.leftBarButtonItem = nil;
        }
        
        NavDataStore *nds = [NavDataStore sharedDataStore];
        HLPLocation *loc = [nds currentLocation];
        BOOL isNotManual = ![nds isManualLocation] || [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
        BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
        BOOL useDest = self.useDestination.on;

        self.fromButton.enabled = updated && actionEnabled;
        self.toButton.enabled = updated && actionEnabled;
        self.refreshButton.enabled = updated && actionEnabled;
        
        self.switchButton.enabled = (nds.to._id != nil && nds.from._id != nil && actionEnabled);
        self.previewButton.enabled = ((!useDest || nds.to._id != nil) && nds.from._id != nil && actionEnabled);
        
        
        [self.fromButton setTitle:nds.from.name forState:UIControlStateNormal];
        
        if (nds.from.type == NavDestinationTypeSelectStart) {
            self.fromButton.accessibilityLabel = nds.from.name;
        } else {
            self.fromButton.accessibilityLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"From_button", @"BlindView", @""), nds.from.namePron];
        }
        
        [self.toButton setTitle:nds.to.name forState:UIControlStateNormal];
        if (nds.to.type == NavDestinationTypeSelectDestination) {
            self.toButton.accessibilityLabel = nds.to.name;
        } else {
            self.toButton.accessibilityLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"To_button", @"BlindView", @""), nds.to.namePron];
        }
        
        self.historyClearButton.enabled = ([[nds searchHistory] count] > 0) && updated && actionEnabled;
        
        self.toLabel.enabled = useDest;
        self.toButton.hidden = !useDest;
        self.toArrow.hidden = !useDest;
        self.switchButton.hidden = !useDest;
    });
}

- (IBAction)switchFromTo:(id)sender {
    [[NavDataStore sharedDataStore] switchFromTo];
    [self updateViewWithFlag:YES];
}

- (IBAction)clearHistory:(id)sender {
    [[NavDataStore sharedDataStore] clearSearchHistory];
    [_historyView reloadData];
    [self updateViewWithFlag:YES];
}

- (IBAction)previewNavigation:(id)sender {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    nds.previewMode = YES;
    nds.exerciseMode = NO;
    [self _startNavigation:nil];
}

- (void) _startNavigation:(NSDictionary*)override
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    __block NSMutableDictionary *prefs = [@{
                            @"dist":@"500",
                            @"preset":@"9",
                            @"min_width":@"8",
                            @"slope":@"9",
                            @"road_condition":@"9",
                            @"deff_LV":@"9",
                            @"stairs":[ud boolForKey:@"route_use_stairs"]?@"9":@"1",
                            @"esc":[ud boolForKey:@"route_use_escalator"]?@"9":@"1",
                            @"elv":[ud boolForKey:@"route_use_elevator"]?@"9":@"1",
                            @"tactile_paving":[ud boolForKey:@"route_tactile_paving"]?@"1":@"",
                            } mutableCopy];
    // override
    [override enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        prefs[key] = obj;
    }];
    
    actionEnabled = NO;
    [self updateViewWithFlag:NO];
    [NavUtil showModalWaitingWithMessage:NSLocalizedString(@"Loading, please wait",@"")];    
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionAllowBluetooth
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    if (nds.to._id != nil) {
        [[NavDataStore sharedDataStore] requestRouteFrom:nds.from.singleId To:nds.to._id withPreferences:prefs complete:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                /*
                 if (nds.route && nds.to.type == NavDestinationTypeLandmarks) {
                 HLPNode *dest = [nds.route lastObject];
                 nds.to = [nds destinationByID:dest._id];
                 }
                 */
                
                [self.navigationController popViewControllerAnimated:YES];
                [NavUtil hideModalWaiting];
            });
        }];
    } else {        
        [[NavDataStore sharedDataStore] requestRouteFrom:nds.from.singleId To:nds.from.singleId withPreferences:prefs complete:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                /*
                 if (nds.route && nds.to.type == NavDestinationTypeLandmarks) {
                 HLPNode *dest = [nds.route lastObject];
                 nds.to = [nds destinationByID:dest._id];
                 }
                 */
                
                [self.navigationController popViewControllerAnimated:YES];
                [NavUtil hideModalWaiting];
            });
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *hist = [historySource historyAtIndexPath:indexPath];
    
    if ([historySource isKnownHist:hist]) {
        return indexPath;
    }
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *hist = [historySource historyAtIndexPath:indexPath];
    
    return [historySource isKnownHist:hist];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *hist = [historySource historyAtIndexPath:indexPath];
    
    if ([historySource isKnownHist:hist]) {
        NavDataStore *nds = [NavDataStore sharedDataStore];
        nds.to = [NSKeyedUnarchiver unarchiveObjectWithData:hist[@"to"]];
        nds.from = [NSKeyedUnarchiver unarchiveObjectWithData:hist[@"from"]];
        [self updateViewWithFlag:YES];
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.destinationViewController isKindOfClass:DestinationTableViewController.class]) {
        [NavUtil hideModalWaiting];

        DestinationTableViewController *dView = (DestinationTableViewController*)segue.destinationViewController;
        lastIdentifier = dView.restorationIdentifier = segue.identifier;
        dView.root = self;
        
        if ([lastIdentifier isEqualToString:@"toDestinations"]) {
            dView.voTarget = _toButton;
        } else {
            dView.voTarget = _fromButton;
        }
    
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if ([sender isKindOfClass:NSArray.class]) {
                NSArray *temp = [sender copy];
                if ([temp count] > 0) {
                    NSString *name = temp[0];
                    temp = [temp subarrayWithRange:NSMakeRange(1, [temp count]-1)];
                    [[segue destinationViewController] performSegueWithIdentifier:name sender:temp];
                }
            }
        });
    } else {
        segue.destinationViewController.restorationIdentifier = segue.identifier;
    }
}


@end
