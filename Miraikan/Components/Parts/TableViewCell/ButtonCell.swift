//
//  ButtonCell.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/30.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation


class ButtonCell: UITableViewCell {
    private let baseView = UIView()
    private let titleLabel = UILabel()
    private let button = StyledButton()
    
    private var model : ButtonModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        titleLabel.isAccessibilityElement = false
        setupBaseView()
        setupTitleLabel()
        setupButton()
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
        let trailing = titleLabel.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: 0)
        let top = titleLabel.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 0)
        NSLayoutConstraint.activate([leading, trailing, top])
        titleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    private func setupButton() {
        baseView.addSubview(button)
        button.addTarget(self, action: #selector(_tapAction(_:)), for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        let centerXConstraint = button.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        let top = button.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        let bottom = button.bottomAnchor.constraint(equalTo: baseView.bottomAnchor, constant: -8)
        NSLayoutConstraint.activate([centerXConstraint, top, bottom])
        button.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    @objc private func _tapAction(_ sender: UIButton) {
        if let key = self.model?.key {
            UserDefaults.standard.removeObject(forKey: key)
            if let _f = self.model?.tapAction {
                _f()
            }
        }
    }

    public func configure(_ model : ButtonModel) {
        self.model = model
        button.setTitle(model.title, for: .normal)
        button.sizeToFit()
        if let isEnabled = model.isEnabled {
            button.isEnabled = isEnabled
        }
    }
}
