//
//  ViewController.swift
//  DemoApp
//
//  Created by Eman Basic on 28.11.23.
//  Copyright © 2023 almassapargali. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var presentButton: UIButton = {
        let view = UIButton(primaryAction: UIAction { [unowned self] _ in
            let viewController = LocationPickerWrapper(predefinedLocation: nil) { location in
                print("Completion: ", location ?? "no location")
            }
            
            let navigationController = UINavigationController(rootViewController: viewController)
            self.present(navigationController, animated: true)
        })
        
        view.setTitle("Open Location Picker", for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    
        view.addSubview(presentButton)
        
        NSLayoutConstraint.activate([
            presentButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            presentButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

