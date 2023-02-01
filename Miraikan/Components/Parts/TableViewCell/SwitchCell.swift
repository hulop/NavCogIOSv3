//
//  SwitchCell.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/30.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

class SwitchCell: UITableViewCell {
    private let baseView = UIView()
    private let titleLabel = UILabel()
    private let switchButton = BaseSwitch()

    private var model : SwitchModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        titleLabel.isAccessibilityElement = false
        setupBaseView()
        setupSwitchButton()
        setupTitleLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBaseView() {
        contentView.addSubview(baseView)

        baseView.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = baseView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9)
        let heightConstraint = baseView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.9)
        let centerXConstraint = baseView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        let centerYConstraint = baseView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        NSLayoutConstraint.activate([widthConstraint, heightConstraint, centerXConstraint, centerYConstraint])
    }

    private func setupTitleLabel() {
        titleLabel.font = .preferredFont(forTextStyle: .callout)
        baseView.addSubview(titleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let leading = titleLabel.leadingAnchor.constraint(equalTo: baseView.leadingAnchor, constant: 0)
        let trailing = titleLabel.trailingAnchor.constraint(equalTo: switchButton.leadingAnchor, constant: 0)
        let centerYConstraint = titleLabel.centerYAnchor.constraint(equalTo: switchButton.centerYAnchor)
        NSLayoutConstraint.activate([leading, trailing, centerYConstraint])
    }

    private func setupSwitchButton() {
        baseView.addSubview(switchButton)

        switchButton.translatesAutoresizingMaskIntoConstraints = false
        let trailing = switchButton.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: -8)
        let top = switchButton.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 8)
        let bottom = switchButton.bottomAnchor.constraint(equalTo: baseView.bottomAnchor, constant: -8)
        NSLayoutConstraint.activate([trailing, top, bottom])
    }
    
    public func configure(_ model : SwitchModel) {
        titleLabel.text = model.desc
        switchButton.accessibilityLabel = model.desc

        switchButton.isOn = model.isOn
        if let isEnabled = model.isEnabled {
            switchButton.isEnabled = isEnabled
        }
        switchButton.onSwitch({ sw in
            UserDefaults.standard.set(sw.isOn, forKey: model.key)
        })
    }
}
