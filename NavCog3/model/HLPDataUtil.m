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

#define ROUTE_SEARCH @"%@://%@/%@routesearch"

@implementation HLPDataUtil

+ (NSURL*) urlForRouteSearchService
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *server = [ud stringForKey:@"selected_hokoukukan_server"];
    NSString *context = [ud stringForKey:@"hokoukukan_server_context"];
    NSString *https = [ud boolForKey:@"https_connection"]?@"https":@"http";
    return [NSURL URLWithString:[NSString stringWithFormat:ROUTE_SEARCH, https, server, context]];
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
        } else {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                callback(nil);
            } else {
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
                        }
                    }
                }
                callback(array);
            }
        }
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
        } else {
            NSError *error;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                callback(nil);
            } else {
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
            }
        }
    }];
}

+ (void)loadNodeMapForUser:(NSString*)user WithCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSDictionary *dic =
    @{
      @"action": @"nodemap",
      @"user": user
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
        } else {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
            
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                callback(nil);
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
        }
    }];
}

+ (void)loadFeaturesForUser:(NSString*)user WithCallback:(void (^)(NSArray<HLPObject *> *))callback
{
    NSDictionary *dic =
    @{
      @"action": @"features",
      @"user": user
      };
    
    NSURL *url = [self urlForRouteSearchService];
    
    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response == nil) {
            callback(nil);
        } else {
            NSError *error;
            NSArray *json = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                callback(nil);
            } else {
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
            }
        }
    }];
}

+(void)postRequest:(NSURL*) url withData:(NSDictionary*) data callback:(void(^)(NSData* response))callback
{
    @try {
        NSMutableURLRequest *request = [NSMutableURLRequest
                                        requestWithURL: url
                                        cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                        timeoutInterval: 60.0];
        
        NSMutableString *temp = [[NSMutableString alloc] init];
        for(NSString *key in [data allKeys]) {
            [temp appendFormat:@"%@=%@&", key, data[key]];
        }
        
        //NSLog(@"Requesting %@ \n%@", url, temp);
        
        
        NSData *query = [temp dataUsingEncoding:NSUTF8StringEncoding];
        
        [request setHTTPMethod: @"POST"];
        [request setValue: @"application/x-www-form-urlencoded"  forHTTPHeaderField: @"Content-Type"];
        [request setValue: [NSString stringWithFormat: @"%lu", (unsigned long)[query length]]  forHTTPHeaderField: @"Content-Length"];
        [request setHTTPBody: query];
        
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
    
    NSMutableURLRequest *request = [NSMutableURLRequest
                                    requestWithURL: url
                                    cachePolicy: NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                    timeoutInterval: 60.0];
    [request setHTTPMethod: @"GET"];
    
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithRequest: request  completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        @try {
            if (response && ! error) {
                NSError *error2;
                NSObject *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error2];
                if (json && !error2) {
                    callback(json);
                } else {
                    NSLog(@"Error2: %@", [error2 localizedDescription]);
                }
            } else {
                NSLog(@"Error: %@", [error localizedDescription]);
            }
            callback(nil);
        }
        @catch(NSException *e) {
            NSLog(@"%@", [e debugDescription]);
        }
    }] resume];
}
@end
