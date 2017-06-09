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


#import "FPTabBarController.h"
#import "BlindViewController.h"
#import "ConfigManager.h"
#import "ServerConfig+FingerPrint.h"

@interface FPTabBarController ()

@end

@implementation FPTabBarController {    
    UINavigationController *b1, *b2, *b3;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSUserDefaults standardUserDefaults] setObject:@"UI_BLIND" forKey:@"ui_mode"];
    [ConfigManager loadConfig:@"presets/blind.plist"];
    
    b1 = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"blind_ui_navigation"];
    ((BlindViewController*)b1.topViewController).fp_mode = FPModeFingerprint;
    b2 = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"blind_ui_navigation"];
    ((BlindViewController*)b2.topViewController).fp_mode = FPModeBeacon;
    b3 = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"blind_ui_navigation"];
    ((BlindViewController*)b3.topViewController).fp_mode = FPModePOI;
    
}

- (void) viewDidAppear:(BOOL)animated
{
    if ([[ServerConfig sharedConfig] isMapEditorKeyAvailable]) {
        [self setViewControllers:@[b1, b2, b3]];
    } else {
        [self setViewControllers:@[b1, b2]];
    }
    
    self.tabBar.items[0].title = @"FingerPrint";
    self.tabBar.items[0].image = [UIImage imageNamed:@"fingerprint"];
    self.tabBar.items[1].title = @"Beacon";
    self.tabBar.items[1].image = [UIImage imageNamed:@"beacon"];
    
    if ([[ServerConfig sharedConfig] isMapEditorKeyAvailable]) {
        self.tabBar.items[2].title = @"POI";
        self.tabBar.items[2].image = [UIImage imageNamed:@"poi"];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)viewWillAppear:(BOOL)animated
{

}



@end
