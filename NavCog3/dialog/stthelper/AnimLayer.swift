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

import UIKit

class AnimLayer: CALayer {
    var size:CGFloat = 0.0
    static let blue = UIColor(colorLiteralRed: 50.0/255.0, green: 92.0/255.0, blue: 128.0/255.0, alpha: 1.0).CGColor
    static let gray = UIColor(colorLiteralRed: 221.0/255.0, green: 222.0/255.0, blue: 223.0/255.0, alpha: 1.0).CGColor
    static let white = UIColor(colorLiteralRed: 244.0/255.0, green: 244.0/255.0, blue: 236.0/255.0, alpha: 1.0).CGColor
    var color = blue
    var frames:[NSTimeInterval] = []
    override func drawInContext(ctx: CGContext) {
        let fs = self.bounds.size.width
        let rect = CGRect(x: (fs-size)/2, y: (fs-size)/2, width: size, height: size)
        CGContextSetFillColorWithColor(ctx, color)
        CGContextAddEllipseInRect(ctx, rect)
        CGContextFillPath(ctx)
        super.drawInContext(ctx)
        
        frames.append(NSDate().timeIntervalSince1970)
        let last = NSDate().timeIntervalSince1970 - 1
        while(frames[0] < last) {
            frames.removeFirst()
        }
        //NSLog("\(frames.count) fps")
    }
    override class func needsDisplayForKey(key: String) -> Bool {
        if key == "size" {
            return true
        }
        return super.needsDisplayForKey(key)
    }
    

    // animation builders
    static func pulse(duration:CFTimeInterval, size: CGFloat, scale:CGFloat) -> CAAnimation{
        let a = CAKeyframeAnimation(keyPath: "size")
        var v:[CGFloat] = []
        var k:[CGFloat] = []
        let N:CGFloat = 30
        for var i:CGFloat = 0; i <= N; i += 1.0 {
            v.append(size+size*(scale-1)*sin(CGFloat(i)/N*CGFloat(M_PI)*2))
            k.append(CGFloat(i)/N)
        }
        a.values = v
        a.keyTimes = k
        a.duration = duration
        a.autoreverses = false
        a.removedOnCompletion = false;
        a.repeatCount = 1
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        return a
    }
    
    static func pop(duration:CFTimeInterval, scale:CGFloat, x:CGFloat, y:CGFloat, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "transform")
        a.duration = duration/2;
        var tr = CATransform3DIdentity;
        a.fromValue = NSValue(CATransform3D: tr)
        tr = CATransform3DTranslate(tr, x, y, 0);
        tr = CATransform3DScale(tr, scale, scale, 1);
        tr = CATransform3DTranslate(tr, -x, -y, 0);
        a.toValue = NSValue(CATransform3D: tr)
        a.repeatCount = 1
        a.autoreverses = true
        a.removedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func scale(duration:CFTimeInterval, current: CGFloat, scale:CGFloat, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "size")
        a.duration = duration
        a.fromValue = current
        a.toValue = current * scale
        a.repeatCount = 1
        a.autoreverses = false
        a.removedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func dissolve(duration:CFTimeInterval, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration
        a.fromValue = 0
        a.toValue = 1
        a.repeatCount = 1
        a.autoreverses = false
        a.removedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func dissolveOut(duration:CFTimeInterval, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration
        a.fromValue = 1
        a.toValue = 0
        a.repeatCount = 1
        a.autoreverses = false
        a.removedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func blink(duration:CFTimeInterval, rep:Float) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration/2.0/CFTimeInterval(rep)
        a.repeatCount = rep
        a.fromValue = 1
        a.toValue = 0
        a.autoreverses = true
        a.removedOnCompletion = false
        a.fillMode = kCAFillModeBoth
        return a
    }
    
    static func delay(a: CAAnimation, second:CFTimeInterval) -> CAAnimation{
        a.beginTime = CACurrentMediaTime() + second
        return a
    }

}
