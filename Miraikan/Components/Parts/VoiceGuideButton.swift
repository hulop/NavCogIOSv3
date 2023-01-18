//
//
//  VoiceGuideButton.swift
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

class VoiceGuideButton: UIButton {

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
        self.backgroundColor = .white
        self.layer.cornerRadius = 30

        self.layer.borderColor = UIColor(red: 105/255, green: 0, blue: 50/255, alpha: 1).cgColor
        self.layer.borderWidth = 6.0

        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.3
        self.layer.shadowRadius = 5.0
        self.layer.shadowOffset = CGSize(width: 5.0, height: 5.0)

        self.titleLabel?.numberOfLines = 0

        self.setTitleColor(.black, for: .normal)
        self.setTitle(NSLocalizedString("Voice Guide Off", comment: ""), for: .normal)
        self.setTitle(NSLocalizedString("Voice Guide On", comment: ""), for: .selected)
        self.titleLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        self.titleLabel?.textAlignment = .center

        self.setImage(UIImage(named: "icons8-mute"), for: .normal)
        self.setImage(UIImage(named: "icons8-sound"), for: .selected)
        
        self.imageEdgeInsets = UIEdgeInsets(top: 0, left: 30, bottom: 30, right: 0)
        self.titleEdgeInsets = UIEdgeInsets(top: 30, left: -20, bottom: 0, right: 0)

        self.isSelected = UserDefaults.standard.bool(forKey: "isVoiceGuideOn")
    }

    private func setupAction() {
        self.addTarget(self, action: #selector(self.buttonTapped(_:)), for: .touchUpInside)
    }

    @objc func buttonTapped(_ sender: UIButton) {
        let isOn = !sender.isSelected
        sender.isSelected = isOn
        UserDefaults.standard.set(isOn, forKey: "isVoiceGuideOn")
        AudioGuideManager.shared.isActive(isOn)
    }

    func isDisplayButton(_ isDisplay: Bool) {
        if (self.alpha == 1) == isDisplay {
            return
        }

        DispatchQueue.main.async{
            self.alpha = isDisplay ? 0 : 1
            UIView.animate(withDuration: 0.1, animations: { [weak self] in
                guard let self = self else { return }
                self.alpha = isDisplay ? 1 : 0
            })
        }
    }
}
