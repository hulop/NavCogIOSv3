//
//  LinkingHeader.swift
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

class LinkingHeader: BaseView {

    private let titleLink = UnderlinedLabel()

    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 20

    var model : ExhibitionLinkModel? {
        didSet {
            guard let model = model else { return }
            titleLink.title = model.counter != ""
                ? "\(model.counter) \(model.title)" : model.title

            if let titlePron = model.titlePron {
                titleLink.accessibilityLabel = titlePron
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
            self.isUserInteractionEnabled = true
            self.addGestureRecognizer(tap)
        }
    }

    var isFirst : Bool = false

    override func setup() {
        super.setup()
        
        titleLink.accessibilityTraits = .header
        addSubview(titleLink)
    }

    @objc private func tapAction(_ sender: UIView) {
        guard let model = model else { return }
        guard let nav = self.navVC else { return }
        nav.show(BaseController(ExhibitionView(nodeId: model.nodeId,
                                               detail: model.blindDetail,
                                               locations: model.locations),
                                title: model.title), sender: nil)
    }
    
    override func layoutSubviews() {
        let topMargin = isFirst ? (insets.top + gapY) : insets.top
        let linkSz = CGSize(width: innerSize.width - gapX * 2, height: 0)
        titleLink.frame = CGRect(x: insets.left + gapX,
                                 y: topMargin,
                                 width: innerSize.width - gapX * 2,
                                 height: titleLink.sizeThatFits(linkSz).height)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let linkSz = CGSize(width: innerSizing(parentSize: size).width, height: 0)
        let topMargin = isFirst ? (insets.top + gapY) : insets.top
        let height = topMargin + insets.bottom + titleLink.sizeThatFits(linkSz).height
        return CGSize(width: size.width, height: height)
    }
}
