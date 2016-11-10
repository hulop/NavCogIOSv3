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
    BOOL listDestinations = NO;
    std::string filter = "";
    BOOL combinations = NO;
}Option;

void printHelp() {
    std::cout << "NavCogTool" << std::endl;
    std::cout << "-h                     print this help" << std::endl;
    std::cout << "--list                 print all destinations" << std::endl;
    std::cout << "--filter <json>        filter destinations" << std::endl;
    std::cout << "--combinations         output all combinations of destinations" << std::endl;
    std::cout << "-f <string>            from node ID for route search" << std::endl;
    std::cout << "-t <string>            to node ID for route search" << std::endl;
    std::cout << "-p <double>,<double>   lat,lng for init" << std::endl;
    std::cout << "-d <double>            distance for init" << std::endl;
    std::cout << "-u <string>            set user ID" << std::endl;
    std::cout << "-l <string>            set user language" << std::endl;
    std::cout << "-c <string>            config file name" << std::endl;
    std::cout << "-o <string>            set output file path" << std::endl;
    std::cout << "--useStairs [1|0]      set useStairs" << std::endl;
    std::cout << "--useEscalator [1|0]   set useEscalator" << std::endl;
    std::cout << "--useElevator [1|0]    set useElevator" << std::endl;
}

Option parseArguments(int argc, char * argv[]){
    Option opt;
    
    int c;
    int option_index = 0;
    int boolean;
    struct option long_options[] = {
        {"list",          no_argument, NULL,  0 },
        {"filter",        required_argument, NULL,  0 },
        {"combinations",  no_argument, NULL,  0 },
        {"useStairs",     required_argument, NULL,  0 },
        {"useEscalator",  required_argument, NULL,  0 },
        {"useElevator",   required_argument, NULL,  0 },
        {0,         0,                 0,  0 }
    };
    
    while ((c = getopt_long(argc, argv, "hf:t:p:d:c:u:l:o:", long_options, &option_index )) != -1)
        switch (c)
    {
        case 0:
            if (strcmp(long_options[option_index].name, "useStairs") == 0){
                sscanf(optarg, "%d", &boolean);
                opt.useStairs = boolean;
            }
            if (strcmp(long_options[option_index].name, "useEscalator") == 0){
                sscanf(optarg, "%d", &boolean);
                opt.useEscalator = boolean;
            }
            if (strcmp(long_options[option_index].name, "useElevator") == 0){
                sscanf(optarg, "%d", &boolean);
                opt.useElevator = boolean;
            }
            if (strcmp(long_options[option_index].name, "list") == 0){
                opt.listDestinations = YES;
            }
            if (strcmp(long_options[option_index].name, "filter") == 0){
                opt.filter.assign(optarg);
                std::cout << opt.filter << std::endl;
            }
            if (strcmp(long_options[option_index].name, "combinations") == 0){
                opt.combinations = YES;
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
    
    NSArray *fromToList;
    NSTimer *timeoutTimer;
    NSDictionary *processing;
    int countDown;
}

- (instancetype) init
{
    self = [super init];
    dataStore = [NavDataStore sharedDataStore];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)start:(Option)_opt
{
    opt = _opt;
    _isActive = YES;
    
    NSString *userID = [NSString stringWithCString:opt.userID.c_str() encoding:NSUTF8StringEncoding];
    NSLog(@"User,%@", userID);
    
    dataStore.userID = userID;
    [dataStore reloadDestinationsAtLat:opt.lat Lng:opt.lng forUser:dataStore.userID withUserLang:dataStore.userLanguage];
}

- (void)destinationChanged:(NSNotification*)note
{
    if (dataStore.destinations == nil) {
        std::cerr << "Could not load destinations" << std::endl;
        exit(10);
    }
    if (opt.listDestinations) {
        NSDictionary *filter = nil;
        if(opt.filter.length() > 0) {
            NSError *error;
            NSData *data = [NSData dataWithBytes:opt.filter.c_str() length:opt.filter.length()];
            filter = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                std::cerr << "Could not parse filter \"" << opt.filter << "\"" << std::endl;
                std::cerr << [error.localizedDescription UTF8String] << std::endl;
                exit(11);
            }
        }
        NSArray *list = [dataStore.destinations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HLPLandmark* l, NSDictionary<NSString *,id> * _Nullable bindings) {
            if (filter == nil) {
                return YES;
            }
            BOOL flag = YES;
            for(NSString *key in filter.allKeys) {
                flag = flag && [l.properties[key] isEqualToString:filter[key]];
            }
            return flag;
        }]];
        for(HLPLandmark *l in list) {
            std::cout << [l.nodeID UTF8String];
            std::cout << "\t";
            std::cout << [l.getLandmarkName UTF8String];
            std::cout << std::endl;
            //std::cout << [l.description UTF8String];
            //std::cout << std::endl;
        }
        
        if (opt.combinations) {
            NSString *dir = @".";
            if (opt.outputPath.length() > 0) {
                dir = [NSString stringWithFormat:@"%s", opt.outputPath.c_str()];
                NSError *error;
                BOOL isDir;
                if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
                    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir
                                                   withIntermediateDirectories:NO
                                                                    attributes:nil
                                                                         error:&error])
                    {
                        std::cout << "Create directory error: " << [error.localizedDescription UTF8String] << std::endl;
                        exit(1);
                    }
                } else if(isDir == NO) {
                    std::cout << "Path is not directory: " << opt.outputPath << std::endl;
                    exit(2);
                }
            }
            NSMutableArray *temp = [@[] mutableCopy];
            for(HLPLandmark* l1 in list) {
                for(HLPLandmark* l2 in list) {
                    if ([l1 isEqual:l2]) {
                        continue;
                    }
                    [temp addObject:@{
                                      @"from":l1.nodeID,
                                      @"to":l2.nodeID,
                                      @"file":[NSString stringWithFormat:@"%@/%@-%@.log", dir, l1.nodeID, l2.nodeID]
                                      }];
                }
            }
            fromToList = temp;
        }
    } else {
        NSString *fromID = [NSString stringWithCString:opt.fromID.c_str() encoding:NSUTF8StringEncoding];
        NSString *toID = [NSString stringWithCString:opt.toID.c_str() encoding:NSUTF8StringEncoding];
        if (opt.outputPath.length() > 0) {
            fromToList = @[@{@"from":fromID, @"to":toID, @"file":[NSString stringWithCString:opt.outputPath.c_str() encoding:NSUTF8StringEncoding]}];
        }
        else {
            fromToList = @[@{@"from":fromID, @"to":toID}];
        }
    }

    [self processOne];
}

