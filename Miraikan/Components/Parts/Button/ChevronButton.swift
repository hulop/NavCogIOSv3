//
//  ChevronButton.swift
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

import UIKit

/**
 A BaseButton with chevron.right icon (arrow) for links
 */
class ChevronButton: BaseButton {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.titleLabel?.numberOfLines = 0
        self.titleLabel?.lineBreakMode = .byWordWrapping
        self.setImage(UIImage(systemName: "chevron.right"), for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let labelWidth = self.frame.width - self.imageView!.frame.width
        let labelSz = CGSize(width: labelWidth,
                             height: self.titleLabel!.intrinsicContentSize.height)
        self.titleLabel?.frame.size = self.titleLabel!.sizeThatFits(labelSz)
        
        let midY = max(self.titleLabel!.frame.height, self.imageView!.frame.height) / 2
        self.titleLabel?.frame.origin.x = self.safeAreaInsets.left
        self.titleLabel?.center.y = midY
        self.imageView?.frame.origin.x = self.safeAreaInsets.left + self.titleLabel!.frame.width
        self.imageView?.center.y = midY
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelWidth = size.width - self.imageView!.frame.width
        let labelSz = CGSize(width: labelWidth,
                             height: self.titleLabel!.intrinsicContentSize.height)
        let height = max(self.titleLabel!.sizeThatFits(labelSz).height,
                         imageView!.frame.height)
        return CGSize(width: size.width, height: height)
    }
}
