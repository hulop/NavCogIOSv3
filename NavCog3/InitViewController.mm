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
#import "HLPLocationManager.h"
#import "NavUtil.h"
#import "ServerConfig.h"
#import "AuthManager.h"
#import "HLPLocationManagerParameters.h"

@interface InitViewController ()

@end

@implementation InitViewController {
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void) updateView
{
    self.blindButton.enabled = NO;
    //self.wcButton.enabled = NO;
    //self.gpButton.enabled = NO;
    
    NSDictionary *config = [ServerConfig sharedConfig].selectedServerConfig;
    
    if (config[@"key_for_blind"]) {
        BOOL blind_authorized = [[AuthManager sharedManager] isAuthorizedForName:@"blind" withKey:config[@"key_for_blind"]];
        self.blindButton.enabled = blind_authorized;
    } else {
        self.blindButton.enabled = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    NSDictionary *config = [ServerConfig sharedConfig].selectedServerConfig;
    if (config[@"default_mode"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:config[@"default_mode"] sender:self];
        });
    }
}


- (void)infoButtonPushed:(NSObject*)sender
{
    NSURL *url = [NSURL URLWithString:@"https://hulop.github.io/"];
    [NavUtil openURL:url onViewController:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"user_blind"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_BLIND" forKey:@"ui_mode"];
        [ConfigManager loadConfig:@"presets/blind.plist"];
    }
    else if ([segue.identifier isEqualToString:@"user_wheelchair"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_WHEELCHAIR" forKey:@"ui_mode"];
        [ConfigManager loadConfig:@"presets/wheelchair.plist"];
    }
    else if ([segue.identifier isEqualToString:@"user_general"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@"UI_WHEELCHAIR" forKey:@"ui_mode"];
        [ConfigManager loadConfig:@"presets/general.plist"];
    }
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:segue.identifier forKey:@"user_mode"];
    
    HLPLocationManager *manager = [HLPLocationManager sharedManager];
    
    NSString *modelName = [ud stringForKey:@"bleloc_map_data"];
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString* modelPath = [documentsPath stringByAppendingPathComponent:modelName];
    [manager setModelPath:modelPath];
    
    NSDictionary *params = [self getLocationManagerParams];
    [manager setParameters:params];
    
    [manager start];
}

