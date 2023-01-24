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


#import "NavDataStore.h"
#import "HLPDataUtil.h"
#import "HLPGeoJSON.h"
#import "LocationEvent.h"
#import "Logging.h"
#import "ServerConfig.h"
#import "NavUtil.h"

#import <GameplayKit/GameplayKit.h>
#import <MapKit/MapKit.h>

@implementation NavDestination {
    HLPLocation *_location;
    HLPDirectoryItem *_item;
}

- (BOOL) isEqual:(NavDestination*)obj
{
    if (_type != obj.type) {
        return NO;
    }
    
    switch(_type) {
        case NavDestinationTypeDirectoryItem:
            return [_item isEqual:obj->_item];
        case NavDestinationTypeLandmark:
            return [_landmark isEqual:obj->_landmark];
        case NavDestinationTypeLandmarks:
            return [_landmarks isEqualToArray:obj->_landmarks];
        case NavDestinationTypeLocation:
            return [_location isEqual:obj->_location];
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
        case NavDestinationTypeDirectoryItem:
            [aCoder encodeObject:_item forKey:@"item"];
            break;
        case NavDestinationTypeLandmarks:
            [aCoder encodeObject:_landmarks forKey:@"landmarks"];
        case NavDestinationTypeLandmark:
            [aCoder encodeObject:_landmark forKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
            } else {
                loc = _location;
            }
            [aCoder encodeObject:loc forKey:@"location"];
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
        case NavDestinationTypeDirectoryItem:
            _item = [aDecoder decodeObjectForKey:@"item"];
            break;
        case NavDestinationTypeLandmarks:
            _landmarks = [aDecoder decodeObjectForKey:@"landmarks"];
        case NavDestinationTypeLandmark:
            _landmark = [aDecoder decodeObjectForKey:@"landmark"];
            break;
        case NavDestinationTypeLocation:
            //_location = [aDecoder decodeObjectForKey:@"location"];
            break;
        default:
            break;
    }
    return self;
}

- (instancetype)initWithLocation:(HLPLocation *)location
{
    self = [super init];
    _type = NavDestinationTypeLocation;
    _location = location;
    return self;
}

- (instancetype)initWithDirectoryItem:(HLPDirectoryItem *)item
{
    self = [super init];
    _item = item;
    if (item.content) {
        _type = NavDestinationTypeFilter;
    } else {
        _type = NavDestinationTypeDirectoryItem;
    }
    return self;
}

- (instancetype)initWithLandmark:(HLPLandmark *)landmark
{
    self = [super init];
    _type = NavDestinationTypeLandmark;
    _landmark = landmark;
    return self;
}

- (instancetype)initWithLabel:(NSString*)label Filter:(NSDictionary *)filter
{
    self = [super init];
    _type = NavDestinationTypeFilter;
    _label = label;
    _filter = filter;
    return self;
}
-(void)addLandmark:(HLPLandmark *)landmark
{
    if (!_landmarks) {
        _landmarks = @[_landmark];
        _type = NavDestinationTypeLandmarks;
    }
    _landmarks = [_landmarks arrayByAddingObject:landmark];
}
- (HLPLocation *)location
{
    switch(_type) {
        case NavDestinationTypeDirectoryItem:
            @throw @"Not implemented";
            return nil;
        case NavDestinationTypeLandmark:
            return [_landmark nodeLocation];
        case NavDestinationTypeLandmarks:
            return [[[NavDataStore sharedDataStore] closestDestinationInLandmarks:_landmarks] location];
        case NavDestinationTypeLocation:
            if (_location) {
                return _location;
            } else {
                return [[NavDataStore sharedDataStore] mapCenter];
            }
        default:
            return nil;
    }
}
- (HLPDirectoryItem *)item
{
    return _item;
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

+ (instancetype)dialogSearch
{
    NavDestination *ret = [[NavDestination alloc] init];
    ret->_type = NavDestinationTypeDialogSearch;
    return ret;
}

- (NSString*)_id
{
    HLPLocation *loc;
    int floor;
    NSMutableString* __block temp = [@"" mutableCopy];
    switch(_type) {
        case NavDestinationTypeDirectoryItem:
            return [_item nodeID];
        case NavDestinationTypeLandmark:
            return [_landmark nodeID];
        case NavDestinationTypeLandmarks:
            for(HLPLandmark *l in _landmarks) {
                if ([temp length] > 0) {
                    [temp appendString:@"|"];
                }
                [temp appendString:[l nodeID]];
            }
            return temp;
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
            } else {
                loc = _location;
            }
            floor = (int)round(loc.floor);
            floor = (floor >= 0)?floor+1:floor;
            return [NSString stringWithFormat:@"latlng:%f:%f:%d", loc.lat, loc.lng, floor];
        default:
            return nil;
    }
}


- (NSString*)singleId
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (_type == NavDestinationTypeLandmarks) {
        NavDestination *dest = [nds closestDestinationInLandmarks:_landmarks];
        return dest._id;
    }
    if (_type == NavDestinationTypeDirectoryItem) {
        NSArray *items = [self._id componentsSeparatedByString:@"|"];
        return items[0];
    }
    return self._id;
}

- (NSString*)name
{
    HLPLocation *loc;
    int floor;
    switch(_type) {
        case NavDestinationTypeDirectoryItem:
            if (_item.subtitle) {
                return [NSString stringWithFormat:@"%@, %@", _item.title, _item.subtitle];
            } else {
                return [NSString stringWithFormat:@"%@", _item.title];
            }
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [_landmark getLandmarkName];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                loc = [[NavDataStore sharedDataStore] mapCenter];
                floor = (int)round(loc.floor);
                floor = (floor >= 0)?floor+1:floor;
                return [NSString stringWithFormat:@"%@(%f,%f,%@%dF)",
                        NSLocalizedStringFromTable(@"_nav_latlng", @"BlindView", @""),loc.lat,loc.lng,floor<0?@"B":@"",abs(floor)];
            } else {
                loc = _location;
                floor = (int)round(loc.floor);
                floor = (floor >= 0)?floor+1:floor;
                return [NSString stringWithFormat:@"%@(%f,%f,%@%dF)",
                        NSLocalizedStringFromTable(@"_nav_latlng_fix", @"BlindView", @""),loc.lat,loc.lng,floor<0?@"B":@"",abs(floor)];
            }
        case NavDestinationTypeSelectStart:
            return NSLocalizedStringFromTable(@"_nav_select_start", @"BlindView", @"");
        case NavDestinationTypeSelectDestination:
            return NSLocalizedStringFromTable(@"_nav_select_destination", @"BlindView", @"");
        case NavDestinationTypeFilter:
            return _label;
        case NavDestinationTypeDialogSearch:
            return NSLocalizedStringFromTable(@"DialogSearch", @"BlindView", @"");
    }
    return nil;
}

- (NSString*)namePron
{
    switch(_type) {
        case NavDestinationTypeDirectoryItem:
            return [_item getItemTitlePron];
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [_landmark getLandmarkNamePron];
        case NavDestinationTypeLocation:
            if (_location == nil) {
                return NSLocalizedStringFromTable(@"_nav_latlng", @"BlindView", @"");
            }
        default:
            return [self name];
    }
    return nil;
}

