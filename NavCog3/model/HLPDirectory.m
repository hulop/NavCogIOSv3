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

#import "HLPDirectory.h"

@implementation HLPDirectoryItem

-(id) copyWithZone:(NSZone *) zone
{
    HLPDirectoryItem *object = [super copyWithZone:zone];
    object->_title = self.title;
    object->_titlePron  = self.titlePron;
    object->_subtitle = self.subtitle;
    object->_nodeID = self.nodeID;
    object->_content = [self.content copyWithZone:zone];
    return object;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"title": @"title",
             @"titlePron": @"titlePron",
             @"subtitle": @"subtitle",
             @"subtitlePron": @"subtitlePron",
             @"nodeID": @"nodeID",
             @"content": @"content"
             };
}

- (void)walk:(BOOL (^)(HLPDirectoryItem *))func withBuffer:(NSMutableArray *)buffer
{
    if (_content) {
        [_content walk:func withBuffer:buffer];
    } else {
        if (func(self)) {
            [buffer addObject:self];
        }
    }
}

- (NSString*) getItemTitle {
    return _title;
}

- (NSString *) getItemTitlePron {
    if (_titlePron) {
        return _titlePron;
    }
    return _title;
}

- (NSString *)getItemSubtitle {
    return _subtitle;
}

- (NSString *)getItemSubtitlePron {
    if (_subtitlePron) {
        return _subtitlePron;
    }
    return _subtitle;
}

@end

@implementation HLPDirectorySection

-(id) copyWithZone:(NSZone *) zone
{
    HLPDirectorySection *object = [super copyWithZone:zone];
    object->_title = self.title;
    object->_pron  = self.pron;
    object->_indexTitle = self.indexTitle;
    object->_items = [[self.items mutableCopy] copyWithZone:zone];
    return object;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"title": @"title",
             @"pron": @"pron",
             @"indexTitle": @"indexTitle",
             @"items": @"items"
             };
}

+ (NSValueTransformer *)itemsJSONTransformer
{
    return [MTLJSONAdapter arrayTransformerWithModelClass:HLPDirectoryItem.class];
}

- (void)walk:(BOOL (^)(HLPDirectoryItem *))func withBuffer:(NSMutableArray *)buffer
{
    for(HLPDirectoryItem *item in _items) {
        if ([item isKindOfClass:HLPDirectoryItem.class]){
            [item walk:func withBuffer:buffer];
        }
    }
}

@end

@implementation HLPDirectory

-(id) copyWithZone:(NSZone *) zone
{
    HLPDirectory *object = [super copyWithZone:zone];
    object->_showSectionIndex = self.showSectionIndex;
    object->_sections = [[self.sections mutableCopy] copyWithZone:zone];
    return object;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
             @"sections": @"sections",
             @"showSectionIndex": @"showSectionIndex"
             };
}

+ (NSValueTransformer *)sectionsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:HLPDirectorySection.class];
}

- (void)walk:(BOOL (^)(HLPDirectoryItem *))func withBuffer:(NSMutableArray *)buffer
{
    for(HLPDirectorySection *section in _sections) {
        [section walk:func withBuffer:buffer];
    }
}

- (void)addSection:(HLPDirectorySection *)section atIndex:(NSUInteger)index
{
    NSMutableArray *temp = [_sections mutableCopy];
    [temp insertObject:section atIndex:index];
    _sections = temp;
}

@end
