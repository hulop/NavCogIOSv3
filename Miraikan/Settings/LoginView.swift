//
//  LoginView.swift
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
 Layout for login
 */
class LoginView: BaseView {
    private let titleLabel = UILabel()
    private let mailAddressTextField = UITextField()
    private let passwordTextField = UITextField()
    private let btnLogin = UIButton()
    
    override func setup() {
        super.setup()
        
        // TODO: Mock
        titleLabel.text = "Miraikan ID"
        titleLabel.accessibilityLabel = "ミライカンアイディー"
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.sizeToFit()
        addSubview(titleLabel)

        mailAddressTextField.borderStyle = .roundedRect
        mailAddressTextField.layer.borderWidth = 1.0
        mailAddressTextField.layer.cornerRadius = 10.0
        mailAddressTextField.layer.masksToBounds = true
        mailAddressTextField.layer.borderColor = UIColor.gray.cgColor
        mailAddressTextField.placeholder = "  " + "メールアドレス"
        mailAddressTextField.keyboardType = .emailAddress
        addSubview(mailAddressTextField)

        passwordTextField.borderStyle = .roundedRect
        passwordTextField.layer.borderWidth = 1.0
        passwordTextField.layer.cornerRadius = 10.0
        passwordTextField.layer.masksToBounds = true
        passwordTextField.layer.borderColor = UIColor.gray.cgColor
        passwordTextField.placeholder = "  " + "パスワード"
        passwordTextField.keyboardType = .asciiCapable
        passwordTextField.isSecureTextEntry = true
        addSubview(passwordTextField)
        
        btnLogin.setTitle(NSLocalizedString("Login", comment: ""), for: .normal)
        btnLogin.setTitleColor(.white, for: .normal)
        btnLogin.setTitleColor(.white, for: .highlighted)
        btnLogin.layer.cornerRadius = 10
        btnLogin.layer.borderWidth = 2
        btnLogin.layer.borderColor = UIColor.init(red: 10/255, green: 38/255, blue: 70/255, alpha: 1).cgColor
        btnLogin.layer.backgroundColor = UIColor.init(red: 46/255, green: 110/255, blue: 168/255, alpha: 1).cgColor
        btnLogin.contentEdgeInsets = UIEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)
        btnLogin.addTarget(self, action: #selector(_tapAction(_:)), for: .touchUpInside)
        addSubview(btnLogin)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let baseWidth = self.frame.width * 2 / 3
        let baseHeight = CGFloat(50.0)

        passwordTextField.frame = CGRect(x: (self.frame.width - baseWidth) / 2,
                                         y: self.frame.height / 4,
                                         width: baseWidth,
                                         height: baseHeight)

        passwordTextField.center = CGPoint(x: self.frame.width / 2,
                                           y: self.frame.height / 2 - baseHeight)
        
        btnLogin.frame = CGRect(x: (self.frame.width - baseWidth) / 2,
                                y: passwordTextField.frame.maxY + 30,
                                width: baseWidth,
                                height: baseHeight)
        
        mailAddressTextField.frame = CGRect(x: (self.frame.width - baseWidth) / 2,
                                        y: passwordTextField.frame.minY - 20 - baseHeight,
                                        width: baseWidth,
                                        height: baseHeight)

        titleLabel.frame = CGRect(x: (self.frame.width - titleLabel.frame.width) / 2,
                                  y: mailAddressTextField.frame.minY - 60 - titleLabel.frame.height,
                                  width: titleLabel.frame.width,
                                  height: titleLabel.frame.height)
    }

    @objc private func _tapAction(_ sender: UIButton) {
        
        UserDefaults.standard.setValue(true, forKey: "LoggedIn")
        
        // Remove the tab after login
        if let viewController = UIApplication.shared.windows.first?.rootViewController {
//            if let tabBarController = viewController as? TabController {
            if let tabBarController = viewController as? MainTabController {
                tabBarController.selectedIndex = TabItem.home.rawValue
                if var tabs = tabBarController.viewControllers {
                    tabs.remove(at: TabItem.login.rawValue)
                    tabBarController.viewControllers = tabs
                    tabBarController.selectedIndex = TabItem.home.rawValue
                    
                    for tab in tabs {
                        if let homeTabController = tab as? HomeTabController {
                            for vc in homeTabController.nav.viewControllers {
                                if let miraikanController = vc as? MiraikanController {
                                    miraikanController.reload()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
