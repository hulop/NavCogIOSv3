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

#import "HLPSetting.h"

@implementation  HLPOptionGroup {
    BOOL _changing;
}
- (instancetype)init
{
    self = [super init];
    self.options = [@[] mutableCopy];
    return self;
}
- (void)addOption:(HLPSetting *)setting
{
    if ([self.options containsObject:setting]) {
        return;
    }
    [self.options addObject:setting];
    setting.group = self;
}
- (void)checkOption:(HLPSetting *)setting
{
    _currentValue = setting.name;
    [self save];
}
- (void)update
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    _currentValue = [ud objectForKey:_name];
    [[NSNotificationCenter defaultCenter] postNotificationName:HLPSettingChanged object:self];
}
- (void)save
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:_currentValue forKey:_name];
    [ud synchronize];
}
- (void) exportSetting:(NSMutableDictionary*)dic{
    if (_currentValue) {
        [dic setObject:_currentValue forKey:_name];
    }
}
@end

@implementation HLPSetting {
    BOOL _changing;
}

- (id) init
{
    self = [super init];
    self.visible = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsDidChange:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
    return self;
}

- (void) userDefaultsDidChange:(NSNotification*)note
{
    if (!_name || _changing) {
        return;
    }
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *selected_key = [NSString stringWithFormat:@"selected_%@", _name];
    NSString *list_key = [NSString stringWithFormat:@"%@_list", _name];
    
    if (_isList) {
        _currentValue = [ud arrayForKey:list_key];
        _selectedValue = [ud objectForKey:selected_key];
    } else {
        if (self.group) {
            [self.group update];
        } else {
            _currentValue = [ud objectForKey:_name];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:HLPSettingChanged object:self];
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"HLPSetting[%@] (%ld) %@", _label, _type, _visible?@"visible":@""];
}

- (void) save {
    if(_name == nil) {
        return;
    }
    _changing = YES;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (self.isList) {
        NSString *selected_key = [NSString stringWithFormat:@"selected_%@", self.name];
        NSString *list_key = [NSString stringWithFormat:@"%@_list", self.name];
        [ud setObject:self.currentValue forKey: list_key];
        [ud setObject:self.selectedValue forKey: selected_key];
    } else {
        if (self.group) {
            [self.group save];
        } else {
            [ud setObject:self.currentValue forKey: self.name];
        }
    }
    [ud synchronize];
    _changing = NO;
}

- (void)setHandler:(NSObject *(^)(NSObject *))_handler
{
    handler = _handler;
}

- (NSObject *)checkValue:(NSObject *)text
{
    if (!handler) {
        return text;
    }
    return handler(text);
}

- (NSInteger)numberOfRows
{
    if (self.isList) {
        return [((NSArray *) self.currentValue) count];
    }
    return 0;
}

- (NSInteger) selectedRow
{
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        for(int i = 0; i < [array count]; i++) {
            if ([[array objectAtIndex:i] isEqual:self.selectedValue]) {
                return i;
            }
        }
    }
    return -1;
}

-(NSString *)titleForRow: (NSInteger) row
{
    return [((NSArray *) self.currentValue) objectAtIndex: row];
}

- (void)addObject:(NSObject *)object
{
    if (self.isList) {
        self.currentValue = [((NSArray *) self.currentValue) arrayByAddingObject:object];
        self.selectedValue = object;
    }
}

- (void)removeSelected
{
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        if ([array count] <= 1) {
            return;
        }
        
        NSObject *select = nil, *last = nil;
        for(NSObject *obj in array) {
            if (![obj isEqual:self.selectedValue]) {
                [newArray addObject:obj];
            } else {
                if (last) {
                    select = last;
                }
            }
            last = obj;
        }
        if (!select) {
            select = [newArray firstObject];
        }
        self.selectedValue = select;
        self.currentValue = newArray;
    }
}

- (void)select:(NSInteger)row
{
    if (self.isList) {
        NSArray *array  = (NSArray*) self.currentValue;
        self.selectedValue = [array objectAtIndex:row];
    }
}

- (float) floatValue
{
    if ([self.currentValue isKindOfClass:[NSNumber class]]) {
        return [(NSNumber*) self.currentValue floatValue];
    }
    return 0;
}

- (BOOL)boolValue
{
    if (self.group) {
        return [self.name isEqualToString:(NSString*)self.group.currentValue];
    }
    else if ([self.currentValue isKindOfClass:[NSNumber class]]) {
        return [(NSNumber*) self.currentValue boolValue];
    }
    return NO;
}

- (NSString *)stringValue
{
    if ([self.currentValue isKindOfClass:[NSString class]]) {
        return (NSString*) self.currentValue;
    } else if ([self.currentValue isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%@", (NSNumber*) self.currentValue];
    }
    return nil;
}

- (void) exportSetting:(NSMutableDictionary*)dic
{
    if (_type == ACTION || _type == SECTION) {
        return;
    }
    if (_isList) {
        NSString *selected_key = [NSString stringWithFormat:@"selected_%@", self.name];
        NSString *list_key = [NSString stringWithFormat:@"%@_list", self.name];
        if (_selectedValue) {
            [dic setObject:_selectedValue forKey:selected_key];
        }
        if (_currentValue) {
            [dic setObject:_currentValue forKey:list_key];
        }
    } else {
        if (self.group) {
            [self.group exportSetting:dic];
        }
        else if (_currentValue) {
            [dic setObject:_currentValue forKey:_name];
        }
    }
}
@end
