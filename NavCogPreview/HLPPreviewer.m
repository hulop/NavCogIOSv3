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

@implementation HLPPreviewEvent : NSObject

typedef NS_ENUM(NSUInteger, HLPPreviewHeadingType) {
    HLPPreviewHeadingTypeForward = 0,
    HLPPreviewHeadingTypeBackward,
    HLPPreviewHeadingTypeOther,
};

- (instancetype) init{
    self = [super init];
    _orientation = NAN;
    return self;
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
    if ([_nextTarget isKindOfClass:HLPNode.class]) {
        HLPNode* node = (HLPNode*)_nextTarget;
        
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


#pragma mark - private setter

- (void)setLink:(HLPLink *)link
{
    _link = link;
    if (isnan(_orientation)) {
        _orientation = link.initialBearingFromSource;
    }
}

- (void)turnRight
{
    _link = _rightLink;
    _orientation = (_link.sourceNode == _target)?_link.initialBearingFromSource:_link.initialBearingFromTarget;
    _leftLink = _rightLink = nil;
}

- (void)turnLeft
{
    _link = _leftLink;
    _orientation = (_link.sourceNode == _target)?_link.initialBearingFromSource:_link.initialBearingFromTarget;
    _leftLink = _rightLink = nil;
}

- (void)turnAround
{
    _orientation = [HLPLocation normalizeDegree:180-_orientation];
}

- (void)setLocation:(HLPLocation *)location
{
    _location = location;
    _target = nil;
    _prevTarget = nil;
    _nextTarget = nil;
}

- (void)setTarget:(HLPObject *)target
{
    _nextTarget = nil;
    _prevTarget = _target;
    _target = target;

    if ([target isKindOfClass:HLPNode.class]) {
        _location = ((HLPNode*)target).location;
    }
    if ([target isKindOfClass:HLPPOI.class]) {
        _location = ((HLPPOI*)target).location;
        if (_link) {
            _location = [_link nearestLocationTo:_location];
        }
    }
}

- (void)updateWithDataStore:(NavDataStore*)nds
{
    BOOL(^isIntersection)(HLPObject*) = ^BOOL(HLPObject *node) {
        if (![node isKindOfClass:HLPNode.class]) {
            return NO;
        }
        int count = 0;
        for(HLPLink* link in nds.nodeLinksMap[node._id]) {
            count += link.isLeaf?1:0;
        }
        return count > 2;
    };
    
    NSArray*(^collectPois)(HLPObject*) = ^NSArray*(HLPObject *node) {
        if (![node isKindOfClass:HLPNode.class]) {
            return nil;
        }
        NSMutableArray *temp = [@[] mutableCopy];
        for(HLPLink* link in nds.nodeLinksMap[node._id]) {
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
    };
    
    HLPLink*(^defaultNextLink)(HLPLink*,HLPNode*,double)=
    ^HLPLink*(HLPLink *link, HLPNode *node, double orientation) {
        NSArray *links = nds.nodeLinksMap[node._id];
        
        HLPLink *temp = nil;
        double min = DBL_MAX;
        for(HLPLink *l in links) {
            double d = 0;
            if (l.sourceNode == node) {
                d = fabs([HLPLocation normalizeDegree:orientation - l.initialBearingFromSource]);
            }
            else if (l.targetNode == node) {
                d = fabs([HLPLocation normalizeDegree:orientation - l.initialBearingFromTarget]);
            }
            if (d < min) {
                min = d;
                temp = l;
            }
        }
        if (min < 20) {
            return temp;
        }
        return (temp == link) ? nil : temp;
    };
    
    HLPLink*(^nextLink)(HLPLink*,HLPNode*,BOOL)=
    ^HLPLink*(HLPLink *link, HLPNode *node, BOOL clockwise) {
        NSArray *links = nds.nodeLinksMap[node._id];
        if (link == nil) return links[0];
        NSUInteger index = [links indexOfObject:link] + (clockwise?1:-1);
        index = (index + [links count]) % [links count];
        return links[index];
    };
    
    HLPObject*(^findNextTarget)(HLPLink*,HLPNode*) =
    ^HLPObject*(HLPLink* link, HLPNode* node) {
        return (link.sourceNode == node) ? link.targetNode : link.sourceNode;
    };
    
    // collect required information here
    // based on current.link and current.location
    
    // orientation is not decided
    // very beginning
    if (_target == nil) {
        if (_orientation == _link.initialBearingFromSource) {
            _nextTarget = _link.targetNode;
        } else if (_orientation == _link.initialBearingFromTarget) {
            _nextTarget = _link.sourceNode;
        }
    } else {
        HLPNode *node = (HLPNode*)_target;
        
        _intersection = node;
        _link = defaultNextLink(_link, node, _orientation);
        _rightLink = nextLink(_link, node, YES);
        _leftLink = nextLink(_link, node, NO);
        
        _nextTarget = nil;
        if (_link) {
            _nextTarget = findNextTarget(_link, node);
        }
    }
    
    _pois = collectPois(_target);
    
    //current.linksToNextIntersection
    //current.linksToPrevIntersections
    
    NSLog(@"%@", self);
}

- (NSString*)description
{
    NSMutableString *temp = [@"\n---------------\n" mutableCopy];

    [temp appendFormat:@"Link  : %@\n", _link._id];
    [temp appendFormat:@"Right : %@\n", _rightLink._id];
    [temp appendFormat:@"Left  : %@\n", _leftLink._id];
    [temp appendFormat:@"Loc   : %@\n", _location];
    [temp appendFormat:@"Ori   : %f\n", _orientation];
    [temp appendFormat:@"Target: %@\n", _target._id];
    [temp appendFormat:@"Next  : %@\n", _nextTarget._id];
    [temp appendFormat:@"Prev  : %@\n", _prevTarget._id];
    [temp appendFormat:@"POIS  : %ld\n", _pois.count];
    
    return temp;
}
@end


@implementation HLPPreviewer {
    NavDataStore *nds;
    HLPPreviewEvent *current;
}

- (HLPPreviewEvent*) event
{
    return current;
}

- (void)startAt:(HLPLocation *)loc
{
    nds = [NavDataStore sharedDataStore];
    current = [[HLPPreviewEvent alloc] init];
    
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
        [current setLink:minLink];
    } else {
        NSLog(@"no link found");
        //[_delegate errorWithMessage:@"closest link is not found"];
    }
    [current setLocation:loc];
    [current updateWithDataStore:nds];
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
        [current setTarget:current.nextTarget];
        [current updateWithDataStore:nds];
    
        [_delegate userMoved:distance];
        [_delegate previewUpdated:current];
    } else {
        [_delegate userMoved:0];
    }
}

- (void)stepBackward
{
    if (current.prevTarget) {
        double distance = [current distanceToPrevTarget];
        [current setTarget:current.prevTarget];
        [current updateWithDataStore:nds];
        
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
    if (current.link == current.rightLink) {
        [current turnAround];
    } else {
        [current turnRight];
    }
    [current updateWithDataStore:nds];
}

- (void)faceLeft
{
    if (current.link == current.rightLink) {
        [current turnAround];
    } else {
        [current turnLeft];
    }
    [current updateWithDataStore:nds];
}

@end
