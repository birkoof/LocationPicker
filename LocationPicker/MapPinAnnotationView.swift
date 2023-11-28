//
//  MapPinAnnotationView.swift
//  LocationPicker
//
//  Created by Eman Basic on 28.11.23.
//  Copyright © 2023 almassapargali. All rights reserved.
//

import MapKit

final class MapPinAnnotationView: MKPointAnnotation {
    static let reuseIdentifier = "MapPinAnnotationView"
    
    static let pinImage = UIImage(resource: .mapPin)
    
    static func add(to mapView: MKMapView, coordinate: CLLocationCoordinate2D, title: String? = nil) -> MKAnnotation {
        let annotation = MapPinAnnotationView()
        annotation.coordinate = coordinate
        annotation.title = title
        let pinAnnotation = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        mapView.addAnnotation(pinAnnotation.annotation!)
        return pinAnnotation.annotation!
    }
}
