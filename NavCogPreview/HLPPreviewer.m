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

#import "HLPPreviewer.h"
#import "NavDataStore.h"
#import "ServerConfig+Preview.h"

#define TIMER_INTERVAL (1.0/64.0)
#define INITIAL_SPEED (2.0)
#define MAX_SPEED (INITIAL_SPEED*1.5*1.5*1.5*1.5)
#define MIN_SPEED (INITIAL_SPEED/1.5/1.5)
#define SPEED_FACTOR (1.5)


@interface TemporalLocationObject : HLPLocationObject
@end

@implementation TemporalLocationObject {
    HLPLocation *_location;
}

- (instancetype) initWithLocation:(HLPLocation*)location {
    self = [super init];
    _location = location;
    return self;
}

- (HLPLocation*) location{
    return _location;
}
@end

@implementation HLPPreviewEvent {
    HLPLocation *_location;
    NSArray *_linkPoisCache;
}

typedef NS_ENUM(NSUInteger, HLPPreviewHeadingType) {
    HLPPreviewHeadingTypeForward = 0,
    HLPPreviewHeadingTypeBackward,
    HLPPreviewHeadingTypeOther,
};

- (id)copyWithZone:(NSZone*)zone
{
    HLPPreviewEvent *temp = [[[self class] allocWithZone:zone] initWithLink:_link
                                                                   Location:_location
                                                                Orientation:_orientation
                                                                    onRoute:_routeLink];
    [temp setDistanceMoved:_distanceMoved];
    [temp setPrev:_prev];
    return temp;
}

- (instancetype)initWithLink:(HLPLink *)link Location:(HLPLocation*)location Orientation:(double)orientation onRoute:(HLPLink*)routeLink
{
    self = [super init];
    _link = link;
    _orientation = orientation;
    _routeLink = routeLink;
    [self setLocation:location];

    return self;
}

- (NSArray*) _linkPois
{
    if (!_linkPoisCache) {
        NSArray *temp = [NavDataStore sharedDataStore].linkPoiMap[_link._id];
        if (temp) {
            temp = [temp sortedArrayUsingComparator:^NSComparisonResult(HLPPOI *poi1, HLPPOI *poi2) {
                HLPLocation *l1 = [_link nearestLocationTo:poi1.location];
                HLPLocation *l2 = [_link nearestLocationTo:poi2.location];
                double diff = [l1 distanceTo:_link.sourceLocation] - [l2 distanceTo:_link.sourceLocation];
                
                if (self._sourceToTarget) {
                    return diff < 0 ? NSOrderedAscending : NSOrderedDescending;
                }
                else if (self._targetToSource) {
                    return diff > 0 ? NSOrderedAscending : NSOrderedDescending;
                }
                return NSOrderedSame;
            }];
            
            [temp enumerateObjectsUsingBlock:^(HLPPOI *poi, NSUInteger idx, BOOL * _Nonnull stop) {
                HLPLocation *l = [_link nearestLocationTo:poi.location];
                double dist = [l distanceTo:self._sourceToTarget?_link.sourceLocation:_link.targetLocation];
                //NSLog(@"%@ %.2f", poi._id, dist);
            }];
        }
        _linkPoisCache = temp;
    }
    return _linkPoisCache;
}

