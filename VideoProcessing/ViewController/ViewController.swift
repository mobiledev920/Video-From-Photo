//
//  ViewController.swift
//  VideoProcessing
//
//  Created by Monkey on 11/19/16.
//  Copyright © 2016 Monkey. All rights reserved.
//

import UIKit
import DKImagePickerController

class ViewController: UIViewController {
    
    @IBOutlet var btnSelectClip: UIButton!
    var pickerController: DKImagePickerController!
    var assets: [DKAsset]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        pickerController = DKImagePickerController()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func onClickedSelectClipButton(sender: UIButton) {
        self.showImagePickerWithAssetType(.allAssets, allowMultipleType: true, allowsLandscape: false, singleSelect: false)
    }
    
    func showImagePickerWithAssetType(_ assetType: DKImagePickerControllerAssetType,
                                      allowMultipleType: Bool,
                                      sourceType: DKImagePickerControllerSourceType = .both,
                                      allowsLandscape: Bool,
                                      singleSelect: Bool) {
        
        let pickerController = DKImagePickerController()
        
        pickerController.assetType = assetType
        pickerController.allowsLandscape = allowsLandscape
        pickerController.allowMultipleTypes = allowMultipleType
        pickerController.sourceType = sourceType
        pickerController.singleSelect = singleSelect
        
   		pickerController.showsCancelButton = true
       
        // Clear all the selected assets if you used the picker controller as a single instance.
   		pickerController.defaultSelectedAssets = nil
        
        pickerController.didSelectAssets = { [unowned self] (assets: [DKAsset]) in
            print("didSelectAssets")
            
            self.assets = assets
            if assets.count != 0 {
                self.performSegue(withIdentifier: "MergeVCSegue", sender: nil)
            }
        }
        
        if UI_USER_INTERFACE_IDIOM() == .pad {
            pickerController.modalPresentationStyle = .formSheet
        }
        
        self.present(pickerController, animated: true) {}
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "MergeVCSegue" {
            let mergeVC = segue.destination as! MergeViewController
            mergeVC.assets = self.assets
        }
    }

}

