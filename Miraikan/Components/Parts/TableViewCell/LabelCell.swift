//
//  LabelCell.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/30.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation


class LabelCell: UITableViewCell {
    private let baseView = UIView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
//        self.isAccessibilityElement = true
        self.isAccessibilityElement = false
        setupBaseView()
        setupTitleLabel()
        setupValueLabel()
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
        let top = titleLabel.topAnchor.constraint(equalTo: baseView.topAnchor, constant: 8)
        NSLayoutConstraint.activate([leading, trailing, top])
        titleLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    private func setupValueLabel() {
        valueLabel.font = .preferredFont(forTextStyle: .callout)
        baseView.addSubview(valueLabel)
        
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.numberOfLines = 0
        valueLabel.lineBreakMode = .byClipping

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        let leading = valueLabel.leadingAnchor.constraint(equalTo: baseView.leadingAnchor, constant: 8)
        let trailing = titleLabel.trailingAnchor.constraint(equalTo: baseView.trailingAnchor, constant: 0)
        let top = valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        let bottom = valueLabel.bottomAnchor.constraint(equalTo: baseView.bottomAnchor, constant: -8)
        NSLayoutConstraint.activate([leading, trailing, top, bottom])
        valueLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }
    
    public func configure(_ model : LabelModel) {
        titleLabel.text = model.title
        valueLabel.text = model.value
    }
}
