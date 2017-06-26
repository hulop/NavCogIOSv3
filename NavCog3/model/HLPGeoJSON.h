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
#import <Mantle/Mantle.h>
#import "HLPLocation.h"

@interface HLPGeometry : MTLModel<MTLJSONSerializing, NSCoding>
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSArray *coordinates;

- (void) updateCoordinates:(NSArray*)coordinates;
- (instancetype)initWithLocations:(NSArray*) locations;
- (HLPLocation*)point;
- (NSArray<HLPLocation*>*)points;
@end


@interface HLPGeoJSONFeature : MTLModel<MTLJSONSerializing, NSCoding> {
@protected
    NSString *_type;
    HLPGeometry *_geometry;
    NSDictionary *_properties;
}
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) HLPGeometry *geometry;
@property (nonatomic, readonly) NSDictionary *properties;
- (HLPLocation*)nearestLocationTo:(HLPLocation*) location;
@end

@interface HLPGeoJSON : MTLModel<MTLJSONSerializing, NSCoding>
@property (nonatomic, readonly) NSString *type;
@property (nonatomic, readonly) NSArray<HLPGeoJSONFeature*> *features;
@end

typedef enum {
    HLP_OBJECT_CATEGORY_LINK=1,
    HLP_OBJECT_CATEGORY_NODE,
    HLP_OBJECT_CATEGORY_PUBLIC_FACILITY,
    HLP_OBJECT_CATEGORY_ENTRANCE,
    HLP_OBJECT_CATEGORY_TOILET
} HLPObjectCategory;

@interface HLPObject : HLPGeoJSONFeature {
@protected
    NSString *__id;
    NSString *__rev;
    HLPObjectCategory _category;
}
@property (nonatomic, readonly) NSString *_id;
@property (nonatomic, readonly) NSString *_rev;
@property (nonatomic, readonly) HLPObjectCategory category;
- (void) updateWithLang:(NSString*)lang;

@end

@class HLPNode;

@interface HLPLandmark : HLPGeoJSONFeature
@property (nonatomic, readonly) NSString *category;
@property (nonatomic, readonly) NSString *exit;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *namePron;
@property (nonatomic, readonly) NSString *nodeID;
@property (nonatomic, readonly) double nodeHeight;
@property (nonatomic, readonly) NSArray* nodeCoordinates;
@property (nonatomic, readonly) HLPLocation *nodeLocation;

- (NSString*) getLandmarkName;
- (NSString*) getLandmarkNamePron;
- (BOOL) isToilet;
- (BOOL) isFacility;
@end

@interface HLPNode : HLPObject
@property (nonatomic, readonly) NSArray<NSString*> *connectedLinkIDs;
@property (nonatomic, readonly) double lat;
@property (nonatomic, readonly) double lng;
@property (nonatomic, readonly) double height;

- (HLPLocation*) location;
- (BOOL) isLeaf;
@end

typedef enum: int {
    DIRECTION_TYPE_BOTH = 0,
    DIRECTION_TYPE_SOURCE_TO_TARGET = 1,
    DIRECTION_TYPE_TARGET_TO_SOURCE = 2,
    DIRECTION_TYPE_UNKNOWN = 9
} HLPDirectionType;

typedef NS_ENUM(NSInteger, HLPBrailleBlockType) {
    HLPBrailleBlockTypeNone = 0,
    HLPBrailleBlockTypeAvailable = 1,
    HLPBrailleBlockTypeUnknown = 9
};

typedef enum: int {
    LINK_TYPE_SIDEWALK = 1,
    LINK_TYPE_PEDESTRIAN_ROAD = 2,
    LINK_TYPE_GARDEN_WALK = 3,
    LINK_TYPE_ROAD_WITHOUT_SIDEWALK = 4,
    LINK_TYPE_CROSSING = 5,
    LINK_TYPE_CROSSING_WITHOUT_SIGN = 6,
    LINK_TYPE_PEDESTRIAN_CONVEYER = 7,
    LINK_TYPE_FREE_WALKWAY = 8,
    LINK_TYPE_RAIL_CROSSING = 9,
    LINK_TYPE_ELEVATOR = 10,
    LINK_TYPE_ESCALATOR = 11,
    LINK_TYPE_STAIRWAY = 12,
    LINK_TYPE_RAMP = 13,
    
    LINK_TYPE_UNKNOWN = 99
} HLPLinkType;
// 1：歩道、2：歩行者専用道路、3：園路、4：歩車共存道路、5：横断歩道、
// 6：横断歩道の路面標示の無い交差点の道路、7：動く歩道、8：自由通路、
// 9：踏切、10：エレベーター、11：エスカレーター、12：階段、13：スロープ、99：不明

