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

#import "HLPPreviewCommander.h"
#import "HLPWalker.h"
#import "NavDataStore.h"
#import "TTTOrdinalNumberFormatter.h"

@implementation HLPPreviewCommander {    
    BOOL stepLR;
    NSMutableArray *playBlocks;
    void (^playingBlock)(void (^complete)());
    HLPPreviewEvent *current;
    HLPPreviewEvent *next;
    HLPPreviewEvent *prev;
    
    BOOL onRoute;
    
    NSMutableSet *context;
}

- (void)previewStarted:(HLPPreviewEvent *)event
{
    prev = nil;
    current = event;
    onRoute = current.isOnRoute;
    context = [[NSMutableSet alloc] init];
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    NSMutableString *str = [@"" mutableCopy];
    [str appendFormat:@"Preview is started. "];
    if (nds.hasRoute) {
        double d = 0;
        for(HLPObject *o in nds.route) {
            if ([o isKindOfClass:HLPLink.class]) {
                d += ((HLPLink*)o).length;
            }
        }
        NSString *distString = [self distanceString:d];
        [str appendFormat:@"%@ to %@. ", distString, nds.to.namePron];
        next = current.nextAction;
        [str appendString:[self nextActionString:next]];
    }
    [str appendString:[self poisString:event]];

    [_delegate speak:str withOptions:@{@"force":@(YES)} completionHandler:nil];
}

- (void)previewStopped:(HLPPreviewEvent *)event
{
    NSMutableString *str = [@"" mutableCopy];
    [str appendFormat:@"Preview is stopped. "];
    
    [_delegate speak:str withOptions:@{@"force":@(YES)} completionHandler:nil];
}

-(void)previewUpdated:(HLPPreviewEvent *)event
{
    //NSLog(@"%@", event);
    prev = current;
    current = event;
    [self previewCurrent:nil];
}

-(void)previewCurrentFull
{
    //TODO
    [self previewCurrent:@{}];
}

-(void)previewCurrent:(NSDictionary*)options
{
    NSMutableString *str = [@"" mutableCopy];
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
    if (nds.hasRoute && current.isOnRoute) {
        //NSLog(@"isOnRoute:%d", current.isOnRoute);
        //NSLog(@"isGoingToBeOffRoute:%d", current.isGoingToBeOffRoute);
        //NSLog(@"isArrived:%d", current.isArrived);
        //NSLog(@"isGoingBackward:%d", current.isGoingBackward);
        
        if (prev != nil) {
            // moved
            if (current.target != prev.target) {
                if (current.isArrived) {
                    [str appendString:@"You have arrived. "];
                    [str appendString:[self poisString:current]];
                }
                else if (current.isGoingToBeOffRoute) {
                    double angle = [self turnAngle:current.orientation toLink:current.routeLink at:current.target];
                    [str appendString:[self turnString:angle]];
                    [str appendString:@". "];
                }
                else if (!current.isGoingBackward) {
                    if (!next) {
                        next = current.nextAction;
                        [str appendString:[self nextActionString:next]];
                    }
                    [str appendString:[self poisString:current]];
                }
                else if (current.isGoingBackward) {
                    if (!onRoute) { // recovered
                        HLPPreviewEvent *temp = current.right;
                        while(YES) {
                            if ((!temp.isGoingBackward && !temp.isGoingToBeOffRoute) || temp.link == current.link) {
                                break;
                            }
                            temp = temp.right;
                        }
                        [str appendString:@"You are back on route. "];
                        if (temp.link != current.link) {
                            double angle = [self turnAngle:current.orientation toLink:temp.link at:current.target];
                            [str appendString:[self turnString:angle]];
                        }
                    } else {
                        [str appendString:@"You are going backward. "];
                    }
                }
                //[str appendString:[self intersectionString:current]];
                //[str appendString:[self upcomingString:current]];
            }
            // turned
            if (current.target == prev.target && current.orientation != prev.orientation) {
                next = nil;
                if (!current.isGoingToBeOffRoute) {
                    next = current.nextAction;
                    [str appendString:[self nextActionString:next]];
                }
            }
        }
    } else {
        if (onRoute) {
            [str appendString:@"You are going wrong direction. "];
        }
        // elevator
        if ([nds isElevatorNode:current.targetNode]) {
            [str appendFormat:@"Elevator. "];
            [str appendFormat:@"You are on the %@.", [self floorString:current.targetNode.height]];
        } else {
            // others
            
            // escalator or stairs
            if (prev != nil && (current.targetNode.height != prev.targetNode.height)) {
                HLPPreviewEvent *temp = current;
                while(temp && temp.target != prev.target) {
                    temp = temp.prev;
                    if (temp.link.linkType == LINK_TYPE_ESCALATOR) {
                        [str appendFormat:@"Escalator. "];
                        break;
                    }
                    if (temp.link.linkType == LINK_TYPE_STAIRWAY) {
                        [str appendFormat:@"Stairs. "];
                        break;
                    }
                }
                [str appendFormat:@"You are on the %@.", [self floorString:current.targetNode.height]];
            }
            
            // not start point
            if (prev != nil) {
                // moved
                if (current.target != prev.target) {
                    [str appendString:[self intersectionString:current]];
                    [str appendString:[self upcomingString:current]];
                }
                // turned
                if (current.target == prev.target && current.orientation != prev.orientation) {
                    double heading = [self turnAngle:prev.orientation toLink:current.link at:current.target];
                    if (fabs(heading) > 20) {
                        [str appendString:[self turnString:heading]];
                        [str appendString:@". "];
                    }
                }
            }
        }
        
        [str appendString:[self poisString:current]];
     }
     
    if (str.length > 0) {
        __weak HLPPreviewCommander *weakself = self;
        [self addBlock:^(void (^complete)(void)) {
            if (weakself) {
                [weakself.delegate speak:str withOptions:@{@"force":@(NO)} completionHandler:nil];
                complete();
            }
        }];
    }
    onRoute = current.isOnRoute;
}

