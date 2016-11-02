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

#import "HLPSettingHelper.h"

@implementation HLPSettingHelper

- (id) init
{
    self = [super init];
    self.settings = [[NSMutableArray alloc] init];
    return self;
}

- (NSInteger)numberOfSections
{
    int count = 0;
    for(HLPSetting *s in self.settings) {
        //NSLog(@"%@ %d", s.label, s.type);
        if (s.type == SECTION && s.visible) {
            count++;
        }
    }
    if (count == 0) {
        return 1;
    }
    return count;
}

- (NSInteger)numberOfRowsInSection:(NSInteger)section
{
    if ([self.settings count] == 0) {
        return 0;
    }

    BOOL first = YES;
    int current = -1;
    int count = 0;
    BOOL selected = NO;
    
    for(HLPSetting *s in self.settings) {
        if (!s.visible) continue;
        
        if (first && s.type != SECTION) {
            current++;
        }
        else if (s.type == SECTION) {
            current++;
        }
        
        if (current == section) {
            selected = YES;
        } else {
            selected = NO;
        }

        if (selected && s.type != SECTION) {
            count++;
        }

        first = NO;
    }
    //NSLog(@"section %ld, row %d", section , count);
    return count;
}

- (HLPSetting*) _getSetting: (NSIndexPath*) indexPath
{
    if ([self.settings count] == 0) {
        return nil;
    }
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    BOOL first = YES;
    NSInteger current = -1;
    NSInteger count = 0;
    BOOL selected = NO;
    
    for(HLPSetting *s in self.settings) {
        if (!s.visible) continue;
        
        if (first && s.type != SECTION) {
            current++;
        }
        else if (s.type == SECTION) {
            current++;
        }
        
        if (current == section) {
            if (row == -1) {
                return s;
            }
            selected = YES;
        } else {
            selected = NO;
        }
        
        if (selected && s.type != SECTION) {
            if (count == row) {
                return s;
            }
            count++;
        }
        first = NO;
    }
    return nil;
}

- (NSString*) cellIdentifierFor: (HLPSetting*) s
{
    if (s.isList) {
        return @"pickerCell";
    }
    switch (s.type) {
        case UUID_TYPE:
        case HOST_PORT:
        case SUBTITLE:
        case STRING:
        case OPTION:
        case ACTION:
            return @"subtitleCell";
        case BOOLEAN:
            return @"switchCell";
        case DOUBLE:
            return @"sliderCell";
        case TEXTINPUT:
        case PASSINPUT:
            return @"textCell";
        default:
            break;
    }
    
    return nil;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HLPSetting *s = [self _getSetting:indexPath];
    if (s == nil) {
        return nil;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[self cellIdentifierFor:s] forIndexPath:indexPath];
    
    [self updateCell:cell forSetting:s];
    
    //NSLog(@"%@", cell);
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HLPSetting *s = [self _getSetting:indexPath];
    if (s == nil) {
        return 44;
    }
    if (s.type == DOUBLE) {
        return 76;
    }
    if (s.type == TEXTINPUT || s.type == PASSINPUT) {
        return 78;
    }
    if (s.isList) {
        return 146;
    }
    return 44;
}

- (void) updateCell:(UITableViewCell*) cell forSetting:(HLPSetting*) s
{
    if ([cell isKindOfClass:HLPSettingViewCell.class]) {
        HLPSettingViewCell *sCell = (HLPSettingViewCell*)cell;
        sCell.delegate = self;
        if ([sCell respondsToSelector:@selector(update:)]) {
            [sCell performSelector:@selector(update:) withObject:s];
        }
    }
}

- (void)actionPerformed:(HLPSetting *)setting
{
    [self.delegate actionPerformed:setting];
}

- (NSObject*) uuidDefaultHandler:(NSObject*) value
{
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *str = (NSString*) value;
    
    NSString* pattern = @"^[0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12}$";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    if ([[regex matchesInString:str options:0 range:NSMakeRange(0, [str length])] count] > 0 ) {
        return str;
    }
    return nil;
}

- (NSObject*) hostPortDefaultHandler:(NSObject*) value
{
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *str = (NSString*) value;
    NSString* pattern = @"^([-0-9a-zA-Z]+(\\.[-0-9a-zA-Z]+)+)(:[0-9]+)?$";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    if ([[regex matchesInString:str options:0 range:NSMakeRange(0, [str length])] count] > 0 ) {
        return value;
    }
    return nil;
}

- (void)addSectionTitle:(NSString *)title
{
    HLPSetting *s = [[HLPSetting alloc] init];
    s.type = SECTION;
    s.label = title;
    
    [self.settings addObject:s];
}

- (void)addActionTitle:(NSString *)title Name:(NSString*)name
{
    HLPSetting *s = [[HLPSetting alloc] init];
    s.type = ACTION;
    s.label = title;
    s.name = name;
    
    [self.settings addObject:s];
}

