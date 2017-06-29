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
    
    @IBOutlet weak var aboutWindow: NSWindow!
    
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var preferencesToolbar: NSToolbar!
    @IBOutlet weak var preferencesGeneral: NSView!
    @IBOutlet weak var preferencesCoin: NSView!
    @IBOutlet weak var preferencesDonation: NSView!
    
    struct Coin {
        let unit: String
        let name: String
        let tag: Int
        let mark: String
        let marketParams: [String: String]
        let markets: [Market]
        
        init(_ key: String, _ value: NSMutableDictionary, _ markets: [Market]) {
            self.unit = key
            self.name = value["name"] as! String
            self.tag = value["tag"] as! Int
            self.mark = String(Character(UnicodeScalar(Int(value["mark"] as! String, radix: 16)!)!))
            
            let marketParams: [String: String] = value["marketParams"] as! [String: String]
            self.marketParams = marketParams
            
            var hasMarkets: [Market] = []
            for market in markets {
                if (marketParams[market.name] != nil) {
                    hasMarkets.append(market)
                }
            }
            
            self.markets = hasMarkets
        }
    }
    
    struct Api {
        let url: String
        let first: [String]
        let last: [String]
        let change: [String]
        let isCompare: Bool
        
        init(_ data: NSMutableDictionary) {
            self.url = data["url"] as! String
            
            let first: String? = data["first"] as? String
            self.first = first == nil ? [] : first!.characters.split(separator: ".").map{ String($0) }
            
            let last: String! = data["last"] as! String
            self.last = last == nil ? [] : last!.characters.split(separator: ".").map{ String($0) }
            
            let change: String? = data["change"] as? String
            self.change = change == nil ? [] : change!.characters.split(separator: ".").map{ String($0) }
            
            self.isCompare = first != nil || change != nil
        }
    }
    
    struct Market {
        let name: String
        let tag: Int
        let currency: String
        let isCombination: Bool
        let isBtcMarket: Bool
        let api: Api
        
        init(_ key: String,_ value: NSMutableDictionary) {
            self.name = key
            self.tag = value["tag"] as! Int
            self.currency = value["currency"] as! String
            self.isCombination = value["isCombination"] as! Bool
            self.isBtcMarket = value["isBtcMarket"] as! Bool
            self.api = Api(value["api"] as! NSMutableDictionary)
        }
        
        func paddingName() -> String {
            return self.name + "".padding(toLength: Int((20 - self.name.characters.count) / 4), withPad: "\t", startingAt: 0)
        }
    }
    
    let statusMenu: NSMenu = NSMenu()
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var costs: [String: [String: Double]] = [:]
    var costChanges: [String: [String: Double?]] = [:]
    
    let currencyName: [String] = ["", "KRW", "USD", "JPY", "CNY", "EUR"]
    let currencyMark: [String] = ["", "₩", "$", "¥", "¥", "€"]
    var currencyLatestTime: Double = 0
    
    var plist: NSMutableDictionary = [:]
    var markets: [Market] = []
    var coins: [Coin] = []
    
    var tickerTimer = Timer()
    var updaterTimer: [String: Timer] = [:]
    
    var timer: Timer = Timer()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.killLauncher()
        
        self.initPlist()
        self.initCosts()
        self.initAboutWindow()
        self.initPreferencesWindow()
        self.initMenus()
        
        self.statusItem.menu = self.statusMenu
        
        self.updateTicker()
        self.startTicker()
        
        self.updateData()
//        self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        //self.timer.
        
//        self.timer = Timer.scheduledTimer(timeInterval: Double(self.getOptionsRefreshTime()), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        
        /*
        self.initVisible()
        
        self.initOptions()
        
        
        
        self.updateTicker()
        
        self.updateData()
        self.timer = Timer.scheduledTimer(timeInterval: Double(self.getOptionsRefreshTime()), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        self.startTicker()
        */
        
