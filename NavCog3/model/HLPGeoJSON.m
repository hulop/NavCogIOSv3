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

#import "HLPGeoJSON.h"
#import "HLPLocation.h"

#define PROPKEY_NODE_ID @"ノードID"
#define PROPKEY_NODE_FOR_ID @"対応ノードID"
#define PROPKEY_LINK_ID @"リンクID"
#define PROPKEY_FACILITY_ID @"施設ID"
#define PROPKEY_FACILITY_FOR_ID @"対応施設ID"
#define PROPKEY_ENTRANCE_ID @"出入口ID"
#define PROPKEY_HEIGHT @"高さ"
#define PROPKEY_CONNECTED_LINK_ID_PREFIX @"接続リンクID"
#define PROPKEY_LINK_LENGTH @"リンク延長"
#define PROPKEY_LINK_DIRECTION @"方向性"
#define PROPKEY_LINK_TYPE @"経路の種類"
#define PROPKEY_TARGET_NODE_ID @"終点ノードID"
#define PROPKEY_SOURCE_NODE_ID @"起点ノードID"
#define PROPKEY_NAME @"名称"
#define PROPKEY_ENTRANCE_NAME @"出入口の名称"
#define PROPKEY_MALE_OR_FEMALE @"男女別"
#define PROPKEY_MULTI_PURPOSE_TOILET @"多目的トイレ"

// for extension
#define PROPKEY_EXT_MAJOR_CATEGORY @"major_category"
#define PROPKEY_EXT_SUB_CATEGORY @"sub_category"
#define PROPKEY_EXT_MINOR_CATEGORY @"minor_category"
#define PROPKEY_EXT_LONG_DESCRIPTION @"long_description"
#define PROPKEY_EXT_HEADING @"heading"
#define PROPKEY_EXT_ANGLE @"angle"
#define PROPKEY_EXT_HEIGHT @"height"


#define CATEGORY_LINK @"リンクの情報"
#define CATEGORY_NODE @"ノード情報"
#define CATEGORY_PUBLIC_FACILITY @"公共施設の情報"
#define CATEGORY_ENTRANCE @"出入口情報"
#define CATEGORY_TOILET @"公共用トイレの情報"

#define NAV_POI @"_nav_poi_"
#define POI_CATEGORY_INFO @"_nav_info_"
#define POI_CATEGORY_CORNER @"_nav_corner_"
#define POI_CATEGORY_FLOOR @"_nav_floor_"

#define POI_CATEGORY_SCENE @"_nav_scene_"

#define POI_CATEGORY_OBJECT @"_nav_object_"
#define POI_CATEGORY_SIGN @"_nav_sign_"

#define POI_CATEGORY_SHOP @"_nav_shop_"
#define POI_CATEGORY_LIVE @"_nav_live_"
#define POI_FLAGS_CAUTION @"_nav_caution_"
#define POI_FLAGS_PLURAL @"_nav_plural_"

@implementation HLPGeometry
+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"type": @"type",
             @"coordinates": @"coordinates"
             };
}
@end

@implementation HLPGeoJSON {
    HLPLocation *loc1;
    HLPLocation *loc2;
    HLPLocation *loc3;
}

+(NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"type": @"type",
             @"geometry": @"geometry",
             @"properties": @"properties"
             };
}


- (HLPLocation*)nearestLocationTo:(HLPLocation*)location
{
    if (!loc1) {
        loc1 = [[HLPLocation alloc] init];
        loc2 = [[HLPLocation alloc] init];
        loc3 = [[HLPLocation alloc] init];
    }
    
    [loc1 update:location];
    double dist = DBL_MAX;
    HLPLocation *minloc;
    if ([self.geometry.type isEqualToString:@"Point"]) {
        dist = [loc1 distanceToLat:[self.geometry.coordinates[1] doubleValue]
                              Lng:[self.geometry.coordinates[0] doubleValue]];
    } else if ([self.geometry.type isEqualToString:@"LineString"]) {
        for(int i = 0; i < [self.geometry.coordinates count]-1; i++) {
            [loc2 updateLat:[self.geometry.coordinates[i][1] doubleValue]
                        Lng:[self.geometry.coordinates[i][0] doubleValue]];
            [loc3 updateLat:[self.geometry.coordinates[i+1][1] doubleValue]
                        Lng:[self.geometry.coordinates[i+1][0] doubleValue]];
            
            HLPLocation *loc = [loc1 nearestLocationToLineFromLocation:loc2 ToLocation:loc3];
            double temp = [loc1 distanceToLineFromLocation:loc2 ToLocation:loc3];
            if (temp < dist) {
                dist = temp;
                minloc = loc;
            }
        }
    }
    
    return minloc;
}

