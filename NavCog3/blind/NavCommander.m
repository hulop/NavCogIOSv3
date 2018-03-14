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

#import "NavCommander.h"
#import <FormatterKit/TTTOrdinalNumberFormatter.h>
#import "NavDataStore.h"
#import "LocationEvent.h"

@implementation NavCommander {
    NSTimeInterval lastPOIAnnounceTime;
    NSMutableArray<NavPOI*>* approachingPOIs;
}

#pragma mark - string builder functions

- (instancetype) init
{
    self = [super self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestNearestPOI:) name:REQUEST_NEAREST_POI object:nil];
    approachingPOIs = [@[] mutableCopy];
    return self;
}

- (void)dealloc
{
    //NSLog(@"NavCommander dealloc");
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

- (NSString*)distanceString:(double)distance
{
    if (round(distance) == 0) {
        return nil;
    }
    NSString *distance_unit = [[NSUserDefaults standardUserDefaults] stringForKey:@"distance_unit"];
    
    BOOL isFeet = [distance_unit isEqualToString:@"unit_feet"];
    const double FEET_UNIT = 0.3024;
    
    if (isFeet) {
        distance /= FEET_UNIT;
    }

    if (distance > 50) {
        distance = floor(distance / 10.0) * 10.0;
    }
    if (distance > 10) {
        distance = floor(distance / 5.0) * 5.0;
    }
    NSString *unit = isFeet?@"unit_feet":@"unit_meter";
    return [NSString stringWithFormat:NSLocalizedStringFromTable(unit, @"BlindView", @""), (int)round(distance)];
}

- (NSString*)actionString:(NSDictionary*)properties
{
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    HLPLinkType nextLinkType = [properties[@"nextLinkType"] intValue];
    double turnAngle = [properties[@"turnAngle"] doubleValue];
    
    if (properties[@"diffHeading"]) {
        if (fabs([HLPLocation normalizeDegree:[properties[@"diffHeading"] doubleValue] - turnAngle]) > 45 &&
            linkType != LINK_TYPE_ELEVATOR) {
            turnAngle = [properties[@"diffHeading"] doubleValue];
        }
    }
    NSString *string = nil;
    
    if (turnAngle < -150 ) {
        string = NSLocalizedStringFromTable(@"make a u-turn to the left",@"BlindView", @"make turn to -180 ~ -180");
    } else if (turnAngle > 150) {
        string = NSLocalizedStringFromTable(@"make a u-turn to the right",@"BlindView", @"make turn to +150 ~ +180");
    } else if (turnAngle < -120) {
        string = NSLocalizedStringFromTable(@"make a big left turn",@"BlindView", @"make turn to -120 ~ -150");
    } else if (turnAngle > 120) {
        string = NSLocalizedStringFromTable(@"make a big right turn",@"BlindView", @"make turn to +120 ~ +150");
    } else if (turnAngle < -60) {
        string = NSLocalizedStringFromTable(@"turn left",@"BlindView", @"make turn to -60 ~ -120");
    } else if (turnAngle > 60) {
        string = NSLocalizedStringFromTable(@"turn right",@"BlindView", @"make turn to +60 ~ +120");
    } else if (turnAngle < -22.5) {
        string = NSLocalizedStringFromTable(@"make a slight left turn",@"BlindView", @"make turn to -22.5 ~ -60");
    } else if (turnAngle > 22.5) {
        string = NSLocalizedStringFromTable(@"make a slight right turn",@"BlindView", @"make turn to +22.5 ~ +60");
    } else {
        string = NSLocalizedStringFromTable(@"go straight", @"BlindView", @"");
    }
    
    NSArray *pois = properties[@"pois"];
    NSString *cornerInfo = [self cornerPOIString:pois];
    BOOL isCornerEnd = [self isCornerEnd:pois];
    BOOL isCornerWarningBlock = [self isCornerWarningBlock:pois];
    
    NSString *formatString = @"action";
    if (cornerInfo && !isCornerEnd) {
        formatString = [formatString stringByAppendingString:@" at near object"];
    }
    if (isCornerWarningBlock) {
        formatString = [formatString stringByAppendingString:@" at warning block"];
    }
    if (isCornerEnd) {
        formatString = [formatString stringByAppendingString:@" at end object"];
    }
    formatString = NSLocalizedStringFromTable(formatString, @"BlindView", @"");
    string = [NSString stringWithFormat:formatString, string, cornerInfo];
    

    if (nextLinkType == LINK_TYPE_ELEVATOR || nextLinkType == LINK_TYPE_ESCALATOR || nextLinkType == LINK_TYPE_STAIRWAY) {
        double sourceHeight = [properties[@"nextSourceHeight"] doubleValue];
        double targetHeight = [properties[@"nextTargetHeight"] doubleValue];
        NSString *mean = [HLPLink nameOfLinkType:nextLinkType];
        
        NSString *angle;
        if (turnAngle < -150) {
            angle = NSLocalizedStringFromTable(@"on your left side(almost back)",@"BlindView", @"something at your degree -150 ~ -180"); //@"左後ろ";
        } else if (turnAngle > 150) {
            angle = NSLocalizedStringFromTable(@"on your right side(almost back)",@"BlindView", @"something at your degree +150 ~ +180"); //@"右後ろ";
        } else if (turnAngle < -135) {
            angle = NSLocalizedStringFromTable(@"on your left side(back)",@"BlindView", @"something at your degree -120 ~ -150"); //@"左斜め後ろ";
        } else if (turnAngle > 135) {
            angle = NSLocalizedStringFromTable(@"on your right side(back)",@"BlindView", @"something at your degree +120 ~ +150"); //@"右斜め後ろ";
        } else if (turnAngle < -45) {
            angle = NSLocalizedStringFromTable(@"on your left side",@"BlindView", @"something at your degree -60 ~ -120"); //@"左";
        } else if (turnAngle > 45) {
            angle = NSLocalizedStringFromTable(@"on your right side",@"BlindView", @"something at your degree +60 ~ +120"); //@"右";
        //} else if (turnAngle < -22.5) {
        //    angle = NSLocalizedStringFromTable(@"on your left side(front)",@"BlindView", @"something at your degree -22.5 ~ -60"); //@"左斜め前";
        //} else if (turnAngle > 22.5) {
        //    angle = NSLocalizedStringFromTable(@"on your right side(front)",@"BlindView", @"something at your degree +22.5 ~ +60"); //@"右斜め前";
        } else {
            angle = NSLocalizedStringFromTable(@"in front of you",@"BlindView", @"something at your degree -22.5 ~ +22.5"); //@"正面";
        }
        
        BOOL full = [properties[@"fullAction"] boolValue];
        NSArray<HLPPOIEscalatorFlags*> *flags = properties[@"escalatorFlags"];
        
        if (full && nextLinkType == LINK_TYPE_ESCALATOR) {
            return nil;
        }
        else {
            BOOL up = targetHeight > sourceHeight;
            BOOL __block left = NO, right = NO;
            [flags enumerateObjectsUsingBlock:^(HLPPOIEscalatorFlags * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                left = left || obj.left;
                right = right || obj.right;
            }];
            
            NSString *side;
            if (left && right) {
                side = @"InMiddle";
            } else if (left) {
                side = @"RightSide";
            } else if (right) {
                side = @"LeftSide";
            }
            side = NSLocalizedStringFromTable(side, @"BlindView", @"");

            NSString *tfloor = [self floorString:targetHeight];
            NSString *format = @"FloorChangeActionString4";
            format = [format stringByAppendingString:up?@"Up":@"Down"];
            
            string = [NSString stringWithFormat:NSLocalizedStringFromTable(format,@"BlindView",@"") , angle, side, mean, tfloor];//@""
            string = [string stringByAppendingString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
            
            if (nextLinkType == LINK_TYPE_ESCALATOR && [flags count] > 0) {
                NSString *format;
                for(int i = 0; i < [flags count]; i++) {
                    HLPPOIEscalatorFlags *flag = flags[i];
                    if (flag.left) {
                        format = @"EscalatorSideLeft";
                    }
                    if (flag.right) {
                        format = @"EscalatorSideRight";
                    }
                    if (flag.forward) {
                        format = [format stringByAppendingString:@"Forward"];
                    }
                    if (flag.backward) {
                        format = [format stringByAppendingString:@"Backward"];
                    }
                    string = [string stringByAppendingString:NSLocalizedStringFromTable(format, @"BlindView", @"")];
                    string = [string stringByAppendingString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
                }
            }
        }
    }
    else if (linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        double sourceHeight = [properties[@"nextSourceHeight"] doubleValue];
        double targetHeight = [properties[@"nextTargetHeight"] doubleValue];
        NSString *mean = [HLPLink nameOfLinkType:linkType];
        //NSString *sfloor = [self floorString:sourceHeight];
        NSString *tfloor = [self floorString:targetHeight];
        //string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Go to %2$@ by %1$@, now you are in %3$@",@"BlindView",@"") , mean, tfloor, sfloor];
        BOOL up = targetHeight > sourceHeight;
        BOOL full = [properties[@"fullAction"] boolValue];
        if (full) {
            NSString *format = @"FloorChangeDoneActionString2";
            format = [format stringByAppendingString:up?@"Up":@"Down"];
            string = [NSString stringWithFormat:NSLocalizedStringFromTable(format,@"BlindView",@"") , mean, string];
        } else {
            NSString *format = @"FloorChangeActionString2";
            format = [format stringByAppendingString:up?@"Up":@"Down"];
            string = [NSString stringWithFormat:NSLocalizedStringFromTable(format,@"BlindView",@"") , mean, tfloor];
        }
    }
    else {
        if (linkType == LINK_TYPE_ELEVATOR) {
            string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"After getting off the elevator, %@", @"BlindView", @""), string];
        }
    }
    return string;
}

- (NSString*) doorString:(NavPOI*)poi withOption:option
{
    BOOL shortSentence = option && option[@"short"] && [option[@"short"] boolValue];
    NSString *format = @"DoorPOIString";
    format = [(poi.flagAuto)?@"Auto":@"" stringByAppendingString:format];
    format = [format stringByAppendingString:(poi.count == 1)?@"1":@"2"];
    format = [format stringByAppendingString:(shortSentence)?@"Short":@""];
    
    return [NSString stringWithFormat:NSLocalizedStringFromTable(format, @"BlindView", @""), poi.count];
}

- (NSString*) obstacleString:(NavPOI*)poi withOption:option
{
    NSString *side = nil;
    if (poi.leftSide && poi.rightSide) {
        side = NSLocalizedStringFromTable(@"BothSide", @"BlindView", @"");
    } else if (poi.leftSide) {
        side = NSLocalizedStringFromTable(@"LeftSide", @"BlindView", @"");
    } else if (poi.rightSide) {
        side = NSLocalizedStringFromTable(@"RightSide", @"BlindView", @"");
    }
    
    BOOL shortSentence = option && option[@"short"] && [option[@"short"] boolValue];

    if (side) {
        NSString *format = @"ObstaclePOIString";
        format = [format stringByAppendingString:(poi.count == 1)?@"1":@"2"];
        format = [format stringByAppendingString:(shortSentence)?@"Short":@""];
        return [NSString stringWithFormat:NSLocalizedStringFromTable(format, @"BlindView", @""), side];
    }
    
    return nil;
}

- (NSString*) rampString:(NavPOI*)poi withOption:option
{
    BOOL shortSentence = option && option[@"short"] && [option[@"short"] boolValue];
    NSString *format = @"RampPOIString";
    format = [format stringByAppendingString:(shortSentence)?@"Short":@""];
    
    return NSLocalizedStringFromTable(format, @"BlindView", @"");
}

- (NSString*) brailleBlockString:(NavPOI*)poi withOption:option
{
    BOOL shortSentence = option && option[@"short"] && [option[@"short"] boolValue];
    NSString *format = @"BrailleBlockPOIString";
    format = [poi.flagEnd?@"No":@"" stringByAppendingString:format];
    format = [format stringByAppendingString:(shortSentence)?@"Short":@""];
    
    return NSLocalizedStringFromTable(format, @"BlindView", @"");
}

- (NSString*) poiString:(NavPOI*) poi
{
    return [self poiString:poi withOption:nil];
}

- (NSString*) poiString:(NavPOI*) poi withOption:(NSDictionary*)option
{
    if (poi == nil) {
        return @"";
    }
    
    NSMutableString *string = [@"" mutableCopy];
    if (poi.forFloor) {
        if (poi.flagCaution) {
            [string appendFormat:NSLocalizedStringFromTable(@"Watch your step, %@", @"BlindView", @""), poi.text];
        }
    }
    else if (poi.forSign) {
        [string appendFormat:NSLocalizedStringFromTable(@"There is a sign says %@", @"BlindView", @""), poi.text];
    }
    else if (poi.forDoor) {
        [string appendString:[self doorString:poi withOption:option]];
    }
    else if (poi.forObstacle) {
        [string appendString:[self obstacleString:poi withOption:option]];
    }
    else if (poi.forRamp) {
        [string appendString:[self rampString:poi withOption:option]];
    }
    else if (poi.forBrailleBlock) {
        [string appendString:[self brailleBlockString:poi withOption:option]];
    }
    else {
        NSString *temp = @"";
        if (poi.text) {
            temp = [temp stringByAppendingString:poi.text];
        }
        if (poi.longDescription) {
            if ([temp length] > 0) {
                temp = [temp stringByAppendingString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
            }
            temp = [temp stringByAppendingString:poi.longDescription];
        }
        if (poi.flagCaution) {
            temp = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Caution, %@", @"BlindView", @""), temp];
        }
        [string appendString:temp];
    }
    return string;
}

- (NSString*) welcomePOIString:(NSArray*) pois
{
    if (pois == nil || [pois count] == 0) {
        return @"";
    }
    NSMutableString *string = [@"" mutableCopy];
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forWelcome == YES"]];
    for(NavPOI *poi in pois) {
        [string appendString:[self poiString:poi]];
        [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
    }
    return string;
}

- (NSString*) startPOIString:(NSArray*) pois
{
    if (pois == nil || [pois count] == 0) {
        return @"";
    }
    NSMutableString *string = [@"" mutableCopy];
    
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forBeforeStart == YES"]];
    
    if (pois && [pois count] > 0) {
        NSArray *infos = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"flagCaution == NO"]];
        for(NavPOI *poi in infos) {
            [string appendString:[self poiString:poi]];
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
        }
        NSArray *cautions = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"flagCaution == YES"]];
        for(NavPOI *poi in cautions) {
            [string appendString:[self poiString:poi]];
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
        }
    }
    
    return string;
}

