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


#import "NavDataSource.h"
#import "LocationEvent.h"


#pragma mark - Destination Data Source

@implementation NavDestinationDataSource {
    NSArray *sections;
    BOOL _showCurrentLocation;
    BOOL _showFacility;
}

- (instancetype) init {
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [self update:nil];
    return self;
}

- (BOOL) showCurrentLocation
{
    return _showCurrentLocation;
}

- (void) setShowCurrentLocation:(BOOL) flag
{
    _showCurrentLocation = flag;
    [self update:nil];
}

- (BOOL) showFacility
{
    return _showFacility;
}

- (void) setShowFacility:(BOOL) flag
{
    _showFacility = flag;
    [self update:nil];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) update:(NSNotification*)notification {
    NSArray *all = [[NavDataStore sharedDataStore] destinations];
    NSMutableArray *tempSections = [@[] mutableCopy];
    
    if (_showCurrentLocation) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithLocation:nil]];
        [tempSections addObject:@{@"key":@"◎", @"rows":temp}];
    }
    
    if (_showFacility) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithFacility:@"CAT_TOIL_A"]];
        [temp addObject:[[NavDestination alloc] initWithFacility:@"CAT_TOIL_M"]];
        [temp addObject:[[NavDestination alloc] initWithFacility:@"CAT_TOIL_F"]];
        [tempSections addObject:@{@"key":@"🚻", @"rows":temp}];
    }
    NSMutableArray __block *temp = [@[] mutableCopy];
    NSString __block *lastFirst = nil;
    [all enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [landmark getLandmarkNamePron];
        
        if (name == nil || [name length] == 0) {
            NSLog(@"no name landmark %@", landmark);
            return;
        }
        
        NSString *first = [[name substringWithRange:NSMakeRange(0, 1)] lowercaseString];
        
        if (![first isEqualToString:lastFirst]) {
            temp = [@[] mutableCopy];
            [tempSections addObject:@{@"key":first, @"rows":temp}];
        }
        [temp addObject:[[NavDestination alloc] initWithLandmark:landmark]];
        lastFirst = first;
    }];
    
    sections = tempSections;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[sections objectAtIndex:section][@"rows"] count];
}

- (NavDestination*) destinationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NavDestination *ret = [[sections objectAtIndex:indexPath.section][@"rows"] objectAtIndex:indexPath.row];
    
    return ret;
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSMutableArray *titles = [@[] mutableCopy];
    [sections enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [titles addObject:obj[@"key"]];
    }];
    return titles;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [sections objectAtIndex:section][@"key"];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"destinationCell";
    //UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    
    NavDestination *dest = [self destinationForRowAtIndexPath:indexPath];
    
    cell.textLabel.text = dest.name;
    cell.clipsToBounds = YES;
    return cell;
}

@end

@implementation NavSearchHistoryDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSArray *hist = [[NavDataStore sharedDataStore] searchHistory];
    
    return [hist count];
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
    
    NavDestination *from = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"from"]];
    NavDestination *to = [NSKeyedUnarchiver unarchiveObjectWithData:dic[@"to"]];
    
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    cell.textLabel.text = to.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), from.name];
    
    return cell;
}

-(NSDictionary *)historyAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *hist = [[NavDataStore sharedDataStore] searchHistory];
    
    return [hist objectAtIndex:indexPath.row];
}

@end
