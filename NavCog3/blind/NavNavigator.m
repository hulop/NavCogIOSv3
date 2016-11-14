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


#import "NavNavigator.h"
#import "LocationEvent.h"
#import "NavDataStore.h"
#import "objc/runtime.h"


// attribute names of hokoukukan network data in Japanese
#define FOR_NODE_ID @"対応ノードID"
#define SOURCE_NODE_ID @"起点ノードID"
#define TARGET_NODE_ID @"終点ノードID"
#define FACILITY_ID @"施設ID"
#define FOR_FACILITY_ID @"対応施設ID"

#define FIXED @(YES)
#define NOT_FIXED @(NO)

/**
 * This represents all constant values for navigator.
 * The default values of the constants are defined in [+ (NSDictionary*) defaults] method.
 * You can expose the value for setting by removing FIXED flag
 */
@implementation NavNavigatorConstants

static NavNavigatorConstants *_instance;

+ (instancetype) constants
{
    return [[NavNavigatorConstants alloc] init];
    /*
    if (!_instance) {
        _instance = [[NavNavigatorConstants alloc] init];
    }
    return _instance;
     */
}

- (instancetype) init
{
    self = [super init];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSArray *propertyNames = [NavNavigatorConstants allPropertyNames];
    NSDictionary *defaults = [NavNavigatorConstants defaults];
    
    for(NSString *propertyName in propertyNames) {
        NSArray *vals = defaults[propertyName];
        if ([vals count] == 5) {
            if ([vals[4] boolValue]) { // FIXED
                [self setValue:vals[0] forKey:propertyName];
                continue;
            }
        }
        if ([ud valueForKey:propertyName]) {
            [self setValue:[ud valueForKey:propertyName] forKey:propertyName];
        } else {
            [self setValue:vals[0] forKey:propertyName];
        }
    }

    return self;
}

+ (NSArray*) allPropertyNames
{
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList(NavNavigatorConstants.class, &outCount);
    NSMutableArray *array = [@[] mutableCopy];
    for(i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            NSString *propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
            [array addObject:propertyName];
        }
    }
    free(properties);
    
    return array;
}

+ (NSArray*) propertyNames
{
    NSArray *names = [NavNavigatorConstants allPropertyNames];
    NSDictionary *defaults = [NavNavigatorConstants defaults];
    
    return [names filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        NSArray *vals = defaults[evaluatedObject];
        return vals && ([vals count] != 5 || ![vals[4] boolValue]);
    }]];
}

+ (NSDictionary*) defaults
{
    return @{//Property name: @[default value, min value, max value, interval, FIXED prevents to be changed in setting view
             @"PREVENT_REMAINING_DISTANCE_EVENT_FOR_FIRST_N_METERS": @[@(7.0), @(0), @(20), @(1), FIXED],
             @"APPROACHING_DISTANCE_THRESHOLD": @[@(6.0), @(1), @(10), @(0.5)],
             @"APPROACHED_DISTANCE_THRESHOLD": @[@(2.0), @(0.5), @(5), @(0.25)],
             @"NO_APPROACHING_DISTANCE_THRESHOLD": @[@(2.0), @(0.5), @(10), @(0.25)],
             @"REMAINING_DISTANCE_INTERVAL": @[@(10.0), @(1), @(25), @(1)],
             @"NO_ANDTURN_DISTANCE_THRESHOLD": @[@(2.0), @(0), @(10), @(0.5)],
             
             @"IGNORE_FIRST_LINK_LENGTH_THRESHOLD": @[@(3.0), @(0), @(10.0), @(0.5)],
             @"IGNORE_LAST_LINK_LENGTH_THRESHOLD": @[@(3.0), @(0), @(10.0), @(0.5), FIXED],
             
             @"POI_ANNOUNCE_DISTANCE": @[@(2.0), @(0), @(10), @(0.5)],
             @"POI_START_INFO_DISTANCE_THRESHOLD": @[@(3.0), @(3), @(10), @(1), FIXED],
             @"POI_END_INFO_DISTANCE_THRESHOLD": @[@(3.0), @(3), @(10), @(1), FIXED],             
             @"POI_DISTANCE_MIN_THRESHOLD": @[@(5.0), @(2), @(50), @(5), FIXED],
             @"POI_FLOOR_DISTANCE_THRESHOLD": @[@(2.0), @(0), @(10), @(0.5), FIXED],
             @"POI_TARGET_DISTANCE_THRESHOLD": @[@(2.0), @(0), @(10), @(0.5), FIXED],
             @"POI_ANNOUNCE_MIN_INTERVAL": @[@(20), @(10), @(120), @(10), FIXED],

             @"NAVIGATION_START_CAUTION_DISTANCE_LIMIT": @[@(3.0), @(1), @(10), @(0.5), FIXED],
             @"NAVIGATION_START_DISTANCE_LIMIT": @[@(10.0), @(0), @(100), @(5), FIXED],
             @"REPEAT_ACTION_TIME_INTERVAL": @[@(15.0), @(5), @(100), @(5), FIXED],

             
             @"OFF_ROUTE_THRESHOLD": @[@(5.0), @(1.0), @(50.0), @(1.0)],
             @"OFF_ROUTE_EXT_LINK_THRETHOLD": @[@(3.0), @(1.0), @(10.0), @(1.0), FIXED],
             @"REROUTE_DISTANCE_THRESHOLD": @[@(6.0), @(1.0), @(10.0), @(1.0), FIXED],
             @"OFF_ROUTE_ANNOUNCE_MIN_INTERVAL": @[@(10), @(5), @(60), @(5), FIXED],
             
             @"NUM_OF_LINKS_TO_CHECK": @[@(3), @(1), @(10), @(1), FIXED],
    
             @"OFF_ROUTE_BEARING_THRESHOLD": @[@(2.0), @(0), @(10), @(0.1), FIXED],
             @"CHANGE_HEADING_THRESHOLD": @[@(30.0), @(0), @(90), @(5)],
             @"ADJUST_HEADING_MARGIN": @[@(15.0), @(0), @(90), @(5)],
             
             @"BACK_DETECTION_THRESHOLD": @[@(2.0), @(0), @(10), @(1)],
             @"BACK_DETECTION_HEADING_THRESHOLD": @[@(120), @(90), @(180), @(5), FIXED],
             @"BACK_ANNOUNCE_MIN_INTERVAL": @[@(10), @(5), @(60), @(5), FIXED],
             
             @"FLOOR_DIFF_THRESHOLD": @[@(0.1), @(0), @(0.5), @(0.1)],
             
             @"CRANK_REMOVE_SAFE_RATE": @[@(0.75), @(0), @(1.0), @(0.05), FIXED]
             };
}
@end

/**
 * This represents link information and navigation state on the route.
 */
@implementation NavLinkInfo
- initWithLink:(HLPLink*)link nextLink:(HLPLink*)nextLink andPOIs:(NSArray *)allPOIs
{
    self = [super self];
    _link = link;
    _nextLink = nextLink;
    _allPOIs = allPOIs;
    [self reset];
    return self;
}