-(BOOL)isCurrentLocation
{
    return _type == NavDestinationTypeLocation && _location == nil;
}

- (BOOL)isMultiple
{
    return ![[self _id] isEqualToString:[self singleId]];
}
@end

@implementation NavDataStore {
    // location instance that keep the current status should be handled
    HLPLocation *location;
    
    // parameters passed from location manager and manual operations
    BOOL isManualLocation;
    HLPLocation *manualCurrentLocation;
    HLPLocation *currentLocation;
    HLPLocation *savedLocation;
    HLPLocation *savedCenterLocation;
    BOOL savedIsManualLocation;
    
    double magneticOrientation;
    double magneticOrientationAccuracy;
    BOOL _previewMode;
    
    double manualOrientation;
    
    // parameters for request
    NSString* _userID;
    NSString* userLanguage;
    
    // cached data
    NSArray* destinationCache;
    HLPLocation* destinationCacheLocation;
    double destinationDistCache;
    
    HLPDirectory* directoryCache;
    
    BOOL destinationRequesting;
    NSArray* routeCache;
    NSArray* featuresCache;
    
    NSDictionary *destinationHash;
    NSDictionary *serverConfig;
    
    GKQuadtree *quadtree;
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
    
    [self selectUserLanguage:[self userLanguageCandidates].firstObject];
    destinationDistCache = 1000;
    
    // prevent problem on server cache
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:ORIENTATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocationChanged:) name:MANUAL_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processShowRouteLog:) name:REQUEST_PROCESS_SHOW_ROUTE_LOG object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processInitTargetLog:) name:REQUEST_PROCESS_INIT_TARGET_LOG object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildingChanged:) name:BUILDING_CHANGED_NOTIFICATION object:nil];

    return self;
}

- (NSArray*) userLanguageCandidates
{
    // Enumerate user language candidates by using first preferred language
    NSMutableArray* userLanguageCandidates = [[NSMutableArray alloc] init];
    NSString* separator = @"-";
    NSString *userLanguage = [NSLocale preferredLanguages].firstObject; // use first preferred language.
    if (userLanguage == nil){
        userLanguage = @"en";
    }
    NSArray *userLangSplitted = [userLanguage componentsSeparatedByString:separator];
    for(int j=0; j<userLangSplitted.count-1; j++){
        NSRange range = [userLanguage rangeOfString:separator options:NSBackwardsSearch];
        userLanguage = [userLanguage substringToIndex: range.location];
        
        // for compatibility
        if([userLanguage isEqualToString:@"zh-Hans"]){
            [userLanguageCandidates addObject:@"zh-CN"];
        }else if([userLanguage isEqualToString:@"zh-Hant"]){
            [userLanguageCandidates addObject:@"zh-TW"];
        }
        [userLanguageCandidates addObject:userLanguage];
    }
    [userLanguageCandidates addObject:@"en"]; // add "en" as the last candidate
    return userLanguageCandidates;
}

- (BOOL)selectUserLanguage:(NSString *)newLanguage
{
    if ([self.userLanguageCandidates containsObject:newLanguage]) {
        userLanguage = newLanguage;
        return YES;
    }
    return NO;
}

- (void) setUserID:(NSString *)userID
{
    //_userID = [NSString stringWithFormat:@"%@:%@", userID, userLanguage];
    _userID = userID;
}

- (NSString*) userID
{
    return _userID;
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

    /*
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    if ([ud dictionaryForKey:@"lastLocation"]) {
        NSDictionary *dic = [ud dictionaryForKey:@"lastLocation"];
        double lat = [dic[@"lat"] doubleValue];
        double lng = [dic[@"lng"] doubleValue];
        double x = cos(lng/180*M_PI);
        double y = sin(lng/180*M_PI);
        lng = atan2(y,x)/M_PI*180;

        [currentLocation updateLat:lat Lng:lng Accuracy:0 Floor:0];
    }
     */
}


- (void) locationChanged: (NSNotification*) note
{
    if (_previewMode) {
        return;
    }
    
    NSDictionary *obj = [note userInfo];
    
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
    
    if (!(isManualLocation)) {
        [self postLocationNotification];
    }
    if (!isManualLocation) {
        _mapCenter = currentLocation;
    }
}


-(void) postLocationNotification
{
    HLPLocation *loc = [self currentLocation];
    if (loc && [Logging isLogging]) {
        long now = (long)([[NSDate date] timeIntervalSince1970]*1000);
        NSLog(@"Pose,%f,%f,%f,%f,%f,%f,%ld,%f",loc.lat,loc.lng,loc.floor,loc.accuracy,loc.orientation,loc.orientationAccuracy,now,loc.speed);
    }
    [[NSNotificationCenter defaultCenter]
     postNotificationName:NAV_LOCATION_CHANGED_NOTIFICATION
     object: self
     userInfo:
     @{
       @"current":loc?loc:[NSNull null],
       @"isManual":@(isManualLocation),
       
       // Removed nan check to publish unknown lat and lng
       //@"actual":(isnan(currentLocation.lat)||isnan(currentLocation.lng))?[NSNull null]:currentLocation
       @"actual":currentLocation
       }];
}

- (void) orientationChanged: (NSNotification*) note
{
    if (_previewMode) {
        return;
    }

    NSDictionary *obj = [note userInfo];
    
    magneticOrientation = [obj[@"orientation"] doubleValue];
    magneticOrientationAccuracy = [obj[@"orientationAccuracy"] doubleValue];
    
    [self postLocationNotification];
}

- (void) manualLocationChanged: (NSNotification*) note
{
    NSDictionary *obj = [note userInfo];
    double floor = [obj[@"floor"] doubleValue];
    if (floor >= 1) {
        floor -= 1;
    }
    BOOL firstMapCenter = (_mapCenter == nil);
    _mapCenter = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                             Lng:[obj[@"lng"] doubleValue]
                                        Accuracy:1
                                           Floor:floor
                                           Speed:1.0
                                     Orientation:0
                             OrientationAccuracy:999];
    if ([[note userInfo][@"sync"] boolValue]) {
        if (firstMapCenter) {
            [self postLocationNotification];
        }
        isManualLocation = NO;
        manualCurrentLocation = nil;
    } else {
        if (_previewMode) {
            return;
        }
        isManualLocation = YES;
        manualCurrentLocation = _mapCenter;
        [self postLocationNotification];
    }
}

