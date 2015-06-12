//
//  AppDelegate.swift
//  CatNap
//
//  Created by Marin Todorov on 4/9/15.
//  Copyright (c) 2015 Razeware ltd. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Override point for customization after application launch.
    return true
  }
    
    
    func application(application: UIApplication, supportedInterfaceOrientationsForWindow window: UIWindow?) -> Int {
        return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
    }
  
}