- (void)setLocation:(HLPLocation *)location
{
    _location = location;
    _linkPoisCache = nil; // clear cache

    if (_link == nil) {
        return;
    }
    if (self.target == nil) {
        return;
    }
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    NSArray *links = [self intersectionLinks];
    
    HLPLink *nextLink = nil;
    HLPLink *nextRouteLink = nil;
    double min = DBL_MAX;
    double min2 = DBL_MAX;
    BOOL isInitial = isnan(_orientation);
    if (isInitial) _orientation = 0;
    
    // find possible next link and possible next route link
    if ([self.target isKindOfClass:HLPNode.class]) {
        for(HLPLink *l in links) {
            double d = 0;
            if (l.sourceNode == self.target) {
                d = fabs([HLPLocation normalizeDegree:_orientation - l.initialBearingFromSource]);
            }
            else if (l.targetNode == self.target) {
                d = fabs([HLPLocation normalizeDegree:_orientation - l.initialBearingFromTarget]);
            }
            if (d < min) {
                min = d;
                nextLink = l;
            }
            // special for elevator
            if ([nds isElevatorNode:self.targetNode]) {
                d = 0;
            }
            if (d < min2 && [nds isOnRoute:l._id]) {
                min2 = d;
                nextRouteLink = [nds routeLinkById:l._id];
            }
        }

        if (isInitial) _orientation = min;
        
        if (min < 20) {
            _link = nextLink;
            if (_link.sourceNode == self.target) {
                _orientation = _link.initialBearingFromSource;
            }
            else if (_link.targetNode == self.target) {
                _orientation = _link.initialBearingFromTarget;
            }
        } else {
            // if it is on elevator, face to the exit
            if ([nds isElevatorNode:self.targetNode]) {
                _orientation = [_link initialBearingFrom:self.targetNode];
            }
        }
        // otherwise keep previous link
        
        _routeLink = nextRouteLink;
    }
}

- (BOOL) isOnRoute
{
    if (self.target == nil) {
        return NO;
    }
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    if ([nds isElevatorNode:self.targetNode]) {
        return [nds hasRoute] && [nds isOnRoute:self.targetNode._id];
    } else {
        return [nds hasRoute] && _link && _routeLink;
    }
}

- (BOOL) isGoingToBeOffRoute
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    return [nds hasRoute] && _link && _routeLink && ![_link._id isEqualToString:_routeLink._id];
}

- (BOOL)isGoingBackward
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    return [nds hasRoute] && _link && _routeLink && [_link._id isEqualToString:_routeLink._id] &&
    _orientation == _routeLink.initialBearingFromTarget;
}

- (BOOL)isArrived
{
    if (self.targetNode == nil) {
        return NO;
    }
    NavDataStore *nds = [NavDataStore sharedDataStore];
    return [nds isOnDestination:self.targetNode._id];
}

- (HLPLocation*)location
{
    double floor = 0;
    if (self.targetNode) {
        floor = self.targetNode.height;
    } else if (_link) {
        floor = _link.sourceHeight;
    }
    return [[HLPLocation alloc] initWithLat:_location.lat Lng:_location.lng Accuracy:0 Floor:floor Speed:0 Orientation:_orientation OrientationAccuracy:0];
}

- (HLPPreviewHeadingType) headingType
{
    if (isnan(_location.orientation)) {
        return HLPPreviewHeadingTypeOther;
    }
    
    double f = [_link bearingAtLocation:_location];
    double b = [HLPLocation normalizeDegree:180-f];
    
    if (fabs([HLPLocation normalizeDegree:_location.orientation - f]) < 5) {
        return HLPPreviewHeadingTypeForward;
    }

    if (fabs([HLPLocation normalizeDegree:_location.orientation - b]) < 5) {
        return HLPPreviewHeadingTypeForward;
    }

    return HLPPreviewHeadingTypeOther;
}

- (NSArray<HLPLink*>*)intersectionLinks
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    NSArray *links = nds.nodeLinksMap[self.target._id];
    HLPNode *node = self.targetNode;
    
    return [links filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLink *link, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (link.direction == DIRECTION_TYPE_SOURCE_TO_TARGET) {
            return (link.sourceNode == node);
        }
        if (link.direction == DIRECTION_TYPE_TARGET_TO_SOURCE) {
            return (link.targetNode == node);
        }
        return link.isLeaf == NO || link.length >= 3;
    }]];
}

- (BOOL) _sourceToTarget {
    return fabs(_orientation - _link.initialBearingFromSource) < 0.01;
}

- (BOOL) _targetToSource {
    return fabs(_orientation - _link.initialBearingFromTarget) < 0.01;
}

