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


#import <UIKit/UIKit.h>
#import "NavDataStore.h"
#import "HLPDataUtil.h"
#import "HLPGeoJSON.h"
#import "LocationEvent.h"
#import "Logging.h"


@implementation NavDataStore {
    // location instance that keep the current status should be handled
    HLPLocation *location;
    
    // parameters passed from location manager and manual operations
    BOOL isManualLocation;
    HLPLocation *manualCurrentLocation;
    HLPLocation *currentLocation;
    double magneticOrientation;
    double magneticOrientationAccuracy;
    BOOL _previewMode;
    
    double manualOrientation;
    
    // parameters for request
    NSString* userID;
    NSString* userLanguage;
    
    // cached data
    NSArray* destinationCache;
    BOOL destinationRequesting;
    NSArray* routeCache;
    NSArray* featuresCache;
    
    NSDictionary *destinationHash;
    
}

static NavDataStore* instance_ = nil;

+ (instancetype)sharedDataStore{
    if (!instance_) {
        instance_ = [[NavDataStore alloc] init];
    }
    return instance_;
}

- (instancetype) init
{
    self = [super init];
    
    [self reset];
    
    userID = [UIDevice currentDevice].identifierForVendor.UUIDString;
    
    userLanguage = [[[NSLocale preferredLanguages] objectAtIndex:0] substringToIndex:2];
    
    // prevent problem on server cache
    userID = [NSString stringWithFormat:@"%@:%@", userID, userLanguage];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:ORIENTATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocationChanged:) name:MANUAL_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processShowRouteLog:) name:REQUEST_PROCESS_SHOW_ROUTE_LOG object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processInitTargetLog:) name:REQUEST_PROCESS_INIT_TARGET_LOG object:nil];

    return self;
}

- (void) reset
{
    isManualLocation = NO;
    destinationRequesting = NO;
    
    magneticOrientationAccuracy = 180;
    
    location = [[HLPLocation alloc] init];
    [location updateOrientation:0 withAccuracy:999];
    currentLocation = [[HLPLocation alloc] init];
    [currentLocation updateOrientation:0 withAccuracy:999];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    if ([ud valueForKey:@"lastLat"]) {
        double lng = [ud doubleForKey:@"lastLng"];
        while(lng > 180) {
            lng -= 360;
        }
        [currentLocation updateLat:[ud doubleForKey:@"lastLat"] Lng:lng Accuracy:0 Floor:[ud doubleForKey:@"lastFloor"]];
    }
}


- (void) locationChanged: (NSNotification*) notification
{
    if (_previewMode) {
        return;
    }
    
    NSDictionary *obj = [notification object];
    
    currentLocation = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                                   Lng:[obj[@"lng"] doubleValue]
                                              Accuracy:[obj[@"accuracy"] doubleValue]
                                                 Floor:[obj[@"floor"] doubleValue]
                                                 Speed:[obj[@"speed"] doubleValue]
                                           Orientation:[obj[@"orientation"] doubleValue]
                                   OrientationAccuracy:[obj[@"orientationAccuracy"] doubleValue]];
    
    if (obj[@"debug_info"] || obj[@"debug_latlng"]) {
        [currentLocation updateParams:obj];
    }
    
    if (!isManualLocation) {
        [self postLocationNotification];
    }
}

-(void) saveLocation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
            HLPLocation *loc = [self currentLocation];
            [ud setObject:@(loc.lat) forKey:@"lastLat"];
            [ud setObject:@(loc.lng) forKey:@"lastLng"];
            [ud setObject:@(loc.floor) forKey:@"lastFloor"];
            [ud synchronize];
        }@catch(NSException *e) {
            NSLog(@"%@", [e debugDescription]);
        }
    });
}

-(void) postLocationNotification
{
    HLPLocation *loc = [self currentLocation];
    if (loc && [Logging isLogging]) {
        long now = (long)([[NSDate date] timeIntervalSince1970]*1000);
        NSLog(@"Pose,%f,%f,%f,%f,%f,%f,%ld",loc.lat,loc.lng,loc.floor,loc.accuracy,loc.orientation,loc.orientationAccuracy,now);
    }
    [[NSNotificationCenter defaultCenter]
     postNotificationName:NAV_LOCATION_CHANGED_NOTIFICATION
     object:
     @{
       @"current":loc?loc:[NSNull null],
       @"isManual":@(isManualLocation),
       @"actual":(isnan(currentLocation.lat)||isnan(currentLocation.lng))?[NSNull null]:currentLocation
       }];
}