@interface HLPPOIFlags: NSObject <NSCoding>
- (instancetype)initWithString:(NSString *)str;
@property (nonatomic, readonly) BOOL flagCaution;
@property (nonatomic, readonly) BOOL flagOnomastic;
@property (nonatomic, readonly) BOOL flagSingular;
@property (nonatomic, readonly) BOOL flagPlural;
@property (nonatomic, readonly) BOOL flagAuto;
@property (nonatomic, readonly) BOOL flagWelcome;
@end

@interface HLPPOIElevatorEquipments: HLPPOIFlags
@property (nonatomic, readonly) BOOL buttonLeft;
@property (nonatomic, readonly) BOOL buttonLeftBraille;
@property (nonatomic, readonly) BOOL buttonRight;
@property (nonatomic, readonly) BOOL buttonRightBraille;
@property (nonatomic, readonly) BOOL voiceGuide;
@property (nonatomic, readonly) BOOL buttonWcLeft;
@property (nonatomic, readonly) BOOL buttonWcLeftBraille;
@property (nonatomic, readonly) BOOL buttonWcRight;
@property (nonatomic, readonly) BOOL buttonWcRightBraille;
@end

@interface HLPPOIElevatorButtons: HLPPOIFlags
@property (nonatomic, readonly) BOOL buttonLeft;
@property (nonatomic, readonly) BOOL buttonLeftBraille;
@property (nonatomic, readonly) BOOL buttonRight;
@property (nonatomic, readonly) BOOL buttonRightBraille;
@property (nonatomic, readonly) BOOL buttonMiddle;
@property (nonatomic, readonly) BOOL buttonMiddleBraille;
@property (nonatomic, readonly) BOOL flagLower;
@end

@interface HLPPOIEscalatorFlags: HLPPOIFlags
@property (nonatomic, readonly) BOOL upward;
@property (nonatomic, readonly) BOOL downward;
@property (nonatomic, readonly) BOOL forward;
@property (nonatomic, readonly) BOOL backward;
@property (nonatomic, readonly) BOOL left;
@property (nonatomic, readonly) BOOL right;
@end

@interface HLPLink : HLPObject {
@protected
    double _length;
    HLPDirectionType _direction;
    NSString *_sourceNodeID;
    double _sourceHeight;
    NSString *_targetNodeID;
    double _targetHeight;
    HLPLinkType _linkType;
    BOOL _backward;
    HLPLocation *sourceLocation;
    HLPLocation *targetLocation;
    double _minimumWidth;
    HLPPOIElevatorEquipments *elevatorEquipments;
    HLPBrailleBlockType _brailleBlockType;
    NSArray<HLPPOIEscalatorFlags*>* _escalatorFlags;
}

@property (nonatomic, readonly) double length;
@property (nonatomic, readonly) HLPDirectionType direction;
@property (nonatomic, readonly) NSString *sourceNodeID;
@property (nonatomic, readonly) double sourceHeight;
@property (nonatomic, readonly) NSString *targetNodeID;
@property (nonatomic, readonly) double targetHeight;
@property (nonatomic, readonly) HLPLinkType linkType;
@property (nonatomic, readonly) BOOL backward;
@property (nonatomic, readonly) double minimumWidth;
@property (nonatomic, readonly) HLPBrailleBlockType brailleBlockType;
@property (nonatomic, readonly) BOOL isLeaf;
@property NSArray<HLPPOIEscalatorFlags*>* escalatorFlags;
@property (nonatomic, readonly) HLPNode *sourceNode;
@property (nonatomic, readonly) HLPNode *targetNode;

