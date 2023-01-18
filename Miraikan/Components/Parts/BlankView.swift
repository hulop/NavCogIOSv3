//
//
//  BlankView.swift
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

/**
 A blank page for functions not implemented
 */
class BlankView: BaseView {

    private let lblDesc = UILabel()

    override func setup() {
        super.setup()

        lblDesc.text = NSLocalizedString("blank_description", comment: "")
        lblDesc.lineBreakMode = .byWordWrapping
        lblDesc.textAlignment = .center
        lblDesc.numberOfLines = 0
        lblDesc.font = .preferredFont(forTextStyle: .headline)
        lblDesc.frame.size.width = UIScreen.main.bounds.width
        lblDesc.frame.size.height = UIScreen.main.bounds.height
        lblDesc.sizeToFit()
        lblDesc.center = self.center
        addSubview(lblDesc)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        lblDesc.frame = CGRect(x: (self.frame.width - lblDesc.frame.width) / 2,
                               y: (self.frame.height - lblDesc.frame.height) / 2,
                               width: lblDesc.frame.width,
                               height: lblDesc.frame.height)
    }
}
