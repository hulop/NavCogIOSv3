//
//  AskAIView.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/25.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation
import UIKit

/**
 The view to show before AI Dialog starts and after it ends
 */
class AskAIView: BaseView {
    
    private let btnStart = StyledButton()
    private let lblDesc = AutoWrapLabel()
    
    var openAction : (()->())?
    
    var isAvailable : Bool? {
        didSet {
            guard let isAvailable = isAvailable else { return }
            
            btnStart.isEnabled = isAvailable
            if isAvailable {
                btnStart.setTitle(NSLocalizedString("ai_available", comment: ""), for: .normal)
                btnStart.setTitleColor(.systemBlue, for: .normal)
            } else {
                btnStart.setTitle(NSLocalizedString("ai_not_available", comment: ""), for: .disabled)
                btnStart.setTitleColor(.lightText, for: .disabled)
            }
            btnStart.sizeToFit()
        }
    }
    
    override func setup() {
        super.setup()
        
        btnStart.tapAction { [weak self] _ in
            guard let self = self else { return }
            if let _f = self.openAction {
                _f()
            }
        }
        addSubview(btnStart)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        btnStart.frame = CGRect(x: (self.frame.width - btnStart.frame.width) / 2,
                                y: (self.frame.height - btnStart.frame.height) / 2,
                                width: btnStart.frame.width,
                                height: btnStart.frame.height)
    }
}
