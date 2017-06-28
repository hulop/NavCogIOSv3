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


@implementation HLPPreviewCommander {    
    BOOL stepLR;
    NSMutableArray *playBlocks;
    void (^playingBlock)(void (^complete)());
    HLPPreviewEvent *prev;
}

- (void)previewStarted:(HLPPreviewEvent *)event
{
    NSMutableString *str = [@"" mutableCopy];
    [str appendFormat:@"Preview is started. "];
    [str appendString:[self poisString:event]];

    [_delegate speak:str withOptions:nil completionHandler:nil];
    prev = event;
}

- (void)previewStopped:(HLPPreviewEvent *)event
{
    NSMutableString *str = [@"" mutableCopy];
    [str appendFormat:@"Preview is stopped. "];
    
    [_delegate speak:str withOptions:nil completionHandler:nil];
}

-(void)previewUpdated:(HLPPreviewEvent *)event
{
    NSMutableString *str = [@"" mutableCopy];
    [str appendString:[self poisString:event]];
    
    if (prev != nil && event.target != prev.target) {
        [str appendString:[self intersectionString:event]];
    }
    
    if (str.length > 0) {
        [_delegate speak:str withOptions:nil completionHandler:nil];
    }
    prev = event;
}

- (NSString*) poisString:(HLPPreviewEvent *)event
{
    NSArray<HLPFacility*>*pois = event.targetPOIs;
    if (pois == nil) {
        return @"";
    }
    NSMutableString *str = [@"" mutableCopy];
    for(HLPFacility *poi in pois) {
        double poiDir = [event.location bearingTo:poi.location];
        double heading = [HLPLocation normalizeDegree:poiDir - event.orientation];
        
        NSString *name = [poi namePron];
        
        if (heading > 45) {
            [str appendFormat:@"%@ is on your right", name];
        }
        else if (heading < 45) {
            [str appendFormat:@"%@ is on your left", name];
        }
        else {
            [str appendFormat:@"%@ is in your front", name];
        }
    }
    return str;
}

- (NSString*) intersectionString:(HLPPreviewEvent*)event
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
    
    if (event.link == next.link) {
        // end
        if (remains.count == 0) {
            [str appendString:@"Here is dead end. You need to turn around."];
        }
        else if (remains.count == 1) {
            double heading = [self turnAngle:event.orientation toLink:remains[0] atNode:node];
            NSString *turn = [self turnString:heading];
            [str appendFormat:@"You need to %@", turn];
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
        }
    } else {
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
    
    int steps = MAX(round(distance / step_length), 2);
    // todo
    
    [self addBlock:^(void(^complete)(void)){
        __block int n = MIN(steps, 20);
        if (steps > 20) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *str = [NSString stringWithFormat:@"%.0f meters", distance];
                [_delegate speak:str withOptions:nil completionHandler:nil];
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