- (NSString*) floorPOIString:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forFloor == YES && forBeforeStart == NO"]];
    
    NSString *text = nil;
    if ([pois count] > 1) {
        // TODO: multiple floor info
    }
    if ([pois count] > 0) {
        NavPOI *poi = pois[0];
        if (poi.forBrailleBlock) {
            text = NSLocalizedStringFromTable(@"BrailleBlock", @"BlindView", @"");
        } else {
            if (poi.text && [poi.text length] > 0) {
                text = poi.text;
            }
        }
    }
    return text;
}

- (BOOL) isCornerEnd:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forCorner == YES && forBeforeStart == NO && forCornerEnd == YES"]];
    return [pois count] > 0;
}

- (BOOL) isCornerWarningBlock:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forCorner == YES && forBeforeStart == NO && forCornerWarningBlock == YES"]];
    return [pois count] > 0;
}

- (NSString*) cornerPOIString:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forCorner == YES && forBeforeStart == NO"]];
    NSString *text = nil;
    if ([pois count] > 1) {
        // TODO: multiple floor info
    }
    if ([pois count] > 0) {
        NavPOI *poi = pois[0];
        if (poi.text && [poi.text length] > 0) {
            text = poi.text;
        }
    }
    return text;
}

- (NSString*) headingActionString:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    double threshold = [properties[@"threshold"] doubleValue];
    BOOL looseDirection = [properties[@"looseDirection"] boolValue];
    
    NSString *string;
    if (looseDirection) {
        if (diffHeading < -135 || 135 < diffHeading) {
            string = NSLocalizedStringFromTable(@"turn around",@"BlindView", @"head to the back");
        } else if (diffHeading < -67.5) {
            string = NSLocalizedStringFromTable(@"turn to the left",@"BlindView", @"head to the left direction");
        } else if (diffHeading > 67.5) {
            string = NSLocalizedStringFromTable(@"turn to the right",@"BlindView", @"head to the right direction");
        } else if (diffHeading < -threshold) {
            string = NSLocalizedStringFromTable(@"bear left",@"BlindView", @"head to the diagonally forward left direction");
        } else if (diffHeading > threshold) {
            string = NSLocalizedStringFromTable(@"bear right",@"BlindView", @"head to the diagonally forward right direction");
        } else {
            return nil;
        }
    } else {
        if (diffHeading < -150 || 150 < diffHeading) {
            string = NSLocalizedStringFromTable(@"turn around",@"BlindView", @"head to the back");
        } else if (diffHeading < -120) {
            string = NSLocalizedStringFromTable(@"turn to the backward left",@"BlindView", @"head to the diagonally backward left direction");
        } else if (diffHeading > 120) {
            string = NSLocalizedStringFromTable(@"turn to the backward right",@"BlindView", @"head to the diagonally backward right direction");
        } else if (diffHeading < -60) {
            string = NSLocalizedStringFromTable(@"turn to the left",@"BlindView", @"head to the left direction");
        } else if (diffHeading > 60) {
            string = NSLocalizedStringFromTable(@"turn to the right",@"BlindView", @"head to the right direction");
        } else if (diffHeading < -threshold) {
            string = NSLocalizedStringFromTable(@"bear left",@"BlindView", @"head to the diagonally forward left direction");
        } else if (diffHeading > threshold) {
            string = NSLocalizedStringFromTable(@"bear right",@"BlindView", @"head to the diagonally forward right direction");
        } else {
            //@throw [[NSException alloc] initWithName:@"wrong parameters" reason:@"abs(diffHeading) is smaller than threshold" userInfo:nil];
            return nil;
        }
    }
    
    return string;
}

