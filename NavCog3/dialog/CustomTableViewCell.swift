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

class CustomLeftTableViewCell: UITableViewCell
{
    var icon: UIImageView = UIImageView()
    var name: UILabel = UILabel()
    var bNoIcon: Bool = true              // hide icon
    
    var arrow: CustomLeftArrow?
    var message: UILabel = UILabel()
    var viewMessage: UIView = UIView()
    
    var marginLeft: CGFloat?
    var marginRight: CGFloat?
    var marginVertical: CGFloat?
    var paddingHorizontal: CGFloat?
    var paddingVertical: CGFloat?
    var widthMax: CGFloat?
    
    var strokeColor:UIColor? = UIColor.black
    var fillColor:UIColor? = UIColor.white
    var fontColor:UIColor? = UIColor.black
    
    let borderWidth:CGFloat = 0.5
    
    func initstyle(){
        self.arrow =  CustomLeftArrow()
        self.marginLeft = bNoIcon ?30:60
        self.marginRight = 0
        self.marginVertical = 30
        self.paddingHorizontal = 10
        self.paddingVertical = 10
    }
    
    required init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)!
        self.selectionStyle = UITableViewCellSelectionStyle.none
        self.initstyle()
    }
    override init(style: UITableViewCellStyle, reuseIdentifier: String?)
    {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = UITableViewCellSelectionStyle.none
        
        self.initstyle()

        self.viewMessage.layer.borderWidth = borderWidth
        self.viewMessage.layer.cornerRadius = 10.0
        
        self.message.font = UIFont.systemFont(ofSize: 15)
        self.message.numberOfLines = 0
        
        self.viewMessage.addSubview(self.message)
        self.contentView.addSubview(self.viewMessage)
        
        self.addSubview(self.arrow!)
        
        self.icon.layer.borderColor = UIColor.black.cgColor
        self.icon.layer.borderWidth = borderWidth

        self.addSubview(self.icon)
                
        self.name.font = UIFont.boldSystemFont(ofSize: 14)
        
        self.name.textAlignment = NSTextAlignment.left
        self.addSubview(self.name)

    }
    func drawOriginator(_ data: Dictionary<String,Any>){
        let icymargin:CGFloat = 8
        let xIcon: CGFloat = 3
        let yIcon: CGFloat = 3 + icymargin
        let widthIcon: CGFloat = bNoIcon ?0:48
        let heightIcon: CGFloat = bNoIcon ?0:48
        self.icon.frame = CGRect(x: xIcon, y: yIcon, width: widthIcon, height: heightIcon)
        self.icon.image = UIImage(named: (data["image"] as? String)!)
        self.icon.layer.cornerRadius = self.icon.frame.size.width * 0.5
        self.icon.clipsToBounds = true
        
        let xName: CGFloat = self.icon.frame.origin.x + self.icon.frame.size.width + 3
        let yName: CGFloat = self.icon.frame.origin.y - icymargin
        let widthName: CGFloat = self.widthMax! - (self.icon.frame.origin.x + self.icon.frame.size.width + 3)
        let heightName: CGFloat = 30
        self.name.text = data["name"] as? String
        self.name.frame = CGRect(x: xName, y: yName, width: widthName, height: heightName)
    }
    func syncColors(){
        self.viewMessage.layer.borderColor = self.strokeColor?.cgColor
        self.viewMessage.backgroundColor = self.fillColor

        self.message.backgroundColor = self.fillColor
        self.message.textColor = self.fontColor
        
        self.arrow!.backgroundColor = self.backgroundColor
        self.arrow!.fillColor = self.fillColor
        self.arrow!.strokeColor = self.strokeColor
    }
    func layoutMessageArea(){
        let xMessageView: CGFloat = marginLeft!
        let yMessageView: CGFloat = marginVertical!
        let widthMessageView: CGFloat = self.message.frame.size.width + paddingHorizontal! * 2
        let heightMessageView: CGFloat = self.message.frame.size.height + paddingVertical! * 2
        self.viewMessage.frame = CGRect(x: xMessageView, y: yMessageView, width: widthMessageView, height: heightMessageView)
        
        let widthArrow: CGFloat = 10
        let heightArrorw: CGFloat = 10
        let xArrow: CGFloat = marginLeft! - widthArrow + 1
        let yArrow: CGFloat = self.viewMessage.frame.origin.y + heightArrorw
        self.arrow!.frame = CGRect(x: xArrow, y: yArrow, width: widthArrow, height: heightArrorw)
    }
    
    func drawMessageText(_ text:String, x:CGFloat, y:CGFloat, width:CGFloat, height: CGFloat){
        self.message.frame = CGRect(x: x,y: y,width: width,height: height)
        self.message.text = text
        self.message.sizeToFit()
        self.layoutMessageArea()
    }
    func setData(_ widthMax: CGFloat,data: Dictionary<String,Any>) -> CGFloat
    {
        self.widthMax = widthMax
        self.syncColors()
        self.drawOriginator(data)
        
        self.drawMessageText(data["message"] as! String,
                             x: paddingHorizontal!,
                             y: paddingVertical!,
                             width: self.widthMax! - (marginLeft! + marginRight! + paddingHorizontal! * 2),
                             height: 0)
        
        self.layoutMessageArea()
        let height: CGFloat = self.viewMessage.frame.height + marginVertical! * 2
        return height
    }
}