- (void) reset
{
    if (_nextLink) {
        double aCurrent = _link.lastBearingForTarget;
        double aNext = _nextLink.initialBearingFromSource;
        if (isnan(aCurrent) || isnan(aNext)) {
            _nextTurnAngle = NAN;
        } else {
            _nextTurnAngle = [HLPLocation normalizeDegree:aNext-aCurrent];
        }
    } else {
        _nextTurnAngle = NAN;
    }
    
    _hasBeenBearing = NO;
    _hasBeenActivated = NO;
    _hasBeenApproaching = NO;
    _hasBeenWaitingAction = NO;
    _hasBeenFixBackward = NO;
    _nextTargetRemainingDistance = NAN;
    _expirationTimeOfPreventRemainingDistanceEvent = NAN;
    _backDetectedLocation = nil;
    _distanceFromBackDetectedLocationToSnappedLocationOnLink = NAN;
    
    _isComplex = fabs([HLPLocation normalizeDegree:_link.initialBearingFromSource - _link.lastBearingForTarget]) > 10;
    
    _targetLocation = _link.targetLocation;
    _sourceLocation = _link.sourceLocation;
    
    NSMutableArray<NavPOI*> *poisTemp = [@[] mutableCopy];
    NSArray *links = @[_link];
    
    if ([_link isKindOfClass: HLPCombinedLink.class]) {
        links = ((HLPCombinedLink*)_link).links;
    }
    
    _isNextDestination = (_nextLink == nil);
    
    NavNavigatorConstants *C = [NavNavigatorConstants constants];
    
    
    // check NavPOI
    [_allPOIs enumerateObjectsUsingBlock:^(HLPObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        //BOOL isFirstLink = (idx == 0);

        if ([obj isKindOfClass:HLPPOI.class]) { // poi information
            HLPPOI *poi = (HLPPOI*)obj;
            HLPLocation *loc = [poi location];
            HLPLocation *nearest = [_link nearestLocationTo:loc];
            
            double dLocToNearest = [loc distanceTo:nearest];
            
            if (dLocToNearest > C.POI_DISTANCE_MIN_THRESHOLD) {
                return;
            }
            
            double hLocToNearest = [loc bearingTo:nearest];
            BOOL inAngleAtNearest = fabs([HLPLocation normalizeDegree:hLocToNearest - poi.heading]) < poi.angle;
            
            double hLocToSource = [loc bearingTo:_link.sourceLocation];
            double dLocToSource = [loc distanceTo:_link.sourceLocation];
            BOOL inAngleAtSource = fabs([HLPLocation normalizeDegree:hLocToSource - poi.heading]) < poi.angle;
            
            double hLocToTarget = [loc bearingTo:_link.targetLocation];
            double dLocToTarget = [loc distanceTo:_link.targetLocation];
            BOOL inAngleAtTarget = fabs([HLPLocation normalizeDegree:hLocToTarget - poi.heading]) < poi.angle;
            
            double hInitial = [HLPLocation normalizeDegree:_link.initialBearingFromSource - 180];
            BOOL inAngleInitial = fabs([HLPLocation normalizeDegree:hInitial - poi.heading]) < poi.angle;
            
            
            NavPOI *navpoi = nil;
            
            switch(poi.poiCategory) {
                case HLP_POI_CATEGORY_INFO:
                    if (inAngleInitial &&
                        (dLocToSource < C.POI_START_INFO_DISTANCE_THRESHOLD || poi.flagCaution)) {
                        // add info at first link source before navigation announce
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:_link.sourceLocation Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flagCaution)
                                    }];
                    }
                    else if (inAngleInitial &&
                             dLocToTarget < C.POI_END_INFO_DISTANCE_THRESHOLD) {
                        // add info at nearest location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeEnd": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    else if (inAngleInitial) {
                        // add info at nearest location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(poi.flagCaution),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flagCaution)
                                    }];
                    }
                    break;
                case HLP_POI_CATEGORY_FLOOR:
                    if (dLocToNearest < C.POI_FLOOR_DISTANCE_THRESHOLD && inAngleInitial) {
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(poi.flagCaution),
                                    @"forFloor": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flagCaution)
                                    }];                    }
                    break;
                case HLP_POI_CATEGORY_SCENE:
                case HLP_POI_CATEGORY_SHOP:
                case HLP_POI_CATEGORY_LIVE:
                    if (inAngleAtNearest && dLocToNearest < C.POI_DISTANCE_MIN_THRESHOLD) {
                        // add poi info at location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"angleFromLocation": @([nearest bearingTo:poi.location]),
                                    @"flagPlural": @(poi.flagPlural),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
                case HLP_POI_CATEGORY_SIGN:
                    if (inAngleAtSource && dLocToSource < C.POI_TARGET_DISTANCE_THRESHOLD) {
                        // add corner info
                        navpoi = [[NavPOI alloc] initWithText:poi.longDescription Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(YES),
                                    @"forSign": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
                case HLP_POI_CATEGORY_OBJECT:
                    if (inAngleAtTarget && dLocToTarget < C.POI_TARGET_DISTANCE_THRESHOLD) {
                        // add corner info
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forCorner": @(YES),
                                    @"flagPlural": @(poi.flagPlural),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
                case HLP_POI_CATEGORY_CORNER:
                    if (inAngleAtNearest && dLocToTarget < C.POI_TARGET_DISTANCE_THRESHOLD) {
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"angleFromLocation": @([nearest bearingTo:poi.location]),
                                    @"forBeforeEnd": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
            }
            
            if (navpoi != nil) {
                [poisTemp addObject:navpoi];
            }
        } else if ([obj isKindOfClass:HLPEntrance.class]) { // non poi information (facility and entrance)
            HLPEntrance *ent = (HLPEntrance*)obj;
            NavPOI *navpoi = nil;
            
            if ([_nextLink.targetNodeID isEqualToString:ent.node._id]) {
                // destination with a leaf node, make second last link as last link
                _isNextDestination = YES;
                navpoi = [[NavPOI alloc] initWithText:nil Location:ent.facility.location Options:
                          @{
                            @"origin": ent,
                            @"forBeforeEnd": @(YES),
                            @"isDestination": @(YES),
                            @"angleFromLocation": @(_nextLink.lastBearingForTarget)
                            }];
                
            } else if([_link.targetNodeID isEqualToString:ent.node._id]) {
                // destination with non-leaf node
                _isNextDestination = YES;
                navpoi = [[NavPOI alloc] initWithText:obj.properties[@"long_description"]
                                             Location:ent.node.location
                                              Options: @{
                                                         @"origin": ent,
                                                         @"forBeforeEnd": @(YES)
                                                         }];
            } else {
                // mid in route
                HLPLocation *nearest = [_link nearestLocationTo:ent.node.location];
                double angle = [HLPLocation normalizeDegree:[nearest bearingTo:ent.node.location] - _link.initialBearingFromSource];
                if (45 < fabs(angle) && fabs(angle) < 135) {
                    navpoi = [[NavPOI alloc] initWithText:[ent getNamePron] Location:nearest Options:
                              @{
                                @"origin": ent,
                                @"longDescription": [ent getLongDescriptionPron],
                                @"angleFromLocation": @([nearest bearingTo:ent.node.location])
                                }];
                }
            }
            if (navpoi) {
                [poisTemp addObject:navpoi];
            }
        }
        else {
            NSLog(@"unexpected poi object %@", obj);
        }
    }];
    
    
    // convert NAVCOG1/2 acc info into NavPOI
    [links enumerateObjectsUsingBlock:^(HLPLink *link, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *surroundInfo = link.properties[link.backward?@"_NAVCOG_infoFromNode2":@"_NAVCOG_infoFromNode1"];
        if (surroundInfo) {
            NSLog(@"surroundInfo=%@", surroundInfo);
            
            HLPLocation *poiloc = link.sourceLocation;
            
            NavPOI *poi = [[NavPOI alloc] initWithText:surroundInfo Location:poiloc Options:
                           @{@"origin":surroundInfo}];
            
            [poisTemp addObject:poi];
        }
        
        NSString *nodeInfoJSON = link.properties[link.backward?@"_NAVCOG_infoAtNode1":@"_NAVCOG_infoAtNode2"];
        if (nodeInfoJSON) {
            NSError *error;
            NSDictionary* nodeInfo = [NSJSONSerialization JSONObjectWithData:[nodeInfoJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"%@", error);
            } else {
                NSString *info = nodeInfo[@"info"];
                NSString *destInfo = nodeInfo[@"destInfo"];
                NSString *trickyInfo = nodeInfo[@"trickyInfo"];
                BOOL beTricky = [nodeInfo[@"beTricky"] boolValue];
                
                HLPLocation *poiloc = link.targetLocation;
                HLPLocation *trickloc = [link locationDistanceToTarget:15];
                
                if (info) {
                    NavPOI *poi = [[NavPOI alloc] initWithText:info Location:poiloc Options:
                                   @{@"origin":info}];
                    [poisTemp addObject:poi];
                }
                
                if (destInfo) {
                    NavPOI *poi = [[NavPOI alloc] initWithText:destInfo Location:poiloc Options:
                                   @{
                                     @"origin":destInfo,
                                     @"forBeforeEnd": @(YES)
                                     }];
                    [poisTemp addObject:poi];
                }
                
                if (trickyInfo && beTricky) {
                    NavPOI *poi = [[NavPOI alloc] initWithText:trickyInfo Location:trickloc Options:
                                   @{
                                     @"origin":trickyInfo,
                                     @"neesToPlaySound": @(YES),
                                     @"requiresUserAction": @(YES)
                                     }];
                    [poisTemp addObject:poi];
                }
            }
        }
    }];
    
    NSMutableArray *filtered = [@[] mutableCopy];
    NSMutableSet *check = [[NSMutableSet alloc] init];
    for(NavPOI *poi in poisTemp) {
        if ([check containsObject:poi.origin]) {
            NSLog(@"poi is filtered %@", poi.origin);
            continue;
        }
        [check addObject:poi.origin];
        [filtered addObject:poi];
    }
    
    _pois = filtered;
}

