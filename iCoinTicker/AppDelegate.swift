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
    
    @IBOutlet weak var refreshMenu: NSMenu!
    
    @IBOutlet weak var currencyMenu: NSMenu!
    @IBOutlet weak var fontSizeMenu: NSMenu!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var costs: [[Double]] = []//[Double]](count) (count: 5, repeatedValue: [Double](count: 11, repeatedValue: Double(0)))
    
    var btcCurrency: Double = 0
    var ethCurrency: Double = 0
    var etcCurrency: Double = 0
    var xrpCurrency: Double = 0
    
    var currency: Int = 0
    let currencyName: [String] = ["", "KRW", "USD"]
    let currencyMark: [String] = ["", "₩", "$"]
    var currencyLatestTime: Double = 0
    
    let coinName: [String] = ["", "BTC", "ETH", "ETC", "XRP", "STRAT", "DGB"]
    let coinMark: [String] = ["", "\u{e9a7}", "\u{e9c4}", "\u{e9c2}", "\u{e93a}", "\u{e916}", "\u{e9b6}"]
    let marketName: [String] = ["", "Korbit", "Bithumb", "Coinone","","","","","","","Poloniex"]
    
    var fontSize: Int = 0
    
    var tickerTimer = Timer()
    var timer = Timer()
    var time = Double(300)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for i in 0..<self.coinName.count {
            if (i > 0) {
                self.initMarketList(i)
            }
            
            self.costs.append([])
            for _ in self.marketName {
                self.costs[i].append(Double(0))
            }
        }
        
        self.initOptions()
        
        self.currency = UserDefaults.standard.integer(forKey: "currency") == 0 ? 1 : UserDefaults.standard.integer(forKey: "currency")
        self.currencyMenu.item(withTag: self.currency)?.state = NSOnState
        
        self.fontSize = UserDefaults.standard.integer(forKey: "fontSize") == 0 ? 14 : UserDefaults.standard.integer(forKey: "fontSize")
        self.fontSizeMenu.item(withTag: self.fontSize)?.state = NSOnState
        
        self.statusItem.menu = self.statusMenu
        
        self.updateTicker()
        
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
        let menu: NSMenuItem = NSMenuItem(title: "TEST", action: #selector(self.setMarket), keyEquivalent: "")
        menu.tag = coin
        
        let list: NSMenu = NSMenu()
        menu.submenu = list
        
        self.statusMenu.insertItem(menu, at: coin + 1)
        
        let none: NSMenuItem = NSMenuItem(title: "NONE", action: #selector(self.setMarket), keyEquivalent: "")
        none.tag = coin * 100
        list.addItem(none)
        
        list.addItem(NSMenuItem.separator())
        
        if (coin <= 3) {
            let korbit: NSMenuItem = NSMenuItem(title: self.marketName[1], action: #selector(self.setMarket), keyEquivalent: "")
            korbit.tag = coin * 100 + 1
            list.addItem(korbit)
        }
        
        if (coin <= 4) {
            let bithumb: NSMenuItem = NSMenuItem(title: self.marketName[2], action: #selector(self.setMarket), keyEquivalent: "")
            bithumb.tag = coin * 100 + 2
            list.addItem(bithumb)
            
            let coinone: NSMenuItem = NSMenuItem(title: self.marketName[3], action: #selector(self.setMarket), keyEquivalent: "")
            coinone.tag = coin * 100 + 3
            list.addItem(coinone)
            
            list.addItem(NSMenuItem.separator())
        }
        
        let poloniex: NSMenuItem = NSMenuItem(title: self.marketName[10], action: #selector(self.setMarket), keyEquivalent: "")
        poloniex.tag = coin * 100 + 10
        list.addItem(poloniex)
        
        let market = self.getMarket(coin)
        let title = NSMutableAttributedString(string: "")
        title.append(NSAttributedString(string: self.coinMark[coin], attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
        title.append(NSAttributedString(string: " "+"\(self.coinName[coin])", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        menu.attributedTitle = title
        
        if (market == 0) {
            menu.state = NSOffState
            list.item(withTag: coin * 100)?.state = NSOnState
        } else {
            menu.state = NSOnState
            list.item(withTag: coin * 100 + market)?.state = NSOnState
        }
    }
    
    func initOptions() {
        for i in 1..<self.currencyName.count {
            let menu: NSMenuItem = NSMenuItem(title: self.currencyMark[i] + " " + self.currencyName[i], action: #selector(self.setOptionsCurrency), keyEquivalent: "")
            menu.tag = i
            self.currencyMenu.addItem(menu)
        }
        
        let fontSize: [Int] = [10, 12, 14]
        for size in fontSize {
            let menu: NSMenuItem = NSMenuItem(title: String(size) + "px", action: #selector(self.setOptionsFontSize), keyEquivalent: "")
            menu.tag = size
            self.fontSizeMenu.addItem(menu)
        }
    }
    
    func getMarket(_ coin: Int) -> Int {
        return UserDefaults.standard.integer(forKey: self.coinName[coin].lowercased())
    }
    
    func setMarket(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            let coin = sender.tag / 100
            let market = sender.tag % 100
            
            UserDefaults.standard.set(market, forKey: self.coinName[coin].lowercased())
            self.statusMenu.item(withTag: coin)!.state = market == 0 ? NSOffState : NSOnState
            
            for item in self.statusMenu.item(withTag: coin)!.submenu!.items {
                item.state = NSOffState
            }
            
            sender.state = NSOnState
            
            self.getData(coin, market)
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
    }
    
    func getMarketCurrency(_ market: Int) -> Int {
        if (market < 10) {
            return 1
        } else if (market < 20) {
            return 2
        }
        
        return 0
    }
    
    func getCost(_ coin: Int, _ market: Int, _ useTicker: Bool) -> String {
        var cost: Double = self.costs[coin][market] * self.getCurrency(self.getMarketCurrency(market), self.currency)
        
        if (cost == 0) {
            if (useTicker == true) {
                return "Loading..."
            } else {
                return ""
            }
        } else {
            var places: Double = Double(0)
            if (self.currency == 2) {
                places = Double(2)
            }
            
            let divisor = pow(10.0, places)
            cost = round(cost * divisor) / divisor
            
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            
            if (useTicker == true) {
                return numberFormatter.string(from: NSNumber(value: cost))!
            } else {
                return " (" + self.currencyMark[self.currency] + numberFormatter.string(from: NSNumber(value: cost))! + ")"
            }
        }
    }
    
    func updateTicker() {
        let tickerString = NSMutableAttributedString(string: "")
        
        var markAttributes: [String: Any] = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]
        var costAttributes: [String: Any] = [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]
        
        if (self.fontSize == 10) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 10.0), NSBaselineOffsetAttributeName: 2.5]
        } else if (self.fontSize == 12) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 12.0), NSBaselineOffsetAttributeName: 2.0]
        }
        
        for coin in 1..<self.coinName.count {
            if (self.getMarket(coin) > 0) {
                if (tickerString.length > 0) {
                    tickerString.append(NSAttributedString(string: " ", attributes: costAttributes))
                }
                
                tickerString.append(NSAttributedString(string: self.coinMark[coin], attributes: markAttributes))
                tickerString.append(NSAttributedString(string: " "+"\(self.getCost(coin, self.getMarket(coin), true))", attributes: costAttributes))
            }
        }
        
        if (tickerString.length == 0) {
            self.statusItem.image = NSImage(named: "statusIcon")
            self.statusItem.attributedTitle = nil
        } else {
            self.statusItem.image = nil
            self.statusItem.attributedTitle = tickerString
        }
        
        for i in 1..<self.coinName.count {
            for menu in self.statusMenu.item(withTag: i)!.submenu!.items {
                if (menu.tag % 100 > 0) {
                    menu.title = self.marketName[menu.tag % 100] + self.getCost(i, menu.tag % 100, false)
                }
            }
        }
    }
    
    func startTicker() {
        self.stopTicker()
        self.tickerTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(AppDelegate.updateTicker), userInfo: nil, repeats: true)
    }
    
    func stopTicker() {
        self.tickerTimer.invalidate()
    }
    
    func getCurrency(_ from: Int, _ to: Int) -> Double {
        if (from == to) {
            return 1
        } else {
            return UserDefaults.standard.double(forKey: self.currencyName[from] + self.currencyName[to])
        }
    }
    
    func updateCurrency(_ from: Int, _ to: Int) {
        if (from == to) {
            return
        }
        
        let session = URLSession.shared
        let jsonUrl = URL(string: "https://api.manana.kr/exchange/rate/" + self.currencyName[to] + "/" + self.currencyName[from] + ".json")
        
        let task = session.dataTask(with: jsonUrl!, completionHandler: {
            (data, response, error) -> Void in
            
            do {
                let jsonData = try JSONSerialization.jsonObject(with: data!) as! [[String: Any]]
                
                if (jsonData.count == 1) {
                    let currency: Double = jsonData[0]["rate"] as! Double
                    UserDefaults.standard.set(currency, forKey: self.currencyName[from] + self.currencyName[to])
                }
            } catch _ {
                // Error
            }
        })
        
        task.resume()
    }
    
    func getData(_ coin: Int, _ market:Int) {
        var apiUrl: String = ""
        
        if (market == 1) {
            apiUrl = "https://api.korbit.co.kr/v1/ticker?currency_pair=" + self.coinName[coin].lowercased() + "_krw"
        }
        
        if (market == 2) {
            apiUrl = "https://api.bithumb.com/public/ticker/" + self.coinName[coin].lowercased()
        }
        
        if (market == 3) {
            apiUrl = "https://api.coinone.co.kr/ticker/?currency=" + self.coinName[coin].lowercased()
        }
        
        if (market == 10) {
            apiUrl = "https://poloniex.com/public?command=returnTicker"
        }
        
        if (apiUrl != "") {
            let session = URLSession.shared
            let jsonUrl = URL(string: apiUrl)
            
            let task = session.dataTask(with: jsonUrl!, completionHandler: {
                (data, response, error) -> Void in
                
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data!) as! [String: Any]
                    var cost = Double(0)
                    
                    if (market == 10) {
                        cost = Double((jsonData["USDT_BTC"] as! [String: Any])["last"] as! String)!
                        self.costs[1][10] = cost
                        
                        cost = Double((jsonData["USDT_ETH"] as! [String: Any])["last"] as! String)!
                        self.costs[2][10] = cost
                        
                        cost = Double((jsonData["USDT_ETC"] as! [String: Any])["last"] as! String)!
                        self.costs[3][10] = cost
                        
                        cost = Double((jsonData["USDT_XRP"] as! [String: Any])["last"] as! String)!
                        self.costs[4][10] = cost
                        
                        cost = Double((jsonData["BTC_STRAT"] as! [String: Any])["last"] as! String)! * self.costs[1][10]
                        self.costs[5][10] = cost
                        
                        cost = Double((jsonData["BTC_DGB"] as! [String: Any])["last"] as! String)! * self.costs[1][10]
                        self.costs[6][10] = cost
                    } else {
                        if (market == 1) {
                            cost = Double(jsonData["last"] as! String)!
                        } else if (market == 2) {
                            cost = Double((jsonData["data"] as! [String: Any])["closing_price"] as! String)!
                        } else if (market == 3) {
                            cost = Double(jsonData["last"] as! String)!
                        }
                        
                        if (cost == 0) {
                            return
                        }
                        
                        self.costs[coin][market] = cost
                    }
                } catch _ {
                    // Error
                }
            })
            
            task.resume()
        }
    }
    
    func updateData() {
        for i in 1...4 {
            for market in self.statusMenu.item(withTag: i)!.submenu!.items {
                if (market.tag % 100 > 0) {
                    if (market.tag % 100 != 10) {
                        self.getData(i, market.tag % 100)
                    }
                }
            }
        }
        self.getData(0, 10)
        
        let todaysDate = Date()
        
        if (self.currencyLatestTime < todaysDate.timeIntervalSince1970 - 60 * 60) {
            for i in 1..<self.currencyName.count {
                for j in 1..<self.currencyName.count {
                    self.updateCurrency(i, j)
                }
            }
            
            self.currencyLatestTime = todaysDate.timeIntervalSince1970
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        let DateInFormat = dateFormatter.string(from: todaysDate)
        self.refresh.title = "Refresh : " + "\(DateInFormat)"
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func setOptionsCurrency(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "currency")
        for menu in self.currencyMenu.items {
            menu.state = NSOffState
        }
        
        self.currency = sender.tag
        sender.state = NSOnState
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    func setOptionsFontSize(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "fontSize")
        for menu in self.fontSizeMenu.items {
            menu.state = NSOffState
        }
        
        self.fontSize = sender.tag
        sender.state = NSOnState
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    @IBAction func info(_ sender: AnyObject) {
        self.window!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        self.appname.stringValue = "iCoinTicker v" + version
    }
    
    @IBAction func refresh(_ sender: AnyObject) {
        for i in 0..<self.coinName.count {
            for j in 0..<self.marketName.count {
                self.costs[i][j] = Double(0)
            }
        }
        
        self.updateData()
        
        self.stopTicker()
        self.updateTicker()
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
        self.tickerTimer.invalidate()
        exit(0)
    }
}
