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
             @"NO_APPROACHING_DISTANCE_THRESHOLD": @[@(6.0), @(0.5), @(15), @(0.25)],
             @"REMAINING_DISTANCE_INTERVAL": @[@(15.0), @(1), @(25), @(1)],
             @"NO_ANDTURN_DISTANCE_THRESHOLD": @[@(4.0), @(0), @(10), @(0.5)],
             
             @"IGNORE_FIRST_LINK_LENGTH_THRESHOLD": @[@(3.0), @(0), @(10.0), @(0.5)],
             @"IGNORE_LAST_LINK_LENGTH_THRESHOLD": @[@(3.0), @(0), @(10.0), @(0.5), FIXED],
             
             @"POI_ANNOUNCE_DISTANCE": @[@(4.0), @(0), @(10), @(0.5)],
             @"POI_START_INFO_DISTANCE_THRESHOLD": @[@(3.0), @(3), @(10), @(1), FIXED],
             @"POI_END_INFO_DISTANCE_THRESHOLD": @[@(3.0), @(3), @(10), @(1), FIXED],
             @"POI_DISTANCE_MIN_THRESHOLD": @[@(5.0), @(2), @(50), @(5), FIXED],
             @"POI_FLOOR_DISTANCE_THRESHOLD": @[@(2.0), @(0), @(10), @(0.5), FIXED],
             @"POI_TARGET_DISTANCE_THRESHOLD": @[@(2.0), @(0), @(10), @(0.5), FIXED],
             @"POI_ANNOUNCE_MIN_INTERVAL": @[@(20), @(10), @(120), @(10), FIXED],
             
             @"NAVIGATION_START_CAUTION_DISTANCE_LIMIT": @[@(3.0), @(1), @(10), @(0.5), FIXED],
             @"NAVIGATION_START_DISTANCE_LIMIT": @[@(10.0), @(0), @(100), @(5), FIXED],
             @"REPEAT_ACTION_TIME_INTERVAL": @[@(15.0), @(5), @(100), @(5), FIXED],
             
             
             @"OFF_ROUTE_THRESHOLD": @[@(6.0), @(1.0), @(50.0), @(1.0)],
             @"OFF_ROUTE_EXT_LINK_THRETHOLD": @[@(3.0), @(1.0), @(10.0), @(1.0), FIXED],
             @"REROUTE_DISTANCE_THRESHOLD": @[@(6.0), @(1.0), @(10.0), @(1.0), FIXED],
             @"OFF_ROUTE_ANNOUNCE_MIN_INTERVAL": @[@(10), @(5), @(60), @(5), FIXED],
             
             @"NUM_OF_LINKS_TO_CHECK": @[@(3), @(1), @(10), @(1), FIXED],
             
             @"OFF_ROUTE_BEARING_THRESHOLD": @[@(2.0), @(0), @(10), @(0.1), FIXED],
             @"CHANGE_HEADING_THRESHOLD": @[@(30.0), @(0), @(90), @(5)],
             @"ADJUST_HEADING_MARGIN": @[@(20.0), @(0), @(90), @(5)],
             
             @"BACK_DETECTION_THRESHOLD": @[@(5.0), @(0), @(10), @(1)],
             @"BACK_DETECTION_HEADING_THRESHOLD": @[@(120), @(90), @(180), @(5), FIXED],
             @"BACK_ANNOUNCE_MIN_INTERVAL": @[@(10), @(5), @(60), @(5), FIXED],
             
             @"FLOOR_DIFF_THRESHOLD": @[@(0.4), @(0), @(0.5), @(0.1)],
             
             @"CRANK_REMOVE_SAFE_RATE": @[@(0.75), @(0), @(1.0), @(0.05), FIXED],
             
             @"MINIMUM_OBSTACLES_POI": @[@(5), @(0), @(10), @(1)]
             
             };
}
@end

/**
 * This represents link information and navigation state on the route.
 */