- (HLPLocation*) currentLocation
{
    
    // Removed nan check
    //if (isnan(currentLocation.lat) && isnan(manualCurrentLocation.lat)) {
    //    return nil;
    //}
    
    [location update:currentLocation];
    
    if (manualCurrentLocation) {
        [location updateLat:manualCurrentLocation.lat
                        Lng:manualCurrentLocation.lng
                   Accuracy:manualCurrentLocation.accuracy
                      Floor:manualCurrentLocation.floor];
        [location updateSpeed:manualCurrentLocation.speed];
        if (magneticOrientationAccuracy < location.orientationAccuracy) {
            [location updateOrientation:magneticOrientation
                           withAccuracy:magneticOrientationAccuracy];
        }
    }
    
    // Removed orientation check
    //else {
    //    if (magneticOrientationAccuracy < location.orientationAccuracy) {
    //        [location updateOrientation:magneticOrientation
    //                       withAccuracy:magneticOrientationAccuracy];
    //    }
    //}
    
    // Removed nan check
    //if (isnan(location.lat) || isnan(location.lng)) {
    //    return nil;
    //}
    
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

- (void)processInitTargetLog:(NSNotification*)note
{
    NSString *logstr = [note userInfo][@"text"];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    double lat = [param[@"lat"] doubleValue];
    double lng = [param[@"lng"] doubleValue];
    //NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    [self reloadDestinationsAtLat:lat Lng:lng forUser:self.userID withUserLang:lang];
}

- (void)processShowRouteLog:(NSNotification*)note
{
    NSString *logstr = [note userInfo][@"text"];
    NSRange r1 = [logstr rangeOfString:@","];
    NSString *s1 = [logstr substringFromIndex:r1.location+r1.length];
    NSRange r2 = [s1 rangeOfString:@","];
    NSString *s2 = [s1 substringFromIndex:r2.location+r2.length];
    
    NSDictionary *param = [NSJSONSerialization JSONObjectWithData:[s2 dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSString *fromID = param[@"fromID"];
    NSString *toID = param[@"toID"];
    //NSString *user = param[@"user"];
    NSString *lang = param[@"user_lang"];
    NSDictionary *prefs = param[@"prefs"];
    self.from = [self destinationByID:fromID];
    self.to = [self destinationByID:toID];
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:lang useCache:NO withPreferences:prefs complete:nil];
}

- (void)searchDestinations:(NSString*) query withComplete:(void (^)(HLPDirectory *))complete
{
    NSString *user = [self userID];
    NSString *lang = [self userLanguage];
    [HLPDataUtil queryDirectoryForUser:user withQuery:query withLang:lang withCallback:^(HLPDirectory *directory) {
        complete(directory);
    }];
}

- (BOOL)reloadDestinations:(BOOL)force;
{
    return [self reloadDestinations:force withComplete:nil];
}

- (BOOL)reloadDestinations:(BOOL)force withComplete:(void(^)(NSArray*, HLPDirectory*))complete
{
    if (destinationRequesting) {
        return NO;
    }
    if (force) {
        destinationCacheLocation = nil;
    }
    destinationRequesting = YES;
    double lat = [self mapCenter].lat;
    double lng = [self mapCenter].lng;
    
    NSString *user = [self userID];
    NSString *user_lang = [self userLanguage];
    
    return [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:user_lang withComplete:complete];
}

- (NSString*)normalizePron:(NSString*)str
{
    NSMutableString* retStr = [[NSMutableString alloc] initWithString:str];
    CFStringTransform((CFMutableStringRef)retStr, NULL, kCFStringTransformHiraganaKatakana, YES);
    
    NSRange range = [retStr rangeOfString:@"^[0-9]" options:NSRegularExpressionSearch];
    BOOL matches = range.location != NSNotFound;
    return matches?[NSString stringWithFormat:@"ZZZZZZ%@",retStr]:retStr;
}

- (BOOL)reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang {
    return [self reloadDestinationsAtLat:lat Lng:lng forUser:user withUserLang:user_lang withComplete:nil];
}

- (BOOL)reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang withComplete:(void(^)(NSArray*, HLPDirectory*))complete
{
    return [self reloadDestinationsAtLat:lat Lng:lng Dist:destinationDistCache forUser:user withUserLang:user_lang withComplete:complete];
}

- (BOOL)reloadDestinationsAtLat:(double)lat Lng:(double)lng Dist:(int)dist forUser:(NSString*)user withUserLang:(NSString*)user_lang
{
    return [self reloadDestinationsAtLat:lat Lng:lng Dist:dist forUser:user withUserLang:user_lang withComplete:nil];
}

- (BOOL)reloadDestinationsAtLat:(double)lat Lng:(double)lng Dist:(int)dist forUser:(NSString*)user withUserLang:(NSString*)user_lang withComplete:(void(^)(NSArray*, HLPDirectory*))complete
{
    if (isnan(lat) || isnan(lng) || user == nil || user_lang == nil) {
        return NO;
    }
    destinationDistCache = dist;
    _loadLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng];
    if (destinationCacheLocation && [destinationCacheLocation distanceTo:_loadLocation] < dist/2 &&
        destinationCache && destinationCache.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
        });
        destinationRequesting = NO;
        return NO;
    }
    
    NSDictionary *param = @{@"lat":@(lat), @"lng":@(lng), @"dist": @(dist), @"user":user, @"user_lang":user_lang};
    [Logging logType:@"initTarget" withParam:param];
    
    NSString *query_server = [[ServerConfig sharedConfig] selectedServerConfig][@"query_server"];
    if (query_server) {
        [HLPDataUtil loadDirectoryAtLat:lat Lng:lng inDist:dist forUser:user withLang:user_lang withCallback:^(NSArray<HLPObject *> *result, HLPDirectory *directory) {
            [self didLoadLandmarks:result andDirectory:directory withComplete:complete];
        }];
    } else {
        [HLPDataUtil loadLandmarksAtLat:lat Lng:lng inDist:dist forUser:user withLang:user_lang withCallback:^(NSArray<HLPObject *> *result) {
            [self didLoadLandmarks:result andDirectory:nil withComplete:complete];
        }];
    }
    return YES;
}
    
- (void) didLoadLandmarks:(NSArray<HLPObject *>*) result andDirectory:(HLPDirectory*)directory withComplete:(void(^)(NSArray*, HLPDirectory*))complete{
    if (result == nil) {
        destinationRequesting = NO;
        destinationCache = nil;
        destinationCacheLocation = nil;
        destinationHash = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
        });
        return;
    }
    directoryCache = directory;
    NSLog(@"%ld landmarks are loaded", (unsigned long)[result count]);
    destinationCache = [result sortedArrayUsingComparator:^NSComparisonResult(HLPLandmark *obj1, HLPLandmark *obj2) {
        return [[self normalizePron:[obj1 getLandmarkNamePron]] compare:[self normalizePron:[obj2 getLandmarkNamePron]]];
    }];
    destinationCacheLocation = _loadLocation;
    
    NSMutableDictionary *temp = [@{} mutableCopy];
    [destinationCache enumerateObjectsUsingBlock:^(HLPLandmark *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        temp[[obj nodeID]] = obj;
    }];
    destinationHash = temp;
    
    // check directory item it is facility or not
    for (HLPDirectorySection *section in directoryCache.sections) {
        for(HLPDirectoryItem *item in section.items) {
            if (item.nodeID) {
                NSArray* ids = [item.nodeID componentsSeparatedByString:@"|"];
                HLPLandmark *landmark = [destinationHash objectForKey:ids[0]];
                item.isFacility = landmark.isFacility;
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DESTINATIONS_CHANGED_NOTIFICATION object:self userInfo:@{@"destinations":destinationCache?destinationCache:@[]}];
    });
    if (complete) {
        complete(destinationCache, directoryCache);
    }
    
    destinationRequesting = NO;
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
    
    while([temp count] > 5) {
        [temp removeLastObject];
    }
    [NSKeyedArchiver archiveRootObject:temp toFile:path];
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID withPreferences:(NSDictionary *)prefs complete:(void (^)(void))complete
{
    [self saveHistory];
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:self.userLanguage useCache:NO withPreferences:prefs complete:complete];
}

