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
    
    [NavDataStore sharedDataStore].userID = [UIDevice currentDevice].identifierForVendor.UUIDString;

    [NavDeviceTTS sharedTTS];
    
    // check location privilege
    manager = [LocationManager sharedManager];
    [manager start];
        
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    // prevent automatic sleep
    application.idleTimerDisabled = YES;
    
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
    [Logging stopLog];
    //[manager stop];
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_SAVE object:nil];
    //[[NavDataStore sharedDataStore] reset];
    //manager = nil;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [Logging startLog];
    
    // check ui mode
    [self checkUIMode];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
