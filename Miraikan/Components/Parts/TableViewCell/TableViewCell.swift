//
//
//  TableViewCell.swift
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
 The parent customized UITableViewCell to be inherited by specific cells.
 The variables and functions are copied from BaseView for the same purposes
 */
class BaseRow: UITableViewCell {

    // MARK: padding
    var innerSize: CGSize {
        return innerSizing()
    }

    var insets: UIEdgeInsets {
        return padding()
    }

    // MARK: Variables for upper level controllers
    var parent: UIViewController? {
        return getParent()
    }

    var nav: BaseNavController? {
        if let parent = parent {
            return parent.navigationController as? BaseNavController
        }
        return nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        // To enable the UI actions inside the cell
        self.contentView.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Size calculation
    private func padding() -> UIEdgeInsets {
        return UIEdgeInsets(top: safeAreaInsets.top + 0,
                            left: 0,
                            bottom: 0,
                            right: 0)
    }

    func innerSizing() -> CGSize {
        let insets = padding()
        return CGSize(width: frame.width - (insets.left + insets.right),
                      height: frame.height - (insets.top + insets.bottom))
    }

    func innerSizing(parentSize: CGSize) -> CGSize {
        let insets = padding()
        return CGSize(width: parentSize.width - (insets.left + insets.right),
                      height: parentSize.height - (insets.top + insets.bottom))
    }

    // MARK: Parent Controllers
    private func getParent() -> UIViewController? {
        var responder: UIResponder? = self.next
        while responder != nil {
            if let c = responder as? UIViewController { return c }
            else { responder = responder?.next }
        }
        return nil
    }
}
