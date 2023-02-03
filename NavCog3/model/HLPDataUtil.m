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

#import "HLPDataUtil.h"
#import "ServerConfig.h"

#define ROUTE_SEARCH @"%@://%@/%@routesearch"
#define QUERY_SERVICE @"%@://%@/%@"
#define QUERY_DIRECTRY @"directory"
#define QUERY_SEARCH @"search"

@implementation HLPDataUtil

+ (NSURL*)urlForRouteSearchService
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *server = [ud stringForKey:@"selected_hokoukukan_server"];
    NSString *context = [ud stringForKey:@"hokoukukan_server_context"];
    NSString *https = [ud boolForKey:@"https_connection"]?@"https":@"http";
    return [NSURL URLWithString:[NSString stringWithFormat:ROUTE_SEARCH, https, server, context]];
}

+ (NSURL*)urlForQueryServiceWithAction:(NSString*)action {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *config = [[ServerConfig sharedConfig] selectedServerConfig];
    NSString *server = config[@"query_server"];
    NSString *https = [ud boolForKey:@"https_connection"]?@"https":@"http";
    return [NSURL URLWithString:[NSString stringWithFormat:QUERY_SERVICE, https, server, action]];
}


+ (void)queryDirectoryForUser:(NSString *)user withQuery:(NSString *)query withLang:(NSString*)lang withCallback :(void (^)(HLPDirectory *))callback
{
    NSDictionary *dic =
    @{
      @"user": user,
      @"lang": lang,
      @"q": query
      };
    
    NSURL *url = [self urlForQueryServiceWithAction:QUERY_SEARCH];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
            return;
        }
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil);
            return;
        }
        HLPDirectory *directory = [MTLJSONAdapter modelOfClass:HLPDirectory.class fromJSONDictionary:json error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", json[@"sections"]);
            callback(nil);
        } else {
            callback(directory);
        }
    }];
}

+ (void)loadDirectoryAtLat:(double)lat Lng:(double)lng inDist:(int)dist forUser:(NSString*)user withLang:(NSString*)lang withCallback:(void(^)(NSArray<HLPObject*>* result, HLPDirectory* directory))callback
{
    
    NSDictionary *dic =
    @{
      @"lat": @(lat),
      @"lng": @(lng),
      @"dist": @(dist),
      @"user": user,
      @"lang": lang
      };
    
    NSURL *url = [self urlForQueryServiceWithAction:QUERY_DIRECTRY];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil, nil);
            return;
        }
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil, nil);
            return;
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
            [self saveToPlistWithDictionary:json fileName:@"jsonloadDirectoryAtLat.plist"];
        }
        NSMutableArray *array = [@[] mutableCopy];
        if (json[@"landmarks"] != nil) {
            for(NSDictionary* dic in json[@"landmarks"]) {
                NSError *error;
                HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [array addObject:obj];
#if TARGET_OS_SIMULATOR
                    NSLog(@"%@", obj);
#endif
                }
            }
        }
        HLPDirectory *directory = [MTLJSONAdapter modelOfClass:HLPDirectory.class fromJSONDictionary:json error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", json[@"sections"]);
            callback(array, nil);
        } else {
            callback(array, directory);
        }
    }];
}
    
+ (void)loadLandmarksAtLat:(double)lat Lng:(double)lng inDist:(int)dist forUser:(NSString*)user withLang:(NSString *)lang withCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSDictionary *dic =
    @{
      @"action": @"start",
      @"lat": @(lat),
      @"lng": @(lng),
      @"dist": @(dist),
      @"user": user,
      @"lang": lang
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
            return;
        }
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil);
            return;
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
            [self saveToPlistWithDictionary:json fileName:@"jsonloadLandmarksAtLat.plist"];
        }
        NSMutableArray *array = [@[] mutableCopy];
        if (json[@"landmarks"] != nil) {
            for(NSDictionary* dic in json[@"landmarks"]) {
                NSError *error;
                HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [array addObject:obj];
#if TARGET_OS_SIMULATOR
                    NSLog(@"%@", obj);
#endif
                }
            }
        }
        callback(array);
    }];
}


/*
 {"dist":"500","preset":"9","min_width":"9","slope":"9","road_condition":"9","stairs":"9","deff_LV":"9","esc":"1","elv":"9"}
 */

+ (void)loadRouteFromNode:(NSString *)from toNode:(NSString *)to forUser:(NSString*)user withLang:(NSString *)lang withPrefs:(NSDictionary *)prefs withCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSString* prefstr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:prefs options:0 error:nil] encoding:NSUTF8StringEncoding];
    NSDictionary *dic =
    @{
      @"action": @"search",
      @"from": from,
      @"to": to,
      @"preferences": prefstr,
      @"user": user,
      @"lang": lang
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
            return;
        }
        NSError *error;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil);
            return;
        }
        if ([json isKindOfClass:NSDictionary.class]) { // error json
            callback(nil);
            return;
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
            [self saveToPlistWithArray:json fileName:[NSString stringWithFormat:@"jsonloadRouteFromNode_%@_%@.plist", from, to]];
        }
        NSMutableArray *array = [@[] mutableCopy];
        for(NSDictionary* dic in json) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [array addObject:obj];