- (void)requestRerouteFrom:(NSString *)fromID To:(NSString *)toID withPreferences:(NSDictionary *)prefs complete:(void (^)(void))complete
{
    [self requestRouteFrom:fromID To:toID forUser:self.userID withLang:self.userLanguage useCache:YES withPreferences:prefs complete:complete];
}

- (void)requestRouteFrom:(NSString *)fromID To:(NSString *)toID forUser:(NSString*)user withLang:(NSString*)lang useCache:(BOOL)useCache withPreferences:(NSDictionary *)prefs complete:(void (^)(void))complete
{
    if (fromID == nil || toID == nil || user == nil || lang == nil || prefs == nil) {
        return;
    }
    NSDictionary *param = @{@"fromID":fromID, @"toID":toID, @"user":user, @"user_lang":lang, @"prefs":prefs};
    [Logging logType:@"showRoute" withParam:param];
    
    if ([fromID isEqualToString:toID]) {
        routeCache = nil;
        if (useCache && featuresCache) {
            if (complete) {
                complete();
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
            return;
        }
        [HLPDataUtil loadNodeMapForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
            featuresCache = result;
            [HLPDataUtil loadFeaturesForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
                featuresCache = [featuresCache arrayByAddingObjectsFromArray: result];
                
                for(HLPObject* f in featuresCache) {
                    [f updateWithLang:lang];
                }
                
                [self analyzeFeatures:featuresCache];
                [self updateRoute];
                
                if (complete) {
                    complete();
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
            }];
        }];
    } else {
        [HLPDataUtil loadRouteFromNode:fromID toNode:toID forUser:user withLang:lang withPrefs:prefs withCallback:^(NSArray<HLPObject *> *result) {
            routeCache = result;
            if (useCache && featuresCache) {
                if (complete) {
                    complete();
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
                return;
            }
            [HLPDataUtil loadNodeMapForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
                featuresCache = result;
                [HLPDataUtil loadFeaturesForUser:user withLang:lang WithCallback:^(NSArray<HLPObject *> *result) {
                    featuresCache = [featuresCache arrayByAddingObjectsFromArray: result];
                    
                    for(HLPObject* f in featuresCache) {
                        [f updateWithLang:lang];
                    }
                    
                    [self analyzeFeatures:featuresCache];
                    [self updateRoute];
                    
                    if (complete) {
                        complete();
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":routeCache?routeCache:@[]}];
                }];
            }];
        }];
    }
}

- (void) updateRoute
{
    [routeCache enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:HLPLink.class]) {
            [obj updateWithNodesMap:_nodesMap];
        }
    }];
    
    [routeCache enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:HLPLink.class]) {
            HLPLink *link = (HLPLink*)obj;
            link.escalatorFlags = [_linksMap[link._id] escalatorFlags];
        }
    }];
}

// attribute names of hokoukukan network data in Japanese
#define FOR_NODE_ID @"対応ノードID"
#define SOURCE_NODE_ID @"起点ノードID"
#define TARGET_NODE_ID @"終点ノードID"
#define FACILITY_ID @"施設ID"
#define FOR_FACILITY_ID @"対応施設ID"

MKMapPoint convertFromGlobal(HLPLocation* global, HLPLocation* rp) {
    double distance = [HLPLocation distanceFromLat:global.lat Lng:global.lng toLat:rp.lat Lng:rp.lng];
    double d2r = M_PI / 180;
    double r = [HLPLocation bearingFromLat:rp.lat Lng:rp.lng toLat:global.lat Lng:global.lng] * d2r;
    return MKMapPointMake(distance*sin(r), distance*cos(r));
}

