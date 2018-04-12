//
//  VideoUtils.swift
//
//  Created by Karoud Mounir on 05/12/2017.
//  Copyright © 2017 Karoud Mounir. All rights reserved.
//

import UIKit
import Foundation
import CoreMedia
import AVFoundation
import Photos

//This is the name of the album where videos will be saved in camera roll
let MyAlbumTitle = "MyAlbumTitle"

//This function let's you save a video to camera roll.
//You need to pass the url of the video you want to save
func saveVideo(withURL url: URL) {
    PHPhotoLibrary.shared().performChanges({
        let albumAssetCollection = albumAssetCollections(withTitle: MyAlbumTitle)
        if albumAssetCollection == nil {
            let changeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: MyAlbumTitle)
            let _ = changeRequest.placeholderForCreatedAssetCollection
        }}, completionHandler: { (success1: Bool, error1: Error?) in
            if let albumAssetCollection = albumAssetCollections(withTitle: MyAlbumTitle) {
                PHPhotoLibrary.shared().performChanges({
                    if let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) {
                        let assetCollectionChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                        if let placeholder = assetChangeRequest.placeholderForCreatedAsset {
                            let enumeration: NSArray = [placeholder]
                            assetCollectionChangeRequest?.addAssets(enumeration)
                        }
                    }
                }, completionHandler: { (success2: Bool, error2: Error?) in
                    if success2 == true {
                        debugPrint("Video saved")
                    } else {
                        debugPrint("Error saving video")
                    }
                })
            }
    })
}

//This is function is need to save the video to camera roll
func albumAssetCollections(withTitle title: String) -> PHAssetCollection? {
    let predicate = NSPredicate(format: "localizedTitle = %@", title)
    let options = PHFetchOptions()
    options.predicate = predicate
    let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
    if result.count > 0 {
        return result.firstObject
    }
    return nil
}

//This useful function let's you compress a video to the format you want, for example in this case it compress
//videos to the .mp4 format with a resolution of 640x480.
//Using the handler you can notice if the compression was successful or not.
func compressVideo(inputURL: URL, outputURL: URL, handler:@escaping (_ exportSession: AVAssetExportSession?)-> Void) {
    let urlAsset = AVURLAsset(url: inputURL, options: nil)
		//Change the presetName to change the resolution
    guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPreset640x480) else {
        handler(nil)
        
        return
    }
    
    exportSession.outputURL = outputURL
		//Change the outputFileType with the extension you want. (Not all extensions are supported)
    exportSession.outputFileType = AVFileType.mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.exportAsynchronously { () -> Void in
        handler(exportSession)
    }
}

//Return a thumbnail given the url of a video. You can choose the exact time at which get the frame if you want
func getThumbnailFrom(path: URL) -> UIImage? {
    do {
        let asset = AVURLAsset(url: path , options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        
        return thumbnail
    } catch let error {
        debugPrint("*** Error generating thumbnail: \(error.localizedDescription)")
        return nil
    }
}

//You can easily put a watermark in the bottom right corner of your video with this function
func addWatermark(inputURL: URL, outputURL: URL, handler:@escaping (_ exportSession: AVAssetExportSession?)-> Void) {
    let tmpOutput = NSURL.fileURL(withPath: NSTemporaryDirectory() + NSUUID().uuidString + "0.mp4")
    let mixComposition = AVMutableComposition()
    let asset = AVAsset(url: inputURL)
    let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
    let timerange = CMTimeRangeMake(kCMTimeZero, asset.duration)
    
    let compositionVideoTrack:AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))!
    
    do {
        try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: kCMTimeZero)
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
    } catch {
        debugPrint(error)
    }
    
    let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
		//Here you put the image you want to use as a watermark
    let watermarkImage = CIImage(image: UIImage(named: "waterMark")!)
    let videoComposition = AVVideoComposition(asset: asset) { (filteringRequest) in
        let source = filteringRequest.sourceImage.clampedToExtent()
        watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
        let transform = CGAffineTransform(translationX: filteringRequest.sourceImage.extent.width - (watermarkImage?.extent.width)! - 2, y: 0)
        watermarkFilter.setValue(watermarkImage?.transformed(by: transform), forKey: "inputImage")
        filteringRequest.finish(with: watermarkFilter.outputImage!, context: nil)
    }
    
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else {
        handler(nil)
        
        return
    }
    
    exportSession.outputURL = tmpOutput
    exportSession.outputFileType = AVFileType.mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.videoComposition = videoComposition
    exportSession.exportAsynchronously {
        handler(exportSession)
    }
}

//It let's you put a video in a square, very useful if you want to share a video on Instagram.
//It will create a square of the size you want with white background and center the video in the square.
func squareVideo(inputURL: URL, outputURL: URL, squareSize: Int, handler:@escaping (_ exportSession: AVAssetExportSession?)-> Void) {
    
    let mixComposition = AVMutableComposition()
    let asset = AVAsset(url: inputURL)
    let videoTrack = asset.tracks(withMediaType: AVMediaType.video)[0]
    let timerange = CMTimeRangeMake(kCMTimeZero, asset.duration)
    
    let compositionVideoTrack:AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))!
    
    do {
        try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: kCMTimeZero)
        compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
    } catch {
        debugPrint(error)
    }
    
    let mutableVideoComposition = AVMutableVideoComposition()
    mutableVideoComposition.frameDuration = CMTimeMake(1, 30)
    mutableVideoComposition.renderSize = CGSize(width: sqaureSize, height: squareSize)
    let instructions = AVMutableVideoCompositionInstruction()
    instructions.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
    let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    let x = (videoTrack.naturalSize.height - videoTrack.naturalSize.width) / 2
    let finalTransform = CGAffineTransform(translationX: x, y: 0)//.rotated(by: .pi / 2)
    transformer.setTransform(finalTransform, at: kCMTimeZero)
		//Here you can change the background color of the square
    instructions.backgroundColor = myWhite.cgColor
    instructions.layerInstructions = [transformer]
    mutableVideoComposition.instructions = [instructions]
    
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset640x480) else {
        handler(nil)
        
        return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = AVFileType.mp4
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.videoComposition = mutableVideoComposition
    exportSession.exportAsynchronously {
        handler(exportSession)
    }
}