- (NSString*) directionString:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    NSString *string = nil;
    
    if (diffHeading < -157.5 || 157.5 < diffHeading) {
        string = NSLocalizedStringFromTable(@"BACK_DIRECTION",@"BlindView", @"");
    } else if (diffHeading < -112.5) {
        string = NSLocalizedStringFromTable(@"LEFT_BACK_DIRECTION",@"BlindView", @"");
    } else if (diffHeading > 112.5) {
        string = NSLocalizedStringFromTable(@"RIGHT_BACK_DIRECTION",@"BlindView", @"");
    } else if (diffHeading < -67.5) {
        string = NSLocalizedStringFromTable(@"LEFT_DIRECTION",@"BlindView", @"");
    } else if (diffHeading > 67.5) {
        string = NSLocalizedStringFromTable(@"RIGHT_DIRECTION",@"BlindView", @"");
    } else if (diffHeading < -22.5) {
        string = NSLocalizedStringFromTable(@"LEFT_FRONT_DIRECTION",@"BlindView", @"");
    } else if (diffHeading > 22.5) {
        string = NSLocalizedStringFromTable(@"RIGHT_FRONT_DIRECTION",@"BlindView", @"");
    } else {
        string = NSLocalizedStringFromTable(@"FRONT_DIRECTION",@"BlindView", @"");
    }
    return string;
}

