//
//  LocationSearchResultsViewController.swift
//  LocationPicker
//
//  Created by Almas Sapargali on 7/29/15.
//  Copyright (c) 2015 almassapargali. All rights reserved.
//

import UIKit
import MapKit

class LocationSearchResultsViewController: UITableViewController {
	var locations: [Location] = []
	var onSelectLocation: ((Location) -> ())?
    var onDeleteLocation: ((Location) -> ())?
	var isShowingHistory = false
	var searchHistoryLabel: String?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		extendedLayoutIncludesOpaqueBars = true
	}
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return isShowingHistory ? searchHistoryLabel : nil
    }

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return locations.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell")
			?? UITableViewCell(style: .subtitle, reuseIdentifier: "LocationCell")

		let location = locations[indexPath.row]
        if isShowingHistory {
            cell.textLabel?.text = location.name ?? location.address
        } else {
            cell.textLabel?.text = location.name
        }
		cell.detailTextLabel?.text = location.address
		
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		onSelectLocation?(locations[indexPath.row])
	}

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard isShowingHistory else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self else {
                completion(false)
                return
            }
            let location = self.locations[indexPath.row]
            self.onDeleteLocation?(location)
            self.locations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

}
