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
}

- (instancetype) init {
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) update:(NSNotification*)notification {
    NSArray *all = [[[NavDataStore sharedDataStore] destinations] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLandmark *landmark, NSDictionary<NSString *,id> * _Nullable bindings) {
        BOOL flag = YES;
        if (_filter) {
            for(NSString *key in _filter.allKeys) {
                flag = flag && [landmark.properties[key] isEqual:_filter[key]];
            }
        }
        return flag;
    }]];
    
    NSMutableArray *tempSections = [@[] mutableCopy];
    
    if (_showCurrentLocation) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithLocation:nil]];
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_latlng",@"BlindView",@""), @"rows":temp}];
    }
    
    if (_showNearShops) {
        NSMutableArray *temp = [@[] mutableCopy];
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        [[all sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *obj1, HLPLandmark *obj2) {
            NSComparisonResult r = [@(fabs(loc.floor - obj1.nodeHeight)) compare:@(fabs(loc.floor - obj2.nodeHeight))];
            if (r == NSOrderedSame) {
                HLPLocation *loc1 = [obj1 nearestLocationTo:loc];
                HLPLocation *loc2 = [obj2 nearestLocationTo:loc];
                return [@([loc1 distanceTo:loc]) compare:@([loc2 distanceTo:loc])];
            }
            return r;
        }] enumerateObjectsUsingBlock:^(HLPLandmark *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            HLPLocation *loc1 = [obj nearestLocationTo:loc];
            double dist = [loc1 distanceTo:loc];
            if (idx < 5 && fabs(loc.floor - obj.nodeHeight) < 0.5 && dist < 25) {
                [temp addObject:[[NavDestination alloc] initWithLandmark:obj]];
            }
        }];
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_near_shops",@"BlindView",@""), @"rows":temp}];
    }
    
    if (_showBuilding) {
        BOOL __block noBuilding = NO;
        NSMutableArray __block *temp = [@[] mutableCopy];
        NSMutableDictionary __block *buildings = [@{} mutableCopy];
        [all enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *building = landmark.properties[@"building"];
            if (building) {
                if (!buildings[building]) {
                    [buildings setObject:[[NavDestination alloc] initWithLabel:building Filter:@{@"building":building}]
                                  forKey:building];
                }
            } else {
                noBuilding = YES;
            }
        }];
        [[[buildings allKeys] sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [obj1 compare:obj2];
        }] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [temp addObject:buildings[obj]];
        }];
        if ([buildings count] > 0) {
            [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_building",@"BlindView",@""), @"rows":temp}];
            
            if (noBuilding) {
                [temp addObject:[[NavDestination alloc] initWithLabel:NSLocalizedStringFromTable(@"Others", @"BlindView", @"") Filter:@{@"building":@""}]];
            }
        } else {
            if (noBuilding) {
                _showBuilding = NO;
                _showShops = YES;
            }
        }
    }
    
    if (_showFacility) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithFacility:NavDestinationFacilityTypeToiletA]];
        [temp addObject:[[NavDestination alloc] initWithFacility:NavDestinationFacilityTypeToiletM]];
        [temp addObject:[[NavDestination alloc] initWithFacility:NavDestinationFacilityTypeToiletF]];
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_facility",@"BlindView",@""), @"rows":temp}];
    }
    
    if (_showShops) {
        NSMutableArray __block *temp = [@[] mutableCopy];
        NSString __block *lastFirst = nil;
        [all enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *name = [landmark getLandmarkNamePron];
            
            if (name == nil || [name length] == 0) {
                NSLog(@"no name landmark %@", landmark);
                return;
            }
            
            NSString *first = [[name substringWithRange:NSMakeRange(0, 1)] uppercaseString];
            NSMutableString* retStr = [[NSMutableString alloc] initWithString:first];
            CFStringTransform((CFMutableStringRef)retStr, NULL, kCFStringTransformHiraganaKatakana, YES);
            first = retStr;
            
            if (![first isEqualToString:lastFirst]) {
                temp = [@[] mutableCopy];
                [tempSections addObject:@{@"key":first, @"rows":temp}];
            }
            [temp addObject:[[NavDestination alloc] initWithLandmark:landmark]];
            lastFirst = first;
        }];
    }
    
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
    if (_showSectionIndex) {
        NSMutableArray *titles = [@[] mutableCopy];
        [sections enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [titles addObject:obj[@"key"]];
        }];
        return titles;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [sections objectAtIndex:section][@"key"];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"NavDestinationDataSourceCell";
    //UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    cell.textLabel.minimumScaleFactor = 0.5;
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByClipping;
    cell.detailTextLabel.minimumScaleFactor = 0.5;
    
    NavDestination *dest = [self destinationForRowAtIndexPath:indexPath];
    NSString *floor = @"";
    if (_showShopFloor && dest.landmark) {
        if (_showShopBuilding && dest.landmark.properties[@"building"]) {
            floor = dest.landmark.properties[@"building"];
            floor = [floor stringByAppendingString:@" "];
        }
        floor = [floor stringByAppendingString:[self floorString:dest.landmark.nodeHeight]];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (dest.filter) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.textLabel.text = dest.name;
    cell.detailTextLabel.text = floor;
    cell.accessibilityLabel = dest.namePron;
    cell.clipsToBounds = YES;
    return cell;
}

- (NSString*) floorString:(double) floor
{
    floor = round(floor*2.0)/2.0;
    
    floor = (floor >= 0)?floor+1:floor;
        
    if (floor < 0) {
        return [NSString stringWithFormat:@"B%dF", (int)fabs(floor)];
    } else {
        return [NSString stringWithFormat:@"%dF", (int)fabs(floor)];
    }
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
    cell.textLabel.accessibilityLabel = to.namePron;
    
    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), from.name];
    cell.detailTextLabel.accessibilityLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), from.namePron];
    
    return cell;
}

-(NSDictionary *)historyAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *hist = [[NavDataStore sharedDataStore] searchHistory];
    
    return [hist objectAtIndex:indexPath.row];
}

@end
