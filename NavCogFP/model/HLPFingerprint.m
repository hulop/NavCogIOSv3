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

#import "HLPFingerprint.h"

@implementation HLPDBObject

+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"_id": @"_id",
             @"_metadata": @"_metadata"
             };
}
static NSValueTransformer *transformer;
+(NSValueTransformer*) stringNumberTransformer
{
    if (!transformer) {
        transformer = [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
            if ([value isKindOfClass:NSString.class]) {
                return @([((NSString*)value) doubleValue]);
            } else {
                return value;
            }
        }];
    }
    return transformer;
}
@end

@implementation HLPFloorplan
+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
             @"type": @"type",
             @"group": @"group",
             @"floor": @"floor",
             @"origin_x": @"origin_x",
             @"origin_y": @"origin_y",
             @"width": @"width",
             @"height": @"height",
             @"ppm_x": @"ppm_x",
             @"ppm_y": @"ppm_y",
             @"filename": @"filename",
             @"lat": @"lat",
             @"lng": @"lng",
             @"rotate": @"rotate",
             @"beacons": @"beacons"
             }];
}

+ (NSValueTransformer *)floorJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)origin_xJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)origin_yJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)widthJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)heightJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)ppm_xJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)ppm_yJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)latJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)lngJSONTransformer { return [HLPDBObject stringNumberTransformer];}
+ (NSValueTransformer *)rotateJSONTransformer { return [HLPDBObject stringNumberTransformer];}
@end

@implementation HLPRefpoint
+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
             @"filename": @"filename",
             @"floor": @"floor",
             @"floor_num": @"floor_num",
             @"anchor_lat": @"anchor_lat",
             @"anchor_lng": @"anchor_lng",
             @"anchor_rotate": @"anchor_rotate",
             @"refid": @"refid",
             @"x": @"x",
             @"y": @"y",
             @"rotate": @"rotate"
             }];
}

- (void) updateWithFloorplan:(HLPFloorplan*) floorplan
{
    _anchor_lat = floorplan.lat;
    _anchor_lng = floorplan.lng;
    _anchor_rotate = floorplan.rotate;
    _floor_num = floorplan.floor;
    _filename = floorplan.filename;
}

+ (NSValueTransformer *)rotateEntityAttributeTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(id value, BOOL *success, NSError *__autoreleasing *error) {
        if ([value isKindOfClass:NSString.class]) {
            return @([((NSString*)value) doubleValue]);
        } else {
            return value;
        }
    }];
}
@end

@implementation HLPSampling

- (NSString *)description {
    return self._id[@"$oid"];
}

+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
             @"information": @"information",
             @"beacons": @"beacons"
             }];
}
@end

@implementation HLPSamplingInfo
+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"refid": @"refid",
             @"x": @"x",
             @"y": @"y",
             @"absx": @"absx",
             @"absy": @"absy",
             @"floor" : @"floor",
             @"floor_num": @"floor_num"
             };
}
@end
