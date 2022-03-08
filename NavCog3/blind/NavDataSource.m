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
#import <FormatterKit/TTTOrdinalNumberFormatter.h>

#pragma mark - Destination Data Source


@implementation NavTableDataSource
- (NavDestination*) destinationForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    [self doesNotRecognizeSelector:_cmd];
    return 0;
}
@end

@implementation NavDirectoryDataSource {
    HLPDirectory *_original;
    HLPDirectory *_directory;
}

- (instancetype) init {
    self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    return self;
}

- (instancetype)initWithDirectory:(HLPDirectory *)directory
{
    self = [super init];
    self.directory = directory;
    return self;
}

- (void) setDirectory:(HLPDirectory *)directory
{
    _original = directory;
    _directory = directory.copy;
}

- (HLPDirectory*) directory
{
    return _directory;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) update:(NSNotification*)note {
    _directory = _original.copy;
    
    if (_showDialog) {
        HLPDirectorySection *section = [[HLPDirectorySection alloc] init];
        section.title = NSLocalizedStringFromTable(@"DialogSearch",@"BlindView",@"");
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[NavDestination dialogSearch]];
        section.items = temp;
        [_directory addSection:section atIndex:0];
    }
    
    if (_showCurrentLocation) {
        HLPDirectorySection *section = [[HLPDirectorySection alloc] init];
        section.title = NSLocalizedStringFromTable(@"_nav_latlng",@"BlindView",@"");
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithLocation:nil]];
        section.items = temp;
        [_directory addSection:section atIndex:0];
    }
    
    if (!_showFacility) {
        NSMutableArray *temp = [@[] mutableCopy];
        for(HLPDirectorySection *section in _directory.sections) {
            NSMutableArray *temp2 = [@[] mutableCopy];
            [section walk:^BOOL(HLPDirectoryItem *item) {
                return item.isFacility;
            } withBuffer:temp2];
            if (temp2.count == 0) {
                [temp addObject:section];
            }
        }
        _directory.sections = temp;
    }
}

- (NSString*)firstLetter:(NSString*)string
{
    if (!string) return @"";
    NSString *first = [[string substringWithRange:NSMakeRange(0, 1)] uppercaseString];
    NSMutableString* retStr = [[NSMutableString alloc] initWithString:first];
    CFStringTransform((CFMutableStringRef)retStr, NULL, kCFStringTransformHiraganaKatakana, YES);
    first = retStr;
    return first;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _directory.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _directory.sections[section].items.count;
}

- (HLPDirectoryItem*) itemForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return _directory.sections[indexPath.section].items[indexPath.row];
}

- (NavDestination*) destinationForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HLPDirectoryItem *item = [self itemForRowAtIndexPath:indexPath];
    if ([item isKindOfClass:HLPDirectoryItem.class]) {
        return [[NavDestination alloc] initWithDirectoryItem:item];
    }
    return nil;
}

