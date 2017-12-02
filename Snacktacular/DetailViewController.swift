//
//  DetailViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import GooglePlaces
import Firebase

class DetailViewController: UIViewController {

    @IBOutlet weak var placeNameField: UITextField!
    @IBOutlet weak var addressField: UITextField!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var placeData: PlaceData?
    var locationManger: CLLocationManager!
    var currentLocation: CLLocation!
    var regionRadius = 1000.0 // 1 km
    var imagePicker = UIImagePickerController()
    var newImages = [UIImage]()
    var placeImages = [UIImage]()
    var db: Firestore!
    var storage: Storage!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        
        db = Firestore.firestore()
        storage = Storage.storage()
        
        // These three lines will dismiss the keyboard when one taps outside of a textField
        let tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)

        mapView.delegate = self
        if let placeData = placeData {
            centerMap(mapLocation: placeData.coordinate, regionRadius: regionRadius)
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(placeData)
            mapView.selectAnnotation(placeData, animated: true)
            updateUserInterface()
            loadImages()
        } else {
            placeData = PlaceData()
            getLocation()
        }
    }
    
    func updateUserInterface() {
        placeNameField.text = placeData!.placeName
        addressField.text = placeData!.address
    }
    
    func getImageRerences(completion: @escaping ([String]) -> ()) {
        var imageReferences = [String]()
        db.collection("places").document((placeData?.placeDocumentID)!).collection("images").getDocuments { (querySnapshot, error) in
            if error != nil {
                print("ERROR: reading documents at \(error!.localizedDescription)")
            } else {
                for document in querySnapshot!.documents {
                    imageReferences.append(document.documentID)
                }
            }
            completion(imageReferences)
        }
    }
    
    func loadImages() {
        getImageRerences { (imageReferences) in
            guard let bucketRef = self.placeData?.placeDocumentID else {
                print("Couldn't read bucketRef for \(self.placeData!.placeDocumentID)")
                return
            }
            for imageReference in imageReferences {
                let imageReference = self.storage.reference().child(bucketRef+"/"+imageReference)
                imageReference.getData(maxSize: 10 * 1024 * 1024) { data, error in
                    guard error == nil else {
                        print("An error occurred while rading data from file ref: \(imageReference), error \(error!.localizedDescription)")
                        return
                    }
                    let image = UIImage(data: data!)
                    self.placeImages.append(image!)
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func centerMap(mapLocation: CLLocationCoordinate2D, regionRadius: CLLocationDistance) {
        let region = MKCoordinateRegionMakeWithDistance(mapLocation, regionRadius, regionRadius)
        mapView.setRegion(region, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowPhoto" {
            let destination = segue.destination as! PhotoViewController
            destination.photoImage = placeImages[collectionView.indexPathsForSelectedItems!.first!.row]
        } else {
            placeData?.placeName = placeNameField.text!
            placeData?.address = addressField.text!
        }
    }
    
    func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(alertAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        let isPrestingInAddMode = presentingViewController is UINavigationController
        if isPrestingInAddMode {
            dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func lookupButtonPressed(_ sender: UIBarButtonItem) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        present(autocompleteController, animated: true, completion: nil)
    }
    
    @IBAction func cameraButtonPressed(_ sender: UIBarButtonItem) {
       let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { (cameraAction) in
            self.accessCamera()
        }
        let libraryAction = UIAlertAction(title: "Photo Library", style: .default) { (libraryAction) in
            self.accessLibrary()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cameraAction)
        alertController.addAction(libraryAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension DetailViewController: CLLocationManagerDelegate {
    
    func getLocation(){
        locationManger = CLLocationManager()
        locationManger.delegate = self
    }
    
    func handleLocationAuthorizationStatus(status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManger.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManger.requestLocation()
        case .denied:
            showAlertToPrivacySettings(title: "User has not authorized location services", message: "Select 'Settings' below to open device settings and enable location services for this app.")
        case .restricted:
            showAlert(title: "Location services denied", message: "It may be that parental controls are restricting location use in this app")
        }
    }
    
    func showAlertToPrivacySettings(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            print("Something went wrong getting the UIApplicationOpenSettingsURLString")
            return
        }
        let settingsActions = UIAlertAction(title: "Settings", style: .default) { value in
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(settingsActions)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleLocationAuthorizationStatus(status: status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let geoCoder = CLGeocoder()
        currentLocation = locations.last
        let currentLatitude = currentLocation.coordinate.latitude
        let currentLongitude = currentLocation.coordinate.longitude
        geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: {placemarks, error in
            if placemarks != nil {
                let placemark = placemarks?.last
                self.placeData?.placeName = (placemark?.name)!
                self.placeData?.address = placemark?.thoroughfare ?? "unknown"
                self.placeData?.coordinate = CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
                self.centerMap(mapLocation: (self.placeData?.coordinate)!, regionRadius: self.regionRadius)
                self.mapView.addAnnotation(self.placeData!)
                self.mapView.selectAnnotation(self.placeData!, animated: true)
                self.updateUserInterface()
            } else {
                print("Error retrieving place. Error code: \(error!)")
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get user location.")
    }
}

extension DetailViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let identifer = "Marker"
        var view: MKPinAnnotationView
        if let dequedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifer) as? MKPinAnnotationView {
            dequedView.annotation = annotation
            view = dequedView
        } else {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifer)
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .custom)
        }
        return view
    }
    
}

extension DetailViewController: GMSAutocompleteViewControllerDelegate {
    
    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        placeData?.placeName = place.name
        placeData?.coordinate = place.coordinate
        placeData?.address = place.formattedAddress ?? "unknown"
        centerMap(mapLocation: (placeData?.coordinate)!, regionRadius: regionRadius)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(self.placeData!)
        mapView.selectAnnotation(self.placeData!, animated: true)
        updateUserInterface()
        dismiss(animated: true, completion: nil)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }
    
    // User canceled the operation.
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}

extension DetailViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let selectedImage = info[UIImagePickerControllerOriginalImage] as! UIImage
        placeImages.insert(selectedImage, at: 0)
        newImages.append(selectedImage)
        dismiss(animated: true, completion: {self.collectionView.reloadData()})
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func accessLibrary() {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    func accessCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePicker.sourceType = .camera
            present(imagePicker, animated: true, completion: nil)
        } else {
            showAlert(title: "Camera Not Available", message: "There is no camera available on this device.")
        }
    }
}

extension DetailViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return placeImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PlaceImageCollectionViewCell
        cell.placeImage.image = placeImages[indexPath.row]
        return cell
    }
}
