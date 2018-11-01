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

@interface ServerConfig : NSObject

@property NSDictionary *serverList;

@property NSDictionary *selected;
@property (readonly) NSDictionary *selectedServerConfig;
@property (readonly) NSDictionary *agreementConfig;
@property (readonly) NSDictionary *downloadConfig;

+ (instancetype) sharedConfig;

- (void) requestServerList:(NSString*)path withComplete:(void(^)(NSDictionary*))complete;
- (void) requestServerConfig:(void(^)(NSDictionary* config))complete;
- (NSArray*) checkDownloadFiles;
- (void) checkAgreementForIdentifier:(NSString*)identifier withCompletion:(void(^)(NSDictionary* config))complete;

- (NSURL*) getDestLocation:(NSString*)path;

- (void) clear;

- (BOOL) shouldAskRating;
- (void) completeRating;
- (BOOL) isPreviewDisabled;

- (void) enumerateModes:(void(^_Nonnull)(NSString* _Nonnull mode, NSString* _Nonnull presetPath))iterator;
- (NSArray*) modeList;
@end
