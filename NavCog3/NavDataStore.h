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
@property (readonly) NSDictionary* filter;
@property (readonly) NSString* label;
@property (readonly) HLPLandmark* landmark;
@property (readonly) NSArray<HLPLandmark*>* landmarks;

-(instancetype)initWithLandmark:(HLPLandmark*)landmark;
-(instancetype)initWithLocation:(HLPLocation*)location;
-(instancetype)initWithLabel:(NSString*)label Filter:(NSDictionary*)filter;
-(void)addLandmark:(HLPLandmark*)landmark;
+(instancetype)selectStart;
+(instancetype)selectDestination;
+(instancetype)dialogSearch;
@end

@interface NavDataStore : NSObject

@property NavDestination *to;
@property NavDestination *from;
@property BOOL previewMode;
@property NSString* userID;
@property HLPLocation *mapCenter;
@property (readonly) NSDictionary *buildingInfo;

+ (instancetype) sharedDataStore;

- (void) reset;
- (BOOL) reloadDestinations:(BOOL)force;
- (BOOL) reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang;
- (void) requestRouteFrom:(NSString*)fromID To:(NSString*)toID withPreferences:(NSDictionary*)prefs complete:(void(^)())complete;
- (void) requestServerConfigWithComplete:(void(^)())complete;
- (void) clearRoute;
- (NSArray*) destinations;
- (HLPLocation*) currentLocation;
- (NSArray*) route;
- (NSArray*) features;
- (NSString*) userLanguage;
- (NSArray*) searchHistory;
- (NSDictionary*) serverConfig;

- (void) switchFromTo;
- (NavDestination*) destinationByID:(NSString*)key;
- (void) manualTurn:(double)diffOrientation;
- (void) manualLocation:(HLPLocation*)location;
- (void) manualLocationReset:(NSDictionary*)location;
- (void) clearSearchHistory;
- (BOOL) isKnownDestination:(NavDestination*)dest;

+ (NavDestination*) destinationForCurrentLocation;

@end


