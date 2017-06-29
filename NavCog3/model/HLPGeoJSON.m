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
#import "objc/runtime.h"

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
#define PROPKEY_EFFECTIVE_WIDTH @"有効幅員"
#define PROPKEY_ELEVATOR_EQUIPMENTS @"elevator_equipments"
#define PROPKEY_BRAILLE_BLOCK @"視覚障害者誘導用ブロック"
#define PROPKEY_ADDR @"所在地"

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

@implementation HLPGeometry
+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"type": @"type",
             @"coordinates": @"coordinates"
             };
}

-(void)updateCoordinates:(NSArray *)coordinates
{
    _coordinates = coordinates;
}

- (instancetype)initWithLocations:(NSArray *)locations
{
    self = [super init];
    if (!locations || [locations count] == 0) {
        return nil;
    }
    if ([locations count] == 1) {
        _type = @"Point";
        HLPLocation* loc = locations[0];
        _coordinates = @[@(loc.lng), @(loc.lat)];
    } else {
        _type = @"LineString";
        NSMutableArray *temp = [[NSMutableArray alloc] initWithCapacity:[locations count]];
        [locations enumerateObjectsUsingBlock:^(HLPLocation *loc, NSUInteger idx, BOOL * _Nonnull stop) {
            temp[idx] = @[@(loc.lng), @(loc.lat)];
        }];
        _coordinates = temp;
    }
    
    return self;
}

- (HLPLocation *)point
{
    if ([_coordinates[0] isKindOfClass:NSArray.class]) {
        return nil;
    }
    return [[HLPLocation alloc] initWithLat:[_coordinates[1] doubleValue] Lng:[_coordinates[0] doubleValue]];
}

- (NSArray<HLPLocation *> *)points
{
    NSMutableArray *temp = [@[] mutableCopy];
    for(NSArray* a in _coordinates) {
        if ([a isKindOfClass:NSArray.class]) {
            [temp addObject:[[HLPLocation alloc] initWithLat:[a[1] doubleValue] Lng:[a[0] doubleValue]]];
        } else {
            return nil;
        }
    }
    return temp;
}

@end

@implementation HLPGeoJSONFeature {
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
        [loc2 updateLat:[self.geometry.coordinates[1] doubleValue]
                    Lng:[self.geometry.coordinates[0] doubleValue]];
        minloc = [[HLPLocation alloc] init];
        [minloc update:loc2];
        dist = [loc1 distanceTo:loc2];
    } else if ([self.geometry.type isEqualToString:@"LineString"]) {
        for(int i = 0; i < [self.geometry.coordinates count]-1; i++) {
            [loc2 updateLat:[self.geometry.coordinates[i][1] doubleValue]
                        Lng:[self.geometry.coordinates[i][0] doubleValue]];
            [loc3 updateLat:[self.geometry.coordinates[i+1][1] doubleValue]
                        Lng:[self.geometry.coordinates[i+1][0] doubleValue]];
            
            HLPLocation *loc = [loc1 nearestLocationToLineFromLocation:loc2 ToLocation:loc3];
            double temp = [loc1 distanceToLineFromLocation:loc2 ToLocation:loc3];
            if ([loc2 distanceTo:loc3] < 1e-5) {
                loc = [[HLPLocation alloc] init];
                [loc update:loc2];
                temp = [loc2 distanceTo:loc1];
            }
            if (temp < dist) {
                dist = temp;
                minloc = loc;
            }
        }
    }
    [minloc updateFloor:location.floor];
    return minloc;
}

@end

@implementation  HLPGeoJSON

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"type": @"type",
             @"features": @"features"
             };
}

+ (NSValueTransformer *)featuresJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:HLPGeoJSONFeature.class];
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
        [temp appendFormat:@" %@", properties[PROPKEY_ENTRANCE_NAME]];
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
    } else if (self.properties[name]){
        return self.properties[name];
    } else {
        return @"";
    }
}

- (NSString*) getI18nPronAttribute:(NSString*)name Lang:(NSString*)lang
{
    NSString *key = [NSString stringWithFormat:@"%@:%@", name, lang];
    NSString *pronKey = [key stringByAppendingString:@"-Pron"];
    
    if (self.properties[pronKey]) {
        return self.properties[pronKey];
    } else if (self.properties[key]){
        return self.properties[key];
    } else {
        return nil;
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
              @"nodeID": @"node",
              @"nodeHeight": @"node_height",
              @"nodeCoordinates": @"node_coordinates"
              }];
}

