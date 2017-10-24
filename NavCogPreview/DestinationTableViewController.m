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

#import "DestinationTableViewController.h"
#import "LocationEvent.h"
#import "HLPGeoJSON+External.h"

@interface DestinationTableViewController ()

@end

@implementation DestinationTableViewController {
    NavDestinationDataSource *source;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    source = [[NavDestinationDataSource alloc] init];
    source.defaultFilter = @{@"minor_category":@{@"$not_contains":@"_preview_no_destination_"}};
    source.filter = _filterDest.filter;
    if (source.filter) {
        self.navigationItem.title = _filterDest.label;
        source.showShops = YES;
        source.showSectionIndex = YES;
        source.showShopBuilding = NO;
        source.showShopFloor = YES;
    }
    
    if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {
        if (!source.filter) {
            self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
            source.showCurrentLocation = NO;
            source.showDialog = NO;
            source.showNearShops = YES;
            source.showBuilding = YES;
            source.showShopBuilding = YES;
            source.showShopFloor = YES;
        }
    }
    if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
        if (!source.filter) {
            self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
            source.showCurrentLocation = NO;
            source.showDialog = NO;
            source.showFacility = YES;
            source.showBuilding = YES;
            source.showShopBuilding = YES;
            source.showShopFloor = YES;
        }
    }
    [source update:nil];
    
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configChanged:) name:DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configChanged:(NSNotification*)note {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [source numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [source tableView:tableView numberOfRowsInSection:section];
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [source sectionIndexTitlesForTableView:tableView];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [source tableView:tableView titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [source tableView:tableView cellForRowAtIndexPath:indexPath];
    
    cell.textLabel.text = NSLocalizedStringFromTable(cell.textLabel.text, @"BlindView", @"");
    
    return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NavDestination *dest = [source destinationForRowAtIndexPath:indexPath];
    
    if (dest.type == NavDestinationTypeFilter) {
        _filterDest = dest;
        [self performSegueWithIdentifier:@"sub_category" sender:self];
    } else {
        if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {            
            [NavDataStore sharedDataStore].from = dest;
        }
        if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
            [NavDataStore sharedDataStore].to = dest;
        }
        [self.navigationController popToViewController:_root animated:YES];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _voTarget);        
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"sub_category"]) {
        if ([segue.destinationViewController isKindOfClass:DestinationTableViewController.class]) {
            DestinationTableViewController *dView = (DestinationTableViewController*)segue.destinationViewController;
            dView.restorationIdentifier = self.restorationIdentifier;
            dView.filterDest = _filterDest;
            dView.root = _root;
        }
    }
}


@end
