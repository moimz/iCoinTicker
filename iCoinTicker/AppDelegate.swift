//
//  AppDelegate.swift
//  iCoinTicker
//
//  Created by Arzz on 2017. 5. 22..
//  Copyright © 2017 Moimz. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var appname: NSTextField!
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var refresh: NSMenuItem!
    
    @IBOutlet weak var korbit: NSMenuItem!
    @IBOutlet weak var bithumb: NSMenuItem!
    @IBOutlet weak var coinone: NSMenuItem!
    
    @IBOutlet weak var btc: NSMenuItem!
    @IBOutlet weak var eth: NSMenuItem!
    
    @IBOutlet weak var krw: NSMenuItem!
    @IBOutlet weak var usd: NSMenuItem!
    
    @IBOutlet weak var refresh10: NSMenuItem!
    @IBOutlet weak var refresh30: NSMenuItem!
    @IBOutlet weak var refresh60: NSMenuItem!
    @IBOutlet weak var refresh300: NSMenuItem!
    @IBOutlet weak var refresh600: NSMenuItem!
    @IBOutlet weak var refresh1800: NSMenuItem!
    @IBOutlet weak var refresh3600: NSMenuItem!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    let space = "    "
    var title = "Loading..."
    var timer = Timer()
    var time = Double(300)
    var market = "Korbit"
    var coin = "BTC"
    var currency = "KRW"
    
    let korbitUrl = "https://api.korbit.co.kr/v1/ticker?currency_pair="
    let bithumbUrl = "https://api.bithumb.com/public/ticker/"
    let coinoneUrl = "https://api.coinone.co.kr/ticker/?currency="
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.market = UserDefaults.standard.string(forKey: "market") == nil ? "Korbit" : UserDefaults.standard.string(forKey: "market")!
        self.coin = UserDefaults.standard.string(forKey: "coin") == nil ? "BTC" : UserDefaults.standard.string(forKey: "coin")!
        self.currency = UserDefaults.standard.string(forKey: "currency") == nil ? "KRW" : UserDefaults.standard.string(forKey: "currency")!
        self.market = UserDefaults.standard.string(forKey: "market") == nil ? "Korbit" : UserDefaults.standard.string(forKey: "market")!
        self.time = UserDefaults.standard.double(forKey: "time") == Double(0) ? Double(300) : UserDefaults.standard.double(forKey: "time")
        
        korbit.state = NSOffState
        bithumb.state = NSOffState
        coinone.state = NSOffState
        
        switch (self.market) {
        case "Korbit":
            korbit.state = NSOnState
            break
            
        case "Bithumb":
            bithumb.state = NSOnState
            break
            
        case "Coinone":
            coinone.state = NSOnState
            break
            
        default:
            break
        }
        
        btc.state = NSOffState
        eth.state = NSOffState
        
        switch (self.coin) {
        case "BTC":
            btc.state = NSOnState
            break
            
        case "ETH":
            eth.state = NSOnState
            break
            
        default:
            break
        }
        
        krw.state = NSOffState
        usd.state = NSOffState
        
        switch (self.currency) {
        case "KRW":
            krw.state = NSOnState
            break
            
        case "USD":
            usd.state = NSOnState
            break
            
        default:
            break
        }
        
        refresh10.state = NSOffState
        refresh30.state = NSOffState
        refresh60.state = NSOffState
        refresh300.state = NSOffState
        refresh600.state = NSOffState
        refresh1800.state = NSOffState
        refresh3600.state = NSOffState
        
        switch (self.time) {
        case 10:
            refresh10.state = NSOnState
            break
            
        case 30:
            refresh30.state = NSOnState
            break
            
        case 60:
            refresh60.state = NSOnState
            break
            
        case 300:
            refresh300.state = NSOnState
            break
            
        case 600:
            refresh600.state = NSOnState
            break
            
        case 1800:
            refresh1800.state = NSOnState
            break
            
        case 3600:
            refresh3600.state = NSOnState
            break
            
        default:
            break
        }
        
        
        let icon = NSImage(named: self.coin.lowercased())
        
        statusItem.image = icon
        statusItem.menu = statusMenu
        statusItem.title = title+space
        
        self.getData()
        
        timer = Timer.scheduledTimer(timeInterval: self.time, target: self, selector: #selector(AppDelegate.getData), userInfo: nil, repeats: true)
        
    }
    
    func getData(){
        let session = URLSession.shared
        var apiUrl = ""
        
        if (self.market == "Korbit") {
            apiUrl = self.korbitUrl + self.coin.lowercased() + "_" + self.currency.lowercased()
        } else if (self.market == "Bithumb") {
            apiUrl = self.bithumbUrl + self.coin
        } else if (self.market == "Coinone") {
            apiUrl = self.coinoneUrl + self.coin.lowercased()
        }
        
        let jsonUrl = URL(string: apiUrl)
        
        let task = session.dataTask(with: jsonUrl!, completionHandler: {
            (data, response, error) -> Void in
            
            do {
                let jsonData: AnyObject? = try JSONSerialization.jsonObject(with: data!, options:JSONSerialization.ReadingOptions.mutableContainers ) as! NSDictionary
                
                var currency = Double(0)
                
                if (self.market == "Korbit") {
                    currency = Double(jsonData!["last"] as! String)!
                } else if (self.market == "Bithumb") {
                    let json: AnyObject? = jsonData!["data"] as! NSDictionary
                    currency = Double(json!["closing_price"] as! String)!
                } else if (self.market == "Coinone") {
                    currency = Double(jsonData!["last"] as! String)!
                }
                
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                
                let price = numberFormatter.string(from: NSNumber(value: currency))!
                
                let icon = NSImage(named: self.coin.lowercased())
                self.statusItem.image = icon
                self.statusItem.title = price
                
                let todaysDate = Date()
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
                let DateInFormat = dateFormatter.string(from: todaysDate)
                self.refresh.title = "Refresh : " + "\(DateInFormat)"
            } catch _ {
                // Error
            }
        })
        
        task.resume()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @IBAction func info(_ sender: AnyObject) {
        self.window!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        self.appname.stringValue = "iCoinTicker v" + version
    }
    
    @IBAction func market(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            korbit.state = NSOffState
            bithumb.state = NSOffState
            coinone.state = NSOffState
            
            self.market = sender.title
            sender.state = NSOnState
            
            UserDefaults.standard.set(self.market, forKey:"market")
            
            self.getData()
        }
    }
    
    @IBAction func coin(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            btc.state = NSOffState
            eth.state = NSOffState
            
            self.coin = sender.title
            sender.state = NSOnState
            
            UserDefaults.standard.set(self.coin, forKey:"coin")
            
            self.getData()
        }
    }
    
    @IBAction func currency(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            krw.state = NSOffState
            usd.state = NSOffState
            
            self.currency = sender.title
            sender.state = NSOnState
            
            UserDefaults.standard.set(self.currency, forKey:"currency")
            
            self.getData()
        }
    }
    
    @IBAction func refresh(_ sender: AnyObject) {
        self.getData()
    }
    
    @IBAction func refreshTime(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            refresh10.state = NSOffState
            refresh30.state = NSOffState
            refresh60.state = NSOffState
            refresh300.state = NSOffState
            refresh600.state = NSOffState
            refresh1800.state = NSOffState
            refresh3600.state = NSOffState
            
            sender.state = NSOnState
            
            self.time = Double(sender.tag)
            
            UserDefaults.standard.set(self.time, forKey:"time")
            
            timer.invalidate()
            timer = Timer.scheduledTimer(timeInterval: self.time, target: self, selector: #selector(AppDelegate.getData), userInfo: nil, repeats: true)
        }
    }
    
    @IBAction func quit(_ sender: AnyObject) {
        timer.invalidate()
        exit(0)
    }
}
