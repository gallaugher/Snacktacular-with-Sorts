 //
//  PlaceListViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 11/24/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase
import FirebaseAuthUI
import FirebaseGoogleAuthUI

class PlaceListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var sortSegmentedControl: UISegmentedControl!
    var places = [PlaceData]()
    var authUI: FUIAuth!
    var db: Firestore!
    var storage: Storage!
    var newImages = [UIImage]()
    let userLocation = CLLocation(latitude: 42.334709, longitude: -71.170061)
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        db = Firestore.firestore()
        storage = Storage.storage()
        authUI = FUIAuth.defaultAuthUI()
        // You need to adopt a FUIDelegate protocol to receive callback
        authUI?.delegate = self
        
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        checkForUpdates()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        signIn()
    }
    
    func signIn() {
        let providers: [FUIAuthProvider] = [
            FUIGoogleAuth()
            ]
        if authUI.auth?.currentUser == nil {
            self.authUI?.providers = providers
            present(authUI.authViewController(), animated: true, completion: nil)
        }
    }
    
    func checkForUpdates() {
        db.collection("places").addSnapshotListener { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: adding the snapshot listener \(error!.localizedDescription)")
                return
            }
            self.loadData()
        }
    }
    
    func loadData() {
        db.collection("places").getDocuments { (querySnapshot, error) in
            guard error == nil else {
                print("ERROR: reading documents \(error!.localizedDescription)")
                return
            }
            self.places = []
            for document in querySnapshot!.documents {
                let placeData = PlaceData(dictionary: document.data())
                placeData.placeDocumentID = document.documentID
                self.places.append(placeData)
            }
            if self.sortSegmentedControl.selectedSegmentIndex != 0 {
                self.sortBasedOnSegmentPressed()
            }
            self.tableView.reloadData()
        }
    }
    
    func saveData(placeData: PlaceData) {
        // Grab the unique userID
        if let postingUserID = (authUI.auth?.currentUser?.email) {
            placeData.postingUserID = postingUserID
        } else {
            placeData.postingUserID = "unknown user"
        }
        
        // Create the dictionary representing data we want to save
        let dataToSave: [String: Any] = placeData.dictionary
        
        // if we HAVE saved a record, we'll have an ID
        if placeData.placeDocumentID != "" {
            let ref = db.collection("places").document(placeData.placeDocumentID)
            ref.setData(dataToSave) { (error) in
                if let error = error {
                    print("ERROR: updating document \(error.localizedDescription)")
                } else {
                    print("Document updated with reference ID \(ref.documentID)")
                    self.sortBasedOnSegmentPressed()
                    self.saveImages(placeDocumentID: placeData.placeDocumentID)
                }
            }
        } else { // Otherwise we don't have a document ID so we need to create the ref ID and save a new document
            var ref: DocumentReference? = nil // Firestore will creat a new ID for us
            ref = db.collection("places").addDocument(data: dataToSave) { (error) in
                if let error = error {
                    print("ERROR: adding document \(error.localizedDescription)")
                } else {
                    print("Document added with reference ID \(ref!.documentID)")
                    placeData.placeDocumentID = "\(ref!.documentID)"
                    self.sortBasedOnSegmentPressed() // includes call to tableView.reloadData()
                    self.saveImages(placeDocumentID: placeData.placeDocumentID)
                }
            }
        }
    }
    
    func saveImages(placeDocumentID: String) {
        // imagesRef now pointsn to a bucket to hold all images for place named: "placeDocumentID"
        let imagesRef = storage.reference().child(placeDocumentID)
        
        for image in newImages {
            let imageName = NSUUID().uuidString+".jpg" // always creates a unique string in part based on time/date
            // Convert image to type Data so it can be saved to Storage
            guard let imageData = UIImageJPEGRepresentation(image, 0.8) else {
                print("ERROR creating imageData from JPEGRepresentation")
                return
            }
            // Create a ref to the file you want to upload
            let uploadedImageRef = imagesRef.child(imageName)
            let uploadTask = uploadedImageRef.putData(imageData, metadata: nil, completion: { (metadata, error) in
                guard error == nil else {
                    print("ERROR: \(error!.localizedDescription)")
                    return
                }
                let downloadURL = metadata!.downloadURL
                print("%%% successfully uploaded - the downloadURL is \(downloadURL)")
                
                let postingUserID = Auth.auth().currentUser?.email ?? ""
                self.db.collection("places").document(placeDocumentID).collection("images").document(imageName).setData(["postingUserID": postingUserID]) { (error) in
                    if let error = error {
                        print("ERROR: adding document \(error.localizedDescription)")
                    } else {
                        print("Document added for place \(placeDocumentID) and image \(imageName)")
                    }
                }
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowDetail" {
            let destination = segue.destination as! DetailViewController
            let selectedRow = tableView.indexPathForSelectedRow!.row
            destination.placeData = places[selectedRow]
        } else {
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
        }
    }
    
    func sortBasedOnSegmentPressed() {
        switch sortSegmentedControl.selectedSegmentIndex {
        case 0: // unsorted
            loadData()
        case 1: // A-Z
            let sortedArray = places.sorted(by: {$0.placeName < $1.placeName})
            places = sortedArray
            tableView.reloadData()
        case 2: // Distance (Closest to Farthest)
            let sortedPlaces = places.sorted (by: {$0.location.distance(from: userLocation) < $1.location.distance(from: userLocation)})
            places = sortedPlaces
            _ = places.map {print($0.placeName, $0.latitude, $0.longitude)}
            tableView.reloadData()
        default:
            print("ERROR: You should never have gotten here!")
        }
    }
    
    @IBAction func unwindFromDetail(segue: UIStoryboardSegue) {
        let source = segue.source as! DetailViewController
        newImages = source.newImages
        if tableView.indexPathForSelectedRow != nil {
            let indexOfMatch = places.index(where: {$0.placeDocumentID == source.placeData?.placeDocumentID})!
            places[indexOfMatch] = (source.placeData)!
            saveData(placeData: places[indexOfMatch])
        } else {
            let newIndexPath = IndexPath(row: places.count, section: 0)
            places.append((source.placeData)!)
            saveData(placeData: (source.placeData)!)
        }
    }
    
    @IBAction func signOutButtonPressed(_ sender: UIBarButtonItem) {
        do {
            try authUI!.signOut()
            print("^^^ Successfully signed out!")
            signIn()
        } catch {
            print("Couldn't sign out")
        }
    }
    
    @IBAction func sortSegmentPressed(_ sender: UISegmentedControl) {
        sortBasedOnSegmentPressed()
    }
 }
 

extension PlaceListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PlaceTableViewCell
        cell.placeNameLabel?.text = places[indexPath.row].placeName
        let distanceInMeters = places[indexPath.row].location.distance(from: userLocation)
        let distanceInMiles = "Distance: "+String(format: "%.2f", (distanceInMeters * 0.00062137))+" miles"
        cell.distanceLabel.text = distanceInMiles
        return cell
    }
}

extension PlaceListViewController: FUIAuthDelegate {
    
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        let sourceApplication = options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String?
        if FUIAuth.defaultAuthUI()?.handleOpen(url, sourceApplication: sourceApplication) ?? false {
            return true
        }
        // other URL handling goes here.
        return false
    }
    
    func authUI(_ authUI: FUIAuth, didSignInWith user: User?, error: Error?) {
        if let user = user {
            print("*** Successfully logged in with user = \(user.email!)")
        }
    }
    
    func authPickerViewController(forAuthUI authUI: FUIAuth) -> FUIAuthPickerViewController {
        let loginViewController = FUIAuthPickerViewController(authUI: authUI)
        loginViewController.view.backgroundColor = UIColor.white
        
        let marginInset: CGFloat = 16
        let imageY = self.view.center.y - 225
        
        let logoFrame = CGRect(x: self.view.frame.origin.x + marginInset, y: imageY, width: self.view.frame.width - (marginInset*2), height: 225)
        let logoImageView = UIImageView(frame: logoFrame)
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        loginViewController.view.addSubview(logoImageView)
        
        return loginViewController
    }
}
