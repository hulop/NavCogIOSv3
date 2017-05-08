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


#import "AuthManager.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation AuthManager

static AuthManager *instance;

+ (instancetype)sharedManager
{
    if (!instance) {
        instance = [[AuthManager alloc] init];
    }
    return instance;
}

- (BOOL)isAuthorizedForName:(NSString *)name withKey:(NSString *)key
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* keyFile = [documentsPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.keyfile", name]];
    
    NSError *error;
    NSString* localKey = [NSString stringWithContentsOfFile:keyFile encoding:NSUTF8StringEncoding error:&error];
    localKey = [localKey stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    localKey = [AuthManager MD5Hash:localKey];
    
    return [key isEqualToString:localKey];
}

- (BOOL)isDeveloperAuthorized
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"dev" ofType:@"hashfile"];
    if (!path) {
        return NO;
    }
    NSError *error;
    NSString *hash = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    hash = [hash stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return [self isAuthorizedForName:@"dev" withKey:hash];
}

+ (NSString *)MD5Hash:(NSString *)original
{
    if (original.length == 0) {
        return nil;
    }
    const char *data = [original UTF8String];
    CC_LONG len = (CC_LONG)strlen(data);
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, len, result);
    NSMutableString *ms = [@"" mutableCopy];
    for (int i = 0; i < 16; i++) {
        [ms appendFormat:@"%02X",result[i]];
    }
    return ms;
}

@end
