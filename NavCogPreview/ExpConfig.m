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
#import "ExpConfig.h"
#import "HLPDataUtil.h"
#import "ServerConfig+Preview.h"
#import "NavDataStore.h"

@implementation ExpConfig

static ExpConfig *instance;

+ (instancetype)sharedConfig
{
    if (!instance) {
        instance = [[ExpConfig alloc] init];
    }
    return instance;
}

- (instancetype) init
{
    self = [super init];
    return self;
}

- (void)requestUserInfo:(NSString*)user_id withComplete:(void(^)(NSDictionary*))complete
{
    _user_id = user_id;
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    BOOL useDeviceID = [[ServerConfig sharedConfig] useDeviceId];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/user?id=%@",https, server_host, user_id]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _userInfo = (NSDictionary*)result;
            complete(self.userInfo);
        } else {
            if (useDeviceID) {
                [[ExpConfig sharedConfig] saveUserInfo:user_id withInfo:@{@"group":@"anonymous"} withComplete:^{
                    [[ExpConfig sharedConfig] requestUserInfo:user_id withComplete:^(NSDictionary *dic) {
                        complete(dic);
                    }];
                }];
            } else {
                complete(nil);
            }
        }
    }];
}


- (void)saveUserInfo:(NSString*)user_id withInfo:(NSDictionary*)info withComplete:(void(^)(void))complete;
{
    _user_id = user_id;
    NSError *error;
    
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"] ? @"https" : @"http";
    
    NSURL *userurl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/user?id=%@",https, server_host, _user_id]];
    NSData *userdata = [NSJSONSerialization dataWithJSONObject:info options:0 error:&error];
    
    [HLPDataUtil postRequest:userurl
                 contentType:@"application/json; charset=UTF-8"
                    withData:userdata
                    callback:^(NSData *response)
     {
         NSError *error;
         [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
         if (error) {
             NSString *res = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
             NSLog(@"%@", res);
         } else {
             _userInfo = info;
             complete();
         }
     }];
}

- (void)requestRoutesConfig:(void(^)(NSDictionary*))complete
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLocation *center = [nds mapCenter];
    
    if (![[NavDataStore sharedDataStore] reloadDestinationsAtLat:center.lat Lng:center.lng Dist:100000 forUser:nds.userID withUserLang:nds.userLanguage withComplete:^(NSArray* dest){
        [self _requestRoutesConfig:complete];
    }]) {
        [self _requestRoutesConfig:complete];
    }
}

- (void)_requestRoutesConfig:(void(^)(NSDictionary*))complete
{
    if ([NavDataStore sharedDataStore].destinations == nil ||
        [NavDataStore sharedDataStore].destinations.count == 0) {
        complete(nil);
        return;
    }
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    NSString *routes_file_name = @"exp_routes.json";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@",https, server_host, routes_file_name]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            _expRoutes = (NSDictionary*)result;
            complete(self.expRoutes);
            [[NSNotificationCenter defaultCenter] postNotificationName:EXP_ROUTES_CHANGED_NOTIFICATION object:self];
        } else {
            complete(nil);
        }
    }];
}

