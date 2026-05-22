//
//  LocationPickerViewController.swift
//  LocationPicker
//
//  Created by Almas Sapargali on 7/29/15.
//  Copyright (c) 2015 almassapargali. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

open class LocationPickerViewController: UIViewController {
	struct CurrentLocationListener {
		let once: Bool
		let action: (CLLocation) -> ()
	}
	
	public var completion: ((Location?) -> ())?
	
	// region distance to be used for creation region when user selects place from search results
	public var resultRegionDistance: CLLocationDistance = 600
	
	/// default: true
	public var showCurrentLocationButton = true
	
	/// default: true
	public var showCurrentLocationInitially = true

    /// default: false
    /// Select current location only if `location` property is nil.
    public var selectCurrentLocationInitially = false
	
	/// see `region` property of `MKLocalSearchRequest`
	/// default: false
	public var useCurrentLocationAsHint = false
	
	/// default: "Search or enter an address"
	public var searchBarPlaceholder = "Search or enter an address"
	
    /// default: "Search History"
    public var searchHistoryLabel = "Search History"

    /// default: "Select"
    public var selectButtonTitle = "Select"

    /// default: "Enter coordinates manually"
    public var manualCoordinatesMenuTitle = "Enter coordinates manually"

    /// default: "Enter Coordinates"
    public var manualCoordinatesAlertTitle = "Enter Coordinates"

    /// default: "Type latitude and longitude values."
    public var manualCoordinatesAlertMessage = "Type latitude and longitude values."

    /// default: "Latitude"
    public var manualCoordinatesLatitudePlaceholder = "Latitude"

    /// default: "Longitude"
    public var manualCoordinatesLongitudePlaceholder = "Longitude"

    /// default: "Save"
    public var manualCoordinatesSaveButtonTitle = "Save"

    /// default: "Cancel"
    public var manualCoordinatesCancelButtonTitle = "Cancel"

    /// default: "Invalid Coordinates"
    public var manualCoordinatesValidationErrorTitle = "Invalid Coordinates"

    /// default: "Please enter both latitude and longitude."
    public var manualCoordinatesMissingValuesErrorMessage = "Please enter both latitude and longitude."

    /// default: "Latitude and longitude must be valid numbers."
    public var manualCoordinatesInvalidNumberErrorMessage = "Latitude and longitude must be valid numbers."

    /// default: "Latitude must be between -90 and 90."
    public var manualCoordinatesLatitudeRangeErrorMessage = "Latitude must be between -90 and 90."

    /// default: "Longitude must be between -180 and 180."
    public var manualCoordinatesLongitudeRangeErrorMessage = "Longitude must be between -180 and 180."

    /// default: "OK"
    public var manualCoordinatesValidationErrorButtonTitle = "OK"
	
	public lazy var currentLocationButtonBackground: UIColor = {
		if let navigationBar = self.navigationController?.navigationBar,
			let barTintColor = navigationBar.barTintColor {
				return barTintColor
		} else { return .white }
	}()
    
    /// default: .minimal
    public var searchBarStyle: UISearchBar.Style = .minimal

	/// default: .default
	public var statusBarStyle: UIStatusBarStyle = .default

    public lazy var searchTextFieldColor: UIColor = .clear
	
	public var mapType: MKMapType = .hybrid {
		didSet {
			if isViewLoaded {
				mapView.mapType = mapType
			}
		}
	}
	
	public var location: Location? {
		didSet {
			if isViewLoaded {
				searchBar.text = location.flatMap({ $0.title }) ?? ""
				updateAnnotation()
			}
		}
	}
	
	static let SearchTermKey = "SearchTermKey"
	
	let historyManager = SearchHistoryManager()
	let locationManager = CLLocationManager()
	let geocoder = CLGeocoder()
	var localSearch: MKLocalSearch?
	var searchTimer: Timer?
	
	var currentLocationListeners: [CurrentLocationListener] = []
	
	var mapView: MKMapView!
	var locationButton: UIButton?
    private var isAutofillingCoordinateFields = false
	