- (HLPLocationObject*) stepTarget
{
    if (_link == nil) {
        return nil;
    }
    
    HLPLocationObject *next = nil;
    if (self.target == nil) {
        if (self._sourceToTarget) {
            next = _link.targetNode;
        } else if (self._targetToSource) {
            next = _link.sourceNode;
        }
    } else {
        NSArray<HLPLocationObject*> *stepTargets = self._linkPois;
        if (stepTargets == nil) stepTargets = @[];
        
        if (self._sourceToTarget) {
            stepTargets = [@[_link.sourceNode] arrayByAddingObjectsFromArray:stepTargets];
            stepTargets = [stepTargets arrayByAddingObject:_link.targetNode];
        } else if (self._targetToSource) {
            stepTargets = [@[_link.targetNode] arrayByAddingObjectsFromArray:stepTargets];
            stepTargets = [stepTargets arrayByAddingObject:_link.sourceNode];
        }
        
        unsigned long j = 0;
        for(unsigned long i = 0; i < stepTargets.count; i++) {
            HLPLocationObject *lo = stepTargets[i];
            if (![lo isKindOfClass:HLPLocationObject.class]) {
                continue;
            }
            if ([[_link nearestLocationTo:lo.location] distanceTo:_location] < 0.5) {
                j = MIN((i+1), stepTargets.count-1);
            }
        }
        
        next = stepTargets[j];
        
        /* test
        if ([_location distanceTo:stepTargets[j].location] > 5) {
            HLPLocation *loc = [_location offsetLocationByDistance:5 Bearing:[_location bearingTo:stepTargets[j].location]];
            next = [[TemporalLocationObject alloc] initWithLocation:loc];
        } else {
            next = stepTargets[j];
        }
         */
        
    }
    return next;
}

- (HLPLocation*)stepTargetLocation
{
    return [_link nearestLocationTo:self.stepTarget.location];
}

- (double)distanceToStepTarget
{
    HLPLocation *loc = self.stepTargetLocation;
    if (loc) {
        return [[_link nearestLocationTo:loc] distanceTo:_location];
    }
    return NAN;
}

- (void) setPrev:(HLPPreviewEvent *)prev
{
    _prev = prev;
}

- (HLPPreviewEvent *)next
{
    HLPPreviewEvent *temp = self;
    HLPLocationObject *prevTarget = nil;

    double distance = 0;
    while(true) {
        HLPPreviewEvent *prev = temp;
        temp = [temp copy];
        [temp setPrev:prev];
        
        if (temp.stepTarget == prevTarget) {
            temp = prev;
            break;
        }
        
        if ((prevTarget = temp.stepTarget)) {
            distance += [temp distanceToStepTarget];
            [temp setLocation:temp.stepTargetLocation];
            if (temp.targetPOIs || temp.targetIntersection || temp.isGoingToBeOffRoute) {
                break;
            }
        } else {
            break;
        }
    }
    [temp setDistanceMoved:distance];

    return temp;
}

- (HLPPreviewEvent *)right
{
    HLPPreviewEvent *temp = [self copy];
    
    [temp turnToLink:self.rightLink];
    return temp;
}

- (HLPPreviewEvent *)left
{
    HLPPreviewEvent *temp = [self copy];
    
    [temp turnToLink:self.leftLink];
    return temp;
}

- (HLPPreviewEvent *)nextAction
{
    HLPPreviewEvent *next = self.next;
    double d = next.distanceMoved;
    while(YES) {
        if (!next.isOnRoute || next.isGoingToBeOffRoute || next.isArrived) {
            break;
        }
        next = next.next;
        d += next.distanceMoved;
    }
    [next setDistanceMoved:d];
    return next;
}


- (void)turnToLink:(HLPLink*)link
{
    if (_link == link) {
        _orientation = [HLPLocation normalizeDegree:_orientation+180];
    } else {
        _link = link;
        _orientation = (_link.sourceNode == self.target)?_link.initialBearingFromSource:_link.initialBearingFromTarget;
    }
    [self setLocation:_location];
}

- (HLPLocationObject*) target
{
    if (_link == nil) {
        return nil;
    }
    if (_location == nil) {
        return nil;
    }
    if ([_link.sourceNode.location distanceTo:_location] < 0.5) {
        return _link.sourceNode;
    }
    if ([_link.targetNode.location distanceTo:_location] < 0.5) {
        return _link.targetNode;
    }
    NSArray *pois = self._linkPois;
    if (pois) {
        for(HLPLocationObject *lo in pois) {
            if ([[_link nearestLocationTo:lo.location] distanceTo:_location] < 0.01) {
                return lo;
            }
        }
    }
    
    return nil;
}

