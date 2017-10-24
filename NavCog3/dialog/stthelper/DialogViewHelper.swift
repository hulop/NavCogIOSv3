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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


enum DialogViewState:String {
    case Unknown = "unknown"
    case Inactive = "inactive"
    case Speaking = "speaking"
    case Listening = "listening"
    case Recognized = "recognized"
    
    mutating func animTo(_ state:DialogViewState, target:DialogViewHelper) {
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

@objc protocol DialogViewDelegate {
    func tapped();
}

class HelperView: UIView {
    var delegate: DialogViewDelegate?
    var bTabEnabled:Bool=false  // tap availability
    var disabled:Bool = false {
        didSet {
            self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitStaticText
            if (disabled) {
                self.accessibilityTraits = self.accessibilityTraits | UIAccessibilityTraitNotEnabled
                self.layer.opacity = 0.25
            } else {
                self.layer.opacity = 1.0
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.accessibilityLabel = NSLocalizedString("DialogSearch", tableName:"BlindView", comment:"")
        self.isAccessibilityElement = true
        self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitStaticText | UIAccessibilityTraitNotEnabled
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
 
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (self.disabled) {
            return;
        }
        self.layer.opacity = 0.5
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (self.disabled) {
            return;
        }
        self.layer.opacity = 1.0
        delegate?.tapped()
    }
}

class DialogViewHelper: NSObject {
    fileprivate var initialized: Bool = false
    
    fileprivate var back1: AnimLayer!       // first circle
    fileprivate var back2: AnimLayer!       // second circle
    fileprivate var l1: AnimLayer!          // speak indicator center / volume indicator
    fileprivate var l2: AnimLayer!          // speak indicator left
    fileprivate var l3: AnimLayer!          // speak indicator right
    fileprivate var micback: AnimLayer!     // mic background
    fileprivate var mic: CALayer!           // mic image
    fileprivate var micimgw:CGImage!        // mic white image
    fileprivate var micimgr:CGImage!        // mic red image
    fileprivate var power:Float = 0.0       // mic audio power
    fileprivate var recording = false       // recording flag
    fileprivate var threthold:Float = 80    // if power is bigger than threthold then volume indicator becomes biga
    fileprivate var scale:Float = 1.4       // maximum scale for volume indicator
    fileprivate var speed:Float = 0.05      // reducing time
    
    fileprivate var timer:Timer!          // timer for animation
    fileprivate var outFilter:Float = 1.0   // lowpass filter param for max volume
    fileprivate var peakDuration:Float = 0.1// keep peak value for in this interval
    fileprivate var peakTimer:Float = 0
    
    fileprivate var bScale:Float=1.03       // small indication for mic input
    fileprivate var bDuration:Float=2.5     // breathing duration
    
    var label: UILabel!
    
    fileprivate let Frequency:Float = 1.0/30.0
    fileprivate let MaxDB:Float = 110
    fileprivate var IconOuterSize1:CGFloat = 139
    fileprivate var IconOuterSize2:CGFloat = 113
    fileprivate var IconSize:CGFloat = 90
    fileprivate var IconSmallSize:CGFloat = 23
    fileprivate var SmallIconPadding:CGFloat = 33
    fileprivate var LabelHeight:CGFloat = 40
    fileprivate var ImageSize:CGFloat = 64
    
    fileprivate var ViewSize:CGFloat = 142
    var helperView:HelperView!
    var transparentBack:Bool = false
    var layerScale:CGFloat = 1.0 {
        didSet {
            IconOuterSize1 = 139 * layerScale
            IconOuterSize2 = 113 * layerScale
            IconSize = 90 * layerScale
            IconSmallSize = 23 * layerScale
            SmallIconPadding = 33 * layerScale
            LabelHeight = 40 * layerScale
            ViewSize = 142 * layerScale
            ImageSize = 64 * layerScale
        }
    }
    
    fileprivate var viewState: DialogViewState {
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
        DispatchQueue.main.async {
            self.viewState.animTo(.Recognized, target: self)
        }
    }
    
    func speak() {
        DispatchQueue.main.async {
            self.viewState.animTo(.Speaking, target: self)
        }
    }
    
    func listen() {
        DispatchQueue.main.async {
            self.viewState.animTo(.Listening, target: self)
        }
    }
    
    func inactive() {
        DispatchQueue.main.async {
            self.viewState.animTo(.Inactive, target: self)
        }
    }
    
    func tapped() {
        delegate?.tapped()
    }
    
    func setup(_ view:UIView, position:CGPoint) {
        self.setup(view, position:position, tapEnabled:false);
    }
    
    func setup(_ view:UIView, position:CGPoint, tapEnabled:Bool) {
//        for direct layer rendering
//        let cx = position.x
//        let cy = position.y
//        let layerView = view
        
        helperView = HelperView(frame: CGRect(x: 0, y: 0, width: ViewSize, height: ViewSize))
        helperView.bTabEnabled = tapEnabled
        
        helperView.translatesAutoresizingMaskIntoConstraints = false;
        helperView.isOpaque = true
        let cx = ViewSize/2
        let cy = ViewSize/2
        let layerView = helperView
        
        view.addSubview(helperView)
        view.addConstraints([
            NSLayoutConstraint(
                item: helperView,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: view,
                attribute: .left,
                multiplier: 1.0,
                constant: position.x
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .centerY  ,
                relatedBy: .equal,
                toItem: view,
                attribute: .top,
                multiplier: 1.0,
                constant: position.y
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .width,
                relatedBy: .equal,
                toItem: nil,
                attribute: .width,
                multiplier: 1.0,
                constant: ViewSize
            ),
            NSLayoutConstraint(
                item: helperView,
                attribute: .height,
                relatedBy: .equal,
                toItem: nil,
                attribute: .height,
                multiplier: 1.0,
                constant: ViewSize
            )
            ])
        
        func make(_ size:CGFloat, max:CGFloat, x:CGFloat, y:CGFloat) -> AnimLayer {
            let layer = AnimLayer()
            layer.size = size
            layer.bounds = CGRect(x:0, y:0, width: max, height: max)
            layer.position = CGPoint(x:x, y:y)
            layerView?.layer.addSublayer(layer)
            layer.setNeedsDisplay()
            return layer
        }
        
        
        back1 = make(IconOuterSize1, max: IconOuterSize1, x: cx, y: cy)
        back1.color = transparentBack ?AnimLayer.transparent:AnimLayer.gray
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
        micimgw = UIImage(named: "Mic_White")?.cgImage
        micimgr = UIImage(named: "Mic_Blue")?.cgImage
        mic.contents = micimgw
        mic.bounds = CGRect(x: 0, y: 0, width: ImageSize, height: ImageSize)
        mic.edgeAntialiasingMask = CAEdgeAntialiasingMask.layerLeftEdge.union(CAEdgeAntialiasingMask.layerRightEdge).union(CAEdgeAntialiasingMask.layerTopEdge).union(CAEdgeAntialiasingMask.layerBottomEdge)
        mic.position = CGPoint(x: cx, y: cy)
        layerView?.layer.addSublayer(mic)

        
        label = UILabel(frame: CGRect(x: 0, y: 0, width: 1000, height: LabelHeight))
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "HelveticaNeue-Medium", size: 22)

        label.textAlignment = NSTextAlignment.center
        label.alpha = 0.3
        label.text = ""
        view.addSubview(label)
        
        view.addConstraints([
            NSLayoutConstraint(
                item: label,
                attribute: .centerX,
                relatedBy: .equal,
                toItem: view,
                attribute: .centerX,
                multiplier: 1.0,
                constant: 0
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .centerY  ,
                relatedBy: .equal,
                toItem: view,
                attribute: .bottom,
                multiplier: 1.0,
                constant: CGFloat(-LabelHeight)
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .width,
                relatedBy: .equal,
                toItem: view,
                attribute: .width,
                multiplier: 1.0,
                constant: 0
            ),
            NSLayoutConstraint(
                item: label,
                attribute: .height,
                relatedBy: .equal,
                toItem: nil,
                attribute: .height,
                multiplier: 1.0,
                constant: CGFloat(LabelHeight)
            )])
        
        //self.inactive()
        
        initialized = true
    }
    
    func setMaxPower(_ p:Float) {
        power = p;
    }
    
    
    // remove all animations
    func reset() {
        timer?.invalidate()
        if initialized == false {
            return
        }
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
    @objc fileprivate func recognizeAnim() {
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
    
    @objc fileprivate func listenpopAnim() {
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
        l1.add(a1, forKey: "scale")
        
        let a3 = AnimLayer.delay(AnimLayer.dissolve(0.1, type:kCAMediaTimingFunctionLinear), second:0.1);
        micback.add(a3, forKey: "dissolve")
        mic.add(a3, forKey: "dissolve")
        
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(DialogViewHelper.listenAnim), userInfo: nil, repeats: false)
    }
    
    @objc fileprivate func listenAnim() {
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
        micback.add(a2, forKey: "listen-breathing")
        
        timer = Timer.scheduledTimer(timeInterval: Double(Frequency), target: self, selector: #selector(DialogViewHelper.listening(_:)), userInfo: nil, repeats: true)
    }
    
    @objc fileprivate func listening(_ timer:Timer) {
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
    
    @objc fileprivate func shrinkAnim(_ sel:Selector) {
        if (mic.opacity == 0) {
            Timer.scheduledTimer(timeInterval: 0, target: self, selector: sel, userInfo: nil, repeats: false)
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

        mic.add(a1, forKey: "shrink")
        micback.add(a1, forKey: "shrink")
        l1.add(a2, forKey: "shrink")
        l2.add(a2, forKey: "shrink")
        l3.add(a2, forKey: "shrink")
        
        
        Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: sel, userInfo: nil, repeats: false)
    }
    
    @objc fileprivate func speakpopAnim() {
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
        
        l2.add(dissolve, forKey: "speakpop1")
        l2.add(scale, forKey: "speakpop2")
        l1.add(dissolve, forKey: "speakpop1")
        l1.add(scale, forKey: "speakpop2")
        l3.add(dissolve, forKey: "speakpop1")
        l3.add(scale, forKey: "speakpop2")
        
        Timer.scheduledTimer(timeInterval: 0.2, target: self,
                                               selector: #selector(DialogViewHelper.speakAnim),
                                               userInfo: nil, repeats: false)
    }

    @objc fileprivate func speakAnim() {
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
        
        l2.add(pulse, forKey: "speak1")
        l1.add(pulse, forKey: "speak1")
        l3.add(pulse, forKey: "speak1")
    }
    
    @objc fileprivate func inactiveAnim() {
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

        micback.add(a1, forKey: "inactive")
        mic.add(a1, forKey: "inactive")
    }
    
    // showing text
    
    var textTimer:Timer?
    var textPos:Int = 0
    var text:String?
    func showText(_ text:String) {
        
        let len = text.characters.count
        
        if let currentText = self.label.text {
            if currentText.characters.count < len ||
                self.label.text?.substring(to: (self.label.text?.characters.index((self.label.text?.startIndex)!, offsetBy: len-1))!) != text {
                    textTimer?.invalidate()
                    textPos = (self.label.text?.characters.count)!
                    textTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(DialogViewHelper.showText2(_:)), userInfo: nil, repeats: true)
            }
        } else {
            self.label.text = text
        }
        self.text = text
        NSLog("showText: \(text)")
    }
    
    func showText2(_ timer:Timer) {
        self.textPos += 1
        var part = self.text
        if (self.textPos < self.text?.characters.count) {
            part = self.text?.substring(to: (self.text?.characters.index((self.text?.startIndex)!, offsetBy: self.textPos-1))!)
        }
        DispatchQueue.main.async {
 //           NSLog("showLabel: \(part)")
            self.label.text = part
        }
    }
    
    // utility function
    
    static func delay(_ delay:Double, callback: @escaping (Void)->Void) {
        let time = DispatchTime.now() + Double((Int64)(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC);
        DispatchQueue.main.asyncAfter(deadline: time) {
            callback()
        }
    }
}