#pragma mark - NavNavigatorDelegate

- (void)didActiveStatusChanged:(NSDictionary *)properties
{
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"Reason,%@", properties[@"reason"]);
    
    //TODO
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSMutableString *string = [[NSMutableString alloc] init];
    NSString *destination = [NavDataStore sharedDataStore].to.namePron;
    
    double totalLength = [properties[@"totalLength"] doubleValue];
    NSString *totalDist = [self distanceString:totalLength];
    
    NSArray *pois = properties[@"pois"];
    [string appendString:[self welcomePOIString:pois]];
    
    if (destination && ![destination isEqual:[NSNull null]] && [destination length] > 0){
        [string appendFormat:NSLocalizedStringFromTable(@"distance to %1$@", @"BlindView", @"distance to a destination name"), destination, totalDist];
    } else {
        [string appendFormat:NSLocalizedStringFromTable(@"distance to the destination", @"BlindView", @"distance to the destination"), totalDist];
    }
    
    [_delegate speak:string withOptions:properties completionHandler:^{}];
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSString *destination = nil;
    if (properties[@"isEndOfLink"] && [properties[@"isEndOfLink"] boolValue] == YES) {
        destination = [NavDataStore sharedDataStore].to.namePron;
    }
    
    NSMutableString *string = [[NSMutableString alloc] init];
    if (destination && ![destination isEqual:[NSNull null]] && [destination length] > 0){
        [string appendFormat:NSLocalizedStringFromTable(@"You arrived at %1$@",@"BlindView", @"arrived message with destination name"), destination];
    } else {
        [string appendFormat:NSLocalizedStringFromTable(@"You arrived",@"BlindView", @"arrived message")];
    }
    
    NSArray *destPois = [properties[@"pois"] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forAfterEnd == YES AND isDestination == YES"]];
    BOOL hasDestinationPOI = [destPois count] > 0;
    
    [_delegate vibrate];
    [_delegate speak:string withOptions:properties completionHandler:^{
        if (hasDestinationPOI == NO) {
            [[NavDataStore sharedDataStore] clearRoute];
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RATING object:nil];
        }
    }];

    for(NavPOI *poi in destPois) {
        [self userIsApproachingToPOI:
         @{
           @"poi": poi,
           @"heading": @(poi.diffAngleFromUserOrientation)
           }];
    }
}

- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSString *string = [self headingActionString:properties];
    
    if (string) {
        [self.delegate vibrate];
        [_delegate speak:string withOptions:properties completionHandler:^{}];
    }
}

- (void)userAdjustedHeading:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"speak,<play success sound>");
        [_delegate playSuccess];
    });
}

- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    double distance = [properties[@"distance"] doubleValue];
    BOOL target = [properties[@"target"] boolValue];
    
    if (target) {
        NSLog(@"%@", NSStringFromSelector(_cmd));
        NSString *dist = [self distanceString:distance];
        NSString *string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"remaining distance",@"BlindView", @""),  dist];
        [_delegate speak:string withOptions:properties completionHandler:^{}];
    }
}

- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSString *action = [self actionString:properties];
    NSString *string = nil;
    
    if (false && action) {
        string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"approaching to %@",@"BlindView",@"approaching to do something") , action];
    } else {
        string = NSLocalizedStringFromTable(@"approaching",@"BlindView",@"approaching");
    }
    properties = [properties mtl_dictionaryByAddingEntriesFromDictionary:@{@"force":@(YES)}];
    [_delegate speak:string withOptions:properties completionHandler:^{}];
}

- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSString *action = [self actionString:properties];
    if (!action) {
        return;
    }
    
    [_delegate vibrate];
    properties = [properties mtl_dictionaryByAddingEntriesFromDictionary:@{@"force":@(YES)}];
    [_delegate speak:action withOptions:properties completionHandler:^{}];
}

