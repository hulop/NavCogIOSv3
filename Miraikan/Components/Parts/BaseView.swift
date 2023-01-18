//
//  BaseView.swift
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
 The parent UIView with common variables and functions
 for calculating the size and accessing the parent ViewControllers.
 
 It is suggested to override the setup() function instead of init(),
 since the required init?() would also be required for init().
 */
class BaseView: UIView {

    // MARK: padding
    var innerSize: CGSize {
        return innerSizing()
    }

    var insets: UIEdgeInsets {
        return padding()
    }

    var paddingAboveTab: CGFloat {
        return 0.0
    }

    // MARK: parent ViewControllers
    var parentVC: UIViewController? {
        return getParent()
    }

    var navVC: BaseNavController? {
        if let parent = parentVC {
            return parent.navigationController as? BaseNavController
        }
        return nil
    }

//    var tabVC: TabController? {
//        if let parent = parentVC {
//            return parent.tabBarController as? TabController
//        }
//        return nil
//    }

    // MARK: init with setup() function
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Override it, and add the subviews here
     */
    func setup() {
        backgroundColor = .systemBackground
    }

    // MARK: Size calculation
    private func padding(margin: CGFloat = 0) -> UIEdgeInsets {
        return UIEdgeInsets(top: safeAreaInsets.top,
                            left: margin,
                            bottom: 0,
                            right: margin)
    }

    func innerSizing(margin: CGFloat = 0) -> CGSize {
        return innerSizing(parentSize: frame.size, margin: margin)
    }

    func innerSizing(parentSize: CGSize, margin: CGFloat = 0) -> CGSize {
        let insets = padding(margin: margin)
        return CGSize(width: parentSize.width - (insets.left + insets.right),
                      height: parentSize.height - (insets.top + insets.bottom))
    }

    // MARK: Parent UIViewController
    private func getParent() -> UIViewController? {
        var responder: UIResponder? = self.next
        while responder != nil {
            if let c = responder as? UIViewController { return c }
            else { responder = responder?.next }
        }
        return nil
    }
}
