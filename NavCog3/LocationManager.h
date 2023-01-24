//
//  LocationManager.h
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/24.
//  Copyright © 2023 HULOP. All rights reserved.
//

#ifndef LocationManager_h
#define LocationManager_h

#import <Foundation/Foundation.h>
#import <HLPLocationManager/HLPLocationManager.h>

@interface LocationManager: NSObject <HLPLocationManagerDelegate>

+ (instancetype)sharedManager;

- (void)setup;

@end

#endif /* LocationManager_h */