#pragma mark - string functions

- (NSString*)distanceString:(double)distance
{
    distance = round(distance);
    if (distance > 10) {
        distance = round(distance / 5) * 5;
    }
    if (distance == 1) {
        return @"1 meter";
    }
    return [NSString stringWithFormat:@"%.0f meters", distance];
}

- (NSString*)nextActionString:(HLPPreviewEvent*)event
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    NSString *distStr = [self distanceString:event.distanceMoved];
    NSString *actionStr = @"";
    if (event.isArrived) {
        actionStr = [self poisString:event];
    } else {
        if ([nds isElevatorNode:event.targetNode]) {
            actionStr = @"take an elevator";
        } else {
            double angle = [self turnAngle:event.orientation toLink:event.routeLink at:event.target];
            actionStr = [self turnString:angle];
        }
    }
    return [NSString stringWithFormat:@"proceed %@ and %@. ", distStr, actionStr];
}

/*
 
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
 */

- (NSString*) poisString:(HLPPreviewEvent *)event
{
    NSArray<HLPLocationObject*>*pois = event.targetPOIs;
    if (pois == nil) {
        return @"";
    }

    NSMutableString *str = [@"" mutableCopy];
    for(HLPLocationObject *lo in pois) {
        double poiDir = [event.location bearingTo:lo.location];
        double heading = [HLPLocation normalizeDegree:poiDir - event.orientation];
        if ([event.location distanceTo:lo.location] == 0) {
            heading = 0;
        }


        NSString *name = nil;
        if ([lo isKindOfClass:HLPEntrance.class]) {
            name = [((HLPEntrance*)lo).facility namePron];
        }
        if ([lo isKindOfClass:HLPPOI.class]) {
            HLPPOI *poi = (HLPPOI*)lo;
            if (poi.poiCategory == HLPPOICategoryInfo) {
                
                if ([poi isOnFront:event.location]) {
                    [str appendFormat:@"%@. ", poi.name];
                } else if ([poi isOnSide:event.location]) {
                    name = poi.name;
                }
            }
        }
        if (name && name.length > 0) {
            if (heading > 45) {
                [str appendFormat:@"%@ is on your right. ", name];
            }
            else if (heading < -45) {
                [str appendFormat:@"%@ is on your left. ", name];
            }
            else {
                [str appendFormat:@"%@ is in your front. ", name];
            }
        }
    }
    return str;
}

- (NSString*) floorString:(double) floor
{
    NSString *type = NSLocalizedStringFromTable(@"FloorNumType", @"BlindView", @"floor num type");
    
    if ([type isEqualToString:@"ordinal"]) {
        TTTOrdinalNumberFormatter*ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
        
        NSString *localeStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleLocale"];
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:localeStr];
        [ordinalNumberFormatter setLocale:locale];
        [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
        
        floor = round(floor*2.0)/2.0;
        
        if (floor < 0) {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(fabs(floor))];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), ordinalNumber];
        } else {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(floor+1)];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), ordinalNumber];
        }
    } else {
        floor = round(floor*2.0)/2.0;
        
        if (floor < 0) {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), @(fabs(floor))];
        } else {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), @(floor+1)];
        }
    }
}