- (NSString*) description
{
    NSMutableString *string = [[NSMutableString alloc] initWithString:@"\n"];
    
    [string appendFormat:@"link.length=%f\n", _link.length];
    [string appendFormat:@"link.linkType=%d\n", _link.linkType];
    [string appendFormat:@"link.sourceHeight=%f\n", _link.sourceHeight];
    [string appendFormat:@"link.targetHeight=%f\n", _link.targetHeight];
    [string appendFormat:@"nextTurnAngle=%f\n", _nextTurnAngle];
    [string appendFormat:@"number of POIs=%ld¥n", [_pois count]];
    
    return string;
}

- (void)updateWithLocation:(HLPLocation *)location
{
    @synchronized (self) {

        _userLocation = location;
        _snappedLocationOnLink = [_link nearestLocationTo:location];
        
        _distanceToUserLocationFromLink = [_snappedLocationOnLink distanceTo:_userLocation];
        
        
        _distanceToTargetFromUserLocation = [_userLocation distanceTo:_targetLocation];
        _distanceToTargetFromSnappedLocationOnLink = [_snappedLocationOnLink distanceTo:_targetLocation];
        _distanceToSourceFromSnappedLocationOnLink = [_snappedLocationOnLink distanceTo:_sourceLocation];
        
        if (_backDetectedLocation) {
            _distanceFromBackDetectedLocationToSnappedLocationOnLink = [_backDetectedLocation distanceTo:_snappedLocationOnLink];
        }
        
        if ([_link.geometry.type isEqualToString:@"LineString"]) {
            //TODO for polyline link (assumes the link as a line)
            _diffBearingAtUserLocation = [HLPLocation normalizeDegree:[_userLocation bearingTo:_targetLocation] - _userLocation.orientation];
            
            _diffBearingAtSnappedLocationOnLink = [HLPLocation normalizeDegree:_link.lastBearingForTarget - _userLocation.orientation];
            /*
             _diffBearingAtSnappedLocationOnLink = [HLPLocation normalizeDegree:[_snappedLocationOnLink bearingTo:_targetLocation] - _userLocation.orientation];
             */
            
            _diffBearingAtUserLocationToSnappedLocationOnLink = [HLPLocation normalizeDegree:[_userLocation bearingTo:_snappedLocationOnLink] - _userLocation.orientation];
            
        } else if ([_link.geometry.type isEqualToString:@"Point"]) {
            _diffBearingAtUserLocation = NAN;
            _diffBearingAtSnappedLocationOnLink = NAN;
            _diffBearingAtUserLocationToSnappedLocationOnLink = NAN;
        }
        
        if (isnan(_nextLink.initialBearingFromSource)) {
            _diffNextBearingAtSnappedLocationOnLink = NAN;
        } else {
            _diffNextBearingAtSnappedLocationOnLink = [HLPLocation normalizeDegree:_nextLink.initialBearingFromSource - _userLocation.orientation];
        }
        
        [_pois enumerateObjectsUsingBlock:^(NavPOI * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj updateWithLocation:_snappedLocationOnLink andUserLocation:location];
        }];
    }
}
@end

@implementation NavPOI

-(instancetype)initWithText:(NSString *)text Location:(HLPLocation *)location Options:(NSDictionary *)options
{
    self = [super self];
    _text = text;
    _poiLocation = location;
    _needsToPlaySound = NO;
    _requiresUserAction = NO;
    _forBeforeStart = NO;
    _forFloor = NO;
    _forCorner = NO;
    _forBeforeEnd = NO;
    _flagCaution = NO;
    _flagPlural = NO;
    _angleFromLocation = NAN;
    _diffAngleFromUserOrientation = NAN;
    
    [options enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [self setValue:obj forKey:key];
    }];
    return self;
}

- (void)updateWithLocation:(HLPLocation *)location andUserLocation:(HLPLocation *)userLocation
{
    _snappedLocationOnLink = location;
    _distanceFromSnappedLocation = [_snappedLocationOnLink distanceTo:_poiLocation];
    _distanceFromUserLocation = [userLocation distanceTo:_poiLocation];
    if (!isnan(_angleFromLocation)) {
        _diffAngleFromUserOrientation = [HLPLocation normalizeDegree:_angleFromLocation - userLocation.orientation];
    }
    _userLocation = userLocation;
}
@end

@implementation NavNavigator {
    BOOL isFirst;
    NSArray *route;
    NSArray *features;
    
    NSMutableArray *linkInfos;
    
    NSDictionary *idMap;
    NSDictionary *toiletMap;
    NSDictionary *entranceMap;
    NSDictionary *poiMap;
    NSDictionary *nodesMap;
    NSDictionary *linksMap;
    NSDictionary *nodeLinksMap;
    NSArray *pois;
    NSArray *oneHopLinks;
    
    //NSString *destination;
    //NSString *startPoint;
    HLPNode *destinationNode;
    NSTimeInterval lastCouldNotStartNavigationTime;
    NSTimeInterval waitingStartUntil;
    
    int navIndex;
    int lastNavIndex;
    int firstLinkIndex;
    
    NSTimer *timeoutTimer;
}

- (instancetype)init
{
    self = [super init];
    
    _isActive = NO;
    [self reset];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:) name:ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeCleared:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    return self;
}

