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

#import "InitViewController.h"
#import "ConfigManager.h"
#import "LocationManager.h"
#import "NavUtil.h"

@interface InitViewController ()

@end

@implementation InitViewController {
    BOOL isAvailable;
}

- (void)viewDidLoad {
    [super viewDidLoad];

}

- (void) viewWillLayoutSubviews
{
    [self checkServerSettingFile];
    
    NSString *server = [[NSUserDefaults standardUserDefaults] valueForKey:@"selected_hokoukukan_server"];
    if (server && [server length] > 0) {
        isAvailable = YES;
    } else {
        isAvailable = NO;
        CGRect wf = self.view.window.frame;
        UIView *cover = [[UIView alloc] initWithFrame:wf];
        cover.backgroundColor = UIColor.whiteColor;
        CGRect frame = CGRectMake(0, wf.size.height/2-25, wf.size.width, 50);
        UILabel *label = [[UILabel alloc] initWithFrame:frame];
        label.numberOfLines = 2;
        label.textAlignment = NSTextAlignmentCenter;
        label.text = NSLocalizedString(@"NOT_AVAILABLE", @"");
        [cover addSubview:label];
        
        frame = CGRectMake(wf.size.width/2-20, wf.size.height/2+25, 40, 40);
        UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoLight];
        button.frame = frame;
        [button addTarget:self action:@selector(infoButtonPushed:) forControlEvents:UIControlEventTouchUpInside];
        
        [cover addSubview:button];
        [self.view addSubview:cover];
    }
}

- (void)checkServerSettingFile
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];

    NSString* serverSetting = [documentsPath stringByAppendingPathComponent:@"server.txt"];

    if ([fm fileExistsAtPath:serverSetting]) {
        NSError *error;
        NSString *server = [[NSString alloc] initWithContentsOfFile:serverSetting encoding:NSUTF8StringEncoding error:&error];
        
        server = [server stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [[NSUserDefaults standardUserDefaults] setObject:server forKey:@"selected_hokoukukan_server"];
    }
    
}
- (void)infoButtonPushed:(NSObject*)sender
{
    NSURL *url = [NSURL URLWithString:@"https://hulop.github.io/"];
    [NavUtil openURL:url onViewController:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (isAvailable && UIAccessibilityIsVoiceOverRunning()) {
        [self performSegueWithIdentifier:@"user_blind" sender:self];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    return isAvailable;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"user_blind"]) {
        [ConfigManager loadConfig:@"presets/blind.plist"];
    }
    else if ([segue.identifier isEqualToString:@"user_wheelchair"]) {
        [ConfigManager loadConfig:@"presets/wheelchair.plist"];
    }
    else if ([segue.identifier isEqualToString:@"user_general"]) {
        [ConfigManager loadConfig:@"presets/general.plist"];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:segue.identifier forKey:@"user_mode"];
    
    LocationManager *manager = [LocationManager sharedManager];
    manager.isReadyToStart = YES;
    [manager start];

}


@end
