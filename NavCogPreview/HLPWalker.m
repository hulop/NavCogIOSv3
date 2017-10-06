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

#import "HLPWalker.h"
#import "NavDataStore.h"

@implementation HLPWalkerPointer

- (instancetype)initWithNode:(HLPNode *)node Link:(HLPLink *)link
{
    self = [super init];
    if (link.sourceNode != node && link.targetNode != node) {
        @throw [NSException
                exceptionWithName:@"InvalidLinkAndNode"
                reason:@"Node is not belonging to Link"
                userInfo:nil];
    }
    _node = node;
    _link = link;
    return self;
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:HLPWalkerPointer.class]) {
        HLPWalkerPointer* p = ((HLPWalkerPointer*)object);
        return [p.node._id isEqualToString:_node._id] && [p.link._id isEqualToString:_link._id];
    }
    return NO;
}

- (NSUInteger)hash
{
    NSString *str = [NSString stringWithFormat:@"%@_%@", _node._id, _link._id];
    return str.hash;
}


- (NSSet<HLPWalkerPointer *> *)walk
{
    HLPNode *next;
    if (_link.sourceNode == _node) {
        next = _link.targetNode;
    } else if(_link.targetNode == _node) {
        next = _link.sourceNode;
    }
    
    NSArray *links = [NavDataStore sharedDataStore].nodeLinksMap[next._id];
    
    links = [links filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLink *link, NSDictionary<NSString *,id> * _Nullable bindings) {
        if (link == _link) {
            return NO;
        }
        if (link.direction == DIRECTION_TYPE_SOURCE_TO_TARGET) {
            return (link.sourceNode == next);
        }
        if (link.direction == DIRECTION_TYPE_TARGET_TO_SOURCE) {
            return (link.targetNode == next);
        }
        return !link.isLeaf;
    }]];
    
    NSMutableSet *temp = [[NSMutableSet alloc] init];
    for(HLPLink* link in links) {
        [temp addObject:[[HLPWalkerPointer alloc] initWithNode:next Link:link]];
    }

    return temp;
}

@end

@implementation HLPWalker {
    NSMutableSet* current;
    NSMutableSet* visited;
    HLPWalkerPointer *_root;
    double _rootOri;
}

static HLPWalker *instance;

+(instancetype)sharedInstance
{
    if (!instance) {
        instance = [[HLPWalker alloc] init];
    }
    return instance;
}

- (void) reset
{
    current = [[NSMutableSet alloc] init];
    visited = [[NSMutableSet alloc] init];
    _root = nil;
}

- (void) setRoot:(HLPWalkerPointer *)root
{
    _root = root;
    
    if (root.link.sourceNode == root.node) {
        _rootOri = root.link.initialBearingFromSource;
    }
    if (root.link.targetNode == root.node) {
        _rootOri = root.link.initialBearingFromTarget;
    }
    
    [current addObject:root];
}

- (void) walkOneHop:(void (^)(HLPWalkerPointer *))handler
{
    NSMutableSet *temp = [[NSMutableSet alloc] init];
    for(HLPWalkerPointer *p in current) {
        NSSet *ps = [p walk];
        for(HLPWalkerPointer *p2 in ps) {
            if ([visited containsObject:p2] == NO) {
                if (_angle > 0) {
                    double o = [_root.node.location bearingTo:p2.node.location];
                    if (fabs([HLPLocation normalizeDegree:o-_rootOri]) > _angle) {
                        continue;
                    }
                }                
                [temp addObject:p2];
                handler(p2);
            }
        }
        [visited addObject:p];
    }
    current = temp;
}

@end
