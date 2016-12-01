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

import Foundation
import UIKit

class CustomLeftArrow: UIView
{
    let linewidth:CGFloat = 0.3

    var x:CGFloat? = nil
    var y:CGFloat? = nil
    
    var x2:CGFloat? = nil
    var y2:CGFloat? = nil
    
    var x3:CGFloat? = nil
    var y3:CGFloat? = nil
    
    var horOffset:CGFloat = 1.0
    var fillColor:UIColor? = UIColor.whiteColor()
    var strokeColor:UIColor? = UIColor.blackColor()

    func setSize(rect:CGRect){
        x = 0.0
        y = rect.size.height / 2
        
        x2 = rect.size.width
        y2 = 0.0
        
        x3 = rect.size.width
        y3 = rect.size.height
    }
    override func drawRect(rect: CGRect)
    {
        setSize(rect)
        
        self.strokeColor!.setStroke()
        
        let line = UIBezierPath()
        line.lineWidth = linewidth
        line.moveToPoint(CGPointMake(x2!, y2!))
        line.addLineToPoint(CGPointMake(x!, y!))
        line.addLineToPoint(CGPointMake(x3!, y3!))
        line.stroke()
        
        self.fillColor!.setStroke()
        self.fillColor!.setFill()
        
        let line2 = UIBezierPath()
        line2.lineWidth = linewidth
        line2.moveToPoint(CGPointMake(x2! + horOffset, y2!))
        line2.addLineToPoint(CGPointMake(x! + horOffset, y!))
        line2.addLineToPoint(CGPointMake(x3! + horOffset, y3!))
        line2.closePath()
        line2.stroke()
        line2.fill()
    }
}

class CustomRightArrow: CustomLeftArrow{
    override func setSize(rect: CGRect)
    {
        x = rect.size.width
        y = rect.size.height / 2
        
        x2 = 0.0
        y2 = 0.0
        
        x3 = 0.0
        y3 = rect.size.height
        horOffset = -1.0
    }
}
