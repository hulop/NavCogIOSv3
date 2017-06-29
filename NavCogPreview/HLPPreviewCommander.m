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
    HLPPreviewEvent *prev;
    
    NSMutableSet *context;
}

- (void)previewStarted:(HLPPreviewEvent *)event
{
    prev = nil;
    current = event;
    
    context = [[NSMutableSet alloc] init];
    
    NSMutableString *str = [@"" mutableCopy];
    [str appendFormat:@"Preview is started. "];
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
    NSLog(@"%@", event);
    prev = current;
    current = event;
    [self previewCurrent];
}

-(void)previewCurrent
{
    NSMutableString *str = [@"" mutableCopy];
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    
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
        
        if (prev != nil) {
            if (current.target != prev.target) {
                [str appendString:[self intersectionString:current]];
                [str appendString:[self upcomingString:current]];
            }
            if (current.target == prev.target && current.orientation != prev.orientation) {
                double heading = [self turnAngle:prev.orientation toLink:current.link atNode:current.target];
                if (fabs(heading) > 20) {
                    [str appendString:[self turnString:heading]];
                    [str appendString:@". "];
                }
            }
        }
    }
    
    [str appendString:[self poisString:current]];
    
    if (str.length > 0) {
        [self addBlock:^(void (^complete)(void)) {
            [_delegate speak:str withOptions:@{@"force":@(YES)} completionHandler:nil];
            complete();
        }];
    }
}

- (NSString*) poisString:(HLPPreviewEvent *)event
{
    NSArray<HLPEntrance*>*ents = event.targetPOIEntrances;
    if (ents == nil) {
        return @"";
    }
    NSMutableString *str = [@"" mutableCopy];
    for(HLPEntrance *ent in ents) {
        double poiDir = [event.location bearingTo:ent.node.location];
        double heading = [HLPLocation normalizeDegree:poiDir - event.orientation];
        
        NSString *name = [ent.facility namePron];
        if (!name || name.length == 0) {
            continue;
        }
        
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
    NSLog(@"%@ %f", NSStringFromSelector(_cmd), distance);
    
    if (distance == 0) {
        [self addBlock:^(void(^complete)(void)){
            [_delegate playNoStep];
            complete();
        }];
        return;
    }
    
    double step_length = [[NSUserDefaults standardUserDefaults] doubleForKey:@"preview_step_length"];
    BOOL step_sound_for_jump = [[NSUserDefaults standardUserDefaults] doubleForKey:@"step_sound_for_jump"];
    
    if (step_sound_for_jump == YES) {
        
        int steps = MAX(round(distance / step_length), 2);
        // todo
        
        [self addBlock:^(void(^complete)(void)){
            __block int n = MIN(steps, 20);
            if (steps > 20) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *str = [NSString stringWithFormat:@"%.0f meters", distance];
                    [_delegate speak:str withOptions:@{@"force":@(YES)} completionHandler:nil];
                });
            }
            [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                [_delegate playStep];
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



@end
