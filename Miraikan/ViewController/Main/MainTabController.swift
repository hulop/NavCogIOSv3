//
//  MainTabController.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/11.
//  Copyright © 2023 HULOP. All rights reserved.
//

import UIKit

class MainTabController: UITabBarController, UITabBarControllerDelegate {

    private var buttonBaseView = ThroughView()
    private var voiceGuideButton = VoiceGuideButton()
//    private var logButton = LocationRecordingButton()
//    private var locationButton = LocationInputButton()
//    private var locationInputView = LocationInputView()
    var voiceGuideObserver: NSKeyValueObservation?
    var footerButtonViewObserver: NSKeyValueObservation?
//    var debugObserver: NSKeyValueObservation?
//    var debugLocationObserver: NSKeyValueObservation?
//    var locationObserver: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        self.tabBar.backgroundColor = .systemBackground
        self.tabBar.layer.borderWidth = 1.0
        self.tabBar.layer.borderColor = UIColor.systemGray5.cgColor

        let tabs = TabItem.allCases.filter({ item in
            return true
        })
        
        self.viewControllers = tabs.map({ $0.vc })
        self.selectedIndex = tabs.firstIndex(where: { $0 == .home })!
        if let items = self.tabBar.items {
            for (i, t) in tabs.enumerated() {
                items[i].title = t.title
                items[i].accessibilityLabel = t.accessibilityTitle
                items[i].image = UIImage(named: t.imgName)
            }
        }

        UserDefaults.standard.set(true, forKey: "isFooterButtonView")
        AudioGuideManager.shared.active()
        AudioGuideManager.shared.isActive(UserDefaults.standard.bool(forKey: "isVoiceGuideOn"))
        setLayerButton()
        setKVO()
//        becomeFirstResponder()

//        self.mapVC = UIStoryboard(name: "Main", bundle: nil)
//            .instantiateViewController(withIdentifier: "map_ui_navigation")
    }

//    override var canBecomeFirstResponder: Bool {
//        return true
//    }
//
//    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
//        super.motionBegan(motion, with: event)
//    }
//
//    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
//        super.motionEnded(motion, with: event)
//        if motion == .motionShake {
//            showSettings()
//        }
//    }
//
//    override func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
//        super.motionCancelled(motion, with: event)
//    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
//        if let navigationController = viewController as? UINavigationController {
//            navigationController.popToRootViewController(animated: true)
//        } else if let navigationController = viewController as? BaseTabController {
//            navigationController.popToRootViewController(animated: true)
//        }
        return true
    }

    private func setKVO() {
        voiceGuideObserver = AudioGuideManager.shared.observe(\.isDisplay,
                                                     options: [.initial, .new],
                                                     changeHandler: { [weak self] (defaults, change) in
            guard let self = self else { return }
            if let change = change.newValue {
                self.voiceGuideButton.isDisplayButton(change)
            }
        })

        footerButtonViewObserver = UserDefaults.standard.observe(\.isFooterButtonView, options: [.initial, .new], changeHandler: { [weak self] (defaults, change) in
            guard let self = self else { return }
            if let change = change.newValue {
                UserDefaults.standard.set(change, forKey: "isFooterButtonView")
                self.buttonBaseView.isHidden = !change
            }
        })

//        locationObserver = UserDefaults.standard.observe(\.isLocationInput, options: [.initial, .new], changeHandler: { [weak self] (defaults, change) in
//            guard let self = self else { return }
//            if let change = change.newValue {
//                self.locationInputView.isDisplayButton(change)
//            }
//        })
//
//        debugObserver = UserDefaults.standard.observe(\.DebugMode, options: [.initial, .new], changeHandler: { [weak self] (defaults, change) in
//            guard let self = self else { return }
//            if let change = change.newValue {
//                UserDefaults.standard.set(false, forKey: "isMoveLogStart")
//                self.logButton.isDisplayButton(change)
//            }
//        })
//
//        debugLocationObserver = UserDefaults.standard.observe(\.DebugLocationInput, options: [.initial, .new], changeHandler: { [weak self] (defaults, change) in
//            guard let self = self else { return }
//            if let change = change.newValue {
//                self.locationButton.isDisplayButton(change)
//                if !change {
//                    let center = NotificationCenter.default
//                    center.post(name: NSNotification.Name(rawValue: "request_location_restart"), object: self)
//                }
//            }
//        })
    }

    private func setLayerButton() {
        var rightPadding: CGFloat = 0
//        var leftPadding: CGFloat = 0
        var bottomPadding: CGFloat = 0
        if let window = UIApplication.shared.windows.first {
            rightPadding = window.safeAreaInsets.right
//            leftPadding = window.safeAreaInsets.left
            bottomPadding = window.safeAreaInsets.bottom
        }

        let tabHeight = self.tabBar.frame.height

        buttonBaseView.frame = CGRect(x: 0,
                                      y: UIScreen.main.bounds.height - 100 - tabHeight - bottomPadding,
                                      width: UIScreen.main.bounds.width,
                                      height: 100)
        buttonBaseView.backgroundColor = .clear
        self.view.addSubview(buttonBaseView)

        voiceGuideButton.frame = CGRect(x: UIScreen.main.bounds.width - 100 - rightPadding,
                                        y: 10,
                                        width: 80,
                                        height: 80)
        buttonBaseView.addSubview(voiceGuideButton)

//        logButton.frame = CGRect(x: UIScreen.main.bounds.width - 100 - 10 - 60 - rightPadding,
//                                 y: 20,
//                                 width: 60,
//                                 height: 60)
//        buttonBaseView.addSubview(logButton)
//
//        locationButton.frame = CGRect(x: leftPadding + leftPadding + 100,
//                                      y: 20,
//                                      width: 60,
//                                      height: 60)
//        buttonBaseView.addSubview(locationButton)
//
//        locationInputView.frame = CGRect(x: 0,
//                                         y: 0,
//                                         width: 360,
//                                         height: 440)
//        locationInputView.center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 3)
//        self.view.addSubview(locationInputView)
    }

//    private func showSettings() {
//        let vc = NaviSettingController(title: NSLocalizedString("Navi Settings", comment: ""))
//        self.present(vc, animated: true, completion: nil)
//    }
}
