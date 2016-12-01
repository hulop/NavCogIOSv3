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

#import "AppDelegate.h"
#import "Logging.h"
#import "SettingViewController.h"
#import "LocationManager.h"
#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavDeviceTTS.h"
#import <Speech/Speech.h> // for Swift header
#import "NavCog3-Swift.h"

@interface AppDelegate ()

@end

@implementation AppDelegate {
    LocationManager *manager;
    NSString *currentUIMode;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //[self checkUIMode];
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    // [Logging startLog];
    
    // need to call once after install
    [SettingViewController setup];
    
    //manager = [[LocationManager alloc] init];
    //manager.delegate = self;
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    nds.userID = [UIDevice currentDevice].identifierForVendor.UUIDString;
    [nds requestServerConfigWithComplete:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SERVER_CONFIG_CHANGED_NOTIFICATION object:nds.serverConfig];
    }];

    [DialogManager sharedManager];

    [NavDeviceTTS sharedTTS];
    
    // check location privilege
    manager = [LocationManager sharedManager];
    [manager start];
        
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    // prevent automatic sleep
    application.idleTimerDisabled = YES;
    
    _backgroundID = UIBackgroundTaskInvalid;
    
    return YES;
    
}

void uncaughtExceptionHandler(NSException *exception)
{
    NSLog(@"%@", exception.name);
    NSLog(@"%@", exception.reason);
    NSLog(@"%@", exception.callStackSymbols);
}

- (void) checkUIMode
{
    NSString *ui_mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"ui_mode"];
 
    if ([ui_mode isEqualToString:currentUIMode]) {
        return;
    }
    currentUIMode = ui_mode;
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];;
    UIViewController *viewController = nil;
    
    if ([ui_mode isEqualToString:@"UI_BLIND"]) {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"blind_ui_navigation"];
    } else if ([ui_mode isEqualToString:@"UI_WHEELCHAIR"]) {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"wheelchair_ui_navigation"];
    } else if (ui_mode == nil) {
        // TODO show a view for UI mode select
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"wheelchair_ui_navigation"];
    }
    
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
    

}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    //[manager stop];
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_SAVE object:nil];
    //[[NavDataStore sharedDataStore] reset];
    //manager = nil;
    UIApplication *app = [UIApplication sharedApplication];
    _backgroundID = [app beginBackgroundTaskWithExpirationHandler:^{
        [manager stop];
        [app endBackgroundTask:_backgroundID];
        _backgroundID = UIBackgroundTaskInvalid;
    }];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self beginReceivingRemoteControlEvents];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [UIApplication.sharedApplication endBackgroundTask:_backgroundID];
    [self endReceivingRemoteControlEvents];
    if (!manager.isActive) {
        [manager start];
    }
    [Logging stopLog];    
    [Logging startLog];
    
    // check ui mode
    [self checkUIMode];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void) beginReceivingRemoteControlEvents {
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}
- (void) endReceivingRemoteControlEvents {
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
                // do something...
        }
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([[url scheme] isEqualToString:@"navcog3"]) {
        if ([[url host] isEqualToString:@"start_navigation"]) {
            NSURLComponents *comp = [[NSURLComponents alloc] initWithString:[url absoluteString]];

            NSMutableDictionary *opt = [@{} mutableCopy];
            for(NSURLQueryItem *item in comp.queryItems) {
                opt[item.name] = item.value;
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_START_NAVIGATION object:opt];
            return YES;
        }
    }
    return NO;
}

@end
