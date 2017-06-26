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
    return [[[self class] allocWithZone:zone] initWithLink:_link Location:_location Orientation:_orientation];
}

- (instancetype)initWithLink:(HLPLink *)link Location:(HLPLocation*)location Orientation:(double)orientation
{
    self = [super init];
    _link = link;
    _orientation = orientation;
    [self _setLocation:location];

    NSLog(@"%@", self);
    return self;
}

// set location and return previous event
- (instancetype)setLocation:(HLPLocation *)location
{
    HLPPreviewEvent *oldSelf = [self copy];
    [self _setLocation:location];
    NSLog(@"%@", self);
    return oldSelf;
}

- (void)_setLocation:(HLPLocation*)location
{
    _location = location;
    
    if (_link == nil) {
        return;
    }
    if (self.target == nil) {
        return;
    }
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    NSArray *links = nds.nodeLinksMap[self.target._id];
    
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

- (HLPLocation*)nextTargetLocation
{
    if ([self.nextTarget isKindOfClass:HLPNode.class]) {
        HLPNode* node = (HLPNode*)self.nextTarget;
        
        return node.location;
    }
    return nil;
}

- (double)distanceToNextTarget
{
    if ([self nextTargetLocation]) {
        [[self nextTargetLocation] distanceTo:_location];
    }
    return NAN;
}

/*
- (double)distanceToNextIntersection
{
    double dist = 0;
    for(int i = 0; i < [_linksToNextIntersection count]; i++) {
        if (i == 0) {
            switch([self headingType]) {
                case HLPPreviewHeadingTypeForward:
                    dist += [_link.targetLocation distanceTo:_location];
                    break;
                case HLPPreviewHeadingTypeBackward:
                    dist += [_link.sourceLocation distanceTo:_location];
                    break;
                case HLPPreviewHeadingTypeOther:
                    return NAN;
            }
        } else {
            dist += _linksToNextIntersection[i].length;
        }
    }
    return dist;
}

- (HLPLocation*)prevTargetLocation
{
    if ([_prevTarget isKindOfClass:HLPNode.class]) {
        HLPNode* node = (HLPNode*)_prevTarget;
        
        return node.location;
    }
    return nil;
}

- (double)distanceToPrevTarget
{
    if ([self prevTargetLocation]) {
        [[self prevTargetLocation] distanceTo:_location];
    }
    return NAN;
}

- (double)distanceToPrevIntersection
{
    double dist = 0;
    for(int i = 0; i < [_linksToPrevIntersection count]; i++) {
        if (i == 0) {
            switch([self headingType]) {
                case HLPPreviewHeadingTypeForward:
                    dist += [_link.sourceLocation distanceTo:_location];
                    break;
                case HLPPreviewHeadingTypeBackward:
                    dist += [_link.targetLocation distanceTo:_location];
                    break;
                case HLPPreviewHeadingTypeOther:
                    return NAN;
            }
        } else {
            dist += _linksToPrevIntersection[i].length;
        }
    }
    return dist;
}
*/

#pragma mark - private setter

- (void)turnToLink:(HLPLink*)link
{
    if (_link == link) {
        _orientation = [HLPLocation normalizeDegree:180-_orientation];
    } else {
        _link = link;
        _orientation = (_link.sourceNode == self.target)?_link.initialBearingFromSource:_link.initialBearingFromTarget;
    }
    NSLog(@"%@", self);
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
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    int count = 0;
    for(HLPLink* link in nds.nodeLinksMap[self.targetNode._id]) {
        count += link.isLeaf?1:0;
    }
    return count > 2 ? self.targetNode : nil;
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
            if (nds.entranceMap[link.sourceNodeID]) {
                [temp addObject:nds.entranceMap[link.sourceNodeID]];
            }
            if (nds.entranceMap[link.targetNodeID]) {
                [temp addObject:nds.entranceMap[link.targetNodeID]];
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
    NSArray<HLPLink*> *links = nds.nodeLinksMap[self.target._id];

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

- (HLPObject*) nextTarget
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

- (NSString*)description
{
    NSMutableString *temp = [@"\n---------------\n" mutableCopy];

    [temp appendFormat:@"Link  : %@\n", _link._id];
    [temp appendFormat:@"Loc   : %@\n", _location];
    [temp appendFormat:@"Ori   : %f\n", _orientation];
    [temp appendFormat:@"Right : %@\n", self.rightLink._id];
    [temp appendFormat:@"Left  : %@\n", self.leftLink._id];
    [temp appendFormat:@"Target: %@\n", self.target._id];
    [temp appendFormat:@"Next  : %@\n", self.nextTarget._id];
    //[temp appendFormat:@"Prev  : %@\n", self.prevTarget._id];
    [temp appendFormat:@"POIS  : %ld\n", self.targetPOIs.count];
    
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
}

- (void)gotoEnd
{
}

- (void)stepForward
{
    if (current.nextTarget) {
        double distance = [current distanceToNextTarget];
        [history addObject:[current setLocation:current.nextTargetLocation]];
    
        [_delegate userMoved:distance];
        [_delegate previewUpdated:current];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)stepBackward
{
    if (history.count > 0) {
        current = [history lastObject];
        [history removeLastObject];
        double distance = [current distanceToNextTarget];
        
        [_delegate userMoved:distance];
        [_delegate previewUpdated:current];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)jumpForward
{

}

- (void)jumpBackward
{
    
}

- (void)faceRight
{
    if (current.rightLink) {
        [current turnToLink:current.rightLink];
        [_delegate previewUpdated:current];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)faceLeft
{
    if (current.leftLink) {
        [current turnToLink:current.leftLink];
        [_delegate previewUpdated:current];
    } else {
        [_delegate userMoved:0];
    }
}

@end