+ (NSValueTransformer *)nodeHeightJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *height, BOOL *success, NSError *__autoreleasing *error) {
        double h = [height doubleValue];
        return @((h >= 1)?h-1:h);
    } reverseBlock:^id(NSNumber *height, BOOL *success, NSError *__autoreleasing *error) {
        double h = [height doubleValue];
        h = (h >= 0)?h+1:h;
        return [NSString stringWithFormat:@"%.0f",h];
    }];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError *__autoreleasing *)error
{
    self = [super initWithDictionary:dictionaryValue error:error];
    //_nodeHeight = (_nodeHeight >= 1)?_nodeHeight-1:_nodeHeight;
    
    if(dictionaryValue[@"nodeCoordinates"]) {
        double lat = [dictionaryValue[@"nodeCoordinates"][1] doubleValue];
        double lng = [dictionaryValue[@"nodeCoordinates"][0] doubleValue];
        _nodeLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:_nodeHeight];
    }
    
    return self;
}

- (NSString *)getLandmarkName
{
    return [self _getLandmarkName:_name];
}

- (NSString *)getLandmarkNamePron
{
    return [self _getLandmarkName:_namePron?_namePron:_name];
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
    }
    
    return [temp stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

- (BOOL)isToilet
{
    return [_category isEqualToString:CATEGORY_TOILET];
}

- (BOOL)isFacility
{
    return [_properties[@"sub_category"] isEqualToString:@"NURS"] ||
    [_properties[@"sub_category"] isEqualToString:@"SMOK"] ||
    [_properties[@"sub_category"] isEqualToString:@"ATM"] ||
    [_properties[@"sub_category"] isEqualToString:@"RE_L"] ||
    [self isToilet];
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
    
    _height = NAN;
    if (self.properties[PROPKEY_HEIGHT]) {
        _height = [self.properties[PROPKEY_HEIGHT] doubleValue];
        _height = (_height >= 1)?_height-1:_height;
    }
    
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

- (BOOL) isLeaf
{
    if (_connectedLinkIDs) {
        return ([_connectedLinkIDs count] == 1);
    }
    return NO;
}

@end

@implementation HLPPOIFlags {
    @protected
    BOOL _flagPlural;
}
- (instancetype)initWithString:(NSString *)str
{
    self = [super init];
    
    if (str) {
        NSString*(^camelToDash)(NSString*) = ^(NSString* str) {
            NSRegularExpression *p = [NSRegularExpression regularExpressionWithPattern:@"([A-Z])" options:0 error:nil];
            NSString *temp = [p stringByReplacingMatchesInString:str options:0 range:NSMakeRange(0, str.length) withTemplate:@"_$1"];
            return [NSString stringWithFormat:@"_%@_", [temp lowercaseString]];
        };
        
        for (NSString *name in [self allPropertyNames]) {
            NSString *flagName = camelToDash(name);
            if ([str containsString:flagName]) {
                [self setValue:@(YES) forKey:name];
            }
        }
    }
    return self;
}

- (NSArray*) allPropertyNames
{
    unsigned int outCount, i;
    
    objc_property_t *properties = class_copyPropertyList(self.class, &outCount);
    NSMutableArray *array = [@[] mutableCopy];
    for(i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            NSString *propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
            [array addObject:propertyName];
        }
    }
    free(properties);
    
    return array;
}
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
}

@end

@implementation HLPPOIElevatorEquipments: HLPPOIFlags
- (NSString*) description
{
    NSMutableString *string = [@"" mutableCopy];
    if (_buttonLeft && _buttonRight) {
        [string appendString:@"ElvEqButtonBoth"];
        if (_buttonLeftBraille && _buttonRightBraille) {
            [string appendString:@"Braille"];
        } else if (_buttonLeftBraille) {
            [string appendString:@"LeftBraille"];
        } else if (_buttonRightBraille) {
            [string appendString:@"RightBraille"];
        }
    } else if (_buttonRight) {
        [string appendString:@"ElvEqButtonRight"];
        if (_buttonRightBraille) {
            [string appendString:@"Braille"];
        }
    } else if (_buttonLeft) {
        [string appendString:@"ElvEqButtonLeft"];
        if (_buttonLeftBraille) {
            [string appendString:@"Braille"];
        }
    } else {
        // no button
        return nil;
    }
    NSString *elv = NSLocalizedStringFromTable(string, @"HLPGeoJSON", @"");    
    return elv;
}
@end

