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

@implementation NavDestination {
    NSString *_facilityType;
    HLPLandmark *_landmark;
    HLPLocation *_location;
}

- (BOOL) isEqual:(NavDestination*)obj
{
    if (_type != obj.type) {
        return NO;
    }
    
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark isEqual:obj->_landmark];
        case NavDestinationTypeLocation:
            return [_location isEqual:obj->_location];
        case NavDestinationTypeFacility:
            return [_facilityType isEqualToString:obj->_facilityType];
        default:
            break;
    }
    return NO;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithInt:_type] forKey:@"type"];
    HLPLocation *loc;
    switch(_type) {
        case NavDestinationTypeLandmark:
            [aCoder encodeObject:_landmark forKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] currentLocation];
            } else {
                loc = _location;
            }
            [aCoder encodeObject:loc forKey:@"location"];
            break;
        case NavDestinationTypeFacility:
            [aCoder encodeObject:_facilityType forKey:@"facilityType"];
            break;
        default:
            break;
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    _type = [[aDecoder decodeObjectForKey:@"type"] intValue];
    switch(_type) {
        case NavDestinationTypeLandmark:
            _landmark = [aDecoder decodeObjectForKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            _location = [aDecoder decodeObjectForKey:@"location"];
            break;
        case NavDestinationTypeFacility:
            _facilityType = [aDecoder decodeObjectForKey:@"facilityType"];
            break;
        default:
            break;
    }
    return self;
}

- (instancetype)initWithFacility:(NSString *)facilityType
{
    self = [super init];
    _type = NavDestinationTypeFacility;
    _facilityType = facilityType;
    return self;
}

- (instancetype)initWithLocation:(HLPLocation *)location
{
    self = [super init];
    _type = NavDestinationTypeLocation;
    _location = location;
    return self;
}

- (instancetype)initWithLandmark:(HLPLandmark *)landmark
{
    self = [super init];
    _type = NavDestinationTypeLandmark;
    _landmark = landmark;
    return self;
}

+ (instancetype)selectStart
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeSelectStart;
    return ret;
}

+ (instancetype)selectDestination
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeSelectDestination;
    return ret;
}


- (NSString*)_id
{
    HLPLocation *loc;
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark nodeID];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] currentLocation];
            } else {
                loc = _location;
            }
            return [NSString stringWithFormat:@"latlng:%f:%f:%d", loc.lat, loc.lng, (int)loc.floor];
        case NavDestinationTypeFacility:
            //TODO
            return @"";
        default:
            return nil;
    }
}

- (NSString*)name
{
    HLPLocation *loc;
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark getLandmarkName];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] currentLocation];
            } else {
                loc = _location;
            }
            return [NSString stringWithFormat:@"%@(%f,%f,%d)",
                    NSLocalizedStringFromTable(@"_nav_latlng", @"BlindView", @""),loc.lat,loc.lng,(int)loc.floor];
        case NavDestinationTypeFacility:
            //TODO
            return @"";
        case NavDestinationTypeSelectStart:
            return NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
        case NavDestinationTypeSelectDestination:
            return NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
    }
    return nil;
}

- (NSString*)namePron
{
    switch(_type) {
        case NavDestinationTypeLandmark:
            return [_landmark getLandmarkNamePron];
        default:
            return [self name];
    }
    return nil;
}
@end

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
    NSDictionary *obj = [notification object];
    double floor = [obj[@"floor"] doubleValue];
    if (floor >= 1) {
        floor -= 1;
    }
    if ([[notification object][@"sync"] boolValue]) {
        isManualLocation = NO;
        manualCurrentLocation = nil;
    } else {
        if (_previewMode) {
            return;
        }
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
            return [[[obj1 getLandmarkNamePron] lowercaseString] compare:[[obj2 getLandmarkNamePron] lowercaseString]];
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
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];

    NSArray *history = @[];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        history = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    
    NSDictionary *newHist = @{
                              @"from":[NSKeyedArchiver archivedDataWithRootObject:_from],
                              @"to":[NSKeyedArchiver archivedDataWithRootObject:_to]};
    
    
    if ([history count] > 0) {
        BOOL __block flag = YES;
        [newHist enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            
            NavDestination *dest1 = [NSKeyedUnarchiver unarchiveObjectWithData:[history firstObject][key]];
            NavDestination *dest2 = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
            
            flag = flag && [dest1 isEqual:dest2];
        }];
        if (flag) {
            return;
        }
    }
    NSMutableArray *temp = [history mutableCopy];
    [temp insertObject:newHist
               atIndex:0];
    
    while([temp count] > 100) {
        [temp removeLastObject];
    }
    [NSKeyedArchiver archiveRootObject:temp toFile:path];
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
                
                for(HLPObject* f in featuresCache) {
                    [f updateWithLang:lang];
                }
                
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
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];
    
    NSArray *history = @[];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        history = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }

    return history;
}

- (void)switchFromTo
{
    NavDestination *temp = _from;
    _from = _to;
    _to = temp;
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
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:@"history.object"];

    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+ (NavDestination*) destinationForCurrentLocation;
{
    return [[NavDestination alloc] initWithLocation:nil];
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
