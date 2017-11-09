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


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CoreMotion.h>
#import "core/Status.hpp"
#import "core/BLEBeacon.hpp"
#import "core/LatLngConverter.hpp"
#import "LocationEvent.h"
#import "RBManager.h"
#import "RBSubscriber.h"

#import "HeaderMessage.h"

#import "encoderMessage.h"

//encoder from ROS encoder.msg

/*@interface encoderTime : RBMessage {
    long * sec;
    long * nsec;
}

@property (nonatomic) long* sec;
@property (nonatomic) long* nsec;

@end

@interface encoderHeader : RBMessage {
    int * seq;
    encoderTime * time;
    NSString * frameid;
    
}

@property (nonatomic) int * seq;
@property (nonatomic) encoderTime * time;
@property (nonatomic) NSString * frameid;

@end*/

/*@interface encoderMessage : RBMessage {
    NSNumber * speed;
    HeaderMessage * header;
}

@property (nonatomic, strong) NSNumber * speed;
@property (nonatomic, strong) HeaderMessage * header;

@end*/


//END encoder from ROS encoder.msg

@interface LocationManager : NSObject < CLLocationManagerDelegate >


@property BOOL isReadyToStart;
@property BOOL isActive;
@property NavLocationStatus currentStatus;

- (instancetype) init NS_UNAVAILABLE;
+ (instancetype) sharedManager;
- (void) start;
// - (void) stop; // no need to stop anymore
- (void) setModelAtPath:(NSString*) path withWorkingDir:(NSString*) dir;
- (void) getRssiBias:(NSDictionary*)param withCompletion:(void (^)(float rssiBias)) completion;
- (loc::LatLngConverter::Ptr) getProjection;


@property RBSubscriber * ROSEncoderSubscriber; //Rbmanager encoder
-(void)EncoderUpdate:(encoderMessage*)encoder; //will send the encoder info to localizer

@end