@implementation HLPPOIElevatorButtons: HLPPOIFlags
- (NSString*)description
{
    BOOL brail = NO;
    NSString *pos = nil;
    if (_buttonRight) {
        pos = @"ElvButtonRight";
        brail = brail || _buttonRightBraille;
    }
    else if (_buttonLeft) {
        pos = @"ElvButtonLeft";
        brail = brail || _buttonLeftBraille;
    }
    else if (_buttonMiddle) {
        pos = @"ElvButtonMiddle";
        brail = brail || _buttonMiddleBraille;
    }
    
    if (_flagPlural) {
        pos = [pos stringByAppendingString:@"Plural"];
    }
    
    if (_flagLower) {
        pos = [pos stringByAppendingString:@"Lower"];
    }
    
    NSString *str = NSLocalizedStringFromTable(pos, @"HLPGeoJSON", @"");
    if (brail) {
        str = [NSString stringWithFormat:NSLocalizedStringFromTable(@"ElvButtonWithBraille", @"HLPGeoJSON", @""), str];
    }
    
    return str;
}
@end

@implementation HLPPOIEscalatorFlags : HLPPOIFlags
- (NSString*)description
{
    NSString *str = @"HLPPOIEscalatorFlags:";
    if (_left) str = [str stringByAppendingString:@"left "];
    if (_right) str = [str stringByAppendingString:@"right "];
    if (_upward) str = [str stringByAppendingString:@"upward "];
    if (_downward) str = [str stringByAppendingString:@"downward "];
    if (_forward) str = [str stringByAppendingString:@"forward "];
    if (_backward) str = [str stringByAppendingString:@"backward "];
    return str;
}
@end

@implementation HLPLink {
@protected
    double initialBearingFromSource;
    double initialBearingFromTarget;
    double lastBearingForTarget;
    double lastBearingForSource;
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
    
    elevatorEquipments = [[HLPPOIElevatorEquipments alloc] initWithString:self.properties[PROPKEY_ELEVATOR_EQUIPMENTS]];

    _length = [self.properties[PROPKEY_LINK_LENGTH] doubleValue];
    
    _direction = [self.properties[PROPKEY_LINK_DIRECTION] intValue];
    _sourceNodeID = self.properties[@"sourceNode"];
    _sourceHeight = [self.properties[@"sourceHeight"] doubleValue];
    _targetNodeID = self.properties[@"targetNode"];
    _targetHeight = [self.properties[@"targetHeight"] doubleValue];
    _sourceHeight = (_sourceHeight >= 1)?_sourceHeight-1:_sourceHeight;
    _targetHeight = (_targetHeight >= 1)?_targetHeight-1:_targetHeight;

    _linkType = [self.properties[PROPKEY_LINK_TYPE] intValue];
    if(_linkType == LINK_TYPE_ELEVATOR) {
        _length = 0;
    }
    
    _brailleBlockType = [self.properties[PROPKEY_BRAILLE_BLOCK] intValue];
    
    _minimumWidth = 3.0;
    if (self.properties[PROPKEY_EFFECTIVE_WIDTH]) {
        switch([self.properties[PROPKEY_EFFECTIVE_WIDTH] intValue]) {
            case 0: _minimumWidth = 1; break;
            case 1: _minimumWidth = 1.0; break;
            case 2: _minimumWidth = 1.5; break;
            case 3: _minimumWidth = 2.0; break;
            case 9: _minimumWidth = 3.0; break;
        }
    }
    
    [self update];
    return self;
}

