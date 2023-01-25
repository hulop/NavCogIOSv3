//
//
//  AskAIViewController.swift
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
import HLPDialog


/**
 This controller manages the actions of AI Dialog.
 
 - The first time:
 The AI Dialog would be opened if available.
 A notification of navigation would be observed.
 
 - Navigation:
 A notification of navigation would be posted here, and another notification would be observed the next time opening AI Dialog,
 either automatically or manually.
 */
class AskAIViewController: BaseController {
    
    private let askAiView = AskAIView()
    private var isObserved = false
    
    init(title: String) {
        super.init(askAiView, title: title)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDialog()
        AudioGuideManager.shared.isDisplayButton(false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let dialogManager = DialogManager.sharedManager()
        askAiView.isAvailable = dialogManager.isAvailable
        askAiView.openAction = { [weak self] in
            guard let self = self else { return }
            self.loadDialog(manager: dialogManager)
        }
    }
    
    private func loadDialog(manager : DialogManager? = nil) {
        let manager = manager != nil ? manager! : DialogManager.sharedManager()
        
        if !manager.isAvailable { return }
        
        manager.userMode = "user_\(MiraikanUtil.routeMode)"
        let dialogVC = DialogViewController()
        dialogVC.tts = DefaultTTS()
        dialogVC.title = self.title
        dialogVC.view.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height - 50)
        dialogVC.dialogViewHelper.removeFromSuperview()
        dialogVC.dialogViewHelper.setup(dialogVC.view,
                                        position: CGPoint(x: self.view.frame.width / 2,
                                                          y: self.view.frame.height - 120))

        if let nav = self.navigationController as? BaseNavController {
            nav.show(dialogVC, sender: nil)
        }
        
        if self.isObserved { return }
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.aiNavi(note:)),
                                               name: Notification.Name(rawValue:"request_start_navigation"),
                                               object: nil)
        self.isObserved = true
    }

    @objc func aiNavi(note: Notification) {
        guard let toID = note.userInfo?["toID"] as? String else { return }
        guard let nav = self.navigationController as? BaseNavController else { return }
        self.isObserved = false
        nav.openMap(nodeId: toID)
    }
}