+ (NSString*) nameOfLinkType:(HLPLinkType)type;
- (double) initialBearingFromSource;
- (double) lastBearingForTarget;
- (double) initialBearingFromTarget;
- (double) lastBearingForSource;
- (double) initialBearingFrom:(HLPNode*)node;
- (double) bearingAtLocation:(HLPLocation*)loc;
- (void) updateLastBearingForTarget:(double)bearing;
- (HLPLocation*) sourceLocation;
- (HLPLocation*) targetLocation;
- (HLPLocation*) locationDistanceToTarget:(double) distance;
- (void) updateWithNodesMap:(NSDictionary*)nodesMap;
- (void) setTargetNodeIfNeeded:(HLPNode*)node withNodesMap:(NSDictionary*)nodesMap;
- (void) offsetTarget:(double)distance;
- (void) offsetSource:(double)distance;
- (HLPPOIElevatorEquipments*) elevatorEquipments;
- (BOOL) isSafeLinkType;

- (instancetype) initWithSource:(HLPLocation*)source Target:(HLPLocation*)target;
@end

@interface HLPCombinedLink : HLPLink

@property (nonatomic, readonly) NSArray* links;
+(BOOL) link:(HLPLink*)link1 shouldBeCombinedWithLink:(HLPLink*)link2;
+(BOOL) link:(HLPLink*)link1 canBeCombinedWithLink:(HLPLink*)link2;
-(instancetype) initWithLink1:(HLPLink*)link1 andLink2:(HLPLink*) link2;

@end

@interface HLPFacility : HLPObject
@property (nonatomic, readonly) double lat;
@property (nonatomic, readonly) double lng;
@property (nonatomic, readonly) double height;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *namePron;
@property (nonatomic, readonly) NSString *longDescription;
@property (nonatomic, readonly) NSString *longDescriptionPron;
@property (nonatomic, readonly) NSString *lang;
@property (nonatomic, readonly) NSString *addr;

- (HLPLocation*) location;
@end

typedef NS_ENUM(NSInteger, HLPPOICategory) {
    HLPPOICategoryInfo=0,
    HLPPOICategoryFloor,
    HLPPOICategoryCornerEnd,
    HLPPOICategoryCornerWarningBlock,
    HLPPOICategoryCornerLandmark,
    HLPPOICategoryElevator,
    HLPPOICategoryElevatorEquipments,
    HLPPOICategoryDoor,
    HLPPOICategoryObstacle,
    HLPPOICategoryCOUNT
};
static const char* HLPPOICategoryStrings[] = {
    "_nav_info_",
    "_nav_floor_",
    "_nav_corner_end_",
    "_nav_corner_warning_block_",
    "_nav_corner_landmark_",
    "_nav_elevator_",
    "_nav_elevator_equipments_",
    "_nav_door_",
    "_nav_obstacle_"
};

@interface HLPPOI : HLPFacility
@property (nonatomic, readonly) NSString* majorCategory;
@property (nonatomic, readonly) NSString* subCategory;
@property (nonatomic, readonly) NSString* minorCategory;
@property (nonatomic, readonly) double heading;
@property (nonatomic, readonly) double angle;
@property (nonatomic, readonly) HLPPOICategory poiCategory;
@property (nonatomic, readonly) HLPPOIFlags* flags;
@property (nonatomic, readonly) HLPPOIElevatorButtons *elevatorButtons;
@property (nonatomic, readonly) HLPPOIElevatorEquipments *elevatorEquipments;
- (BOOL) allowsNoFloor;
- (NSString*) poiCategoryString;
@end

@interface HLPEntrance : HLPObject
@property (nonatomic, readonly) NSString *forNodeID;
@property (nonatomic, readonly) NSString *forFacilityID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *namePron;
@property (nonatomic, readonly) HLPNode *node;
@property (nonatomic, readonly) HLPFacility *facility;
@property (nonatomic, readonly) NSString *lang;
- (void) updateNode:(HLPNode*) node andFacility:(HLPFacility*) facility;
- (NSString*) getName;
- (NSString*) getNamePron;
- (NSString*) getLongDescription;
- (NSString*) getLongDescriptionPron;
@end
