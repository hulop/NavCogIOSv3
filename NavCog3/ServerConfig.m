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

@implementation ServerConfig {
    NSString *targetDir;
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
    _selectedServerConfig = nil;
    _agreementConfig = nil;
    _selected = nil;
}

- (void)requestServerList:(NSString *)path withComplete:(void (^)(NSDictionary *))complete
{
    // TODO download from server
    /*
    [HLPDataUtil getJSON:[NSURL URLWithString:@"url"] withCallback:^(NSObject *result) {
       // result == nil if error

     }];
     */
    
    _serverList = @{
                @"servers":@[
                        @{
                            @"server_id": @"coredo_muromachi",
                            @"name": @"COREDO室町",
                            @"description": @"2017年02月08日から利用開始",
                            @"hostname": @"hokoukukan.au-syd.mybluemix.net"
                            },
                        @{
                            @"server_id": @"coredo_test",
                            @"name": @"COREDO室町",
                            @"description": @"Test",
                            @"hostname": @"hokoukukan.mybluemix.net"
                            }
                        ]
                };
    
    complete(_serverList);
}

- (void)requestServerConfig:(void(^)(NSDictionary*))complete
{

    NSString *server_host = [self.selected objectForKey:@"hostname"];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/config/server_config.json",server_host]];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        NSError *error2;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error2];
        if (error2) {
            NSLog(@"%@", error2.localizedDescription);
        }
        _selectedServerConfig = json;
        complete(_selectedServerConfig);
    }] resume];
}

- (NSArray*) checkDownloadFiles
{
    NSString *server_host = [self.selected objectForKey:@"hostname"];
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
                                   @"url": [NSString stringWithFormat:@"https://%@/%@",server_host, src]
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
                                   @"url": [NSString stringWithFormat:@"https://%@/%@",server_host,src]
                                   }];
            }
            [config_json setValue:[self getDestLocation:src].path forKey:obj];
        }
    }];
    NSString* location_config = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:config_json options:0 error:nil] encoding:NSUTF8StringEncoding];
    [location_config writeToURL:[self getDestLocation:@"location_config.json"] atomically:NO encoding:NSUTF8StringEncoding error:nil];
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
    NSString *server_host = [[ServerConfig sharedConfig].selected objectForKey:@"hostname"];
    NSString *device_id = [[UIDevice currentDevice].identifierForVendor UUIDString];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/check_agreement?id=%@",server_host, device_id]];
    
    [[[NSURLSession sharedSession] dataTaskWithURL:url
                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                     NSLog(@"check_agreement: %@", json);
                                     
                                     _agreementConfig = json;
                                     complete(_agreementConfig);
                                 }] resume];
}


@end
