//
//  NavCogTests.m
//  NavCogTests
//
//  Created by CAL Cabot on 3/8/22.
//  Copyright © 2022 HULOP. All rights reserved.
//

#import <XCTest/XCTest.h>
#include "NavDataStore.h"
#include "ServerConfig.h"

@interface NavCogTests : XCTestCase

@end

@implementation NavCogTests

- (void)setUp {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    [nds setMapCenter:[[HLPLocation alloc] initWithLat:40.49577065744299 Lng:-80.24609318398905]];
    nds.userID = @"NavCogTests";

    NSString *description = [NSString stringWithFormat:@"%s%d", __FUNCTION__, __LINE__];
    XCTestExpectation *exp = [self expectationWithDescription:description];

    [nds reloadDestinations:YES withComplete:^(NSArray *dest, HLPDirectory *dir) {
        [exp fulfill];
    }];

    // Wait for the async request to complete
    [self waitForExpectationsWithTimeout:10 handler: nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testLoading {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    XCTAssertGreaterThan(nds.destinations.count, 0);
}

- (void)testArchive1 {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *f = nds.destinations[0];
    NavDestination *from = [[NavDestination alloc] initWithLandmark:f];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:from requiringSecureCoding:YES error:&error];
    XCTAssertNotNil(data);
    NSLog(@"%@", error.description);
}

- (void)testArchive2 {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *f = nds.destinations[0];
    HLPLandmark *t = nds.destinations[1];
    NavDestination *from = [[NavDestination alloc] initWithLandmark:f];
    NavDestination *to = [[NavDestination alloc] initWithLandmark:t];

    NSDictionary *newHist = @{
        @"from":[NSKeyedArchiver archivedDataWithRootObject:from requiringSecureCoding:YES error:nil],
        @"to":[NSKeyedArchiver archivedDataWithRootObject:to requiringSecureCoding:YES error:nil] };


    NSMutableArray *temp = [@[] mutableCopy];
    [temp insertObject:newHist
               atIndex:0];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:temp requiringSecureCoding:YES error:&error];
    NSLog(@"%@", error.description);
    XCTAssertNotNil(data);
}

- (void)testArchiveHLPLocation {
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:0 Lng:0];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:loc requiringSecureCoding:YES error:&error];
    NSLog(@"%@", error.description);

    XCTAssertNotNil(data);
}

- (void)testUnarchiveHLPLocation {
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:0 Lng:0];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:loc requiringSecureCoding:YES error:&error];

    HLPLocation *loc2 = [NSKeyedUnarchiver unarchivedObjectOfClass:HLPLocation.class fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(loc2);
}


- (void)testUnarchiveHLPGeometry {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *landmark = nds.destinations[0];

    HLPGeometry *geo = landmark.geometry;

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:geo requiringSecureCoding:YES error:&error];

    HLPGeometry *geo2 = [NSKeyedUnarchiver unarchivedObjectOfClass:HLPGeometry.class fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(geo2);
}


- (void)testUnarchiveHLPLandmarkProperties {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *landmark = nds.destinations[0];

    NSDictionary *prop = landmark.properties;

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:prop requiringSecureCoding:YES error:&error];

    NSSet *set = [[NSSet alloc] initWithArray:@[NSDictionary.class, NSString.class]];
    NSDictionary *prop2 = [NSKeyedUnarchiver unarchivedObjectOfClasses:set fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(prop2);
}

- (void)testUnarchiveHLPLandmark {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *landmark = nds.destinations[0];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:landmark requiringSecureCoding:YES error:&error];

    HLPLandmark *landmark2 = [NSKeyedUnarchiver unarchivedObjectOfClass:HLPLandmark.class fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(landmark2);
}

- (void)testUnarchiveNavDestination {
    NavDataStore *nds = [NavDataStore sharedDataStore];

    for (int i = 0; i < nds.destinations.count; i++) {
        HLPLandmark *landmark = nds.destinations[i];
        NavDestination *destination = [[NavDestination alloc] initWithLandmark:landmark];

        NSError *error;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:destination requiringSecureCoding:YES error:&error];

        NavDestination *destination2 = [NSKeyedUnarchiver unarchivedObjectOfClass:NavDestination.class fromData:data error:&error];

        NSLog(@"%@", error.description);
        XCTAssertNotNil(destination2);
        if (destination2 == nil) {
            break;
        }
    }
}

- (void)testUnarchiveNavDestination2 {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *landmark0 = nds.destinations[0];
    HLPLandmark *landmark1 = nds.destinations[1];

    NavDestination *destination = [[NavDestination alloc] initWithLandmark:landmark0];
    [destination addLandmark:landmark1];

    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:destination requiringSecureCoding:YES error:&error];

    NavDestination *destination2 = [NSKeyedUnarchiver unarchivedObjectOfClass:NavDestination.class fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(destination2);
}

- (void)testUnarchiveNavHistory {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *f = nds.destinations[0];
    HLPLandmark *t = nds.destinations[1];
    NavDestination *from = [[NavDestination alloc] initWithLandmark:f];
    NavDestination *to = [[NavDestination alloc] initWithLandmark:t];

    NavHistory *history = [[NavHistory alloc] initWithFrom:from andTo:to];

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:history requiringSecureCoding:YES error:nil];

    NSError *error;
    NavHistory *history2 = [NSKeyedUnarchiver unarchivedObjectOfClass:NavHistory.class fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertNotNil(history2);
}

- (void)testUnarchiveNavHistoryArray {
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLandmark *f = nds.destinations[0];
    HLPLandmark *t = nds.destinations[1];
    NavDestination *from = [[NavDestination alloc] initWithLandmark:f];
    NavDestination *to = [[NavDestination alloc] initWithLandmark:t];

    NavHistory *newHist = [[NavHistory alloc] initWithFrom:from andTo:to];

    NSMutableArray *temp = [@[] mutableCopy];
    [temp insertObject:newHist
               atIndex:0];

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:temp requiringSecureCoding:YES error:nil];

    NSError *error;
    NSSet *set = [[NSSet alloc] initWithArray:@[NSArray.class, NavHistory.class]];
    NSArray *history = [NSKeyedUnarchiver unarchivedObjectOfClasses:set fromData:data error:&error];

    NSLog(@"%@", error.description);
    XCTAssertGreaterThan(history.count, 0);
}

@end
