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
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/user?id=%@",https, server_host, user_id]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            self.userInfo = (NSDictionary*)result;
            complete(self.userInfo);
        } else {
            complete(nil);
        }
    }];
}

- (void)saveUserInfo:(NSString*)user_id withInfo:(NSDictionary *)info withComplete:(void (^)())complete
{
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/user?id=%@",https, server_host, user_id]];
    
    [HLPDataUtil postRequest:url withData:info callback:^(NSData *response) {
        if (response != nil) {
            self.userInfo = info;
        }
    }];
}

- (void)requestRoutesConfig:(void(^)(NSDictionary*))complete
{
    NSString *server_host = [[ServerConfig sharedConfig] expServerHost];
    NSString *https = [[[ServerConfig sharedConfig].selected objectForKey:@"use_http"] boolValue] ? @"http": @"https";
    NSString *routes_file_name = @"exp_routes.json";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@",https, server_host, routes_file_name]];
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if (result && [result isKindOfClass:NSDictionary.class]) {
            self.expRoutes = (NSDictionary*)result;
            complete(self.expRoutes);
        } else {
            complete(nil);
        }
    }];
}

@end
