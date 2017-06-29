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

@implementation HLPPreviewEvent : NSObject {
    HLPLocation *_location;
}

typedef NS_ENUM(NSUInteger, HLPPreviewHeadingType) {
    HLPPreviewHeadingTypeForward = 0,
    HLPPreviewHeadingTypeBackward,
    HLPPreviewHeadingTypeOther,
};

- (id)copyWithZone:(NSZone*)zone
{
    HLPPreviewEvent *temp = [[[self class] allocWithZone:zone] initWithLink:_link Location:_location Orientation:_orientation];
    [temp setDistanceMoved:_distanceMoved];
    [temp setPrev:_prev];
    return temp;
}

- (instancetype)initWithLink:(HLPLink *)link Location:(HLPLocation*)location Orientation:(double)orientation
{
    self = [super init];
    _link = link;
    _orientation = orientation;
    [self setLocation:location];

    return self;
}

- (void)setLocation:(HLPLocation *)location
{
    _location = location;
    
    if (_link == nil) {
        return;
    }
    if (self.target == nil) {
        return;
    }
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    NSArray *links = [self intersectionLinks];
    
    HLPLink *temp = nil;
    double min = DBL_MAX;
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
            temp = l;
        }
    }
    
    if (min < 20) {
        _link = temp;
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
        return !link.isLeaf;
    }]];
}

- (HLPObject*) stepTarget
{
    if (_link == nil) {
        return nil;
    }
    
    HLPObject *next = nil;
    if (self.target == nil) {
        if (_orientation == _link.initialBearingFromSource) {
            next = _link.targetNode;
        } else if (_orientation == _link.initialBearingFromTarget) {
            next = _link.sourceNode;
        }
    } else {
        HLPNode *node = (HLPNode*)self.target;
        
        if (_link.sourceNode == node && fabs(_link.initialBearingFromSource - _orientation) < DBL_EPSILON) {
            next = _link.targetNode;
        }
        if (_link.targetNode == node && fabs(_link.initialBearingFromTarget - _orientation) < DBL_EPSILON) {
            next = _link.sourceNode;
        }
    }
    return next;
}

- (HLPLocation*)stepTargetLocation
{
    if ([self.stepTarget isKindOfClass:HLPNode.class]) {
        HLPNode* node = (HLPNode*)self.stepTarget;
        
        return node.location;
    }
    return nil;
}

- (double)distanceToStepTarget
{
    if ([self stepTargetLocation]) {
        return [[self stepTargetLocation] distanceTo:_location];
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

    double distance = 0;
    while(true) {
        HLPPreviewEvent *prev = temp;
        temp = [temp copy];
        [temp setPrev:prev];
        
        if (temp.stepTarget) {
            distance += [temp distanceToStepTarget];
            [temp setLocation:temp.stepTargetLocation];
            if (temp.targetPOIs || temp.targetIntersection) {
                break;
            }
        } else {
            break;
        }
    }
    [temp setDistanceMoved:distance];

    return temp;
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

- (HLPObject*) target
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
    return links.count > 2 ? self.targetNode : nil;
}

- (NSArray<HLPFacility *> *)targetPOIs
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (self.targetNode == nil) {
        return nil;
    }
    NSMutableArray *temp = [@[] mutableCopy];
    for(HLPLink* link in nds.nodeLinksMap[self.targetNode._id]) {
        if (link.isLeaf) {
            void(^check)(HLPEntrance*) = ^(HLPEntrance* ent) {
                if (ent && ent.facility && ent.facility.name && ent.facility.name.length > 0) {
                    [temp addObject:ent.facility];
                }
            };
            check(nds.entranceMap[link.sourceNodeID]);
            check(nds.entranceMap[link.targetNodeID]);
        }
    }
    if ([temp count] > 0) {
        return temp;
    }
    return nil;
}

- (NSArray<HLPEntrance *> *)targetPOIEntrances
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (self.targetNode == nil) {
        return nil;
    }
    NSMutableArray *temp = [@[] mutableCopy];
    NSArray *links = nds.nodeLinksMap[self.targetNode._id];
    for(HLPLink* link in links) {
        if (link.isLeaf) {
            void(^check)(HLPEntrance*) = ^(HLPEntrance* ent) {
                if (ent && ent.facility && ent.facility.name && ent.facility.name.length > 0) {
                    [temp addObject:ent];
                }
            };
            check(nds.entranceMap[link.sourceNodeID]);
            check(nds.entranceMap[link.targetNodeID]);            
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
}

- (instancetype) init
{
    self = [super init];
    history = [@[] mutableCopy];
    return self;
}

- (HLPPreviewEvent*) event
{
    return current;
}

- (void)startAt:(HLPLocation *)loc
{
    nds = [NavDataStore sharedDataStore];
    
    //find nearest link
    double min = DBL_MAX;
    HLPLink *minLink = nil;
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
        current = [[HLPPreviewEvent alloc] initWithLink:minLink Location:loc Orientation:0];
    } else {
        NSLog(@"no link found");
        //[_delegate errorWithMessage:@"closest link is not found"];
    }
    [_delegate previewStarted:current];
}

- (void)stop
{
    current = nil;
    [_delegate previewStopped:current];
}

#pragma mark - PreviewTraverseDelegate

- (void)gotoBegin
{
    current = history[0];
    [_delegate previewUpdated:[current copy]];
}

- (void)gotoEnd
{
    [_delegate userMoved:0];
}

- (void)stepForward
{
    double distance = [self _stepForward];
    [_delegate userMoved:distance];
    [_delegate previewUpdated:[current copy]];
}

- (double)_stepForward
{
    HLPPreviewEvent *next = [current next];
    if (next.distanceMoved > 0) {
        [history addObject:current];
        current = next;
    }
    return next.distanceMoved;
}

- (void)stepBackward
{
    if (history.count > 0) {
        double distance = current.distanceMoved;
        current = [history lastObject];
        [history removeLastObject];
        
        [_delegate userMoved:distance];
        [_delegate previewUpdated:[current copy]];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)jumpForward
{
    double distance = 0;
    while(true) {
        double d = [self _stepForward];
        distance += d;
        if (current.targetIntersection || d == 0) {
            break;
        }
    }
    [_delegate userMoved:distance];
    [_delegate previewUpdated:[current copy]];
}

- (void)jumpBackward
{
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
        [_delegate userMoved:distance];
        [_delegate previewUpdated:[current copy]];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)faceRight
{
    if (current.rightLink) {
        HLPPreviewEvent *temp = [current copy];
        [temp setPrev:current];
        [temp turnToLink:temp.rightLink];
        current = temp;
        [_delegate previewUpdated:[current copy]];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)faceLeft
{
    if (current.leftLink) {
        HLPPreviewEvent *temp = [current copy];
        [temp setPrev:current];
        [temp turnToLink:temp.leftLink];
        current = temp;
        [_delegate previewUpdated:[current copy]];
    } else {
        [_delegate userMoved:0];
    }
}

@end
