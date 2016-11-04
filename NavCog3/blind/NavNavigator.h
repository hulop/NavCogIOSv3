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

@class NavPOI;

@interface NavNavigatorConstants : NSObject
    
@property (readonly) double PREVENT_REMAINING_DISTANCE_EVENT_FOR_FIRST_N_METERS;
@property (readonly) double APPROACHING_DISTANCE_THRESHOLD;
@property (readonly) double APPROACHED_DISTANCE_THRESHOLD;
@property (readonly) double NO_APPROACHING_DISTANCE_THRESHOLD;
@property (readonly) double REMAINING_DISTANCE_INTERVAL;
@property (readonly) double NO_ANDTURN_DISTANCE_THRESHOLD;

@property (readonly) double IGNORE_FIRST_LINK_LENGTH_THRESHOLD;
@property (readonly) double IGNORE_LAST_LINK_LENGTH_THRESHOLD;
    
@property (readonly) double POI_ANNOUNCE_DISTANCE;
@property (readonly) double POI_START_INFO_DISTANCE_THRESHOLD;
@property (readonly) double POI_END_INFO_DISTANCE_THRESHOLD;
@property (readonly) double POI_DISTANCE_MIN_THRESHOLD;
@property (readonly) double POI_FLOOR_DISTANCE_THRESHOLD;
@property (readonly) double POI_TARGET_DISTANCE_THRESHOLD;
@property (readonly) double POI_ANNOUNCE_MIN_INTERVAL;

@property (readonly) double NAVIGATION_START_CAUTION_DISTANCE_LIMIT;
@property (readonly) double NAVIGATION_START_DISTANCE_LIMIT;
@property (readonly) double REPEAT_ACTION_TIME_INTERVAL;

@property (readonly) double OFF_ROUTE_THRESHOLD;
@property (readonly) double OFF_ROUTE_EXT_LINK_THRETHOLD;
@property (readonly) double REROUTE_DISTANCE_THRESHOLD;
@property (readonly) double OFF_ROUTE_ANNOUNCE_MIN_INTERVAL;

@property (readonly) int NUM_OF_LINKS_TO_CHECK;

@property (readonly) double OFF_ROUTE_BEARING_THRESHOLD;
@property (readonly) double CHANGE_HEADING_THRESHOLD;
@property (readonly) double ADJUST_HEADING_MARGIN;

@property (readonly) double BACK_DETECTION_THRESHOLD;
@property (readonly) double BACK_DETECTION_HEADING_THRESHOLD;
@property (readonly) double BACK_ANNOUNCE_MIN_INTERVAL;
    
@property (readonly) double FLOOR_DIFF_THRESHOLD;

+ (instancetype) constants;
+ (NSArray*) propertyNames;
+ (NSDictionary*) defaults;

@end

@protocol NavNavigatorDelegate <NSObject>
- (void)didActiveStatusChanged:(NSDictionary*)properties;

#pragma mark - Navigation events
@optional

// navigation control
- (void)couldNotStartNavigation:(NSDictionary*)properties;
- (void)didNavigationStarted:(NSDictionary*)properties;
- (void)didNavigationFinished:(NSDictionary*)properties;

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties;
- (void)userAdjustedHeading:(NSDictionary*)properties;
- (void)remainingDistanceToTarget:(NSDictionary*)properties;
- (void)userIsApproachingToTarget:(NSDictionary*)properties;
- (void)userNeedsToTakeAction:(NSDictionary*)properties;
- (void)userNeedsToWalk:(NSDictionary*)properties;

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties;
- (void)userMaybeOffRoute:(NSDictionary*)properties;
- (void)userMayGetBackOnRoute:(NSDictionary*)properties;
- (void)userShouldAdjustBearing:(NSDictionary*)properties;

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties;
- (void)userIsLeavingFromPOI:(NSDictionary*)properties;
@end