- (void)dealloc
{
    //NSLog(@"NavNavigator dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) reset
{
    isFirst = YES;
}

- (void) stop
{
    _isActive = NO;
    [self.delegate didActiveStatusChanged:
     @{
       @"isActive": @(_isActive)
       }];
}

- (void)routeChanged:(NSNotification*)notification
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    NavNavigatorConstants *C = [NavNavigatorConstants constants];
    route = nds.route;
    
    if (route == nil) {
        if ([self.delegate respondsToSelector:@selector(couldNotStartNavigation:)]) {
            [self.delegate couldNotStartNavigation:@{@"reason":@"NETWORK_ERROR"}];
        }
        return;
    }
    if ([route count] == 0) {
        if ([self.delegate respondsToSelector:@selector(couldNotStartNavigation:)]) {
            [self.delegate couldNotStartNavigation:@{@"reason":@"NO_ROUTE"}];
        }
        return;
    }
    
    _isActive = YES;
    waitingStartUntil = [[NSDate date] timeIntervalSince1970] + 1.0;
    [self reset];
    
    // prepare data
    features = nds.features;
    
    NSMutableDictionary *idMapTemp = [@{} mutableCopy];
    NSMutableDictionary *entranceMapTemp = [@{} mutableCopy];
    NSMutableDictionary *poiMapTemp = [@{} mutableCopy];
    NSMutableArray *poisTemp = [@[] mutableCopy];
    NSMutableDictionary *nodesMapTemp = [@{} mutableCopy];
    NSMutableDictionary *linksMapTemp = [@{} mutableCopy];
    NSMutableDictionary *nodeLinksMapTemp = [@{} mutableCopy];

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
            [ent updateNode:nodesMapTemp[ent.forNodeID]
                andFacility:poiMapTemp[ent.forFacilityID]];
            
            entranceMapTemp[ent.forNodeID] = ent;
        }
    }
    
    idMap = idMapTemp;
    entranceMap = entranceMapTemp;
    poiMap = poiMapTemp;
    pois = poisTemp;
    nodesMap = nodesMapTemp;
    linksMap = linksMapTemp;
    nodeLinksMap = nodeLinksMapTemp;
    
    [linksMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [obj updateWithNodesMap:nodesMap];
    }];
    
    
    navIndex = 0;
    
    destinationNode = entranceMap[[[route lastObject] _id]];
    //destination = [entranceMap[[[route lastObject] _id]] getLandmarkName];
    //startPoint = [entranceMap[[[route firstObject] _id]] getLandmarkName];
    
    NSArray*(^nearestLinks)(HLPLocation*, NSString*) = ^ NSArray* (HLPLocation *loc, NSString* nodeID) {
        NSMutableArray<HLPLink*> __block *nearestLinks = [@[] mutableCopy];
        double __block minDistance = DBL_MAX;
        
        [linksMap enumerateKeysAndObjectsUsingBlock:^(NSString* key, HLPLink *link, BOOL * _Nonnull stop) {

            if (!isnan(loc.floor) &&
                (link.sourceHeight != loc.floor || link.targetHeight != loc.floor)) {
                return;
            }
            if ([link.sourceNodeID isEqualToString:nodeID] ||
                [link.targetNodeID isEqualToString:nodeID]) {
                return;
            }
            
            HLPLocation *nearest = [link nearestLocationTo:loc];
            double distance = [loc distanceTo:nearest];
            
            if (distance < minDistance) {
                minDistance = distance;
                nearestLinks = [@[link] mutableCopy];
            } else if (distance == minDistance) {
                [nearestLinks addObject:link];
            }
        }];

        if (minDistance < C.POI_DISTANCE_MIN_THRESHOLD) {
            return nearestLinks;
        } else {
            return @[];
        }
    };

    NSArray*(^collectLinks)(NSArray*) = ^(NSArray *array) {
        NSMutableArray *temp = [@[] mutableCopy];
        for(HLPObject *obj2 in array) {
            if ([obj2 isKindOfClass:HLPLink.class]) {
                HLPNode *sn = nodesMap[[(HLPLink*)obj2 sourceNodeID]];
                HLPNode *tn = nodesMap[[(HLPLink*)obj2 targetNodeID]];
                
                for(HLPLink *lid in sn.connectedLinkIDs) {
                    HLPLink *link = linksMap[lid];
                    [link setTargetNodeIfNeeded:sn withNodesMap:nodesMap];
                    if (![temp containsObject:link]) {
                        [temp addObject:link];
                    }
                }
                for(HLPLink *lid in tn.connectedLinkIDs) {
                    HLPLink *link = linksMap[lid];
                    [link setTargetNodeIfNeeded:tn withNodesMap:nodesMap];
                    if (![temp containsObject:link]) {
                        [temp addObject:link];
                    }
                }
            }
        }
        return temp;
    };
    oneHopLinks = collectLinks(route);
    

    oneHopLinks = [oneHopLinks filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLink *link, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![route containsObject:link] && [link length] > C.OFF_ROUTE_THRESHOLD;
    }]];
    
    navIndex = 0;
    
    // associate pois to links
    NSMutableDictionary *linkPoiMap = [@{} mutableCopy];
    for(int j = 0; j < [pois count]; j++) {
        if ([pois[j] isKindOfClass:HLPPOI.class] == NO) {
            continue;
        }
        HLPPOI *poi = pois[j];
        
        NSArray *links = nearestLinks(poi.location, nil);
        
        for(HLPLink* nearestLink in links) {
            NSMutableArray *linkPois = linkPoiMap[nearestLink._id];
            if (!linkPois) {
                linkPois = [@[] mutableCopy];
                linkPoiMap[nearestLink._id] = linkPois;
            }
            [linkPois addObject:poi];
        }
    }
    
    for(HLPEntrance *ent in features) {
        if ([ent isKindOfClass:HLPEntrance.class]) {
            
            NSArray *links = nearestLinks(ent.node.location, ent.node._id);
            for(HLPLink* nearestLink in links) {
                if ([nearestLink.sourceNodeID isEqualToString:ent.node._id] ||
                    [nearestLink.targetNodeID isEqualToString:ent.node._id]) {
                    //TODO announce about building
                    continue;
                }
                NSMutableArray *linkPois = linkPoiMap[nearestLink._id];
                if (!linkPois) {
                    linkPois = [@[] mutableCopy];
                        linkPoiMap[nearestLink._id] = linkPois;
                }
                [linkPois addObject:ent];
            }
        }
    }
    // end associate pois to links
    
    
    
    // optimize links for navigation
    
    // remove crank
    NSArray*(^removeCrank)(NSArray*) = ^(NSArray *array) {
        NSMutableArray *temp = [[NSMutableArray alloc] initWithArray:array];
        for(int i = 0; i < [temp count]-2; i++) {
            HLPObject* obj1 = temp[i];
            HLPObject* obj2 = temp[i+1];
            HLPObject* obj3 = temp[i+2];
            if ([obj1 isKindOfClass:HLPLink.class] &&
                [obj2 isKindOfClass:HLPLink.class] &&
                [obj3 isKindOfClass:HLPLink.class]
                ) {
                HLPLink* link1 = (HLPLink*) obj1;
                HLPLink* link2 = (HLPLink*) obj2;
                HLPLink* link3 = (HLPLink*) obj3;
                
                if (![HLPCombinedLink link:link1 shouldBeCombinedWithLink:link2] &&
                    ![HLPCombinedLink link:link2 shouldBeCombinedWithLink:link3] &&
                    [HLPCombinedLink link:link1 shouldBeCombinedWithLink:link3]
                    ) {
                    double mw1 = link1.minimumWidth;
                    double mw3 = link3.minimumWidth;
                    if (link2.length < (mw1 + mw3) / 2 * C.CRANK_REMOVE_SAFE_RATE) {
                        
                        // need to update links
                        [temp removeObjectAtIndex:i+1];
                        i--;
                    }
                }
            }
        }
        return temp;
    };
    route = removeCrank(route);
    
    // combine links
    NSArray*(^combineLinks)(NSArray*) = ^(NSArray *array) {
        NSMutableArray *temp = [[NSMutableArray alloc] initWithArray:array];
        for(int i = 0; i < [temp count]-1; i++) {
            HLPObject* obj1 = temp[i];
            HLPObject* obj2 = temp[i+1];
            if ([obj1 isKindOfClass:HLPLink.class] && [obj2 isKindOfClass:HLPLink.class]) {
                HLPLink* link1 = (HLPLink*) obj1;
                HLPLink* link2 = (HLPLink*) obj2;
                
                if ([HLPCombinedLink link:link1 shouldBeCombinedWithLink:link2]) {
                    HLPLink* link12 = [[HLPCombinedLink alloc] initWithLink1:link1 andLink2:link2];
                    [temp setObject:link12 atIndexedSubscript:i];
                    [temp removeObjectAtIndex:i+1];
                    i--;
                }
            }
        }
        return temp;
    };
    
    route = combineLinks(route);
    
    // end optimize links for navigation
    
    // prepare link info
    
    linkInfos = [[NSMutableArray alloc] initWithArray:route];
    for(int i = 0; i < [linkInfos count]; i++) {linkInfos[i] = [NSNull null];}
    
    BOOL isFirstLink = YES;
    for(int i = 0; i < [route count]; i++) {
        if ([route[i] isKindOfClass:HLPLink.class]) {
            HLPLink* link1 = (HLPLink*)route[i];
            
            HLPLink* link2 = nil;
            int j=i+1;
            for(; j < [route count]; j++) {
                if ([route[j] isKindOfClass:HLPLink.class]) {
                    link2 = (HLPLink*)route[j];
                    break;
                }
            }
            
            if (isFirstLink) {
                isFirstLink = NO;
                if (link1.length < C.IGNORE_FIRST_LINK_LENGTH_THRESHOLD &&
                    link2 != nil &&
                    link2.linkType != LINK_TYPE_ELEVATOR &&
                    link2.linkType != LINK_TYPE_ESCALATOR &&
                    link2.linkType != LINK_TYPE_STAIRWAY
                    ) {
                    firstLinkIndex = 2;
                    continue;
                }
                firstLinkIndex = 1;
            }
            
            NSMutableArray *linkPois = [@[] mutableCopy];
            if (!isFirstLink) {
                [linkPois addObjectsFromArray:linkPoiMap[link1._id]];
                if ([link1 isKindOfClass:HLPCombinedLink.class]) {
                    for(HLPLink *link in [(HLPCombinedLink*) link1 links]) {
                        [linkPois addObjectsFromArray:linkPoiMap[link._id]];
                    }
                }
            }
            
            linkInfos[i] = [[NavLinkInfo alloc] initWithLink:link1 nextLink:link2 andPOIs:linkPois];
            
            //NSLog(@"%@", linkInfos[i]);
        }
    }
    
    NavLinkInfo *info = linkInfos[firstLinkIndex];
    [self.delegate didActiveStatusChanged:
     @{
       @"isActive": @(_isActive),
       @"location":info.link.sourceLocation,
       @"heading":@(info.link.initialBearingFromSource)
       }];
    //[self locationChanged:nil];
    
    [self setTimeout:1 withBlock:^(NSTimer * _Nonnull timer) {
        [[NavDataStore sharedDataStore] manualLocation:nil];
    }];
}