@end

@implementation HLPObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;

    NSString *category = [[self properties] objectForKey:@"category"];
    if ([CATEGORY_LINK isEqualToString:category]) {
        _category = HLP_OBJECT_CATEGORY_LINK;
    } else if ([CATEGORY_NODE isEqualToString:category]) {
        _category = HLP_OBJECT_CATEGORY_NODE;
    } else if ([CATEGORY_PUBLIC_FACILITY isEqualToString:category]) {
        _category = HLP_OBJECT_CATEGORY_PUBLIC_FACILITY;
    } else if ([CATEGORY_ENTRANCE isEqualToString:category]) {
        _category = HLP_OBJECT_CATEGORY_ENTRANCE;
    } else if ([CATEGORY_TOILET isEqualToString:category]) {
        _category = HLP_OBJECT_CATEGORY_TOILET;
    }
    
    return self;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:@{
              @"_id": @"_id",
              @"_rev": @"_rev"
              }];
}

+ (Class)classForParsingJSONDictionary:(NSDictionary *)JSONDictionary
{
    if (JSONDictionary[@"category"] != nil) {
        return HLPLandmark.class;
    }    
    
    NSDictionary* properties = JSONDictionary[@"properties"];
    if (properties) {
        if ([properties[PROPKEY_EXT_MAJOR_CATEGORY] isEqualToString:NAV_POI]) {
            return HLPPOI.class;
        }
        if (properties[PROPKEY_NODE_ID] != nil) {
            return HLPNode.class;
        }        
        if (properties[PROPKEY_LINK_ID] != nil) {
            return HLPLink.class;
        }
        if (properties[PROPKEY_FACILITY_ID] != nil) {
            return HLPFacility.class;
        }
        if (properties[PROPKEY_ENTRANCE_ID] != nil) {
            return HLPEntrance.class;
        }
     }
    return self;
}

