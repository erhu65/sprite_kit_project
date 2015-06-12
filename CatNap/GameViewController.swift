//
//  GameViewController.swift
//  CatNap
//
//  Created by Marin Todorov on 4/9/15.
//  Copyright (c) 2015 Razeware ltd. All rights reserved.
//

import UIKit
import SpriteKit

extension SKNode {
  class func unarchiveFromFile(file : String) -> SKNode? {
    if let path = NSBundle.mainBundle().pathForResource(file, ofType: "sks") {
      var sceneData = NSData(contentsOfFile: path, options: .DataReadingMappedIfSafe, error: nil)!
      var archiver = NSKeyedUnarchiver(forReadingWithData: sceneData)
      
      archiver.setClass(self.classForKeyedUnarchiver(), forClassName: "SKScene")
      let scene = archiver.decodeObjectForKey(NSKeyedArchiveRootObjectKey) as! GameScene
      archiver.finishDecoding()
      return scene
    } else {
      return nil
    }
  }
}

class GameViewController: UIViewController, ImageCaptureDelegate, UIImagePickerControllerDelegate,
UINavigationControllerDelegate{
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let scene = GameScene.level(6) {
      // Configure the view.
      let skView = self.view as! SKView
      skView.showsPhysics = true
      skView.showsFPS = true
      skView.showsNodeCount = true
      
      /* Sprite Kit applies additional optimizations to improve rendering performance */
      skView.ignoresSiblingOrder = false
      
      /* Set the scale mode to scale to fit the window */
      scene.scaleMode = .AspectFill
      
      skView.presentScene(scene)
      scene.imageCaptureDelegate = self
    }
  }
  
  override func shouldAutorotate() -> Bool {
    return true
  }
  
  override func supportedInterfaceOrientations() -> Int {
    if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
      return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
    } else {
      return Int(UIInterfaceOrientationMask.All.rawValue)
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Release any cached data, images, etc that aren't in use.
  }
  
  override func prefersStatusBarHidden() -> Bool {
    return true
  }
  
  
  func requestImagePicker() {
    let imagePickerControlller = UIImagePickerController()
    imagePickerControlller.delegate = self
    presentViewController(imagePickerControlller, animated: true, completion: nil)
  }
  
  
  func imagePickerController(picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [NSObject:AnyObject]) {
      //1
      let image =
      info[UIImagePickerControllerOriginalImage] as! UIImage
      //2
      picker.dismissViewControllerAnimated(true, completion: {
        //3
        let imageTexture = SKTexture(image: image)
        //4
        let skView = self.view as! SKView
        let gameScene = skView.scene as! GameScene
        //place core image code here
        //5
        gameScene.changePhotoTexture(imageTexture)
      })
  }
}