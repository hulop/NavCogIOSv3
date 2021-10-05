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

#import "ConfigManager.h"
#import <Mantle.h>

@implementation ConfigManager

+ (NSArray *)filenamesWithSuffix:(NSString*)suffix {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray* allFileNames = [fm contentsOfDirectoryAtPath:documentsPath error:nil];
    
    return [allFileNames filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"SELF like '*%@'", suffix]]];
}

+ (BOOL)saveConfig:(NSDictionary*)config withName:(NSString*)name Force:(BOOL)force
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* path = [[documentsPath stringByAppendingPathComponent:name] stringByAppendingString:@".plist"];
    
    if (!force && [fm fileExistsAtPath:path]) {
        return NO;
    }

    //NSLog(@"%@", config);
    [config writeToFile:path atomically:YES];
    return YES;
}

+ (BOOL)loadConfig:(NSString *)name
{
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString* path = [documentsPath stringByAppendingPathComponent:name];
    
    NSDictionary* dic = [[NSDictionary alloc] initWithContentsOfFile:path];
    if (!dic) {
        return NO;
    }
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (dic[@"one_time_preset"]) { // onetime preset values
        NSDictionary *preset = dic[@"one_time_preset"];
        dic = [dic mtl_dictionaryByRemovingValuesForKeys:@[@"one_time_preset"]];
        
        if (preset[@"id"]) {
            NSString *key = [NSString stringWithFormat:@"one_time_preset_%@", preset[@"id"]];
            preset = [preset mtl_dictionaryByRemovingValuesForKeys:@[@"id"]];
            
            if (![ud boolForKey:key]) {
                [ud setBool:YES forKey:key];
                for(NSString *key in preset) {
                    [ud setObject:preset[key] forKey:key];
                }
            }
        }
    }
    
    for(NSString *key in dic) {
        [ud setObject:dic[key] forKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

@end
