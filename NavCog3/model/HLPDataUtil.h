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

@interface HLPDataUtil : NSObject

+ (void) loadRouteFromNode:(NSString*)from toNode:(NSString*)to forUser:(NSString*) user withLang:(NSString*)lang withPrefs:(NSDictionary*) prefs withCallback:(void(^)(NSArray<HLPObject*>* result))callback;

+ (void) loadLandmarksAtLat:(double) lat Lng:(double) lng inDist:(int) dist forUser:(NSString*) user withLang:(NSString*) lang withCallback:(void(^)(NSArray<HLPObject*>* result))callback;

// need to call loadLandmarksAtLat first before calling the following methods
+ (void) loadNodeMapForUser:(NSString*)user withLang:(NSString*)lang WithCallback:(void(^)(NSArray<HLPObject*>* result))callback;
+ (void) loadFeaturesForUser:(NSString*)user withLang:(NSString*)lang WithCallback:(void(^)(NSArray<HLPObject*>* result))callback;

+ (void) getJSON:(NSURL*)url withCallback:(void(^)(NSObject* result))callback;

+(void)postRequest:(NSURL*) url withData:(NSDictionary*) data callback:(void(^)(NSData* response))callback;

@end