- (void) orientationChanged: (NSNotification*) notification
{
    if (_previewMode) {
        return;
    }
    NSDictionary *obj = [notification object];
    
    magneticOrientation = [obj[@"orientation"] doubleValue];
    magneticOrientationAccuracy = [obj[@"orientationAccuracy"] doubleValue];
    
    [self postLocationNotification];
}

- (void) manualLocationChanged: (NSNotification*) notification
{
    if (_previewMode) {
        return;
    }
    
    NSDictionary *obj = [notification object];
    double floor = [obj[@"floor"] doubleValue];
    if (floor >= 1) {
        floor -= 1;
    }
    if ([[notification object][@"sync"] boolValue]) {
        isManualLocation = NO;
        manualCurrentLocation = nil;
    } else {
        isManualLocation = YES;
        manualCurrentLocation = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                                             Lng:[obj[@"lng"] doubleValue]
                                                        Accuracy:1
                                                           Floor:floor
                                                           Speed:0
                                                     Orientation:0
                                             OrientationAccuracy:999];

        [self postLocationNotification];
    }
}

- (HLPLocation*) currentLocation
{
    if (isnan(currentLocation.lat) && isnan(manualCurrentLocation.lat)) {
        return nil;
    }
    
    [location update:currentLocation];
    
    if (manualCurrentLocation) {
        [location updateLat:manualCurrentLocation.lat
                        Lng:manualCurrentLocation.lng
                   Accuracy:manualCurrentLocation.accuracy
                      Floor:manualCurrentLocation.floor];
        [location updateOrientation:manualOrientation
                       withAccuracy:0];
    } else {
        if (magneticOrientationAccuracy < location.orientationAccuracy) {
            [location updateOrientation:magneticOrientation
                           withAccuracy:magneticOrientationAccuracy];
        }
    }
    
    if (isnan(location.lat) || isnan(location.lng)) {
        return nil;
    }
    
    
    HLPLocation *newLoc = [[HLPLocation alloc] init];
    [newLoc update:location];
    return newLoc;
    
    //return location;
}

- (NSArray *)route
{
    return routeCache;
}

- (NSArray *)features
{
    return featuresCache;
}

- (void)processInitTargetLog:(NSNotification*)notification
{
    NSString *logstr = [notification object];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    double lat = [param[@"lat"] doubleValue];
    double lng = [param[@"lng"] doubleValue];
    NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:lang];
}

- (void)processShowRouteLog:(NSNotification*)notification
{
    NSString *logstr = [notification object];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSString *fromID = param[@"fromID"];
    NSString *toID = param[@"toID"];
    NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    NSDictionary *prefs = param[@"prefs"];
    [self requestRouteFrom:fromID To:toID forUser:user withLang:lang withPreferences:prefs complete:nil];
}


- (void)reloadDestinations
{
    if (destinationRequesting) {
        return;
    }
    destinationRequesting = YES;
    double lat = [self currentLocation].lat;
    double lng = [self currentLocation].lng;
    
    NSString *user = [self userID];
    NSString *user_lang = [self userLanguage];
    
    [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:user_lang];
}

- (void)reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang
{
    int dist = 500;
    NSDictionary *param = @{@"lat":@(lat), @"lng":@(lng), @"user":user, @"user_lang":user_lang};
    [Logging logType:@"initTarget" withParam:param];
    
    [HLPDataUtil loadLandmarksAtLat:lat Lng:lng inDist:dist forUser:user withLang:user_lang withCallback:^(NSArray<HLPObject *> *result) {
        //NSLog(@"%ld landmarks are loaded", (unsigned long)[result count]);
        destinationCache = [result sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *obj1, HLPLandmark *obj2) {
            return [[[obj1 getLandmarkName] lowercaseString] compare:[[obj2 getLandmarkName] lowercaseString]];
        }];
        
        destinationCache = [destinationCache filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLandmark *evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return ![evaluatedObject isToilet];
        }]];
        
        NSMutableDictionary *temp = [@{} mutableCopy];
        [destinationCache enumerateObjectsUsingBlock:^(HLPLandmark *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            temp[[obj nodeID]] = obj;
        }];
        destinationHash = temp;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:destinationCache];
        });

        destinationRequesting = NO;
    }];
}

