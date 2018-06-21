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
#import <ARKit/ARKit.h>
#import "HLPPoint3D.h"
#import "HLPBeaconSample.h"

#define IRTCF_DEBUG NO
@protocol HLPBeaconSamplerDelegate <NSObject>

@required
- (void)updated;
- (void)qrCodeDetected:(CIQRCodeFeature*)message;
- (void)arPositionUpdated:(SCNVector3)position;
@optional

@end

@interface HLPBeaconSampler : NSObject <CLLocationManagerDelegate, ARSCNViewDelegate>{
    CLLocationManager *locationManager;
    
    CLBeaconRegion *allBeacons;
    NSString *collectionName;
    
    BOOL recording;
    BOOL pauseing;
    BOOL isStartRecording;
    
    HLPPoint3D *lastLocation;
}

@property (nonatomic, assign) id<HLPBeaconSamplerDelegate> delegate;
@property (nonatomic, readonly) NSArray* visibleBeacons;
@property BOOL ARKitEnabled;
@property (nullable, readonly) ARSCNView *view;
@property (readonly) HLPBeaconSamples* samples;
@property double qrCodeInterval;

+ (HLPBeaconSampler *)sharedInstance;

- (void) setSamplingBeaconUUID:(NSString*)uuid_str;
- (void) setSamplingLocation:(HLPPoint3D *)point;

- (void) reset;
- (BOOL) startRecording;
- (void) stopRecording;

- (NSArray*) toJSON:(NSDictionary*)optionalInfo;
- (long) visibleBeaconCount;
- (long) beaconSampleCount;
- (BOOL) isRecording;

- (void) transform2D:(CGAffineTransform)param;
@end