@implementation NavLinkInfo
- initWithLink:(HLPLink*)link nextLink:(HLPLink*)nextLink andOptions:(NSDictionary*)options
{
    self = [super self];
    _link = link;
    _nextLink = nextLink;
    _options = options;
    _allPOIs = options[@"allPOIs"];
    _isFirst = [options[@"isFirst"] boolValue];
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
    _distanceFromBackDetectedLocationToLocation = NAN;
    //_noBearing = (_link.minimumWidth <= 2.0);
    _noBearing = YES;
    
    _isComplex = fabs([HLPLocation normalizeDegree:_link.initialBearingFromSource - _link.lastBearingForTarget]) > 10;
    
    _targetLocation = _link.targetLocation;
    _sourceLocation = _link.sourceLocation;
    
    NSMutableArray<NavPOI*> *poisTemp = [@[] mutableCopy];
    NSArray *links = @[_link];
    
    if ([_link isKindOfClass: HLPCombinedLink.class]) {
        links = ((HLPCombinedLink*)_link).links;
    }
    
    _isNextDestination = (_nextLink == nil);
    
    // check destination POI before adding POI actually to enable isNextDestination
    NavNavigatorConstants *C = [NavNavigatorConstants constants];
    [_allPOIs enumerateObjectsUsingBlock:^(HLPObject *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:HLPEntrance.class]) { // non poi information (facility and entrance)
            HLPEntrance *ent = (HLPEntrance*)obj;
            
            if ([_nextLink.targetNodeID isEqualToString:ent.node._id]) {
                if (_nextLink.length < 3) {
                    // destination with a leaf node, make second last link as last link
                    _isNextDestination = YES;
                }
            } else if([_link.targetNodeID isEqualToString:ent.node._id]) {
                _isNextDestination = _isNextDestination || ent.node.isLeaf;
            }
        }
    }];
    
    // handle elevator poi
    NSArray<HLPPOI*> *elevators = [_allPOIs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject isKindOfClass:HLPPOI.class]) {
            return [((HLPPOI*)evaluatedObject) poiCategory] == HLPPOICategoryElevator;
        }
        return false;
    }]];
    
    [elevators enumerateObjectsUsingBlock:^(HLPPOI * _Nonnull poi, NSUInteger idx, BOOL * _Nonnull stop) {
        HLPLocation *loc = [poi location];
        HLPLocation *nearest = [_link nearestLocationTo:loc];
        
        double dLocToNearest = [loc distanceTo:nearest];
        if (dLocToNearest > C.POI_DISTANCE_MIN_THRESHOLD) {
            return;
        }
        
        double dLocToTarget = [loc distanceTo:_link.targetLocation];
        
        double hInitial = [HLPLocation normalizeDegree:_link.initialBearingFromSource - 180];
        BOOL inAngleInitial = fabs([HLPLocation normalizeDegree:hInitial - poi.heading]) < poi.angle;
        
        NavPOI *navpoi = nil;
        if (inAngleInitial &&
            dLocToTarget < C.POI_END_INFO_DISTANCE_THRESHOLD) {
            navpoi = [[NavPOI alloc] initWithText:poi.elevatorButtons.description
                                         Location:_link.targetLocation
                                          Options:
                      @{
                        @"origin": poi,
                        @"forAfterEnd": @(YES)
                        }];
        }
        if (navpoi != nil) {
            [poisTemp addObject:navpoi];
        }
    }];
    
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
            
            //double hLocToSource = [loc bearingTo:_link.sourceLocation];
            double dLocToSource = [loc distanceTo:_link.sourceLocation];
            //BOOL inAngleAtSource = fabs([HLPLocation normalizeDegree:hLocToSource - poi.heading]) < poi.angle;
            
            double hLocToTarget = [loc bearingTo:_link.targetLocation];
            double dLocToTarget = [loc distanceTo:_link.targetLocation];
            BOOL inAngleAtTarget = fabs([HLPLocation normalizeDegree:hLocToTarget - poi.heading]) <= poi.angle;
            
            double hInitial = [HLPLocation normalizeDegree:_link.initialBearingFromSource - 180];
            BOOL inAngleInitial = fabs([HLPLocation normalizeDegree:hInitial - poi.heading]) <= poi.angle;
            
            double hLast = [HLPLocation normalizeDegree:_link.lastBearingForTarget - 180];
            BOOL inAngleLast = fabs([HLPLocation normalizeDegree:hLast - poi.heading]) <= poi.angle;
            
            
            NavPOI *navpoi = nil;
            
            switch(poi.poiCategory) {
                case HLPPOICategoryInfo:
                    if (inAngleInitial &&
                        (dLocToSource < C.POI_START_INFO_DISTANCE_THRESHOLD || poi.flags.flagCaution)) {
                        // add info at first link source before navigation announce
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:_link.sourceLocation Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(!_isFirst),
                                    @"forWelcome": @(_isFirst && poi.flags.flagWelcome),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flags.flagCaution)
                                    }];
                    }
                    else if (inAngleInitial &&
                             dLocToTarget < C.POI_END_INFO_DISTANCE_THRESHOLD) {
                        // add info at nearest location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forAfterEnd": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    else if (inAngleInitial) {
                        // add info at nearest location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(poi.flags.flagCaution),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flags.flagCaution)
                                    }];
                    }
                    else if (inAngleAtNearest && dLocToNearest < C.POI_DISTANCE_MIN_THRESHOLD) {
                        // add poi info at location
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"angleFromLocation": @([nearest bearingTo:poi.location]),
                                    @"flagPlural": @(poi.flags.flagPlural),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
                case HLPPOICategoryElevator:
                    navpoi = [[NavPOI alloc] initWithText:poi.elevatorButtons.description
                                                 Location:poi.location
                                                  Options:
                              @{
                                @"origin": poi
                                }];
                    break;
                case HLPPOICategoryElevatorEquipments:
                    navpoi = [[NavPOI alloc] initWithText:poi.elevatorEquipments.description
                                                 Location:poi.location
                                                  Options:
                              @{
                                @"origin": poi
                                }];
                    break;
                case HLPPOICategoryFloor:
                    if (dLocToNearest < C.POI_FLOOR_DISTANCE_THRESHOLD && inAngleInitial) {
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forBeforeStart": @(poi.flags.flagCaution),
                                    @"forFloor": @(YES),
                                    @"longDescription": poi.longDescription?poi.longDescription:@"",
                                    @"flagCaution": @(poi.flags.flagCaution)
                                    }];
                        break;
                    }
                case HLPPOICategoryCornerEnd:
                case HLPPOICategoryCornerLandmark:
                case HLPPOICategoryCornerWarningBlock:
                    if (inAngleAtTarget && inAngleLast && dLocToTarget < C.POI_TARGET_DISTANCE_THRESHOLD) {
                        navpoi = [[NavPOI alloc] initWithText:poi.name Location:nearest Options:
                                  @{
                                    @"origin": poi,
                                    @"forCorner": @(YES),
                                    @"forCornerEnd": @(poi.poiCategory == HLPPOICategoryCornerEnd),
                                    @"forCornerWarningBlock": @(poi.poiCategory == HLPPOICategoryCornerWarningBlock),
                                    @"flagPlural": @(poi.flags.flagPlural),
                                    @"longDescription": poi.longDescription?poi.longDescription:@""
                                    }];
                    }
                    break;
                default:
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
                //_isNextDestination = YES;
                if (_nextLink.length < 3) {
                    
                    navpoi = [[NavPOI alloc] initWithText:[NavDataStore sharedDataStore].to.namePron
                                                 Location:ent.facility.location Options:
                              @{
                                @"origin": ent,
                                @"forAfterEnd": @(YES),
                                @"isDestination": @(YES),
                                @"angleFromLocation": @(_nextLink.lastBearingForTarget),
                                @"longDescription":  ent.facility.longDescriptionPron
                                }];
                }
            } else if([_link.targetNodeID isEqualToString:ent.node._id]) {
                // destination with non-leaf node
                //_isNextDestination = YES;
                navpoi = [[NavPOI alloc] initWithText:[ent getLongDescription]
                                             Location:ent.node.location
                                              Options: @{
                                                         @"origin": ent,
                                                         @"isDestination": @(YES),
                                                         @"forAfterEnd": @(YES)
                                                         }];
            } else {
                // mid in route
                HLPLocation *nearest = [_link nearestLocationTo:ent.node.location];
                if (ent.facility && ent.facility.isNotRead) {
                    return; // skip no read flag facility
                }
                if ((!_isFirst && !_isNextDestination) ||
                    (_isFirst && [_link.sourceLocation distanceTo:nearest] > C.POI_ANNOUNCE_DISTANCE) ||
                    (_isNextDestination && [_link.targetLocation distanceTo:nearest] > C.POI_ANNOUNCE_DISTANCE)) {
                    if ([nearest distanceTo:ent.node.location] < 1e-3) {
                        navpoi = [[NavPOI alloc] initWithText:[ent getNamePron] Location:nearest Options:
                                  @{
                                    @"origin": ent
                                    }];
                    } else {
                        double angle = [HLPLocation normalizeDegree:[nearest bearingTo:ent.node.location] - _link.initialBearingFromSource];
                        if (45 < fabs(angle) && fabs(angle) < 135) {
                            NSString *name = [ent getNamePron];
                            if (name && [name length] > 0) {
                                navpoi = [[NavPOI alloc] initWithText:[ent getNamePron] Location:nearest Options:
                                          @{
                                            @"origin": ent,
                                            //@"longDescription": [ent getLongDescriptionPron],
                                            @"angleFromLocation": @([nearest bearingTo:ent.node.location]),
                                            @"flagOnomastic":@(YES)
                                            }];
                            }
                        }
                    }
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
    
    
    // handle door poi
    NSArray<HLPPOI*> *doors = [_allPOIs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject isKindOfClass:HLPPOI.class]) {
            return [((HLPPOI*)evaluatedObject) poiCategory] == HLPPOICategoryDoor;
        }
        return false;
    }]];
    
    if ([doors count] > 0) {
        doors = [doors sortedArrayUsingComparator:^NSComparisonResult(HLPPOI *p1, HLPPOI *p2) {
            HLPLocation *n1 = [_link nearestLocationTo:p1.location];
            HLPLocation *n2 = [_link nearestLocationTo:p2.location];
            return [@([n1 distanceTo:_sourceLocation]) compare:@([n2 distanceTo:_sourceLocation])];
        }];
        
        for(int start = 0; start < [doors count];){
            HLPLocation *locStart = [_link nearestLocationTo:doors[start].location];
            HLPLocation *locEnd = [_link nearestLocationTo:doors[start].location];
            int end = start;
            for(int i = start+1; i < [doors count]; i++) {
                HLPLocation *loc = [_link nearestLocationTo:doors[i].location];
                if ([locEnd distanceTo:loc] < 5 && doors[start].flags.flagAuto == doors[i].flags.flagAuto) {
                    locEnd = loc;
                    end = i;
                } else {
                    break;
                }
            }
            BOOL forBeforeStart = [locStart distanceTo:self.link.sourceLocation] < C.POI_START_INFO_DISTANCE_THRESHOLD;
            int count = end - start + 1;
            NavPOI *navpoi = [[NavPOI alloc] initWithText:nil Location:locStart Options:
                              @{
                                @"origin":[doors subarrayWithRange:NSMakeRange(start, count)],
                                @"forBeforeStart":@(forBeforeStart),
                                @"forDoor":@(YES),
                                @"count":@(count),
                                @"flagAuto":@(doors[start].flags.flagAuto)
                                }];
            [poisTemp addObject:navpoi];
            start = end+1;
        }
    }
    
    // handle obstacle poi
    
    NSArray<HLPPOI*> *obstacles = [_allPOIs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject isKindOfClass:HLPPOI.class]) {
            return [((HLPPOI*)evaluatedObject) poiCategory] == HLPPOICategoryObstacle;
        }
        return false;
    }]];
    
    if ([obstacles count] > C.MINIMUM_OBSTACLES_POI) {
        obstacles = [obstacles sortedArrayUsingComparator:^NSComparisonResult(HLPPOI *p1, HLPPOI *p2) {
            HLPLocation *n1 = [_link nearestLocationTo:p1.location];
            HLPLocation *n2 = [_link nearestLocationTo:p2.location];
            return [@([n1 distanceTo:_sourceLocation]) compare:@([n2 distanceTo:_sourceLocation])];
        }];
        
        for(int start = 0; start < [obstacles count];){
            HLPLocation *locStart = [_link nearestLocationTo:obstacles[start].location];
            HLPLocation *locEnd = [_link nearestLocationTo:obstacles[start].location];
            BOOL rightSide = NO;
            BOOL leftSide = NO;
            int end = start;
            for(int i = start; i < [obstacles count]; i++) {
                HLPLocation *loc = [_link nearestLocationTo:obstacles[i].location];
                double side = [HLPLocation normalizeDegree:[loc bearingTo:obstacles[i].location] - _link.initialBearingFromSource];
                if (30 < fabs(side) && fabs(side) < 150) {
                    rightSide = rightSide || (side > 0);
                    leftSide = leftSide || (side < 0);
                }
                if ([locEnd distanceTo:loc] < 5) {
                    locEnd = loc;
                    end = i;
                } else {
                    break;
                }
            }
            BOOL forBeforeStart = [locStart distanceTo:self.link.sourceLocation] < C.POI_START_INFO_DISTANCE_THRESHOLD;
            int count = end - start + 1;
            NavPOI *navpoi = [[NavPOI alloc] initWithText:nil Location:locStart Options:
                              @{
                                @"origin":[obstacles subarrayWithRange:NSMakeRange(start, count)],
                                @"forBeforeStart":@(forBeforeStart),
                                @"forObstacle":@(YES),
                                @"count":@(count),
                                @"rightSide":@(rightSide),
                                @"leftSide":@(leftSide)
                                }];
            [poisTemp addObject:navpoi];
            start = end+1;
        }
    }
    
    // handle link type as POI
    // generate POI from links
    void(^checkLinkFeatures)(NSArray*, BOOL(^)(HLPLink*), void(^)(NSRange)) =
    ^(NSArray* links, BOOL(^condition)(HLPLink*), void(^found)(NSRange)) {
        for(int start = 0; start < [links count];) {
            HLPLocation *locEnd = nil;
            int end = start;
            for(int i = start; i < [links count]; i++) {
                HLPLink *link = links[i];
                if (condition(link)) {
                    locEnd = link.targetLocation;
                    end = i;
                } else {
                    break;
                }
            }
            if (locEnd) {
                found(NSMakeRange(start, end-start+1));
            }
            start = end+1;
        }
    };
    
    // handle ramp
    checkLinkFeatures(links, ^ BOOL (HLPLink *link) {
        return link.linkType == LINK_TYPE_RAMP;
    }, ^(NSRange range) {
        NSArray *result = [links subarrayWithRange:range];
        HLPLink *link = result[0];
        [poisTemp addObject:[[NavPOI alloc] initWithText:nil Location:link.sourceLocation Options:
                             @{
                               @"origin":result,
                               @"forRamp":@(YES)
                               }]];
    });
    
    // handle Braille block
    checkLinkFeatures(links, ^ BOOL (HLPLink *link) {
        return link.brailleBlockType == HLPBrailleBlockTypeAvailable;
    }, ^(NSRange range) {
        _noBearing = YES;
        NSArray *result = [links subarrayWithRange:range];
        HLPLink *link = result[0];
        HLPLink *link2 = [result lastObject];
        [poisTemp addObject:[[NavPOI alloc] initWithText:nil Location:link.sourceLocation Options:
                             @{
                               @"origin":link,
                               @"forBrailleBlock":@(YES),
                               @"forFloor":@(range.location == 0)
                               }]];
        
        // no block
        BOOL lastLinkHasBraille = (range.location+range.length == [links count]);
        
        if (!lastLinkHasBraille || _nextLink.brailleBlockType != HLPBrailleBlockTypeAvailable) {
            [poisTemp addObject:[[NavPOI alloc] initWithText:nil Location:link2.targetLocation Options:
                                 @{
                                   @"origin":result,
                                   @"forBrailleBlock":@(YES),
                                   @"flagEnd":@(YES),
                                   @"forAfterEnd":@(lastLinkHasBraille)
                                   }]];
        }
    });
    
    // braille block is avilable after turn
    checkLinkFeatures(links, ^ BOOL (HLPLink *link) {
        return link.brailleBlockType != HLPBrailleBlockTypeAvailable;
    }, ^(NSRange range) {
        BOOL lastLinkHasNoBraille = range.location+range.length == [links count];
        if (lastLinkHasNoBraille && _nextLink.brailleBlockType == HLPBrailleBlockTypeAvailable) {
            [poisTemp addObject:[[NavPOI alloc] initWithText:nil Location:_link.targetLocation Options:
                                 @{
                                   @"origin":_nextLink,
                                   @"forBrailleBlock":@(YES)
                                   }]];
        }
    });
    
    // convert NAVCOG1/2 acc info into NavPOI
    [links enumerateObjectsUsingBlock:^(HLPLink *link, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *surroundInfo = link.properties[link.backward?@"_NAVCOG_infoFromNode2":@"_NAVCOG_infoFromNode1"];
        if (surroundInfo && [surroundInfo length] > 0) {
            NSLog(@"surroundInfo=%@", surroundInfo);
            
            HLPLocation *poiloc = link.sourceLocation;
            
            NavPOI *poi = [[NavPOI alloc] initWithText:surroundInfo Location:poiloc Options:
                           @{@"origin":surroundInfo}];
            
            [poisTemp addObject:poi];
        }
        
        NSString *nodeInfoJSON = link.properties[link.backward?@"_NAVCOG_infoAtNode1":@"_NAVCOG_infoAtNode2"];
        if (nodeInfoJSON && [nodeInfoJSON length] > 0) {
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
                
                if (info && [info length] > 0) {
                    NavPOI *poi = [[NavPOI alloc] initWithText:info Location:poiloc Options:
                                   @{@"origin":info}];
                    [poisTemp addObject:poi];
                }
                
                if (destInfo && [destInfo length] > 0) {
                    NavPOI *poi = [[NavPOI alloc] initWithText:destInfo Location:poiloc Options:
                                   @{
                                     @"origin":destInfo,
                                     @"forAfterEnd": @(YES)
                                     }];
                    [poisTemp addObject:poi];
                }
                
                if (trickyInfo && [trickyInfo length] > 0 && beTricky) {
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
            _distanceFromBackDetectedLocationToLocation = [_backDetectedLocation distanceTo:_userLocation];
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
    _forDoor = NO;
    _forObstacle = NO;
    _forRamp = NO;
    _forAfterEnd = NO;
    _flagCaution = NO;
    _flagPlural = NO;
    _flagOnomastic = NO;
    _flagEnd = NO;
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
    NSMutableArray *linkInfos;
    
    NSArray *oneHopLinks;
    
    //NSString *destination;
    //NSString *startPoint;
    NSTimeInterval lastCouldNotStartNavigationTime;
    NSTimeInterval waitingStartUntil;
    
    int navIndex;
    int lastNavIndex;
    int firstLinkIndex;
    
    NSTimer *timeoutTimer;
    
    NSTimeInterval lastElevatorResetTime;
    
    NSOperationQueue *navigationQueue;
    
    BOOL alertForHeadingAccuracy;
    HLPLocation *prevLocation;
    
    NSMutableArray *walkedDistances;
    double walkingSpeed;
}

- (instancetype)init
{
    self = [super init];
    
    _isActive = NO;
    [self reset];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:) name:ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeCleared:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStatus:) name:REQUEST_NAVIGATION_STATUS object:nil];
    
    navigationQueue = [[NSOperationQueue alloc] init];
    navigationQueue.maxConcurrentOperationCount = 1;
    navigationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
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
    lastElevatorResetTime = NAN;
}