@interface NavLinkInfo : NSObject
@property (readonly) HLPLink* link;
@property (readonly) HLPLink* nextLink;
@property (readonly) NSArray* allPOIs;
@property (readonly) NSArray<NavPOI*>* pois;
@property (readonly) HLPLocation *userLocation;
@property (readonly) HLPLocation *snappedLocationOnLink;
@property (readonly) HLPLocation *targetLocation;
@property (readonly) HLPLocation *sourceLocation;

@property (readonly) double distanceToUserLocationFromLink;
@property (readonly) double distanceToTargetFromUserLocation;
@property (readonly) double distanceToTargetFromSnappedLocationOnLink;
@property (readonly) double distanceToSourceFromSnappedLocationOnLink;

@property (readonly) double nextTurnAngle;
@property (readonly) double diffBearingAtUserLocation;
@property (readonly) double diffBearingAtSnappedLocationOnLink;
@property (readonly) double diffNextBearingAtSnappedLocationOnLink;

@property (readonly) double diffBearingAtUserLocationToSnappedLocationOnLink;

@property (readonly) double isComplex;
@property (readonly) BOOL isNextDestination;

#pragma mark - flags for navigation
@property BOOL hasBeenBearing;
@property BOOL hasBeenActivated;
@property BOOL hasBeenApproaching;
@property BOOL hasBeenWaitingAction;
@property BOOL hasBeenFixBackward;
@property BOOL hasBeenFixOffRoute;
@property double nextTargetRemainingDistance;
@property NSTimeInterval expirationTimeOfPreventRemainingDistanceEvent;
@property HLPLocation *backDetectedLocation;
@property (readonly) double distanceFromBackDetectedLocationToSnappedLocationOnLink;
@property NSTimeInterval lastBackNotified;
@property NSTimeInterval lastOffRouteNotified;

@property BOOL mayBeOffRoute;
@property NavLinkInfo* offRouteLinkInfo;


- (instancetype)initWithLink:(HLPLink*)link nextLink:(HLPLink*)nextLink andPOIs:(NSArray*)allPOIs;
- (void)reset;
- (void)updateWithLocation:(HLPLocation*)location;

@end

@interface NavPOI : NSObject
@property (readonly) id origin;
@property (readonly) NSString *text;
@property (readonly) NSString *longDescription;
@property (readonly) HLPLocation *poiLocation;
@property (readonly) BOOL needsToPlaySound;
@property (readonly) BOOL requiresUserAction;
@property (readonly) BOOL forBeforeStart;
@property (readonly) BOOL forFloor;
@property (readonly) BOOL forCorner;
@property (readonly) BOOL forSign;
@property (readonly) BOOL forBeforeEnd;
@property (readonly) BOOL flagCaution;
@property (readonly) BOOL flagPlural;
@property (readonly) BOOL isDestination;
@property (readonly) double angleFromLocation;

@property (readonly) HLPLocation *snappedLocationOnLink;
@property (readonly) HLPLocation *userLocation;
@property (readonly) double distanceFromSnappedLocation;
@property (readonly) double distanceFromUserLocation;
@property (readonly) double diffAngleFromUserOrientation;


#pragma mark - flags for navigation
@property BOOL hasBeenApproached;
@property NSTimeInterval lastApproached;
@property BOOL hasBeenLeft;
@property NSTimeInterval lastLeft;
@property BOOL count;

- (instancetype)initWithText:(NSString*)text Location:(HLPLocation*)location Options:(NSDictionary*)options;
- (void)updateWithLocation:(HLPLocation*)location andUserLocation:(HLPLocation*)userLocation;
@end

@interface NavNavigator : NSObject
@property (readonly) BOOL isActive;
@property (weak) id<NavNavigatorDelegate> delegate;

+ (instancetype) sharedNavigator;
- (void) stop;
//- (void)preventRemainingDistanceEventFor:(NSTimeInterval)timeInSeconds;
//- (void)preventRemainingDistanceEventBy:(double)nextTargetDistance;
@end
