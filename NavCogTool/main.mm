//
//  main.m
//  NavCogTool
//
//  Created by Daisuke Sato on 2016/11/08.
//  Copyright © 2016年 Daisuke Sato. All rights reserved.
//

#include <iostream>
#include <getopt.h>

#import <Foundation/Foundation.h>

#import "NavDataStore.h"
#import "NavNavigator.h"
#import "NavCommander.h"
#import "NavPreviewer.h"
#import "LocationEvent.h"

typedef struct {
    std::string fromID = "";
    std::string toID = "";
    std::string configPath = "";
    std::string outputPath = "";
    std::string userID = "NavCogTool";
    std::string userLang = "en";
    double lat;
    double lng;
    double dist = 500;
    BOOL useStairs = NO;
    BOOL useEscalator = NO;
    BOOL useElevator = YES;
}Option;

void printHelp() {
    std::cout << "NavCogTool" << std::endl;
    std::cout << "-h                     print this help" << std::endl;
    std::cout << "-f <string>            from node ID for route search" << std::endl;
    std::cout << "-t <string>            to node ID for route search" << std::endl;
    std::cout << "-p <double>,<double>   lat,lng for init" << std::endl;
    std::cout << "-d <double>            distance for init" << std::endl;
    std::cout << "-u <string>            set user ID" << std::endl;
    std::cout << "-l <string>            set user language" << std::endl;
    std::cout << "-c <string>            config file name" << std::endl;
    std::cout << "-o <string>            set output file path" << std::endl;
    std::cout << "-useStairs [YES|NO]    set useStairs" << std::endl;
    std::cout << "-useEscalator [YES|NO] set useEscalator" << std::endl;
    std::cout << "-useElevator [YES|NO]  set useElevator" << std::endl;
}

Option parseArguments(int argc, char * argv[]){
    Option opt;
    
    int c;
    int option_index = 0;
    struct option long_options[] = {
        {"useStairs",     required_argument, NULL,  0 },
        {"useEscalator",  required_argument, NULL,  0 },
        {"useElevator",   required_argument, NULL,  0 },
        {0,         0,                 0,  0 }
    };
    
    while ((c = getopt_long(argc, argv, "hf:t:p:d:c:u:l:o:", long_options, &option_index )) != -1)
        switch (c)
    {
        case '0':
            if (strcmp(long_options[option_index].name, "useStairs") == 0){
                sscanf(optarg, "%s", &opt.useStairs);
            }
            if (strcmp(long_options[option_index].name, "useEscalator") == 0){
                sscanf(optarg, "%s", &opt.useEscalator);
            }
            if (strcmp(long_options[option_index].name, "useElevator") == 0){
                sscanf(optarg, "%s", &opt.useElevator);
            }
            break;
        case 'h':
            printHelp();
            abort();
        case 'f':
            opt.fromID.assign(optarg);
            break;
        case 't':
            opt.toID.assign(optarg);
            break;
        case 'p':
            sscanf(optarg, "%lf,%lf", &opt.lat, &opt.lng);
            break;
        case 'd':
            sscanf(optarg, "%lf", &opt.dist);
            break;
        case 'c':
            opt.configPath.assign(optarg);
            break;
        case 'u':
            opt.userID.assign(optarg);
            break;
        case 'l':
            opt.userLang.assign(optarg);
            break;
        case 'o':
            opt.outputPath.assign(optarg);
            break;
        default:
            break;
    }
    return opt;
}

@interface NavController: NSObject <NavNavigatorDelegate, NavCommanderDelegate, NavPreviewerDelegate>

@property (readonly) BOOL isActive;

- (void)start:(Option)option;

@end

@implementation NavController {
    NavDataStore *dataStore;
    NavNavigator *navigator;
    NavCommander *commander;
    NavPreviewer *previewer;
    Option opt;
}

- (instancetype) init
{
    self = [super init];
    dataStore = [NavDataStore sharedDataStore];
    navigator = [[NavNavigator alloc] init];
    commander = [[NavCommander alloc] init];
    previewer = [[NavPreviewer alloc] init];
    navigator.delegate = self;
    commander.delegate = self;
    previewer.delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    return self;
}

- (void)start:(Option)_opt
{
    opt = _opt;
    _isActive = YES;
    
    NSString *userID = [NSString stringWithCString:opt.userID.c_str() encoding:NSUTF8StringEncoding];
    NSLog(@"User,%@", userID);
    
    dataStore.userID = userID;
    dataStore.previewMode = YES;
    [dataStore reloadDestinationsAtLat:opt.lat Lng:opt.lng forUser:dataStore.userID withUserLang:dataStore.userLanguage];
}

- (void)destinationChanged:(NSNotification*)note
{
    NSDictionary *prefs = @{
                            @"dist":@"500",
                            @"preset":@"9",
                            @"min_width":@"2",
                            @"slope":@"9",
                            @"road_condition":@"9",
                            @"deff_LV":@"9",
                            @"stairs":opt.useStairs?@"9":@"1",
                            @"esc":opt.useEscalator?@"9":@"1",
                            @"elv":opt.useElevator?@"9":@"1"
                            };

    if (opt.fromID.length() == 0 || opt.toID.length() == 0) {
        NSLog(@"missing fromID(%s) or toID(%s)", opt.fromID.c_str(), opt.toID.c_str());
        exit(-2);
    }
    
    NSString *fromID = [NSString stringWithCString:opt.fromID.c_str() encoding:NSUTF8StringEncoding];
    NSString *toID = [NSString stringWithCString:opt.toID.c_str() encoding:NSUTF8StringEncoding];

    dataStore.from = [dataStore destinationByID:fromID];
    dataStore.to = [dataStore destinationByID:toID];
    
    [dataStore requestRouteFrom:fromID To:toID withPreferences:prefs complete:^{
    }];
}