- (void) stop
{
    _isActive = NO;
    [self.delegate didActiveStatusChanged:
     @{
       @"isActive": @(_isActive)
       }];
}

- (void)routeChanged:(NSNotification*)note
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
    
    waitingStartUntil = [[NSDate date] timeIntervalSince1970] + 1.0;
    [self reset];
    
    
    navIndex = 0;
        
    NSArray*(^collectLinks)(NSArray*) = ^(NSArray *array) {
        NSMutableArray *temp = [@[] mutableCopy];
        for(HLPObject *obj2 in array) {
            if ([obj2 isKindOfClass:HLPLink.class]) {
                HLPNode *sn = nds.nodesMap[[(HLPLink*)obj2 sourceNodeID]];
                HLPNode *tn = nds.nodesMap[[(HLPLink*)obj2 targetNodeID]];
                
                for(HLPLink *lid in sn.connectedLinkIDs) {
                    HLPLink *link = nds.linksMap[lid];
                    if (link) {
                        [link setTargetNodeIfNeeded:sn withNodesMap:nds.nodesMap];
                        if (![temp containsObject:link]) {
                            [temp addObject:link];
                        }
                    }
                }
                for(HLPLink *lid in tn.connectedLinkIDs) {
                    HLPLink *link = nds.linksMap[lid];
                    if (link) {
                        [link setTargetNodeIfNeeded:tn withNodesMap:nds.nodesMap];
                        if (![temp containsObject:link]) {
                            [temp addObject:link];
                        }
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
                        // TODO: tricky update
                        [link2 offsetTarget:-link2.length];
                        [link2 updateLastBearingForTarget:link1.lastBearingForTarget];
                        HLPLink* link12 = [[HLPCombinedLink alloc] initWithLink1:link1 andLink2:link2];
                        [temp setObject:link12 atIndexedSubscript:i];
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
                
                if (link1.isLeaf && link1.length < C.IGNORE_FIRST_LINK_LENGTH_THRESHOLD) {
                    continue;
                }
                
                if (link2.isLeaf && link2.length < C.IGNORE_LAST_LINK_LENGTH_THRESHOLD) {
                    continue;
                }
                
                if ([HLPCombinedLink link:link1 shouldBeCombinedWithLink:link2]) {
                    if (i == 1 && link1.linkType != LINK_TYPE_ELEVATOR && link2.linkType == LINK_TYPE_ELEVATOR) {
                        // avoid combining the first link with elevator
                        continue;
                    }
                    
                    HLPLink* link12 = [[HLPCombinedLink alloc] initWithLink1:link1 andLink2:link2];
                    [temp setObject:link12 atIndexedSubscript:i];
                    [temp removeObjectAtIndex:i+1];
                    i--;
                    continue;
                }
                
                if ([link1 isSafeLinkType] && link2.linkType == LINK_TYPE_RAMP &&
                    [HLPCombinedLink link:link1 canBeCombinedWithLink:link2]) {
                    HLPLink* link12 = [[HLPCombinedLink alloc] initWithLink1:link1 andLink2:link2];
                    [temp setObject:link12 atIndexedSubscript:i];
                    [temp removeObjectAtIndex:i+1];
                    i--;
                    continue;
                }
                
            }
        }
        return temp;
    };
    route = combineLinks(route);
    
    // shorten link before elevator, set bearing after elevator
    NSArray*(^shortenLinkBeforeElevator)(NSArray*) = ^(NSArray *array) {
        NSMutableArray *temp = [[NSMutableArray alloc] initWithArray:array];
        for(int i = 0; i < [temp count]-2; i++) {
            HLPObject* obj1 = temp[i];
            HLPObject* obj2 = temp[i+1];
            if ([obj1 isKindOfClass:HLPLink.class] &&
                [obj2 isKindOfClass:HLPLink.class]
                ) {
                HLPLink* link1 = (HLPLink*) obj1;
                HLPLink* link2 = (HLPLink*) obj2;
                
                if (link1.linkType != LINK_TYPE_ELEVATOR &&
                    link2.linkType == LINK_TYPE_ELEVATOR && isnan(link2.initialBearingFromSource)) {
                    [link1 offsetTarget:-2];
                }
                
                if (link1.linkType == LINK_TYPE_ELEVATOR &&
                    link2.linkType != LINK_TYPE_ELEVATOR && isnan(link1.lastBearingForTarget)) {
                    [link1 updateLastBearingForTarget: link2.initialBearingFromSource];
                    [link2 offsetSource:-2];
                }
            }
        }
        return temp;
    };
    route = shortenLinkBeforeElevator(route);
    
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
            
            NSMutableSet *linkPois = [[NSMutableSet alloc] init];
            if (!isFirstLink) {
                [linkPois addObjectsFromArray:nds.linkPoiMap[link1._id]];
                if ([link1 isKindOfClass:HLPCombinedLink.class]) {
                    for(HLPLink *link in [(HLPCombinedLink*) link1 links]) {
                        [linkPois addObjectsFromArray:nds.linkPoiMap[link._id]];
                    }
                }
            }
            
            linkInfos[i] = [[NavLinkInfo alloc] initWithLink:link1 nextLink:link2 andOptions:
                            @{
                              @"allPOIs": [linkPois allObjects],
                              @"isFirst": @(i == firstLinkIndex)
                              }];
        }
    }
    
    _isActive = YES;
    
    NavLinkInfo *info = linkInfos[firstLinkIndex];
    
    [self.delegate didActiveStatusChanged:
     @{
       @"isActive": @(_isActive),
       @"location":info.link.sourceLocation,
       @"heading":@(info.link.initialBearingFromSource)
       }];
    
    [info updateWithLocation:[nds currentLocation]];
    if (info.distanceToUserLocationFromLink > C.OFF_ROUTE_THRESHOLD) {
        HLPLink *dummyLink = [[HLPLink alloc] initWithSource:[nds currentLocation] Target:info.snappedLocationOnLink];
        NavLinkInfo *dummy = [[NavLinkInfo alloc] initWithLink:dummyLink nextLink:info.link andOptions:
                              @{@"isFirst": @(YES)}];
        [linkInfos insertObject:dummy atIndex:firstLinkIndex];
        info.isFirst = NO;
        info = dummy;
    }
    
    [self setTimeout:1 withBlock:^{
        [[NavDataStore sharedDataStore] manualLocation:nil];
    }];
}