-(void) processOne
{
    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self _processOne];
    }];
}

- (void) _processOne
{
    if (processing) {
        return;
    }
    
    if ([fromToList count] > 0) {
        int index = arc4random_uniform((int)[fromToList count]);
        
        processing = fromToList[index];
        
        if (timeoutTimer) {
            std::cout << std::endl;
            [timeoutTimer invalidate];
        }
        std::cout << [processing[@"from"] UTF8String] << "-" << [processing[@"to"] UTF8String] << "-";
        fflush(stdout);
        
        countDown = 20;
    
        __block __weak NavPreviewer *weakPreviewer = previewer;
        __block __weak NavController *weakSelf = self;
        timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            if (countDown <= 0) {
                std::cout << "Timeout";
                fflush(stdout);
                if ([fromToList count] == 0) {
                    std::cout << std::endl;
                    exit(6);
                }
                [timer invalidate];
                timeoutTimer = nil;
                [weakPreviewer setAutoProceed:NO];
                [weakSelf processDone];
                [weakSelf processOne];
            } else {
                countDown--;
                std::cout << ".";
                fflush(stdout);
            }
        }];
        
        dataStore.previewMode = YES;
        [self navigationFrom:processing[@"from"] To:processing[@"to"] File:processing[@"file"]];
        
        fromToList = [fromToList mtl_arrayByRemovingObject:processing];
    } else {
        exit(0);
    }
}

- (void) processDone
{
    @autoreleasepool {
        processing = nil;
        navigator.delegate = nil;
        navigator = nil;
        commander.delegate = nil;
        commander = nil;
        previewer.delegate = nil;
        [previewer setAutoProceed:NO];
        previewer = nil;
    }
}

-(void) navigationFrom:(NSString*)fromID To:(NSString*)toID File:(NSString*)filename
{
    navigator = [[NavNavigator alloc] init];
    commander = [[NavCommander alloc] init];
    previewer = [[NavPreviewer alloc] init];
    navigator.delegate = self;
    commander.delegate = self;
    previewer.delegate = self;
    
    if (filename) {
        freopen([filename UTF8String], "w", stderr);
    }

    NSDictionary *prefs = @{
                            @"dist":@"500",
                            @"preset":@"9",
                            @"min_width":@"8",
                            @"slope":@"9",
                            @"road_condition":@"9",
                            @"deff_LV":@"9",
                            @"stairs":opt.useStairs?@"9":@"1",
                            @"esc":opt.useEscalator?@"9":@"1",
                            @"elv":opt.useElevator?@"9":@"1"
                            };

    if (!fromID || !toID || [fromID length] == 0 || [toID length] == 0) {
        NSLog(@"missing fromID(%@) or toID(%@)", fromID, toID);
        exit(3);
    }
    
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
    
    NSLog(@"Navigation,%@,%@",dataStore.from.name,dataStore.to.name);
    if ([properties[@"isActive"] boolValue]) {
        __block __weak NavPreviewer *weakPreviewer = previewer;
        if (dataStore.previewMode) {
            [dataStore manualLocationReset:properties];
            
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [weakPreviewer setAutoProceed:YES];
            });
        }
    } else {
        [previewer setAutoProceed:NO];
        _isActive = NO;
    }
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    [commander couldNotStartNavigation:properties];
    [previewer couldNotStartNavigation:properties];
    std::cout << [properties[@"reason"] UTF8String];
    if ([fromToList count] == 0) {
        std::cout << std::endl;
        exit(4);
    }
    [self processDone];
    [self processOne];
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
    [self processDone];
    [self processOne];
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
        
        NSString *userLang = [NSString stringWithCString:opt.userLang.c_str() encoding:NSUTF8StringEncoding];
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        
        NSString* path = [NSString stringWithCString:opt.configPath.c_str() encoding:NSUTF8StringEncoding];
        NSDictionary* dic = [[NSDictionary alloc] initWithContentsOfFile:path];
        if (!dic) {
            std::cout << "Config file could not be loaded" << std::endl;
            exit(5);
        }
        NSLog(@"Config,%@", path);
        for(NSString *key in dic) {
            [ud setObject:dic[key] forKey:key];
        }
        // set language for i18n
        [ud setObject:@[userLang] forKey:@"AppleLanguages"];
        [ud setObject:userLang forKey:@"AppleLocale"];
        [ud setObject:@(100) forKey:@"preview_speed"];
        
        NSLog(@"Language,%@", userLang);
        
        [ud synchronize];

        NavController *controller = [[NavController alloc] init];
        [controller start:opt];

        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}

