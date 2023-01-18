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


#import "ServerConfig.h"
#import "HLPDataUtil.h"

@interface I18nStringsTransformer: NSValueTransformer
@end
@implementation I18nStringsTransformer
static I18nStringsTransformer *I18nStringsTransformerInstance;
+ (instancetype) getInstance {
    if (!I18nStringsTransformerInstance) {
        I18nStringsTransformerInstance = [[I18nStringsTransformer alloc] init];
    }
    return I18nStringsTransformerInstance;
}
+ (Class)transformedValueClass {
    return [I18nStrings class];
}
+ (BOOL)allowsReverseTransformation {
    return NO;
}
- (id)transformedValue:(id)value {
    return [[I18nStrings alloc] initWithDictionary:value];
}
@end

@implementation I18nStrings {
    NSDictionary* _table;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    _table = dictionary;
    return self;
}

- (NSString *)stringByLanguage:(NSString *)lang
{
    if (lang == nil) {
        lang = @"en";
    }
    if (_table && _table[lang]) {
        return _table[lang];
    }
    //return [NSString stringWithFormat:@"_string_not_found_with_%@", lang];
    return nil;
}
@end


@implementation ServerSetting
+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"hostname": @"hostname",
             @"configFileName": @"config_file_name"
             };
}
@end

@implementation ServerEntry {
    int serverIndex;
    NSString *_hostname;
    NSString *_configFileName;
}
@synthesize hostname = _hostname;
@synthesize configFileName = _configFileName;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"serverID": @"server_id",
             @"available": @"available",
             @"name": @"name",
             @"serverDescription": @"description",
             @"settings": @"settings",
             @"hostname": @"hostname",
             @"configFileName": @"config_file_name",
             @"noCheckAgreement": @"no_check_agreement",
             @"selected": @"selected",
             @"useHttp": @"use_http",
             @"minimumAppVersion":@"minimum_app_version"
             };
}

+ (NSValueTransformer *)nameJSONTransformer {
    return [I18nStringsTransformer getInstance];
}

+ (NSValueTransformer *)serverDescriptionJSONTransformer {
    return [I18nStringsTransformer getInstance];
}

+ (NSValueTransformer *)settingsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[ServerSetting class]];
}


-(NSString *)hostname
{
    unsigned long limit = (_settings != nil) ? _settings.count : 1;
    if (serverIndex < limit) {
        if (_settings) {
            return _settings[serverIndex].hostname;
        } else {
            return _hostname;
        }
    } else {
        return nil;
    }
}

- (NSString *)configFileName
{
    unsigned long limit = (_settings != nil) ? _settings.count : 1;
    if (serverIndex < limit) {
        if (_settings) {
            return _settings[serverIndex].configFileName;
        } else {
            return _configFileName;
        }
    } else {
        return nil;
    }
}

- (void)failed
{
    serverIndex++;
}

- (NSString*)httpProtocol
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"] ? @"https" : @"http";
}

- (NSURL *)checkAgreementURLWithIdentifier:(NSString *)identifier
{
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    NSString *path = [NSString stringWithFormat:@"api/check_agreement?id=%@&appname=%@",identifier, appName];
    return [self URLWithPath:path];
}

- (NSURL *)agreementURLWithIdentifier:(NSString *)identifier
{
    NSDictionary *config = [ServerConfig sharedConfig].agreementConfig;
    NSString *path = [NSString stringWithFormat:@"%@?id=%@", config[@"path"], identifier];
    return [self URLWithPath:path];
}

- (NSURL *)configFileURL
{
    return [self URLWithPath:[NSString stringWithFormat:@"config/%@", self.configFileName]];
}

- (NSURL*)URLWithPath:(NSString *)path
{
    NSString *urlString = [NSString stringWithFormat:@"%@://%@/%@", self.httpProtocol, self.hostname, path];
    return [NSURL URLWithString:urlString];
}

@end


@implementation ServerConfig {
    NSURL* targetDir;
    int _requestCount;
    ServerEntry* _selected;
}

