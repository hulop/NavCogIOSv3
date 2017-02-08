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
    static let blue = UIColor(colorLiteralRed: 50.0/255.0, green: 92.0/255.0, blue: 128.0/255.0, alpha: 1.0).cgColor
    static let gray = UIColor(colorLiteralRed: 221.0/255.0, green: 222.0/255.0, blue: 223.0/255.0, alpha: 1.0).cgColor
    static let white = UIColor(colorLiteralRed: 244.0/255.0, green: 244.0/255.0, blue: 236.0/255.0, alpha: 1.0).cgColor
    static let transparent = UIColor(colorLiteralRed: 255.0/255.0, green: 255.0/255.0, blue: 255.0/255.0, alpha: 0.0).cgColor
    var color = blue
    var frames:[TimeInterval] = []
    override func draw(in ctx: CGContext) {
        let fs = self.bounds.size.width
        let rect = CGRect(x: (fs-size)/2, y: (fs-size)/2, width: size, height: size)
        ctx.setFillColor(color)
        ctx.addEllipse(in: rect)
        ctx.fillPath()
        super.draw(in: ctx)
        
        frames.append(Date().timeIntervalSince1970)
        let last = Date().timeIntervalSince1970 - 1
        while(frames[0] < last) {
            frames.removeFirst()
        }
        //NSLog("\(frames.count) fps")
    }
    override class func needsDisplay(forKey key: String) -> Bool {
        if key == "size" {
            return true
        }
        return super.needsDisplay(forKey: key)
    }
    

    // animation builders
    static func pulse(_ duration:CFTimeInterval, size: CGFloat, scale:CGFloat) -> CAAnimation{
        let a = CAKeyframeAnimation(keyPath: "size")
        var v:[CGFloat] = []
        var k:[CGFloat] = []
        let N = 30
        for i in 0..<N+1 {
            v.append(size+size*(scale-1)*sin(CGFloat(i)/CGFloat(N)*CGFloat(M_PI)*2))
            k.append(CGFloat(i)/CGFloat(N))
        }
        a.values = v
        a.keyTimes = k as [NSNumber]?
        a.duration = duration
        a.autoreverses = false
        a.isRemovedOnCompletion = false;
        a.repeatCount = 1
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        return a
    }
    
    static func pop(_ duration:CFTimeInterval, scale:CGFloat, x:CGFloat, y:CGFloat, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "transform")
        a.duration = duration/2;
        var tr = CATransform3DIdentity;
        a.fromValue = NSValue(caTransform3D: tr)
        tr = CATransform3DTranslate(tr, x, y, 0);
        tr = CATransform3DScale(tr, scale, scale, 1);
        tr = CATransform3DTranslate(tr, -x, -y, 0);
        a.toValue = NSValue(caTransform3D: tr)
        a.repeatCount = 1
        a.autoreverses = true
        a.isRemovedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func scale(_ duration:CFTimeInterval, current: CGFloat, scale:CGFloat, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "size")
        a.duration = duration
        a.fromValue = current
        a.toValue = current * scale
        a.repeatCount = 1
        a.autoreverses = false
        a.isRemovedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func dissolve(_ duration:CFTimeInterval, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration
        a.fromValue = 0
        a.toValue = 1
        a.repeatCount = 1
        a.autoreverses = false
        a.isRemovedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func dissolveOut(_ duration:CFTimeInterval, type:String) -> CABasicAnimation{
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration
        a.fromValue = 1
        a.toValue = 0
        a.repeatCount = 1
        a.autoreverses = false
        a.isRemovedOnCompletion = false;
        a.fillMode = kCAFillModeBoth;
        a.timingFunction = CAMediaTimingFunction(name: type)
        return a
    }
    
    static func blink(_ duration:CFTimeInterval, rep:Float) -> CABasicAnimation {
        let a = CABasicAnimation(keyPath: "opacity")
        a.duration = duration/2.0/CFTimeInterval(rep)
        a.repeatCount = rep
        a.fromValue = 1
        a.toValue = 0
        a.autoreverses = true
        a.isRemovedOnCompletion = false
        a.fillMode = kCAFillModeBoth
        return a
    }
    
    static func delay(_ a: CAAnimation, second:CFTimeInterval) -> CAAnimation{
        a.beginTime = CACurrentMediaTime() + second
        return a
    }

}
