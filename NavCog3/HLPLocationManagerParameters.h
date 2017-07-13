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

#import <bleloc/BasicLocalizer.hpp>

#ifndef HLPLocationManagerParameters_h
#define HLPLocationManagerParameters_h

typedef NS_ENUM(NSInteger, HLPLocationManagerRepLocation) {
    HLPLocationManagerRepLocationMean,
    HLPLocationManagerRepLocationDensest,
    HLPLocationManagerRepLocationClosestMean
};

@interface HLPLocationManagerLocation : NSObject
@property double x;
@property double y;
@property double z;
@property double floor;
@end

@interface HLPLocationManagerPoseProperty : NSObject
@property double meanVelocity;
@property double stdVelocity;
@property double diffusionVelocity;
@property double minVelocity;
@property double maxVelocity;
@property double stdOrientation;
@end

@interface HLPLocationManagerStateProperty : NSObject
@property double meanRssiBias;
@property double stdRssiBias;
@property double diffusionRssiBias;
@property double diffusionOrientationBias;
@property double minRssiBias;
@property double maxRssiBias;
@end

@interface HLPLocationManagerFloorTransitionParameters : NSObject
@property double heightChangedCriterion;
@property double weightTransitionArea;
@property double mixtureProbaTransArea;
@property double rejectDistance;
@end

@interface HLPLocationManagerLocationStatusMonitorParameters : NSObject
@property double minimumWeightStable;
@property double stdev2DEnterStable;
@property double stdev2DExitStable;
//@property double stdevFloorEnterStable;
@property double stdev2DEnterLocating;
@property double stdev2DExitLocating;
@property long monitorIntervalMS;
@end

@interface HLPLocationManagerSystemModelInBuildingProperty : NSObject
@property double probabilityUpStair;
@property double probabilityDownStair;
@property double probabilityStayStair;
@property double probabilityUpElevator;
@property double probabilityDownElevator;
@property double probabilityStayElevator;
@property double probabilityUpEscalator;
@property double probabilityDownEscalator;
@property double probabilityStayEscalator;
@property double probabilityFloorJump;
@property double wallCrossingAliveRate;
@property double maxIncidenceAngle;
// Field velocity rate
@property double velocityRateFloor;
@property double velocityRateStair;
@property double velocityRateElevator;
@property double velocityRateEscalator;
@property double relativeVelocityEscalator;
@property double weightDecayRate;
@property (readonly) int maxTrial;
@end

@interface HLPLocationManagerParameters : NSObject

- (instancetype) initWithTarget:(HLPLocationManager*)target;

@property (readonly) HLPLocationManager* target;

- (void)updateWithDictionary:(NSDictionary*)dict;
- (NSDictionary*)toDictionary;

@property int nStates;
@property double alphaWeaken;
@property int nSmooth;
@property int nSmoothTracking;
@property loc::SmoothType smoothType;
@property loc::LocalizeMode localizeMode;

@property double effectiveSampleSizeThreshold;
@property int nStrongest;
@property bool enablesFloorUpdate;

@property double walkDetectSigmaThreshold;
@property double meanVelocity;
@property double stdVelocity;
@property double diffusionVelocity;
@property double minVelocity;
@property double maxVelocity;

@property double stdRssiBias;
@property double diffusionRssiBias;
@property double stdOrientation;
@property double diffusionOrientationBias;

@property double angularVelocityLimit;
// Parametes for PoseRandomWalker
@property bool doesUpdateWhenStopping;

@property double maxIncidenceAngle;
@property double weightDecayHalfLife;

// Parameters for RandomWalkerMotion and WeakPoseRandomWalker
@property double sigmaStop;
@property double sigmaMove;

// Parameters for SystemModelInBuilding
@property double velocityRateFloor;
@property double velocityRateElevator;
@property double velocityRateStair;
@property double velocityRateEscalator;
@property double relativeVelocityEscalator;

// Parameters for WeakPoseRandomWalker
@property double probabilityOrientationBiasJump;
@property double poseRandomWalkRate;
@property double randomWalkRate;
@property double probabilityBackwardMove;

@property int nBurnIn;
@property int burnInRadius2D;
@property int burnInInterval;
@property loc::InitType burnInInitType;

@property double mixProba;
@property double rejectDistance;
@property double rejectFloorDifference;
@property int nBeaconsMinimum;

@property (readonly) HLPLocationManagerLocation *locLB;
//@property Location locLB{0.5, 0.5, 1e-6, 1e-6};

@property bool usesAltimeterForFloorTransCheck;
@property double coeffDiffFloorStdev;

@property loc::OrientationMeterType orientationMeterType;


// parameter objects
@property (readonly) HLPLocationManagerPoseProperty *poseProperty;
//@property loc::PoseProperty::Ptr poseProperty;// = std::make_shared<PoseProperty>();
@property (readonly) HLPLocationManagerStateProperty *stateProperty;
//@property loc::StateProperty::Ptr stateProperty;// = std::make_shared<StateProperty>();

@property (readonly) HLPLocationManagerFloorTransitionParameters *pfFloorTransParams;
//@property loc::StreamParticleFilter::FloorTransitionParameters::Ptr pfFloorTransParams;// = std::make_shared<StreamParticleFilter::FloorTransitionParameters>();
@property (readonly) HLPLocationManagerLocationStatusMonitorParameters *locationStatusMonitorParameters;
//@property loc::LocationStatusMonitorParameters::Ptr locationStatusMonitorParameters;// = std::make_shared<LocationStatusMonitorParameters>();
@property (readonly) HLPLocationManagerSystemModelInBuildingProperty *prwBuildingProperty;
//@property loc::SystemModelInBuildingProperty::Ptr prwBuildingProperty;// = std::make_shared<SystemModelInBuildingProperty>();


@property HLPLocationManagerRepLocation repLocation;
@property double meanRssiBias;
@property double minRssiBias;
@property double maxRssiBias;
@property double headingConfidenceForOrientationInit;

@property BOOL accuracyForDemo;
@property BOOL usesBlelocppAcc;
@property double blelocppAccuracySigma;

@property double oriAccThreshold;

@property BOOL showsStates;
@property BOOL usesCompass;

@end


#endif /* HLPLocationManagerParameters_h */