- (void)endExpDuration:(double)duration withLogFile:(NSString *)logFile withComplete:(void (^)(void))complete
{
    NSError *error;
    
    NSString *logFileName = [logFile lastPathComponent];
    NSString *logFileId = [NSString stringWithFormat:@"%@/%@", _user_id, logFileName];
    NSString *logContent = [NSString stringWithContentsOfFile:logFile encoding:NSUTF8StringEncoding error:&error];
    
    if (logContent == nil) {
        NSLog(@"logContent is nil (%@)", logFile);
        complete();
        return;
    }
    
    double endAt = [[NSDate date] timeIntervalSince1970];
    NSString *routeName = _currentRoute[@"name"];
    if (routeName == nil) {
        complete();
        return;
    }
    
    NSMutableDictionary *info = [_userInfo mutableCopy];
    if (info[@"_id"] == nil) {
        info[@"_id"] = _user_id;
    }
    
    NSMutableArray *routes = [@[] mutableCopy];
    if (!info[@"routes"]) {
        info[@"routes"] = @[];
    }
    BOOL flag = YES;
    for(NSDictionary *route in info[@"routes"]) {
        if ([route[@"name"] isEqualToString:routeName]) {
            flag = NO;
            break;
        }
    }
    if (flag) {
        info[@"routes"] = [info[@"routes"] arrayByAddingObject:@{@"name":routeName, @"limit":_currentRoute[@"limit"]}];
    }
    for(NSDictionary *route in info[@"routes"]) {
        if ([route[@"name"] isEqualToString:routeName]) {
            NSMutableDictionary *temp = [route mutableCopy];
            
            double elapsed_time = [temp[@"elapsed_time"] doubleValue] + duration;
            if (temp[@"lastday"]) {
                NSDate *lastday = [[NSDate alloc] initWithTimeIntervalSince1970:[temp[@"lastday"] doubleValue]];
                NSDate *today = NSDate.date;
                
                NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                NSUInteger lastdayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay
                                                                inUnit:NSCalendarUnitYear forDate:lastday];
                NSUInteger todayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay
                                                              inUnit:NSCalendarUnitYear forDate:today];
                if (lastdayOfYear != todayOfYear) {
                    elapsed_time = duration;
                }
            }
            temp[@"lastday"] = @(NSDate.date.timeIntervalSince1970);
            temp[@"elapsed_time"] = @(elapsed_time);
            if (!temp[@"activities"]) {
                temp[@"activities"] = @[];
            }
            
            NSMutableArray *temp2 = [@[] mutableCopy];
            BOOL flag2 = YES;
            for(NSDictionary *a in temp[@"activities"]) {
                if ([a[@"log_file"] isEqualToString:logFileId]) {
                    [temp2 addObject:@{
                                      @"end_at": @(endAt),
                                      @"duration": @([a[@"duration"] doubleValue]+duration),
                                      @"log_file": logFileId
                                      }];
                    flag2 = NO;
                } else {
                    [temp2 addObject:a];
                }
            }
            if (flag2) {
                [temp2 addObject:@{
                                   @"end_at": @(endAt),
                                   @"duration": @(duration),
                                   @"log_file": logFileId
                                   }];
            }
            temp[@"activities"] = temp2;
            [routes addObject:temp];
        } else {
            [routes addObject:route];
        }
    }
    info[@"routes"] = routes;

    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    
    NSURL *logurl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/log?id=%@",https, server_host, logFileId]];
    NSDictionary *logdic = @{
                              @"_id": logFileId,
                              @"user_id": _user_id,
                              @"created_at": @(endAt),
                              @"log": logContent
                              };
    
    NSData *logdata = [NSJSONSerialization dataWithJSONObject:logdic options:0 error:&error];
    
    NSURL *userurl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/user?id=%@",https, server_host, _user_id]];
    NSData *userdata = [NSJSONSerialization dataWithJSONObject:info options:0 error:&error];
    
    [HLPDataUtil postRequest:logurl
                 contentType:@"application/json; charset=UTF-8"
                    withData:logdata
                    callback:^(NSData *response)
     {
         NSError *error;
         [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
         if (error) {
             NSString *res = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
             NSLog(@"%@", res);
         } else {
             [HLPDataUtil postRequest:userurl
                          contentType:@"application/json; charset=UTF-8"
                             withData:userdata
                             callback:^(NSData *response)
              {
                  NSError *error;
                  [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
                  if (error) {
                      NSString *res = [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding];
                      NSLog(@"%@", res);
                  } else {
                      _userInfo = info;
                      complete();
                  }
             }];
         }
     }];
}

- (double)elapsedTimeForRoute:(NSDictionary *)route
{
    NSArray *infos = [[ExpConfig sharedConfig] expUserRouteInfo];
    double elapsed_time = 0;
    if (infos) {
        for(NSDictionary *info in infos) {
            if ([route[@"name"] isEqualToString:info[@"name"]]) {
                if (info[@"lastday"]) {
                    elapsed_time = [info[@"elapsed_time"] doubleValue];
                    NSDate *lastday = [[NSDate alloc] initWithTimeIntervalSince1970:[info[@"lastday"] doubleValue]];
                    NSDate *today = NSDate.date;
                    
                    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
                    NSUInteger lastdayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay
                                                                    inUnit:NSCalendarUnitYear forDate:lastday];
                    NSUInteger todayOfYear = [gregorian ordinalityOfUnit:NSCalendarUnitDay
                                                                  inUnit:NSCalendarUnitYear forDate:today];
                    if (lastdayOfYear != todayOfYear) {
                        elapsed_time = 0;
                    }
                } else {
                    elapsed_time = 0;
                }
            }
        }
    }
    return elapsed_time;
}

- (NSArray*)expUserRoutes
{
    if (_expRoutes == nil || _userInfo == nil) {
        return nil;
    }
    NSString *group = _userInfo[@"group"];
    if (group == nil) {
        return nil;
    }
    NSArray *routes = _expRoutes[group][@"routes"];
    
    return routes == nil ? @[] : routes;
}

- (NSArray*)expUserRouteInfo
{
    if (_userInfo == nil) {
        return nil;
    }
    return _userInfo[@"routes"];
}

- (NSDictionary *)expUserCurrentRouteInfo
{
    NSArray *infos = [self expUserRouteInfo];
    if (infos != nil || _currentRoute != nil) {
        for(NSDictionary *info in infos) {
            if ([info[@"name"] isEqualToString:_currentRoute[@"name"]]) {
                return info;
            }
        }
    }
    return nil;
}

@end
