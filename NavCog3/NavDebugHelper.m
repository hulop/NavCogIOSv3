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

#import "NavDebugHelper.h"
#import "LocationEvent.h"
#import "NavDeviceTTS.h"

#import <CoreLocation/CoreLocation.h>
#import <sys/sysctl.h>

@implementation NavDebugHelper {
    NSMutableDictionary *_lastSent;
}

static NavDebugHelper* instance;

+ (instancetype)sharedHelper
{
    if (!instance) {
        instance = [[NavDebugHelper alloc] init];
    }
    return instance;
}

- (instancetype)init
{
    self = [super init];
    _peers = [@[] mutableCopy];
    _lastSent = [@{} mutableCopy];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:) name:REQUEST_PROCESS_SHOW_ROUTE object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:) name:SPEAK_TEXT_QUEUEING object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:) name:ROUTE_CLEARED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData:) name:PLAY_SYSTEM_SOUND object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processData2:) name:REQUEST_LOCATION_HEADING_RESET object:nil];

    
    
    return self;
}

- (void) processData:(NSNotification*)note
{
    NSString *name = [note name];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if ([name isEqualToString:NAV_LOCATION_CHANGED_NOTIFICATION] && _lastSent[name]) {
        if (now - [_lastSent[name] doubleValue] < 0.2) {
            return;
        }
    }
    _lastSent[name] = @([[NSDate date] timeIntervalSince1970]);

    NSDictionary *userInfo = [note userInfo];

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:
                    @{
                      @"name": name,
                      @"timestamp": @([[NSDate date] timeIntervalSince1970]),
                      @"userInfo": userInfo?userInfo:[NSNull null]
                      }];
    if (data) {
        [self sendData:data];
    }
}

- (void) processData2:(NSNotification*)note
{
    return;
}

- (void) start
{
    NSString *name = [[UIDevice currentDevice] name];
    _peerID = [[MCPeerID alloc] initWithDisplayName:name];
    
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = self;
    
    _assistant = [[MCAdvertiserAssistant alloc] initWithServiceType:NAVCOG3_DEBUG_SERVICE_TYPE
                                                      discoveryInfo:nil
                                                            session:_session];
    [_assistant start];
}

- (void)sendData:(NSData *)data
{
    NSError *error;
    
    if ([_peers count] > 0) {
        [_session sendData:data
                   toPeers:_peers
                  withMode:MCSessionSendDataUnreliable
                     error:&error];
    }
}

#pragma mark - delegate methods

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    if (state == MCSessionStateConnected) {
        if (![_peers containsObject:peerID]) {
            [_peers addObject:peerID];
        }
    } else {
        if ([_peers containsObject:peerID]) {
            [_peers removeObject:peerID];
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:DEBUG_PEER_STATE_CHANGE object:self  userInfo:@{@"peers":_peers}];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    [self processReceivedData:data];
}

- (void)session:(MCSession *)session
didStartReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
   withProgress:(NSProgress *)progress
{
}

- (void)session:(MCSession *)session
didFinishReceivingResourceWithName:(NSString *)resourceName
       fromPeer:(MCPeerID *)peerID
          atURL:(NSURL *)localURL
      withError:(NSError *)error
{
}

- (void)session:(MCSession *)session
didReceiveStream:(NSInputStream *)stream
       withName:(NSString *)streamName
       fromPeer:(MCPeerID *)peerID
{
}

- (void) processReceivedData:(NSData*)data
{
    NSDictionary *json = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (json) {
            NSString *name = json[@"name"];
            double timestamp = [json[@"timestamp"] doubleValue];
            NSDictionary *userInfo = json[@"userInfo"];
        
            NSLog(@"receiveData,%ld,%@,%f", [data length], name, [[NSDate date] timeIntervalSince1970] - timestamp);
            [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
        }
    });
}

- (void) session:(MCSession *)session
  didReceiveCertificate:(nullable NSArray *)certificate
               fromPeer:(MCPeerID *)peerID
     certificateHandler:(void (^)(BOOL accept))certificateHandler;
{
    certificateHandler(YES);
}


- (NSString*) platformString
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char*)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *deviceName = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return deviceName;
}

- (NSDictionary*) buildBeaconJSON:(NSArray<CLBeacon *> *) beacons
{
    NSMutableDictionary *json = [@{} mutableCopy];
    json[@"type"] = @"rssi";
    
    
    NSString *phoneID = [NSString stringWithFormat:@"%@-%@", [self platformString], UIDevice.currentDevice.identifierForVendor.UUIDString];
    json[@"phoneID"] = phoneID;
    
    long timestamp = [[NSDate date] timeIntervalSince1970] * 1000.0;
    
    json[@"timestamp"] = @(timestamp);
    
    NSMutableArray* array = [@[] mutableCopy];
    
    for(CLBeacon *beacon in beacons) {
        NSString* id = [NSString stringWithFormat:@"%@-%@-%@",
                        beacon.proximityUUID.UUIDString,
                        beacon.major,
                        beacon.minor];
        NSDictionary* obj = @{
                              @"type": @"iBeacon",
                              @"id": id,
                              @"rssi": @(beacon.rssi)
                              };
        [array addObject:obj];
    }
    json[@"data"] = array;
    
    return json;
}

- (void) sendBeacons:(NSArray<CLBeacon *> *) beacons
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ud boolForKey:@"send_beacon_data"]) {
        return;
    }
    
    NSDictionary *json = [self buildBeaconJSON:beacons];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/beacon", [ud stringForKey:@"beacon_data_server"]]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    request.HTTPMethod = @"POST";
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    request.HTTPBody = data;
    
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 2;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data != nil) {
            NSLog(@"Send success");
            //std::cout << "Send success" << std::endl;
        }
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
            //std::cout << [[error localizedDescription] cStringUsingEncoding:NSUTF8StringEncoding] << std::endl;
        }
    }];
    
    [task resume];
}


@end
