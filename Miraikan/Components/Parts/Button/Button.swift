//
//
//  Button.swift
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

import Foundation
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

/**
 A UIBarButtonItem with easier access to the action
 */
class BaseBarButton: UIBarButtonItem {
    
    private var _action: (()->())?
    
    init(image: UIImage?) {
        super.init()
        self.image = image
        self.target = self
        self.style = .done
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func tapAction(_ action: @escaping (()->())) {
        self._action = action
        self.action = #selector(_tapAction)
    }
    
    @objc private func _tapAction() {
        if let _f = _action {
            _f()
        }
    }
}

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
