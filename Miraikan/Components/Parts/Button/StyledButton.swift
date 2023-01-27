//
//  StyledButton.swift
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
 A BaseButton that styled as Navigation Button
 */
@IBDesignable
class StyledButton: UIButton {
    
    @IBInspectable var mainColor = UIColor.systemBlue
    @IBInspectable var subColor = UIColor.systemBackground

    private var action: ((UIButton)->())?
    
    var paddingX: CGFloat {
        return self.titleEdgeInsets.left + self.titleEdgeInsets.right
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setup()
    }

    private func setup() {
        setupDesign()
        setupAction()
    }

    private func setupDesign() {
        self.setTitleColor(mainColor, for: .normal)
        self.setTitleColor(subColor, for: .highlighted)
        self.setBackgroundImage(subColor.createColorImage(), for: .normal)
        self.setBackgroundImage(mainColor.createColorImage(), for: .highlighted)
        self.clipsToBounds = true
        self.layer.cornerRadius = 5
        self.layer.borderWidth = 1
        self.layer.borderColor = mainColor.cgColor
        self.contentEdgeInsets = UIEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)
    }

    private func setupAction() {
        self.addTarget(self, action: #selector(_touchUpInside(_:)), for: .touchUpInside)
    }

    @objc private func _touchUpInside(_ sender: UIButton) {
        if let _f = self.action {
            _f(self)
        }
    }

    @objc public func tapAction(_ action: @escaping ((UIButton)->())) {
        self.action = action
    }
}