- (NSDictionary*) getLocationManagerParams
{
    NSMutableDictionary *params = [@{} mutableCopy];
    
    NSDictionary *nameTable =
    @{//custom
      @"location_tracking": @"localizeMode",
      @"rssi_bias":         @"rssi_bias",
      @"locLB":             @"locLB",
      @"activatesStatusMonitoring":@"activatesStatusMonitoring",
      @"rep_location":      @"repLocation",
      //
      @"nStates":           @"nStates",
      @"nEffective":        @"effectiveSampleSizeThreshold",
      @"alphaWeaken":       @"alphaWeaken",
      @"nSmooth":           @"nSmooth",
      @"nSmoothTracking":   @"nSmoothTracking",
      @"wheelchair_pdr":    @"walkDetectSigmaThreshold",
      @"meanVelocity":      @"meanVelocity",
      @"stdVelocity":       @"stdVelocity",
      @"diffusionVelocity": @"diffusionVelocity",
      @"minVelocity":       @"minVelocity",
      @"maxVelocity":       @"maxVelocity",
      @"diffusionOrientationBias":@"diffusionOrientationBias",
      @"weightDecayHalfLife":@"weightDecayHalfLife",
      @"sigmaStopRW":       @"sigmaStop",
      @"sigmaMoveRW":       @"sigmaMove",
      @"relativeVelocityEscalator":@"relativeVelocityEscalator",
      @"nStates":           @"nBurnIn",
      @"mixProba":          @"mixProba",
      @"rejectDistance":    @"rejectDistance",
      @"rejectFloorDifference":@"rejectFloorDifference",
      @"nBeaconsMinimum":   @"nBeaconsMinimum",
      @"probaOriBiasJump":  @"probabilityOrientationBiasJump",
      @"poseRandomWalkRate":@"poseRandomWalkRate",
      @"randomWalkRate":    @"randomWalkRate",
      @"probaBackwardMove": @"probabilityBackwardMove",
      @"floorLB":           @"locLB.floor",
      @"coeffDiffFloorStdev":@"coeffDiffFloorStdev",
      @"use_altimeter":     @"usesAltimeterForFloorTransCheck",
      @"weightFloorTransArea":@"pfFloorTransParams.weightTransitionArea",
      @"mixtureProbabilityFloorTransArea":@"pfFloorTransParams.mixtureProbaTransArea",
      @"headingConfidenceInit":@"headingConfidenceForOrientationInit",
      
      @"accuracy_for_demo": @"accuracyForDemo",
      @"use_blelocpp_acc":  @"usesBlelocppAcc",
      @"blelocpp_accuracy_sigma":@"blelocppAccuracySigma",
      @"oriAccThreshold":   @"oriAccThreshold",
      @"show_states":       @"showsStates",
      @"use_compass":       @"usesCompass",
      };
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    [nameTable enumerateKeysAndObjectsUsingBlock:^(NSString *from, NSString *to, BOOL * _Nonnull stop) {
        
        NSObject *value;
        
        if ([from isEqualToString:@"location_tracking"]) {
            NSString *location_tracking = [ud stringForKey:from];
            if ([location_tracking isEqualToString:@"tracking"]) {
                value = @(loc::RANDOM_WALK_ACC_ATT);
            } else if([location_tracking isEqualToString:@"oneshot"]) {
                value = @(loc::ONESHOT);
            } else if([location_tracking isEqualToString:@"randomwalker"]) {
                value = @(loc::RANDOM_WALK_ACC);
            } else if([location_tracking isEqualToString:@"weak_pose_random_walker"]) {
                value = @(loc::WEAK_POSE_RANDOM_WALKER);
            }
        }
        else if ([from isEqualToString:@"activatesStatusMonitoring"]) {
            bool activatesDynamicStatusMonitoring = [ud boolForKey:@"activatesStatusMonitoring"];
            if(activatesDynamicStatusMonitoring){
                double minWeightStable = std::pow(10.0, [ud doubleForKey:@"exponentMinWeightStable"]);
                params[@"locationStatusMonitorParameters.minimumWeightStable"] = @(minWeightStable);
                params[@"locationStatusMonitorParameters.stdev2DEnterStable"] = ([ud valueForKey:@"enterStable"]);
                params[@"locationStatusMonitorParameters.stdev2DExitStable"] = ([ud valueForKey:@"exitStable"]);
                params[@"locationStatusMonitorParameters.stdev2DEnterLocating"] = ([ud valueForKey:@"enterLocating"]);
                params[@"locationStatusMonitorParameters.stdev2DExitLocating"] = ([ud valueForKey:@"exitLocating"]);
                params[@"locationStatusMonitorParameters.monitorIntervalMS"] = ([ud valueForKey:@"statusMonitoringIntervalMS"]);
            }else{
                params[@"locationStatusMonitorParameters.minimumWeightStable"] = @(0.0);
                NSNumber *largeStdev = @(10000);
                params[@"locationStatusMonitorParameters.stdev2DEnterStable"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DExitStable"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DEnterLocating"] = largeStdev;
                params[@"locationStatusMonitorParameters.stdev2DExitLocating"] = largeStdev;
                params[@"locationStatusMonitorParameters.monitorIntervalMS"] = @(3600*1000);
            }
            return;
        }
        else if ([from isEqualToString:@"wheelchair_pdr"]) {
            value = @([ud boolForKey:@"wheelchair_pdr"]?0.1:0.6);
        }
        else if ([from isEqualToString:@"locLB"]) {
            value = [ud valueForKey:@"locLB"];
            params[@"locLB.x"] = value;
            params[@"locLB.y"] = value;
            return;
        }
        else if ([from isEqualToString:@"rssi_bias"]) {
            double rssiBias = [ud doubleForKey:@"rssi_bias"];
            if([ud boolForKey:@"rssi_bias_model_used"]){
                // check device and update rssi_bias
                NSString *deviceName = [NavUtil deviceModel];
                NSString *configKey = [@"rssi_bias_m_" stringByAppendingString:deviceName];
                rssiBias = [ud floatForKey:configKey];
            }
            params[@"minRssiBias"] = @(rssiBias-0.1);
            params[@"maxRssiBias"] = @(rssiBias+0.1);
            params[@"meanRssiBias"] = @(rssiBias);
            return;
        }
        else if ([from isEqualToString:@"rep_location"]) {
            NSString *rep_location = [ud stringForKey:@"rep_location"];
            if([rep_location isEqualToString:@"mean"]){
                value = @(HLPLocationManagerRepLocationMean);
            }else if([rep_location isEqualToString:@"densest"]){
                value = @(HLPLocationManagerRepLocationDensest);
            }else if([rep_location isEqualToString:@"closest_mean"]){
                value = @(HLPLocationManagerRepLocationClosestMean);
            }
        }
        else {
            value = [ud valueForKey:from];
        }

        params[to] = value;

    }];
    
    return params;
}


@end
