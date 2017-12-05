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
#import <UIKit/UIKit.h>

#define SERVERLIST_URL @"https://hulop.github.io/serverlist.json"

@implementation ServerConfig {
    NSURL *targetDir;
    int requestCount;
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

- (void)requestServerList:(NSString *)path withComplete:(void (^)(NSDictionary *))complete
{
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* serverListPath = [documentsPath stringByAppendingPathComponent:@"serverlist.json"];
    
    if ([fm fileExistsAtPath:serverListPath]) {
        NSError *error;
        NSData *data = [NSData dataWithContentsOfFile:serverListPath];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (json) {
            _serverList = json;
            
            for (NSDictionary *server in _serverList[@"servers"]) {
                if ([server[@"selected"] boolValue]) {
                    _selected = server;
                }
            }
            complete(json);
            return;
        }
    }
    NSString *serverlist = SERVERLIST_URL;
    
    NSURL *serverListURL = [[NSBundle mainBundle] URLForResource:@"serverlist" withExtension:@"txt"];
    if (serverListURL) {
        NSError *error;
        serverlist = [NSString stringWithContentsOfURL:serverListURL encoding:NSUTF8StringEncoding error:&error];
        serverlist = [serverlist stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }
    
    NSString* serverListURLPath = [documentsPath stringByAppendingPathComponent:@"serverlist.txt"];
    if ([fm fileExistsAtPath:serverListURLPath]) {
        NSError *error;
        serverlist = [NSString stringWithContentsOfFile:serverListURLPath encoding:NSUTF8StringEncoding error:&error];
        serverlist = [serverlist stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }
    
    [HLPDataUtil getJSON:[NSURL URLWithString:serverlist] withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _serverList = (NSDictionary*)result;
            
            for (NSDictionary *server in _serverList[@"servers"]) {
                if ([server[@"selected"] boolValue]) {
                    _selected = server;
                }
            }
            complete(_serverList);
        } else {
            complete(nil);
        }
    }];
}

- (void)requestServerConfig:(void(^)(NSDictionary*))complete
{
    NSString *server_host = [self.selected objectForKey:@"hostname"];
    NSString *config_file_name = [self.selected objectForKey:@"config_file_name"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"] ? @"https" : @"http";

    config_file_name = config_file_name?config_file_name:@"server_config.json";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/config/%@",https, server_host, config_file_name]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _selectedServerConfig = (NSDictionary*)result;
            complete(_selectedServerConfig);
        } else {
            complete(nil);
        }
    }];
}

- (NSArray*) checkDownloadFiles
{
    NSString *server_host = [self.selected objectForKey:@"hostname"];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"] ? @"https" : @"http";
    NSDictionary *json = _selectedServerConfig;

    NSLog(@"server_config.json: %@", json);
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
                                   @"url": [NSString stringWithFormat:@"%@://%@/%@",https, server_host, src]
                                   }];
            }
            [maps addObject:[self getDestLocation:src].path];
        }];
        [config_json setObject:maps forKey:@"map_files"];
    }
    NSArray *const PRESETS = @[@"preset_for_blind", @"preset_for_sighted", @"preset_for_wheelchair"];
    [PRESETS enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
        NSDictionary* preset = [json objectForKey:obj];
        if (preset) {
            NSString *src = [preset objectForKey:@"src"];
            long size = [[preset objectForKey:@"size"] longValue];
            if (![self checkIfExists:src size:size]) {
                [files addObject:@{
                                   @"length": @(size),
                                   @"url": [NSString stringWithFormat:@"%@://%@/%@",https, server_host,src]
                                   }];
            }
            [config_json setValue:[self getDestLocation:src].path forKey:obj];
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

- (void)checkAgreement:(void(^)(NSDictionary*))complete
{
    if ([[[ServerConfig sharedConfig].selected objectForKey:@"no_checkagreement"] boolValue]) {
        _agreementConfig = @{@"agreed":@(true)};
        complete(_agreementConfig);
        return;
    }

    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    NSLog(@"AppName: %@",appName);
    NSString *server_host = [[ServerConfig sharedConfig].selected objectForKey:@"hostname"];
    NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
    NSString *https = [[self.selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/api/check_agreement?id=%@&appname=%@",https,server_host, device_id, appName]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _agreementConfig = (NSDictionary*)result;
            complete(_agreementConfig);
        } else {
            complete(nil);
        }
    }];
}

- (BOOL)shouldAskRating
{
    NSString *identifier = @"temp";
    if (_selected) {
        identifier = _selected[@"server_id"];
    }
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL ask_enquete = NO;
    BOOL isFirstTime = ![ud boolForKey:[NSString stringWithFormat:@"%@_enquete_answered", identifier]];
    long count = [ud integerForKey:[NSString stringWithFormat:@"%@_enquete_ask_count", identifier]];
    if (!isFirstTime) {
        count++;
        [ud setObject:@(count) forKey:[NSString stringWithFormat:@"%@_enquete_ask_count", identifier]];
    }
    
    if (_selectedServerConfig) {
        ask_enquete = [_selectedServerConfig[@"ask_enquete"] boolValue];
    }

    return ask_enquete && (isFirstTime || count % 5 == 0);
}

- (void)completeRating
{
    NSString *identifier = @"temp";
    if (_selected) {
        identifier = _selected[@"server_id"];
    }

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:@(YES) forKey:[NSString stringWithFormat:@"%@_enquete_answered", identifier]];
    [ud setObject:@(0) forKey:[NSString stringWithFormat:@"%@_enquete_ask_count", identifier]];
}

- (BOOL)isPreviewDisabled
{
    return _selectedServerConfig[@"navcog_disable_preview"] && [_selectedServerConfig[@"navcog_disable_preview"] boolValue];
}
@end