class CustomLeftTableViewCellSpeaking : CustomLeftTableViewCell{
    var textbuff:String?
    var timer:Timer?

    internal func showAllText(){
        if let timer = self.timer{
            timer.invalidate()
        }
        self.timer = nil
        self.message.text = self.textbuff
        self.message.sizeToFit()
        self.layoutMessageArea()
    }
    override func drawMessageText(_ text:String, x:CGFloat, y:CGFloat, width:CGFloat, height: CGFloat){
        self.textbuff = text
        let len:Int = text.characters.count
        let sidx:String.Index = text.startIndex
        var idx:Int = 1
        
        self.timer = Timer.scheduledTimer(timeInterval: 0.15, target: BlockOperation(block: {
            if idx >= len{
                self.showAllText()
            }else{
                self.message.frame = CGRect(x: x, y: y, width: width, height: height)
                self.message.text = text.substring(to: text.index(sidx, offsetBy: idx))
                self.message.sizeToFit()
                self.layoutMessageArea()
                idx = idx + 1
            }
        }), selector: #selector(Operation.main), userInfo:nil, repeats:true)
    }
}
class CustomRightTableViewCell : CustomLeftTableViewCell{
    override func initstyle() {
        self.arrow =  CustomRightArrow()
        self.marginLeft = 0
        self.marginRight = 0
        self.marginVertical = 1
        self.paddingHorizontal = 10
        self.paddingVertical = 10
    }
    override func drawOriginator(_ data: Dictionary<String,Any>){
    //NOP
    }
    override func layoutMessageArea(){
        let yMessageView: CGFloat = marginVertical!
        let widthMessageView: CGFloat = self.message.frame.size.width + paddingHorizontal! * 2
        let heightMessageView: CGFloat = self.message.frame.size.height + paddingVertical! * 2
        let xMessageView: CGFloat = self.widthMax! - widthMessageView - marginRight!
        self.viewMessage.frame = CGRect(x: xMessageView, y: yMessageView, width: widthMessageView, height: heightMessageView)
        
        let widthArrow: CGFloat = 10
        let heightArrorw: CGFloat = 10
        let xArrow: CGFloat = self.widthMax! - marginRight! - 1// - widthArrow + 1
        let yArrow: CGFloat = self.viewMessage.frame.origin.y + heightArrorw
        self.arrow!.frame = CGRect(x: xArrow, y: yArrow, width: widthArrow, height: heightArrorw)
    }


}
