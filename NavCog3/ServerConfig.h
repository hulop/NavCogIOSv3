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
#import <Mantle.h>

@interface I18nStrings : NSObject
- (instancetype _Nonnull)initWithDictionary:(NSDictionary* _Nonnull)dictionary;
- (NSString* _Nonnull)stringByLanguage:(NSString* _Nonnull)lang;
@end

@interface ServerSetting : MTLModel<MTLJSONSerializing>
@property (readonly) NSString* _Nonnull hostname;
@property (readonly) NSString* _Nonnull configFileName;
@end

@interface ServerEntry : MTLModel<MTLJSONSerializing>
@property (readonly) NSString* _Nonnull serverID;
@property (readonly) BOOL available;
@property (readonly) I18nStrings* _Nonnull name;
@property (readonly) I18nStrings* _Nonnull serverDescription;
@property (readonly) NSArray<ServerSetting*>* _Nullable settings;
@property (readonly) NSString* _Nullable hostname;
@property (readonly) NSString* _Nullable configFileName;
@property (readonly) BOOL noCheckAgreement;
@property (readonly) BOOL selected;
@property (readonly) BOOL useHttp;
@property (readonly) NSString* _Nullable minimumAppVersion;
@property NSString* _Nonnull userLanguage;

- (void)failed;
- (NSURL* _Nonnull)configFileURL;
- (NSURL* _Nonnull)checkAgreementURLWithIdentifier:(NSString* _Nonnull)identifier;
- (NSURL* _Nonnull)agreementURLWithIdentifier:(NSString* _Nonnull)identifier;
- (NSURL* _Nonnull)URLWithPath:(NSString* _Nonnull)path;
@end

typedef NSArray<ServerEntry*> ServerList;

@interface ServerConfig : NSObject

@property ServerList* _Nullable serverList;

@property ServerEntry* _Nullable selected;
@property (readonly) NSDictionary* _Nullable selectedServerConfig;
@property (readonly) NSDictionary* _Nullable agreementConfig;
@property (readonly) NSDictionary* _Nullable downloadConfig;
@property (readonly) NSArray* _Nullable extraMenuConfig;

+ (instancetype _Nonnull) sharedConfig;

- (void) requestServerList:(void(^_Nullable)(ServerList* _Nullable))complete;

- (void) requestServerConfig:(void(^_Nullable)(NSDictionary* _Nullable config))complete;
- (NSArray* _Nonnull) checkDownloadFiles;
- (void) checkAgreementForIdentifier:(NSString* _Nonnull)identifier withCompletion:(void(^_Nullable)(NSDictionary* _Nullable config))complete;

- (NSURL* _Nonnull) getDestLocation:(NSString* _Nonnull)path;

- (void) clear;

- (BOOL) shouldAskRating;
- (void) completeRating;
- (BOOL) isPreviewDisabled;

- (void) enumerateModes:(void(^_Nonnull)(NSString* _Nonnull mode, NSString* _Nonnull presetPath))iterator;
- (NSArray* _Nonnull) modeList;

- (NSArray* _Nullable) extraMenuList;
- (NSString*_Nonnull)convertRelativePath:(NSString*_Nonnull)orig;
@end
