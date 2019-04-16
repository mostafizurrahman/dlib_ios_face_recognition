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
    
    @IBOutlet weak var preview: UIView!
    
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

    }
    
    
    @IBAction func train_image(_ sender: Any) {
        sessionHandler.wrapper?.imageRecognize = true
    }
    
    @IBAction func recog_nise(_ sender: Any) {
        sessionHandler.wrapper?.imageRecognizeCheck = true
        
    }
    
    
    
}