static ServerConfig *instance;

+ (instancetype)sharedConfig
{
    if (!instance) {
        instance = [[ServerConfig alloc] init];
    }
    return instance;
}

- (instancetype) init
{
    self = [super init];
    
    NSString *dir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    dir = [NSString stringWithFormat:@"%@/location", dir];
    NSLog(@"dir=%@",dir);
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    targetDir = [NSURL fileURLWithPath:dir];
    NSLog(@"targetDir=%@",targetDir);

    return self;
}

- (void)clear
{
    _serverList = nil;
    _selectedServerConfig = nil;
    _agreementConfig = nil;
    _downloadConfig = nil;
    _selected = nil;
}

- (void)setSelected:(ServerEntry *)selected
{
    _selected = selected;
    
    if (_selected.useHttp) {
        [[NSUserDefaults standardUserDefaults] setValue:@(NO) forKey:@"https_connection"];
    } else {
        [[NSUserDefaults standardUserDefaults] setValue:@(YES) forKey:@"https_connection"];
    }
}

- (ServerEntry *)selected
{
    return _selected;
}

- (void)requestServerList:(void (^)(ServerList *))complete
{
    ServerList*(^processServerList)(NSDictionary*) = ^(NSDictionary* json) {
        if (json && json[@"servers"]) {
            NSMutableArray* ret = [@[] mutableCopy];
            [json[@"servers"] enumerateObjectsUsingBlock:^(NSDictionary* _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSError *error;
                ServerEntry* entry = [MTLJSONAdapter modelOfClass:ServerEntry.class
                                               fromJSONDictionary:obj error:&error];
                if (error) {
                    NSLog(@"%@", error.localizedDescription);
                }
                [ret addObject:entry];
            }];
            
            for (ServerEntry *entry in ret) {
                if (entry.selected) {
                    self.selected = entry;
                    break;
                }
            }
            return (ServerList*)ret;
        }
        return (ServerList*)nil;
    };
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* serverListPath = [documentsPath stringByAppendingPathComponent:@"serverlist.json"];
    
    if ([fm fileExistsAtPath:serverListPath]) {
        NSError *error;
        NSData *data = [NSData dataWithContentsOfFile:serverListPath];
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if ((_serverList = processServerList(json)) != nil) {
            complete(_serverList);
            return;
        }
    }

    NSURL *miraikanURL = [[NSBundle mainBundle] URLForResource:@"serverlist" withExtension:@"json"];
    if (miraikanURL) {
        NSError *error;
        NSData *data = [NSData dataWithContentsOfURL:miraikanURL];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if ((_serverList = processServerList(json)) != nil) {
            complete(_serverList);
            return;
        }
    }
}

- (void)requestServerConfig:(void(^)(NSDictionary*))complete
{
    NSURL* url = self.selected.configFileURL;
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _selectedServerConfig = (NSDictionary*)result;
            _selectedServerConfig = [self convertRelativePath:_selectedServerConfig withHostName:url.host];
            complete(_selectedServerConfig);
        } else {
            [self.selected failed];
            complete(nil);
        }
    }];
}

- (NSString*)convertRelativePath:(NSString*)orig
{
    if (_selected) {
        NSURL* url = self.selected.configFileURL;
        if ([orig hasPrefix:@"/"]) {
            return [NSString stringWithFormat:@"%@%@", url.host, orig];
        }
    }
    return orig;
}

- (NSDictionary*)convertRelativePath:(NSDictionary*)orig withHostName:(NSString*)hostname
{
    NSMutableDictionary* ret = [orig mutableCopy];
    
    [ret enumerateKeysAndObjectsUsingBlock:^(NSString*  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key rangeOfString:@"server"].location != NSNotFound) {
            if ([obj isKindOfClass:NSString.class]) {
                if ([((NSString*)obj) hasPrefix:@"/"]) {
                    [ret setObject:[NSString stringWithFormat:@"%@%@", hostname, obj] forKey:key];
                }
            }
        }
    }];
    
    return ret;
}