- (void)userNeedsToWalk:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    double distance = [properties[@"distance"] doubleValue];
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    BOOL isNextDestination = [properties[@"isNextDestination"] boolValue];
    double noAndTurnMinDistance = [properties[@"noAndTurnMinDistance"] doubleValue];
    
    NSString *action = [self actionString:[properties mtl_dictionaryByRemovingValuesForKeys:@[@"isCrossingCorridor"]]];
    NSMutableString *string = [@"" mutableCopy];
    
    NSArray *pois = properties[@"pois"];
    [string appendString:[self startPOIString:pois]];

    
    NSString *floorInfo = [self floorPOIString:pois];
    NSString *dist = [self distanceString:distance];
    
    if (linkType == LINK_TYPE_ELEVATOR || linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        [string appendString:action];
    }
    else if (isNextDestination) {
        NSString *destTitle = [NavDataStore sharedDataStore].to.namePron;
        
        [string appendString: [NSString stringWithFormat:NSLocalizedStringFromTable(@"destination is in distance",@"BlindView",@"remaining distance to the destination"), destTitle, dist]];
        
        // TODO braille block is not handled
        // TODO no destTitle
    }
    else if (action) {
        NSString *proceedString = @"proceed distance";
        NSString *nextActionString = @"and action";
        
        if ([properties[@"isCrossingCorridor"] boolValue]) {
            proceedString = [proceedString stringByAppendingString:@" across the corridor"];
        }
        if (floorInfo) {
            proceedString = [proceedString stringByAppendingString:@" on floor"];
        }
        if ((noAndTurnMinDistance < distance && distance < 50) || isnan(noAndTurnMinDistance)) {
            proceedString = [proceedString stringByAppendingString:@" ..."];
        }

        proceedString = NSLocalizedStringFromTable(proceedString, @"BlindView", @"");
        proceedString = [NSString stringWithFormat:proceedString, dist, floorInfo];
        nextActionString = NSLocalizedStringFromTable(nextActionString, @"BlindView", @"");
        nextActionString = [NSString stringWithFormat:nextActionString, action];
        
        [string appendString:proceedString];
        if ((noAndTurnMinDistance < distance && distance < 50) || isnan(noAndTurnMinDistance)) {
            [string appendString:nextActionString];
        }
    }
    
    [_delegate speak:string withOptions:properties completionHandler:^{}];
}
- (void)userGetsOnElevator:(NSDictionary *)properties
{
    NavPOI *poi = properties[@"poi"];
    NSString *floor = [self floorString:[properties[@"nextSourceHeight"] doubleValue]];
    NSString *string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Go to %1$@", @"BlindView", @""), floor];
    
    if (poi) {
        string = [string stringByAppendingString:poi.text];
    }

    [_delegate speak:string withOptions:properties completionHandler:^{}];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSString *hAction = [self headingActionString:properties];
    
    if (hAction) {
        NSString *string = NSLocalizedStringFromTable(@"%@, you might be going backward.", @"BlindView", @"");
        string = [NSString stringWithFormat:string, hAction];
        [_delegate speak:string withOptions:properties completionHandler:^{}];
    }
    
}

- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSString *hAction = [self headingActionString:properties];
    
    if (hAction) {
        NSString *string = NSLocalizedStringFromTable(@"%@, you might be going wrong direction.", @"BlindView", @"");
        string = [NSString stringWithFormat:string, hAction];
        [_delegate speak:string withOptions:properties completionHandler:^{}];
    }
}

- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    NSLog(@"%@", NSStringFromSelector(_cmd));
    NavPOI *poi = properties[@"poi"];
    double heading = [properties[@"heading"] doubleValue];
    
    BOOL isDestinationPOI = NO;
    BOOL shortSentence = (now - lastPOIAnnounceTime) < 3;
    
    if (poi && ![approachingPOIs containsObject:poi] && poi.hasContent) {
        [_delegate vibrate];
        [approachingPOIs addObject:poi];
    }
    
    BOOL ignoreFacility = [[NSUserDefaults standardUserDefaults] boolForKey:@"ignore_facility"];
    if (ignoreFacility && [poi.origin isKindOfClass:HLPEntrance.class]) {
        return;
    }
    
    if (poi.needsToPlaySound) {
        // play something
    }
    if (poi.forDoor || poi.forObstacle || poi.forRamp || poi.forBrailleBlock) {
        if (poi.countApproached == 0) { // only for first time
            NSString *string = [self poiString:poi withOption:@{@"short":@(shortSentence)}];
            [_delegate speak:string withOptions:properties completionHandler:^{}];
            lastPOIAnnounceTime = now;
        }
    } else if (poi.requiresUserAction) {
    } else {
        NSString *angle;
        if (!isnan(heading)) {
            if (heading < -30) {
                angle = NSLocalizedStringFromTable(@"on your left side",@"BlindView", @""); //@"左";
            } else if (heading > 30) {
                angle = NSLocalizedStringFromTable(@"on your right side",@"BlindView", @""); //@"右";
            } else {
                angle = NSLocalizedStringFromTable(@"in front of you",@"BlindView", @""); //@"正面";
            }
        }
        
        NSString *text = poi.text;
        NSString *ld = poi.longDescription;
        
        
        NSMutableString *string = [@"" mutableCopy];
        if (angle && (poi.text || text)) {
            if (poi.isDestination) {
                [string appendFormat:NSLocalizedStringFromTable(@"destination is %@", @"BlindView", @""), text, angle];
                /*if (poi.text) {
                    [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
                    [string appendString:poi.text];
                }*/
                isDestinationPOI = YES;
            } else {
                if (poi.flagPlural) {
                    [string appendFormat:NSLocalizedStringFromTable(@"poi are %@", @"BlindView", @""), text, angle];
                } else if (poi.flagOnomastic) {
                    [string appendFormat:NSLocalizedStringFromTable(@"name is %@", @"BlindView", @""), text, angle];
                } else {
                    [string appendFormat:NSLocalizedStringFromTable(@"poi is %@", @"BlindView", @""), text, angle];
                }
            }
        } else {
            if (text) {
                [string appendString:text];
            }
        }
        if (ld) {
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
            [string appendString:ld];
        }
        
        NSArray *result = [self checkCommand:string];
        
        [_delegate speak:result[0] withOptions:properties completionHandler:^{
            if (isDestinationPOI) {
                [[NavDataStore sharedDataStore] clearRoute];
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RATING object:nil];
            }
            
            if ([result count] < 2) {
                return;
            }
            [_delegate executeCommand:result[1]];
        }];
        lastPOIAnnounceTime = now;
    }
}


- (NSArray*)checkCommand:(NSString *)text
{
    NSRegularExpression *commandPattern = [NSRegularExpression regularExpressionWithPattern:@"\\[\\[([^\\]]+)\\]\\]" options:0 error:nil];
    
    NSTextCheckingResult *result;
    NSMutableArray *commands = [@[] mutableCopy];
    while((result = [commandPattern firstMatchInString:text options:0 range:NSMakeRange(0, [text length])]) != nil) {
        NSString *command = [text substringWithRange:[result rangeAtIndex:1]];
        text = [text stringByReplacingCharactersInRange:result.range withString:@""];
        [commands addObject:command];
    }
    [commands insertObject:text atIndex:0];
    return commands;
}

- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NavPOI *poi = properties[@"poi"];
    if (poi && [approachingPOIs containsObject:poi]) {
        [approachingPOIs removeObject:poi];
    }
}

