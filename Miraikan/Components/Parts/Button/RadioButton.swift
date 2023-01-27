//
//  RadioButton.swift
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
 A button for HTML style RadioGroup
 */
class RadioButton: UIButton {
    
    private var action: ((UIButton)->())?

    var isChecked: Bool {
        didSet {
            setImage()
            layoutSubviews()
        }
    }

    private let radioSize = CGSize(width: 30, height: 30)
    private var img: UIImage?

    override init(frame: CGRect) {
        isChecked = false
        super.init(frame: frame)
        setImage()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setImage() {
        let imgName = isChecked ? "icons8-checked-radio-button" : "icons8-unchecked-radio-button"
        img = UIImage(named: imgName)
        self.titleLabel?.sizeToFit()
        self.setImage(img, for: .normal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let imageAdaptor = ImageAdaptor(img: img)
        let rescaledSize = imageAdaptor.scaleImage(viewSize: radioSize,
                                                   frameWidth: radioSize.width)
        self.imageView?.frame = CGRect(origin: .zero, size: rescaledSize)
        self.titleLabel?.frame.size = CGSize(width: self.frame.width - radioSize.width,
                                             height: self.titleLabel!.intrinsicContentSize.height)
        self.titleLabel?.frame.origin.x = radioSize.width + CGFloat(10)
        self.titleLabel?.center.y = self.imageView!.center.y
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = min(radioSize.height, self.titleLabel!.intrinsicContentSize.height)
        return CGSize(width: size.width, height: height)
    }

    @objc public func tapAction(_ action: @escaping ((UIButton)->())) {
        self.action = action
        self.addTarget(self, action: #selector(_tapAction(_:)), for: .touchUpInside)
    }
    
    @objc private func _tapAction(_ sender: UIButton) {
        if let _f = self.action {
            _f(self)
        }
    }
}
