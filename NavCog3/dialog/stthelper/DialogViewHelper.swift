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

enum DialogViewState:String {
    case Unknown = "unknown"
    case Inactive = "inactive"
    case Speaking = "speaking"
    case Listening = "listening"
    case Recognized = "recognized"
    
    mutating func animTo(state:DialogViewState, target:DialogViewHelper) {
        let anims:[(from:DialogViewState,to:DialogViewState,anim:((DialogViewHelper)->Void))] = [
            (from:.Unknown, to:.Inactive, anim:{$0.inactiveAnim()}),
            (from:.Unknown, to:.Speaking, anim:{$0.speakpopAnim()}),
            (from:.Unknown, to:.Listening, anim:{$0.listenpopAnim()}),
            (from:.Unknown, to:.Recognized, anim:{$0.recognizeAnim()}),
            
            (from:.Inactive, to:.Recognized, anim:{$0.recognizeAnim()}),
            (from:.Speaking, to:.Recognized, anim:{$0.recognizeAnim()}),
            (from:.Listening, to:.Recognized, anim:{$0.recognizeAnim()}),
            
            (from:.Inactive, to:.Speaking, anim:{$0.speakpopAnim()}),
            (from:.Listening, to:.Speaking, anim:{$0.speakpopAnim()}),
            (from:.Recognized, to:.Speaking, anim:{$0.shrinkAnim(#selector(DialogViewHelper.speakpopAnim)) }),
            
            (from:.Inactive, to:.Listening, anim:{$0.listenpopAnim()}),
            (from:.Speaking, to:.Listening, anim:{$0.listenpopAnim()}),
            (from:.Recognized, to:.Listening, anim:{$0.listenpopAnim()}),
            
            (from:.Speaking, to:.Inactive, anim:{$0.inactiveAnim()}),
            (from:.Listening, to:.Inactive, anim:{$0.inactiveAnim()}),
            (from:.Recognized, to:.Inactive, anim:{$0.inactiveAnim()})
        ]
        
        for tuple in anims {
            if (self == tuple.from && state == tuple.to) {
                tuple.anim(target);
            }
        }
        self = state;
    }
}

protocol DialogViewDelegate {
    func tapped(state:DialogViewState);
}

class HelperView: UIView {
    var delegate: DialogViewDelegate?
    var bTabEnabled:Bool=false  // tap availability
 
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.layer.opacity = 0.5
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.layer.opacity = 1.0
        delegate?.tapped(DialogViewState.Unknown)
    }
}

class DialogViewHelper: NSObject {
    private var back1: AnimLayer!       // first circle
    private var back2: AnimLayer!       // second circle
    private var l1: AnimLayer!          // speak indicator center / volume indicator
    private var l2: AnimLayer!          // speak indicator left
    private var l3: AnimLayer!          // speak indicator right
    private var micback: AnimLayer!     // mic background
    private var mic: CALayer!           // mic image
    private var micimgw:CGImage!        // mic white image
    private var micimgr:CGImage!        // mic red image
    private var power:Float = 0.0       // mic audio power
    private var recording = false       // recording flag
    private var threthold:Float = 80    // if power is bigger than threthold then volume indicator becomes biga
    private var scale:Float = 1.4       // maximum scale for volume indicator
    private var speed:Float = 0.05      // reducing time
    
    private var timer:NSTimer!          // timer for animation
    private var outFilter:Float = 1.0   // lowpass filter param for max volume
    private var peakDuration:Float = 0.1// keep peak value for in this interval
    private var peakTimer:Float = 0
    
    private var bScale:Float=1.03       // small indication for mic input
    private var bDuration:Float=2.5     // breathing duration
    
    var label: UILabel!
    
    private let Frequency:Float = 1.0/30.0
    private let MaxDB:Float = 110
    private let IconOuterSize1:CGFloat = 139
    private let IconOuterSize2:CGFloat = 113
    private let IconSize:CGFloat = 90
    private let IconSmallSize:CGFloat = 23
    private let SmallIconPadding:CGFloat = 33
    private let LabelHeight = 40
    
    private let ViewSize:CGFloat = 142
    var helperView:HelperView!
    
    private var viewState: DialogViewState {
        didSet {
            NSLog("\(viewState)")
        }
    }
    
    // public properties
    
    var state: DialogViewState {
        return viewState
    }
    
    var delegate: DialogViewDelegate? {
        didSet {
            if helperView != nil {
                helperView!.delegate = delegate
            }
        }
    }
    
    // public properties end
    
    
    override init() {
        self.viewState = .Unknown
    }
    
    func recognize() {
        dispatch_async(dispatch_get_main_queue()) {
            self.viewState.animTo(.Recognized, target: self)
        }
    }
    
    func speak() {
        dispatch_async(dispatch_get_main_queue()) {
            self.viewState.animTo(.Speaking, target: self)
        }
    }
    
    func listen() {
        dispatch_async(dispatch_get_main_queue()) {
            self.viewState.animTo(.Listening, target: self)
        }
    }
    
    func inactive() {
        dispatch_async(dispatch_get_main_queue()) {
            self.viewState.animTo(.Inactive, target: self)
        }
    }
    
    func tapped(state:DialogViewState) {
        delegate?.tapped(viewState)
    }
    
    func setup(view:UIView, position:CGPoint) {
        self.setup(view, position:position, tapEnabled:false);
    }
    
    func setup(view:UIView, position:CGPoint, tapEnabled:Bool) {
//        for direct layer rendering
//        let cx = position.x
//        let cy = position.y
//        let layerView = view
        
        helperView = HelperView(frame: CGRect(x: 0, y: 0, width: ViewSize, height: ViewSize))
        helperView.bTabEnabled = tapEnabled
        
        helperView.translatesAutoresizingMaskIntoConstraints = false;
        helperView.opaque = true
        let cx = ViewSize/2
        let cy = ViewSize/2
        let layerView = helperView
        
        view.addSubview(helperView)
        view.addConstraints([
            NSLayoutConstraint(
                item: helperView,
                attribute: .CenterX,
                relatedBy: .Equal,
                toItem: view,
                attribute: .Left,
                multiplier: 1.0,
                constant: position.x
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .CenterY  ,
                relatedBy: .Equal,
                toItem: view,
                attribute: .Top,
                multiplier: 1.0,
                constant: position.y
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .Width,
                relatedBy: .Equal,
                toItem: nil,
                attribute: .Width,
                multiplier: 1.0,
                constant: ViewSize
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .Height,
                relatedBy: .Equal,
                toItem: nil,
                attribute: .Height,
                multiplier: 1.0,
                constant: ViewSize
            )
            ])
        
        func make(size:CGFloat, max:CGFloat, x:CGFloat, y:CGFloat) -> AnimLayer {
            let layer = AnimLayer()
            layer.size = size
            layer.bounds = CGRect(x:0, y:0, width: max, height: max)
            layer.position = CGPoint(x:x, y:y)
            layerView.layer.addSublayer(layer)
            layer.setNeedsDisplay()
            return layer
        }
        
        
        back1 = make(IconOuterSize1, max: IconOuterSize1, x: cx, y: cy)
        back1.color = AnimLayer.gray
        back1.zPosition = 0
        back2 = make(IconOuterSize2, max: IconOuterSize2, x: cx, y: cy)
        back2.color = AnimLayer.white
        back2.zPosition = 1
        
        l1 = make(IconSmallSize, max:IconSize*3, x: cx, y: cy)
        l1.zPosition = 2
        l1.opacity = 0
        l2 = make(IconSmallSize, max:IconSmallSize*2, x: cx-SmallIconPadding, y: cy)
        l2.zPosition = 2
        l2.opacity = 0
        l3 = make(IconSmallSize, max:IconSmallSize*2, x: cx+SmallIconPadding, y: cy)
        l3.zPosition = 2
        l3.opacity = 0
        
        micback = make(IconSize, max:IconSize*2, x: cx, y: cy)
        micback.zPosition = 3
        micback.opacity = 0
        mic = CALayer()
        mic.zPosition = 4
        mic.opacity = 0
        micimgw = UIImage(named: "Mic_White")?.CGImage
        micimgr = UIImage(named: "Mic_Blue")?.CGImage
        mic.contents = micimgw
        mic.bounds = CGRect(x: 0, y: 0, width: 64, height: 64)
        mic.edgeAntialiasingMask = CAEdgeAntialiasingMask.LayerLeftEdge.union(CAEdgeAntialiasingMask.LayerRightEdge).union(CAEdgeAntialiasingMask.LayerTopEdge).union(CAEdgeAntialiasingMask.LayerBottomEdge)
        mic.position = CGPoint(x: cx, y: cy)
        layerView.layer.addSublayer(mic)

        
        label = UILabel(frame: CGRect(x: 0, y: 0, width: 1000, height: LabelHeight))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HelveticaNeue-Medium", size: 22)

        label.textAlignment = NSTextAlignment.Center
        label.alpha = 0.3
        label.text = ""
        view.addSubview(label)
        
        view.addConstraints([
            NSLayoutConstraint(
                item: label,
                attribute: .CenterX,
                relatedBy: .Equal,
                toItem: view,
                attribute: .CenterX,
                multiplier: 1.0,
                constant: 0
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .CenterY  ,
                relatedBy: .Equal,
                toItem: view,
                attribute: .Bottom,
                multiplier: 1.0,
                constant: CGFloat(-LabelHeight)
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .Width,
                relatedBy: .Equal,
                toItem: view,
                attribute: .Width,
                multiplier: 1.0,
                constant: 0
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .Height,
                relatedBy: .Equal,
                toItem: nil,
                attribute: .Height,
                multiplier: 1.0,
                constant: CGFloat(LabelHeight)
            )])
        
        //self.inactive()
    }
    
    func setMaxPower(p:Float) {
        power = p;
    }
    
    
    // remove all animations
    func reset() {
        timer?.invalidate()
        for l:CALayer in [back1, back2, l1, l2, l3, micback, mic] {
            l.removeAllAnimations()
        }
    }
    internal func removeFromSuperview(){
        if let ttm = self.textTimer{
            ttm.invalidate()
        }
        self.label.text = ""
        self.label.removeFromSuperview()
        self.helperView.removeFromSuperview()
        self.text = ""
    }
    
    // anim functions
    @objc private func recognizeAnim() {
        NSLog("recognize anim")
        reset()
        back2.color = AnimLayer.blue
        micback.color = AnimLayer.white
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        mic.contents = micimgr
        l1.opacity = 0
        l2.opacity = 0
        l3.opacity = 0
        micback.opacity = 1
        mic.opacity = 1
    }
    
    @objc private func listenpopAnim() {
        NSLog("pop anim")
        reset()
        l1.opacity = 1
        l2.opacity = 0
        l3.opacity = 0
        micback.opacity = 0
        mic.opacity = 0
        mic.contents = micimgw
        l1.size = 23
        micback.size = IconSize
        back2.color = AnimLayer.white
        micback.color = AnimLayer.blue
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        
        
        let a1 = AnimLayer.scale(0.1, current:1, scale:IconSize, type:kCAMediaTimingFunctionLinear)
        l1.addAnimation(a1, forKey: "scale")
        
        let a3 = AnimLayer.delay(AnimLayer.dissolve(0.1, type:kCAMediaTimingFunctionLinear), second:0.1);
        micback.addAnimation(a3, forKey: "dissolve")
        mic.addAnimation(a3, forKey: "dissolve")
        
        NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: #selector(DialogViewHelper.listenAnim), userInfo: nil, repeats: false)
    }
    
    @objc private func listenAnim() {
        NSLog("listen anim")
        reset()
        back2.color = AnimLayer.white
        micback.color = AnimLayer.blue
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        mic.opacity = 1
        mic.contents = micimgw
        l1.size = IconSize
        l1.opacity = 1
        l2.opacity = 0
        l3.opacity = 0
        micback.size = IconSize
        micback.opacity = 1
        
        let a2 = AnimLayer.pulse(Double(bDuration), size: IconSize, scale: CGFloat(bScale))
        a2.repeatCount = 10000000
        micback.addAnimation(a2, forKey: "listen-breathing")
        
        timer = NSTimer.scheduledTimerWithTimeInterval(Double(Frequency), target: self, selector: #selector(DialogViewHelper.listening(_:)), userInfo: nil, repeats: true)
    }
    
    @objc private func listening(timer:NSTimer) {
        var p:Float = power - threthold
        p = p / (MaxDB-threthold)
        p = max(p, 0)
        
        
        peakTimer -= Frequency
        
        if (peakTimer < 0) { // reduce max power gradually
            power -= MaxDB*Frequency/speed
            power = max(power, 0)
        }
        
        l1.size = min(CGFloat(p * (scale - 1.0) + 1.0) * IconSize, IconOuterSize2)
        //NSLog("\(p), \(scale), \(l1.size)")
        self.l1.setNeedsDisplay()
    }
    
    @objc private func shrinkAnim(sel:Selector) {
        if (mic.opacity == 0) {
            NSTimer.scheduledTimerWithTimeInterval(0, target: self, selector: sel, userInfo: nil, repeats: false)
            return
        }
        
        NSLog("shrink anim")
        reset()
        l1.opacity = 1
        l2.opacity = 0
        l3.opacity = 0
        micback.opacity = 1
        mic.opacity = 1
        mic.contents = micimgw
        back2.color = AnimLayer.white
        micback.color = AnimLayer.blue
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        
        let a1 = AnimLayer.dissolveOut(0.2, type: kCAMediaTimingFunctionEaseOut)
        let a2 = AnimLayer.scale(0.2, current: IconSize, scale: 0.0, type: kCAMediaTimingFunctionEaseOut)

        mic.addAnimation(a1, forKey: "shrink")
        micback.addAnimation(a1, forKey: "shrink")
        l1.addAnimation(a2, forKey: "shrink")
        l2.addAnimation(a2, forKey: "shrink")
        l3.addAnimation(a2, forKey: "shrink")
        
        
        NSTimer.scheduledTimerWithTimeInterval(0.3, target: self, selector: sel, userInfo: nil, repeats: false)
    }
    
    @objc private func speakpopAnim() {
        NSLog("speakpop anim")
        reset()
        l1.opacity = 1
        l2.opacity = 1
        l3.opacity = 1
        l1.size = 1;
        l2.size = 1;
        l3.size = 1;
        micback.opacity = 0
        mic.opacity = 0
        mic.contents = nil

        back2.color = AnimLayer.white
        micback.color = AnimLayer.blue
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        
        let dissolve = AnimLayer.dissolve(0.2, type: kCAMediaTimingFunctionEaseOut)
        let scale = AnimLayer.scale(0.2, current: 1, scale: CGFloat(IconSmallSize), type:kCAMediaTimingFunctionLinear)
        
        l2.addAnimation(dissolve, forKey: "speakpop1")
        l2.addAnimation(scale, forKey: "speakpop2")
        l1.addAnimation(dissolve, forKey: "speakpop1")
        l1.addAnimation(scale, forKey: "speakpop2")
        l3.addAnimation(dissolve, forKey: "speakpop1")
        l3.addAnimation(scale, forKey: "speakpop2")
        
        NSTimer.scheduledTimerWithTimeInterval(0.2, target: self,
                                               selector: #selector(DialogViewHelper.speakAnim),
                                               userInfo: nil, repeats: false)
    }

    @objc private func speakAnim() {
        NSLog("speak anim")
        reset()
        l1.opacity = 1
        l2.opacity = 1
        l3.opacity = 1
        l1.size = IconSmallSize;
        l2.size = IconSmallSize;
        l3.size = IconSmallSize;

        let pulse = AnimLayer.pulse(1/4.0, size: IconSmallSize, scale:1.03)
        pulse.repeatCount = 1000
        
        l2.addAnimation(pulse, forKey: "speak1")
        l1.addAnimation(pulse, forKey: "speak1")
        l3.addAnimation(pulse, forKey: "speak1")
    }
    
    @objc private func inactiveAnim() {
        reset()
        l1.opacity = 0
        l2.opacity = 0
        l3.opacity = 0
        micback.opacity = 0
        mic.opacity = 0
        mic.contents = micimgw
        l1.size = 23
        micback.size = IconSize
        back2.color = AnimLayer.white
        micback.color = AnimLayer.gray
        back2.setNeedsDisplay()
        micback.setNeedsDisplay()
        mic.contents = micimgr
        
        let a1 = AnimLayer.dissolve(0.2, type: kCAMediaTimingFunctionEaseOut)

        micback.addAnimation(a1, forKey: "inactive")
        mic.addAnimation(a1, forKey: "inactive")
    }
    
    // showing text
    
    var textTimer:NSTimer?
    var textPos:Int = 0
    var text:String?
    func showText(text:String) {
        
        let len = text.characters.count
        
        if let currentText = self.label.text {
            if currentText.characters.count < len ||
                self.label.text?.substringToIndex((self.label.text?.startIndex.advancedBy(len-1))!) != text {
                    textTimer?.invalidate()
                    textPos = (self.label.text?.characters.count)!
                    textTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(DialogViewHelper.showText2(_:)), userInfo: nil, repeats: true)
            }
        } else {
            self.label.text = text
        }
        self.text = text
        NSLog("showText: \(text)")
    }
    
    func showText2(timer:NSTimer) {
        self.textPos += 1
        var part = self.text
        if (self.textPos < self.text?.characters.count) {
            part = self.text?.substringToIndex((self.text?.startIndex.advancedBy(self.textPos-1))!)
        }
        dispatch_async(dispatch_get_main_queue()) {
 //           NSLog("showLabel: \(part)")
            self.label.text = part
        }
    }
    
    // utility function
    
    static func delay(delay:Double, callback: (Void)->Void) {
        let time = dispatch_time(DISPATCH_TIME_NOW, (Int64)(delay * Double(NSEC_PER_SEC)));
        dispatch_after(time, dispatch_get_main_queue()) {
            callback()
        }
    }
}

