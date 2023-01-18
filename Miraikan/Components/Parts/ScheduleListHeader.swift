//
//
//  ScheduleListHeader.swift
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

/**
 The header that displays today's date
 */
class ScheduleListHeader: BaseView {

    private let lblDate = UILabel()

    private let padding: CGFloat = 10

    override func setup() {
        super.setup()
        
        let todayText = MiraikanUtil.todayText()
        lblDate.text = todayText.string
        lblDate.accessibilityLabel = todayText.accessibility
        lblDate.font = .preferredFont(forTextStyle: .headline)
        lblDate.sizeToFit()
        addSubview(lblDate)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        lblDate.center.y = self.center.y
        lblDate.frame.origin.x = padding
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = padding * 2 + lblDate.frame.height
        return CGSize(width: size.width, height: height)
    }
}
