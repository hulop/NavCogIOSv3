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

#import <Foundation/Foundation.h>

#import "HLPGeoJSON.h"
#import <Mantle.h>
#import <HLPLocationManager/HLPLocation.h>

@interface HLPDBObject : MTLModel<MTLJSONSerializing, NSCoding>
@property (nonatomic, readonly) NSDictionary *_id;
@property (nonatomic, readonly) NSDictionary *_metadata;
@end

@interface HLPFloorplan : HLPDBObject
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSString *group;
@property (nonatomic, readonly) double floor;
@property (nonatomic, readonly) double origin_x;
@property (nonatomic, readonly) double origin_y;
@property (nonatomic, readonly) double width;
@property (nonatomic, readonly) double height;
@property (nonatomic, readonly) double ppm_x;
@property (nonatomic, readonly) double ppm_y;
@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) double lat;
@property (nonatomic, readonly) double lng;
@property (nonatomic, readonly) double rotate;
@property (nonatomic) HLPGeoJSON *beacons;
@end

@interface HLPRefpoint : HLPDBObject
@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) NSDictionary *refid;
@property (nonatomic, readonly) NSString *floor;
@property (nonatomic, readonly) double floor_num;
@property (nonatomic, readonly) double anchor_lat;
@property (nonatomic, readonly) double anchor_lng;
@property (nonatomic, readonly) double anchor_rotate;
@property (nonatomic, readonly) double x;
@property (nonatomic, readonly) double y;
@property (nonatomic, readonly) double rotate;
- (void) updateWithFloorplan:(HLPFloorplan*) floorplan;
@end

@interface HLPSamplingInfo : MTLModel<MTLJSONSerializing, NSCoding>
@property (nonatomic, readonly) NSDictionary *refid;
@property (nonatomic, readonly) double x;
@property (nonatomic, readonly) double y;
@property (nonatomic, readonly) double absx;
@property (nonatomic, readonly) double absy;
@property (nonatomic, readonly) NSString* floor;
@property (nonatomic, readonly) double floor_num;
@end

@interface HLPSampling : HLPDBObject
@property (nonatomic, readonly) HLPSamplingInfo *information;
@property (nonatomic, readonly) NSArray *beacons;
@property (nonatomic) double lat;
@property (nonatomic) double lng;
@end
