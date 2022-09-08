//
//  PushPresentViewController.swift
//  REES46_Example
//
//  Created by Arseniy Dorogin on 11.04.2022.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import UIKit

class PushPresentViewController: UIViewController {
    
    @IBOutlet private weak var titleLabel: UILabel!

    var pushTitle: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 0
        titleLabel.text = pushTitle
        
        self.navigationItem.leftBarButtonItem = .init(barButtonSystemItem: .cancel, target: self, action: #selector(closeButton))
    }
    
    @objc
    func closeButton() {
        self.dismiss(animated: true)
    }
}
