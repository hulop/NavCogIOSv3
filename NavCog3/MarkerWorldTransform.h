//
//  MarkerWorldTransform.h
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2023 © Miraikan - The National Museum of Emerging Science and Innovation
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

#ifndef MarkerWorldTransform_h
#define MarkerWorldTransform_h

#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkerWorldTransform : NSObject

@property(nonatomic) int arucoId;
@property(nonatomic) SCNMatrix4 transform;
@property(nonatomic) NSArray *points;
@property(nonatomic) CGPoint intersection;

@property(nonatomic) CGFloat distance;
@property(nonatomic) CGFloat horizontalDistance;

@property(nonatomic) CGFloat x;
@property(nonatomic) CGFloat y;
@property(nonatomic) CGFloat z;
@property(nonatomic) CGFloat roll;
@property(nonatomic) CGFloat pitch;
@property(nonatomic) CGFloat yaw;

@end

NS_ASSUME_NONNULL_END

#endif /* MarkerWorldTransform_h */
