/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
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

#define HLPSettingChanged @"HLPSettingChanged"

@class HLPSetting;

@interface HLPOptionGroup : NSObject
@property NSString *name;
@property NSMutableArray *options;
@property NSObject *currentValue;
- (void) addOption:(HLPSetting*)setting;
- (void) checkOption:(HLPSetting*)setting;
- (void) exportSetting:(NSMutableDictionary*)dic;
- (void) update;
@end

#define HLPSettingDefaultCellHeight (-1)

typedef NS_ENUM (NSUInteger, NavCogSettingType) {
    NavCogSettingTypeSection,
    NavCogSettingTypeAction,
    NavCogSettingTypeUUIDType,
    NavCogSettingTypeHostPort,
    NavCogSettingTypeString,
    NavCogSettingTypeSubtitle,
    NavCogSettingTypeDouble,
    NavCogSettingTypeBoolean,
    NavCogSettingTypeTextInput,
    NavCogSettingTypePassInput,
    NavCogSettingTypeOption
};

@interface HLPSetting: NSObject {
    NSObject*(^handler)(NSObject *value);
}

- (void) setHandler:(NSObject*(^)(NSObject* value)) _handler;
- (NSInteger) numberOfRows;
- (NSInteger) selectedRow;
- (NSString*) titleForRow: (NSInteger) row;
- (NSObject*) checkValue: (NSObject*) value;
- (void) addObject: (NSObject*) object;
- (void) removeSelected;
- (void) select:(NSInteger) row;
- (void) save;
- (float) floatValue;
- (BOOL) boolValue;
- (NSString*) stringValue;
- (void) exportSetting:(NSMutableDictionary*)dic;

@property NavCogSettingType type;
@property NSString *label;
@property NSString *name;
@property HLPOptionGroup *group;
@property NSObject *defaultValue;
@property NSObject *currentValue;
@property NSObject *selectedValue;
@property BOOL isList;
@property float min;
@property float max;
@property float interval;
@property BOOL visible;
@property BOOL disabled;
@property CGFloat cellHeight;
@property UIFont *titleFont;

@end
