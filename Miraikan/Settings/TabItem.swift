//
//  TabItem.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/11.
//  Copyright © 2023 HULOP. All rights reserved.
//

import UIKit

/**
 This should be accessible for TabController and its related controllers / views
 
 - References:
 
 [Icon by](https://icons8.com),
 [Staff](https://icons8.com/icon/61242/management),
 [Inquiry](https://icons8.com/icon/20150/inquiry),
 [Home](https://icons8.com/icon/59809/home),
 [Login](https://icons8.com/icon/26218/login),
 [Ask Question](https://icons8.com/icon/7857/ask-question)
 */
enum TabItem: Int, CaseIterable {
    case callStaff
    case callSC
    case home
    case login
    case askAI

    var title: String {
        switch self {
        case .callStaff:
            return NSLocalizedString("Call Staff", comment: "")
        case .callSC:
            return NSLocalizedString("Call SC", comment: "")
        case .home:
            return NSLocalizedString("Home", comment: "")
        case .login:
            return NSLocalizedString("Login", comment: "")
        case .askAI:
            return NSLocalizedString("Ask AI", comment: "")
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .callStaff:
            return NSLocalizedString("Call Staff pron", comment: "")
        case .callSC:
            return NSLocalizedString("Call SC pron", comment: "")
        case .home:
            return NSLocalizedString("Home pron", comment: "")
        case .login:
            return NSLocalizedString("Login pron", comment: "")
        case .askAI:
            return NSLocalizedString("Ask AI pron", comment: "")
        }
    }

    var imgName: String {
        switch self {
        case .callStaff:
            return "call_staff"
        case .callSC:
            return "call_sc"
        case .home:
            return "home"
        case .login:
            return "login"
        case .askAI:
            return "ask_ai"
        }
    }

    var vc: UIViewController {
        switch self {
        case .callStaff:
            return StaffTabController()
        case .callSC:
            return SCTabController()
        case .home:
            return HomeTabController()
        case .login:
            return LoginTabController()
        case .askAI:
            return AITabController()
        }
    }
}
