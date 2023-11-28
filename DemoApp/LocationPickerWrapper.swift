//
//  LocationPickerWrapper.swift
//  DemoApp
//
//  Created by Eman Basic on 28.11.23.
//  Copyright © 2023 almassapargali. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import LocationPicker
import MapKit
import Combine

final class LocationPickerWrapper: LocationPickerViewController {
    convenience init(
        predefinedLocation: CLLocationCoordinate2D?,
        completion: @escaping (CLLocationCoordinate2D?) -> Void
    ) {
        self.init()
        setupOnInit(predefinedLocation, completion)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
}

// MARK: - Setup

extension LocationPickerWrapper {
    private func setupOnInit(_ predefinedLocation: CLLocationCoordinate2D?, _ completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        if let predefinedLocation {
            let placemark = MKPlacemark(coordinate: predefinedLocation, addressDictionary: nil)
            location = Location(name: nil, location: nil, placemark: placemark)
        }
        
        self.completion = { location in
            completion(location?.coordinate)
        }
        
        searchBarPlaceholder = NSLocalizedString("Search or enter address", comment: "")
        searchHistoryLabel = NSLocalizedString("Previously searched", comment: "")
        selectButtonTitle = NSLocalizedString("Save", comment: "")
        showCurrentLocationButton = false
        showCurrentLocationInitially = false
        mapType = .standard
        searchBarStyle = .prominent
    }
    
    private func setup() {
        title = NSLocalizedString("Custom location", comment: "")
                
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [unowned self] _ in
            self.completion?(self.location)
            
            if let navigationController, navigationController.viewControllers.count > 1 {
                // view controller has been pushed onto the navigation stack
                navigationController.popViewController(animated: true)
            } else {
                // view controller has been presented
                presentingViewController?.dismiss(animated: true)
            }
        })
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "map.fill"),
            style: .plain,
            target: self,
            action: #selector(mapButtonPressed)
        )
        
        navigationController?.navigationBar.tintColor = .label
    }
}

// MARK: - Actions

extension LocationPickerWrapper {
    @objc private func mapButtonPressed() {
        mapType = switch mapType {
            case .standard: .hybrid
            case .hybrid: .standard
            default: .standard
        }
    }
}
