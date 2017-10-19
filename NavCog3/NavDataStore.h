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
#import "HLPLocation.h"
#import "HLPGeoJson.h"

typedef enum {
    NavDestinationTypeLandmark = 1,
    NavDestinationTypeLocation,
    NavDestinationTypeSelectStart,
    NavDestinationTypeSelectDestination,
    NavDestinationTypeFilter,
    NavDestinationTypeLandmarks,
    NavDestinationTypeDialogSearch
} NavDestinationType;

@interface NavDestination : NSObject <NSCoding>
@property (readonly) NavDestinationType type;
@property (readonly) NSString* name;
@property (readonly) NSString* namePron;
@property (readonly) NSString* _id;
@property (readonly) NSString* singleId;
@property (readonly) NSDictionary* filter;
@property (readonly) NSString* label;
@property (readonly) HLPLandmark* landmark;
@property (readonly) NSArray<HLPLandmark*>* landmarks;

-(instancetype)initWithLandmark:(HLPLandmark*)landmark;
-(instancetype)initWithLocation:(HLPLocation*)location;
-(instancetype)initWithLabel:(NSString*)label Filter:(NSDictionary*)filter;
-(void)addLandmark:(HLPLandmark*)landmark;
-(HLPLocation*)location;
+(instancetype)selectStart;
+(instancetype)selectDestination;
+(instancetype)dialogSearch;
@end

@interface NavDataStore : NSObject

@property NavDestination *to;
@property NavDestination *from;
@property BOOL previewMode;
@property BOOL exerciseMode;
@property BOOL toolMode;
@property NSString* userID;
@property HLPLocation *mapCenter;
@property (readonly) NSDictionary *buildingInfo;
@property HLPLocation *loadLocation;


@property (readonly) NSDictionary *idMap;
@property (readonly) NSDictionary<NSString*, HLPEntrance*> *entranceMap;
@property (readonly) NSDictionary *poiMap;
@property (readonly) NSDictionary *nodesMap;
@property (readonly) NSDictionary *linksMap;
@property (readonly) NSDictionary *nodeLinksMap;
@property (readonly) NSDictionary *linkPoiMap;
@property (readonly) NSArray *pois;
@property (readonly) NSArray *escalatorLinks;


@property NSTimeInterval start;

+ (instancetype) sharedDataStore;

- (void) reset;
- (BOOL) reloadDestinations:(BOOL)force withComplete:(void(^)(NSArray*))complete;
- (BOOL) reloadDestinations:(BOOL)force;
- (BOOL) reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang;
- (BOOL) reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang withComplete:(void(^)(NSArray*))complete;
- (BOOL) reloadDestinationsAtLat:(double)lat Lng:(double)lng Dist:(int)dist forUser:(NSString*)user withUserLang:(NSString*)user_lang;
- (BOOL) reloadDestinationsAtLat:(double)lat Lng:(double)lng Dist:(int)dist forUser:(NSString*)user withUserLang:(NSString*)user_lang withComplete:(void(^)(NSArray*))complete;
- (void) requestRouteFrom:(NSString*)fromID To:(NSString*)toID withPreferences:(NSDictionary*)prefs complete:(void(^)())complete;
- (void) requestRerouteFrom:(NSString*)fromID To:(NSString*)toID withPreferences:(NSDictionary*)prefs complete:(void(^)())complete;
- (void) requestServerConfigWithComplete:(void(^)())complete;
- (void) clearRoute;
- (NSArray*) destinations;
- (HLPLocation*) currentLocation;
- (NSArray*) route;
- (NSArray*) features;
- (NSString*) userLanguage;
- (NSArray*) searchHistory;
- (BOOL) isManualLocation;

- (void) switchFromTo;
- (NavDestination*) destinationByID:(NSString*)key;
- (NavDestination*) destinationByIDs:(NSArray*)keys;
- (NavDestination*) closestDestinationInLandmarks:(NSArray*)landmarks;
- (void) manualTurn:(double)diffOrientation;
- (void) manualLocation:(HLPLocation*)location;
- (void) manualLocationReset:(NSDictionary*)location;
- (void) clearSearchHistory;
- (BOOL) isKnownDestination:(NavDestination*)dest;
- (void) startExercise;

- (BOOL) isElevatorNode:(HLPNode*)node;
- (BOOL) hasRoute;
- (BOOL) isOnRoute:(NSString*)objID;
- (BOOL) isOnDestination:(NSString*)nodeID;
- (BOOL) isOnStart:(NSString*)nodeID;
- (HLPLink*) firstRouteLink:(double)ignoreDistance;
- (HLPLink*) lastRouteLink:(double)ignoreDistance;
- (HLPLink*) routeLinkById:(NSString*)linkID;
- (HLPLink*) findElevatorLink:(HLPLink*)link;
- (NSArray*) nearestLinksAt:(HLPLocation*)loc withOptions:(NSDictionary*)option;

+ (NavDestination*) destinationForCurrentLocation;

@end