- (void)locationChanged:(NSNotification*)note
{
    NSDictionary *dict = [note object];
    HLPLocation *current = dict[@"current"];
    NSLog(@"Pose,%f,%f,%f,%f", current.lat, current.lng, current.floor, current.orientation);
}

#pragma mark - NavPreviewerDelegate

- (double)turnAction
{
    return 0;
}
- (BOOL)forwardAction
{
    return NO;
}
- (void)startAction
{
}
- (void)stopAction
{
}


#pragma mark - NavCommanderDelegate

- (void)speak:(NSString *)text force:(BOOL)flag completionHandler:(void (^)())handler
{
    NSLog(@"speak_queue,%@,%@", text, flag?@"Force":@"");
}

- (void)speak:(NSString *)text completionHandler:(void (^)())handler
{
    [self speak:text force:NO completionHandler:handler];
}

- (void)playSuccess
{
}

- (void)executeCommand:(NSString *)command
{
}

#pragma mark - NavNavigatorDelegate

- (void)didActiveStatusChanged:(NSDictionary *)properties
{
    [commander didActiveStatusChanged:properties];
    [previewer didActiveStatusChanged:properties];
    if ([properties[@"isActive"] boolValue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (dataStore.previewMode) {
                [dataStore manualLocationReset:properties];
                
                double delayInSeconds = 2.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [previewer setAutoProceed:YES];
                });
            }
        });
    } else {
        [previewer setAutoProceed:NO];
        _isActive = NO;
    }
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    [commander couldNotStartNavigation:properties];
    [previewer couldNotStartNavigation:properties];
    exit(-3);
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    [commander didNavigationStarted:properties];
    [previewer didNavigationStarted:properties];
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    [commander didNavigationFinished:properties];
    [previewer didNavigationFinished:properties];
    exit(0);
}

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    [commander userNeedsToChangeHeading:properties];
    [previewer userNeedsToChangeHeading:properties];
}
- (void)userAdjustedHeading:(NSDictionary*)properties
{
    [commander userAdjustedHeading:properties];
    [previewer userAdjustedHeading:properties];
}
- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    [commander remainingDistanceToTarget:properties];
    [previewer remainingDistanceToTarget:properties];
}
- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    [commander userIsApproachingToTarget:properties];
    [previewer userIsApproachingToTarget:properties];
}
- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    [commander userNeedsToTakeAction:properties];
    [previewer userNeedsToTakeAction:properties];
}
- (void)userNeedsToWalk:(NSDictionary*)properties
{
    [commander userNeedsToWalk:properties];
    [previewer userNeedsToWalk:properties];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties
{
    [commander userMaybeGoingBackward:properties];
    [previewer userMaybeGoingBackward:properties];
}
- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    [commander userMaybeOffRoute:properties];
    [previewer userMaybeOffRoute:properties];
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    [commander userMayGetBackOnRoute:properties];
    [previewer userMayGetBackOnRoute:properties];
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    [commander userShouldAdjustBearing:properties];
    [previewer userShouldAdjustBearing:properties];
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    [commander userIsApproachingToPOI:properties];
    [previewer userIsApproachingToPOI:properties];
}
- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    [commander userIsLeavingFromPOI:properties];
    [previewer userIsLeavingFromPOI:properties];
}

@end


int main(int argc, char * argv[]) {
    @autoreleasepool {
        //for(int i = 0; i < argc; i++) {
        //    std::cout << argv[i] << std::endl;
        //}
        //NSLog(@"%@", [NSBundle mainBundle]);
        //NSLog(@"%@", NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @""));
        
        Option opt = parseArguments(argc, argv);
        
        if (opt.outputPath.length() > 0) {
            freopen(opt.outputPath.c_str(),"a+",stderr);
        }
        dup2(STDOUT_FILENO, STDERR_FILENO);
        
        NSString *userLang = [NSString stringWithCString:opt.userLang.c_str() encoding:NSUTF8StringEncoding];
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        
        NSString* path = [NSString stringWithCString:opt.configPath.c_str() encoding:NSUTF8StringEncoding];
        NSDictionary* dic = [[NSDictionary alloc] initWithContentsOfFile:path];
        if (!dic) {
            NSLog(@"Config file could not be loaded");
            exit(-1);
        }
        NSLog(@"Config,%@", path);
        for(NSString *key in dic) {
            [ud setObject:dic[key] forKey:key];
        }
        // set language for i18n
        [ud setObject:@[userLang] forKey:@"AppleLanguages"];
        [ud setObject:userLang forKey:@"AppleLocale"];
        
        NSLog(@"Language,%@", userLang);
        
        [ud synchronize];

        NavController *controller = [[NavController alloc] init];
        [controller start:opt];

        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}

