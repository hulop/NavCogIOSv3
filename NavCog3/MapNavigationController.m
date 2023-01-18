//
//  MapNavigationController.m
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/10.
//  Copyright © 2023 HULOP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HLPLocationManager/HLPLocationManager.h>
#import <HLPLocationManager/HLPLocationManagerParameters.h>
#import "MapNavigationController.h"
#import "NavDataStore.h"
#import "NavUtil.h"

@implementation MapNavigationController

- (void)dealloc
{
    NSLog(@"%s: %d" , __func__, __LINE__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NavDataStore sharedDataStore] setUpHLPLocationManager];
}

@end