- (void) analyzeFeatures:(NSArray*)features
{
    NSMutableDictionary *idMapTemp = [@{} mutableCopy];
    NSMutableDictionary *entranceMapTemp = [@{} mutableCopy];
    NSMutableDictionary *poiMapTemp = [@{} mutableCopy];
    NSMutableArray *poisTemp = [@[] mutableCopy];
    NSMutableDictionary *nodesMapTemp = [@{} mutableCopy];
    NSMutableDictionary *linksMapTemp = [@{} mutableCopy];
    NSMutableDictionary *nodeLinksMapTemp = [@{} mutableCopy];
    NSMutableArray *escalatorLinksTemp = [@[] mutableCopy];
    
    for(HLPObject *obj in features) {
        @try {
            idMapTemp[obj._id] = obj;
            NSMutableArray *array = nil;
            switch(obj.category) {
                case HLP_OBJECT_CATEGORY_LINK:
                    linksMapTemp[obj._id] = obj;
                    array = nodeLinksMapTemp[obj.properties[SOURCE_NODE_ID]];
                    if (!array) {
                        array = [@[] mutableCopy];
                        nodeLinksMapTemp[obj.properties[SOURCE_NODE_ID]] = array;
                    }
                    [array addObject:obj];
                    
                    array = nodeLinksMapTemp[obj.properties[TARGET_NODE_ID]];
                    if (!array) {
                        array = [@[] mutableCopy];
                        nodeLinksMapTemp[obj.properties[TARGET_NODE_ID]] = array;
                    }
                    [array addObject:obj];
                    if (((HLPLink*)obj).linkType == LINK_TYPE_ESCALATOR) {
                        [escalatorLinksTemp addObject:obj];
                    }
                    
                    break;
                case HLP_OBJECT_CATEGORY_NODE:
                    nodesMapTemp[obj._id] = obj;
                    break;
                case HLP_OBJECT_CATEGORY_TOILET:
                case HLP_OBJECT_CATEGORY_PUBLIC_FACILITY:
                    poiMapTemp[obj.properties[FACILITY_ID]] = obj;
                    [poisTemp addObject:obj];
                    break;
                default:
                    break;
            }
        }
        @catch(NSException *e) {
            NSLog(@"%@", [e debugDescription]);
            NSLog(@"%@", obj);
        }
    }
    for(HLPEntrance *ent in features) {
        if ([ent isKindOfClass:HLPEntrance.class]) {
            if ([[ent getName] isEqualToString:@"#"]) {
                // remove special door tag
                continue;
            }
            [ent updateNode:nodesMapTemp[ent.forNodeID]
                andFacility:poiMapTemp[ent.forFacilityID]];
            
            entranceMapTemp[ent.forNodeID] = ent;
        }
    }
    
    _idMap = idMapTemp;
    _entranceMap = entranceMapTemp;
    _poiMap = poiMapTemp;
    _pois = poisTemp;
    _nodesMap = nodesMapTemp;
    _linksMap = linksMapTemp;
    _nodeLinksMap = nodeLinksMapTemp;
    _escalatorLinks = escalatorLinksTemp;
    
    [_linksMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [obj updateWithNodesMap:_nodesMap];
    }];
    
    [nodeLinksMapTemp enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSMutableArray* obj, BOOL * _Nonnull stop) {
        HLPNode *node = _nodesMap[key];
        [obj sortUsingComparator:^NSComparisonResult(HLPLink *l1, HLPLink *l2) {
            double o1, o2;
            o1 = (l1.sourceNode == node)?l1.initialBearingFromSource:l1.initialBearingFromTarget;
            o2 = (l2.sourceNode == node)?l2.initialBearingFromSource:l2.initialBearingFromTarget;
            return [@(o1) compare:@(o2)];
        }];
    }];
     
    // determine escalator side from links
    for(int i = 0; i < [_escalatorLinks count]; i++) {
        HLPLink* link1 = _escalatorLinks[i];
        if (link1.direction == DIRECTION_TYPE_BOTH) {
            continue;
        }
        BOOL dir1 = (link1.direction == DIRECTION_TYPE_SOURCE_TO_TARGET);
        HLPLocation *source1 = dir1?link1.sourceLocation:link1.targetLocation;
        //HLPLocation *source1 = link1.sourceLocation;
        double bearing1 = link1.initialBearingFromSource;
        
        HLPPOIEscalatorFlags*(^isSideBySideEscalator)(HLPLink*) = ^(HLPLink* link2) {
            BOOL dir2 = (link2.direction == DIRECTION_TYPE_SOURCE_TO_TARGET);
            HLPLocation *source2 = dir2?link2.sourceLocation:link2.targetLocation;
            HLPLocation *target2 = dir2?link2.targetLocation:link2.sourceLocation;
            if (source1.floor != source2.floor && source1.floor != target2.floor) {
                source2 = target2 = nil;
            }
            if (!source2) {
                return (HLPPOIEscalatorFlags*)nil;
            }
            if ([source1 distanceTo:source2] > 2.5) {
                return (HLPPOIEscalatorFlags*)nil;
            }
            double bearing = [HLPLocation normalizeDegree:[source1 bearingTo:source2] - bearing1];
            if (fabs(bearing) < 80 || 100 < fabs(bearing)) {
                //NSLog(@"bearing-%f", bearing);
                //return (HLPPOIEscalatorFlags*)nil;
            }
            NSMutableString* temp = [@"" mutableCopy];
            [temp appendString:bearing<0?@"_left_ ":@"_right_ "];
            [temp appendString:((source2==link2.sourceLocation) && dir2) ? @"_forward_ ":@"_backward_ "];
            [temp appendString:source2.floor > target2.floor ? @"_downward_ ":@"_upward_ "];
            
            return [[HLPPOIEscalatorFlags alloc] initWithString:temp];
        };
        
        NSMutableArray *flags = [@[] mutableCopy];
        
        for(int j = 0; j < [_escalatorLinks count]; j++) {
            HLPLink* link2 = _escalatorLinks[j];
            if (link1 == link2 ||
                (source1.floor != link2.sourceHeight && source1.floor != link2.targetHeight) ||
                link2.direction == DIRECTION_TYPE_BOTH
                ) {
                continue;
            }
            
            HLPPOIEscalatorFlags *flag = isSideBySideEscalator(link2);
            if (flag == nil) {
                continue;
            }
            [flags addObject:flag];
        }
        //NSLog(@"%@, %f->%f, %@", link1._id, link1.sourceHeight, link1.targetHeight, flags);
        
        link1.escalatorFlags = flags;
    }
    
    HLPLocation *rp = _loadLocation;
    __block float maxx = FLT_MIN, maxy = FLT_MIN, minx = FLT_MAX, miny = FLT_MAX;
    [self.linksMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, HLPLink *link, BOOL * _Nonnull stop) {
        MKMapPoint ms = convertFromGlobal(link.sourceLocation, rp);
        MKMapPoint mt = convertFromGlobal(link.targetLocation, rp);
        
        maxx = (float)MAX(maxx, ms.x);
        maxx = (float)MAX(maxx, mt.x);
        minx = (float)MIN(minx, ms.x);
        minx = (float)MIN(minx, mt.x);
        
        maxy = (float)MAX(maxy, ms.y);
        maxy = (float)MAX(maxy, mt.y);
        miny = (float)MIN(miny, ms.y);
        miny = (float)MIN(miny, mt.y);
    }];
    struct GKQuad q;
    q.quadMin = (vector_float2){minx, miny};
    q.quadMax = (vector_float2){maxx, maxy};
    quadtree = [GKQuadtree quadtreeWithBoundingQuad:q minimumCellSize:100];
    
    [self.linksMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, HLPLink *link, BOOL * _Nonnull stop) {
        MKMapPoint ms = convertFromGlobal(link.sourceLocation, rp);
        MKMapPoint mt = convertFromGlobal(link.targetLocation, rp);
        
        [quadtree addElement:link withPoint:(vector_float2){ms.x, ms.y}];
        [quadtree addElement:link withPoint:(vector_float2){mt.x, mt.y}];
        
        double d = sqrt(pow(ms.x-mt.x, 2)+pow(ms.y-mt.y, 2));
        //NSLog(@"quadtree,%f, %f, %f, %f, %f", ms.x, ms.y, mt.x, mt.y, d);
        while(d > 3) {
            double r = 1;
            MKMapPoint ms2 = MKMapPointMake((ms.x*(d-r)+mt.x*r)/d, (ms.y*(d-r)+mt.y*r)/d);
            MKMapPoint mt2 = MKMapPointMake((mt.x*(d-r)+ms.x*r)/d, (mt.y*(d-r)+ms.y*r)/d);
            [quadtree addElement:link withPoint:(vector_float2){ms2.x, ms2.y}];
            [quadtree addElement:link withPoint:(vector_float2){mt2.x, mt2.y}];
            ms = ms2;
            mt = mt2;
            d = sqrt(pow(ms.x-mt.x, 2)+pow(ms.y-mt.y, 2));
            //NSLog(@"quadtree,%f, %f, %f, %f, %f", ms.x, ms.y, mt.x, mt.y, d);
        }
        //NSLog(@"quadtree------ %f (%f).", d, [link.sourceLocation distanceTo:link.targetLocation]);
    }];
    
    // associate pois to links
    NSMutableDictionary *linkPoiMap = [@{} mutableCopy];
    for(int j = 0; j < [_pois count]; j++) {
        if ([_pois[j] isKindOfClass:HLPPOI.class] == NO) {
            continue;
        }
        HLPPOI *poi = _pois[j];
        HLPLocation *poiLoc = poi.location;
        HLPLinkType linkType = 0;
        if (poi.poiCategory == HLPPOICategoryElevatorEquipments ||
            poi.poiCategory == HLPPOICategoryElevator
            ) {
            linkType = LINK_TYPE_ELEVATOR;
            [poiLoc updateFloor:NAN];
        }
        NSArray *links = [self nearestLinksAt:poiLoc withOptions:
                          @{@"linkType":@(linkType),
                            @"POI_DISTANCE_MIN_THRESHOLD":@(10)}];
        
        for(HLPLink* nearestLink in links) {
            NSMutableArray *linkPois = linkPoiMap[nearestLink._id];
            if (!linkPois) {
                linkPois = [@[] mutableCopy];
                linkPoiMap[nearestLink._id] = linkPois;
            }
            [linkPois addObject:poi];
        }
    }
    
    //HLPEntrance *destinationNode = _entranceMap[[[self.route lastObject] _id]];
    //HLPEntrance *startNode = _entranceMap[[[self.route firstObject] _id]];;
    
    for(HLPEntrance *ent in features) {
        if ([ent isKindOfClass:HLPEntrance.class]) {
            /*
            if ([startNode.forFacilityID isEqualToString:ent.forFacilityID]) {
                //continue;
            }
            if ([destinationNode.forFacilityID isEqualToString:ent.forFacilityID]) {
                //NSLog(@"%@", ent);
            }
             */
            if (!ent.node) { // special door tag
                continue;
            }
            //NSLog(@"Facility: %@ %@", ent._id, ent.facility.name);
            
            BOOL isLeaf = ent.node.isLeaf;
            NSMutableDictionary *opt = [isLeaf?@{@"onlyEnd":@(YES)}:@{} mutableCopy];
            opt[@"POI_DISTANCE_MIN_THRESHOLD"] = @(10);

            NSArray *links = [self nearestLinksAt:ent.node.location withOptions:opt];
            for(HLPLink* nearestLink in links) {
                if ([nearestLink.sourceNodeID isEqualToString:ent.node._id] ||
                    [nearestLink.targetNodeID isEqualToString:ent.node._id]) {
                    //TODO announce about building
                    //continue;
                }
                NSMutableArray *linkPois = linkPoiMap[nearestLink._id];
                if (!linkPois) {
                    linkPois = [@[] mutableCopy];
                    linkPoiMap[nearestLink._id] = linkPois;
                }
                [linkPois addObject:ent];
                //NSLog(@"%@", nearestLink._id);
                //break;
            }
        }
    }
    _linkPoiMap = linkPoiMap;
    // end associate pois to links

}

