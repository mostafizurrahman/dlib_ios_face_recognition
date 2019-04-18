//
//  ViewController.swift
//  DisplayLiveSamples
//
//  Created by Luis Reisewitz on 15.05.16.
//  Copyright © 2016 ZweiGraf. All rights reserved.
//

import UIKit
import AVFoundation

struct UserData{
    let imageName:String
    let faceVector:[Float]
    
}

class ViewController: UIViewController {
    let sessionHandler = SessionHandler()
    
    @IBOutlet var nameLabels: [UILabel]!
    @IBOutlet weak var labelContainerView: UIView!
    
    let pointerToFloats = UnsafeMutablePointer<Float>.allocate(capacity: 128)
    @IBOutlet weak var recogImageView: UIImageView!
    @IBOutlet weak var findingLabel: UILabel!
    
    @IBOutlet weak var recogLable: UILabel!
    @IBOutlet weak var preview: UIView!
    var fid_array:[FaceID] = []
    @IBOutlet var btn: [UIButton]!
    var userDataArray:[UserData] = []
    var personName:String = ""
    var selectedIndex = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = Bundle.main.path(forResource: "face_data", ofType: "txt") {
            let data = try! String(contentsOfFile: path)
            let lines = data.split(separator: "\n")
            for line in lines {
                let dataArray = line.split(separator: "_")
                var floats = [Float]()
                for i in 1...128 {
                    let str_f = dataArray[i]
                    let val_f = Float(str_f) ?? 0
                    floats.append(val_f)
                }
                let person = dataArray[0]
                let data = UserData(imageName: String(person), faceVector: floats)
                self.userDataArray.append(data)
            }
        }
        
        print("done")
        
        if let wrapper = self.sessionHandler.wrapper {
            for data in self.userDataArray {
                for i in 0...127 {
                    pointerToFloats[i] = data.faceVector[i]
                }
                wrapper.setFaceVectors(pointerToFloats)
            }
        }
        
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
        if let wrapper = self.sessionHandler.wrapper {
            wrapper.imageRecognizeCheck = true
            wrapper.singleRecognizer = !wrapper.singleRecognizer
            self.faceCollectionView.isHidden = !wrapper.singleRecognizer
            self.labelContainerView.isHidden = wrapper.singleRecognizer
        }
        
    }
}

extension ViewController:RecognitionDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    func onFindIndices(_ indices: UnsafeMutablePointer<Int32>?, count: Int32) {
        DispatchQueue.main.async {
            for label in self.nameLabels {
                label.textColor = UIColor.red
                label.backgroundColor = UIColor.clear
            }
            if count == 0 {
                return
            }
            for i in 0...count-1 {
                if let index = indices?[Int(i)],
                    index != -1 {
                    let data = self.userDataArray[Int(index)]
                    for label in self.nameLabels {
                        if let name = label.text,
                            name.elementsEqual(data.imageName){
                            label.textColor = UIColor.green
                            label.backgroundColor = UIColor.lightGray
                            break
                        }
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.userDataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FID", for: indexPath)
        let data =  self.userDataArray[indexPath.row]
        if let _imageView = cell.viewWithTag(121) as? UIImageView {
            let person = data.imageName
            let image = UIImage(named: person )
            _imageView.image = image
            _imageView.layer.cornerRadius = _imageView.frame.width / 2
            _imageView.layer.masksToBounds = true
            _imageView.layer.borderColor = self.selectedIndex
                == indexPath.row ? UIColor.red.cgColor : UIColor.gray.cgColor
            _imageView.layer.borderWidth = 2
        }
        if let name = cell.viewWithTag(120) as? UILabel {
            name.text = data.imageName
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
            self.recogLable.text = self.personName
        }
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.selectedIndex != -1 {
            let s_indexPath = IndexPath(row: self.selectedIndex, section: 0)
            if let item = collectionView.cellForItem(at: s_indexPath) {
                if let _imgView = item.viewWithTag(121) {
                    _imgView.layer.borderColor = UIColor.gray.cgColor
                }
            }
        }
        
        if let item = collectionView.cellForItem(at: indexPath){
            if let imageView = item.viewWithTag(121) {
                imageView.layer.borderColor = UIColor.red.cgColor
            }
        }
        self.selectedIndex = indexPath.row
        let data = self.userDataArray[indexPath.row]
        
        // Copying our data into the freshly allocated memory
        for i in 0...127 {
            pointerToFloats[i] = data.faceVector[i]
        }
        
        self.sessionHandler.wrapper?.recognizeVector(pointerToFloats)

        self.personName = "recognised\n\(data.imageName)"
        collectionView.reloadData()
    }
}