- (void)setTimeout:(double)delay withBlock:(void(^)(NSTimer * _Nonnull timer)) block
{
    if (![NavDataStore sharedDataStore].previewMode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:block];
        });
    }
}

- (void)routeCleared:(NSNotification*)notification
{
    [self stop];
}

- (void)locationChanged:(NSNotification*)notification
{
    if (timeoutTimer) {
        [timeoutTimer invalidate];
        [self setTimeout:1 withBlock:^(NSTimer * _Nonnull timer) {
            [[NavDataStore sharedDataStore] manualLocation:nil];
        }];
    }
    
    if (lastNavIndex != navIndex) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NAV_ROUTE_INDEX_CHANGED_NOTIFICATION object:@{@"index":@(navIndex)}];
    }
    lastNavIndex = navIndex;
    
    NavNavigatorConstants *C = [NavNavigatorConstants constants];

    double(^nextTargetRemainingDistance)(double, double) = ^(double dist, double linkLength) {
        double target =  floor((dist - C.PREVENT_REMAINING_DISTANCE_EVENT_FOR_FIRST_N_METERS) / C.REMAINING_DISTANCE_INTERVAL)*C.REMAINING_DISTANCE_INTERVAL;
        return target;
    };
    
    @try {
        HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
        
        if (!_isActive) { // return if navigation is not active
            return;
        }
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (waitingStartUntil > now) {
            return;
        }
        
        // fine closest link in the next N
        int minIndex = -1;
        double minDistance = DBL_MAX;
        
        for(int i = MAX(0, navIndex-C.NUM_OF_LINKS_TO_CHECK); i < MIN(navIndex+C.NUM_OF_LINKS_TO_CHECK, [route count]); i++) {
            NavLinkInfo *info = linkInfos[i];
            if ([info isEqual:[NSNull null]]) {
                continue;
            }
            [info updateWithLocation:location];
            if (info.distanceToUserLocationFromLink < minDistance &&
                ((fabs(location.floor - info.link.sourceHeight) < C.FLOOR_DIFF_THRESHOLD &&
                fabs(location.floor - info.link.targetHeight) < C.FLOOR_DIFF_THRESHOLD) ||
                 (i == 1 && (info.link.linkType == LINK_TYPE_ESCALATOR || info.link.linkType == LINK_TYPE_STAIRWAY)))
                 ) {
                minDistance = info.distanceToUserLocationFromLink;
                minIndex = i;
            }
        }
        //NSLog(@"navIndex=%d, mini=%d, min=%f", navIndex, mini, min);
        
        NavLinkInfo *minLinkInfo = nil;
        if (0 < minIndex && minIndex < [linkInfos count]) {
            minLinkInfo = linkInfos[minIndex];
        }
        NavLinkInfo *linkInfo = nil;
        if (0 < navIndex && navIndex < [linkInfos count]) {
            linkInfo = linkInfos[navIndex];;
        }
        
        
        if (isFirst) {
            if (minDistance > C.NAVIGATION_START_DISTANCE_LIMIT &&
                now - lastCouldNotStartNavigationTime > C.REPEAT_ACTION_TIME_INTERVAL
                ) {// TODO far from link
                if ([self.delegate respondsToSelector:@selector(couldNotStartNavigation:)]) {
                    [self.delegate couldNotStartNavigation:
                     @{
                       @"reason": @"TOO_FAR",
                       @"distance": @(minDistance)
                       }];
                    lastCouldNotStartNavigationTime = [[NSDate date] timeIntervalSince1970];
                    return;
                }
            }
            
            NavLinkInfo *firstLinkInfo = linkInfos[firstLinkIndex];
            // TODO improve length from current location not from existing node
            double totalLength = [self lengthOfRoute:route offset:0 size:[route count]];
            if ([self.delegate respondsToSelector:@selector(didNavigationStarted:)]) {

                
                [self.delegate didNavigationStarted:
                 @{
                   @"pois":firstLinkInfo.pois,
                   @"totalLength":@(totalLength),
                   @"oneHopLinks":oneHopLinks
                   }];
            }
       
            if (minDistance > C.NAVIGATION_START_CAUTION_DISTANCE_LIMIT) {
            }
            //TODO add fix protocol with lower accuracy
            if (fabs(firstLinkInfo.diffBearingAtUserLocation) > C.ADJUST_HEADING_MARGIN) {
                if (!firstLinkInfo.hasBeenBearing && !firstLinkInfo.hasBeenActivated) {
                    firstLinkInfo.hasBeenBearing = YES;
                    if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
                        [self.delegate userNeedsToChangeHeading:
                         @{
                           @"diffHeading": @(firstLinkInfo.diffBearingAtSnappedLocationOnLink),
                           @"threshold": @(C.CHANGE_HEADING_THRESHOLD)
                           }];
                    }
                }
            }
        
            isFirst = NO;
        }
        
        // TODO: check user skip some states
        
        // user should on the expected link
        if (navIndex < [linkInfos count]) {
            NavLinkInfo *linkInfo = linkInfos[navIndex];
            if ([linkInfo isEqual:[NSNull null]]) {
                navIndex++;
                return;
            }
            
            double(^approachingDistance)() = ^{
                if (linkInfo.link.linkType == LINK_TYPE_ESCALATOR || linkInfo.link.linkType == LINK_TYPE_STAIRWAY) {
                    return 3.0;
                } else {
                    return MIN(C.APPROACHING_DISTANCE_THRESHOLD, linkInfo.link.length/2);
                }
            };
            double(^approachedDistance)(NavLinkInfo*) = ^(NavLinkInfo* linkInfo_){
                if (linkInfo_.link.linkType == LINK_TYPE_ESCALATOR || linkInfo_.link.linkType == LINK_TYPE_STAIRWAY) {
                    return 0.5;
                } else {
                    return MAX(MIN(C.APPROACHED_DISTANCE_THRESHOLD, linkInfo_.link.length/4), 0.5);
                }
            };
            if (linkInfo.link.length < C.NO_APPROACHING_DISTANCE_THRESHOLD) {
                linkInfo.hasBeenApproaching = YES;
            }

            
            if (linkInfo.hasBeenWaitingAction) {
                if (linkInfo.nextLink.linkType == LINK_TYPE_ELEVATOR ||
                    (navIndex == 1 && linkInfo.link.linkType == LINK_TYPE_ELEVATOR)) {
                    navIndex++;
                }
                else if (fabs(linkInfo.diffNextBearingAtSnappedLocationOnLink) < C.ADJUST_HEADING_MARGIN) {
                    if ([self.delegate respondsToSelector:@selector(userAdjustedHeading:)]) {
                        [self.delegate userAdjustedHeading:@{}];
                    }
                    navIndex++;
                }

                return;
            }
            
            if (linkInfo.link.linkType == LINK_TYPE_ELEVATOR) {
                if (fabs(linkInfo.link.targetHeight - location.floor) < C.FLOOR_DIFF_THRESHOLD) {
                    if (linkInfo.isNextDestination) {
                        if ([self.delegate respondsToSelector:@selector(didNavigationFinished:)]) {
                            [self.delegate didNavigationFinished:
                             @{
                               @"isEndOfLink": @(linkInfo.nextLink == nil),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                               }];

                        }
                        
                        navIndex = (int)[linkInfos count];
                    } else {
                        linkInfo.hasBeenWaitingAction = YES;
                        if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                            [self.delegate userNeedsToTakeAction:
                             @{
                               @"turnAngle": @(linkInfo.nextTurnAngle),
                               @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                               @"linkType": @(linkInfo.link.linkType),
                               @"nextLinkType": @(linkInfo.nextLink.linkType),
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                               }];
                        }
                    }
                } else {
                    if (navIndex == 1) {
                        if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                            [self.delegate userNeedsToTakeAction:
                             @{
                               @"diffHeading": @(0),
                               @"nextLinkType": @(linkInfo.link.linkType),
                               @"nextSourceHeight": @(linkInfo.link.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.link.targetHeight)
                               }];
                        }
                    }
                }
                return;
            }
            
            
            if (linkInfo.hasBeenBearing) {
                if (fabs(linkInfo.diffBearingAtUserLocation) < C.ADJUST_HEADING_MARGIN) {
                    linkInfo.hasBeenBearing = NO;
                    if ([self.delegate respondsToSelector:@selector(userAdjustedHeading:)]) {
                        [self.delegate userAdjustedHeading:@{}];
                    }
                }
                // TODO if skip this turn
                // return;
            }
            if (linkInfo.hasBeenFixBackward) {
                if (fabs(linkInfo.diffBearingAtSnappedLocationOnLink) < C.ADJUST_HEADING_MARGIN) {
                    linkInfo.hasBeenFixBackward = NO;
                    linkInfo.backDetectedLocation = nil;
                    if ([self.delegate respondsToSelector:@selector(userAdjustedHeading:)]) {
                        [self.delegate userAdjustedHeading:@{}];
                    }
                    if ([self.delegate respondsToSelector:@selector(userNeedsToWalk:)]) {
                        
                        double distance = linkInfo.distanceToTargetFromSnappedLocationOnLink;
                        
                        [self.delegate userNeedsToWalk:
                         @{
                           //@"distance": @(linkInfo.distanceToTargetFromSnappedLocationOnLink),
                           @"pois": linkInfo.pois,
                           @"noCautionPOI": @(YES),
                           @"isFirst": @(navIndex == 1),
                           @"distance": @(distance),
                           @"noAndTurnMinDistance": @(C.NO_ANDTURN_DISTANCE_THRESHOLD),
                           @"linkType": @(linkInfo.link.linkType),
                           @"nextLinkType": @(linkInfo.nextLink.linkType),
                           @"turnAngle": @(linkInfo.nextTurnAngle),
                           @"isNextDestination": @(linkInfo.isNextDestination),
                           @"sourceHeight": @(linkInfo.link.sourceHeight),
                           @"targetHeight": @(linkInfo.link.targetHeight),
                           @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                           @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                           
                           }];
                    }
                }
                // TODO if skip this turn
                // return;
            }
            
            if (!linkInfo.hasBeenActivated && !linkInfo.hasBeenBearing) {
                
                linkInfo.hasBeenActivated = YES;
                if ([self.delegate respondsToSelector:@selector(userNeedsToWalk:)]) {
                    
                    double distance = linkInfo.link.length;
                    if (linkInfo.distanceToUserLocationFromLink - distance > 2) {
                        distance = linkInfo.distanceToTargetFromUserLocation;
                    }
                    
                    [self.delegate userNeedsToWalk:
                     @{
                    //@"distance": @(linkInfo.distanceToTargetFromSnappedLocationOnLink),
                       @"pois": linkInfo.pois,
                       @"isFirst": @(navIndex == 1),
                       @"distance": @(distance),
                       @"noAndTurnMinDistance": @(C.NO_ANDTURN_DISTANCE_THRESHOLD),
                       @"linkType": @(linkInfo.link.linkType),
                       @"nextLinkType": @(linkInfo.nextLink.linkType),
                       @"turnAngle": @(linkInfo.nextTurnAngle),
                       @"isNextDestination": @(linkInfo.isNextDestination),
                       @"sourceHeight": @(linkInfo.link.sourceHeight),
                       @"targetHeight": @(linkInfo.link.targetHeight),
                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                       @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)

                       }];
                }
                linkInfo.nextTargetRemainingDistance = nextTargetRemainingDistance(linkInfo.link.length, linkInfo.link.length);
                
                return;
            }
            
            if (linkInfo.distanceToTargetFromSnappedLocationOnLink < linkInfo.nextTargetRemainingDistance) {
                if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                    [self.delegate remainingDistanceToTarget:
                     @{
                       @"target": @(YES),
                       @"distance": @(linkInfo.distanceToTargetFromSnappedLocationOnLink),
                       @"diffHeading": @((linkInfo.distanceToTargetFromSnappedLocationOnLink>5)?
                           linkInfo.diffBearingAtUserLocation:linkInfo.diffBearingAtSnappedLocationOnLink)
                       }];
                }

                linkInfo.nextTargetRemainingDistance = nextTargetRemainingDistance(linkInfo.distanceToTargetFromSnappedLocationOnLink, linkInfo.link.length);
                return;
            } else {
                if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                    [self.delegate remainingDistanceToTarget:
                     @{
                       @"target": @(NO),
                       @"distance": @(linkInfo.distanceToTargetFromSnappedLocationOnLink),
                       @"diffHeading": @((linkInfo.distanceToTargetFromSnappedLocationOnLink>5)?
                           linkInfo.diffBearingAtUserLocation:linkInfo.diffBearingAtSnappedLocationOnLink)
                       }];
                }
            }
            
            
            // to do adjust approaching distance for short link
            if (linkInfo.distanceToTargetFromSnappedLocationOnLink < approachingDistance() &&
                fabs(linkInfo.diffBearingAtSnappedLocationOnLink) < 45 &&
                !linkInfo.hasBeenApproaching) {
                if ([self.delegate respondsToSelector:@selector(userIsApproachingToTarget:)]) {
                    [self.delegate userIsApproachingToTarget:
                     @{
                       @"turnAngle": @(linkInfo.nextTurnAngle),
                       @"nextLinkType": @(linkInfo.nextLink.linkType),
                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                       @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                       }];
                    
                }
                linkInfo.hasBeenApproaching = YES;
                return;
            }
            
            if (linkInfo.distanceToTargetFromSnappedLocationOnLink < approachedDistance(linkInfo)) {
                
                if (linkInfo.isNextDestination == NO) {
                    if (fabs(linkInfo.link.targetHeight - location.floor) < C.FLOOR_DIFF_THRESHOLD) {
                        if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                            [self.delegate userNeedsToTakeAction:
                             @{
                               @"turnAngle": @(linkInfo.nextTurnAngle),
                               @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                               @"nextLinkType": @(linkInfo.nextLink.linkType),
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                               }];
                        }
                        linkInfo.hasBeenWaitingAction = YES;
                    }
                } else {
                    
                    if ([self.delegate respondsToSelector:@selector(didNavigationFinished:)]) {
                        [self.delegate didNavigationFinished:
                         @{
                           @"isEndOfLink": @(linkInfo.nextLink == nil)
                           }];
                    }
                    
                    navIndex = (int)[linkInfos count];
                }
                
                // read destInfo
                for(int i = 0; i < [linkInfo.pois count]; i++) {
                    NavPOI *poi = linkInfo.pois[i];
                    
                    if (!poi.forBeforeEnd) {
                        continue;
                    }
                    
                    if (!poi.hasBeenApproached) {
                        if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                            [self.delegate userIsApproachingToPOI:
                             @{
                               @"poi": poi,
                               @"heading": @(poi.diffAngleFromUserOrientation)
                               }];
                            poi.hasBeenApproached = YES;
                        }
                    }
                }
                
                return;
            }
            
            
            // check distance to POI and read if it's close
            
            for(int i = 0; i < [linkInfo.pois count]; i++) {
                NavPOI *poi = linkInfo.pois[i];
                
                if (poi.forBeforeStart || poi.forCorner || poi.forFloor) {
                    continue;
                }
                
                if (poi.forBeforeEnd && linkInfo.nextLink != nil) {
                    continue;
                }
                
                if (!poi.hasBeenApproached && now - poi.lastApproached > C.POI_ANNOUNCE_MIN_INTERVAL) {
                    if (poi.distanceFromSnappedLocation < C.POI_ANNOUNCE_DISTANCE &&
                        poi.distanceFromUserLocation < C.POI_ANNOUNCE_DISTANCE) {
                        if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                            [self.delegate userIsApproachingToPOI:
                             @{
                               @"poi": poi,
                               @"heading": @(poi.diffAngleFromUserOrientation)
                               }];
                            poi.hasBeenApproached = YES;
                            poi.hasBeenLeft = NO;
                            poi.lastApproached = now;
                            poi.count++;
                        }
                    }
                } else {
                    if (!poi.hasBeenLeft) {
                        if (poi.distanceFromSnappedLocation > C.POI_ANNOUNCE_DISTANCE) {
                            if ([self.delegate respondsToSelector:@selector(userIsLeavingFromPOI:)]) {
                                [self.delegate userIsLeavingFromPOI:
                                 @{
                                   @"poi": poi,
                                   @"heading": @(poi.diffAngleFromUserOrientation)
                                   }];
                                poi.hasBeenLeft = YES;
                                poi.hasBeenApproached = NO;
                                poi.lastLeft = now;
                            }
                        }
                    }
                }
            }
            
            
            
            // user may be off route
            if (minDistance < DBL_MAX && (minDistance > C.OFF_ROUTE_THRESHOLD || linkInfo.mayBeOffRoute)) {
                int exMinIndex = -1;
                double exMinDistance = DBL_MAX;
                NavLinkInfo *exMinLinkInfo = nil;
                
                if (!linkInfo.offRouteLinkInfo) {
                    for(int i = 0; i < [oneHopLinks count]; i++) {
                        if ([oneHopLinks[i] isKindOfClass:HLPLink.class]) {
                            HLPLink* link1 = (HLPLink*)oneHopLinks[i];
                            NavLinkInfo *info = [[NavLinkInfo alloc] initWithLink:link1 nextLink:nil andPOIs:nil];
                            [info updateWithLocation:location];
                            if (info.distanceToUserLocationFromLink < exMinDistance &&
                                fabs(location.floor - info.link.sourceHeight) < C.FLOOR_DIFF_THRESHOLD &&
                                fabs(location.floor - info.link.targetHeight) < C.FLOOR_DIFF_THRESHOLD) {
                                exMinDistance = info.distanceToUserLocationFromLink;
                                exMinLinkInfo = info;
                                exMinIndex = i;
                            }
                        }
                    }
                    //NSLog(@"%d : %f", exMinIndex, exMinDistance);
                }

                // リンクターゲットで迷った, 曲がり角を行き過ぎた, 反対に曲がった
                // 一度曲がる方向に向いた上で（リンクソース）, 違う方向に行った
                if (linkInfo.distanceToTargetFromSnappedLocationOnLink < C.OFF_ROUTE_EXT_LINK_THRETHOLD ||
                    linkInfo.distanceToSourceFromSnappedLocationOnLink < C.OFF_ROUTE_EXT_LINK_THRETHOLD) {
                    // 現在のリンクから一定以上離れて、one hopリンク上に居る -> 戻すことを試みる
                    if (exMinLinkInfo && exMinDistance < C.OFF_ROUTE_EXT_LINK_THRETHOLD &&
                        (!linkInfo.mayBeOffRoute || (now-linkInfo.lastOffRouteNotified) > C.OFF_ROUTE_ANNOUNCE_MIN_INTERVAL) &&
                        fabs(exMinLinkInfo.diffBearingAtSnappedLocationOnLink) > C.BACK_DETECTION_HEADING_THRESHOLD) {
                        linkInfo.offRouteLinkInfo = exMinLinkInfo;
                        linkInfo.mayBeOffRoute = YES;
                        
                        if ([self.delegate respondsToSelector:@selector(userMaybeOffRoute:)]) {
                            [self.delegate userMaybeOffRoute:
                             @{
                               // 延長リンク上の位置と、headingを指定
                               // exMinLinkInfoがある場合
                               @"distance": @(linkInfo.offRouteLinkInfo.distanceToTargetFromSnappedLocationOnLink),
                               @"diffHeading": @(linkInfo.offRouteLinkInfo.diffBearingAtSnappedLocationOnLink)
                               }];
                        }
                        linkInfo.hasBeenFixOffRoute = YES;
                        linkInfo.hasBeenWaitingAction = NO;
                        linkInfo.hasBeenApproaching = YES;
                        linkInfo.lastOffRouteNotified = now;

                    }
                    else if (minIndex == navIndex && minDistance > C.REROUTE_DISTANCE_THRESHOLD) {
                        // TODO: 不明な場所で、現在のリンクが一番近い -> 戻すことを試みる
                        // linkInfo.mayBeOffRoute = YES;
                        // リンクに近づける方角をアナウンス
                    }
                    else if (minDistance > C.REROUTE_DISTANCE_THRESHOLD) {
                        // TODO: 不明な場所で、現在のリンクではないところが一番近い -> リルート
                    }
                }
                
                if (linkInfo.mayBeOffRoute) {
                    [linkInfo.offRouteLinkInfo updateWithLocation:location];

                    if (linkInfo.hasBeenFixOffRoute &&
                               fabs(linkInfo.offRouteLinkInfo.diffBearingAtSnappedLocationOnLink) < C.ADJUST_HEADING_MARGIN) {
                        linkInfo.hasBeenFixOffRoute = NO;
                        
                        if ([self.delegate respondsToSelector:@selector(userAdjustedHeading:)]) {
                            [self.delegate userAdjustedHeading:@{}];
                        }
                        if ([self.delegate respondsToSelector:@selector(userNeedsToWalk:)]) {
                            
                            double distance = linkInfo.offRouteLinkInfo.distanceToTargetFromSnappedLocationOnLink;
                            
                            [self.delegate userNeedsToWalk:
                             @{
                               //@"distance": @(linkInfo.distanceToTargetFromSnappedLocationOnLink),
                               @"isFirst": @(NO),
                               @"distance": @(distance),
                               @"noAndTurnMinDistance": @(DBL_MAX),
                               @"linkType": @(linkInfo.link.linkType),
                               }];
                        }
                    } else if (linkInfo.offRouteLinkInfo.distanceToTargetFromSnappedLocationOnLink < approachedDistance(linkInfo.offRouteLinkInfo) &&
                         !linkInfo.hasBeenWaitingAction) {
                        linkInfo.mayBeOffRoute = NO;
                        linkInfo.hasBeenWaitingAction = YES;
                        if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                            [self.delegate userNeedsToTakeAction:
                             @{
                               @"turnAngle": @(linkInfo.nextTurnAngle),
                               @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                               @"nextLinkType": @(linkInfo.nextLink.linkType),
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                               }];
                        }
                        
                    }
                    return;
                }
                // 途中で勝手に曲がった
                // bearingで処理
            }
            
            
            // TODO: consider better way to manage user's orientation.
            /*
             if (linkInfo.distanceToUserLocationFromLink > C.OFF_ROUTE_BEARING_THRESHOLD &&
             !isnan(linkInfo.diffBearingAtUserLocation) &&
             fabs(linkInfo.diffBearingAtUserLocation) > C.CHANGE_HEADING_THRESHOLD &&
             !linkInfo.hasBeenBearing &&
             !linkInfo.isComplex) {
             linkInfo.hasBeenBearing = YES;
             if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
             [self.delegate userNeedsToChangeHeading:
             @{
             @"diffHeading": @(linkInfo.diffBearingAtUserLocation),
             @"threshold": @(C.CHANGE_HEADING_THRESHOLD)
             }];
             }
             return;
             }
             */
            
            // check if user goes backward
            if (minIndex <= navIndex && !linkInfo.mayBeOffRoute) {
                
                // BACK_DETECTION_THRESHOLD meters away from current link
                // heading to backward of previous link direction
                if ((minIndex == navIndex ||
                     linkInfo.distanceToUserLocationFromLink > C.BACK_DETECTION_THRESHOLD) &&
                    fabs(minLinkInfo.diffBearingAtSnappedLocationOnLink) > C.BACK_DETECTION_HEADING_THRESHOLD
                    ) {
                    if (minLinkInfo.backDetectedLocation) {
                        if ((minIndex < navIndex && minLinkInfo.distanceToTargetFromSnappedLocationOnLink > C.BACK_DETECTION_THRESHOLD) ||
                            minLinkInfo.distanceFromBackDetectedLocationToSnappedLocationOnLink > C.BACK_DETECTION_THRESHOLD) {
                            if (!minLinkInfo.hasBeenFixBackward || (now-minLinkInfo.lastBackNotified) > C.BACK_ANNOUNCE_MIN_INTERVAL) {
                                navIndex = minIndex;
                                minLinkInfo.hasBeenApproaching = NO;
                                minLinkInfo.hasBeenWaitingAction = NO;
                                minLinkInfo.hasBeenBearing = NO;
                                minLinkInfo.hasBeenFixBackward = YES;
                                minLinkInfo.nextTargetRemainingDistance = nextTargetRemainingDistance(minLinkInfo.distanceToTargetFromSnappedLocationOnLink, linkInfo.link.length);
                                for(int i = navIndex+1; i < [linkInfos count]; i++) {
                                    if (![linkInfos[i] isEqual:[NSNull null]]) {
                                        [linkInfos[i] reset];
                                    }
                                }
                                minLinkInfo.lastBackNotified = now;
                                if ([self.delegate respondsToSelector:@selector(userMaybeGoingBackward:)]) {
                                    [self.delegate userMaybeGoingBackward:
                                     @{
                                       @"diffHeading": @(minLinkInfo.diffBearingAtUserLocation),
                                       @"threshold": @(C.CHANGE_HEADING_THRESHOLD)
                                       }];
                                }
                            }
                            return;
                        }
                    } else {
                        minLinkInfo.backDetectedLocation = minLinkInfo.snappedLocationOnLink;
                    }
                    return;
                }
            }
            
            
            return;
        }
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}



#pragma mark - Private utilities

- (double) lengthOfRoute:(NSArray<HLPObject*>*)array offset:(NSInteger)offset size:(NSInteger)size
{
    double total = 0;
    for(NSInteger i=offset; i < offset+size; i++) {
        if (i < 0 || [array count] <= i) {
            break;
        }
        HLPObject *obj = [array objectAtIndex:i];
        if ([obj isKindOfClass:HLPLink.class]) {
            HLPLink *link = (HLPLink*)obj;
            total += link.length;
        }
    }
    return total;
}

@end