- (void) update
{
    _backward = [self.properties[PROPKEY_TARGET_NODE_ID] isEqualToString:_sourceNodeID];

    if (self.geometry) {
        if ([self.geometry.type isEqualToString:@"LineString"] && [self.geometry.coordinates count] >= 2) {
            NSArray *first = self.geometry.coordinates[_backward?[self.geometry.coordinates count]-1:0];
            NSArray *second = self.geometry.coordinates[_backward?[self.geometry.coordinates count]-2:1];
            
            NSArray *last = self.geometry.coordinates[!_backward?[self.geometry.coordinates count]-1:0];
            NSArray *secondLast = self.geometry.coordinates[!_backward?[self.geometry.coordinates count]-2:1];
            
            sourceLocation = [[HLPLocation alloc] initWithLat:[first[1] doubleValue] Lng:[first[0] doubleValue] Floor:_sourceHeight];
            targetLocation = [[HLPLocation alloc] initWithLat:[last[1] doubleValue] Lng:[last[0] doubleValue] Floor:_targetHeight];
            
            initialBearingFromSource = [sourceLocation bearingToLat:[second[1] doubleValue]
                                                               Lng:[second[0] doubleValue]];
            initialBearingFromTarget = [targetLocation bearingToLat:[secondLast[1] doubleValue]
                                                                Lng:[secondLast[0] doubleValue]];
            
            lastBearingForTarget = [HLPLocation bearingFromLat:[secondLast[1] doubleValue]
                                                           Lng:[secondLast[0] doubleValue]
                                                         toLat:[last[1] doubleValue]
                                                           Lng:[last[0] doubleValue]];
            lastBearingForSource = [HLPLocation bearingFromLat:[second[1] doubleValue]
                                                           Lng:[second[0] doubleValue]
                                                         toLat:[first[1] doubleValue]
                                                           Lng:[first[0] doubleValue]];
            
        } else if ([self.geometry.type isEqualToString:@"Point"] && [self.geometry.coordinates count] == 2) {
            double lat = [self.geometry.coordinates[1] doubleValue];
            double lng = [self.geometry.coordinates[0] doubleValue];
            
            sourceLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:_sourceHeight];
            targetLocation = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:_targetHeight];
            
            initialBearingFromSource = lastBearingForTarget = NAN;
            initialBearingFromTarget = lastBearingForSource = NAN;
        }
    }
}

