//
//  AppDelegate.swift
//  iCoinTicker
//
//  Created by Arzz on 2017. 6. 3..
//  Copyright © 2017 Moimz. All rights reserved.
//

import Cocoa
import Foundation
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var appname: NSTextField!
    
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var refresh: NSMenuItem!
    
    @IBOutlet weak var refreshTimeMenu: NSMenu!
    @IBOutlet weak var currencyMenu: NSMenu!
    @IBOutlet weak var fontSizeMenu: NSMenu!
    @IBOutlet weak var symbolMenu: NSMenu!
    
    @IBOutlet weak var coinMenu: NSMenu!
    @IBOutlet weak var marketMenu: NSMenu!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var costs: [[Double]] = []
    var btcCosts: [[Double]] = []
    
    let currencyName: [String] = ["", "KRW", "USD", "JPY", "CNY", "EUR"]
    let currencyMark: [String] = ["", "₩", "$", "¥", "¥", "€"]
    var currencyLatestTime: Double = 0
    
    let coinUnit: [String] = ["", "BTC", "ETH", "ETC", "XRP", "STRAT", "DGB", "SC" ,"XMR"]
    let coinName: [String] = ["", "Bitcoin", "Ethereum", "Ethereum Classic", "Ripple", "Stratis", "DigiByte", "Siacoin", "Monero"]
    let coinMark: [String] = ["", "\u{e9a7}", "\u{e9c4}", "\u{e9c2}", "\u{e93a}", "\u{e916}", "\u{e9b6}", "\u{e906}", "\u{e936}"]
    let marketName: [String] = ["", "Korbit", "Bithumb", "Coinone", "", "", "", "", "", "", "Poloniex", "Bittrex", "", "", "", "", "", "", "", "", "Coincheck", "Bitflyer", "", "", "", "", "", "", "", "", "Okcoin"]
    
    var tickerTimer = Timer()
    var timer = Timer()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for i in 0..<self.coinUnit.count {
            if (i > 0) {
                self.initMarketList(i)
            }
            
            self.costs.append([])
            self.btcCosts.append([])
            
            for _ in self.marketName {
                self.costs[i].append(Double(0))
                self.btcCosts[i].append(Double(0))
            }
        }
        
        self.initVisible()
        
        self.initOptions()
        
        self.statusItem.menu = self.statusMenu
        
        self.updateTicker()
        
        self.updateData()
        self.timer = Timer.scheduledTimer(timeInterval: Double(self.getOptionsRefreshTime()), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        self.startTicker()
        
//        self.checkUpdate()
    }
    
    func initMarketList(_ coin: Int) {
        let menu: NSMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.tag = coin
        
        let list: NSMenu = NSMenu()
        menu.submenu = list
        
        self.statusMenu.insertItem(menu, at: coin + 1)
        
        let none: NSMenuItem = NSMenuItem(title: "NONE", action: #selector(self.setMarket), keyEquivalent: "")
        none.tag = coin * 1000
        none.isEnabled = true
        list.addItem(none)
        
        list.addItem(NSMenuItem.separator())
        
        if (coin <= 3) {
            let korbit: NSMenuItem = NSMenuItem(title: self.getMarketName(1, true), action: #selector(self.setMarket), keyEquivalent: "")
            korbit.tag = coin * 1000 + 1
            korbit.image = self.getMarketFlag(1)
            list.addItem(korbit)
        }
        
        if (coin <= 4) {
            let bithumb: NSMenuItem = NSMenuItem(title: self.getMarketName(2, true), action: #selector(self.setMarket), keyEquivalent: "")
            bithumb.tag = coin * 1000 + 2
            bithumb.image = self.getMarketFlag(2)
            list.addItem(bithumb)
            
            let coinone: NSMenuItem = NSMenuItem(title: self.getMarketName(3, true), action: #selector(self.setMarket), keyEquivalent: "")
            coinone.tag = coin * 1000 + 3
            coinone.image = self.getMarketFlag(3)
            list.addItem(coinone)
            
            list.addItem(NSMenuItem.separator())
        }
        
        let poloniex: NSMenuItem = NSMenuItem(title: self.getMarketName(10, true), action: #selector(self.setMarket), keyEquivalent: "")
        poloniex.tag = coin * 1000 + 10
        poloniex.image = self.getMarketFlag(10)
        list.addItem(poloniex)
        
        if (coin > 1) {
            let poloniexBtc: NSMenuItem = NSMenuItem(title: self.getMarketName(110, true), action: #selector(self.setMarket), keyEquivalent: "")
            poloniexBtc.tag = coin * 1000 + 110
            poloniexBtc.image = self.getMarketFlag(10)
            list.addItem(poloniexBtc)
        }
        
        let bittrex: NSMenuItem = NSMenuItem(title: self.getMarketName(11, true), action: #selector(self.setMarket), keyEquivalent: "")
        bittrex.tag = coin * 1000 + 11
        bittrex.image = self.getMarketFlag(11)
        list.addItem(bittrex)
        
        if (coin > 1) {
            let bittrexBtc: NSMenuItem = NSMenuItem(title: self.getMarketName(111, true), action: #selector(self.setMarket), keyEquivalent: "")
            bittrexBtc.tag = coin * 1000 + 111
            bittrexBtc.image = self.getMarketFlag(11)
            list.addItem(bittrexBtc)
        }

        if (coin <= 4) {
            list.addItem(NSMenuItem.separator())
            
            let coincheck: NSMenuItem = NSMenuItem(title: self.getMarketName(20, true), action: #selector(self.setMarket), keyEquivalent: "")
            coincheck.tag = coin * 1000 + 20
            coincheck.image = self.getMarketFlag(20)
            list.addItem(coincheck)
        }
        
        if (coin <= 2) {
            let bitflyer: NSMenuItem = NSMenuItem(title: self.getMarketName(21, true), action: #selector(self.setMarket), keyEquivalent: "")
            bitflyer.tag = coin * 1000 + 21
            bitflyer.image = self.getMarketFlag(21)
            list.addItem(bitflyer)
        }
        
        if (coin <= 2) {
            list.addItem(NSMenuItem.separator())
            
            let okcoin: NSMenuItem = NSMenuItem(title: self.getMarketName(30, true), action: #selector(self.setMarket), keyEquivalent: "")
            okcoin.tag = coin * 1000 + 30
            okcoin.image = self.getMarketFlag(30)
            list.addItem(okcoin)
        }
        
        let title = NSMutableAttributedString(string: "")
        title.append(NSAttributedString(string: self.coinMark[coin], attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
        title.append(NSAttributedString(string: " " + self.coinUnit[coin] + " (" + self.coinName[coin] + ")", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
        menu.attributedTitle = title
        
        let market = self.getMarket(coin)
        if (market == 0) {
            menu.state = NSOffState
            list.item(withTag: coin * 1000)?.state = NSOnState
        } else {
            menu.state = NSOnState
            list.item(withTag: coin * 1000 + market)?.state = NSOnState
        }
    }
    
    func initVisible() {
        for coin in 1..<self.coinUnit.count {
            if (self.getOptionsCoin(coin) == true) {
                self.statusMenu.item(withTag: coin)!.isHidden = false
                self.statusMenu.item(withTag: coin)!.isEnabled = true
                
                var marketGroup: Int = -10;
                for i in 1..<self.statusMenu.item(withTag: coin)!.submenu!.items.count {
                    let menu: NSMenuItem = self.statusMenu.item(withTag: coin)!.submenu!.item(at: i)!
                    
                    if (menu.tag == 0) {
                        menu.isHidden = !self.getOptionsMarketGroup(marketGroup)
                    } else {
                        let market = menu.tag % 1000 % 100
                        marketGroup = Int(market / 10) * 10
                        
                        if (self.getOptionsMarket(market) == true) {
                            menu.action = #selector(self.setMarket)
                            menu.isHidden = false
                        } else {
                            menu.action = nil
                            menu.isHidden = true
                        }
                    }
                }
            } else {
                self.statusMenu.item(withTag: coin)!.isHidden = true
                self.statusMenu.item(withTag: coin)!.isEnabled = false
            }
        }
    }
    
    func initOptions() {
        for i in 1..<self.currencyName.count {
            let menu: NSMenuItem = NSMenuItem(title: self.currencyMark[i] + " " + self.currencyName[i], action: #selector(self.setOptionsCurrency), keyEquivalent: "")
            menu.tag = i
            menu.state = self.getOptionsCurrency() == i ? NSOnState : NSOffState
            self.currencyMenu.addItem(menu)
        }
        
        let fontSizes: [Int] = [10, 12, 14]
        for size in fontSizes {
            let menu: NSMenuItem = NSMenuItem(title: String(size) + "px", action: #selector(self.setOptionsFontSize), keyEquivalent: "")
            menu.tag = size
            menu.state = self.getOptionsFontSize() == size ? NSOnState : NSOffState
            self.fontSizeMenu.addItem(menu)
        }
        
        let times: [[Any]] = [[15, "15 sec"], [30, "30 sec"], [60, "1 min"], [300, "5 min"], [600, "10 min"], [900, "15 min"], [1800, "30 min"], [3600, "1 hour"]]
        for time in times {
            let menu: NSMenuItem = NSMenuItem(title: time[1] as! String, action: #selector(self.setOptionsRefreshTime), keyEquivalent: "")
            menu.tag = time[0] as! Int
            menu.state = self.getOptionsRefreshTime() == time[0] as! Int ? NSOnState : NSOffState
            self.refreshTimeMenu.addItem(menu)
        }
        
        let symbols: [String] = ["NONE", "Menu", "Ticker", "Menu and Ticker"]
        for i in 0..<symbols.count {
            let menu: NSMenuItem = NSMenuItem(title: symbols[i], action: #selector(self.setOptionsSymbol), keyEquivalent: "")
            menu.tag = i - 1
            menu.state = self.getOptionsSymbol() == i - 1 ? NSOnState : NSOffState
            self.symbolMenu.addItem(menu)
            
            if (i == 0) {
                self.symbolMenu.addItem(NSMenuItem.separator())
            }
        }
        
        for i in 1..<self.coinUnit.count {
            let menu: NSMenuItem = NSMenuItem(title: "", action: #selector(self.setOptionsCoin), keyEquivalent: "")
            menu.tag = i
            menu.state = self.getOptionsCoin(i) == true ? NSOnState : NSOffState
            
            let title = NSMutableAttributedString(string: "")
            title.append(NSAttributedString(string: self.coinMark[i], attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
            title.append(NSAttributedString(string: " " + self.coinUnit[i], attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
            menu.attributedTitle = title
            
            self.coinMenu.addItem(menu)
        }
        
        for i in 1..<self.marketName.count {
            if (self.marketName[i] == "") {
                continue
            }
            
            if (i % 10 == 0) {
                self.marketMenu.addItem(NSMenuItem.separator())
            }
            
            let menu: NSMenuItem = NSMenuItem(title: self.marketName[i], action: #selector(self.setOptionsMarket), keyEquivalent: "")
            menu.tag = i
            menu.state = self.getOptionsMarket(i) == true ? NSOnState : NSOffState
            menu.image = self.getMarketFlag(i)
            self.marketMenu.addItem(menu)
        }
    }
    
    func getMarket(_ coin: Int) -> Int {
        return UserDefaults.standard.integer(forKey: self.coinUnit[coin].lowercased())
    }
    
    func setMarket(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            let coin = sender.tag / 1000
            let market = sender.tag % 1000
            
            UserDefaults.standard.set(market, forKey: self.coinUnit[coin].lowercased())
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
    
    func getMarketName(_ market: Int, _ padding: Bool = false) -> String {
        var name: String = ""
        if (market < 100) {
            name = self.marketName[market]
        } else {
            name = self.marketName[market % 100] + "(฿)"
        }
        
        if (padding == true) {
            return name + "".padding(toLength: Int((20 - name.characters.count) / 4), withPad: "\t", startingAt: 0)
        } else {
            return name
        }
    }
    
    func getMarketFlag(_ market: Int) -> NSImage {
        var flag: Int = 0
        if (market < 100) {
            flag = Int(market/10)
        } else {
            flag = Int((market % 100)/10)
        }
        
        let flags: [String] = ["kr", "us", "jp", "cn"]
        
        return NSImage(named: flags[flag])!
    }
    
    func getMarketCurrency(_ market: Int) -> Int {
        if (market < 10) {
            return 1
        } else if (market < 20) {
            return 2
        } else if (market < 30) {
            return 3
        } else if (market < 40) {
            return 4
        } else {
            return self.getOptionsCurrency()
        }
    }
    
    func getCost(_ coin: Int, _ market: Int, _ useTicker: Bool) -> String {
        var cost: Double = 0
        if (market < 100) {
            cost = self.costs[coin][market] * self.getCurrency(self.getMarketCurrency(market), self.getOptionsCurrency())
        } else {
            cost = self.btcCosts[coin][market % 100] * self.getCurrency(self.getMarketCurrency(market), self.getOptionsCurrency())
        }
        
        if (cost == 0) {
            if (useTicker == true) {
                return "Loading..."
            } else {
                return self.getOptionsMarket(market) == true ? "Loading..." : ""
            }
        } else {
            var text: String = ""
            
            if (market < 100) {
                var places: Double
                
                switch (self.getOptionsCurrency()) {
                    case 2 :
                        places = Double(2)
                        break
                    
                    case 4 :
                        places = Double(1)
                        break
                    
                    case 5 :
                        places = Double(2)
                        break
                    
                    default :
                        places = Double(0)
                }
                
                let divisor = pow(10.0, places)
                cost = round(cost * divisor) / divisor
                
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                
                if (self.getOptionsSymbol() == 2 || (useTicker == true && self.getOptionsSymbol() == 1) || (useTicker == false && self.getOptionsSymbol() == 0)) {
                    text = self.currencyMark[self.getOptionsCurrency()] + " " + numberFormatter.string(from: NSNumber(value: cost))!
                } else {
                    text = numberFormatter.string(from: NSNumber(value: cost))!
                }
                
                return text
            } else {
                if (self.getOptionsSymbol() == 2 || (useTicker == true && self.getOptionsSymbol() == 1) || (useTicker == false && self.getOptionsSymbol() == 0)) {
                    return "฿ " + String(format:"%0.8f", cost)
                } else {
                    return String(format:"%0.8f", cost)
                }
            }
        }
    }
    
    func updateTicker() {
        let tickerString = NSMutableAttributedString(string: "")
        
        var markAttributes: [String: Any] = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]
        var costAttributes: [String: Any] = [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]
        
        if (self.getOptionsFontSize() == 10) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 10.0), NSBaselineOffsetAttributeName: 2.5]
        } else if (self.getOptionsFontSize() == 12) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 12.0), NSBaselineOffsetAttributeName: 2.0]
        }
        
        for coin in 1..<self.coinUnit.count {
            if (self.getOptionsCoin(coin) == true && self.getMarket(coin) > 0) {
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
        
        for coin in 1..<self.coinUnit.count {
            if (self.getOptionsCoin(coin) == true) {
                /*
                if (self.getMarket(coin) > 0) {
                    let menu: NSMenuItem = self.statusMenu.item(withTag: coin)!
                    let title = NSMutableAttributedString(string: "")
                    title.append(NSAttributedString(string: self.coinMark[coin], attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                    title.append(NSAttributedString(string: " " + self.coinName[coin] + " " + "".padding(toLength: Int((16 - self.coinName[coin].characters.count) / 4), withPad: "\t", startingAt: 0), attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
                    title.append(NSAttributedString(string: self.getCost(coin, self.getMarket(coin), false), attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
                    menu.attributedTitle = title
                }
                */
                for menu in self.statusMenu.item(withTag: coin)!.submenu!.items {
                    if (menu.tag % 1000 > 0 && self.getOptionsMarket(menu.tag % 1000) == true) {
                        let title = NSMutableAttributedString(string: "")
                        title.append(NSAttributedString(string: self.getMarketName(menu.tag % 1000, true), attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0)]))
                        title.append(NSAttributedString(string: self.getCost(coin, menu.tag % 1000, false), attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0)]))
                        menu.attributedTitle = title
                    }
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
            apiUrl = "https://api.korbit.co.kr/v1/ticker?currency_pair=" + self.coinUnit[coin].lowercased() + "_krw"
        }
        
        if (market == 2) {
            apiUrl = "https://api.bithumb.com/public/ticker/" + self.coinUnit[coin].lowercased()
        }
        
        if (market == 3) {
            apiUrl = "https://api.coinone.co.kr/ticker/?currency=" + self.coinUnit[coin].lowercased()
        }
        
        if (market == 10) {
            apiUrl = "https://poloniex.com/public?command=returnTicker"
        }
        
        if (market == 11) {
            apiUrl = "https://bittrex.com/api/v1.1/public/getticker?market="
            
            if (coin == 1) {
                apiUrl = apiUrl + "USDT-" + self.coinUnit[coin]
            } else {
                apiUrl = apiUrl + "BTC-" + self.coinUnit[coin]
            }
        }
        
        if (market == 20) {
            apiUrl = "https://coincheck.com/api/rate/" + self.coinUnit[coin].lowercased() + "_jpy"
        }
        
        if (market == 21) {
            apiUrl = "https://api.bitflyer.jp/v1/ticker/?product_code="
            
            if (coin == 1) {
                apiUrl = apiUrl + self.coinUnit[coin] + "_JPY"
            } else {
                apiUrl = apiUrl + self.coinUnit[coin] + "_BTC"
            }
        }
        
        if (market == 30) {
            apiUrl = "https://www.okcoin.cn/api/v1/ticker.do?symbol=" + self.coinUnit[coin].lowercased() + "_cny"
        }
        
        if (apiUrl != "") {
            let session = URLSession.shared
            let jsonUrl = URL(string: apiUrl)
            
            let task = session.dataTask(with: jsonUrl!, completionHandler: {
                (data, response, error) -> Void in
                
                do {
                    if (data != nil) {
                        let jsonData = try JSONSerialization.jsonObject(with: data!) as! [String: Any]
                        var cost = Double(0)
                        
                        if (market == 10) {
                            cost = self.getDouble((jsonData["USDT_BTC"] as! [String: Any])["last"] as Any)
                            self.costs[1][10] = cost
                            
                            cost = self.getDouble((jsonData["USDT_ETH"] as! [String: Any])["last"] as Any)
                            self.costs[2][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_ETH"] as! [String: Any])["last"] as Any)
                            self.btcCosts[2][10] = cost
                            
                            cost = self.getDouble((jsonData["USDT_ETC"] as! [String: Any])["last"] as Any)
                            self.costs[3][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_ETC"] as! [String: Any])["last"] as Any)
                            self.btcCosts[3][10] = cost
                            
                            cost = self.getDouble((jsonData["USDT_XRP"] as! [String: Any])["last"] as Any)
                            self.costs[4][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_XRP"] as! [String: Any])["last"] as Any)
                            self.btcCosts[4][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_STRAT"] as! [String: Any])["last"] as Any)
                            self.costs[5][10] = cost * self.costs[1][10]
                            self.btcCosts[5][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_DGB"] as! [String: Any])["last"] as Any)
                            self.costs[6][10] = cost * self.costs[1][10]
                            self.btcCosts[6][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_SC"] as! [String: Any])["last"] as Any)
                            self.costs[7][10] = cost * self.costs[1][10]
                            self.btcCosts[7][10] = cost
                            
                            cost = self.getDouble((jsonData["BTC_XMR"] as! [String: Any])["last"] as Any)
                            self.costs[8][10] = cost * self.costs[1][10]
                            self.btcCosts[8][10] = cost
                        } else {
                            if (market == 1) {
                                cost = self.getDouble(jsonData["last"] as Any)
                            }
                            
                            if (market == 2) {
                                cost = self.getDouble((jsonData["data"] as! [String: Any])["closing_price"] as Any)
                            }
                            
                            if (market == 3) {
                                cost = self.getDouble(jsonData["last"] as Any)
                            }
                            
                            if (market == 11) {
                                cost = self.getDouble((jsonData["result"] as! [String: Any])["Last"] as Any)
                                if (coin > 1) {
                                    self.btcCosts[coin][market] = cost
                                    cost = cost * self.costs[1][11]
                                }
                            }
                            
                            if (market == 20) {
                                cost = self.getDouble(jsonData["rate"] as Any)
                            }
                            
                            if (market == 21) {
                                cost = self.getDouble(jsonData["ltp"] as Any)
                                if (coin > 1) {
                                    cost = cost * self.costs[1][21]
                                }
                            }
                            
                            if (market == 30) {
                                cost = self.getDouble((jsonData["ticker"] as! [String: Any])["last"] as Any)
                            }
                            
                            if (cost == 0) {
                                return
                            }
                            
                            self.costs[coin][market] = cost
                        }
                    }
                } catch _ {
                    print("ERROR :",self.coinUnit[coin], self.getMarketName(market))
                }
            })
            
            task.resume()
        }
    }
    
    func getDouble(_ number: Any) -> Double {
        if (number is NSNumber) {
            return number as! Double
        } else if (number is NSString) {
            return Double(number as! String)!
        } else {
            return Double(0)
        }
    }
    
    func updateData() {
        for coin in 1..<self.coinUnit.count {
            if (self.getOptionsCoin(coin) == true) {
                for market in self.statusMenu.item(withTag: coin)!.submenu!.items {
                    if (market.tag % 1000 > 0 && self.getOptionsMarket(market.tag % 1000) == true) {
                        if (market.tag % 1000 != 10) {
                            self.getData(coin, market.tag % 1000)
                        }
                    }
                }
            } else {
                if (coin == 1) {
                    if (self.getOptionsMarket(11) == true) {
                        self.getData(1, 11)
                    }
                }
            }
        }
        
        if (self.getOptionsMarket(10) == true) {
            self.getData(0, 10)
        }
        
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
    
    func getOptionsCurrency() -> Int {
        let currency: Int = UserDefaults.standard.integer(forKey: "currency")
        return currency == 0 ? 1 : currency
    }
    
    func setOptionsCurrency(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            UserDefaults.standard.set(sender.tag, forKey: "currency")
            for menu in self.currencyMenu.items {
                menu.state = NSOffState
            }
            
            sender.state = NSOnState
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
    }
    
    func getOptionsFontSize() -> Int {
        let fontSize: Int = UserDefaults.standard.integer(forKey: "fontSize")
        return fontSize == 0 ? 14 : fontSize
    }
    
    func setOptionsFontSize(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            UserDefaults.standard.set(sender.tag, forKey: "fontSize")
            for menu in self.fontSizeMenu.items {
                menu.state = NSOffState
            }
            
            sender.state = NSOnState
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
    }
    
    func getOptionsSymbol() -> Int {
        return UserDefaults.standard.integer(forKey: "symbol")
    }
    
    func setOptionsSymbol(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            UserDefaults.standard.set(sender.tag, forKey: "symbol")
            for menu in self.symbolMenu.items {
                menu.state = NSOffState
            }
            
            sender.state = NSOnState
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
    }
    
    func getOptionsRefreshTime() -> Int {
        let refreshTime: Int = UserDefaults.standard.integer(forKey: "refreshTime")
        return refreshTime == 0 ? 300 : refreshTime
    }
    
    func setOptionsRefreshTime(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            for item in self.refreshTimeMenu.items {
                item.state = NSOffState
            }
            
            sender.state = NSOnState
            UserDefaults.standard.set(sender.tag, forKey:"refreshTime")
            
            self.timer.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: Double(sender.tag), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        }
    }
    
    func getOptionsCoin(_ coin: Int) -> Bool {
        return UserDefaults.standard.integer(forKey: "coin" + String(coin)) != -1
    }
    
    func setOptionsCoin(_ sender: NSMenuItem) {
        if (sender.state == NSOnState) {
            sender.state = NSOffState
            UserDefaults.standard.set(-1, forKey:"coin" + String(sender.tag))
        } else {
            sender.state = NSOnState
            UserDefaults.standard.set(1, forKey:"coin" + String(sender.tag))
        }
        
        self.initVisible()
        
        if (self.getOptionsCoin(sender.tag) == false && self.getMarket(sender.tag) > 0) {
            self.setMarket(self.statusMenu.item(withTag: sender.tag)!.submenu!.item(withTag: sender.tag * 1000)!)
        }
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    func getOptionsMarketGroup(_ group: Int) -> Bool {
        for market in group..<group+10 {
            if (self.getOptionsMarket(market) == true) {
                return true
            }
        }
        return false
    }
    
    func getOptionsMarket(_ market: Int) -> Bool {
        if (market < 100) {
            return UserDefaults.standard.integer(forKey: "market" + String(market)) != -1
        } else {
            return UserDefaults.standard.integer(forKey: "market" + String(market % 100)) != -1
        }
    }
    
    func setOptionsMarket(_ sender: NSMenuItem) {
        if (sender.state == NSOnState) {
            sender.state = NSOffState
            UserDefaults.standard.set(-1, forKey:"market" + String(sender.tag))
        } else {
            sender.state = NSOnState
            UserDefaults.standard.set(1, forKey:"market" + String(sender.tag))
        }
        
        for coin in 1..<self.coinUnit.count {
            //self.statusMenu.item(withTag: coin)!.submenu?.item(withTag: coin * 1000 + sender.tag)?.action = self.getOptionsMarket(sender.tag) == true ? #selector(AppDelegate.setMarket) : nil
            if (self.getMarket(coin) == sender.tag) {
                self.setMarket(self.statusMenu.item(withTag: coin)!.submenu!.item(withTag: coin * 1000)!)
            }
        }
        
        self.initVisible()
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    /*
    func checkUpdate() {
        let session = URLSession.shared
        let jsonUrl = URL(string: "https://api.github.com/repos/moimz/iCoinTicker/releases/latest")
        
        let task = session.dataTask(with: jsonUrl!, completionHandler: {
            (data, response, error) -> Void in
            
            do {
                let jsonData = try JSONSerialization.jsonObject(with: data!) as! [String: Any]
                let latest = jsonData["tag_name"] as! String
                let message = jsonData["body"] as! String
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
                
                if (latest != "v" + version) {
                    self.showUpdateAlert(latest, message)
                }
            } catch _ {
                // Error
            }
        })
        
        task.resume()
    }
    
    func showUpdateAlert(_ latest: String, _ message: String) {
        DispatchQueue.main.async {
            let alert: NSAlert = NSAlert()
            alert.alertStyle = NSAlertStyle.warning
            alert.informativeText = message + "\n\n"
            alert.messageText = "A new version(" + latest + ") is available.\nWould you like to open website?"
            alert.addButton(withTitle: "Yes")
            alert.addButton(withTitle: "No")
            
            let selected = alert.runModal()
            if (selected == NSAlertFirstButtonReturn) {
                NSWorkspace.shared().open(URL(string: "https://github.com/moimz/iCoinTicker/releases/tag/" + latest)!)
            }
        }
    }
    */
    @IBAction func info(_ sender: AnyObject) {
        self.window!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
 
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        self.appname.stringValue = "iCoinTicker v" + version
    }
    
    @IBAction func refresh(_ sender: AnyObject) {
        for i in 0..<self.coinUnit.count {
            for j in 0..<self.marketName.count {
                self.costs[i][j] = Double(0)
            }
        }
        
        self.updateData()
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
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
