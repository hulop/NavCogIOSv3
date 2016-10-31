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
#import "NavDataStore.h"

@interface DestinationTableViewController ()

@end

@implementation DestinationTableViewController {
    NavDestinationDataSource *source;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    source = [[NavDestinationDataSource alloc] init];
    
    if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {
        source.showCurrentLocation = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_current_location_from_start"];
    }
    if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
        source.showToilet = ![[NSUserDefaults standardUserDefaults] boolForKey:@"hide_toilet_from_to"];
    }
    
    [self.tableView reloadData];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    if ([self.restorationIdentifier isEqualToString:@"fromDestinations"]) {
        [NavDataStore sharedDataStore].fromID = [source idForRowAtIndexPath:indexPath];
        [NavDataStore sharedDataStore].fromTitle = [source titleForRowAtIndexPath:indexPath];
    }
    if ([self.restorationIdentifier isEqualToString:@"toDestinations"]) {
        [NavDataStore sharedDataStore].toID = [source idForRowAtIndexPath:indexPath];
        [NavDataStore sharedDataStore].toTitle = [source titleForRowAtIndexPath:indexPath];
    }
    [self.navigationController popViewControllerAnimated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