- (HLPNode*)  targetNode
{
    if ([self.target isKindOfClass:HLPNode.class]) {
        return (HLPNode*)self.target;
    }
    return nil;
}

- (HLPNode *)targetIntersection
{
    if (self.targetNode == nil) {
        return nil;
    }
    
    if ([[NavDataStore sharedDataStore] isElevatorNode:self.targetNode]) {
        return self.targetNode;
    }
    
    NSArray *links = [self intersectionLinks];
    if (links.count > 2) {
        return self.targetNode;
    }
    return nil;
}

- (BOOL) isEffective:(HLPLocationObject*)obj
{
    NSString *name = nil;
    if ([obj isKindOfClass:HLPEntrance.class]) {
        name = ((HLPEntrance*)obj).facility.name;
    }
    if ([obj isKindOfClass:HLPPOI.class]) {
        HLPPOI *poi = (HLPPOI*)obj;
        if(poi.poiCategory == HLPPOICategoryInfo && ([poi isOnFront:self.location] || [poi isOnSide:self.location])) {
            name = poi.name;
        }
    }
    return name && name.length > 0;
}

- (NSArray<HLPFacility *> *)targetPOIs
{
    if (self._linkPois == nil) {
        return nil;
    }
    
    NSMutableArray *temp = [@[] mutableCopy];
    for(HLPLocationObject *obj in self._linkPois) {
        if ([[_link nearestLocationTo:obj.location] distanceTo:_location] < 0.5) {
            if ([self isEffective:obj]) {
                [temp addObject:obj];
            }
        }
    }
    if ([temp count] > 0) {
        return temp;
    }
    return nil;
}

- (HLPLink*) _nextLink:(BOOL)clockwise
{
    if (self.target == nil) {
        return nil;
    }
    if (self.targetNode == nil) {
        return _link;
    }

    NavDataStore *nds = [NavDataStore sharedDataStore];
    NSArray<HLPLink*> *links = [self intersectionLinks];

    if (clockwise) {
        NSInteger index = -1;
        for(NSInteger i = 0; i < links.count; i++) {
            HLPLink *link = links[i];
            double lo = [link initialBearingFrom:(HLPNode*)self.target];
            if (lo <= _orientation) {
                index = i;
            }
        }
        return links[(index + 1) % links.count];
    } else {
        NSInteger index = links.count;
        for(NSInteger i = links.count-1; i >= 0; i--) {
            HLPLink *link = links[i];
            double lo = [link initialBearingFrom:(HLPNode*)self.target];
            if (lo >= _orientation) {
                index = i;
            }
        }
        return links[(index + links.count - 1) % links.count];
    }
}

- (HLPLink*) _floorLink:(BOOL)up
{
    HLPNode *node = self.targetNode;
    NavDataStore *nds = [NavDataStore sharedDataStore];
    double floor = round(node.height + (up?1:-1));
    for(HLPLink *l in nds.nodeLinksMap[node._id]) {
        if (l.linkType == LINK_TYPE_ELEVATOR) {
            if (l.sourceNode == node) {
                if (l.targetNode.height == floor) {
                    node = l.targetNode;
                    break;
                }
            }
            else if (l.targetNode == node) {
                if (l.sourceNode.height == floor) {
                    node = l.sourceNode;
                    break;
                }
            }
        }
    }
    if (node == nil || node == self.targetNode) {
        return nil;
    }
    for(HLPLink *l in nds.nodeLinksMap[node._id]) {
        if (l.linkType != LINK_TYPE_ELEVATOR) {
            return l;
        }
    }
    return nil;
}

- (HLPLink*) leftLink
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if ([nds isElevatorNode:self.targetNode]) {
        return [self _floorLink:NO];
    }
    
    return [self _nextLink:NO];
}

- (HLPLink*) rightLink
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if ([nds isElevatorNode:self.targetNode]) {
        return [self _floorLink:YES];
    }

    return [self _nextLink:YES];
}

- (void)setDistanceMoved:(double)distanceMoved
{
    _distanceMoved = distanceMoved;
}

