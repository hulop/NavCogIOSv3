//
//  AboutAppView.swift
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
 The about screen for this app.
 
 The copyright references should be placed here.
 */
class AboutAppView: BaseView {
    
    private let lblIcon8 = UILabel()
    private let lblVersion = UILabel()
    private let lblCrossProduct = UILabel()

    // Sizing
    private let gapX: CGFloat = 10
    private let gapY: CGFloat = 15

    override func setup() {
        super.setup()
        
        lblIcon8.text = "Free Icons Retreived from: https://icons8.com for TabBar and NavBar. ウォーキング, 車椅子, ベビーカー, 視覚障害者のアクセス icon by Icons8"
        lblIcon8.lineBreakMode = .byWordWrapping
        lblIcon8.numberOfLines = 0
        lblIcon8.font = .preferredFont(forTextStyle: .callout)
        lblIcon8.sizeToFit()
        addSubview(lblIcon8)

        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            lblVersion.text = "Version: \(version)    Buld: \(build)"
            lblVersion.lineBreakMode = .byWordWrapping
            lblVersion.numberOfLines = 0
            lblIcon8.font = .preferredFont(forTextStyle: .callout)
            lblVersion.sizeToFit()
            addSubview(lblVersion)
        }
        
        lblCrossProduct.text = "GeoUtils.swift\nPiece of code for calculating the intersection of two 2D vectors.\nhttps://gist.github.com/codelynx/80077dbbb07e7d989016188573eab880"
        lblCrossProduct.lineBreakMode = .byWordWrapping
        lblCrossProduct.numberOfLines = 0
        lblCrossProduct.font = .preferredFont(forTextStyle: .callout)
        lblCrossProduct.sizeToFit()
        addSubview(lblCrossProduct)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        var y = insets.top + gapY
        var szFit = CGSize.zero

        szFit = CGSize(width: innerSize.width, height: lblVersion.intrinsicContentSize.height)
        lblVersion.frame = CGRect(x: insets.left + gapX,
                                y: y,
                                width: innerSize.width - gapX * 2,
                                height: lblVersion.sizeThatFits(szFit).height)
        y += lblVersion.frame.height + gapY

        szFit = CGSize(width: innerSize.width, height: lblIcon8.intrinsicContentSize.height)
        lblIcon8.frame = CGRect(x: insets.left + gapX,
                                y: y,
                                width: innerSize.width - gapX * 2,
                                height: lblIcon8.sizeThatFits(szFit).height)
        y += lblIcon8.frame.height + gapY
        
        szFit = CGSize(width: innerSize.width, height: lblCrossProduct.intrinsicContentSize.height)
        lblCrossProduct.frame = CGRect(x: insets.left + gapX,
                                y: y,
                                width: innerSize.width - gapX * 2,
                                height: lblCrossProduct.sizeThatFits(szFit).height)
        y += lblCrossProduct.frame.height + gapY
    }
}
