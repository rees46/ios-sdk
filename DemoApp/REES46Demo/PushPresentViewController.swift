//
//  PushPresentViewController.swift
//  REES46
//
//  Created by REES46
//  Copyright (c) 2024. All rights reserved.
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
