//
//  PhotoViewController.swift
//  Snacktacular
//
//  Created by John Gallaugher on 12/1/17.
//  Copyright © 2017 John Gallaugher. All rights reserved.
//

import UIKit

class PhotoViewController: UIViewController {
    @IBOutlet weak var photoImageView: UIImageView!
    var photoImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let photoImage = photoImage {
            photoImageView.image = photoImage
        }
    }
}