- (NSString*)description
{
    NSMutableString *temp = [@"\n---------------\n" mutableCopy];

    [temp appendFormat:@"Link  : %@\n", _link._id];
    [temp appendFormat:@"Loc   : %@\n", _location];
    [temp appendFormat:@"Ori   : %f\n", _orientation];
    [temp appendFormat:@"Right : %@\n", self.rightLink._id];
    [temp appendFormat:@"Left  : %@\n", self.leftLink._id];
    [temp appendFormat:@"Target: %@\n", self.target._id];
    [temp appendFormat:@"Next  : %@\n", self.stepTarget._id];
    [temp appendFormat:@"POIS  : %ld\n", self.targetPOIs.count];
    [temp appendFormat:@"Dist  : %f\n", _distanceMoved];
    
    return temp;
}
@end


@implementation HLPPreviewer {
    NavDataStore *nds;
    HLPPreviewEvent *current;
    NSMutableArray<HLPPreviewEvent*> *history;
    NSArray *route;
    
    BOOL isAutoProceed;
    NSTimer *autoTimer;
    double stepSpeed;
    double stepCounter;
    double remainingDistanceToNextStep;
    double remainingDistanceToNextAction;
    HLPLocation *currentLocation;
}

- (instancetype) init
{
    self = [super init];
    history = [@[] mutableCopy];
    stepSpeed = INITIAL_SPEED;
    return self;
}

- (HLPPreviewEvent*) event
{
    return current;
}

- (void)startAt:(HLPLocation *)loc
{
    _isActive = YES;
    
    nds = [NavDataStore sharedDataStore];
    route = nds.route;
    
    //find nearest link
    double min = DBL_MAX;
    HLPLink *minLink = nil;
    HLPLink *routeLink = nil;
    double ori = NAN;
    
    // with route
    if ([nds hasRoute]) {
        HLPLink *first = [nds firstRouteLink];
        // route HLPLink is different instance from linksMap so need to get by link id
        routeLink = first;
        minLink = nds.linksMap[first._id];
        loc = first.sourceNode.location;
        ori = first.initialBearingFromSource;
        
    // without route
    } else {
        for(NSObject *key in nds.linksMap) {
            HLPLink *link = nds.linksMap[key];
            if (link.isLeaf) {
                continue;
            }
            if (link.sourceNode.height != link.targetNode.height ||
                link.sourceNode.height != loc.floor) {
                continue;
            }
            double d = [[link nearestLocationTo:loc] distanceTo:loc];
            if (d < min) {
                min = d;
                minLink = link;
            }
        }
        if (minLink) {
            loc = [minLink nearestLocationTo:loc];
        }
    }

    if (minLink) {
        current = [[HLPPreviewEvent alloc] initWithLink:minLink Location:loc Orientation:ori onRoute:routeLink];
    } else {
        //NSLog(@"no link found");
        //[_delegate errorWithMessage:@"closest link is not found"];
    }
    
    remainingDistanceToNextStep = current.next.distanceMoved;
    remainingDistanceToNextAction = current.nextAction.distanceMoved;
    [self fireUserLocation:current.location];
    [_delegate previewStarted:current];
}

- (void)stop
{
    _isActive = NO;
    
    current = nil;
    [self fireUserLocation:current.location];
    [_delegate previewStopped:current];
}

- (void)firePreviewUpdated
{
    if (current.isOnRoute && current.isGoingToBeOffRoute) {
        isAutoProceed = NO;
    }
    remainingDistanceToNextStep = current.next.distanceMoved;
    remainingDistanceToNextAction = current.nextAction.distanceMoved;
    [self fireUserLocation:current.location];
    [_delegate previewUpdated:current];
}

- (void)fireUserMoved:(double)distance
{
    if (isAutoProceed == NO) {
        [_delegate userMoved:distance];
    }
    if (distance == 0) {
        isAutoProceed = NO;
    }
}

- (void)fireUserLocation:(HLPLocation*)location
{
    HLPLocation *loc = [[HLPLocation alloc] init];
    [loc update:location];
    [loc updateOrientation:current.orientation withAccuracy:0];
    currentLocation = loc;
    [_delegate userLocation:loc];
}

- (void)fireRemainingDistance:(double)distance
{
    [_delegate remainingDistance:distance];
}

#pragma mark - PreviewTraverseDelegate