#if TARGET_OS_SIMULATOR
                NSLog(@"%@", obj);
#endif
            }
        }
        callback(array);
    }];
}

+ (void)loadNodeMapForUser:(NSString*)user withLang:(NSString*)lang WithCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSDictionary *dic =
    @{
      @"action": @"nodemap",
      @"user": user,
      @"lang": lang
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
            return;
        }
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil);
            return;
        }
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
            [self saveToPlistWithDictionary:json fileName:@"jsonloadLandmarksAtLat.plist"];
        }

        NSMutableArray *array = [@[] mutableCopy];
        for(NSString *key in json) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:json[key] error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", json[key]);
            } else {
                [array addObject:obj];
            }
        }
        callback(array);
    }];
}

+ (void)loadFeaturesForUser:(NSString*)user withLang:(NSString*)lang WithCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSDictionary *dic =
    @{
      @"action": @"features",
      @"user": user,
      @"lang": lang
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
            return;
        }
        NSError *error;
        NSArray *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
        if (error) {
            NSLog(@"%@", error);
            NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            callback(nil);
            return;
        }
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
            [self saveToPlistWithArray:json fileName:@"jsonloadFeaturesForUser.plist"];
        }

        NSMutableArray *array = [@[] mutableCopy];
        for(NSDictionary* dic in json) {
            NSError *error;
            HLPObject *obj = [MTLJSONAdapter modelOfClass:HLPObject.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                [array addObject:obj];
            }
        }
        callback(array);
    }];
}

+(void)postRequest:(NSURL*) url withData:(NSDictionary*) data callback:(void(^)(NSData* response))callback
{
    [HLPDataUtil method:@"POST" request:url withData:data callback:callback];
}

+(void)postRequest:(NSURL*) url contentType:(NSString*)type withData:(NSData*) data callback:(void(^)(NSData* response))callback
{
    [HLPDataUtil method:@"POST" request:url contentType:type withData:data callback:callback];
}

+(void)deleteRequest:(NSURL*) url withData:(NSDictionary*) data callback:(void(^)(NSData* response))callback
{
    [HLPDataUtil method:@"DELETE" request:url withData:data callback:callback];
}

+(void)method:(NSString*)method request:(NSURL*) url withData:(NSDictionary*) data callback:(void(^)(NSData* response))callback
{
    NSMutableString *temp = [[NSMutableString alloc] init];
    for(NSString *key in [data allKeys]) {
        [temp appendFormat:@"%@=%@&", key, data[key]];
    }
    NSString *temp2 = [temp stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSData *query = [temp2 dataUsingEncoding:NSUTF8StringEncoding];
    
    [HLPDataUtil method:method
                request:url
            contentType:@"application/x-www-form-urlencoded; charset=UTF-8"
               withData:query
               callback:callback];
}

+(void)method:(NSString*)method request:(NSURL*) url contentType:(NSString*)type withData:(NSData*) data callback:(void(^)(NSData* response))callback
{
    @try{
        NSMutableURLRequest *request = [NSMutableURLRequest
                                             requestWithURL: url
                                             cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                             timeoutInterval: 60.0];

        NSLog(@"Requesting %@ %@", method, url);
        NSLog(@"Data:      %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        [request setHTTPMethod: method];
        [request setValue:type forHTTPHeaderField: @"Content-Type"];
        [request setValue:[NSString stringWithFormat: @"%lu", (unsigned long)[data length]]  forHTTPHeaderField: @"Content-Length"];
        [request setHTTPBody: data];
        
        NSURLSession *session = [NSURLSession sharedSession];
        
        [[session dataTaskWithRequest: request  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
            @try {
                if (response && ! error) {
                    callback(data);
                }
                else {
                    NSLog(@"Error: %@", [error localizedDescription]);
                    callback(nil);
                }
            }
            @catch(NSException *e) {
                NSLog(@"%@", [e debugDescription]);
            }
        }] resume];
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
        callback(nil);
    }
}

+ (void)getJSON:(NSURL *)url withCallback:(void (^)(NSObject *))callback
{
    [HLPDataUtil method:@"GET" request:url contentType:@"" withData:[[NSData alloc] init] callback:^(NSData *response) {
        @try {
            if (response) {
                NSError *error2;
                NSObject *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error2];
                if (json && !error2) {
                    callback(json);
                } else {
                    NSLog(@"Error2: %@", [error2 localizedDescription]);
                    //NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                    callback(nil);
                }
            } else {
                callback(nil);
            }
        }
        @catch(NSException *e) {
            NSLog(@"%@", [e debugDescription]);
            callback(nil);
        }
    }];
}

+ (void)saveToPlistWithArray:(NSArray *)array fileName:(NSString *)file
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString *filePath = [directory stringByAppendingPathComponent: file];
    [array writeToFile:filePath atomically:NO];
}

+ (void)saveToPlistWithDictionary:(NSDictionary*)dic fileName:(NSString*)file
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [paths objectAtIndex:0];
    NSString *filePath = [directory stringByAppendingPathComponent: file];
    [dic writeToFile:filePath atomically:NO];
}

@end