- (NSString*) intersectionString:(HLPPreviewEvent*)event
{
    HLPNode *node = event.targetNode;
    if (node == nil) {
        return @"";
    }
    NSArray<HLPLink*>* links = event.intersectionLinks;

    NSMutableString *str = [@"" mutableCopy];
    
    HLPPreviewEvent *next = event.next;
    NSArray<HLPLink*> *remains = [links filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLink* link, NSDictionary<NSString *,id> * _Nullable bindings) {
        double heading = [self turnAngle:event.orientation toLink:link atNode:node];
        return 20 < fabs(heading) && fabs(heading) < 180-20;
    }]];
    
    if (event.target == next.target) {
        // end
        if (remains.count == 0) {
            [str appendString:@"Here is dead end. You need to turn around."];
        }
        else if (remains.count == 1) {
            double heading = [self turnAngle:event.orientation toLink:remains[0] atNode:node];
            NSString *turn = [self turnString:heading];
            [str appendFormat:@"You need to %@. ", turn];
        }
        else {
            [str appendString:@"You need to "];
            for(int i = 0; i < remains.count; i++) {
                if (i == remains.count-1) {
                    [str appendString:@", or "];
                } else if (i > 0) {
                    [str appendString:@", "];
                }
                HLPLink *link = remains[i];
                double heading = [self turnAngle:event.orientation toLink:link atNode:node];
                NSString *turn = [self turnString:heading];
                [str appendString:turn];
            }
            [str appendString:@". "];
        }
    } else if (remains.count > 0){
        [str appendString:@"You can "];
        for(int i = 0; i < remains.count; i++) {
            HLPLink *link = remains[i];
            double heading = [self turnAngle:event.orientation toLink:link atNode:node];
            if (remains.count >= 2 && i == remains.count-1) {
                [str appendString:@", and "];
            } else if (i > 0) {
                [str appendString:@", "];
            }
            NSString *turn = [self turnString:heading];
            [str appendString:turn];
        }
    }
    [str appendString:@". "];
    
    return str;
}

- (NSString*)upcomingString:(HLPPreviewEvent*)event
{
    HLPNode *node = event.targetIntersection;
    if (node == nil) {
        return @"";
    }
    NSArray<HLPLink*>* links = event.intersectionLinks;
    
    NSMutableString *str = [@"" mutableCopy];
    
    HLPPreviewEvent *next = event.next;
    NSArray<HLPLink*> *remains = [links filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLink* link, NSDictionary<NSString *,id> * _Nullable bindings) {
        double heading = [self turnAngle:event.orientation toLink:link atNode:node];
        return fabs(heading) < 180-20;
    }]];

    HLPWalker *walker = [HLPWalker sharedInstance];
    walker.angle = 30;
    
    for(int i = 0; i < remains.count; i++) {
        HLPLink *link = remains[i];
        double heading = [self turnAngle:event.orientation toLink:link atNode:node];
        
        [walker reset];
        HLPWalkerPointer *root = [[HLPWalkerPointer alloc] initWithNode:node Link:link];
        [walker setRoot:root];

        NSMutableSet *temp = [[NSMutableSet alloc] init];
        for(__block int i = 0; i < 5; i++) {
            [walker walkOneHop:^(HLPWalkerPointer *p) {
                if ([context containsObject:p]) {
                    return;
                }
                if (p.link.linkType == LINK_TYPE_ELEVATOR) {
                    [context addObject:p];
                    [temp addObject:@"elevator"];
                    i = 5;
                }
                else if (p.link.linkType == LINK_TYPE_ESCALATOR) {
                    [context addObject:p];
                    if ((p.link.sourceNode == p.node && p.link.sourceNode.height < p.link.targetNode.height) ||
                        (p.link.targetNode == p.node && p.link.targetNode.height < p.link.sourceNode.height)) {
                        [temp addObject:@"up escalator"];
                    } else {
                        [temp addObject:@"down escalator"];
                    }
                    i = 5;
                }
                else if (p.link.linkType == LINK_TYPE_STAIRWAY) {
                    [context addObject:p];
                    [temp addObject:@"stairs"];
                    i = 5;
                }
                
                NavDataStore *nds = [NavDataStore sharedDataStore];
                HLPEntrance *ent = nds.entranceMap[p.node._id];
                if (ent) {
                    [context addObject:p];
                    [temp addObject:[ent getNamePron]];
                    i = 5;
                }
            }];
        }
        
        NSArray *temp2 = [temp allObjects];
        if (temp2.count > 0) {
            [str appendString:@"If you go "];
            [str appendString:[self directionString:heading]];
            [str appendString:@", you can find "];
            for(int i = 0; i < temp2.count; i++) {
                if (i > 0 && temp2.count-1 == i) {
                    [str appendString:@", and "];
                } else if (i > 0) {
                    [str appendString:@", "];
                }

                [str appendString:temp2[i]];
            }
            [str appendString:@". "];
        }
    }

    return str;
}

