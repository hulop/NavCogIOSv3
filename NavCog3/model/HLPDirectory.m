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

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
             @"title": @"title",
             @"pron": @"pron",
             @"subtitle": @"subtitle",
             @"nodeID": @"nodeID",
             @"content": @"content"
             };
}

@end

@implementation HLPDirectorySection

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

@end

@implementation HLPDirectory

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

@end
