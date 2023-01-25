//
//
//  BaseTabController.swift
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
 The default UIViewController to be instantiated as the root of BaseTabController
 
 - Parameters:
 - view: The default UIView
 - title: The title for NavigationBar
 */
class BaseTabController: UIViewController {

    let nav = BaseNavController()

    // MARK: init
    @objc init( ) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    func tabLayout() {
        var bottomPadding = 0.0
        let tabBarHeight = UITabBarController().tabBar.frame.size.height

        if let window = UIApplication.shared.windows.first {
            bottomPadding = window.safeAreaInsets.bottom
        }

        nav.navigationBar.barTintColor = .systemBackground
        
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.shadowColor = .systemGray5
        nav.navigationBar.scrollEdgeAppearance = navigationBarAppearance

        nav.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(nav.view)
        let leading = nav.view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        let trailing = nav.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0)
        let top = nav.view.topAnchor.constraint(equalTo:  view.topAnchor, constant: 0)
        let bottom = nav.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(bottomPadding + tabBarHeight))
        NSLayoutConstraint.activate([leading, trailing, top, bottom])
    }

    func popToRootViewController(animated: Bool) {
        nav.popToRootViewController(animated: animated)
    }
}