- (NSString *)summaryString:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    double distance = [properties[@"distance"] doubleValue];
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    BOOL isNextDestination = [properties[@"isNextDestination"] boolValue];
    
    NSString *action = [self actionString:properties];
    NSMutableString *string = [@"" mutableCopy];
    
    NSArray *pois = properties[@"pois"];
    [string appendString:[self startPOIString:pois]];

    NSString *floorInfo = [self floorPOIString:pois];
    
    NSString *dist = [self distanceString:distance];
    
    if (linkType == LINK_TYPE_ELEVATOR || linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        [string appendString:action];
    }
    else if (isNextDestination) {
        NSString *destTitle = [NavDataStore sharedDataStore].to.namePron;
        
        [string appendString: [NSString stringWithFormat:NSLocalizedStringFromTable(@"destination is in distance",@"BlindView",@"remaining distance to the destination"), destTitle, dist]];
    }
    else if (action) {
        NSString *proceedString = @"proceed distance";
        NSString *nextActionString = @"and action";
        
        if (floorInfo) {
            proceedString = [proceedString stringByAppendingString:@" on floor"];
        }
        proceedString = [proceedString stringByAppendingString:@" ..."];
        
        proceedString = NSLocalizedStringFromTable(proceedString, @"BlindView", @"");
        proceedString = [NSString stringWithFormat:proceedString, dist, floorInfo];
        nextActionString = NSLocalizedStringFromTable(nextActionString, @"BlindView", @"");
        nextActionString = [NSString stringWithFormat:nextActionString, action];
        
        [string appendString:proceedString];
        [string appendString:nextActionString];
    }
    
    return string;
}
- (void)currentStatus:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    BOOL resume = [properties[@"resume"] boolValue];
    
    HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
    double minDistance = DBL_MAX;
    NavPOI *nearestPOI = nil;
    for(NavPOI *poi in approachingPOIs) {
        double d = [poi.poiLocation distanceTo:location];
        if (d < minDistance) {
            minDistance = d;
            nearestPOI = poi;
        }
    }
    if (minDistance < 10) {
        [self userIsApproachingToPOI:@{
                                       @"poi": nearestPOI,
                                       @"heading": @(nearestPOI.diffAngleFromUserOrientation)
                                       }];
        if (!resume) {
            return;
        }
    }
    if (resume) { // read both poi and status info. when it is resumed
        properties = [properties mtl_dictionaryByAddingEntriesFromDictionary:@{@"force":@(NO)}];
    }
    
    double distance = [properties[@"distance"] doubleValue];

    BOOL offRoute = [properties[@"offRoute"] boolValue];
    if (offRoute) {
        NSString *directionString = [self directionString:properties];
        NSString *distanceString = [self distanceString:distance];
        
        NSString *string = [directionString stringByAppendingString:distanceString];
        
        [self.delegate vibrate];
        [self.delegate speak:string withOptions:properties completionHandler:^{}];
        return;
    }
    
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    BOOL isNextDestination = [properties[@"isNextDestination"] boolValue];
    
    NSString *action = [self actionString:properties];
    NSMutableString *string = [@"" mutableCopy];
    
    NSArray *pois = properties[@"pois"];
    //[string appendString:[self startPOIString:pois]];
    
    NSString *floorInfo = [self floorPOIString:pois];
    
    NSString *dist = [self distanceString:distance];
    
    if (linkType == LINK_TYPE_ELEVATOR || linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        [string appendString:action];
    }
    else if (isNextDestination) {
        NSString *destTitle = [NavDataStore sharedDataStore].to.namePron;
        
        [string appendString: [NSString stringWithFormat:NSLocalizedStringFromTable(@"destination is in distance",@"BlindView",@"remaining distance to the destination"), destTitle, dist]];
    }
    else if (action) {
        NSString *proceedString = @"proceed distance";
        NSString *nextActionString = @"and action";
        
        if (floorInfo) {
            proceedString = [proceedString stringByAppendingString:@" on floor"];
        }
        proceedString = [proceedString stringByAppendingString:@" ..."];
        
        if (dist) {
            proceedString = NSLocalizedStringFromTable(proceedString, @"BlindView", @"");
            proceedString = [NSString stringWithFormat:proceedString, dist, floorInfo];
            [string appendString:proceedString];
        }
        
        if (action) {
            nextActionString = NSLocalizedStringFromTable(nextActionString, @"BlindView", @"");
            nextActionString = [NSString stringWithFormat:nextActionString, action];
            [string appendString:nextActionString];
        }
    }
    
    [self.delegate vibrate];
    [self.delegate speak:string withOptions:properties completionHandler:^{}];
    
}

- (void)requiresHeadingCalibration:(NSDictionary *)properties
{
    BOOL noLocation = [properties[@"noLocation"] boolValue];
    if (noLocation) {
        [self.delegate speak:NSLocalizedStringFromTable(@"NO_AVAILABLE_LOCATION",@"BlindView", @"") withOptions:properties completionHandler:^{}];

        return;
    }
    BOOL silenceIfCalibrated = properties[@"silenceIfCalibrated"] != nil && [properties[@"silenceIfCalibrated"] boolValue];
    double acc = [properties[@"accuracy"] doubleValue];
    NSString *string;
    if (acc > 45) {
        string = NSLocalizedStringFromTable(@"HEADING_CALIBRATION", @"BlindView", @"");        
    }
    else if (acc > 22.5) {
        string = NSLocalizedStringFromTable(@"HEADING_CALIBRATION2", @"BlindView", @"");
    }
    else if (!silenceIfCalibrated){
        string = NSLocalizedStringFromTable(@"HEADING_CALIBRATION3", @"BlindView", @"");
    }
    [self.delegate vibrate];
    [self.delegate speak:string withOptions:properties completionHandler:^{}];
}

-(void)reroute:(NSDictionary *)properties
{
    NSString *string = NSLocalizedStringFromTable(@"REROUTING", @"BlindView", @"");
    [self.delegate vibrate];
    [self.delegate speak:string withOptions:properties completionHandler:^{}];
}

- (void)requestNearestPOI:(NSNotification*)note
{
    HLPLocation *location = [[NavDataStore sharedDataStore] currentLocation];
    double minDistance = DBL_MAX;
    NavPOI *nearestPOI = nil;
    for(NavPOI *poi in approachingPOIs) {
        double d = [poi.poiLocation distanceTo:location];
        if (d < minDistance) {
            minDistance = d;
            nearestPOI = poi;
        }
    }
    if (minDistance < 10 && nearestPOI.hasContent) {
        [self.delegate showPOI:nearestPOI.contentURL withName:nearestPOI.contentName];
    }
}



@end
