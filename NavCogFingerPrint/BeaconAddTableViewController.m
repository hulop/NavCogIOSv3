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

#import "BeaconAddTableViewController.h"
#import "HLPBeaconSample.h"

@interface BeaconAddTableViewController ()

@end

@implementation BeaconAddTableViewController {
    FingerprintManager *fpm;
    NSArray *beacons;
    UIBarButtonItem *refreshBtn;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    refreshBtn = [[UIBarButtonItem alloc] initWithTitle:@"Refresh" style:UIBarButtonItemStylePlain target:self action:@selector(refreshBeacons)];
    self.navigationItem.rightBarButtonItem = refreshBtn;
 
    fpm = [FingerprintManager sharedManager];
    
    [self refreshBeacons];
    [self updateView];
}

- (void) refreshBeacons
{
    fpm.delegate = self;
    [fpm cancel];
    [fpm startSamplingAtLat:0 Lng:0];
}

- (void) updateView
{
    [self.tableView reloadData];
}

- (BOOL)manager:(FingerprintManager *)manager didObservedBeacons:(int)beaconCount atSample:(int)sampleCount
{
    beacons = [manager.visibleBeacons sortedArrayUsingComparator:^NSComparisonResult(CLBeacon*  _Nonnull b1, CLBeacon*  _Nonnull b2) {
        return [@(b2.rssi) compare:@(b1.rssi)];
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateView];
    });
    return beaconCount < 1;
}

- (void)manager:(FingerprintManager *)manager didStatusChanged:(BOOL)isReady
{
}

- (void)manager:(FingerprintManager *)manager didSamplingsLoaded:(NSArray *)samplings
{
}

- (void)manager:(FingerprintManager *)manager didSendData:(NSString *)idString withError:(NSError *)error
{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!beacons) {
        return 0;
    }
    return [beacons count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"beaconcell" forIndexPath:indexPath];

    NSString *label = @"";
    if (indexPath.row < [beacons count]) {
        CLBeacon *beacon = [beacons objectAtIndex:indexPath.row];
        label = [NSString stringWithFormat:@"Maj:%@, Min:%@, RSSI:%ld", beacon.major, beacon.minor, beacon.rssi];
    }
    cell.textLabel.text = label;
    
    return cell;
}


#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (beacons) {
        _selectedBeacon = [beacons objectAtIndex:indexPath.row];
    }
    [self performSegueWithIdentifier:@"unwind_beaconadd" sender:self];
}



@end
