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
#import "NavDataSource.h"
#import "LocationEvent.h"
#import <HLPDialog/HLPDialog.h>
#import "DefaultTTS.h"

@interface DestinationTableViewController ()

@end

@implementation DestinationTableViewController {
    NavTableDataSource *_source;
    NavTableDataSource *_defaultSource;
    NavDestination *filterDest;
    UISearchController *searchController;
    
    NSString *lastSearchQuery;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    NSString *query = searchController.searchBar.text;
    if (query && query.length > 0) {
        lastSearchQuery = query;
        searchController.dimsBackgroundDuringPresentation = YES;
        [[NavDataStore sharedDataStore] searchDestinations:query withComplete:^(HLPDirectory *directory) {
            if (![lastSearchQuery isEqualToString:query]) {
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                _source = [[NavDirectoryDataSource alloc] initWithDirectory:directory];
                searchController.dimsBackgroundDuringPresentation = NO;
                [self.tableView reloadData];
            });
        }];
    } else {
        _source = _defaultSource;
        [self.tableView reloadData];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if ([[NavDataStore sharedDataStore] directory]) {
        NavDirectoryDataSource *source = [[NavDirectoryDataSource alloc] init];
        if (filterDest) {
            source.directory = filterDest.item.content;
        } else {
            source.directory = [[NavDataStore sharedDataStore] directory];
            
            if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {
                self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
                source.showDialog = NO;
                source.showCurrentLocation = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_current_location_from_start"];
                source.showFacility = NO;
            }
            if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
                self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
                source.showDialog = YES;
                source.showCurrentLocation = NO;
                source.showFacility = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_facility_from_to"];
            }
            
            searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
            searchController.searchResultsUpdater = self;
            searchController.obscuresBackgroundDuringPresentation = YES;
            searchController.dimsBackgroundDuringPresentation = NO;
            searchController.hidesNavigationBarDuringPresentation = NO;
            searchController.searchBar.placeholder = @"Search";
            if (@available(iOS 11.0, *)) {
                self.navigationItem.searchController = searchController;
            } else {
                self.tableView.tableHeaderView = searchController.searchBar;
            }
        }
        [source update:nil];
        _source = _defaultSource = source;
        self.definesPresentationContext = true;
    } else {
        NavDestinationDataSource *source = [[NavDestinationDataSource alloc] init];

        source.filter = filterDest.filter;
        
        if (source.filter) {
            self.navigationItem.title = filterDest.label;
            source.showShops = YES;
            source.showSectionIndex = YES;
            source.showShopBuilding = NO;
            source.showShopFloor = YES;
        }
        
        if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {
            if (!source.filter) {
                self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
                source.showCurrentLocation = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_current_location_from_start"];
                source.showNearShops = YES;
                source.showBuilding = YES;
                source.showShopBuilding = YES;
                source.showShopFloor = YES;
            }
        }
        if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
            if (!source.filter) {
                self.navigationItem.title = NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
                source.showDialog = YES;
                source.showFacility = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_facility_from_to"];
                source.showBuilding = YES;
                source.showShopBuilding = YES;
                source.showShopFloor = YES;
            }
        }
        [source update:nil];
        _source = source;
    }
    
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configChanged:) name:DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (@available(iOS 11.0, *)) {
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
    }
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
    return [_source numberOfSectionsInTableView:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_source tableView:tableView numberOfRowsInSection:section];
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [_source sectionIndexTitlesForTableView:tableView];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_source tableView:tableView titleForHeaderInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [_source tableView:tableView cellForRowAtIndexPath:indexPath];
    
    cell.textLabel.text = NSLocalizedStringFromTable(cell.textLabel.text, @"BlindView", @"");
    
    NavDestination *dest = [_source destinationForRowAtIndexPath:indexPath];
    if (dest.type == NavDestinationTypeDialogSearch) {
        BOOL dialog = [[DialogManager sharedManager] isAvailable];
        cell.textLabel.enabled = dialog;
        cell.selectionStyle = dialog?UITableViewCellSelectionStyleGray:UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NavDestination *dest = [_source destinationForRowAtIndexPath:indexPath];
    
    if (dest.type == NavDestinationTypeFilter) {
        filterDest = dest;
        [self performSegueWithIdentifier:@"sub_category" sender:self];
    } else if (dest.type == NavDestinationTypeDialogSearch) {
        if ([[DialogManager sharedManager] isAvailable]) {
            [self performSegueWithIdentifier:@"show_dialog" sender:self];
        }
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
            dView->filterDest = filterDest;
            dView.root = _root;
        }
    }
    if ([segue.destinationViewController isKindOfClass:DialogViewController.class]){
        DialogViewController* dView = (DialogViewController*)segue.destinationViewController;
        dView.root = _root;
        dView.tts = [DefaultTTS new];
    }
}


@end