- (void) saveHistory
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *history = [[NSUserDefaults standardUserDefaults] arrayForKey:@"searchHistory"];
        if (!history) {
            history = @[];
        }
        
        NSDictionary *newHist =
        @{
          @"fromID":self.fromID,
          @"fromTitle":[self.fromTitle isEqualToString:@"_nav_latlng"]?[self.fromID substringFromIndex:7]:self.fromTitle,
          @"toID":self.toID,
          @"toTitle":[self.toTitle isEqualToString:@"_nav_latlng"]?[self.toID substringFromIndex:7]:self.toTitle,
          };

        BOOL __block flag = YES;
        [newHist enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            flag = flag && [[history firstObject][key] isEqualToString:obj];
        }];
        if (flag) {
            return;
        }
        NSMutableArray *temp = [history mutableCopy];
        [temp insertObject:newHist
                   atIndex:0];
        
        while([temp count] > 100) {
            [temp removeLastObject];
        }
        [[NSUserDefaults standardUserDefaults] setObject:temp forKey:@"searchHistory"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID withPreferences:(NSDictionary *)prefs complete:(void (^)())complete
{
    [self saveHistory];
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:self.userLanguage withPreferences:prefs complete:complete];
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID forUser:(NSString*)user withLang:(NSString*)lang withPreferences:(NSDictionary *)prefs complete:(void (^)())complete
{
    NSDictionary *param = @{@"fromID":fromID, @"toID":toID, @"user":user, @"user_lang":lang, @"prefs":prefs};
    [Logging logType:@"showRoute" withParam:param];

    [HLPDataUtil loadRouteFromNode:fromID toNode:toID forUser:user withLang:lang withPrefs:prefs withCallback:^(NSArray<HLPObject *> *result) {
        routeCache = result;
        [HLPDataUtil loadNodeMapForUser:user WithCallback:^(NSArray<HLPObject *> *result) {
            featuresCache = result;
            [HLPDataUtil loadFeaturesForUser:user WithCallback:^(NSArray<HLPObject *> *result) {
                featuresCache = [featuresCache arrayByAddingObjectsFromArray: result];
                
                if (complete) {
                    complete();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:routeCache];
            }];
        }];
    }];
    
}

- (void)clearRoute
{
    routeCache = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CLEARED_NOTIFICATION object:routeCache];
}

- (NSArray*)destinations
{
    return destinationCache;
}


- (NSString*) userID
{
    return userID;
}

- (NSString*) userLanguage
{
    return userLanguage;
}

- (NSArray*) searchHistory
{
    NSArray *hist = [[NSUserDefaults standardUserDefaults] arrayForKey:@"searchHistory"];
    if (!hist) {
        hist = @[];
    }
    return hist;
}

- (void)switchFromTo
{
    NSString *tempID = _fromID;
    NSString *tempTitle = _fromTitle;
    _fromID = _toID;
    _fromTitle = _toTitle;
    _toID = tempID;
    _toTitle = tempTitle;
}

- (HLPLandmark*)destinationByID:(NSString *)key
{
    return [destinationHash objectForKey:key];
}

- (void)manualTurn:(double)diffOrientation
{
    if (_previewMode) {
        [currentLocation updateOrientation:currentLocation.orientation+diffOrientation withAccuracy:-1];
        [self postLocationNotification];
    }
    else {
        manualOrientation += diffOrientation;
        magneticOrientationAccuracy = 0;
        [self postLocationNotification];
    }
}

- (void)manualLocation:(HLPLocation *)loc
{
    if (loc == nil) {
        [self postLocationNotification];
    }
    else {
        if (_previewMode) {
            [currentLocation updateLat:loc.lat Lng:loc.lng Accuracy:1.0 Floor:loc.floor];
            [self postLocationNotification];
        }
    }
}

- (void)manualLocationReset:(NSDictionary *)properties
{
    if (_previewMode) {
        HLPLocation *loc = properties[@"location"];
        [loc updateLat:loc.lat Lng:loc.lng Accuracy:1.5 Floor:loc.floor];
        double heading = [properties[@"heading"] doubleValue];
        manualOrientation = heading;
        [loc updateOrientation:heading withAccuracy:-1];
        [currentLocation update:loc];
        [self postLocationNotification];
    }
}