- (void)setTimeout:(double)delay withBlock:(void(^)()) block
{
    if (![NavDataStore sharedDataStore].previewMode) {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if (block) {
                [navigationQueue addOperationWithBlock:block];
            }
        });
    }
}

- (void)routeCleared:(NSNotification*)note
{
    [self stop];
}

- (void)_locationChanged:(NSNotification*)note
{
    BOOL isManualLocation = [NavDataStore sharedDataStore].isManualLocation;
    BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
    if (!isManualLocation || devMode) {
        [navigationQueue addOperationWithBlock:^{
            [self locationChanged:note];
        }];
    }
}

- (void)locationChanged:(NSNotification*)note
{
    if (!_isActive) {
        if (alertForHeadingAccuracy) {
            HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
            if (!prevLocation) {
                prevLocation = location;
            } else {
                if (location.orientationAccuracy < 22.5) {
                    if ([self.delegate respondsToSelector:@selector(requiresHeadingCalibration:)]) {
                        [self.delegate requiresHeadingCalibration:
                         @{
                           @"accuracy": @(location.orientationAccuracy),
                           @"nohistory": @(YES),
                           @"force": @(YES)
                           }];
                    }
                    alertForHeadingAccuracy = NO;
                    return;
                }
                int prev = prevLocation.orientationAccuracy / 20;
                int now = location.orientationAccuracy / 20;
                if (prev > now) {
                    int level = MIN(3,4-now);
                    // play 1 for 70-90
                    // play 2 for 50-70
                    // play 3 for 22.5-50
                    [self.delegate playHeadingAdjusted:level];
                    prevLocation = location;
                }
            }
        }
        return;
    }
    
    if (timeoutTimer) {
        [timeoutTimer invalidate];
        [self setTimeout:1 withBlock:^(NSTimer * _Nonnull timer) {
            [[NavDataStore sharedDataStore] manualLocation:nil];
        }];
    }
    
    if (lastNavIndex != navIndex) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NAV_ROUTE_INDEX_CHANGED_NOTIFICATION object:self userInfo:@{@"index":@(navIndex)}];
    }
    lastNavIndex = navIndex;
    
    NavNavigatorConstants *C = [NavNavigatorConstants constants];
    
    double(^nextTargetRemainingDistance)(double, double) = ^(double dist, double linkLength) {
        double target =  floor((dist - C.PREVENT_REMAINING_DISTANCE_EVENT_FOR_FIRST_N_METERS) / C.REMAINING_DISTANCE_INTERVAL)*C.REMAINING_DISTANCE_INTERVAL;
        return target;
    };
    
    @try {
        HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
        if (isnan(location.lat) || isnan(location.lng)) {
            return;
        }

        if (!_isActive) { // return if navigation is not active
            return;
        }
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (waitingStartUntil > now) {
            return;
        }
        
        if (!prevLocation) {
            prevLocation = location;
        } else {
            double d = [prevLocation distanceTo:location];
            if (!walkedDistances) {
                walkedDistances = [@[] mutableCopy];
            }
            [walkedDistances insertObject:@(d) atIndex:0];
            int MAX_WD = 30;
            if (walkedDistances.count > MAX_WD) {
                [walkedDistances removeLastObject];
                
                double ave = 0;
                for(NSNumber *wd in walkedDistances) {
                    ave += [wd doubleValue];
                }
                walkingSpeed = MAX(ave / MAX_WD * 10, 2.0);
            }
            prevLocation = location;
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
                (
                 (fabs(location.floor - info.link.sourceHeight) < C.FLOOR_DIFF_THRESHOLD &&
                  fabs(location.floor - info.link.targetHeight) < C.FLOOR_DIFF_THRESHOLD) ||
                 ((info.link.linkType == LINK_TYPE_ELEVATOR ||
                   info.link.linkType == LINK_TYPE_ESCALATOR ||
                   info.link.linkType == LINK_TYPE_STAIRWAY) &&
                  (fabs(location.floor - info.link.sourceHeight) < C.FLOOR_DIFF_THRESHOLD ||
                   fabs(location.floor - info.link.targetHeight) < C.FLOOR_DIFF_THRESHOLD))
                 )
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
            NavLinkInfo *firstLinkInfo = linkInfos[firstLinkIndex];
            // TODO improve length from current location not from existing node
            
            double (^lengthOfRoute)() = ^(){
                double total = 0;
                for(NSInteger i=firstLinkIndex; i < [linkInfos count]; i++) {
                    NavLinkInfo *info = [linkInfos objectAtIndex:i];
                    if ([info isEqual:[NSNull null]]) {
                        continue;
                    }
                    total += info.link.length;
                    if (info.isNextDestination) {
                        break;
                    }
                }
                return total;
            };
            
            double totalLength = lengthOfRoute();
            if ([self.delegate respondsToSelector:@selector(didNavigationStarted:)]) {
                [self.delegate didNavigationStarted:
                 @{
                   @"pois":firstLinkInfo.pois,
                   @"totalLength":@(totalLength),
                   @"oneHopLinks":oneHopLinks
                   }];
            }
            
            //TODO add fix protocol with lower accuracy
            double diffHeading = firstLinkInfo.diffBearingAtSnappedLocationOnLink;
            if (fabs(diffHeading) > C.CHANGE_HEADING_THRESHOLD) {
                if (!firstLinkInfo.hasBeenBearing && !firstLinkInfo.hasBeenActivated) {
                    firstLinkInfo.hasBeenBearing = YES;
                    firstLinkInfo.bearingTargetThreshold = C.CHANGE_HEADING_THRESHOLD;
                    if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
                        [self.delegate userNeedsToChangeHeading:
                         @{
                           @"diffHeading": @(diffHeading),
                           @"threshold": @(C.CHANGE_HEADING_THRESHOLD),
                           @"looseDirection": @(YES)
                           }];
                    }
                }
            }
            
            isFirst = NO;
        }
        
        // check user skip some states
        if (navIndex < minIndex) {
            NavLinkInfo *current = linkInfos[navIndex];
            if (current && ![current isEqual:[NSNull null]] &&
                current.distanceToUserLocationFromLink / MAX(1.0, minDistance) > 3) {
                navIndex = minIndex;
                return;
            }
        }
        
        
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
                    double distance = MAX((walkingSpeed-1) * C.APPROACHED_DISTANCE_THRESHOLD, 0);
                    return MIN(C.APPROACHING_DISTANCE_THRESHOLD + distance, linkInfo.link.length/2);
                }
            };
            double(^approachedDistance)(NavLinkInfo*) = ^(NavLinkInfo* linkInfo_){
                if (linkInfo_.link.linkType == LINK_TYPE_ESCALATOR || linkInfo_.link.linkType == LINK_TYPE_STAIRWAY) {
                    return C.APPROACHED_DISTANCE_THRESHOLD;
                } else {
                    // quick fix: adjust approached distance with user's walaking speed
                    double distance = walkingSpeed * C.APPROACHED_DISTANCE_THRESHOLD;
                    return MAX(MIN(distance, linkInfo_.link.length/4), 0.6);
                }
            };
            NSLog(@"ApproachDistance,%.2f,%.2f,%.2f,%.2f",linkInfo.distanceToTargetFromSnappedLocationOnLink,walkingSpeed,approachingDistance(),approachedDistance(linkInfo));
            
            if (linkInfo.link.linkType != LINK_TYPE_ELEVATOR) {
                
                // user may be off route
                if (minDistance < DBL_MAX && (minDistance > C.OFF_ROUTE_THRESHOLD || linkInfo.mayBeOffRoute)) {
                    int exMinIndex = -1;
                    double exMinDistance = DBL_MAX;
                    NavLinkInfo *exMinLinkInfo = nil;
                    
                    if (!linkInfo.offRouteLinkInfo) {
                        for(int i = 0; i < [oneHopLinks count]; i++) {
                            if ([oneHopLinks[i] isKindOfClass:HLPLink.class]) {
                                HLPLink* link1 = (HLPLink*)oneHopLinks[i];
                                NavLinkInfo *info = [[NavLinkInfo alloc] initWithLink:link1 nextLink:nil andOptions:nil];
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
                    //if (linkInfo.distanceToTargetFromSnappedLocationOnLink < C.OFF_ROUTE_EXT_LINK_THRETHOLD ||
                    //    linkInfo.distanceToSourceFromSnappedLocationOnLink < C.OFF_ROUTE_EXT_LINK_THRETHOLD) {
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
                    //else if (minIndex == navIndex && minDistance >= C.OFF_ROUTE_THRESHOLD) {
                    
                    
                    // TODO: 不明な場所で、現在のリンクが一番近い -> 戻すことを試みる
                    // linkInfo.mayBeOffRoute = YES;
                    // リンクに近づける方角をアナウンス
                    //}
                    else if (minDistance > C.REROUTE_DISTANCE_THRESHOLD) {
                        if (linkInfo.lastRerouteDetected && (now - linkInfo.lastRerouteDetected) > 10) {
                            linkInfo.lastRerouteDetected = now + 10;
                            if ([self.delegate respondsToSelector:@selector(reroute:)]) {
                                [self.delegate reroute:@{}];
                            }
                        } else if (!linkInfo.lastRerouteDetected) {
                            linkInfo.lastRerouteDetected = now;
                        }
                    } else {
                        linkInfo.lastRerouteDetected = 0;
                    }
                    //}
                    
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
                                   @"linkType": @(linkInfo.link.linkType)
                                   }];
                            }
                        } else if (linkInfo.offRouteLinkInfo.distanceToTargetFromSnappedLocationOnLink < approachedDistance(linkInfo.offRouteLinkInfo) &&
                                   !linkInfo.hasBeenWaitingAction) {
                            linkInfo.mayBeOffRoute = NO;
                            
                            
                            if (linkInfo.distanceToTargetFromUserLocation < C.OFF_ROUTE_EXT_LINK_THRETHOLD) {
                                linkInfo.hasBeenWaitingAction = YES;
                                linkInfo.offRouteLinkInfo = nil;
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
                            } else {
                                linkInfo.hasBeenBearing = YES;
                                linkInfo.bearingTargetThreshold = C.ADJUST_HEADING_MARGIN;
                                linkInfo.hasBeenActivated = NO;
                                
                                if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                                    [self.delegate userNeedsToTakeAction:
                                     @{
                                       @"turnAngle": @(linkInfo.diffBearingAtSnappedLocationOnLink),
                                       @"threshold": @(0)
                                       }];
                                }
                            }
                            
                        } else if (linkInfo.offRouteLinkInfo.distanceToUserLocationFromLink / MAX(1,linkInfo.distanceToUserLocationFromLink) > 3) {
                            // back to route
                            linkInfo.mayBeOffRoute = NO;
                        }
                        return;
                    }
                    // 途中で勝手に曲がった
                    // bearingで処理
                }
                
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
                                minLinkInfo.distanceFromBackDetectedLocationToLocation > C.BACK_DETECTION_THRESHOLD) {
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
            }
            
            
            if (linkInfo.hasBeenWaitingAction) {
                if (linkInfo.nextLink.linkType == LINK_TYPE_ELEVATOR ||
                    (navIndex == 1 && linkInfo.link.linkType == LINK_TYPE_ELEVATOR)) {
                    navIndex++;
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"stabilize_localize_on_elevator"]) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_STABILIZE_LOCALIZE object:self];
                    }
                }
                else if (fabs(linkInfo.diffNextBearingAtSnappedLocationOnLink) < C.ADJUST_HEADING_MARGIN) {
                    if ([self.delegate respondsToSelector:@selector(userAdjustedHeading:)]) {
                        [self.delegate userAdjustedHeading:@{}];
                    }
                    navIndex++;
                }
                
                return;
            }
            
            HLPLocation*(^elevatorLocation)(HLPLink*) = ^(HLPLink *link) {
                if ([link isKindOfClass:HLPCombinedLink.class]) {
                    HLPCombinedLink *clink = ((HLPCombinedLink*)link);
                    for(HLPLink *l in clink.links) {
                        if (l.linkType == LINK_TYPE_ELEVATOR) {
                            return l.targetLocation;
                        }
                    }
                }
                if ([link isKindOfClass:HLPLink.class]) {
                    return link.targetLocation;
                }
                return (HLPLocation*)nil;
            };
            
            if (linkInfo.link.linkType == LINK_TYPE_ELEVATOR) {
                if (fabs(linkInfo.link.targetHeight - location.floor) < C.FLOOR_DIFF_THRESHOLD) {
                    if (linkInfo.isNextDestination) { // elevator is the destination
                        if ([self.delegate respondsToSelector:@selector(didNavigationFinished:)]) {
                            [self.delegate didNavigationFinished:
                             @{
                               @"isEndOfLink": @(linkInfo.nextLink == nil),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight)
                               }];
                            
                        }
                        navIndex = (int)[linkInfos count];
                    } else { // arrived the target floor
                        linkInfo.hasBeenWaitingAction = YES;
                        if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                            [self.delegate userNeedsToTakeAction:
                             @{
                               @"turnAngle": @(linkInfo.nextTurnAngle),
                               @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                               @"linkType": @(linkInfo.link.linkType),
                               @"nextLinkType": @(linkInfo.nextLink.linkType),
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight),
                               @"distance": @(linkInfo.link.length)
                               }];
                        }
                        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_at_elevator"]) {
                            HLPLocation *loc = elevatorLocation(linkInfo.link);
                            [loc updateLat:loc.lat Lng:loc.lng Accuracy:0 Floor:NAN];
                            
                            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:self userInfo:@{@"location":loc}];
                            lastElevatorResetTime = NAN;
                        }
                        
                        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"stabilize_localize_on_elevator"]) {
                            [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_STABILIZE_LOCALIZE object:self];
                        }
                    }
                } else {
                    NavPOI*(^findElevatorPOI)(NSArray*, HLPPOICategory) = ^(NSArray *array, HLPPOICategory category) {
                        for(NavPOI *poi in array) {
                            if ([poi.origin isKindOfClass:HLPPOI.class] && [poi.origin poiCategory] == category) {
                                return poi;
                            }
                        }
                        return (NavPOI*)nil;
                    };
                    
                    NavPOI *elevatorPOI = findElevatorPOI(linkInfo.pois, HLPPOICategoryElevator);
                    // if elevator poi is assigned to elevator link
                    if (elevatorPOI && !elevatorPOI.hasBeenApproached) {
                        if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                            [self.delegate userIsApproachingToPOI:
                             @{
                               @"poi": elevatorPOI,
                               @"heading": @(elevatorPOI.diffAngleFromUserOrientation)
                               }];
                            elevatorPOI.hasBeenApproached = YES;
                        }
                    }
                    
                    NavPOI *equipmentPOI = findElevatorPOI(linkInfo.pois, HLPPOICategoryElevatorEquipments);
                    
                    if (isnan(linkInfo.link.lastBearingForTarget)) { // elevator is the destination
                        if (!linkInfo.hasBeenApproaching) {
                            if (equipmentPOI) {
                                if ([self.delegate respondsToSelector:@selector(userGetsOnElevator:)]) {
                                    [self.delegate userGetsOnElevator:
                                     @{
                                       @"poi":equipmentPOI,
                                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight)
                                       }];
                                }
                            } else {
                                if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                                    [self.delegate remainingDistanceToTarget:
                                     @{
                                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight)
                                       }];
                                }
                            }
                            linkInfo.hasBeenApproaching = YES;
                        }
                    } else {
                        
                        // face to the exit after getting in the elevator
                        if (fabs(linkInfo.link.lastBearingForTarget-location.orientation) < 45 &&
                            !linkInfo.hasBeenApproaching) {
                            if (equipmentPOI) {
                                if ([self.delegate respondsToSelector:@selector(userGetsOnElevator:)]) {
                                    [self.delegate userGetsOnElevator:
                                     @{
                                       @"poi": equipmentPOI,
                                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight)
                                       }];
                                }
                            } else {
                                if ([self.delegate respondsToSelector:@selector(userGetsOnElevator:)]) {
                                    [self.delegate userGetsOnElevator:
                                     @{
                                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight)
                                       }];
                                }
                            }
                            linkInfo.hasBeenApproaching = YES;
                            lastElevatorResetTime = now;
                            
                        } else if (!linkInfo.hasBeenActivated) {
                            // only for preview
                            double distance = C.APPROACHED_DISTANCE_THRESHOLD+2;
                            double previewSpeed = [[NSUserDefaults standardUserDefaults] doubleForKey:@"preview_speed"];
                            double delayInSeconds = (distance / 0.2) * (1.0 / previewSpeed) * 1.5;
                            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
                                if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                                    [self.delegate remainingDistanceToTarget:
                                     @{
                                       @"diffHeading": @(linkInfo.link.lastBearingForTarget-loc.orientation)
                                       }];
                                }
                            });
                            if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                                [self.delegate remainingDistanceToTarget:
                                 @{
                                   @"distance": @(distance)
                                   }];
                            }
                            /*
                             if (elevatorPOI) {
                             if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                             [self.delegate userIsApproachingToPOI:
                             @{
                             @"poi": elevatorPOI,
                             @"heading": @(NAN)
                             }];
                             }
                             }
                             */
                            linkInfo.hasBeenActivated = YES;
                        }
                    }
                    if (navIndex == 1) {
                        // starts at elevator
                        linkInfo.hasBeenWaitingAction = YES;
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
                    
                    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_at_elevator_continuously"]) {
                        if (!isnan(lastElevatorResetTime) && now - lastElevatorResetTime > 1.9) {
                            HLPLocation *loc = elevatorLocation(linkInfo.link);
                            [loc updateLat:loc.lat Lng:loc.lng Accuracy:0 Floor:NAN];
                            
                            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:self userInfo:@{@"location":loc}];
                            lastElevatorResetTime = now;
                        }
                    }
                }
                return;
            }
            
            if (linkInfo.link.length < C.NO_APPROACHING_DISTANCE_THRESHOLD) {
                linkInfo.hasBeenApproaching = YES;
            }
            
            if (linkInfo.hasBeenBearing) {
                BOOL bearing_for_demo = [[NSUserDefaults standardUserDefaults] boolForKey:@"bearing_for_demo"];
                
                if ((!bearing_for_demo && fabs(linkInfo.diffBearingAtUserLocation) < linkInfo.bearingTargetThreshold) ||
                    (bearing_for_demo && fabs(linkInfo.diffBearingAtSnappedLocationOnLink) < linkInfo.bearingTargetThreshold)) {
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
                           @"isFirst": @(navIndex == firstLinkIndex),
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
            
            if (!linkInfo.hasBeenActivated && linkInfo.distanceToUserLocationFromLink < C.OFF_ROUTE_THRESHOLD) {
                
                linkInfo.hasBeenActivated = YES;
                if ([self.delegate respondsToSelector:@selector(userNeedsToWalk:)]) {
                    
                    double distance = linkInfo.link.length;
                    if (fabs(linkInfo.distanceToTargetFromUserLocation - distance) > 2) {
                        distance = linkInfo.distanceToTargetFromUserLocation;
                    }
                    if (linkInfo.offRouteLinkInfo) {
                        linkInfo.offRouteLinkInfo = nil;
                        distance = linkInfo.distanceToTargetFromSnappedLocationOnLink;
                    }
                    
                    double noAndTurnMinDistance = C.NO_ANDTURN_DISTANCE_THRESHOLD;
                    if (linkInfo.nextLink.linkType == LINK_TYPE_ESCALATOR ||
                        linkInfo.nextLink.linkType == LINK_TYPE_ELEVATOR ||
                        linkInfo.nextLink.linkType == LINK_TYPE_STAIRWAY) {
                        noAndTurnMinDistance = NAN;
                    }
                    
                    [self.delegate userNeedsToWalk:
                     @{
                       @"pois": linkInfo.pois,
                       @"isFirst": @(navIndex == firstLinkIndex),
                       @"distance": @(distance),
                       @"noAndTurnMinDistance": @(noAndTurnMinDistance),
                       @"linkType": @(linkInfo.link.linkType),
                       @"nextLinkType": @(linkInfo.nextLink.linkType),
                       @"turnAngle": @(linkInfo.nextTurnAngle),
                       @"isNextDestination": @(linkInfo.isNextDestination),
                       @"sourceHeight": @(linkInfo.link.sourceHeight),
                       @"targetHeight": @(linkInfo.link.targetHeight),
                       @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                       @"nextTargetHeight": @(linkInfo.nextLink.targetHeight),
                       @"escalatorFlags": linkInfo.nextLink.escalatorFlags?linkInfo.nextLink.escalatorFlags:@[]
                       
                       }];
                }
                linkInfo.nextTargetRemainingDistance = nextTargetRemainingDistance(linkInfo.link.length, linkInfo.link.length);
                
                return;
            }
            
            if (linkInfo.nextTargetRemainingDistance > C.APPROACHED_DISTANCE_THRESHOLD &&
                linkInfo.distanceToTargetFromSnappedLocationOnLink <
                linkInfo.nextTargetRemainingDistance + C.APPROACHED_DISTANCE_THRESHOLD) {
                if ([self.delegate respondsToSelector:@selector(remainingDistanceToTarget:)]) {
                    [self.delegate remainingDistanceToTarget:
                     @{
                       @"target": @(YES),
                       @"distance": @(linkInfo.nextTargetRemainingDistance),
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
                               @"pois": (linkInfo.link.length>C.NO_APPROACHING_DISTANCE_THRESHOLD)?linkInfo.pois:@[],
                               @"turnAngle": @(linkInfo.nextTurnAngle),
                               @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                               @"linkType": @(linkInfo.link.linkType),
                               @"sourceHeight": @(linkInfo.link.sourceHeight),
                               @"targetHeight": @(linkInfo.link.targetHeight),
                               @"nextLinkType": @(linkInfo.nextLink.linkType),
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nextTargetHeight": @(linkInfo.nextLink.targetHeight),
                               @"fullAction": @(YES)
                               }];
                        }
                        linkInfo.hasBeenWaitingAction = YES;
                    }
                    
                    // read destInfo
                    for(int i = 0; i < [linkInfo.pois count]; i++) {
                        NavPOI *poi = linkInfo.pois[i];
                        
                        if (!poi.forAfterEnd) {
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
                } else {
                    if ([self.delegate respondsToSelector:@selector(didNavigationFinished:)]) {
                        [self.delegate didNavigationFinished:
                         @{
                           @"pois": linkInfo.pois,
                           @"isEndOfLink": @(linkInfo.nextLink == nil)
                           }];
                    }
                    navIndex = (int)[linkInfos count];
                }
                
                return;
            }
            
            
            // check distance to POI and read if it's close
            
            for(int i = 0; i < [linkInfo.pois count]; i++) {
                NavPOI *poi = linkInfo.pois[i];
                
                if (poi.forBeforeStart || poi.forWelcome || poi.forCorner || poi.forFloor) {
                    continue;
                }
                
                if (poi.forAfterEnd) {
                    continue;
                }
                
                if (!poi.hasBeenApproached && (now - poi.lastApproached > C.POI_ANNOUNCE_MIN_INTERVAL)) {
                    if (poi.distanceFromSnappedLocation < C.POI_ANNOUNCE_DISTANCE &&
                        poi.distanceFromUserLocation < C.POI_ANNOUNCE_DISTANCE &&
                        ([linkInfo.link.targetLocation distanceTo:poi.poiLocation] > C.POI_ANNOUNCE_DISTANCE ||
                         poi.forDoor || poi.forRamp || poi.forObstacle || poi.forBrailleBlock
                         )
                        ) {
                        if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                            [self.delegate userIsApproachingToPOI:
                             @{
                               @"poi": poi,
                               @"heading": @(poi.diffAngleFromUserOrientation)
                               }];
                            poi.hasBeenApproached = YES;
                            poi.hasBeenLeft = NO;
                            poi.lastApproached = now;
                            poi.countApproached++;
                        }
                    }
                } else {
                    if (!poi.hasBeenLeft) {
                        if (poi.distanceFromSnappedLocation > C.POI_ANNOUNCE_DISTANCE &&
                            poi.distanceFromUserLocation > C.POI_ANNOUNCE_DISTANCE) {
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
            
            
            
            if (!linkInfo.hasBeenBearing && !linkInfo.noBearing) {
                
                BOOL bearing_for_demo = [[NSUserDefaults standardUserDefaults] boolForKey:@"bearing_for_demo"];
                
                if (bearing_for_demo) {
                    if (fabs(linkInfo.diffBearingAtSnappedLocationOnLink) > 20 &&
                        linkInfo.distanceToTargetFromSnappedLocationOnLink > 2) {
                        if (linkInfo.lastBearingDetected == 0) {
                            linkInfo.lastBearingDetected = now;
                        }
                        
                        if (now - linkInfo.lastBearingDetected > 0.5 &&
                            fabs(linkInfo.diffBearingAtSnappedLocationOnLink) < 60
                            ) {
                            //NSLog(@"needs to bearing: %f degree", linkInfo.diffBearingAtUserLocation);
                            if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
                                [self.delegate userNeedsToChangeHeading:
                                 @{
                                   @"diffHeading": @(linkInfo.diffBearingAtSnappedLocationOnLink),
                                   @"threshold": @(0)
                                   }];
                            }
                            linkInfo.hasBeenBearing = YES;
                            linkInfo.bearingTargetThreshold = fabs(linkInfo.diffBearingAtSnappedLocationOnLink / 2);
                            linkInfo.lastBearingDetected = 0;
                        }
                    } else {
                        linkInfo.lastBearingDetected = 0;
                    }
                } else if (walkingSpeed > 0) {
                    double BEARING_TARGET_DISTANCE = 20;
                    double BEARING_DIFF_THRETHOLD = 2.0;
                    double BEARING_DURATION_FACTOR = 0.1;
                    double BEARING_NOTIFY_WAIT = 0.0; // 3.0;
                    
                    double distance = MIN(BEARING_TARGET_DISTANCE, linkInfo.distanceToTargetFromUserLocation);
                    
                    HLPLocation *bearingTarget = [linkInfo.userLocation offsetLocationByDistance:distance Bearing:[linkInfo.userLocation bearingTo:linkInfo.targetLocation]];
                    
                    HLPLocation *predicted = [linkInfo.userLocation offsetLocationByDistance:distance Bearing:linkInfo.userLocation.orientation];
                    
                    double diffBearingDistance = [bearingTarget distanceTo:predicted];
                    double bearingThreshold = BEARING_DIFF_THRETHOLD + distance / walkingSpeed * BEARING_DURATION_FACTOR;
                    if (diffBearingDistance > bearingThreshold) {
                        if (linkInfo.lastBearingDetected == 0) {
                            linkInfo.lastBearingDetected = now;
                        }
                        
                        if (now - linkInfo.lastBearingDetected > BEARING_NOTIFY_WAIT &&
                            linkInfo.diffBearingAtUserLocation < 60
                            ) {
                            //NSLog(@"needs to bearing: %f degree", linkInfo.diffBearingAtUserLocation);
                            if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
                                [self.delegate userNeedsToChangeHeading:
                                 @{
                                   @"diffHeading": @(linkInfo.diffBearingAtUserLocation),
                                   @"threshold": @(0)
                                   }];
                            }
                            linkInfo.hasBeenBearing = YES;
                            linkInfo.bearingTargetThreshold = fabs(linkInfo.diffBearingAtUserLocation / 2);
                            linkInfo.lastBearingDetected = 0;
                        }
                    } else {
                        linkInfo.lastBearingDetected = 0;
                    }
                }
            }
            
            return;
        }
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}

- (NSInteger)numberOfSummary
{
    int count = 0;
    for(int i = 0; i < [linkInfos count]; i++) {
        id obj = linkInfos[i];
        if ([obj isKindOfClass:NavLinkInfo.class]) {
            NavLinkInfo *info = (NavLinkInfo*)obj;
            count++;
            if (info.isNextDestination) {
                count++;
                break;
            }
        }
    }
    return count;
}

- (NSInteger)currentIndex
{
    int count = 0;
    for(int i = 0; i < [linkInfos count]; i++) {
        id obj = linkInfos[i];
        if ([obj isKindOfClass:NavLinkInfo.class]) {
            NavLinkInfo *info = (NavLinkInfo*)obj;
            if (info.hasBeenActivated) {
                count++;
            } else {
                break;
            }
            if (info.isNextDestination) {
                break;
            }

        }
    }
    return count;
}


- (NSString *)summaryAtIndex:(NSInteger)index
{
    NavNavigatorConstants *C = [NavNavigatorConstants constants];
    int count = 0;
    for(int i = 0; i < [linkInfos count]; i++) {
        id obj = linkInfos[i];
        if ([obj isKindOfClass:NavLinkInfo.class]) {
            NavLinkInfo *linkInfo = (NavLinkInfo*)obj;
            if (index == count) {
                if ([self.delegate respondsToSelector:@selector(summaryString:)]) {
                    double distance = linkInfo.link.length;
                    double noAndTurnMinDistance = C.NO_ANDTURN_DISTANCE_THRESHOLD;
                    if (linkInfo.nextLink.linkType == LINK_TYPE_ESCALATOR ||
                        linkInfo.nextLink.linkType == LINK_TYPE_ELEVATOR ||
                        linkInfo.nextLink.linkType == LINK_TYPE_STAIRWAY) {
                        noAndTurnMinDistance = NAN;
                    }
                    
                    return [self.delegate summaryString:
                            @{
                              @"pois": linkInfo.pois,
                              @"isFirst": @(navIndex == firstLinkIndex),
                              @"distance": @(distance),
                              @"noAndTurnMinDistance": @(noAndTurnMinDistance),
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
            count++;
        }
    }
    return nil;
}

- (void) requestStatus:(NSNotification*)note
{
    if (!_isActive) {
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        if ([self.delegate respondsToSelector:@selector(requiresHeadingCalibration:)]) {
            [self.delegate requiresHeadingCalibration:
             @{
               @"noLocation": @(isnan(loc.lat) || isnan(loc.lng)),
               @"accuracy": @(loc.orientationAccuracy),
               @"nohistory": @(YES),
               @"force": @(YES)
               }];
        }
        if (loc.orientationAccuracy > 22.5) {
            alertForHeadingAccuracy = YES;
        }
        return;
    }
    //NavNavigatorConstants *C = [NavNavigatorConstants constants];
    
    id obj = linkInfos[navIndex];
    if (obj && [obj isKindOfClass:NavLinkInfo.class]) {
        NavLinkInfo *linkInfo = (NavLinkInfo*)obj;
        HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
        [linkInfo updateWithLocation:location];
        double distance = linkInfo.distanceToTargetFromUserLocation;
        
        if ([self.delegate respondsToSelector:@selector(currentStatus:)]) {
            
            if (linkInfo.link.linkType == LINK_TYPE_ELEVATOR) {
                
                NavPOI*(^findElevatorPOI)(NSArray*, HLPPOICategory) = ^(NSArray *array, HLPPOICategory category) {
                    for(NavPOI *poi in array) {
                        if ([poi.origin isKindOfClass:HLPPOI.class] && [poi.origin poiCategory] == category) {
                            return poi;
                        }
                    }
                    return (NavPOI*)nil;
                };
                
                NavPOI *elevatorPOI = findElevatorPOI(linkInfo.pois, HLPPOICategoryElevator);
                NavPOI *equipmentPOI = findElevatorPOI(linkInfo.pois, HLPPOICategoryElevatorEquipments);
                
                if (linkInfo.hasBeenWaitingAction) { // getting off elevator
                    [self.delegate currentStatus:
                     @{
                       @"turnAngle": @(linkInfo.nextTurnAngle),
                       @"diffHeading": @(linkInfo.diffNextBearingAtSnappedLocationOnLink),
                       @"linkType": @(linkInfo.link.linkType),
                       @"distance": @(linkInfo.link.length),
                       @"nohistory": @(YES),
                       @"force": @(YES)
                       
                       }];
                } else if (linkInfo.hasBeenApproaching) { // on elevator
                    if (equipmentPOI) {
                        if ([self.delegate respondsToSelector:@selector(userGetsOnElevator:)]) {
                            [self.delegate userGetsOnElevator:
                             @{
                               @"poi": equipmentPOI,
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nohistory": @(YES),
                               @"force": @(YES)
                               
                               }];
                        }
                    } else {
                        if ([self.delegate respondsToSelector:@selector(userGetsOnElevator:)]) {
                            [self.delegate userGetsOnElevator:
                             @{
                               @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                               @"nohistory": @(YES),
                               @"force": @(YES)
                               
                               }];
                        }
                    }
                    
                } else if (linkInfo.hasBeenActivated) { // waiting
                    if ([self.delegate respondsToSelector:@selector(userNeedsToTakeAction:)]) {
                        [self.delegate userNeedsToTakeAction:
                         @{
                           @"nextLinkType": @(linkInfo.link.linkType),
                           @"nextSourceHeight": @(linkInfo.link.sourceHeight),
                           @"nextTargetHeight": @(linkInfo.link.targetHeight),
                           @"fullAction": @(YES),
                           @"nohistory": @(YES),
                           @"force": @(YES)

                           }];
                    }

                    if (elevatorPOI) {
                        if ([self.delegate respondsToSelector:@selector(userIsApproachingToPOI:)]) {
                            [self.delegate userIsApproachingToPOI:
                             @{
                               @"poi": elevatorPOI,
                               @"heading": @(elevatorPOI.diffAngleFromUserOrientation),
                               @"nohistory": @(YES),
                               @"force": @(NO)
                               
                               }];
                            elevatorPOI.hasBeenApproached = YES;
                        }
                    }
                }
                
            } else { // non elevator link
                
                if (linkInfo.distanceToUserLocationFromLink > 3) {
                    [self.delegate currentStatus:
                     @{
                       @"offRoute": @(YES),
                       @"diffHeading": @(linkInfo.diffBearingAtUserLocationToSnappedLocationOnLink),
                       @"distance": @(linkInfo.distanceToUserLocationFromLink),
                       @"nohistory": @(YES),
                       @"force": @(YES)
                       }];
                    
                } else {
                    if (linkInfo.hasBeenWaitingAction) {
                        [self.delegate currentStatus:
                         @{
                           @"turnAngle": @(linkInfo.nextTurnAngle),
                           @"nohistory": @(YES),
                           @"force": @(YES)
                           
                           }];
                    }
                    else if (fabs(linkInfo.diffBearingAtUserLocation) > 22.5) {
                        linkInfo.bearingTargetThreshold = 22.5;
                        linkInfo.hasBeenBearing = YES;
                        if ([self.delegate respondsToSelector:@selector(userNeedsToChangeHeading:)]) {
                            [self.delegate userNeedsToChangeHeading:
                             @{
                               @"diffHeading": @(linkInfo.diffBearingAtUserLocation),
                               @"threshold": @(linkInfo.bearingTargetThreshold),
                               @"nohistory": @(YES),
                               @"force": @(YES)
                               
                               }];
                        }
                    }
                    else {
                        [self.delegate currentStatus:
                         @{
                           @"pois": linkInfo.pois,
                           @"distance": @(distance),
                           @"linkType": @(linkInfo.link.linkType),
                           @"nextLinkType": @(linkInfo.nextLink.linkType),
                           @"turnAngle": @(linkInfo.nextTurnAngle),
                           @"isNextDestination": @(linkInfo.isNextDestination),
                           @"sourceHeight": @(linkInfo.link.sourceHeight),
                           @"targetHeight": @(linkInfo.link.targetHeight),
                           @"nextSourceHeight": @(linkInfo.nextLink.sourceHeight),
                           @"nextTargetHeight": @(linkInfo.nextLink.targetHeight),
                           @"escalatorFlags": linkInfo.nextLink.escalatorFlags?linkInfo.nextLink.escalatorFlags:@[],
                           @"nohistory": @(YES),
                           @"force": @(YES)
                           }];
                    }
                }
            }
        }
    }
}

@end