- (void)updateWithNodesMap:(NSDictionary *)nodesMap
{
    _sourceNodeID = self.properties[_backward?PROPKEY_TARGET_NODE_ID:PROPKEY_SOURCE_NODE_ID];
    HLPNode *snode = nodesMap[_sourceNodeID];
    if (snode) {
        _sourceNode = snode;
        _sourceHeight = snode.height;
        [sourceLocation updateFloor:_sourceHeight];
    }
    
    _targetNodeID = self.properties[!_backward?PROPKEY_TARGET_NODE_ID:PROPKEY_SOURCE_NODE_ID];
    HLPNode *tnode = nodesMap[_targetNodeID];
    if (tnode) {
        _targetNode = tnode;
        _targetHeight = tnode.height;
        [targetLocation updateFloor:_targetHeight];
    }
    
    if ([snode.connectedLinkIDs count] == 1 ||
        [tnode.connectedLinkIDs count] == 1 ) {
        _isLeaf = YES;
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

- (double)initialBearingFromTarget;
{
    return initialBearingFromTarget;
}

- (double)lastBearingForSource;
{
    return lastBearingForSource;
}

- (double) initialBearingFrom:(HLPNode *)node
{
    if (_sourceNode == node) {
        return self.initialBearingFromSource;
    }
    if (_targetNode == node) {
        return self.initialBearingFromTarget;
    }
    return NAN;
}


- (double)bearingAtLocation:(HLPLocation *)loc
{
    int i = 0;
    double orientation = 0;
    double min = DBL_MAX;
    NSArray *points = _geometry.points;
    for(;i<[points count]-1; i++) {
        HLPLocation *a = points[i];
        HLPLocation *b = points[i+1];
        
        HLPLocation *c = [loc nearestLocationToLineFromLocation:a ToLocation:b];
        double d = [c distanceTo:loc];
        if (d < min) {
            min = d;
            orientation = [c bearingTo:b];
        }
    }
    return orientation;
}

- (void) updateLastBearingForTarget:(double)bearing
{
    lastBearingForTarget = bearing;
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

- (void)offsetTarget:(double)distance
{
    if (_length + distance <= 0) {
        distance = -(_length - 0.1);
    }
    
    HLPLocation *temp = [targetLocation offsetLocationByDistance:distance Bearing:lastBearingForTarget];
    
    NSMutableArray *newCoordinates = [_geometry.coordinates mutableCopy];
    if (_backward) {
        newCoordinates[0] = @[@(temp.lng), @(temp.lat)];
    } else {
        newCoordinates[[newCoordinates count]-1] = @[@(temp.lng), @(temp.lat)];
    }
    [_geometry updateCoordinates:newCoordinates];
    
    _length += distance;
    
    [self update];
}

- (void)offsetSource:(double)distance
{
    if (_length + distance <= 0) {
        distance = -(_length - 0.1);
    }
    
    HLPLocation *temp = [sourceLocation offsetLocationByDistance:distance Bearing:180+initialBearingFromSource];
    
    NSMutableArray *newCoordinates = [_geometry.coordinates mutableCopy];
    if (_backward) {
        newCoordinates[[newCoordinates count]-1] = @[@(temp.lng), @(temp.lat)];
    } else {
        newCoordinates[0] = @[@(temp.lng), @(temp.lat)];
    }
    [_geometry updateCoordinates:newCoordinates];
    
    _length += distance;
    
    [self update];
}

- (HLPPOIElevatorEquipments *)elevatorEquipments
{
    return elevatorEquipments;
}

- (BOOL)isSafeLinkType
{
    return _linkType == LINK_TYPE_FREE_WALKWAY ||
    _linkType == LINK_TYPE_SIDEWALK ||
    _linkType == LINK_TYPE_GARDEN_WALK ||
    _linkType == LINK_TYPE_PEDESTRIAN_ROAD;
}

- (instancetype)initWithSource:(HLPLocation *)source Target:(HLPLocation *)target
{
    self = [super init];
    
    sourceLocation = source;
    targetLocation = target;
    _sourceHeight = source.floor;
    _targetHeight = target.floor;
    lastBearingForTarget = initialBearingFromSource = [source bearingTo:target];
    initialBearingFromTarget = lastBearingForSource = [target bearingTo:source];
    _length = [source distanceTo:target];
    _backward = NO;
    _geometry = [[HLPGeometry alloc] initWithLocations:@[source, target]];
    
    return self;
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
    //if (link2.linkType == LINK_TYPE_ESCALATOR) {
    //    return link1.length < 5;
    //}
    if (link1.linkType == LINK_TYPE_ESCALATOR) {
        return link2.length < 3;
    }

    return [HLPCombinedLink link:link1 canBeCombinedWithLink:link2] &&
    link1.linkType == link2.linkType;
}

+ (BOOL) link:(HLPLink *)link1 canBeCombinedWithLink:(HLPLink *)link2
{
    return  fabs(link1.lastBearingForTarget - link2.initialBearingFromSource) < 15.0 &&
    [link1.type isEqualToString:link2.type] &&
    link1.direction == link2.direction &&
    link1.sourceHeight == link1.targetHeight &&
    link1.targetHeight == link2.sourceHeight &&
    link2.sourceHeight == link2.targetHeight;
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
                   @"type":([coords count]==1)?@"Point":@"LineString",
                   @"coordinates":([coords count]==1)?coords[0]:coords
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
        elevatorEquipments = link1.elevatorEquipments?link1.elevatorEquipments:link2.elevatorEquipments;
    }
    if (link2.linkType == LINK_TYPE_ESCALATOR) {
        _linkType = LINK_TYPE_ESCALATOR;
    }
    
    _backward = NO;
    initialBearingFromSource = link1.initialBearingFromSource;
    initialBearingFromTarget = link2.initialBearingFromTarget;
    lastBearingForTarget = link2.lastBearingForTarget;
    lastBearingForSource = link1.lastBearingForSource;
    sourceLocation = [link1 sourceLocation];
    targetLocation = [link2 targetLocation];
    
    _brailleBlockType = link1.brailleBlockType;
    _escalatorFlags = link1.escalatorFlags;
    
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
    _minorCategory = prop[PROPKEY_EXT_MINOR_CATEGORY];

    // check poi type
    _poiCategory = HLPPOICategoryCOUNT;
    for(int i = 0; i < HLPPOICategoryCOUNT; i++) {
        if ([[NSString stringWithUTF8String:HLPPOICategoryStrings[i]] isEqualToString:_subCategory]) {
            _poiCategory = i;
            break;
        }
    }
    if (_poiCategory == HLPPOICategoryCOUNT) { // error check
        NSLog(@"error: unknown poi category %@", _subCategory);
    }
    // check flags
    _flags = [[HLPPOIFlags alloc] initWithString:_minorCategory];
    _elevatorButtons = [[HLPPOIElevatorButtons alloc] initWithString:_minorCategory];
    _elevatorEquipments = [[HLPPOIElevatorEquipments alloc] initWithString:_minorCategory];
    
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

- (BOOL)allowsNoFloor
{
    return (_poiCategory == HLPPOICategoryElevator) || (_poiCategory == HLPPOICategoryElevatorEquipments);
}

- (NSString*)poiCategoryString
{
    if (_poiCategory == HLPPOICategoryCOUNT) {
        return @"?";
    }
    NSString *temp = [NSString stringWithCString:HLPPOICategoryStrings[_poiCategory] encoding:NSUTF8StringEncoding];
    temp = [temp stringByReplacingOccurrencesOfString:@"_nav_" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    return temp;
}

@end

@implementation HLPFacility{
    HLPLocation *_location;
    NSMutableArray *entrances;
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
        if (_height == 0) {
            _height = NAN;
        } else {
            _height = (_height >= 1)?_height-1:_height;
        }
    }
    
    _location = [[HLPLocation alloc] initWithLat:_lat Lng:_lng Floor:_height];
    if (self.properties[PROPKEY_ADDR]) {
        _addr = self.properties[PROPKEY_ADDR];
    }
    
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
    
    if(self.category == HLP_OBJECT_CATEGORY_TOILET) {
        NSMutableString *temp = [[NSMutableString alloc] init];
        if (self.properties) {
            NSString *sex = self.properties[PROPKEY_MALE_OR_FEMALE];
            if ([sex isEqualToString:@"1"]) {
                [temp appendString:NSLocalizedString(@"FOR_MALE",@"Toilet for male")];
            }
            else if ([sex isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_FEMALE",@"Toilet for female")];
            }
            NSString *multi = self.properties[PROPKEY_MULTI_PURPOSE_TOILET];
            
            if ([multi isEqualToString:@"1"] || [multi isEqualToString:@"2"]) {
                [temp appendString:NSLocalizedString(@"FOR_DISABLED", @"Toilet for people with disability")];
            }
        }
        _namePron = _name = temp;
    }
    
    
    _longDescription = [self getI18nAttribute:PROPKEY_EXT_LONG_DESCRIPTION Lang:_lang];
    _longDescriptionPron = [self getI18nPronAttribute:PROPKEY_EXT_LONG_DESCRIPTION Lang:lang];
    if (_longDescriptionPron == nil) {
        _longDescriptionPron = _longDescription;
    }
}

- (void)addEntrance:(HLPEntrance*)ent
{
    if (!entrances) {
        entrances = [[NSMutableArray alloc] init];
    }
    [entrances addObject:ent];
}

- (NSArray *)entrances
{
    return entrances;
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
    [_facility addEntrance:self];
}

- (void)updateWithLang:(NSString *)lang
{
    _lang = lang;
    _name = [self getI18nAttribute:PROPKEY_ENTRANCE_NAME Lang:_lang];
    _namePron = [self getI18nPronAttribute:PROPKEY_ENTRANCE_NAME Lang:_lang];
    if (_namePron == nil) {
        _namePron = _name;
    }
}

- (NSString*)getName
{
    NSString *ret = nil;
    if (_facility) {
        if (_name) {
            ret = [_facility.name stringByAppendingFormat:@" %@", _name];
        } else {
            ret = _facility.name;
        }
    } else {
        if (_name) {
            ret =  _name;
        } else {
            ret =  @"";
        }
    }
    return [ret stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

- (NSString *)getNamePron
{
    NSString *ret = nil;
    if (_facility) {
        if (_name && [_name length] > 0) {
            ret = [_facility.namePron stringByAppendingFormat:@" %@", _namePron];
        } else {
            ret = _facility.namePron;
        }
    } else {
        if (_namePron) {
            ret = _namePron;
        } else {
            ret = @"";
        }
    }
    return [ret stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
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
