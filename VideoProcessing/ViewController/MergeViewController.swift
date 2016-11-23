//
//  MergeViewController.swift
//  VideoProcessing
//
//  Created by Monkey on 11/19/16.
//  Copyright © 2016 Monkey. All rights reserved.
//

import UIKit
import AVFoundation
import DKImagePickerController
import AVKit
import AssetsLibrary

let TIMESCALE = 30

class MergeViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    
    var assets: [DKAsset]?
    @IBOutlet var tableView: UITableView!
    @IBOutlet var btnMerge: UIButton!
    @IBOutlet var btnPreview: UIButton!
    @IBOutlet var btnSaveToGallery: UIButton!
    @IBOutlet var imageView: UIImageView!
    private var filePath: NSString!
    private var av_AssetList: [AVAsset]!
    private var assetTrackList: [AVAssetTrack]!
    private var assetTrackAudioList: [AVAssetTrack?]!
    private var timeDurations: [NSValue]!
    private var imageList: [UIImage]!
    
    private var imageAsset: AVAsset!
    
    private var indexOfVideo: Int!
    private var indexOfPhoto: Int!
    private var indexOfAsset: Int!
    
    var videoFilePath : String!
    var resultFilePath : String!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        indexOfVideo = 0
        indexOfPhoto = 0
        indexOfAsset = 0
        
        // Do any additional setup after loading the view.
        av_AssetList = [AVAsset]()
        imageList = [UIImage]()
        assetTrackList = [AVAssetTrack]()
        timeDurations = [NSValue]()
        assetTrackAudioList = [AVAssetTrack]()
        let pathForImage = Bundle.main.path(forResource: "StartVid", ofType: "MP4")
        self.imageAsset = AVAsset(url: URL(fileURLWithPath: pathForImage!))
        let filePaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        filePath = filePaths[0] as NSString!
        videoFilePath = filePath.appending("/video_photo")
        resultFilePath = filePath.appending("/result_video.mov")
        
        btnPreview.isHidden = true
        btnSaveToGallery.isHidden = true
        
        self.getAVAssets()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.isEditing = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // MARK: Get AVAssets
    private func getAVAssets() {
        btnPreview.isHidden = true
        btnSaveToGallery.isHidden = true
        btnMerge?.backgroundColor = UIColor.green
        if let assets = assets {
            if indexOfAsset >= (assets.count) {
                return
            }
            
            if (assets[indexOfAsset].isVideo) {
                assets[indexOfAsset].fetchAVAssetWithCompleteBlock({ (avAsset, _) in
                    if let avasset = avAsset {
                        self.av_AssetList.append(avasset)
                        self.indexOfAsset = self.indexOfAsset + 1
                        self.getAVAssets()
                    }
                })
            } else {
                assets[indexOfAsset].fetchOriginalImage(true, completeBlock: { (image, _) in
                    self.imageList.append(image!)
                    self.indexOfAsset = self.indexOfAsset + 1
                    self.getAVAssets()
                })
            }
        }
    }

    // MARK: Button Action
    @IBAction func onClickedMergeButton(sender: UIButton?) {
        
        sender?.backgroundColor = UIColor.darkGray
        btnPreview.isHidden = false
        btnSaveToGallery.isHidden = false
        
        indexOfVideo = 0
        indexOfPhoto = 0
        
        self.makeAVAssetList()
        self.timeDurationMake()
        
        MBProgressHUD.showAdded(to: self.view, animated: true)
        self.mergeVideoAndPhoto()
    }
    
    @IBAction func onClickedPreviewButton(sender: UIButton?) {
        let playerVC = AVPlayerViewController()
        let player = AVPlayer(url: URL(fileURLWithPath: resultFilePath))
        playerVC.player = player
        self.present(playerVC, animated: true) { 
            player.play()
        }
    }
    
    @IBAction func onClickedSaveButton(sender: UIButton?) {
        
        let videoFileUrl = URL(fileURLWithPath: resultFilePath)
        MBProgressHUD.showAdded(to: self.view, animated: true)
        let library = ALAssetsLibrary()
        if library.videoAtPathIs(compatibleWithSavedPhotosAlbum: videoFileUrl) {
            library.writeVideoAtPath(toSavedPhotosAlbum: videoFileUrl, completionBlock: { (assetUrl, error) in
                if let error = error {
                    print("Error====", error)
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Cannot Save videod!", title: "Error")
                } else {
                    print("Video Saved")
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Video Saved Successfully", title: "Success")
                }
            })
        }
    }
    
    // MARK: Merge Video and Photo
    func mergeVideoAndPhoto() {
        
        if indexOfVideo >= (assets?.count)! {
            self.mergeVideos()
            return
        }
        
        let composition = AVMutableComposition()
        let compositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            try compositionTrack.insertTimeRange(timeDurations[indexOfVideo].timeRangeValue, of: assetTrackList[indexOfVideo], at: kCMTimeZero)
            if let audioTrack = assetTrackAudioList[indexOfVideo] {
                let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try audioCompositionTrack.insertTimeRange(timeDurations[indexOfVideo].timeRangeValue, of: audioTrack, at: kCMTimeZero)
                compositionTrack.preferredTransform = assetTrackList[indexOfVideo].preferredTransform
            }
        } catch {
            MBProgressHUD.hide(for: self.view, animated: true)
            self.showAlertWith(message: "Cannot merge videod!", title: "Error")
        }
        
        var layerComposition: AVMutableVideoComposition? = nil
        
        if !(assets?[indexOfVideo].isVideo)! {
            
            var isVideoAssetPortrait = false
            let videoTransform = assetTrackList[indexOfVideo].preferredTransform
            var videoAssetOrientation = UIImageOrientation.up
            if videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0 { videoAssetOrientation = UIImageOrientation.right; isVideoAssetPortrait = true }
            if videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0 { videoAssetOrientation = UIImageOrientation.left; isVideoAssetPortrait = true }
            if videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0 { videoAssetOrientation = UIImageOrientation.up }
            if videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0 { videoAssetOrientation = UIImageOrientation.down }
        
            let naturalSize = assetTrackList[indexOfVideo].naturalSize
        
            let insertImageLayer = CALayer()
            let backgroundLayer = CALayer()
            let parentLayer = CALayer()
            
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height))
            imageView.image = imageList[indexOfPhoto]
            imageView.contentMode = UIViewContentMode.scaleAspectFit
            
            if imageList[indexOfPhoto].imageOrientation == UIImageOrientation.down {
                print("Image is sdfasdfasdf")
            } else if imageList[indexOfPhoto].imageOrientation == UIImageOrientation.left || imageList[indexOfPhoto].imageOrientation == .right {
                print("Image is portrait")
                imageView.contentMode = .scaleToFill
            }
            insertImageLayer.frame = CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height)
            backgroundLayer.frame = CGRect(x: 0, y: 0, width: naturalSize.width, height: naturalSize.height)
          
            print("Video natureal size %f", insertImageLayer.frame.size)
            
            insertImageLayer.addSublayer(imageView.layer)
            insertImageLayer.contentsGravity = kCAGravityResizeAspect
            insertImageLayer.backgroundColor = UIColor.black.cgColor
            
            indexOfPhoto = indexOfPhoto + 1
            
            parentLayer.addSublayer(backgroundLayer)
            parentLayer.addSublayer(insertImageLayer)
            
            layerComposition = AVMutableVideoComposition()
            layerComposition?.frameDuration = timeDurations[indexOfVideo].timeRangeValue.duration
            layerComposition?.animationTool = AVVideoCompositionCoreAnimationTool.init(postProcessingAsVideoLayer: backgroundLayer, in: parentLayer)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeDurations[indexOfVideo].timeRangeValue
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetTrackList[indexOfVideo])
    
            var forstAssetScaleToFitRatio = naturalSize.width / naturalSize.width
            if isVideoAssetPortrait {
                forstAssetScaleToFitRatio = naturalSize.width / naturalSize.height
                let firstAssetScaleFactor = CGAffineTransform.init(scaleX: CGFloat(forstAssetScaleToFitRatio), y: CGFloat(forstAssetScaleToFitRatio))
                layerInstruction.setTransform(assetTrackList[indexOfVideo].preferredTransform.concatenating(firstAssetScaleFactor), at: kCMTimeZero)
            } else {
                let firstAssetScaleFactor = CGAffineTransform.init(scaleX: CGFloat(forstAssetScaleToFitRatio), y: CGFloat(forstAssetScaleToFitRatio))
                layerInstruction.setTransform(assetTrackList[indexOfVideo].preferredTransform.concatenating(firstAssetScaleFactor).concatenating(CGAffineTransform(translationX: 0, y: 0)), at: kCMTimeZero)
            }
            instruction.layerInstructions = [layerInstruction]
            layerComposition?.instructions = [instruction]
            layerComposition?.renderSize = naturalSize
        }
        
        let videoFileUrl = URL(fileURLWithPath: String(format: "%@%d.mov", videoFilePath,indexOfVideo))
        print("video file url", videoFileUrl)
        if FileManager.default.fileExists(atPath: String(format: "%@%d.mov", videoFilePath,indexOfVideo)) {
            do {
                try FileManager.default.removeItem(atPath: String(format: "%@%d.mov", videoFilePath,indexOfVideo))
            } catch {
                print("========== Error ===========")
                MBProgressHUD.hide(for: self.view, animated: true)
                self.showAlertWith(message: "Cannot merge videod!", title: "Error")
            }
        }
        
        let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        assetExport?.outputFileType = AVFileTypeQuickTimeMovie
        assetExport?.outputURL = videoFileUrl
        assetExport?.videoComposition = layerComposition
        assetExport?.timeRange = timeDurations[indexOfVideo].timeRangeValue
        assetExport?.exportAsynchronously(completionHandler: {
            if let assetExport = assetExport {
                switch assetExport.status {
                
                case .failed:
                    print("------------ Error --------- : export hightlight files")
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Cannot merge videod!", title: "Error")
                    break
                case .cancelled:
                    print("------------ Error --------- : export hightlight files")
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Cannot merge videod!", title: "Error")
                    break
                case .completed:
                    
                    self.indexOfVideo = self.indexOfVideo + 1
                    self.mergeVideoAndPhoto()
                    break
                default:
                    
                    break
                }
            }
        })
        
    }
    
    func mergeVideos() {
        var assetTracks: [AVAsset] = [AVAsset]()

        for i in 0 ... (assets?.count)! - 1 {
            print(String(format: "%@%d.mov", videoFilePath,i))
            let avAsset = AVAsset(url: URL(fileURLWithPath: String(format: "%@%d.mov", videoFilePath,i)))
            assetTracks.append(avAsset)
        }
        
        let composition = AVMutableComposition()
        
        var arrayInstructions = [AVMutableVideoCompositionLayerInstruction]()
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        
        var duration = kCMTimeZero
        
        for i in 0 ... (assets?.count)! - 1 {
            let compositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            let assetTrack = assetTracks[i].tracks(withMediaType: AVMediaTypeVideo)[0]
            let audioAssetTrack: AVAssetTrack?
            if assetTracks[i].tracks(withMediaType: AVMediaTypeAudio).count != 0 {
                audioAssetTrack = assetTracks[i].tracks(withMediaType: AVMediaTypeAudio)[0]
            } else {
                audioAssetTrack = nil
            }
            
            do{
                try compositionTrack.insertTimeRange(timeDurations[i].timeRangeValue, of: assetTrack, at: duration)
                if audioAssetTrack != nil {
                    let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try audioCompositionTrack.insertTimeRange(timeDurations[i].timeRangeValue, of: audioAssetTrack!, at: duration)
                }
            } catch let error as Error{
                print(error)
                MBProgressHUD.hide(for: self.view, animated: true)
                self.showAlertWith(message: "Cannot merge videod!", title: "Error")
            }
            
            let currentAssetLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
            
            var currentOrientation = UIImageOrientation.up
            var isCurrentAssetPortrait = false;
            let currentTransform = assetTrack.preferredTransform
            
            if currentTransform.a == 0 && currentTransform.b == 1.0 && currentTransform.c == -1.0 && currentTransform.d == 0 {
                currentOrientation = UIImageOrientation.right
                isCurrentAssetPortrait = true
            }
            if currentTransform.a == 0 && currentTransform.b == -1.0 && currentTransform.c == 1.0 && currentTransform.d == 0 {
                currentOrientation = UIImageOrientation.left
                isCurrentAssetPortrait = true
            }
            if currentTransform.a == 1.0 && currentTransform.b == 0 && currentTransform.c == 0 && currentTransform.d == -1.0 {
                currentOrientation = UIImageOrientation.up
            }
            if currentTransform.a == -1.0 && currentTransform.b == 0 && currentTransform.c == 0 && currentTransform.d == 1.0 {
                currentOrientation = UIImageOrientation.down
            }
            
            var forstAssetScaleToFitRatio = self.view.frame.size.width / assetTrack.naturalSize.width
            if isCurrentAssetPortrait {
                forstAssetScaleToFitRatio = self.view.frame.size.width / assetTrack.naturalSize.height
                let firstAssetScaleFactor = CGAffineTransform.init(scaleX: CGFloat(forstAssetScaleToFitRatio), y: CGFloat(forstAssetScaleToFitRatio))
                currentAssetLayerInstruction.setTransform(assetTrack.preferredTransform.concatenating(firstAssetScaleFactor), at: duration)
            } else {
                
                let firstAssetScaleToYRatio = assetTrack.naturalSize.height * forstAssetScaleToFitRatio / self.view.frame.size.height
                let delta = (1 - firstAssetScaleToYRatio) * self.view.frame.height / 2.0
                let firstAssetScaleFactor = CGAffineTransform.init(scaleX: CGFloat(forstAssetScaleToFitRatio), y: CGFloat(forstAssetScaleToFitRatio))
                
                currentAssetLayerInstruction.setTransform(assetTrack.preferredTransform.concatenating(firstAssetScaleFactor).concatenating(CGAffineTransform(translationX: 0, y: delta)), at: duration)
                
            }
            
            duration = CMTimeAdd(duration, timeDurations[i].timeRangeValue.duration)
            
            currentAssetLayerInstruction .setOpacity(0.0, at: duration)
            arrayInstructions.append(currentAssetLayerInstruction)
        }
        
        var totalTimeRange: CMTimeRange = kCMTimeRangeZero
        for timeRange in timeDurations {
            totalTimeRange = creatTimeRangeFromTwo(firstTimeRange: totalTimeRange, secondTimeRange: timeRange.timeRangeValue)
        }
        
        mainInstruction.timeRange = totalTimeRange
        mainInstruction.layerInstructions = arrayInstructions
        let mainCompositionInst = AVMutableVideoComposition()
        mainCompositionInst.instructions = [mainInstruction]
        mainCompositionInst.frameDuration = CMTimeMake(1, 30)
        mainCompositionInst.renderSize = self.view.frame.size
        
        let videoFileUrl = URL(fileURLWithPath: resultFilePath)
        print("video file url", videoFileUrl)
        if FileManager.default.fileExists(atPath: String(format: "%@", resultFilePath)) {
            do {
                try FileManager.default.removeItem(atPath: String(format: "%@", resultFilePath))
            } catch {
                
                MBProgressHUD.hide(for: self.view, animated: true)
                self.showAlertWith(message: "Cannot merge videod!", title: "Error")
            }
        }
        
        let assetExport = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        assetExport?.outputFileType = AVFileTypeQuickTimeMovie
        assetExport?.videoComposition = mainCompositionInst
        assetExport?.outputURL = videoFileUrl
        assetExport?.exportAsynchronously(completionHandler: {
            if let assetExport = assetExport {
                switch assetExport.status {
                    
                case .failed:
                    print("------------ Error --------- : merge 5 files")
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Cannot merge videod!", title: "Error")
                    break
                case .cancelled:
                    print("------------ Error --------- : merge 5 files")
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.showAlertWith(message: "Cannot merge videod!", title: "Error")
                    break
                case .completed:
                    print("------------ Success --------- : merge Successfully")
                    MBProgressHUD.hide(for: self.view, animated: false)
                    self.showAlertWith(message: "Successfully Merged!", title: "Success")
                    break
                default:
                    
                    break
                }
            }
        })
    }
    
    private func timeDurationMake() {
        
        timeDurations.removeAll()
        
        for asset in assets! {
            if asset.isVideo {
                let time = Int(asset.duration!) * TIMESCALE
                let timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(Int64(Int(time)), Int32(TIMESCALE)))
                self.timeDurations.append(NSValue.init(timeRange: timeRange))
            } else {
                let index = assets?.index(of: asset)
                let cell = tableView.cellForRow(at: IndexPath(row: index!, section: 0)) as! AssetTableViewCell
                let strDuration = cell.txtDurationOfPhoto.text
                var time = 0
                if let strDuration = strDuration {
                    time = Int(strDuration)! * TIMESCALE
                }
                let timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(Int64(Int(time)), Int32(TIMESCALE)))
                self.timeDurations.append(NSValue.init(timeRange: timeRange))
            }
        }
    }
    
    private func makeAVAssetList() {
        assetTrackList = [AVAssetTrack]()
        assetTrackAudioList = [AVAssetTrack]()
        if let assets = assets {
            var avIndex = 0
            
            for i in 0 ... assets.count - 1 {
                
                if assets[i].isVideo {
                    let assetTrack = av_AssetList[avIndex].tracks(withMediaType: AVMediaTypeVideo)[0]
                    let assetAudioTrack: AVAssetTrack?
                    if av_AssetList[avIndex].tracks(withMediaType: AVMediaTypeAudio).count != 0 {
                        assetAudioTrack = av_AssetList[avIndex].tracks(withMediaType: AVMediaTypeAudio)[0]
                    } else {
                        assetAudioTrack = nil
                    }
                    assetTrackList.append(assetTrack)
                    assetTrackAudioList.append(assetAudioTrack)
                    avIndex = avIndex + 1
                } else {
                    let assetTrack = imageAsset.tracks(withMediaType: AVMediaTypeVideo)[0]
                    assetTrackList.append(assetTrack)
                    assetTrackAudioList.append(nil)
                    
                }
            }
        }
    }
    
    private func creatTimeRangeFromTwo(firstTimeRange: CMTimeRange, secondTimeRange: CMTimeRange) -> CMTimeRange {
        let firstDuration = firstTimeRange.duration.value
        let secondDuration = secondTimeRange.duration.value
        let totalDuration = firstDuration + secondDuration
        
        return CMTimeRangeMake(kCMTimeZero, CMTimeMake(totalDuration, firstTimeRange.duration.timescale))
    }
    
    private func showAlertWith(message: String?, title: String?) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertVC.addAction(okAction)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    // Mark: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (assets?.count)!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AssetTableViewCell") as! AssetTableViewCell
        cell.lblOrderNumber.text = "Clip \(indexPath.row + 1)"
        let asset = (assets?[indexPath.row])! as DKAsset
        if asset.isVideo {
            cell.txtDurationOfPhoto.isHidden = true
            cell.lblDurationSecond.isHidden = true
            cell.lblMediaType.text = "Video"
        } else {
            cell.txtDurationOfPhoto.isHidden = false
            cell.lblDurationSecond.isHidden = false
            cell.lblMediaType.text = "Photo"
        }
        return cell
    }
    
    // Mark: UITableViewDelegate
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let preAsset = assets?[sourceIndexPath.row]
        assets?.remove(at: sourceIndexPath.row)
        assets?.insert(preAsset!, at: destinationIndexPath.row)
        tableView.reloadData()
        av_AssetList = [AVAsset]()
        imageList = [UIImage]()
        indexOfAsset = 0
        getAVAssets()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.none
    }
    
    
}