- (NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSMutableArray *titles = [@[] mutableCopy];
    
    if (_directory.showSectionIndex) {    
        [_directory.sections enumerateObjectsUsingBlock:^(HLPDirectorySection*  _Nonnull section, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *index = section.indexTitle ? section.indexTitle : [self firstLetter:section.title];
            [titles addObject:index];
        }];
    }
    return titles;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _directory.sections[section].title;
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
    cell.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByClipping;
    cell.detailTextLabel.minimumScaleFactor = 0.5;
    cell.detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    HLPDirectoryItem *item = [self itemForRowAtIndexPath:indexPath];
    NavDestination *dest = [self destinationForRowAtIndexPath:indexPath];

    cell.accessoryType = UITableViewCellAccessoryNone;
    if (dest.filter) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    if ([item isKindOfClass:HLPDirectoryItem.class]) {
        cell.textLabel.text = [item getItemTitle];
        cell.detailTextLabel.text = item.subtitle;
        if (item.subtitle) {
            cell.accessibilityLabel = [NSString stringWithFormat:@"%@ %@ %@",
                                       [item getItemTitlePron],NSLocalizedStringFromTable(@"PERIOD",@"BlindView",@""),[item getItemSubtitlePron]];
        } else {
            cell.accessibilityLabel = [NSString stringWithFormat:@"%@", [item getItemTitlePron]];
        }
        if (item.content) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        cell.textLabel.text = dest.name;
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@", dest.namePron];
        
        if (dest.type == NavDestinationTypeDialogSearch) {
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    cell.clipsToBounds = YES;
    
    
    return cell;
}
@end

@implementation NavDestinationDataSource {
    NSArray *sections;
}

- (instancetype) init {
    self = [super init];
    _defaultFilter = @{};
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) update:(NSNotification*)note {
    if (!_filter) {
        _filter = _defaultFilter;
    } else {
        _filter = [_filter mtl_dictionaryByAddingEntriesFromDictionary:_defaultFilter];
    }
    
    NSArray *all = [[[NavDataStore sharedDataStore] destinations] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLandmark *landmark, NSDictionary<NSString *,id> * _Nullable bindings) {
        BOOL flag = YES;
        if (self->_filter) {
            for(NSString *key in self->_filter.allKeys) {
                if ([[NSNull null] isEqual:self->_filter[key]]) {
                    flag = flag && landmark.properties[key] == nil;
                } else if ([self->_filter[key] isKindOfClass:NSDictionary.class]) {
                    NSDictionary *filter = self->_filter[key];
                    if (filter[@"$not"]) {
                        flag = flag && ![landmark.properties[key] isEqual:filter[@"$not"]];
                    }
                    if (filter[@"$not_contains"]) {
                        flag = flag && ![landmark.properties[key] containsString:filter[@"$not_contains"]];
                    }
                } else if ([self->_filter[key] isKindOfClass:NSString.class]) {
                    flag = flag && ([self->_filter[key] isEqualToString:landmark.properties[key]] ||
                                    ([self->_filter[key] isEqualToString:@""] &&
                                     landmark.properties[key] == nil));
                } else {
                    flag = flag && [landmark.properties[key] isEqual:self->_filter[key]];
                }
            }
        }
        return flag;
    }]];
    
    NSArray *shops = [all filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isFacility = NO"]];
    NSArray *facilities = [all filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isFacility = YES"]];
    facilities = [facilities sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *l1, HLPLandmark *l2) {
        NSString*(^sortName)(HLPLandmark*) = ^(HLPLandmark *l) {
            if (l.isToilet) {
                return @"AAA";
            }
            if (l.properties[@"sub_category"]) {
                return (NSString*)l.properties[@"sub_category"];
            }
            return @"ZZZ";
        };
        NSString *n1 = sortName(l1);
        NSString *n2 = sortName(l2);
        return [n1 compare:n2];
    }];
    
    NSMutableArray *tempSections = [@[] mutableCopy];
    
    if (_showDialog) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[NavDestination dialogSearch]];
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"DialogSearch",@"BlindView",@""), @"rows":temp}];        
    }
    
    if (_showCurrentLocation) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:[[NavDestination alloc] initWithLocation:nil]];
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_latlng",@"BlindView",@""), @"rows":temp}];
    }
    
    if (_showNearShops) {
        NSMutableArray *temp = [@[] mutableCopy];
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        [[shops sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *obj1, HLPLandmark *obj2) {
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
        [shops enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
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
        if ([buildings count] > 1) {
            [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_building",@"BlindView",@""), @"rows":temp}];
            
            if (noBuilding) {
                [temp addObject:[[NavDestination alloc] initWithLabel:NSLocalizedStringFromTable(@"Others", @"BlindView", @"") Filter:@{@"building":[NSNull null]}]];
            }
        } else {
            if (noBuilding || [buildings count] == 1) {
                _showBuilding = NO;
                _showShops = YES;
                _showSectionIndex = YES;
            }
        }
    }
    
    if (_showFacility) {
        NSMutableArray __block *temp = [@[] mutableCopy];
        NSMutableDictionary<NSString*,NavDestination*> __block *nameMap = [@{} mutableCopy];
        [facilities enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *name = [landmark getLandmarkNamePron];
            
            if (name == nil || [name length] == 0) {
                NSLog(@"no name landmark %@", landmark);
                return;
            }
            
            if (nameMap[name]) {
                [nameMap[name] addLandmark:landmark];
                return;
            }
            
            NavDestination *dest = [[NavDestination alloc] initWithLandmark:landmark];
            [temp addObject:dest];
            nameMap[name] = dest;
        }];
        
        [tempSections addObject:@{@"key":NSLocalizedStringFromTable(@"_nav_facility",@"BlindView",@""), @"rows":temp}];
    }
    
    if (_showShops) {
        NSMutableArray __block *temp = [@[] mutableCopy];
        NSString __block *lastFirst = nil;
        NSMutableDictionary<NSString*,NavDestination*> __block *nameMap = [@{} mutableCopy];
        [shops enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *name = [landmark getLandmarkNamePron];
            
            if (name == nil || [name length] == 0) {
                NSLog(@"no name landmark %@", landmark);
                return;
            }
            
            if (nameMap[name]) {
                [nameMap[name] addLandmark:landmark];
                return;
            }
            
            NSString *first = [self firstLetter:name];
            
            if (![first isEqualToString:lastFirst]) {
                temp = [@[] mutableCopy];
                [tempSections addObject:@{@"key":first, @"rows":temp}];
            }
            NavDestination *dest = [[NavDestination alloc] initWithLandmark:landmark];
            [temp addObject:dest];
            nameMap[name] = dest;
            lastFirst = first;
        }];
    }
    
    sections = tempSections;
}

- (NSString*)firstLetter:(NSString*)string
{
    NSString *first = [[string substringWithRange:NSMakeRange(0, 1)] uppercaseString];
    NSMutableString* retStr = [[NSMutableString alloc] initWithString:first];
    CFStringTransform((CFMutableStringRef)retStr, NULL, kCFStringTransformHiraganaKatakana, YES);
    first = retStr;
    return first;
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
            [titles addObject:[self firstLetter:obj[@"key"]]];
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
    cell.textLabel.translatesAutoresizingMaskIntoConstraints = NO;
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.adjustsFontSizeToFitWidth = YES;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByClipping;
    cell.detailTextLabel.minimumScaleFactor = 0.5;
    cell.detailTextLabel.translatesAutoresizingMaskIntoConstraints = NO;
    /*
    NSArray *c = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[textLabel(<=280)]-(>=2)-[detailTextLabel]-|"
                                                                    options:0
                                                                    metrics:@{@"space": @(10)}
                                                                      views:@{@"textLabel": cell.textLabel,
                                                                              @"detailTextLabel": cell.detailTextLabel}];
    [cell.contentView addConstraints:c];
    NSLayoutConstraint *lc = [NSLayoutConstraint constraintWithItem:cell.textLabel
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:cell.contentView
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.f constant:0.f];
    [cell.contentView addConstraint:lc];
    lc = [NSLayoutConstraint constraintWithItem:cell.detailTextLabel
                                     attribute:NSLayoutAttributeCenterY
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:cell.contentView
                                     attribute:NSLayoutAttributeCenterY
                                    multiplier:1.f constant:0.f];
    [cell.contentView addConstraint:lc];
     */
    
    NavDestination *dest = [self destinationForRowAtIndexPath:indexPath];
    NSString *floor = @"";
    NSString *floorPron = @"";
    if (_showShopFloor && dest.landmark && !dest.landmark.isFacility) {
        if (_showShopBuilding && dest.landmark.properties[@"building"]) {
            floorPron = floor = dest.landmark.properties[@"building"];
            floor = [floor stringByAppendingString:@" "];
            floorPron = [floorPron stringByAppendingString:@" "];
        }
        floor = [floor stringByAppendingString:[self floorString:dest.landmark]];
        floorPron = [floorPron stringByAppendingString:[self floorStringPron:dest.landmark]];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (dest.filter) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (dest.type == NavDestinationTypeDialogSearch) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.textLabel.text = dest.name;
    cell.detailTextLabel.text = floor;
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@ %@ %@",
                               dest.namePron,NSLocalizedStringFromTable(@"PERIOD",@"BlindView",@""),floorPron];
    cell.clipsToBounds = YES;
    return cell;
}

- (NSString*) floorString:(HLPLandmark*) landmark
{
    double floor = landmark.nodeHeight;
    floor = round(floor*2.0)/2.0;
    
    floor = (floor >= 0)?floor+1:floor;
    
    if (landmark.isGround) {
        return @"G";
    } else if (floor < 0) {
        return [NSString stringWithFormat:@"B%dF", (int)fabs(floor)];
    } else {
        return [NSString stringWithFormat:@"%dF", (int)fabs(floor)];
    }
}

- (NSString*) floorStringPron:(HLPLandmark*) landmark
{
    double floor = landmark.nodeHeight;
    NSString *type = NSLocalizedStringFromTable(@"FloorNumType", @"BlindView", @"floor num type");
    
    if (landmark.isGround) {
        return NSLocalizedStringFromTable(@"ground floor", @"BlindView", @"");
    }
    else if ([type isEqualToString:@"ordinal"]) {
        TTTOrdinalNumberFormatter*ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
        
        NSString *localeStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleLocale"];
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:localeStr];
        [ordinalNumberFormatter setLocale:locale];
        [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
        
        floor = round(floor*2.0)/2.0;
        
        if (floor < 0) {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(fabs(floor))];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), ordinalNumber];
        } else {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(floor+1)];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), ordinalNumber];
        }
    } else {
        floor = round(floor*2.0)/2.0;
        
        if (landmark.isGround) {
            return NSLocalizedStringFromTable(@"ground floor", @"BlindView", @"");
        }
        else if (floor < 0) {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), @(fabs(floor))];
        } else {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), @(floor+1)];
        }
    }
}

@end

@implementation NavSearchHistoryDataSource {
}

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
    NSArray<NavHistory*> *histories = [[NavDataStore sharedDataStore] searchHistory];
    NavHistory *history = histories[indexPath.row];

    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    cell.textLabel.text = history.to.name;
    cell.textLabel.accessibilityLabel = history.isKnown?history.to.namePron:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Disabled", @"BlindView", @""), history.to.namePron];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), history.from.name];
    cell.detailTextLabel.accessibilityLabel = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), history.from.namePron];
    
    cell.contentView.layer.opacity = history.isKnown?1.0:0.5;
    
    return cell;
}

-(NavHistory *)historyAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray<NavHistory*> *histories = [[NavDataStore sharedDataStore] searchHistory];
    return [histories objectAtIndex:indexPath.row];
}

@end
