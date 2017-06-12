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


#import "NavBlindWebviewHelper.h"
#import <Mantle/Mantle.h>

@implementation NavBlindWebviewHelper

# pragma mark - public methods

- (void)initTarget:(NSArray *)landmarks
{
    NSMutableArray *temp = [@[] mutableCopy];
    NSError *error;
    for(id obj in landmarks) {
        [temp addObject:[MTLJSONAdapter JSONDictionaryFromModel:obj error:&error]];
    }
    
    if ([temp count] == 0) {
        //NSLog(@"No Landmarks %@", landmarks);
        return;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"landmarks":temp} options:0 error:nil];
    NSString *dataStr = [[NSString alloc] initWithData:data  encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"$hulop.map.initTarget(%@, null)", dataStr];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self evalScript:script];
    });
}

- (void)clearRoute
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self evalScript:@"$hulop.map.clearRoute()"];
    });
}

- (void)showRoute:(NSArray *)route
{
    NSMutableArray *temp = [@[] mutableCopy];
    NSError *error;
    for(id obj in route) {
        [temp addObject:[MTLJSONAdapter JSONDictionaryFromModel:obj error:&error]];
    }
    
    if ([temp count] == 0) {
        NSLog(@"No Route %@", route);
        return;
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:temp options:0 error:nil];
    NSString *dataStr = [[NSString alloc] initWithData:data  encoding:NSUTF8StringEncoding];
    
    NSString *script = [NSString stringWithFormat:@"$hulop.map.showRoute(%@, null, true, true);/*$hulop.map.showResult(true);*/$('#map-page').trigger('resize');", dataStr];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self evalScript:script];
    });
}

- (HLPLocation *)getCenter
{
    NSString *script = @"(function(){var a=$hulop.map.getCenter();var f=$hulop.indoor.getCurrentFloor();f=f>0?f-1:f;return JSON.stringify({lat:a[1],lng:a[0],floor:f});})()";
    NSString *state = [self evalScript:script];
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[state dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
    if (json) {
        return [[HLPLocation alloc] initWithLat:[json[@"lat"] doubleValue]
                                            Lng:[json[@"lng"] doubleValue]
                                          Floor:[json[@"floor"] doubleValue]];
    } else {
        NSLog(@"%@", error.localizedDescription);
    }
    return nil;
    
}


- (void) manualLocation: (HLPLocation*) loc withSync:(BOOL)sync
{
    NSMutableString* script = [[NSMutableString alloc] init];
    if (loc && !isnan(loc.floor) ) {
        int ifloor = round(loc.floor<0?loc.floor:loc.floor+1);
        [script appendFormat:@"$hulop.indoor.showFloor(%d);", ifloor];
    }
    [script appendFormat:@"$hulop.map.setSync(%@);", sync?@"true":@"false"];
    if (loc) {
        [script appendFormat:@"var map = $hulop.map;"];
        [script appendFormat:@"map.setCenter([%f,%f]);",loc.lng,loc.lat];
    } else {
        [script appendFormat:@"var map = $hulop.map"];
        [script appendFormat:@"var c = map.getCenter();"];
        [script appendFormat:@"map.setCenter(c);"];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self evalScript:script];
    });
}

@end