//        self.checkUpdate()
    }
    
    /**
     * Kill start at login launcher process
     *
     * @return nil
     */
    func killLauncher() {
        let launcherAppIdentifier = "com.moimz.iCoinTickerLauncher"
        
        var launcherAppRunning = false
        for app in NSWorkspace.shared().runningApplications {
            if (app.bundleIdentifier == launcherAppIdentifier) {
                launcherAppRunning = true
                break
            }
        }
        
        if (launcherAppRunning == true) {
            DistributedNotificationCenter.default().post(name: Notification.Name("killme"), object: Bundle.main.bundleIdentifier!)
        }
    }
    
    /**
     * check documents coins.plist in documents folder and update coins.plist file.
     * Init coins and markets from coins.plist
     *
     * @return nil
     */
    func initPlist() {
        let fileName = "coins.plist"
        
        let documentsUrl: URL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first as URL!).appendingPathComponent(fileName)
        let bundlePath = Bundle.main.path(forResource: fileName, ofType: nil)!
        
        let documentsPlist: NSMutableDictionary? = NSMutableDictionary(contentsOf: documentsUrl)
        let bundlePlist: NSMutableDictionary = NSMutableDictionary(contentsOfFile: bundlePath)!
        
        let documentsUpdated: Date? = documentsPlist == nil ? nil : documentsPlist!["updated"] as? Date
        let bundleUpdated: Date = bundlePlist["updated"] as! Date
        
        if (true || documentsUpdated == nil || bundleUpdated.compare(documentsUpdated!) == ComparisonResult.orderedDescending) {
            do {
                let content = try String(contentsOfFile: bundlePath, encoding: String.Encoding.utf8)
                try content.write(to: documentsUrl, atomically: false, encoding: String.Encoding.utf8)
            } catch {}
            
            self.plist = bundlePlist
        } else {
            self.plist = documentsPlist!
        }
        
        /**
         * Sorting market by tag
         * @todo using sorting option
         */
        let markets: [String: NSMutableDictionary] = self.plist["markets"] as! [String: NSMutableDictionary]
        var marketSorted: [Int: Market] = [:]
        for (key, value) in markets {
            let market: Market = Market(key, value)
            marketSorted[market.tag] = market
        }
        
        for tag in marketSorted.keys.sorted() {
            let market: Market = marketSorted[tag]!
            self.markets.append(market)
        }
        
        /**
         * Sorting coin by tag
         * @todo using sorting option
         */
        let coins: [String: NSMutableDictionary] = self.plist["coins"] as! [String: NSMutableDictionary]
        var coinSorted: [Int: Coin] = [:]
        for (key, value) in coins {
            let coin: Coin = Coin(key, value, self.markets)
            coinSorted[coin.tag] = coin
        }
        
        for tag in coinSorted.keys.sorted() {
            let coin: Coin = coinSorted[tag]!
            self.coins.append(coin)
        }
        /**
         * Sorted coin by tag
         * @todo using sorting option
         *
        var sorted: [Int: String] = [:]
        for (key, value) in plist {
            let tag: Int = Int(value["tag"] as! String)!
            
            /**
             * Sorted market by tag
             * @todo using sorting option
             */
            var marketSorted: [Int: String]
            
            sorted[tag] = key as! String
        }
        
        
        print(sorted)
        */
        /*
        print((self.plist["markets"] as! NSArray)[3])
        print((((self.plist["markets"] as! NSArray)[3]) as! NSMutableDictionary).count)
        print((((self.plist["markets"] as! NSArray)[4]) as! NSMutableDictionary).count)
        */
        /*
        let documentsPlist: URL = documentsUrl.appendingPathComponent("coins.plist")
        
        let bundlePath = Bundle.main.path(forResource: "coins.plist", ofType: nil)!
        let bundleP: NSMutableDictionary = NSMutableDictionary(contentsOfFile: plistPath)!
        
        let coins: NSMutableDictionary? = NSMutableDictionary(contentsOf: plistUrl)
        
        print(coins!["updated"], plist["updated"], coins!["updated"] as! NSDate == plist["updated"] as! NSDate)
        
        if (coins == nil || (coins != nil && coins!["updated"] as! NSDate == plist["updated"] as! NSDate)) {
            do {
                let content = try String(contentsOfFile: plistPath, encoding: String.Encoding.utf8)
                try content.write(to: plistUrl, atomically: false, encoding: String.Encoding.utf8)
            } catch {}
            
            self.coins = NSMutableDictionary(contentsOfFile: plistPath)!
        } else {
            self.coins = coins!
        }
        
        
        print(self.coins)
 */
        /*
        let plistPath = Bundle.main.path(forResource: "coins.plist", ofType: nil)!
        
        
        let updateUrl: URL = URL(string: "https://raw.githubusercontent.com/moimz/iCoinTicker/3.0.0/coins.plist")!
        do {
            do {
                let content = try String(contentsOf: updateUrl, encoding: String.Encoding.utf8)
                try content.write(toFile: plistPath, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                print("error")
            }
        }
        
        
        self.coins = NSMutableDictionary(contentsOfFile: plistPath)!
        
        print(self.coins)
        */
        /*
        
        let test = NSMutableDictionary(contentsOf: destinationFileUrl)
        
        if (true || test == nil) {
            let origin = Bundle.main.path(forResource: "coins.plist", ofType: nil)!
            do {
                let content = try String(contentsOfFile: origin, encoding: String.Encoding.utf8)
                try content.write(to: destinationFileUrl, atomically: false, encoding: String.Encoding.utf8)
            }
            catch {/* error handling here */}
            
            
            /*
             do {
             try text.write(to: path, atomically: false, encoding: String.Encoding.utf8)
             }
             catch {/* error handling here */}
             */
            
        }
        print(test)
        
        print(destinationFileUrl)
        
        
        let filePath = Bundle.main.path(forResource: "coins.plist", ofType: nil)!
        let plist = NSMutableDictionary(contentsOfFile: filePath)!
        
        print(plist)
 */
    }
    
    func initCosts() {
        for coin in self.coins {
            for market in self.markets {
                if (self.costs[coin.unit] == nil) {
                    self.costs[coin.unit] = [:]
                }
                
                if (self.costChanges[coin.unit] == nil) {
                    self.costChanges[coin.unit] = [:]
                }
                
                self.costs[coin.unit]!.updateValue(Double(0), forKey: market.name)
                self.costChanges[coin.unit]!.updateValue(nil, forKey: market.name)
            }
        }
    }
    
    func initAboutWindow() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let appname: NSTextField! = self.aboutWindow.contentView!.viewWithTag(100) as! NSTextField
        appname.stringValue = "iCoinTicker v" + version
    }
    
    func initPreferencesWindow() {
        for item in self.preferencesToolbar.items {
            item.label = NSLocalizedString("preferences.toolbar." + item.label, comment: "")
            item.action = #selector(AppDelegate.preferencesViewSelected)
        }
        
        for view in self.preferencesGeneral.subviews {
            if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("preferences.general." + button.title, comment: "")
            }
        }
        
        let startAtLogin: NSButton! = self.preferencesGeneral.viewWithTag(10) as! NSButton
        startAtLogin.action = #selector(AppDelegate.preferencesStartAtLogin)
        startAtLogin.state = UserDefaults.standard.bool(forKey: "preferencesStartAtLogin") == true ? NSOnState : NSOffState
    }
    
    /**
     * Init status menu
     *
     * @return nil
     */
    func initMenus() {
        self.stopTicker()
        self.statusMenu.removeAllItems()
        
        let about: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.about", comment: ""), action: #selector(AppDelegate.about), keyEquivalent: "")
        self.statusMenu.addItem(about)
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        /**
         * Init enabled coin menu item
         */
        for coin in self.coins {
            if (self.isCoinEnabled(coin.unit) == true) {
                let menu: NSMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                let submenu: NSMenu = NSMenu()
                
                menu.tag = coin.tag
                menu.submenu = submenu
                
                let title = NSMutableAttributedString(string: "")
                title.append(NSAttributedString(string: coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                title.append(NSAttributedString(string: " " + coin.unit + " (" + coin.name + ")", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
                menu.attributedTitle = title
                
                let none: NSMenuItem = NSMenuItem(title: "NONE", action: #selector(self.setSelectedMarket), keyEquivalent: "")
                none.tag = coin.tag * 1000
                none.isEnabled = true
                submenu.addItem(none)
                
                submenu.addItem(NSMenuItem.separator())
                
                var lastSeparator: Bool = true
                var lastCurrency: String = "";
                for market in coin.markets {
                    if (self.isMarketEnabled(market.name) == true) {
                        let menu = NSMenuItem(title: market.paddingName(), action: #selector(self.setSelectedMarket), keyEquivalent: "")
                        menu.tag = coin.tag * 1000 + market.tag
                        menu.image = NSImage(named: market.currency)
                        
                        if (lastSeparator == false && lastCurrency != market.currency) {
                            submenu.addItem(NSMenuItem.separator())
                        }
                        submenu.addItem(menu)
                        lastSeparator = false
                        lastCurrency = market.currency
                    }
                }
                
                let selectedMarket: Market? = self.getSelectedMarket(coin.unit)
                if (selectedMarket == nil) {
                    menu.state = NSOffState
                    submenu.item(withTag: coin.tag * 1000)?.state = NSOnState
                } else {
                    menu.state = NSOnState
                    submenu.item(withTag: coin.tag * 1000 + selectedMarket!.tag)?.state = NSOnState
                }
                
                self.statusMenu.addItem(menu)
            }
        }
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        let refresh: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.refresh", comment: ""), action: #selector(AppDelegate.refresh), keyEquivalent: "r")
        refresh.tag = 100000
        self.statusMenu.addItem(refresh)
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        let preferences: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.preferences", comment: ""), action: #selector(AppDelegate.preferences), keyEquivalent: ",")
        self.statusMenu.addItem(preferences)
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        let quit: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.quit", comment: ""), action: #selector(AppDelegate.quit), keyEquivalent: "q")
        self.statusMenu.addItem(quit)
    }
    
    /**
     * Get coin data by coin unit or tag
     *
     * @param Any coin unit or tag
     * @return Coin? coin
     */
    func getCoin(_ sender: Any) -> Coin? {
        if (sender is Int) {
            let tag: Int = sender as! Int
            
            for coin in self.coins {
                if (coin.tag == tag) {
                    return coin
                }
            }
        } else {
            let unit: String = sender as! String
            
            for coin in self.coins {
                if (coin.unit == unit) {
                    return coin
                }
            }
        }
        
        return nil
    }
    
    /**
     * Get market data by market name or tag
     *
     * @param Any market name or tag
     * @return Market? market
     */
    func getMarket(_ sender: Any) -> Market? {
        if (sender is Int) {
            let tag: Int = sender as! Int
            
            for market in self.markets {
                if (market.tag == tag) {
                    return market
                }
            }
        } else {
            let name: String = sender as! String
            
            for market in self.markets {
                if (market.name == name) {
                    return market
                }
            }
        }
        
        return nil
    }
    
    /**
     * Get ticker selected market by coin unit
     *
     * @param String coin
     * @return Market? market
     */
    func getSelectedMarket(_ unit: String) -> Market? {
        if (unit == "ETH" || unit == "BTC") {
            return self.getMarket("Korbit")
        }
        let coin: Coin? = self.getCoin(unit)
        if (coin == nil) {
            return nil
        } else {
            let selectedMarket: String? = UserDefaults.standard.string(forKey: "Selected" + coin!.unit)
            if (selectedMarket == nil) {
                return nil
            } else {
                let market: Market? = self.getMarket(selectedMarket!)
                if (market == nil || self.isMarketEnabled(market!.name) == false) {
                    return nil
                } else {
                    return market
                }
            }
        }
    }
    
    /**
     * Set selected market
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func setSelectedMarket(_ sender: NSMenuItem) {
        
    }
    
    /**
     * Check coin enabled by coin unit
     *
     * @param String coin unit
     * @return Bool isEnabled
     */
    func isCoinEnabled(_ unit: String) -> Bool {
        let coin: Coin? = self.getCoin(unit)
        if (coin == nil) {
            return false
        } else {
            let isEnabled = UserDefaults.standard.object(forKey: "is" + coin!.unit + "Enabled")
            
            if (isEnabled == nil) {
                UserDefaults.standard.set(true, forKey: "is" + coin!.unit + "Enabled")
                return true
            } else {
                return isEnabled as! Bool
            }
        }
    }
    
    /**
     * Check market enabled by market name
     *
     * @param String market name
     * @return Bool isEnabled
     */
    func isMarketEnabled(_ name: String) -> Bool {
        let market: Market? = self.getMarket(name)
        if (market == nil) {
            return false
        } else {
            let isEnabled = UserDefaults.standard.object(forKey: "is" + market!.name + "Enabled")
            
            if (isEnabled == nil) {
                UserDefaults.standard.set(true, forKey: "is" + market!.name + "Enabled")
                return true
            } else {
                return isEnabled as! Bool
            }
        }
    }
    
    /*
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
            
            //self.getData(coin, market)
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
    }
    */
    /**
     * Get coin cost
     *
     * @param Coin coin
     * @param Market market
     * @param Bool isTicker
     * @reutn String cost
     */
    func getCost(_ coin: Coin, _ market: Market, _ isTicker: Bool) -> String {
        var cost: Double = self.costs[coin.unit]![market.name]!
        
        /*
        if (market < 100) {
            if (self.getOptionsCurrency() > 0) {
                cost = self.costs[coin][market] * self.getCurrency(self.getMarketCurrency(market), self.getOptionsCurrency())
            } else {
                cost = self.costs[coin][market]
            }
        } else {
            cost = self.btcCosts[coin][market % 100] * self.getCurrency(self.getMarketCurrency(market), self.getOptionsCurrency())
        }
        */
        
        
        if (cost == 0) {
            return "Loading..."
        } else {
            var text: String = ""
            
            if (coin.unit != "BTC" && market.isBtcMarket == true) {
                
            } else {
                /*
                var format: String = "#,###"
                
                switch (self.getOptionsCurrency() > 0 ? self.getOptionsCurrency() : market(market)) {
                    case 2 :
                        format = "#,##0.00"
                        break
                    
                    case 4 :
                        format = "#,##0.0"
                        break
                    
                    case 5 :
                        format = "#,##0.00"
                        break
                    
                    default :
                        format = "#,###"
                }
                */
                
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                //numberFormatter.format = format
                /*
                if (self.getOptionsSymbol() == 2 || (useTicker == true && self.getOptionsSymbol() == 1) || (useTicker == false && self.getOptionsSymbol() == 0)) {
                    text = self.currencyMark[self.getOptionsCurrency() > 0 ? self.getOptionsCurrency() : self.getMarketCurrency(market)] + " " + numberFormatter.string(from: NSNumber(value: cost))!
                } else {
                    text = numberFormatter.string(from: NSNumber(value: cost))!
                }
 */
                
                text = numberFormatter.string(from: NSNumber(value: cost))!
                
                return text
            }/* else {
                if (self.getOptionsSymbol() == 2 || (useTicker == true && self.getOptionsSymbol() == 1) || (useTicker == false && self.getOptionsSymbol() == 0)) {
                    return "฿ " + String(format:"%0.8f", cost)
                } else {
                    return String(format:"%0.8f", cost)
                }
            }*/
        }
        
        return ""
    }
    
    /**
     * Start ticker timer
     *
     * @return nil
     */
    func startTicker() {
        self.stopTicker()
        self.tickerTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(AppDelegate.updateTicker), userInfo: nil, repeats: true)
    }
    
    /**
     * Stop ticker timer
     *
     * @return nil
     */
    func stopTicker() {
        self.tickerTimer.invalidate()
    }
    
    /**
     * Update ticker string
     *
     * @return nil
     */
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
        
        for coin in self.coins {
            if (self.isCoinEnabled(coin.unit) == true && self.getSelectedMarket(coin.unit) != nil) {
                if (tickerString.length > 0) {
                    tickerString.append(NSAttributedString(string: " ", attributes: costAttributes))
                }
                
                tickerString.append(NSAttributedString(string: coin.mark, attributes: markAttributes))
                tickerString.append(NSAttributedString(string: " "+"\(self.getCost(coin, self.getSelectedMarket(coin.unit)!, true))", attributes: costAttributes))
            }
        }
        
        if (tickerString.length == 0) {
            self.statusItem.image = NSImage(named: "statusIcon")
            self.statusItem.attributedTitle = nil
        } else {
            self.statusItem.image = nil
            self.statusItem.attributedTitle = tickerString
        }
        /*
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
 */
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
    
    /**
     * Update ticker data
     *
     * @return nil
     */
    func updateData() {
        for market in self.markets {
            if (self.isMarketEnabled(market.name) == true) {
                self.callMarketAPI(market)
            }
        }
        
        let todaysDate = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        let DateInFormat = dateFormatter.string(from: todaysDate)
        
        self.statusMenu.item(withTag: 100000)!.title = NSLocalizedString("menu.refresh", comment: "") + " : " + DateInFormat
    }
    
    /**
     * Call market's ticker API
     *
     * @param Market market
     * @return nil
     */
    func callMarketAPI(_ market:Market) {
        var coins: [String: String] = [:]
        
        for coin in self.coins {
            if (self.isCoinEnabled(coin.unit) == true || (coin.unit == "BTC" && market.isBtcMarket == true)) {
                if (coin.marketParams[market.name] != nil) {
                    coins[coin.unit] = coin.marketParams[market.name]
                }
            }
        }
        
        if (market.isCombination == true) {
            let session = URLSession.shared
            let apiUrl: URL = URL(string: market.api.url)!
            
            let task = session.dataTask(with: apiUrl, completionHandler: {
                (data, response, error) -> Void in
                
                do {
                    if (data != nil) {
                        let jsonData: [String: Any]? = try JSONSerialization.jsonObject(with: data!) as? [String: Any]
                        
                        if (jsonData != nil) {
                            for (unit, param) in coins {
                                let coin: Coin? = self.getCoin(unit)
                                if (coin == nil) {
                                    continue
                                }
                                
                                let coinData: [String: Any]? = jsonData![param] as? [String: Any]
                                
                                var last: Any? = coinData
                                if (last == nil) {
                                    continue
                                }
                            
                                for i in 0..<market.api.last.count {
                                    let key: String = market.api.last[i]
                                    
                                    if (Int(key) == nil) {
                                        let pointer: [String: Any]? = last as? [String: Any]
                                        last = pointer?[key]
                                    } else {
                                        let pointer: NSArray? = last as? NSArray
                                        last = pointer?[Int(key)!]
                                    }
                                }
                                
                                if (last != nil) {
                                    let value: Double = self.getDouble(last!)
                                    self.costs[coin!.unit]![market.name] = value
                                }
                                
                                if (market.api.isCompare == true) {
                                    if (market.api.change.count > 0) {
                                        var change: Any? = coinData
                                        
                                        for i in 0..<market.api.first.count {
                                            let key: String = market.api.change[i]
                                            
                                            if (Int(key) == nil) {
                                                let pointer: [String: Any]? = change as? [String: Any]
                                                change = pointer?[key]
                                            } else {
                                                let pointer: NSArray? = change as? NSArray
                                                change = pointer?[Int(key)!]
                                            }
                                        }
                                        
                                        if (change != nil) {
                                            let value: Double = self.getDouble(change!)
                                            self.costChanges[coin!.unit]![market.name] = value
                                        }
                                    } else {
                                        var first: Any? = coinData
                                        
                                        for i in 0..<market.api.first.count {
                                            let key: String = market.api.first[i]
                                            
                                            if (Int(key) == nil) {
                                                let pointer: [String: Any]? = first as? [String: Any]
                                                first = pointer?[key]
                                            } else {
                                                let pointer: NSArray? = first as? NSArray
                                                first = pointer?[Int(key)!]
                                            }
                                        }
                                        
                                        if (first != nil) {
                                            let value: Double = self.getDouble(first!)
                                            
                                            if (value > 0) {
                                                self.costChanges[coin!.unit]![market.name] = ((self.costs[coin!.unit]![market.name]! - value) / value) * 100
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch _ {}
            })
            
            task.resume()
        } else {
            for (unit, param) in coins {
                let coin: Coin? = self.getCoin(unit)
                if (coin == nil) {
                    continue
                }
                
                let session = URLSession.shared
                let apiUrl: URL = URL(string: market.api.url + param)!
                
                let task = session.dataTask(with: apiUrl, completionHandler: {
                    (data, response, error) -> Void in
                    
                    do {
                        if (data != nil) {
                            let jsonData: [String: Any]? = try JSONSerialization.jsonObject(with: data!) as? [String: Any]
                            
                            if (jsonData != nil) {
                                var last: Any? = jsonData
                                
                                for i in 0..<market.api.last.count {
                                    let key: String = market.api.last[i]
                                    
                                    if (Int(key) == nil) {
                                        let pointer: [String: Any]? = last as? [String: Any]
                                        last = pointer?[key]
                                    } else {
                                        let pointer: NSArray? = last as? NSArray
                                        last = pointer?[Int(key)!]
                                    }
                                }
                                
                                if (last != nil) {
                                    let value: Double = self.getDouble(last!)
                                    self.costs[coin!.unit]![market.name] = value
                                }
                                
                                if (market.api.isCompare == true) {
                                    if (market.api.change.count > 0) {
                                        var change: Any? = jsonData
                                        
                                        for i in 0..<market.api.first.count {
                                            let key: String = market.api.change[i]
                                            
                                            if (Int(key) == nil) {
                                                let pointer: [String: Any]? = change as? [String: Any]
                                                change = pointer?[key]
                                            } else {
                                                let pointer: NSArray? = change as? NSArray
                                                change = pointer?[Int(key)!]
                                            }
                                        }
                                        
                                        if (change != nil) {
                                            let value: Double = self.getDouble(change!)
                                            self.costChanges[coin!.unit]![market.name] = value
                                        }
                                    } else {
                                        var first: Any? = jsonData
                                        
                                        for i in 0..<market.api.first.count {
                                            let key: String = market.api.first[i]
                                            
                                            if (Int(key) == nil) {
                                                let pointer: [String: Any]? = first as? [String: Any]
                                                first = pointer?[key]
                                            } else {
                                                let pointer: NSArray? = first as? NSArray
                                                first = pointer?[Int(key)!]
                                            }
                                        }
                                        
                                        if (first != nil) {
                                            let value: Double = self.getDouble(first!)
                                            
                                            if (value > 0) {
                                                self.costChanges[coin!.unit]![market.name] = ((self.costs[coin!.unit]![market.name]! - value) / value) * 100
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch _ {}
                })
                
                task.resume()
                
            }
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
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func getOptionsCurrency() -> Int {
        return UserDefaults.standard.integer(forKey: "currency")
    }
    /*
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
    */
    func getOptionsFontSize() -> Int {
        let fontSize: Int = UserDefaults.standard.integer(forKey: "fontSize")
        return fontSize == 0 ? 14 : fontSize
    }
    /*
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
    */
    func getOptionsSymbol() -> Int {
        return UserDefaults.standard.integer(forKey: "symbol")
    }
    /*
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
    */
    func getOptionsRefreshTime() -> Int {
        let refreshTime: Int = UserDefaults.standard.integer(forKey: "refreshTime")
        return refreshTime == 0 ? 300 : refreshTime
    }
    /*
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
    */
    
    /*
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
    */
    
    
    /*
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
    */
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
    func about(_ sender: NSMenuItem) {
        self.aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func refresh(_ sender: NSMenuItem) {
        /*
        for i in 0..<self.coinUnit.count {
            for j in 0..<self.marketName.count {
                self.costs[i][j] = Double(0)
            }
        }
        
        self.updateData()
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
 */
    }
    
    func preferences(_ sender: NSMenuItem) {
        self.preferencesWindow.makeKeyAndOrderFront(nil)
        self.preferencesWindow.title = NSLocalizedString("menu.preferences", comment: "")
        NSApp.activate(ignoringOtherApps: true)
        
        if (self.preferencesToolbar.selectedItemIdentifier == nil) {
            self.preferencesToolbar.selectedItemIdentifier = "general"
            preferencesViewSelected(self.preferencesToolbar.items[0])
        }
        
    }
    
    func preferencesViewSelected(_ sender: NSToolbarItem) {
        var subview: NSView
        switch (sender.itemIdentifier) {
            case "general" :
                subview = self.preferencesGeneral
                
            case "coin" :
                subview = self.preferencesCoin
            
            case "donation" :
                subview = self.preferencesDonation
            
            default :
                subview = self.preferencesGeneral
        }
        
        
        let windowRect: NSRect = self.preferencesWindow.frame
        let viewRect: NSRect = subview.frame
        
        self.preferencesWindow.contentView!.isHidden = true
        self.preferencesWindow.contentView = subview
        
        let windowFrame: NSRect = NSMakeRect(windowRect.origin.x, windowRect.origin.y + (windowRect.size.height - viewRect.size.height - 78.0), viewRect.size.width, viewRect.size.height + 78.0)
        self.preferencesWindow.setFrame(windowFrame, display: true, animate: true)
        
        self.preferencesWindow.contentView!.isHidden = false
    }
    
    func preferencesStartAtLogin(_ sender: NSButton) {
        let launcherAppIdentifier = "com.moimz.iCoinTickerLauncher"
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == NSOnState)
        
        UserDefaults.standard.set(sender.state == NSOnState, forKey:"preferencesStartAtLogin")
        
        self.killLauncher()
    }
    
    func quit(_ sender: AnyObject) {
        self.timer.invalidate()
        self.tickerTimer.invalidate()
        exit(0)
    }
    
    @IBAction func openUrl(_ sender: AnyObject) {
        NSWorkspace.shared().open(URL(string: "https://github.com/moimz/iCoinTicker/issues")!)
    }
    
}
