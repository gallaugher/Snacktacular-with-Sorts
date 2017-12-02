//
//  PlaceData.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit

class PlaceData: NSObject, MKAnnotation {
    var placeName: String
    var address: String
    var postingUserID: String
    var coordinate: CLLocationCoordinate2D
    var placeDocumentID: String
    
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var title: String? {
        return placeName
    }
    
    var subtitle: String? {
     return address
    }
    
    var latitude: CLLocationDegrees {
        return coordinate.latitude
    }
    
    var longitude: CLLocationDegrees {
        return coordinate.longitude
    }
    
    var dictionary: [String: Any] {
        return ["placeName": placeName, "address": address, "postingUserID": postingUserID, "latitude": latitude, "longitude": longitude]
    }
    
    init(placeName: String, address: String, coordinate: CLLocationCoordinate2D, postingUserID: String, placeDocumentID: String) {
        self.placeName = placeName
        self.address = address
        self.coordinate = coordinate
        self.postingUserID = postingUserID
        self.placeDocumentID = placeDocumentID
    }
    
    convenience override init() {
        self.init(placeName: "", address: "", coordinate: CLLocationCoordinate2D(), postingUserID: "", placeDocumentID: "")
    }
    
    convenience init(dictionary: [String: Any]) {
        let placeName = dictionary["placeName"] as! String? ?? ""
        let address = dictionary["address"] as! String? ?? ""
        let postingUserID = dictionary["postingUserID"] as! String? ?? ""
        let latitude = dictionary["latitude"] as! CLLocationDegrees? ?? 0.0
        let longitude = dictionary["longitude"] as! CLLocationDegrees? ?? 0.0
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.init(placeName: placeName, address: address, coordinate: coordinate, postingUserID: postingUserID, placeDocumentID: "")
    }
}
