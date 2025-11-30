//
//  SettingsTableViewCell.swift
//  FSNotes
//
//  Created by Oleksandr Hlushchenko on 15.09.2024.
//  Copyright © 2024 Oleksandr Hlushchenko. All rights reserved.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        imageView.image = UIImage(systemName: "star.fill", withConfiguration: symbolConfig)
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let gradientView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var iconName: String?
    private var gradient: [String]?

    init(iconName: String, gradient: [String], style: UITableViewCell.CellStyle = .subtitle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.iconName = iconName
        self.gradient = gradient
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = .white

        setupViews()
        applyGradient()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(gradientView)
        gradientView.addSubview(iconView)
        
        NSLayoutConstraint.activate([
            gradientView.widthAnchor.constraint(equalToConstant: 35),
            gradientView.heightAnchor.constraint(equalToConstant: 35),
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            gradientView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: gradientView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: gradientView.centerYAnchor),

            textLabel!.leadingAnchor.constraint(equalTo: gradientView.trailingAnchor, constant: 16),
            textLabel!.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
        
        if let detailTextLabel = detailTextLabel {
            NSLayoutConstraint.activate([
                textLabel!.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
                textLabel!.bottomAnchor.constraint(equalTo: detailTextLabel.topAnchor, constant: -4),
                
                detailTextLabel.leadingAnchor.constraint(equalTo: textLabel!.leadingAnchor),
                detailTextLabel.trailingAnchor.constraint(equalTo: textLabel!.trailingAnchor),
                
                detailTextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
            ])
        } else {
            NSLayoutConstraint.activate([
                textLabel!.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }
        
        gradientView.layer.cornerRadius = 8
        gradientView.clipsToBounds = true
        
        textLabel?.translatesAutoresizingMaskIntoConstraints = false
        detailTextLabel?.translatesAutoresizingMaskIntoConstraints = false
    }

    private func applyGradient() {
        let gradientLayer = CAGradientLayer()
        let colors = [
            UIColor.getBy(hex: self.gradient!.first!).cgColor,
            UIColor.getBy(hex: self.gradient!.last!).cgColor
        ]
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }
}

