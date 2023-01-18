//
//
//  ContentRow.swift
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
 The customized UITableViewCell for each exhibition
 */
class ContentRow: BaseRow {

    private let lblDescription = AutoWrapLabel()
    private var lblOverview = AutoWrapLabel()

    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 10

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        [lblDescription, lblOverview].forEach({
            $0.isAccessibilityElement = true
            addSubview($0)
        })

        selectionStyle = .none
    }

    public func configure(_ model: ExhibitionContentModel) {
        
        lblDescription.font = .preferredFont(forTextStyle: .body)
        lblOverview.font = .preferredFont(forTextStyle: .body)

        if MiraikanUtil.routeMode != .blind {
            lblDescription.text = model.intro
            lblOverview.isHidden = true
            lblOverview.isAccessibilityElement = false
        } else {
            lblDescription.text = model.blindIntro.isEmpty
                ? model.blindIntro
                : NSLocalizedString("Description", comment: "") + "\n\(model.blindIntro)\n"
            lblDescription.accessibilityLabel = lblDescription.text?.replacingOccurrences(of: "・", with: "")

            lblOverview.text = model.blindOverview.isEmpty
                ? model.blindOverview
                : NSLocalizedString("Overview", comment: "") + "\n\(model.blindOverview)"
            lblOverview.accessibilityLabel = lblOverview.text?.replacingOccurrences(of: "・", with: "")

            let islblDescription = lblDescription.text?.isEmpty ?? true
            lblDescription.isHidden = islblDescription
            lblDescription.isAccessibilityElement = !islblDescription
            
            let islblOverview = lblOverview.text?.isEmpty ?? true
            lblOverview.isHidden = islblOverview
            lblOverview.isAccessibilityElement = !islblOverview
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        lblDescription.text = nil
        lblOverview.text = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        let innerSz = CGSize(width: innerSize.width - gapX * 2, height: innerSize.height)
        var y = insets.top
        lblDescription.frame = CGRect(x: insets.left + gapX,
                                      y: y,
                                      width: innerSize.width - gapX * 2,
                                      height: lblDescription.sizeThatFits(innerSz).height)

        if MiraikanUtil.routeMode == .blind {
            y += lblDescription.frame.height
            lblOverview.frame = CGRect(x: insets.left + gapX,
                                       y: y,
                                       width: innerSize.width - gapX * 2,
                                       height: lblOverview.sizeThatFits(innerSz).height)
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let innerSz = CGSize(width: innerSize.width - gapX * 2, height: innerSize.height)

        var height = insets.top + lblDescription.sizeThatFits(innerSz).height
        if MiraikanUtil.routeMode == .blind {
            height += lblOverview.sizeThatFits(innerSz).height
        }

        return CGSize(width: size.width, height: height + gapY * 2)
    }
}
