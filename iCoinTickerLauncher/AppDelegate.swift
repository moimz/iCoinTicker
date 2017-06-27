//
//  AppDelegate.swift
//  iCoinTickerLauncher
//
//  Created by Arzz on 2017. 6. 28..
//  Copyright © 2017 Moimz. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppIdentifier = "com.moimz.iCoinTicker"
        
        var mainAppRunning = false
        for app in NSWorkspace.shared().runningApplications {
            if (app.bundleIdentifier == mainAppIdentifier) {
                mainAppRunning = true
                break
            }
        }
        
        if (mainAppRunning == false) {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(self.terminate), name: Notification.Name("killme"), object: mainAppIdentifier)
            
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("iCoinTicker") //main app name
            
            let newPath = NSString.path(withComponents: components)
            
            NSWorkspace.shared().launchApplication(newPath)
        } else {
            self.terminate()
        }
    }
    
    func terminate() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
}

