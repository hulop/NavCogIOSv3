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
#import <UIKit/UIKit.h>
#import "NavDataStore.h"
#import "HLPDirectory.h"

@interface NavTableDataSource: NSObject <UITableViewDataSource>{
    @protected NSDictionary *_filter;
    @protected BOOL _showCurrentLocation;
    @protected BOOL _showFacility;
    @protected BOOL _showDialog;
}
@property NSDictionary *filter;
@property BOOL showCurrentLocation;
@property BOOL showFacility;
@property BOOL showDialog;
- (NavDestination*) destinationForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface NavDirectoryDataSource : NavTableDataSource
@property HLPDirectory *directory;
- (instancetype)initWithDirectory:(HLPDirectory*)directory;
- (void)update:(NSNotification*)note;
@end

@interface NavDestinationDataSource : NavTableDataSource
@property NSInteger selectedRow;
@property NSDictionary *defaultFilter;
@property HLPDirectory *directory;

@property BOOL showBuilding;
@property BOOL showShops;
@property BOOL showSectionIndex;
@property BOOL showNearShops;
@property BOOL showShopBuilding;
@property BOOL showShopFloor;

- (NavDestination*) destinationForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)update:(NSNotification*)note;
@end

@interface NavSearchHistoryDataSource : NSObject < UITableViewDataSource>
- (NavHistory*) historyAtIndexPath:(NSIndexPath*)indexPath;
@end
