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
#import <UIKit/UIKit.h>
#import "HLPLocation.h"
#import "HLPGeoJson.h"

@interface NavDataStore : NSObject

@property NSString *toTitle;
@property NSString *fromTitle;
@property NSString *toID;
@property NSString *fromID;
@property BOOL previewMode;

+ (instancetype) sharedDataStore;

- (void) reset;
- (void) reloadDestinations;
- (void) reloadDestinationsAtLat:(double)lat Lng:(double)lng forUser:(NSString*)user withUserLang:(NSString*)user_lang;
- (void) requestRouteFrom:(NSString*)fromID To:(NSString*)toID withPreferences:(NSDictionary*)prefs complete:(void(^)())complete;
- (void) clearRoute;
- (NSArray*) destinations;
- (HLPLocation*) currentLocation;
- (NSArray*) route;
- (NSArray*) features;
- (NSString*) userID;
- (NSString*) userLanguage;
- (NSArray*) searchHistory;

- (void) saveLocation;
- (void) switchFromTo;
- (HLPLandmark*) destinationByID:(NSString*)key;
- (void) manualTurn:(double)diffOrientation;
- (void) manualLocation:(HLPLocation*)location;
- (void) manualLocationReset:(NSDictionary*)location;
- (void) clearSearchHistory;

+ (NSString*) idForCurrentLocation;

@end

@interface NavDestinationDataSource : NSObject <UIPickerViewDataSource, UITableViewDataSource>
@property BOOL showCurrentLocation;
@property NSInteger selectedRow;
@property BOOL showToilet;

- (NSString*) idForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString*) titleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSString*) titleForRow:(NSInteger)row;
- (NSString*) idForRow:(NSInteger)row;

@end

@interface NavSearchHistoryDataSource : NSObject < UITableViewDataSource>
- (NSDictionary*) historyAtIndexPath:(NSIndexPath*)indexPath;
@end