- (void)clearSearchHistory
{
    [[NSUserDefaults standardUserDefaults] setObject:@[] forKey:@"searchHistory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString*) idForCurrentLocation
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    double floor = round(nds.currentLocation.floor);
    floor = (floor >=0)?floor+1:floor;
    NSString *ret = [NSString stringWithFormat:@"latlng:%f:%f:%d", nds.currentLocation.lat, nds.currentLocation.lng, (int)floor];
    return ret;
}

- (void)setPreviewMode:(BOOL)previewMode
{
    _previewMode = previewMode;
    if (_previewMode) {
    } else {
        [currentLocation updateOrientation:currentLocation.orientation withAccuracy:1];
    }
}

- (BOOL)previewMode
{
    return _previewMode;
}

@end

#pragma mark - Destination Data Source

@implementation NavDestinationDataSource {
    NSArray *sections;
    BOOL _showCurrentLocation;
    BOOL _showToilet;
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

- (BOOL) showToilet
{
    return _showToilet;
}

- (void) setShowToilet:(BOOL) flag
{
    _showToilet = flag;
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
        [temp addObject:@{
                          @"name": @"_nav_latlng",
                          @"id": @"_nav_latlng"
                          }];
        
        [tempSections addObject:@{@"key":@"◎", @"rows":temp}];
    }
    if (_showToilet) {
        NSMutableArray *temp = [@[] mutableCopy];
        [temp addObject:@{@"name":@"_nav_toilet_male",@"id":@"_nav_toilet_male"}];
        [temp addObject:@{@"name":@"_nav_toilet_female",@"id":@"_nav_toilet_female"}];
        [temp addObject:@{@"name":@"_nav_toilet_multi",@"id":@"_nav_toilet_multi"}];
        [tempSections addObject:@{@"key":@"🚻", @"rows":temp}];
    }
    NSMutableArray __block *temp = [@[] mutableCopy];
    NSString __block *lastFirst = nil;
    [all enumerateObjectsUsingBlock:^(HLPLandmark *landmark, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [landmark getLandmarkName];
        NSString *first = [[name substringWithRange:NSMakeRange(0, 1)] lowercaseString];
        
        if (![first isEqualToString:lastFirst]) {
            temp = [@[] mutableCopy];
            [tempSections addObject:@{@"key":first, @"rows":temp}];
        }
        [temp addObject:@{
                          @"name": name,
                          @"id": [landmark nodeID],
                          @"obj": landmark,
                          }];
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

- (NSString*) idForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *ret = [[sections objectAtIndex:indexPath.section][@"rows"] objectAtIndex:indexPath.row][@"id"];
    
    if ([ret isEqualToString:@"_nav_latlng"]) {
        ret = [NavDataStore idForCurrentLocation];
    }
    return ret;
}

- (NSString *)titleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [[sections objectAtIndex:indexPath.section][@"rows"] objectAtIndex:indexPath.row][@"name"];
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
    cell.textLabel.text = [[sections objectAtIndex:indexPath.section][@"rows"] objectAtIndex:indexPath.row][@"name"];
    
    cell.clipsToBounds = YES;
    return cell;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    NSInteger count = [[[NavDataStore sharedDataStore] destinations] count] + (_showCurrentLocation?1:0);
    
    return count;
}


-(NSString*) titleForRow:(NSInteger)row
{
    long index = row;
    if (_showCurrentLocation) {
        index--;
    }
    if (index < 0) {
        return @"_nav_latlng";
    } else {
        HLPLandmark *landmark = [[[NavDataStore sharedDataStore] destinations] objectAtIndex:index];
        
        return [landmark getLandmarkName];
    }
}

-(NSString*) idForRow:(NSInteger)row
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    long index = row;
    if (_showCurrentLocation) {
        index--;
    }
    if (index < 0) {
        return [NavDataStore idForCurrentLocation];
    } else {
        HLPLandmark *landmark = [[nds destinations] objectAtIndex:index];
        
        return [landmark nodeID];
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
    
    NSString *from = [[[NavDataStore sharedDataStore] destinationByID:dic[@"fromID"]] getLandmarkName];
    NSString *to = [[[NavDataStore sharedDataStore] destinationByID:dic[@"toID"]] getLandmarkName];
    if (!from) { from = dic[@"fromTitle"]; }
    if (!to) { to = dic[@"toTitle"]; }
    
    
    /*
    int max = 24;
    if ([from length] > max) {
        from = [[from substringWithRange:NSMakeRange(0, max-1)] stringByAppendingString:@".."];
    }
    if ([to length] > max) {
        to = [[to substringWithRange:NSMakeRange(0, max-1)] stringByAppendingString:@".."];
    }*/
    
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.lineBreakMode = NSLineBreakByClipping;
    cell.textLabel.text = to;
    cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedStringFromTable(@"from: %@", @"BlindView", @""), from];
    
    return cell;
}

-(NSDictionary *)historyAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *hist = [[NavDataStore sharedDataStore] searchHistory];
    
    return [hist objectAtIndex:indexPath.row];
}

@end