- (NSArray*) nearestLinksAt:(HLPLocation*)loc withOptions:(NSDictionary*)option
{
    NSMutableSet<HLPLink*> __block *nearestLinks = nil;
    double __block minDistance = DBL_MAX;
    
    HLPLinkType linkType = [option[@"linkType"] intValue];
    BOOL onlyEnd = [option[@"onlyEnd"] boolValue];
    
    HLPLocation *l1 = [loc offsetLocationByDistance:5 Bearing:-45];
    HLPLocation *l2 = [loc offsetLocationByDistance:5 Bearing:135];

    HLPLocation *rp = _loadLocation;
    MKMapPoint ms = convertFromGlobal(l1, rp);
    MKMapPoint mt = convertFromGlobal(l2, rp);
    
    struct GKQuad q;
    q.quadMin = (vector_float2){(float)MIN(ms.x,mt.x), (float)MIN(ms.y,mt.y)};
    q.quadMax = (vector_float2){(float)MAX(ms.x,mt.x), (float)MAX(ms.y,mt.y)};
        
    NSSet *links = [NSSet setWithArray:[quadtree elementsInQuad:q]];
    [links enumerateObjectsUsingBlock:^(HLPLink *link, BOOL * _Nonnull stop) {
        
        if (!isnan(loc.floor) &&
            (link.sourceHeight != loc.floor && link.targetHeight != loc.floor)) {
            return;
        }
        if (link.isLeaf) {
            return;
        }
        
        HLPLocation *nearest = nil;
        if (onlyEnd) {
            double sd = [link.sourceLocation fastDistanceTo:loc];
            double td = [link.targetLocation fastDistanceTo:loc];
            if (sd > td) {
                nearest = link.targetLocation;
            } else {
                nearest = link.sourceLocation;
            }
        } else {
            nearest = [link nearestLocationTo:loc];
        }
        double distance = [loc fastDistanceTo:nearest];
        
        if (distance < minDistance && (linkType == 0 || link.linkType == linkType)) {
            minDistance = distance;
            nearestLinks = [[NSMutableSet alloc] init];
            [nearestLinks addObject:link];
        }
    }];
    [links enumerateObjectsUsingBlock:^(HLPLink *link, BOOL * _Nonnull stop) {
        
        if (!isnan(loc.floor) &&
            (link.sourceHeight != loc.floor && link.targetHeight != loc.floor)) {
            return;
        }
        if (link.isLeaf) {
            return;
        }
        
        HLPLocation *nearest = nil;
        if (onlyEnd) {
            double sd = [link.sourceLocation fastDistanceTo:loc];
            double td = [link.targetLocation fastDistanceTo:loc];
            if (sd > td) {
                nearest = link.targetLocation;
            } else {
                nearest = link.sourceLocation;
            }
        } else {
            nearest = [link nearestLocationTo:loc];
        }
        double distance = [loc fastDistanceTo:nearest];
        
        if (fabs(distance - minDistance) < 0.5 && (linkType == 0 || link.linkType == linkType)) {
            [nearestLinks addObject:link];
        }
    }];


    if (minDistance < (option[@"POI_DISTANCE_MIN_THRESHOLD"]?[option[@"POI_DISTANCE_MIN_THRESHOLD"] doubleValue]:5)) {
        return nearestLinks.allObjects;
    } else {
        return @[];
    }
}

#define CONFIG_JSON @"%@://%@/%@config/dialog_config.json"

- (void)requestServerConfigWithComplete:(void(^)(void))complete
{
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    
    if (!server || [server length] == 0) {
        return;
    }
    
    NSString *context = [[NSUserDefaults standardUserDefaults] stringForKey:@"hokoukukan_server_context"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:CONFIG_JSON, https, server, context]];

    [HLPDataUtil getJSON:url withCallback:^(NSObject* json){
        if (json && [json isKindOfClass:NSDictionary.class]) {
            serverConfig = (NSDictionary*)json;
            complete();
        } else {
            NSLog(@"error in loading dialog_config, retrying...");
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self requestServerConfigWithComplete:complete];
            });
        }
    }];
}

- (NSDictionary*)serverConfig
{
    return serverConfig;
}

- (BOOL) isManualLocation
{
    return isManualLocation;
}

- (void)clearRoute
{
    routeCache = nil;
    [Logging logType:@"clearRoute" withParam:@{}];
    [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CLEARED_NOTIFICATION object:self];
}

- (NSArray*)destinations
{
    return destinationCache;
}
    
