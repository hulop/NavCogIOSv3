//
//  BaseButton.swift
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
 A button with swift style tap action implemented for easier use
 */
class BaseButton: UIButton {
    
    private var action: ((UIButton)->())?

    override init(frame: CGRect) {
      super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
    }

    @objc public func tapAction(_ action: @escaping ((UIButton)->())) {
        self.action = action
        self.addTarget(self, action: #selector(_pressAction(_:)), for: .touchDown)
        self.addTarget(self, action: #selector(_tapAction(_:)), for: .touchUpInside)
    }
    
    @objc private func _pressAction(_ sender: UIButton) {
        self.backgroundColor = .lightGray
    }

    @objc private func _tapAction(_ sender: UIButton) {
        
        UIView.animate(withDuration: 0.1, animations: { [weak self] in
            guard let self = self else { return }
            self.backgroundColor = .lightGray
        }, completion: { [weak self] finished in
            guard let self = self else { return }
            if finished, let _f = self.action {
                self.backgroundColor = .white
                _f(self)
            }
        })
    }
}
