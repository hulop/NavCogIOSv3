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
    var fillColor:UIColor? = UIColor.white
    var strokeColor:UIColor? = UIColor.black

    func setSize(_ rect:CGRect){
        x = 0.0
        y = rect.size.height / 2
        
        x2 = rect.size.width
        y2 = 0.0
        
        x3 = rect.size.width
        y3 = rect.size.height
    }
    override func draw(_ rect: CGRect)
    {
        setSize(rect)
        
        self.strokeColor!.setStroke()
        
        let line = UIBezierPath()
        line.lineWidth = linewidth
        line.move(to: CGPoint(x: x2!, y: y2!))
        line.addLine(to: CGPoint(x: x!, y: y!))
        line.addLine(to: CGPoint(x: x3!, y: y3!))
        line.stroke()
        
        self.fillColor!.setStroke()
        self.fillColor!.setFill()
        
        let line2 = UIBezierPath()
        line2.lineWidth = linewidth
        line2.move(to: CGPoint(x: x2! + horOffset, y: y2!))
        line2.addLine(to: CGPoint(x: x! + horOffset, y: y!))
        line2.addLine(to: CGPoint(x: x3! + horOffset, y: y3!))
        line2.close()
        line2.stroke()
        line2.fill()
    }
}

class CustomRightArrow: CustomLeftArrow{
    override func setSize(_ rect: CGRect)
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
