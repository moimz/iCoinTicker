//
//  AppDelegate.swift
//  iCoinTicker
//
//  Created by Arzz on 2017. 6. 3..
//  Copyright © 2017 Moimz. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var appname: NSTextField!
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var refresh: NSMenuItem!
    
    @IBOutlet weak var btc: NSMenuItem!
    @IBOutlet weak var btcMenu: NSMenu!
    
    @IBOutlet weak var eth: NSMenuItem!
    @IBOutlet weak var ethMenu: NSMenu!
    
    @IBOutlet weak var etc: NSMenuItem!
    @IBOutlet weak var etcMenu: NSMenu!
    
    @IBOutlet weak var xrp: NSMenuItem!
    @IBOutlet weak var xrpMenu: NSMenu!
    
    @IBOutlet weak var refreshMenu: NSMenu!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var btcTitle = "Loading..."
    var ethTitle = "Loading..."
    var etcTitle = "Loading..."
    var xrpTitle = "Loading..."
    
    var ticker: NSAttributedString!
    
    var printTimer = Timer()
    var timer = Timer()
    var time = Double(300)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.initMarketList(1)
        self.initMarketList(2)
        self.initMarketList(3)
        self.initMarketList(4)
        
        self.statusItem.menu = self.statusMenu
        
        self.updateTicker()
        self.printTicker()
        
        self.time = UserDefaults.standard.double(forKey: "time") == Double(0) ? Double(300) : UserDefaults.standard.double(forKey: "time")
        
        for item in self.refreshMenu.items {
            item.state = NSOffState
        }
        
        let refreshMenuSelected: NSMenuItem! = self.refreshMenu.item(withTag: Int(self.time))
        refreshMenuSelected.state = NSOnState
        
        self.updateData()
        self.timer = Timer.scheduledTimer(timeInterval: self.time, target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        self.startTicker()
    }
    
    func initMarketList(_ coin: Int) {
        let menu: NSMenuItem! = self.statusMenu.item(withTag: coin)
        let list: NSMenu! = menu.submenu
        
        let none: NSMenuItem = NSMenuItem(title: "NONE", action: #selector(self.setMarket), keyEquivalent: "")
        none.tag = coin * 100
        list.addItem(none)
        
        list.addItem(NSMenuItem.separator())
        
        if (coin != 4) {
            let korbit: NSMenuItem = NSMenuItem(title: "Korbit (KRW)", action: #selector(self.setMarket), keyEquivalent: "")
            korbit.tag = coin * 100 + 1
            list.addItem(korbit)
        }
        
        let bithumb: NSMenuItem = NSMenuItem(title: "Bithumb (KRW)", action: #selector(self.setMarket), keyEquivalent: "")
        bithumb.tag = coin * 100 + 2
        list.addItem(bithumb)
        
        let coinone: NSMenuItem = NSMenuItem(title: "Coinone (KRW)", action: #selector(self.setMarket), keyEquivalent: "")
        coinone.tag = coin * 100 + 3
        list.addItem(coinone)
        
        let market = self.getMarket(coin)
        let title = NSMutableAttributedString(string: "")
        switch (coin) {
            case 1:
                title.append(NSAttributedString(string: "\u{e9a7}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                break
            
            case 2:
                title.append(NSAttributedString(string: "\u{e9c4}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                break
                
            case 3:
                title.append(NSAttributedString(string: "\u{e9c2}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                break
                
            case 4:
                title.append(NSAttributedString(string: "\u{e93a}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                break
            
            default:
                break
        }
        
        title.append(NSAttributedString(string: " "+"\(menu.title)", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        
        menu.attributedTitle = title
        if (market == 0) {
            menu.state = NSOffState
            list.item(withTag: 0)?.state = NSOnState
        } else {
            menu.state = NSOnState
            list.item(withTag: coin * 100 + market)?.state = NSOnState
        }
    }
    
    func getMarket(_ coin: Int) -> Int {
        switch (coin) {
            case 1:
                return UserDefaults.standard.integer(forKey: "btc")
            
            case 2:
                return UserDefaults.standard.integer(forKey: "eth")
            
            case 3:
                return UserDefaults.standard.integer(forKey: "etc")
                
            case 4:
                return UserDefaults.standard.integer(forKey: "xrp")
            
            default:
                return 0
        }
    }
    
    func setMarket(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            let coin = sender.tag / 100
            let market = sender.tag % 100
            
            switch (coin) {
                case 1:
                    self.btcTitle = "Loading..."
                    UserDefaults.standard.set(market, forKey:"btc")
                    break
                    
                case 2:
                    self.ethTitle = "Loading..."
                    UserDefaults.standard.set(market, forKey:"eth")
                    break
                    
                case 3:
                    self.etcTitle = "Loading..."
                    UserDefaults.standard.set(market, forKey:"etc")
                    break
                    
                case 4:
                    self.xrpTitle = "Loading..."
                    UserDefaults.standard.set(market, forKey:"xrp")
                    break
                    
                default:
                    break
            }
            
            self.statusMenu.item(withTag: coin)!.state = market == 0 ? NSOffState : NSOnState
            
            for item in self.statusMenu.item(withTag: coin)!.submenu!.items {
                item.state = NSOffState
            }
            
            sender.state = NSOnState
            
            self.getData(coin)
            
            self.updateTicker()
            self.stopTicker()
            self.printTicker()
            self.startTicker()
        }
    }
    
    func updateTicker() {
        let tickString = NSMutableAttributedString(string: "")
        
        if (self.getMarket(1) > 0) {
            tickString.append(NSAttributedString(string: "\u{e9a7}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
            tickString.append(NSAttributedString(string: " "+"\(self.btcTitle)", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        }
        
        if (self.getMarket(2) > 0) {
            if (tickString.length > 0) {
                tickString.append(NSAttributedString(string: " ", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
            }
            tickString.append(NSAttributedString(string: "\u{e9c4}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
            tickString.append(NSAttributedString(string: " "+"\(self.ethTitle)", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        }
        
        if (self.getMarket(3) > 0) {
            if (tickString.length > 0) {
                tickString.append(NSAttributedString(string: " ", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
            }
            tickString.append(NSAttributedString(string: "\u{e9c2}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
            tickString.append(NSAttributedString(string: " "+"\(self.etcTitle)", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        }
        
        if (self.getMarket(4) > 0) {
            if (tickString.length > 0) {
                tickString.append(NSAttributedString(string: " ", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
            }
            tickString.append(NSAttributedString(string: "\u{e93a}", attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
            tickString.append(NSAttributedString(string: " "+"\(self.xrpTitle)", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        }
        
        self.ticker = tickString
    }
    
    func startTicker() {
        self.stopTicker()
        self.printTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(AppDelegate.printTicker), userInfo: nil, repeats: true)
    }
    
    func stopTicker() {
        self.printTimer.invalidate()
    }
    
    func printTicker() {
        if (self.getMarket(1) + self.getMarket(2) + self.getMarket(3) + self.getMarket(4) == 0) {
            self.statusItem.image = NSImage(named: "statusIcon")
            self.statusItem.attributedTitle = nil
        } else {
            self.statusItem.image = nil
            self.statusItem.attributedTitle = self.ticker
        }
    }
    
    func getData(_ coin: Int) {
        let market = self.getMarket(coin)
        
        if (market > 0) {
            var apiUrl: String = ""
            
            if (market == 1) {
                apiUrl = "https://api.korbit.co.kr/v1/ticker?currency_pair="
                
                switch (coin) {
                    case 1:
                        apiUrl = apiUrl + "btc_krw"
                        break
                    
                    case 2:
                        apiUrl = apiUrl + "eth_krw"
                        break
                    
                    case 3:
                        apiUrl = apiUrl + "etc_krw"
                        break
                    
                    default:
                        apiUrl = ""
                        break
                }
            }
            
            if (market == 2) {
                apiUrl = "https://api.bithumb.com/public/ticker/"
                
                switch (coin) {
                    case 1:
                        apiUrl = apiUrl + "btc"
                        break
                        
                    case 2:
                        apiUrl = apiUrl + "eth"
                        break
                        
                    case 3:
                        apiUrl = apiUrl + "etc"
                        break
                    
                    case 4:
                        apiUrl = apiUrl + "xrp"
                        break
                    
                    default:
                        apiUrl = ""
                        break
                }
            }
            
            if (market == 3) {
                apiUrl = "https://api.coinone.co.kr/ticker/?currency="
                
                switch (coin) {
                    case 1:
                        apiUrl = apiUrl + "btc"
                        break
                        
                    case 2:
                        apiUrl = apiUrl + "eth"
                        break
                        
                    case 3:
                        apiUrl = apiUrl + "etc"
                        break
                        
                    case 4:
                        apiUrl = apiUrl + "xrp"
                        break
                        
                    default:
                        apiUrl = ""
                        break
                    }
            }
            
            if (apiUrl != "") {
                let session = URLSession.shared
                let jsonUrl = URL(string: apiUrl)
                
                let task = session.dataTask(with: jsonUrl!, completionHandler: {
                    (data, response, error) -> Void in
                    
                    do {
                        let jsonData: AnyObject? = try JSONSerialization.jsonObject(with: data!, options:JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
                        
                        var currency = Double(0)
                        
                        if (market == 1) {
                            currency = Double(jsonData!["last"] as! String)!
                        } else if (market == 2) {
                            let json: AnyObject? = jsonData!["data"] as! NSDictionary
                            currency = Double(json!["closing_price"] as! String)!
                        } else if (market == 3) {
                            currency = Double(jsonData!["last"] as! String)!
                        }
                        
                        let numberFormatter = NumberFormatter()
                        numberFormatter.numberStyle = .decimal
                        
                        let title: String! = numberFormatter.string(from: NSNumber(value: currency))!
                        
                        switch (coin) {
                            case 1:
                                self.btcTitle = title
                                break
                            
                            case 2:
                                self.ethTitle = title
                                break
                                
                            case 3:
                                self.etcTitle = title
                                break
                                
                            case 4:
                                self.xrpTitle = title
                                break
                            
                            default:
                                break
                        }
                        
                        self.updateTicker()
                    } catch _ {
                        // Error
                    }
                })
                
                task.resume()
            }
        }
    }
    
    func updateData() {
        self.getData(1)
        self.getData(2)
        self.getData(3)
        self.getData(4)
        
        let todaysDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        let DateInFormat = dateFormatter.string(from: todaysDate)
        self.refresh.title = "Refresh : " + "\(DateInFormat)"
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
    
    @IBAction func refresh(_ sender: AnyObject) {
        self.updateData()
        
        self.btcTitle = "Loading..."
        self.ethTitle = "Loading..."
        self.etcTitle = "Loading..."
        self.xrpTitle = "Loading..."
        
        self.updateTicker()
        self.stopTicker()
        self.printTicker()
        self.startTicker()
    }
    
    @IBAction func refreshTime(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            for item in self.refreshMenu.items {
                item.state = NSOffState
            }
            
            sender.state = NSOnState
            self.time = Double(sender.tag)
            
            UserDefaults.standard.set(self.time, forKey:"time")
            
            self.timer.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: self.time, target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        }
    }
    
    @IBAction func openUrl(_ sender: AnyObject) {
        NSWorkspace.shared().open(URL(string: "https://github.com/moimz/iCoinTicker/issues")!)
    }
    
    @IBAction func quit(_ sender: AnyObject) {
        self.timer.invalidate()
        self.printTimer.invalidate()
        exit(0)
    }
}