- (NSArray*) checkDownloadFiles
{
    NSDictionary *json = _selectedServerConfig;

    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSMutableDictionary *config_json = [[NSMutableDictionary alloc] init];
    NSArray* map_files = [json objectForKey:@"map_files"];
    if (map_files) {
        NSMutableArray *maps = [[NSMutableArray alloc] init];
        [map_files enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            NSString *src = [obj objectForKey:@"src"];
            long size = [[obj objectForKey:@"size"] longValue];
            if (![self checkIfExists:src size:size]) {
                [files addObject:@{
                                   @"length": @(size),
                                   @"url": [self.selected URLWithPath: src]
                                   }];
            }
            [maps addObject:[self getDestLocation:src].path];
        }];
        [config_json setObject:maps forKey:@"map_files"];
    }

    [json enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSDictionary* _Nonnull preset, BOOL * _Nonnull stop) {
        if ([key hasPrefix:@"preset_for_"]) {
            if ([key isEqualToString:@"preset_for_sighted"]) { // backward compatibility
                key = @"preset_for_general";
            }
            NSString *src = [preset objectForKey:@"src"];
            long size = [[preset objectForKey:@"size"] longValue];
            if (![self checkIfExists:src size:size]) {
                [files addObject:@{
                                   @"length": @(size),
                                   @"url": [self.selected URLWithPath: src]
                                   }];
            }
            [config_json setValue:[self getDestLocation:src].path forKey:key];
        }
    }];
    
    NSString* location_config = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:config_json options:0 error:nil] encoding:NSUTF8StringEncoding];
    [location_config writeToURL:[self getDestLocation:@"location_config.json"] atomically:NO encoding:NSUTF8StringEncoding error:nil];
    _downloadConfig = config_json;
    NSLog(@"files: %@", files);

    return files;
}


- (NSURL*) getDestLocation:(NSString*)path {
    return [NSURL URLWithString:[NSURL URLWithString:path].lastPathComponent relativeToURL:targetDir];
}

- (BOOL) checkIfExists:(NSString*)path size:(long)size {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *filePath = [self getDestLocation:path].path;
    if ([fm fileExistsAtPath:filePath]) {
        if (size > 0) {
            NSDictionary *attribute = [fm attributesOfItemAtPath:filePath error:nil];
            long fileSize = [[attribute objectForKey:NSFileSize] longValue];
            return fileSize == size;
        }
        return YES;
    }
    return NO;
}

- (void)checkAgreementForIdentifier:(NSString*)identifier withCompletion:(void(^)(NSDictionary*))complete
{
    if (self.selected.noCheckAgreement) {
        _agreementConfig = @{@"agreed":@(true)};
        complete(_agreementConfig);
        return;
    }
    
    NSURL *url = [self.selected checkAgreementURLWithIdentifier:identifier];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _agreementConfig = (NSDictionary*)result;
            complete(_agreementConfig);
        } else {
            [self.selected failed];
            complete(nil);
        }
    }];
}

- (BOOL)isPreviewDisabled
{
    return _selectedServerConfig[@"navcog_disable_preview"] && [_selectedServerConfig[@"navcog_disable_preview"] boolValue];
}

- (void)enumerateModes:(void (^)(NSString* _Nonnull, NSString* _Nonnull))iterator
{
    if (_downloadConfig == nil) {
        return;
    }
    [_downloadConfig enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key hasPrefix:@"preset_for_"]) {
            iterator([key substringFromIndex: 11], obj);
        }
    }];
}

- (NSArray *)extraMenuList
{
    NSDictionary *json = _selectedServerConfig;
    
    if (json[@"extra_menus"]) {
        _extraMenuConfig = json[@"extra_menus"];
    }
    
    return _extraMenuConfig;
}

- (void)setDataDownloaded:(BOOL) isCompleted {
    [[NSUserDefaults standardUserDefaults] setBool:isCompleted forKey:@"data_downloaded"];
}

- (BOOL)checkDataDownloaded {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"data_downloaded"];
}

@end
