//
//  ViewController.swift
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 15.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    let sessionHandler = SessionHandler()
    @IBOutlet weak var recogImageView: UIImageView!
    @IBOutlet weak var findingLabel: UILabel!
    
    @IBOutlet weak var recogLable: UILabel!
    @IBOutlet weak var preview: UIView!
    var fid_array:[FaceID] = []
    @IBOutlet var btn: [UIButton]!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sessionHandler.openSession()
        

        let layer = sessionHandler.layer
        layer.frame = preview.bounds

        preview.layer.addSublayer(layer)
        
        view.layoutIfNeeded()

        for b in btn {
            self.view.bringSubview(toFront: b)
        }

        self.view.bringSubview(toFront: self.faceCollectionView)
        self.sessionHandler.wrapper?.faceDelegate = self
        self.sessionHandler.label = self.recogLable
        self.sessionHandler.imageView = self.recogImageView
    }
    
    
    @IBAction func train_image(_ sender: Any) {
        sessionHandler.wrapper?.imageRecognize = true
    }
    
    @IBAction func recog_nise(_ sender: Any) {
        sessionHandler.wrapper?.imageRecognizeCheck = true
        
    }
    
    @IBOutlet weak var faceCollectionView: UICollectionView!
    
    @IBAction func skipPrediction(_ sender: UISwitch) {
        self.sessionHandler.skipPrediction = sender.isOn
    }
    
}

extension ViewController:RecognitionDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.fid_array.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FID", for: indexPath)
        if let _imageView = cell.viewWithTag(121) as? UIImageView {
            _imageView.image = self.fid_array[indexPath.row].faceImage
        }
        return cell
    }
    
    func didFoundFaces(_ fidArray: NSMutableArray!) {
        self.fid_array = fidArray as! [FaceID]
        DispatchQueue.main.async {
            self.faceCollectionView.reloadData()
        }
    }
    
    func onFaceFound(_ faceID: FaceID!) {
        self.fid_array.append(faceID)
        DispatchQueue.main.async {
            self.faceCollectionView.reloadData()
        }
    }
    
    
    func onRecognised(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.recogImageView.image = image
            self.recogLable.isHidden = image == nil
            
        }
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.sessionHandler.wrapper?.recognize(at: indexPath.row)
        self.findingLabel.isHidden = !(self.sessionHandler.wrapper?.imageRecognizeCheck ?? true)
        self.recogLable.isHidden = true
    }
}