- (double)turnAngle:(double)orientation toLink:(HLPLink*)link at:(HLPObject*)object
{
    if ([object isKindOfClass:HLPNode.class]) {
        return [self turnAngle:orientation toLink:link atNode:(HLPNode*)object];
    }
    
    NSAssert(NO, @"turnAngle with object is not implemented");
    return 0;
}

- (double)turnAngle:(double)orientation toLink:(HLPLink*)link atNode:(HLPNode*)node
{
    double linkDir = NAN;
    if (link.sourceNode == node) {
        linkDir = link.initialBearingFromSource;
    }
    else if (link.targetNode == node) {
        linkDir = link.initialBearingFromTarget;
    }
    else {
        NSLog(@"%@ is not node of the link %@", node._id, link._id);
    }
    return [HLPLocation normalizeDegree:linkDir - orientation];
}

-(NSString*)turnString:(double)heading
{
    NSString *side = (heading < 0)?@"left":@"right";
    if (fabs(heading) > 180-20) {
        return @"turn around";
    }
    else if (fabs(heading) > 90+22.5) {
        return [NSString stringWithFormat:@"turn sharp %@", side];
    }
    else if (fabs(heading) > 90-30) {
        return [NSString stringWithFormat:@"turn %@", side];
    }
    else if (fabs(heading) > 20) {
        return [NSString stringWithFormat:@"turn slight %@", side];
    }
    return @"go straight";
}

-(NSString*)directionString:(double)heading
{
    if (fabs(heading) < 45) {
        return @"straight";
    }
    return (heading < 0)?@"left":@"right";
}

-(void)userMoved:(double)distance
{
    //NSLog(@"%@ %f", NSStringFromSelector(_cmd), distance);
    __weak HLPPreviewCommander* weakself = self;

    if (distance == 0) {
        [self addBlock:^(void(^complete)(void)){
            if (weakself) {
                [weakself.delegate playNoStep];
            }
            complete();
        }];
        return;
    }
    
    double step_length = [[NSUserDefaults standardUserDefaults] doubleForKey:@"preview_step_length"];
    BOOL step_sound_for_jump = [[NSUserDefaults standardUserDefaults] doubleForKey:@"step_sound_for_jump"];

    // always speak distance
    //dispatch_async(dispatch_get_main_queue(), ^{
    NSString *str = [NSString stringWithFormat:@"%.0f meters walked. ", distance];
    [_delegate speak:str withOptions:@{@"force":@(NO)} completionHandler:nil];
    //});

    if (step_sound_for_jump == YES) {
        int steps = MAX(round(distance / step_length), 2);
        
        [self addBlock:^(void(^complete)(void)){
            __block int n = MIN(steps, 20);
            
            [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                if (weakself) {
                    [weakself.delegate playStep];
                }
                n--;
                if (n <= 0) {
                    [timer invalidate];
                    complete();
                }
            }];
        }];
    }
}

-(void) addBlock:(void (^)(void(^complete)(void)))block
{
    if (!playBlocks) {
        playBlocks = [[NSMutableArray alloc] init];
    }
    [playBlocks addObject:block];
    
    [self processNextBlock];
}

- (void) processNextBlock
{
    if (playingBlock || playBlocks.count == 0) {
        return;
    }
    playingBlock = [playBlocks firstObject];
    [playBlocks removeObjectAtIndex:0];
    
    playingBlock(^() { // complete
        playingBlock = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self processNextBlock];
        });
    });
}

- (void)userLocation:(HLPLocation *)location
{
}

- (void)remainingDistance:(double)distance
{
    double step_length = [[NSUserDefaults standardUserDefaults] doubleForKey:@"preview_step_length"];
    double target = MAX(floor(distance/15)*15, 5);
    
    if (distance > target && target > distance - step_length) {
        if (target <= 5.0) {
            [_delegate speak:@"approaching. " withOptions:@{@"force":@(YES)} completionHandler:nil];
        } else {
            NSString *distStr = [self distanceString:distance];
            [_delegate speak:distStr withOptions:@{@"force":@(YES)} completionHandler:nil];
        }
    }
}



@end
