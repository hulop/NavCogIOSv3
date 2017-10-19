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

#import "ServerConfig+Preview.h"

@implementation ServerConfig (Exp)

- (BOOL) isExpMode
{
    return [self expServerHost] != nil;
}

- (NSString*) expServerHost
{
    if (self.selectedServerConfig) {
        NSString *host = self.selectedServerConfig[@"exp_server_host"];
        if (host && [host length] > 0) {
            return host;
        }
    }
    return nil;
}

- (BOOL) useDeviceId
{
    if (self.selectedServerConfig) {
        return [self.selectedServerConfig[@"exp_use_device_id"] boolValue];
    }
    return NO;
}

- (BOOL)useAreaSelection
{
    if (self.selectedServerConfig) {
        return [self.selectedServerConfig[@"exp_use_area_selection"] boolValue];
    }
    return NO;
}

- (BOOL)onlyRoutePreview
{
    if (self.selectedServerConfig) {
        return [self.selectedServerConfig[@"exp_only_route_preview"] boolValue];
    }
    return NO;
}

@end