- (HLPDirectory *)directory
{
    return directoryCache;
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

- (NavDestination*)destinationByID:(NSString *)key
{
    return [[NavDestination alloc] initWithLandmark: [destinationHash objectForKey:key]];
}

- (NavDestination *)destinationByIDs:(NSArray *)keys
{
    NavDestination *dest = nil;
    for(NSString *key in keys) {
        HLPLandmark *l = [destinationHash objectForKey:key];
        if (dest == nil) {
            dest = [[NavDestination alloc] initWithLandmark:l];
        } else {
            [dest addLandmark:l];
        }
    }
    return dest;
}

- (NavDestination *)closestDestinationInLandmarks:(NSArray *)landmarks
{
    HLPLocation *loc = [self currentLocation];
    double min = DBL_MAX;
    HLPLandmark *minl = landmarks[0];
    for(HLPLandmark *l in landmarks) {
        if (l) {
            double d = [[l nodeLocation] distanceTo:loc];
            if (d < min) {
                min = d;
                minl = l;
            }
        }
    }
    return [[NavDestination alloc] initWithLandmark: minl];
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
        heading = isnan(heading)?0:heading;
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

- (BOOL)isKnownDestination:(NavDestination *)dest
{
    switch(dest.type) {
        case NavDestinationTypeLocation:
            return YES;
        case NavDestinationTypeDirectoryItem:
        case NavDestinationTypeLandmark:
        case NavDestinationTypeLandmarks:
            return [destinationHash objectForKey:dest.singleId] != nil;
            //return [destinationHash objectForKey:dest.landmark.nodeID] != nil;
        default:
            return NO;
    }
}

+ (NavDestination*) destinationForCurrentLocation;
{
    return [[NavDestination alloc] initWithLocation:nil];
}

- (void)setPreviewMode:(BOOL)previewMode
{
    if (_previewMode != previewMode) {
        if (previewMode) {
            if (!savedLocation) {
                savedLocation = [[HLPLocation alloc] init];
                [savedLocation update:currentLocation];
                savedCenterLocation = [[HLPLocation alloc] init];
                [savedCenterLocation update:_mapCenter];
                savedIsManualLocation = isManualLocation;
            }
        } else {
            if (savedCenterLocation) {
                [_mapCenter update:savedCenterLocation];
                if (_mapCenter) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION
                                                                        object:self
                                                                      userInfo:@{@"location":_mapCenter,
                                                                                 @"sync":@(!savedIsManualLocation)}];
                }
            }
            [currentLocation update:savedLocation];
            savedLocation = nil;
            [self postLocationNotification];
        }
    }
    _previewMode = previewMode;
}

- (BOOL)previewMode
{
    return _previewMode;
}

- (void)buildingChanged:(NSNotification*)note
{
    NSDictionary *dict = [note userInfo];
    _buildingInfo = dict;
}

- (void) startExercise
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"exercise-data" ofType:@"json"];
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return;
    }
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    if (!json) {
        NSLog(@"not valid exercise data");
        return;
    }
    if (json[@"landmark"] && json[@"route"] && json[@"features"]) {
        HLPLandmark *landmark = [MTLJSONAdapter modelOfClass:HLPLandmark.class fromJSONDictionary:json[@"landmark"] error:&error];
        
        NSMutableArray *route = [@[] mutableCopy];
        for(NSDictionary* dic in json[@"route"]) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [route addObject:obj];
            }
        }
        routeCache = route;
        
        NSMutableArray *features = [@[] mutableCopy];
        for(NSDictionary* dic in json[@"features"]) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [features addObject:obj];
            }
        }
        featuresCache = features;
        
        for(HLPObject* f in featuresCache) {
            [f updateWithLang:userLanguage];
        }
        
        self.to = [[NavDestination alloc] initWithLandmark:landmark];
        self.previewMode = YES;
        self.exerciseMode = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:ROUTE_CHANGED_NOTIFICATION object:self userInfo:@{@"route":route}];
    }
}

- (BOOL)isElevatorNode:(HLPNode *)node
{
    if (node == nil) {
        return NO;
    }
    for(HLPLink *l in _nodeLinksMap[node._id]) {
        if (l.linkType == LINK_TYPE_ELEVATOR) {
            return YES;
        }
    }
    return NO;
}


- (BOOL)hasRoute
{
    return self.route != nil && [self.route count] >= 3;
}

- (BOOL)isOnRoute:(NSString *)objID
{
    if (self.route == nil) {
        return NO;
    }
    for(HLPObject *o in self.route) {
        if ([o._id isEqualToString:objID]) {
            return YES;
        }
        if ([o isKindOfClass:HLPLink.class]) {
            HLPLink *l = (HLPLink*)o;
            if ([l.sourceNodeID isEqualToString:objID] || [l.targetNodeID isEqualToString:objID]){
                return YES;
            }
        }
    }
    return NO;
}

- (BOOL)isOnDestination:(NSString *)nodeID
{
    HLPLink *link1 = [self lastRouteLink:0];
    HLPLink *link2 = [self lastRouteLink:3];
    return [link1.targetNodeID isEqualToString:nodeID] || [link2.targetNodeID isEqualToString:nodeID];
}

- (BOOL)isOnStart:(NSString *)nodeID
{
    HLPLink *link1 = [self firstRouteLink:0];
    HLPLink *link2 = [self firstRouteLink:3];
    return [link1.sourceNodeID isEqualToString:nodeID] || [link2.sourceNodeID isEqualToString:nodeID];
}

- (HLPLink *)firstRouteLink:(double)ignoreDistance
{
    if (![self hasRoute]) {
        return nil;
    }
    HLPLink* first = self.route[1];
    if (first.length < ignoreDistance && self.route.count >= 4) {
        first = self.route[2];
    }
    return first;
}

- (HLPLink*)lastRouteLink:(double)ignoreDistance
{
    if (![self hasRoute]) {
        return nil;
    }
    HLPLink* last = self.route[self.route.count-2];
    if (last.length < ignoreDistance && self.route.count >= 4) {
        last = self.route[self.route.count-3];
    }
    return last;
}

- (HLPLink *)routeLinkById:(NSString *)linkID
{
    if (self.route == nil) {
        return nil;
    }
    for(HLPObject *o in self.route) {
        if ([o._id isEqualToString:linkID]) {
            return (HLPLink *)o;
        }
    }
    return nil;
}

- (HLPLink*)findElevatorLink:(HLPLink *)link
{
    if (self.route == nil) {
        return nil;
    }
    BOOL found = NO;
    for(HLPObject *o in self.route) {
        if ([o isKindOfClass:HLPLink.class]) {
            HLPLink *l = (HLPLink*)o;
            if ([l._id isEqualToString:link._id]) {
                return l;
            }
            if ([l.sourceNodeID isEqualToString:link.sourceNodeID] ||
                [l.sourceNodeID isEqualToString:link.targetNodeID]) {
                found = YES;
            }
            if (found && l.linkType != LINK_TYPE_ELEVATOR) {
                return l;
            }
        }
    }
    return nil;
}

- (void)setUpHLPLocationManager {
    HLPLocationManager *manager = [HLPLocationManager sharedManager];
    if (manager.isActive) {
        NavDataStore *nds = [NavDataStore sharedDataStore];
        HLPLocation *loc = [nds currentLocation];
        BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
        if (validLocation) {
            return;
        }
    }

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *modelName = [ud stringForKey:@"bleloc_map_data"];
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    if (modelName) {
        NSString* modelPath = [documentsPath stringByAppendingPathComponent:modelName];
        [manager setModelPath:modelPath];
    }
    
    NSDictionary *params = [self getLocationManagerParams];
    [manager setParameters:params];
    
    [manager start];
}

