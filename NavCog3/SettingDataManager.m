//
//
//  SettingDataManager.m
//  NavCog3
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation
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

#import <Foundation/Foundation.h>
#import "SettingDataManager.h"

@implementation SettingDataManager
static SettingDataManager *sharedData_ = nil;

+ (SettingDataManager *)sharedManager{
   @synchronized(self){
       if (!sharedData_) {
           sharedData_ = [SettingDataManager new];
       }
   }
   return sharedData_;
}

- (id)init
{
   self = [super init];
   if (self) {
       //Initialization
   }
   return self;
}

- (NSMutableDictionary *)getPrefs {

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *prefs = [@{} mutableCopy];

    int presetId = 1;
    int min_width = 9;
    int road_condition = 9;
    int deff_LV = 9;
    int slope = 9;
    int stairs = 9;
    int esc = 9;
    int elv = 1;
    int mvw = 1;
    int tactile_paving = 9;

    NSString* userMode = [ud stringForKey:@"user_mode"];

    if ([userMode isEqualToString:@"user_wheelchair"]) {
        presetId = 2;
        min_width = 2;
        road_condition = 1;
        deff_LV = 2;
        slope = 1;
        stairs = 1;
        esc = 1;
        elv = 2;
        mvw = 1;
        tactile_paving = 1;
    } else if ([userMode isEqualToString:@"user_stroller"]) {
        presetId = 3;
        min_width = 3;
        road_condition = 1;
        deff_LV = 3;
        slope = 1;
        stairs = 1;
        esc = 1;
        elv = 9;
        mvw = 9;
        tactile_paving = 1;
    } else if ([userMode isEqualToString:@"user_blind"]) {
        presetId = 9;
        min_width = 8;
        road_condition = 9;
        deff_LV = 2;
        slope = 1;
        stairs = [ud boolForKey:@"route_use_stairs"] ? 9 : 1;
        esc = [ud boolForKey:@"route_use_escalator"] ? 9 : 1;
        elv = [ud boolForKey:@"route_use_elevator"] ? 9 : 1;
        mvw = [ud boolForKey:@"route_use_moving_walkway"] ? 9 : 1;
        tactile_paving = [ud boolForKey:@"route_tactile_paving"] ? 1 : 0;
    }

    prefs[@"dist"] = @"1000";
    prefs[@"preset"] = [NSString stringWithFormat:@"%d", presetId];
    prefs[@"slope"] = [NSString stringWithFormat:@"%d", slope];
    prefs[@"min_width"] = [NSString stringWithFormat:@"%d", min_width];
    prefs[@"road_condition"] = [NSString stringWithFormat:@"%d", road_condition];
    prefs[@"deff_LV"] = [NSString stringWithFormat:@"%d", deff_LV];
    prefs[@"stairs"] = [NSString stringWithFormat:@"%d", stairs];
    prefs[@"esc"] = [NSString stringWithFormat:@"%d", esc];
    prefs[@"elv"] = [NSString stringWithFormat:@"%d", elv];
    prefs[@"mvw"] = [NSString stringWithFormat:@"%d", mvw];
    prefs[@"tactile_paving"] = [NSString stringWithFormat:@"%d", tactile_paving];

    return prefs;
}

@end
