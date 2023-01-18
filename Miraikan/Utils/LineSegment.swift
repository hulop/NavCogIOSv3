//
//
//  LineSegment.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation
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

import Foundation
import CoreGraphics

// https://gist.github.com/codelynx/80077dbbb07e7d989016188573eab880
// The MIT License (MIT)

// cross product
infix operator ×

extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    static func * (lhs: CGPoint, rhs: CGPoint) -> CGFloat { // dot product
        return lhs.x * rhs.x + lhs.y * rhs.y
    }

    static func × (lhs: CGPoint, rhs: CGPoint) -> CGFloat { // cross product
        return lhs.x * rhs.y - lhs.y * rhs.x
    }

    var length²: CGFloat {
        return (x * x) + (y * y)
    }

    var length: CGFloat {
        return sqrt(self.length²)
    }

    var normalized: CGPoint {
        let length = self.length
        return CGPoint(x: x/length, y: y/length)
    }
}

struct Line {
    var from: CGPoint
    var to: CGPoint

    init(from: CGPoint, to: CGPoint) {
        self.from = from
        self.to = to
    }

    var vector: CGPoint { return to - from }
    var length: CGFloat { return (to - from).length }

    static func intersection(_ line1: Line, _ line2: Line, _ segment: Bool) -> CGPoint? {
        let v = line2.from - line1.from
        let v1 = line1.to - line1.from
        let v2 = line2.to - line2.from
        let cp = v1 × v2
        if cp == 0 { return nil }

        let cp1 = v × v1 // cross product
        let cp2 = v × v2 // cross product

        let t1 = cp2 / cp
        let t2 = cp1 / cp

        let ε = CGFloat(0).nextUp
        if segment {
            if t1 + ε < 0 || t1 - ε > 1 || t2 + ε < 0 || t2 - ε > 1 { return nil }
        }
        return line1.from + v1 * t1
    }

    static func angle(_ line1: Line, _ line2: Line) -> CGFloat {
        let lenght1 = line1.length
        let lenght2 = line2.length

        let vector1 = line1.vector
        let vector2 = line2.vector

        let cosSita = (vector1.x * vector2.x + vector1.y * vector2.y) / (lenght1 * lenght2)
        let sita = acos(cosSita)

        return sita
    }

    static func isRightDirection(_ line: Line, point: CGPoint) -> Bool {
        let  cross = (line.from.x - line.to.x) * (point.y - line.to.y) - (line.from.y - line.to.y) * (point.x - line.to.x)
        return cross > 0
    }

    mutating func scalarTimes(_ scalar: Double) {
        let diff =  self.to - self.from
        self.to = self.to + CGPoint(x: diff.x * scalar, y: diff.y * scalar)
    }
}