- (NSString *)getLandmarkName
{
    NSDictionary *properties = super.properties;
    
    NSMutableString *temp = [[NSMutableString alloc] init];

    if (self.category == HLP_OBJECT_CATEGORY_PUBLIC_FACILITY) {
        [temp appendString:properties[PROPKEY_NAME]];
    }
    else if(self.category == HLP_OBJECT_CATEGORY_ENTRANCE) {
        [temp appendString:properties[PROPKEY_ENTRANCE_NAME]];
    }
    else if(self.category == HLP_OBJECT_CATEGORY_TOILET) {
        temp = [[NSMutableString alloc] init];
        if (properties) {
            NSString *sex = properties[PROPKEY_MALE_OR_FEMALE];
            if ([sex isEqualToString:@"1"]) {
                [temp appendString:NSLocalizedString(@"FOR_MALE",@"Toilet for male")];
            }
            else if ([sex isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_FEMALE",@"Toilet for female")];
            }
            NSString *multi = properties[PROPKEY_MULTI_PURPOSE_TOILET];
            
            if ([multi isEqualToString:@"1"] || [multi isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_DISABLED", @"Toilet for people with disability")];
            }
        }
        [temp appendString:NSLocalizedString(@"TOILET",@"Toilet")];
        
    }
    
    return [temp stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

- (void)updateWithLang:(NSString *)lang
{
    // need to override;
}

- (NSString*) getI18nAttribute:(NSString*)name Lang:(NSString*)lang
{
    NSString *key = [NSString stringWithFormat:@"%@:%@", name, lang];
    if (self.properties[key]) {
        return self.properties[key];
    } else {
        return self.properties[name];
    }
}

- (NSString*) getI18nPronAttribute:(NSString*)name Lang:(NSString*)lang
{
    NSString *key = [NSString stringWithFormat:@"%@:%@", name, lang];
    NSString *pronKey = [key stringByAppendingString:@"-Pron"];
    
    if (self.properties[pronKey]) {
        return self.properties[pronKey];
    } else {
        return self.properties[key];
    }
}



@end

@implementation HLPLandmark

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [[super JSONKeyPathsByPropertyKey] mtl_dictionaryByAddingEntriesFromDictionary:
            @{
              @"category": @"category",
              @"exit": @"exit",
              @"name": @"name",
              @"namePron": @"name_pron",
              @"nodeID": @"node"
              }];
}

- (NSString *)getLandmarkName
{
    return [self _getLandmarkName:_name];
}

- (NSString *)getLandmarkNamePron
{
    return [self _getLandmarkName:_namePron];
}

- (NSString *)_getLandmarkName:(NSString*)name
{
    NSString *exit = _exit;
    NSString *category = _category;
    NSDictionary *properties = super.properties;
    
    NSMutableString *temp = [[NSMutableString alloc] init];
    [temp appendString:name];
    
    if (exit && [exit length] > 0) {
        [temp appendFormat:@" %@", exit];
    }
    if ((!name || [name length] == 0) && [category isEqualToString:CATEGORY_TOILET]) {
        temp = [[NSMutableString alloc] init];
        if (properties) {
            NSString *sex = properties[PROPKEY_MALE_OR_FEMALE];
            if ([sex isEqualToString:@"1"]) {
                [temp appendString:NSLocalizedString(@"FOR_MALE",@"Toilet for male")];
            }
            else if ([sex isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_FEMALE",@"Toilet for female")];
            }
            NSString *multi = properties[PROPKEY_MULTI_PURPOSE_TOILET];
            
            if ([multi isEqualToString:@"1"] || [multi isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_DISABLED", @"Toilet for people with disability")];
            }
        }
        [temp appendString:NSLocalizedString(@"TOILET",@"Toilet")];
        
    }
    
    return [temp stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

- (BOOL)isToilet
{
    return [_category isEqualToString:CATEGORY_TOILET];
}


@end

@implementation HLPNode {
    HLPLocation *_location;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;

    _lat = [self.geometry.coordinates[1] doubleValue];
    _lng = [self.geometry.coordinates[0] doubleValue];
    
    _height = [self.properties[PROPKEY_HEIGHT] doubleValue];
    _height = (_height >= 1)?_height-1:_height;
    
    _location = [[HLPLocation alloc] initWithLat:_lat Lng:_lng Floor:_height];    

    NSMutableArray* temp = [@[] mutableCopy];
    for(NSString *key in [self.properties allKeys]) {
        if ([key hasPrefix:PROPKEY_CONNECTED_LINK_ID_PREFIX]) {
            [temp addObject:self.properties[key]];
        }
    }
    _connectedLinkIDs = temp;
    
    return self;
}

- (HLPLocation*) location
{
    return _location;
}

@end

@implementation HLPLink {
@protected
    double initialBearingFromSource;
    double lastBearingForTarget;
}

+ (NSString *)nameOfLinkType:(HLPLinkType)type
{
    switch (type) {
        case LINK_TYPE_SIDEWALK: return NSLocalizedStringFromTable(@"sidewalk", @"HLPGeoJSON", @"歩道");
        case LINK_TYPE_PEDESTRIAN_ROAD: return NSLocalizedStringFromTable(@"pedestrian road", @"HLPGeoJSON", @"歩行者専用道路");
        case LINK_TYPE_GARDEN_WALK: return NSLocalizedStringFromTable(@"garden walk", @"HLPGeoJSON", @"園路");
        case LINK_TYPE_ROAD_WITHOUT_SIDEWALK: return NSLocalizedStringFromTable(@"road", @"HLPGeoJSON", @"歩車共存道路");
        case LINK_TYPE_CROSSING: return NSLocalizedStringFromTable(@"crossing", @"HLPGeoJSON", @"横断歩道");
        case LINK_TYPE_CROSSING_WITHOUT_SIGN: return NSLocalizedStringFromTable(@"crossing without sign", @"HLPGeoJSON", @"横断歩道の路面標示の無い交差点の道路");
        case LINK_TYPE_PEDESTRIAN_CONVEYER: return NSLocalizedStringFromTable(@"pedestrian conveyer", @"HLPGeoJSON", @"動く歩道");
        case LINK_TYPE_FREE_WALKWAY: return NSLocalizedStringFromTable(@"free walkway", @"HLPGeoJSON", @"自由通路");
        case LINK_TYPE_RAIL_CROSSING: return NSLocalizedStringFromTable(@"rail crossing", @"HLPGeoJSON", @"踏切");
        case LINK_TYPE_ELEVATOR: return NSLocalizedStringFromTable(@"elevator", @"HLPGeoJSON", @"エレベーター");
        case LINK_TYPE_ESCALATOR: return NSLocalizedStringFromTable(@"escalator", @"HLPGeoJSON", @"エスカレーター");
        case LINK_TYPE_STAIRWAY: return NSLocalizedStringFromTable(@"stairway", @"HLPGeoJSON", @"階段");
        case LINK_TYPE_RAMP: return NSLocalizedStringFromTable(@"ramp", @"HLPGeoJSON", @"スロープ");
        case LINK_TYPE_UNKNOWN: return NSLocalizedStringFromTable(@"unknown", @"HLPGeoJSON", @"不明");
    }
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;

    _length = [self.properties[PROPKEY_LINK_LENGTH] doubleValue];
    
    _direction = [self.properties[PROPKEY_LINK_DIRECTION] intValue];
    _sourceNodeID = self.properties[@"sourceNode"];
    _sourceHeight = [self.properties[@"sourceHeight"] doubleValue];
    _targetNodeID = self.properties[@"targetNode"];
    _targetHeight = [self.properties[@"targetHeight"] doubleValue];

    _linkType = [self.properties[PROPKEY_LINK_TYPE] intValue];
    
    [self update];
    return self;
}

- (void) update
{
    _sourceHeight = (_sourceHeight >= 1)?_sourceHeight-1:_sourceHeight;
    _targetHeight = (_targetHeight >= 1)?_targetHeight-1:_targetHeight;
    
    
    _backward = [self.properties[PROPKEY_TARGET_NODE_ID] isEqualToString:_sourceNodeID];

    if (self.geometry) {
        if ([self.geometry.type isEqualToString:@"LineString"] && [self.geometry.coordinates count] >= 2) {
            NSArray *first = self.geometry.coordinates[_backward?[self.geometry.coordinates count]-1:0];
            NSArray *second = self.geometry.coordinates[_backward?[self.geometry.coordinates count]-2:1];
            
            NSArray *last = self.geometry.coordinates[!_backward?[self.geometry.coordinates count]-1:0];
            NSArray *secondLast = self.geometry.coordinates[!_backward?[self.geometry.coordinates count]-2:1];
            
            sourceLocation = [[HLPLocation alloc] initWithLat:[first[1] doubleValue] Lng:[first[0] doubleValue] Floor:_sourceHeight];
            
            initialBearingFromSource = [sourceLocation bearingToLat:[second[1] doubleValue]
                                                               Lng:[second[0] doubleValue]];
            
            targetLocation = [[HLPLocation alloc] initWithLat:[last[1] doubleValue] Lng:[last[0] doubleValue] Floor:_targetHeight];
            
            lastBearingForTarget = [HLPLocation bearingFromLat:[secondLast[1] doubleValue]
                                                           Lng:[secondLast[0] doubleValue]
                                                         toLat:[last[1] doubleValue]
                                                           Lng:[last[0] doubleValue]];
        } else if ([self.geometry.type isEqualToString:@"Point"] && [self.geometry.coordinates count] == 2) {
            double lat = [self.geometry.coordinates[1] doubleValue];
            double lng = [self.geometry.coordinates[0] doubleValue];
            
            sourceLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:_sourceHeight];
            targetLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:_targetHeight];
            
            initialBearingFromSource = lastBearingForTarget = NAN;
        }
    }
}

- (void)updateWithNodesMap:(NSDictionary *)nodesMap
{
    _sourceNodeID = self.properties[PROPKEY_SOURCE_NODE_ID];
    HLPNode *snode = nodesMap[_sourceNodeID];
    if (snode) {
        _sourceHeight = snode.height;
    }
    
    _targetNodeID = self.properties[PROPKEY_TARGET_NODE_ID];
    HLPNode *tnode = nodesMap[_targetNodeID];
    if (tnode) {
        _targetHeight = tnode.height;
    }
}

- (double)initialBearingFromSource
{
    return initialBearingFromSource;
}

- (double)lastBearingForTarget
{
    return lastBearingForTarget;
}

- (HLPLocation *)sourceLocation
{
    return sourceLocation;
}

- (HLPLocation *)targetLocation
{
    return targetLocation;
}

- (HLPLocation *)locationDistanceToTarget:(double)distance
{
    if ([_geometry.type isEqualToString:@"Point"]) {
        return [[HLPLocation alloc] initWithLat:[_geometry.coordinates[1] doubleValue] Lng:[_geometry.coordinates[0] doubleValue]];
    }
    
    NSArray *coords = _geometry.coordinates;
    if (!_backward) {
        coords = [[coords reverseObjectEnumerator] allObjects];
    }
    
    HLPLocation *loc = nil;
    for(int i = 0; i < [coords count]-1; i++) {
        NSArray *p1 = coords[i];
        NSArray *p2 = coords[i+1];
        double lat1 = [p1[1] doubleValue];
        double lng1 = [p1[0] doubleValue];
        double lat2 = [p2[1] doubleValue];
        double lng2 = [p2[0] doubleValue];
        
        double d = [HLPLocation distanceFromLat:lat1 Lng:lng1 toLat:lat2 Lng:lng2];
        
        if (distance < d) {
            double lat3 = (lat2-lat1)*distance/d+lat1;
            double lng3 = (lng2-lng1)*distance/d+lng1;
            loc = [[HLPLocation alloc] initWithLat:lat3 Lng:lng3];
            break;
        }
        distance -= d;
    }
    if (loc == nil) {
        loc =  [[HLPLocation alloc] initWithLat:[[coords lastObject][1] doubleValue] Lng:[[coords lastObject][0] doubleValue]];
    }

    return loc;
}

- (void)setTargetNodeIfNeeded:(HLPNode *)node withNodesMap:(NSDictionary *)nodesMap
{
    if (_sourceNodeID && _targetNodeID) {
        return;
    }
    _targetNodeID = node._id;
    if ([self.properties[PROPKEY_TARGET_NODE_ID] isEqualToString:_targetNodeID]) {
        _sourceNodeID = self.properties[PROPKEY_SOURCE_NODE_ID];
    } else {
        _sourceNodeID = self.properties[PROPKEY_TARGET_NODE_ID];
    }

    if (nodesMap[_sourceNodeID]) {
        _sourceHeight = [nodesMap[_sourceNodeID] height];
    }
    if (nodesMap[_targetNodeID]) {
        _targetHeight = [nodesMap[_targetNodeID] height];
    }
    [self update];
    
}

@end

@implementation HLPCombinedLink

+ (BOOL)link:(HLPLink *)link1 shouldBeCombinedWithLink:(HLPLink *)link2
{
    if (link2.linkType == LINK_TYPE_ELEVATOR) {
        return isnan(link2.initialBearingFromSource) && (link1.length < 5);
    }
    else if (link1.linkType == LINK_TYPE_ELEVATOR) {
        return isnan(link1.lastBearingForTarget) && (link2.length < 5);
    }

    return  fabs(link1.lastBearingForTarget - link2.initialBearingFromSource) < 15.0 &&
    [link1.type isEqualToString:link2.type] &&
    link1.direction == link2.direction &&
    link1.sourceHeight == link1.targetHeight &&
    link1.targetHeight == link2.sourceHeight &&
    link2.sourceHeight == link2.targetHeight &&
    link1.linkType == link2.linkType;
}

-(instancetype)initWithLink1:(HLPLink *)link1 andLink2:(HLPLink *)link2
{
    self = [super self];
    NSMutableArray* temp = [@[] mutableCopy];
    if ([link1 isKindOfClass:HLPCombinedLink.class]) {
        [temp addObjectsFromArray:((HLPCombinedLink*)link1).links];
    } else {
        [temp addObject:link1];
    }
    if ([link2 isKindOfClass:HLPCombinedLink.class]) {
        [temp addObjectsFromArray:((HLPCombinedLink*)link2).links];
    } else {
        [temp addObject:link2];
    }
    _links = temp;
    
    
    __id = [NSString stringWithFormat:@"%@-%@",link1._id,link2._id];
    __rev = nil;
    
    _type = link1.type;
    
    
    NSMutableArray *coords = [@[] mutableCopy];
    if ([link1.geometry.type isEqualToString:@"Point"]) {
        [coords addObject:link1.geometry.coordinates];
    }
    else {
        if (!link1.backward) {
            [coords addObjectsFromArray:link1.geometry.coordinates];
        } else {
            [coords addObjectsFromArray:[[link1.geometry.coordinates reverseObjectEnumerator] allObjects]];
        }
    }
    if ([link2.geometry.type isEqualToString:@"Point"]) {
        [coords addObject:link2.geometry.coordinates];
    }
    else {
        if (!link2.backward) {
            [coords addObjectsFromArray:link2.geometry.coordinates];
        } else {
            [coords addObjectsFromArray:[[link2.geometry.coordinates reverseObjectEnumerator] allObjects]];
        }
    }
    
    for(long i = [coords count]-2; i>=0; i--) {
        if ([coords[i][0] doubleValue] == [coords[i+1][0] doubleValue] &&
            [coords[i][1] doubleValue] == [coords[i+1][1] doubleValue]
            ) {
            [coords removeObjectAtIndex:i+1];
        }
    }
    
    _geometry = [[HLPGeometry alloc] initWithDictionary:
                 @{
                   @"type":@"LineString",
                   @"coordinates":coords
                   } error:nil];
    
    _length = link1.length + link2.length;
    _direction = link1.direction;
    _sourceNodeID = link1.sourceNodeID;
    _sourceHeight = link1.sourceHeight;
    _targetNodeID = link2.targetNodeID;
    _targetHeight = link2.targetHeight;
    _linkType = link1.linkType;
    if (link1.linkType == LINK_TYPE_ELEVATOR || link2.linkType == LINK_TYPE_ELEVATOR) {
        _linkType = LINK_TYPE_ELEVATOR;
    }
    
    _backward = NO;
    initialBearingFromSource = link1.initialBearingFromSource;
    lastBearingForTarget = link2.lastBearingForTarget;
    sourceLocation = [link1 sourceLocation];
    targetLocation = [link2 targetLocation];
    
    return self;
}

@end

@implementation  HLPPOI

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;

    NSDictionary *prop = self.properties;
    _majorCategory = prop[PROPKEY_EXT_MAJOR_CATEGORY];
    _subCategory = prop[PROPKEY_EXT_SUB_CATEGORY];
    if ([POI_CATEGORY_INFO isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_INFO;
    } else if ([POI_CATEGORY_SCENE isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_SCENE;
    } else if ([POI_CATEGORY_OBJECT isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_OBJECT;
    } else if ([POI_CATEGORY_SIGN isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_SIGN;
    } else if ([POI_CATEGORY_FLOOR isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_FLOOR;
    } else if ([POI_CATEGORY_SHOP isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_SHOP;
    } else if ([POI_CATEGORY_LIVE isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_LIVE;
    } else if ([POI_CATEGORY_CORNER isEqualToString:_subCategory]) {
        _poiCategory = HLP_POI_CATEGORY_CORNER;
    }
    _minorCategory = prop[PROPKEY_EXT_MINOR_CATEGORY];
    _flagCaution = [_minorCategory containsString:POI_FLAGS_CAUTION];
    _flagPlural = [_minorCategory containsString:POI_FLAGS_PLURAL];

    if (prop[PROPKEY_EXT_HEADING]) {
        _heading = [prop[PROPKEY_EXT_HEADING] doubleValue];
    } else {
        _heading = 0;
    }
    if (prop[PROPKEY_EXT_ANGLE]) {
        _angle = [prop[PROPKEY_EXT_ANGLE] doubleValue];
    } else {
        _angle = 180;
    }

    return self;
}

@end

@implementation HLPFacility{
    HLPLocation *_location;
}


- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError *__autoreleasing *)error
{
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;
    
    _namePron = _name = self.properties[PROPKEY_NAME];
    _longDescriptionPron = _longDescription = self.properties[PROPKEY_EXT_LONG_DESCRIPTION];
    
    _lat = [self.geometry.coordinates[1] doubleValue];
    _lng = [self.geometry.coordinates[0] doubleValue];
    _height = NAN;
    if (self.properties[PROPKEY_EXT_HEIGHT]) {
        _height = [self.properties[PROPKEY_EXT_HEIGHT] doubleValue];
        _height = (_height >= 1)?_height-1:_height;
    }
    
    _location = [[HLPLocation alloc] initWithLat:_lat Lng:_lng Floor:_height];
    
    return self;
}

- (HLPLocation *)location
{
    return _location;
}


- (void)updateWithLang:(NSString *)lang
{
    _lang = lang;
    _name = [self getI18nAttribute:PROPKEY_NAME Lang:_lang];
    _namePron = [self getI18nPronAttribute:PROPKEY_NAME Lang:lang];
    if (_namePron == nil) {
        _namePron = _name;
    }
    _longDescription = [self getI18nAttribute:PROPKEY_EXT_LONG_DESCRIPTION Lang:_lang];
    _longDescriptionPron = [self getI18nPronAttribute:PROPKEY_EXT_LONG_DESCRIPTION Lang:lang];
    if (_longDescriptionPron == nil) {
        _longDescriptionPron = _longDescription;
    }
}

@end

@implementation HLPEntrance

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError *__autoreleasing *)error
{
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;
    
    _forNodeID = self.properties[PROPKEY_NODE_FOR_ID];
    _forFacilityID = self.properties[PROPKEY_FACILITY_FOR_ID];
    _namePron = _name = self.properties[PROPKEY_ENTRANCE_NAME];
    return self;
}

- (void)updateNode:(HLPNode *)node andFacility:(HLPFacility *)facility
{
    _node = node;
    _facility = facility;
}

- (void)updateWithLang:(NSString *)lang
{
    _lang = lang;
    NSString *langPron = [_lang stringByAppendingString:@"-Pron"];
    _name = [self getI18nAttribute:PROPKEY_NAME Lang:_lang];
    _namePron = [self getI18nAttribute:PROPKEY_NAME Lang:langPron];
    if (_namePron == nil) {
        _namePron = _name;
    }
}

- (NSString*)getName
{
    if (_facility) {
        if (_name) {
            return [_facility.name stringByAppendingString:_name];
        } else {
            return _facility.name;
        }
    } else {
        if (_name) {
            return _name;
        } else {
            return @"";
        }
    }
}

- (NSString *)getNamePron
{
    if (_facility) {
        if (_name) {
            return [_facility.namePron stringByAppendingString:_namePron];
        } else {
            return _facility.namePron;
        }
    } else {
        if (_namePron) {
            return _namePron;
        } else {
            return @"";
        }
    }
}

- (NSString*)getLongDescription
{
    if (_facility) {
        if (_facility.longDescription) {
            return _facility.longDescription;
        }
    }
    return @"";
}

- (NSString *)getLongDescriptionPron
{
    if (_facility) {
        if (_facility.longDescriptionPron) {
            return _facility.longDescriptionPron;
        }
    }
    return @"";
}

@end