- (NSDictionary*) getLocationManagerParams
{
    NSMutableDictionary *params = [@{} mutableCopy];
    
    NSDictionary *nameTable =
    @{//custom
      @"location_tracking": @"localizeMode",
      @"rssi_bias":         @"rssi_bias",
      @"locLB":             @"locLB",
      @"activatesStatusMonitoring":@"activatesStatusMonitoring",
      @"rep_location":      @"repLocation",
      //
      @"nStates":           @"nStates",
      @"nEffective":        @"effectiveSampleSizeThreshold",
      @"alphaWeaken":       @"alphaWeaken",
      @"nSmooth":           @"nSmooth",
      @"nSmoothTracking":   @"nSmoothTracking",
      @"wheelchair_pdr":    @"walkDetectSigmaThreshold",
      @"meanVelocity":      @"meanVelocity",
      @"stdVelocity":       @"stdVelocity",
      @"diffusionVelocity": @"diffusionVelocity",
      @"minVelocity":       @"minVelocity",
      @"maxVelocity":       @"maxVelocity",
      @"diffusionOrientationBias":@"diffusionOrientationBias",
      @"weightDecayHalfLife":@"weightDecayHalfLife",
      @"sigmaStopRW":       @"sigmaStop",
      @"sigmaMoveRW":       @"sigmaMove",
      @"relativeVelocityEscalator":@"relativeVelocityEscalator",
      @"initialSearchRadius2D":@"burnInRadius2D",
      @"mixProba":          @"mixProba",
      @"rejectDistance":    @"rejectDistance",
      @"rejectFloorDifference":@"rejectFloorDifference",
      @"nBeaconsMinimum":   @"nBeaconsMinimum",
      @"probaOriBiasJump":  @"probabilityOrientationBiasJump",
      @"poseRandomWalkRate":@"poseRandomWalkRate",
      @"randomWalkRate":    @"randomWalkRate",
      @"probaBackwardMove": @"probabilityBackwardMove",
      @"floorLB":           @"locLB.floor",
      @"coeffDiffFloorStdev":@"coeffDiffFloorStdev",
      @"use_altimeter":     @"usesAltimeterForFloorTransCheck",
      @"windowAltitudeManager":@"altimeterManagerParameters.window",
      @"stdThresholdAltitudeManager":@"altimeterManagerParameters.stdThreshold",
      @"weightFloorTransArea":@"pfFloorTransParams.weightTransitionArea",
      @"mixtureProbabilityFloorTransArea":@"pfFloorTransParams.mixtureProbaTransArea",
      @"rejectDistanceFloorTrans":@"pfFloorTransParams.rejectDistance",
      @"durationAllowForceFloorUpdate":@"pfFloorTransParams.durationAllowForceFloorUpdate",
      @"headingConfidenceInit":@"headingConfidenceForOrientationInit",
      @"applyYawDriftSmoothing": @"applysYawDriftAdjust",
      
      @"accuracy_for_demo": @"accuracyForDemo",
      @"use_blelocpp_acc":  @"usesBlelocppAcc",
      @"blelocpp_accuracy_sigma":@"blelocppAccuracySigma",
      @"oriAccThreshold":   @"oriAccThreshold",
      @"show_states":       @"showsStates",
      @"use_compass":       @"usesCompass",
      };
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    [nameTable enumerateKeysAndObjectsUsingBlock:^(NSString *from, NSString *to, BOOL * _Nonnull stop) {
        
        NSObject *value;
        
        if ([from isEqualToString:@"location_tracking"]) {
            NSString *location_tracking = [ud stringForKey:from];
            if ([location_tracking isEqualToString:@"tracking"]) {
                value = @(HLPRandomWalkAccAtt);
            } else if([location_tracking isEqualToString:@"oneshot"]) {
                value = @(HLPOneshot);
            } else if([location_tracking isEqualToString:@"randomwalker"]) {
                value = @(HLPRandomWalkAcc);
            } else if([location_tracking isEqualToString:@"weak_pose_random_walker"]) {
                value = @(HLPWeakPoseRandomWalker);
            }
        }
        else if ([from isEqualToString:@"activatesStatusMonitoring"]) {
            bool activatesDynamicStatusMonitoring = [ud boolForKey:@"activatesStatusMonitoring"];
            if(activatesDynamicStatusMonitoring){
                double minWeightStable = pow(10.0, [ud doubleForKey:@"exponentMinWeightStable"]);
                params[@"locationStatusMonitorParameters.minimumWeightStable"] = @(minWeightStable);
                params[@"locationStatusMonitorParameters.stdev2DEnterStable"] = ([ud valueForKey:@"enterStable"]);
                params[@"locationStatusMonitorParameters.stdev2DExitStable"] = ([ud valueForKey:@"exitStable"]);
                params[@"locationStatusMonitorParameters.stdev2DEnterLocating"] = ([ud valueForKey:@"enterLocating"]);
                params[@"locationStatusMonitorParameters.stdev2DExitLocating"] = ([ud valueForKey:@"exitLocating"]);
                params[@"locationStatusMonitorParameters.monitorIntervalMS"] = ([ud valueForKey:@"statusMonitoringIntervalMS"]);
            }else{
                params[@"locationStatusMonitorParameters.minimumWeightStable"] = @(0.0);
                NSNumber *largeStdev = @(10000);
                params[@"locationStatusMonitorParameters.stdev2DEnterStable"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DExitStable"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DEnterLocating"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DExitLocating"] = largeStdev;
                params[@"locationStatusMonitorParameters.monitorIntervalMS"] = @(3600*1000*24);
            }
            params[@"locationStatusMonitorParameters.unstableLoop"] = ([ud valueForKey:@"minUnstableLoop"]);
            return;
        }
        else if ([from isEqualToString:@"wheelchair_pdr"]) {
            value = @([ud boolForKey:@"wheelchair_pdr"]?0.1:0.6);
        }
        else if ([from isEqualToString:@"locLB"]) {
            value = [ud valueForKey:@"locLB"];
            params[@"locLB.x"] = value;
            params[@"locLB.y"] = value;
            return;
        }
        else if ([from isEqualToString:@"rssi_bias"]) {
            double rssiBias = [ud doubleForKey:@"rssi_bias"];
            if([ud boolForKey:@"rssi_bias_model_used"]){
                // check device and update rssi_bias
                NSString *deviceName = [NavUtil deviceModel];
                NSString *configKey = [@"rssi_bias_m_" stringByAppendingString:deviceName];
                // check if configKey exists in the user defaults.
                if ([ud objectForKey:configKey] != nil){
                    rssiBias = [ud floatForKey:configKey];
                }
            }
            params[@"minRssiBias"] = @(rssiBias-0.1);
            params[@"maxRssiBias"] = @(rssiBias+0.1);
            params[@"meanRssiBias"] = @(rssiBias);
            return;
        }
        else if ([from isEqualToString:@"rep_location"]) {
            NSString *rep_location = [ud stringForKey:@"rep_location"];
            if([rep_location isEqualToString:@"mean"]){
                value = @(HLPLocationManagerRepLocationMean);
            }else if([rep_location isEqualToString:@"densest"]){
                value = @(HLPLocationManagerRepLocationDensest);
            }else if([rep_location isEqualToString:@"closest_mean"]){
                value = @(HLPLocationManagerRepLocationClosestMean);
            }
        }
        else {
            value = [ud valueForKey:from];
        }

        params[to] = value;

    }];
    
    return params;
}

@end