	lazy var results: LocationSearchResultsViewController = {
		let results = LocationSearchResultsViewController()
		results.onSelectLocation = { [weak self] in self?.selectedLocation($0) }
        results.onDeleteLocation = { [weak self] in
            self?.historyManager.removeFromHistory($0)
        }
		results.searchHistoryLabel = self.searchHistoryLabel
		return results
	}()

	lazy var searchController: UISearchController = {
		let search = UISearchController(searchResultsController: self.results)
		search.searchResultsUpdater = self
		search.hidesNavigationBarDuringPresentation = false
		return search
	}()
	
	lazy var searchBar: UISearchBar = {
		let searchBar = self.searchController.searchBar
		searchBar.searchBarStyle = self.searchBarStyle
		searchBar.placeholder = self.searchBarPlaceholder
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = searchTextFieldColor
        }
		return searchBar
	}()
	
	deinit {
		searchTimer?.invalidate()
		localSearch?.cancel()
		geocoder.cancelGeocode()
	}
	
	open override func loadView() {
		mapView = MKMapView(frame: UIScreen.main.bounds)
		mapView.mapType = mapType
		view = mapView
		
		if showCurrentLocationButton {
			let button = UIButton(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
			button.backgroundColor = currentLocationButtonBackground
			button.layer.masksToBounds = true
			button.layer.cornerRadius = 16
			#if SWIFT_PACKAGE
			let bundle = Bundle.module
			#else
			let bundle = Bundle(for: LocationPickerViewController.self)
			#endif
			button.setImage(UIImage(named: "geolocation", in: bundle, compatibleWith: nil), for: UIControl.State())
			button.addTarget(self, action: #selector(LocationPickerViewController.currentLocationPressed),
			                 for: .touchUpInside)
			view.addSubview(button)
			locationButton = button
		}
	}
	
    open override func viewDidLoad() {
        super.viewDidLoad()
        		
		locationManager.delegate = self
		mapView.delegate = self
		searchBar.delegate = self
		
		// gesture recognizer for adding by tap
        let locationSelectGesture = UILongPressGestureRecognizer(
            target: self, action: #selector(addLocation(_:)))
        locationSelectGesture.delegate = self
		mapView.addGestureRecognizer(locationSelectGesture)

		// search
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchBar
            // http://stackoverflow.com/questions/32675001/uisearchcontroller-warning-attempting-to-load-the-view-of-a-view-controller/
            _ = searchController.view
        }
        definesPresentationContext = true
		
		// user location
		mapView.userTrackingMode = .none
		mapView.showsUserLocation = showCurrentLocationInitially || showCurrentLocationButton
		
		if useCurrentLocationAsHint {
			getCurrentLocation()
		}
	}
    
    open override func viewWillDisappear(_ animated: Bool) {
        // Resign first responder to avoid the search bar disappearing issue
        searchController.isActive = false
    }

	open override var preferredStatusBarStyle : UIStatusBarStyle {
		return statusBarStyle
	}
	
	var presentedInitialLocation = false
	
	open override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if let button = locationButton {
			button.frame.origin = CGPoint(
				x: view.frame.width - button.frame.width - 16,
				y: view.frame.height - button.frame.height - 20
			)
		}
		
		// setting initial location here since viewWillAppear is too early, and viewDidAppear is too late
		if !presentedInitialLocation {
			setInitialLocation()
			presentedInitialLocation = true
		}
	}
	
	func setInitialLocation() {
		if let location = location {
			// present initial location if any
			self.location = location
			showCoordinates(location.coordinate, animated: false)
            return
		} else if showCurrentLocationInitially || selectCurrentLocationInitially {
            if selectCurrentLocationInitially {
                let listener = CurrentLocationListener(once: true) { [weak self] location in
                    if self?.location == nil { // user hasn't selected location still
                        self?.selectLocation(location: location)
                    }
                }
                currentLocationListeners.append(listener)
            }
			showCurrentLocation(false)
		}
	}
	
	func getCurrentLocation() {
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
    @objc func currentLocationPressed() {
		showCurrentLocation()
	}
	
	func showCurrentLocation(_ animated: Bool = true) {
		let listener = CurrentLocationListener(once: true) { [weak self] location in
			self?.showCoordinates(location.coordinate, animated: animated)
		}
		currentLocationListeners.append(listener)
        getCurrentLocation()
	}
	
	func updateAnnotation() {
		mapView.removeAnnotations(mapView.annotations)
		if let location = location {
			mapView.addAnnotation(location)
			mapView.selectAnnotation(location, animated: true)
		}
	}
	
	func showCoordinates(_ coordinate: CLLocationCoordinate2D, animated: Bool = true) {
		let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: resultRegionDistance, longitudinalMeters: resultRegionDistance)
		mapView.setRegion(region, animated: animated)
	}

    func selectLocation(location: CLLocation, addToHistory: Bool = false) {
        // add point annotation to map
        _ = MapPinAnnotationView.add(to: mapView, coordinate: location.coordinate)

        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { response, _ in
            if let placemark = response?.first {
                // get POI name from placemark if any
                let poiName = placemark.areasOfInterest?.first?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (poiName?.isEmpty == false) ? poiName : self.coordinatesTitle(for: location.coordinate)

                // pass user selected location too
                let selectedLocation = Location(name: name, location: location, placemark: placemark)
                self.location = selectedLocation
                if addToHistory {
                    self.historyManager.addToHistory(selectedLocation)
                }
            } else {
                // Geocoding can fail (for example, ocean coordinates). Keep the selected point.
                let placemark = MKPlacemark(coordinate: location.coordinate)
                let name = self.coordinatesTitle(for: location.coordinate)
                let selectedLocation = Location(name: name, location: location, placemark: placemark)
                self.location = selectedLocation
                if addToHistory {
                    self.historyManager.addToHistory(selectedLocation)
                }
            }
        }
    }

    func coordinatesTitle(for coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.5f°, %.5f°", coordinate.latitude, coordinate.longitude)
    }

    open func presentManualCoordinatesAlert(
        latitudeText: String? = nil,
        longitudeText: String? = nil
    ) {
        let alert = UIAlertController(
            title: manualCoordinatesAlertTitle,
            message: manualCoordinatesAlertMessage,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = self.manualCoordinatesLatitudePlaceholder
            textField.keyboardType = .numbersAndPunctuation
            textField.text = latitudeText
            textField.addTarget(self, action: #selector(self.manualCoordinateFieldDidChange(_:)), for: .editingChanged)
        }
        alert.addTextField { textField in
            textField.placeholder = self.manualCoordinatesLongitudePlaceholder
            textField.keyboardType = .numbersAndPunctuation
            textField.text = longitudeText
            textField.addTarget(self, action: #selector(self.manualCoordinateFieldDidChange(_:)), for: .editingChanged)
        }

        let cancel = UIAlertAction(title: manualCoordinatesCancelButtonTitle, style: .cancel)
        let save = UIAlertAction(title: manualCoordinatesSaveButtonTitle, style: .default) { [weak self, weak alert] _ in
            guard let self, let alert else { return }
            self.handleManualCoordinatesSave(from: alert)
        }
        alert.addAction(cancel)
        alert.addAction(save)

        present(alert, animated: true)
    }

    func handleManualCoordinatesSave(from alert: UIAlertController) {
        let latitudeText = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let longitudeText = alert.textFields?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var parsedLatitudeText = latitudeText
        var parsedLongitudeText = longitudeText

        // Auto-split only when user likely pasted both coordinates into a single field.
        if longitudeText.isEmpty, let pair = parseCoordinatePair(from: latitudeText) {
            parsedLatitudeText = String(pair.latitude)
            parsedLongitudeText = String(pair.longitude)
        } else if latitudeText.isEmpty, let pair = parseCoordinatePair(from: longitudeText) {
            parsedLatitudeText = String(pair.latitude)
            parsedLongitudeText = String(pair.longitude)
        }

        guard !parsedLatitudeText.isEmpty, !parsedLongitudeText.isEmpty else {
            showManualCoordinatesValidationError(
                message: manualCoordinatesMissingValuesErrorMessage,
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            return
        }

        guard let latitude = parseCoordinate(from: parsedLatitudeText), let longitude = parseCoordinate(from: parsedLongitudeText) else {
            showManualCoordinatesValidationError(
                message: manualCoordinatesInvalidNumberErrorMessage,
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            return
        }

        guard (-90.0...90.0).contains(latitude) else {
            showManualCoordinatesValidationError(
                message: manualCoordinatesLatitudeRangeErrorMessage,
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            return
        }

        guard (-180.0...180.0).contains(longitude) else {
            showManualCoordinatesValidationError(
                message: manualCoordinatesLongitudeRangeErrorMessage,
                latitudeText: latitudeText,
                longitudeText: longitudeText
            )
            return
        }

        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
        searchController.isActive = false
        self.location = nil
        showCoordinates(coordinates)
        selectLocation(location: location, addToHistory: true)
    }

    func showManualCoordinatesValidationError(
        message: String,
        latitudeText: String?,
        longitudeText: String?
    ) {
        let alert = UIAlertController(title: manualCoordinatesValidationErrorTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: manualCoordinatesValidationErrorButtonTitle, style: .default) { [weak self] _ in
            self?.presentManualCoordinatesAlert(latitudeText: latitudeText, longitudeText: longitudeText)
        })
        present(alert, animated: true)
    }

    func parseCoordinatePair(from text: String) -> (latitude: Double, longitude: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = CharacterSet(charactersIn: "; ")
        let spaceOrSemicolonComponents = trimmed
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
        if spaceOrSemicolonComponents.count == 2,
           let latitude = parseCoordinate(from: spaceOrSemicolonComponents[0]),
           let longitude = parseCoordinate(from: spaceOrSemicolonComponents[1]) {
            return (latitude, longitude)
        }

        let commaComponents = trimmed
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if commaComponents.count == 2,
           let latitude = parseCoordinate(from: commaComponents[0]),
           let longitude = parseCoordinate(from: commaComponents[1]) {
            return (latitude, longitude)
        }

        return nil
    }

    func parseCoordinate(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        if let value = formatter.number(from: normalized)?.doubleValue {
            return value
        }

        let fallback = normalized.replacingOccurrences(of: ",", with: ".")
        return Double(fallback)
    }

    @objc func manualCoordinateFieldDidChange(_ textField: UITextField) {
        guard !isAutofillingCoordinateFields else { return }
        guard let alert = presentedViewController as? UIAlertController else { return }
        guard let textFields = alert.textFields, textFields.count >= 2 else { return }

        let latitudeField = textFields[0]
        let longitudeField = textFields[1]
        let latitudeText = latitudeField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let longitudeText = longitudeField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if textField === latitudeField, longitudeText.isEmpty, let pair = parseCoordinatePair(from: latitudeText) {
            isAutofillingCoordinateFields = true
            latitudeField.text = String(pair.latitude)
            longitudeField.text = String(pair.longitude)
            isAutofillingCoordinateFields = false
        } else if textField === longitudeField, latitudeText.isEmpty, let pair = parseCoordinatePair(from: longitudeText) {
            isAutofillingCoordinateFields = true
            latitudeField.text = String(pair.latitude)
            longitudeField.text = String(pair.longitude)
            isAutofillingCoordinateFields = false
        }
    }
}

extension LocationPickerViewController: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.first else { return }
        currentLocationListeners.forEach { $0.action(location) }
		currentLocationListeners = currentLocationListeners.filter { !$0.once }
		manager.stopUpdatingLocation()
	}
}

// MARK: Searching

extension LocationPickerViewController: UISearchResultsUpdating {
	public func updateSearchResults(for searchController: UISearchController) {
		guard let term = searchController.searchBar.text else { return }
		
		searchTimer?.invalidate()

		let searchTerm = term.trimmingCharacters(in: CharacterSet.whitespaces)
		
		if searchTerm.isEmpty {
			results.locations = historyManager.history()
			results.isShowingHistory = true
			results.tableView.reloadData()
		} else {
			// clear old results
			showItemsForSearchResult(nil)
			
			searchTimer = Timer.scheduledTimer(timeInterval: 0.2,
				target: self, selector: #selector(LocationPickerViewController.searchFromTimer(_:)),
				userInfo: [LocationPickerViewController.SearchTermKey: searchTerm],
				repeats: false)
		}
	}
	
    @objc func searchFromTimer(_ timer: Timer) {
		guard let userInfo = timer.userInfo as? [String: AnyObject],
			let term = userInfo[LocationPickerViewController.SearchTermKey] as? String
			else { return }
		
		let request = MKLocalSearch.Request()
		request.naturalLanguageQuery = term
		
		if let location = locationManager.location, useCurrentLocationAsHint {
			request.region = MKCoordinateRegion(center: location.coordinate,
				span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
		}
		
		localSearch?.cancel()
		localSearch = MKLocalSearch(request: request)
		localSearch!.start { response, _ in
			self.showItemsForSearchResult(response)
		}
	}
	
	func showItemsForSearchResult(_ searchResult: MKLocalSearch.Response?) {
		results.locations = searchResult?.mapItems.map { Location(name: $0.name, placemark: $0.placemark) } ?? []
		results.isShowingHistory = false
		results.tableView.reloadData()
	}
	
	func selectedLocation(_ location: Location) {
		// dismiss search results
		dismiss(animated: true) {
			// set location, this also adds annotation
			self.location = location
			self.showCoordinates(location.coordinate)
			
			self.historyManager.addToHistory(location)
		}
	}
}

// MARK: Selecting location with gesture

extension LocationPickerViewController {
    @objc func addLocation(_ gestureRecognizer: UIGestureRecognizer) {
		if gestureRecognizer.state == .began {
			let point = gestureRecognizer.location(in: mapView)
			let coordinates = mapView.convert(point, toCoordinateFrom: mapView)
			let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
			
			// clean location, cleans out old annotation too
			self.location = nil
            selectLocation(location: location)
		}
	}
}

// MARK: MKMapViewDelegate

extension LocationPickerViewController: MKMapViewDelegate {
	public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if annotation is MKUserLocation { return nil }
		
        let pin = MKAnnotationView(annotation: annotation, reuseIdentifier: MapPinAnnotationView.reuseIdentifier)
        pin.image = MapPinAnnotationView.pinImage
        pin.canShowCallout = true
		pin.rightCalloutAccessoryView = selectLocationButton()
        
		return pin
	}
	
	func selectLocationButton() -> UIButton {
		let button = UIButton(frame: CGRect(x: 0, y: 0, width: 70, height: 30))
		button.setTitle(selectButtonTitle, for: UIControl.State())
        if let titleLabel = button.titleLabel {
            let width = titleLabel.textRect(forBounds: CGRect(x: 0, y: 0, width: Int.max, height: 30), limitedToNumberOfLines: 1).width
            button.frame.size = CGSize(width: width, height: 30.0)
        }
        button.setTitleColor(.systemBlue, for: UIControl.State())
		return button
	}
	
	public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		completion?(location)
		if let navigation = navigationController, navigation.viewControllers.count > 1 {
			navigation.popViewController(animated: true)
		} else {
			presentingViewController?.dismiss(animated: true, completion: nil)
		}
	}
	
	public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
		let pins = mapView.annotations.filter { $0 is MapPinAnnotationView }
		assert(pins.count <= 1, "Only 1 pin annotation should be on map at a time")

        if let userPin = views.first(where: { $0.annotation is MKUserLocation }) {
            userPin.canShowCallout = false
        }
	}
}

extension LocationPickerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: UISearchBarDelegate

extension LocationPickerViewController: UISearchBarDelegate {
	public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		// dirty hack to show history when there is no text in search bar
		// to be replaced later (hopefully)
		if let text = searchBar.text, text.isEmpty {
			searchBar.text = " "
		}
	}
	
	public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		// remove location if user presses clear or removes text
		if searchText.isEmpty {
			location = nil
			searchBar.text = " "
		}
	}
}