- (HLPSetting*)addSettingWithType:(NavCogSettingType)type Label:(NSString *)label Name:(NSString *)name DefaultValue:(NSObject *)defaultValue Min:(double)min Max:(double)max Interval:(double)interval
{
    HLPSetting *s = [self addSettingWithType:type Label:label Name:name DefaultValue:defaultValue Accept:nil];
    [s setHandler:^NSObject *(NSObject *value) {
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *num = (NSNumber*)value;
            float f = [num floatValue];
            f = round(f*1/s.interval) / (1/s.interval);
            return [NSNumber numberWithFloat:f];
        }
        return nil;
    }];
    s.min = min;
    s.max = max;
    s.interval = interval;
    return s;
}

- (HLPSetting*)addSettingWithType:(NavCogSettingType)type Label:(NSString*) label Name:(NSString *)name Group:(NSString*)group DefaultValue:(NSObject*) defaultValue Accept:(NSObject *(^)(NSObject *))handler
{
    HLPSetting *s = [self addSettingWithType:type Label:label Name:name DefaultValue:defaultValue Accept:handler];
    if (!self.groups) {
        self.groups = [@{} mutableCopy];
    }
    if (!self.groups[group]) {
        HLPOptionGroup *g = [[HLPOptionGroup alloc] init];
        g.name = group;
        self.groups[group] = g;
    }
    [self.groups[group] addOption:s];

    if ([(NSNumber*)defaultValue boolValue]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        NSDictionary *def = [[NSDictionary alloc] initWithObjectsAndKeys: group, name, nil];
        [ud registerDefaults:def];
    }
    
    return s;
}

- (HLPSetting*)addSettingWithType:(NavCogSettingType)type Label:(NSString*) label Name:(NSString *)name DefaultValue:(NSObject*) defaultValue Accept:(NSObject *(^)(NSObject *))handler
{
    HLPSetting *s = [[HLPSetting alloc] init];

    s.type = type;
    s.label = label;
    s.name = name;
    s.defaultValue = defaultValue;
    if (handler) {
        [s setHandler:handler];
    } else {
        if (s.type == UUID_TYPE) {
            [s setHandler:^NSObject *(NSObject *value) {
                return [self uuidDefaultHandler:value];
            }];
        }
        if (s.type == HOST_PORT) {
            [s setHandler:^NSObject *(NSObject *value) {
                return [self hostPortDefaultHandler:value];
            }];
        }
    }

    s.isList = NO;
    if ([defaultValue isKindOfClass: [NSArray class]]) {
        s.isList = YES;
    }
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *def = [[NSDictionary alloc] initWithObjectsAndKeys: name, defaultValue, nil];
    [ud registerDefaults:def];
    
    NSString *selected_key = [NSString stringWithFormat:@"selected_%@", name];
    NSString *list_key = [NSString stringWithFormat:@"%@_list", name];
    
    if (s.isList) {
        s.selectedValue = [ud objectForKey:selected_key];
        if (!s.selectedValue) {
            s.selectedValue = [((NSArray*)s.defaultValue) firstObject];
            [ud setObject:s.selectedValue forKey:selected_key];
        }
        
        s.currentValue = [ud arrayForKey:list_key];
        if (!s.currentValue) {
            s.currentValue = s.defaultValue;
            [ud setObject:s.currentValue forKey:list_key];
        }
    } else {
        s.currentValue = [ud objectForKey:s.name];
        if (!s.currentValue) {
            s.currentValue = s.defaultValue;
            [ud setObject:s.currentValue forKey:s.name];
        }
    }
    
    
    [self.settings addObject:s];
    return s;
}

- (void)removeAllSetting
{
    [_settings removeAllObjects];
}

- (NSString *)titleForSection:(NSInteger)row
{
    NSString *title = @"";
    int count = 0;
    for(HLPSetting *s in self.settings) {
        if (s.type == SECTION && s.visible) {
            if (count == row) {
                title = s.label;
            }
            count++;
        }
    }
    return title;
}

- (void) setVisible:(BOOL) visible Section: (NSInteger) section
{
    for(int i = -1;; i++) {
        NSIndexPath *p = [NSIndexPath indexPathForRow:i inSection:section];
        HLPSetting *s = [self _getSetting:p];
        if (!s) break;
        s.visible = visible;
        //NSLog(@"%@", s);
    }
}





- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self numberOfRowsInSection:section];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self titleForSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    HLPSetting *s = [self _getSetting:indexPath];
    if (s.type == ACTION) {
        [self.delegate actionPerformed:s];
    }
}

- (void) exportSetting:(NSMutableDictionary*)dic
{
    for(HLPSetting *s in _settings) {
        [s exportSetting:dic];
    }
}

@end