- (void)gotoBegin
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    current = history[0];
    [self firePreviewUpdated];
}

- (void)gotoEnd
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    [self fireUserMoved:0];
}

- (void)stepForward
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    double distance = [self _stepForward];
    [self fireUserMoved:distance];
    [self firePreviewUpdated];
}

- (double)_stepForward
{
    HLPPreviewEvent *next = [current next];
    if (next.distanceMoved > 0.1) {
        [history addObject:current];
        current = next;
    } else {
        isAutoProceed = NO;
    }
    return next.distanceMoved;
}

- (void)stepBackward
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    if (history.count > 0) {
        double distance = current.distanceMoved;
        current = [history lastObject];
        [history removeLastObject];
        
        [self fireUserMoved:distance];
        [self firePreviewUpdated];
    } else {
        [self fireUserMoved:0];
    }
}

- (void)jumpForward
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    double distance = 0;
    while(true) {
        double d = [self _stepForward];
        distance += d;
        if (current.targetIntersection || d == 0) {
            break;
        }
    }
    [self fireUserMoved:distance];
    [self firePreviewUpdated];
}

- (void)jumpBackward
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    if (history.count > 0) {
        double distance = 0;
        while (history.count > 0) {
            distance += current.distanceMoved;
            current = [history lastObject];
            [history removeLastObject];
            if (current.targetIntersection) {
                break;
            }
        }
        [self fireUserMoved:distance];
        [self firePreviewUpdated];
    } else {
        [self fireUserMoved:0];
    }
}

- (void)faceRight
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    if (current.rightLink) {
        HLPPreviewEvent *temp = [current copy];
        [temp setPrev:current];
        [temp turnToLink:temp.rightLink];
        current = temp;
        [self firePreviewUpdated];
    } else {
        [self fireUserMoved:0];
    }
}

- (void)faceLeft
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    isAutoProceed = NO;
    if (current.leftLink) {
        HLPPreviewEvent *temp = [current copy];
        [temp setPrev:current];
        [temp turnToLink:temp.leftLink];
        current = temp;
        [self firePreviewUpdated];
    } else {
        [self fireUserMoved:0];
    }
}

- (void)autoStepForwardUp
{    
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    if (isAutoProceed) {
        stepSpeed = MIN(stepSpeed * SPEED_FACTOR, MAX_SPEED);
    }
    
    if (!autoTimer) {
        stepCounter = 1;
        autoTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(autoStep:) userInfo:nil repeats:YES];
    }
    
    isAutoProceed = YES;
}

- (void)autoStepForwardDown
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    if (isAutoProceed) {
        stepSpeed = MAX(stepSpeed / SPEED_FACTOR, MIN_SPEED);
    }
}

- (void)autoStepForwardStop
{
    NSLog(@"%@,%f", NSStringFromSelector(_cmd), NSDate.date.timeIntervalSince1970);
    
    [autoTimer invalidate];
    autoTimer = nil;
    isAutoProceed = NO;
}

- (void)autoStepForwardSpeed:(double)speed Active:(BOOL)active
{
    NSLog(@"%@,%f,%d,%f", NSStringFromSelector(_cmd), speed, active, NSDate.date.timeIntervalSince1970);
    
    
}

- (void)autoStep:(NSTimer*)timer
{
    if (isAutoProceed == NO) {
        [autoTimer invalidate];
        autoTimer = nil;
    }
    
    stepCounter += TIMER_INTERVAL * stepSpeed;
    if (stepCounter >= 1.0) {
        double step_length = [[NSUserDefaults standardUserDefaults] doubleForKey:@"preview_step_length"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isAutoProceed) {
                currentLocation = [currentLocation offsetLocationByDistance:step_length Bearing:currentLocation.orientation];
                [self fireUserLocation:currentLocation];
            }
        });
        stepCounter -= 1.0;
        
        if (isAutoProceed) {            
            remainingDistanceToNextStep -= step_length;
            remainingDistanceToNextAction -= step_length;
            [self fireRemainingDistance:remainingDistanceToNextAction];
            if (remainingDistanceToNextStep < step_length) {
                [self _stepForward];
                [self firePreviewUpdated];
            }
        }
    }
}

@end
