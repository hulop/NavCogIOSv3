//
//  Label.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2021 © Miraikan - The National Museum of Emerging Science and Innovation
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

// TODO: byWordWrapping for English version
/**
 A label that automatically wrap its text to fit the size
 */
class AutoWrapLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.numberOfLines = 0
        self.lineBreakMode = .byWordWrapping
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/**
 A AutoWrapLabel underlined which looks like an HTML link
 */
class UnderlinedLabel: AutoWrapLabel {

    private var action: ((UnderlinedLabel) -> ())?

    public var title: String? {
        didSet {
            if let title = title {
                setText(title)
            }
        }
    }

    init(_ text: String? = nil) {
        super.init(frame: .zero)
        if let text = text {
            setText(text)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setText(_ text: String) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let str = NSMutableAttributedString(string: text,
                                            attributes: attr)
        self.attributedText = str
    }

    public func openView(_ action: @escaping ((UnderlinedLabel) -> ())) {
        self.action = action
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(tap)
    }

    @objc private func tapAction() {
        if let f = action {
            f(self)
        }
    }
}
