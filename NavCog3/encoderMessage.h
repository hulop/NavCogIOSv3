//
//  encoderMessage.h
//  NavCog3
//
//  Created by Shangxuan Wu on 11/9/17.
//  Copyright © 2017 HULOP. All rights reserved.
//

#import "RBManager.h"
#import "RBSubscriber.h"

#import "HeaderMessage.h"

#ifndef encoderMessage_h
#define encoderMessage_h

#endif /* encoderMessage_h */


@interface encoderMessage : RBMessage {
    NSNumber * speed;
    HeaderMessage * header;
}

@property (nonatomic, strong) NSNumber * speed;
@property (nonatomic, strong) HeaderMessage * header;

@end
