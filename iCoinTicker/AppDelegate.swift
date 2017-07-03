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
import StoreKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var aboutWindow: NSWindow!
    
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var preferencesToolbar: NSToolbar!
    @IBOutlet weak var preferencesGeneral: NSView!
    @IBOutlet weak var preferencesAppearance: NSView!
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
            
            let first: String! = data["first"] as! String
            self.first = first == nil ? [] : first.characters.split(separator: ".").map{ String($0) }
            
            let last: String! = data["last"] as! String
            self.last = last == nil ? [] : last!.characters.split(separator: ".").map{ String($0) }
            
            let change: String! = data["change"] as! String
            self.change = change == nil ? [] : change.characters.split(separator: ".").map{ String($0) }
            
            self.isCompare = first.characters.count > 0 || change.characters.count > 0
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
    
    struct Currency {
        let code: String
        let tag: Int
        let mark: String
        let format: String
        
        init(_ key: String, _ value: NSMutableDictionary) {
            self.code = key
            self.tag = value["tag"] as! Int
            self.mark = value["mark"] as! String
            self.format = value["format"] as! String
        }
    }
    
    let statusMenu: NSMenu = NSMenu()
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    var plist: NSMutableDictionary = [:]
    var markets: [Market] = []
    var coins: [Coin] = []
    var currencies: [String: Currency] = [:]
    var costs: [String: [String: Double]] = [:]
    var costChanges: [String: [String: Double]] = [:]
    
    var donations: [String: SKProduct] = [:]
    
    var tickerTimer = Timer()
    var updaterTimer: [String: Timer] = [:]
    
    var timer: Timer = Timer()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.killLauncher()
        
        self.initPlist()
        self.initCosts()
        self.initWindows()
        self.initMenus()
        
        self.statusItem.menu = self.statusMenu
        
        self.updateTicker()
        self.startTicker()
        
        self.updateData()
        self.timer = Timer.scheduledTimer(timeInterval: Double(self.getPreferencesRefreshInterval()), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(AppDelegate.checkUpdate), userInfo: nil, repeats: false)
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
        
        if (documentsUpdated == nil || bundleUpdated.compare(documentsUpdated!) == ComparisonResult.orderedDescending) {
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
        
        let currencies: [String: NSMutableDictionary] = self.plist["currencies"] as! [String: NSMutableDictionary]
        for (key, value) in currencies {
            let currency: Currency = Currency(key, value)
            self.currencies[key] = currency
        }
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
                self.costChanges[coin.unit]!.updateValue(Double(0), forKey: market.name)
            }
        }
    }
    
    /**
     * Init AboutWindow and PreferencesWindow
     * Localizing and action
     *
     * @return nil
     */
    func initWindows() {
        /**
         * Init About Window
         */
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let appname: NSTextField! = self.aboutWindow.contentView!.viewWithTag(100) as! NSTextField
        appname.stringValue = "iCoinTicker v" + version
        
        /**
         * Init Preferences Toolbar
         */
        for item in self.preferencesToolbar.items {
            item.label = NSLocalizedString("preferences.toolbar." + item.label, comment: "")
            item.action = #selector(AppDelegate.preferencesViewSelected)
        }
        
        /**
         * Init Preferences General Panel
         */
        for view in self.preferencesGeneral.subviews {
            if (view is NSPopUpButton) {
                let button: NSPopUpButton = view as! NSPopUpButton
                for menu in button.menu!.items {
                    menu.title = NSLocalizedString("preferences.general." + menu.title, comment: "")
                }
            } else if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("preferences.general." + button.title, comment: "")
            } else if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                textField.stringValue = NSLocalizedString("preferences.general." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let refreshInterval: NSPopUpButton = self.preferencesGeneral.viewWithTag(10) as! NSPopUpButton
        refreshInterval.action = #selector(AppDelegate.setPreferencesRefreshInterval)
        refreshInterval.select(refreshInterval.menu!.item(withTag: self.getPreferencesRefreshInterval()))
        
        let currency: NSPopUpButton = self.preferencesGeneral.viewWithTag(20) as! NSPopUpButton
        let currencyDefault: NSMenuItem = NSMenuItem(title: NSLocalizedString("preferences.general.currency.default", comment: ""), action: #selector(AppDelegate.setPreferencesCurrency), keyEquivalent: "")
        currencyDefault.tag = 0
        currency.menu!.addItem(currencyDefault)
        
        for (_, value) in self.currencies {
            let menu: NSMenuItem = NSMenuItem(title: value.mark + " " + value.code, action: #selector(AppDelegate.setPreferencesCurrency), keyEquivalent: "")
            menu.tag = value.tag
            menu.image = NSImage(named: value.code)
            
            currency.menu!.addItem(menu)
        }
        currency.select(currency.menu!.item(withTag: self.getPreferencesCurrency()))
        
        let autoUpdate: NSButton = self.preferencesGeneral.viewWithTag(100) as! NSButton
        autoUpdate.action = #selector(AppDelegate.setPreferencesAutoUpdate)
        autoUpdate.state = self.getPreferencesAutoUpdate() == -1 ? NSOffState : NSOnState
        
        let autoUpdateSelect: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
        autoUpdateSelect.action = #selector(AppDelegate.setPreferencesAutoUpdate)
        if (self.getPreferencesAutoUpdate() == -1) {
            autoUpdateSelect.isEnabled = false
            autoUpdateSelect.select(autoUpdateSelect.menu?.item(withTag: 0))
        } else {
            autoUpdateSelect.isEnabled = true
            autoUpdateSelect.select(autoUpdateSelect.menu?.item(withTag: self.getPreferencesAutoUpdate()))
        }
        
        let autoEnabledCoin: NSButton = self.preferencesGeneral.viewWithTag(102) as! NSButton
        autoEnabledCoin.action = #selector(AppDelegate.setPreferencesAutoEnabledCoin)
        autoEnabledCoin.state = self.getPreferencesAutoEnabledCoin() == true ? NSOnState : NSOffState
        
        let autoEnabledMarket: NSButton = self.preferencesGeneral.viewWithTag(103) as! NSButton
        autoEnabledMarket.action = #selector(AppDelegate.setPreferencesAutoEnabledMarket)
        autoEnabledMarket.state = self.getPreferencesAutoEnabledMarket() == true ? NSOnState : NSOffState
        
        let startAtLogin: NSButton! = self.preferencesGeneral.viewWithTag(1000) as! NSButton
        startAtLogin.action = #selector(AppDelegate.setPreferencesStartAtLogin)
        startAtLogin.state = UserDefaults.standard.bool(forKey: "preferencesStartAtLogin") == true ? NSOnState : NSOffState
        
        /**
         * Init Preferences Appearance Panel
         */
        for view in self.preferencesAppearance.subviews {
            if (view is NSPopUpButton) {
                let button: NSPopUpButton = view as! NSPopUpButton
                for menu in button.menu!.items {
                    menu.title = NSLocalizedString("preferences.appearance." + menu.title, comment: "")
                }
            } else if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("preferences.appearance." + button.title, comment: "")
            } else if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                textField.stringValue = NSLocalizedString("preferences.appearance." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let fontSize: NSPopUpButton! = self.preferencesAppearance.viewWithTag(10) as! NSPopUpButton
        fontSize.action = #selector(AppDelegate.setPreferencesFontSize)
        fontSize.select(fontSize.menu!.item(withTag: self.getPreferencesFontSize()))
        
        let tickerDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(20) as! NSPopUpButton
        tickerDisplayedCurrency.action = #selector(AppDelegate.setPreferencesTickerDisplayedCurrency)
        tickerDisplayedCurrency.select(tickerDisplayedCurrency.menu!.item(withTag: self.getPreferencesTickerDisplayedCurrency()))
        
        let tickerDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(30) as! NSButton
        tickerDisplayedChange.action = #selector(AppDelegate.setPreferencesTickerDisplayedChange)
        tickerDisplayedChange.state = self.getPreferencesTickerDisplayedChange() == true ? NSOnState : NSOffState
        
        let menuDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(120) as! NSPopUpButton
        menuDisplayedCurrency.action = #selector(AppDelegate.setPreferencesMenuDisplayedCurrency)
        menuDisplayedCurrency.select(menuDisplayedCurrency.menu!.item(withTag: self.getPreferencesMenuDisplayedCurrency()))
        
        let menuDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(130) as! NSButton
        menuDisplayedChange.action = #selector(AppDelegate.setPreferencesMenuDisplayedChange)
        menuDisplayedChange.state = self.getPreferencesMenuDisplayedChange() == true ? NSOnState : NSOffState
        
        /**
         * Init Preferences Coin Panel
         */
        for view in self.preferencesCoin.subviews {
            if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("preferences.coin." + button.title, comment: "")
            } else if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                textField.stringValue = NSLocalizedString("preferences.coin." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let coins: NSTableView = self.preferencesCoin.viewWithTag(10) as! NSTableView
        coins.tableColumn(withIdentifier: "unit")?.headerCell.title = NSLocalizedString("preferences.coin.coins.header.unit", comment: "")
        coins.tableColumn(withIdentifier: "name")?.headerCell.title = NSLocalizedString("preferences.coin.coins.header.name", comment: "")
        coins.delegate = self
        coins.dataSource = self
        
        let markets: NSTableView = self.preferencesCoin.viewWithTag(20) as! NSTableView
        markets.tableColumn(withIdentifier: "market")?.headerCell.title = NSLocalizedString("preferences.coin.markets.header.market", comment: "")
        markets.tableColumn(withIdentifier: "currency")?.headerCell.title = NSLocalizedString("preferences.coin.markets.header.currency", comment: "")
        markets.delegate = self
        markets.dataSource = self
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        
        let lastUpdate: NSTextField = self.preferencesCoin.viewWithTag(200) as! NSTextField
        lastUpdate.stringValue = NSLocalizedString("preferences.coin.lastUpdate", comment:"") + " : " + dateFormatter.string(from: self.plist["updated"] as! Date)
        
        let checkUpdate: NSButton = self.preferencesCoin.viewWithTag(300) as! NSButton
        checkUpdate.action = #selector(AppDelegate.checkUpdate)
        
        let loading = NSProgressIndicator(frame: NSRect(x: 58.0, y: 7.0, width: 16.0, height: 16.0))
        loading.style = NSProgressIndicatorStyle.spinningStyle
        loading.controlSize = NSControlSize.small
        loading.usesThreadedAnimation = false
        loading.isDisplayedWhenStopped = false
        checkUpdate.addSubview(loading)
        
        /**
         * Init Preferences Donation Panel
         */
        for view in self.preferencesDonation.subviews {
            if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("preferences.donation." + button.title, comment: "")
            } else if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                if (textField.tag == -1) {
                    continue
                }
                textField.stringValue = NSLocalizedString("preferences.donation." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let donations: Set<String> = NSSet(array: ["com.moimz.iCoinTicker.donation.tier1", "com.moimz.iCoinTicker.donation.tier2", "com.moimz.iCoinTicker.donation.tier3", "com.moimz.iCoinTicker.donation.tier4"]) as! Set<String>
        
        if (SKPaymentQueue.canMakePayments() == true) {
            let request = SKProductsRequest(productIdentifiers: donations)
            request.delegate = self
            request.start()
        }
        
        SKPaymentQueue.default().add(self)
        
        for tag in 1...4 {
            let button: NSButton = self.preferencesDonation.viewWithTag(tag * 10) as! NSButton
            button.isEnabled = false
            
            let loading = NSProgressIndicator(frame: NSRect(x: 58.0, y: 7.0, width: 16.0, height: 16.0))
            loading.style = NSProgressIndicatorStyle.spinningStyle
            loading.controlSize = NSControlSize.small
            loading.usesThreadedAnimation = false
            loading.isDisplayedWhenStopped = false
            button.addSubview(loading)
        }
    }
    
    /**
     * Init status menu
     *
     * @return nil
     */
    func initMenus() {
        self.stopTicker()
        self.statusMenu.removeAllItems()
        
        let about: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.about", comment: ""), action: #selector(AppDelegate.openAboutWindow), keyEquivalent: "")
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
                
                let none: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.hideTicker", comment: ""), action: #selector(self.setMarketSelectedTag), keyEquivalent: "")
                none.tag = coin.tag * 1000
                none.isEnabled = true
                submenu.addItem(none)
                
                submenu.addItem(NSMenuItem.separator())
                
                var lastSeparator: Bool = true
                var lastCurrency: String = "";
                for market in coin.markets {
                    if (self.isMarketEnabled(market.name) == true) {
                        let menu = NSMenuItem(title: market.paddingName(), action: #selector(self.setMarketSelectedTag), keyEquivalent: "")
                        menu.tag = coin.tag * 1000 + market.tag
                        menu.image = NSImage(named: market.currency)
                        
                        if (lastSeparator == false && lastCurrency != market.currency) {
                            submenu.addItem(NSMenuItem.separator())
                        }
                        submenu.addItem(menu)
                        
                        if (market.isBtcMarket == true) {
                            let menu = NSMenuItem(title: market.paddingName(), action: #selector(self.setMarketSelectedTag), keyEquivalent: "")
                            menu.tag = coin.tag * 1000 + 100 + market.tag
                            menu.image = NSImage(named: market.currency)
                            
                            submenu.addItem(menu)
                        }
                        
                        lastSeparator = false
                        lastCurrency = market.currency
                    }
                }
                
                let marketSelected: Int = self.getMarketSelectedTag(coin.unit)
                if (marketSelected % 100 == 0) {
                    menu.state = NSOffState
                    submenu.item(withTag: coin.tag * 1000)!.state = NSOnState
                } else {
                    menu.state = NSOnState
                    submenu.item(withTag: marketSelected)!.state = NSOnState
                }
                
                self.statusMenu.addItem(menu)
            }
        }
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        let refresh: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.refresh", comment: ""), action: #selector(AppDelegate.refresh), keyEquivalent: "r")
        refresh.tag = 100000
        self.statusMenu.addItem(refresh)
        
        self.statusMenu.addItem(NSMenuItem.separator())
        
        let preferences: NSMenuItem = NSMenuItem(title: NSLocalizedString("menu.preferences", comment: ""), action: #selector(AppDelegate.openPreferencesWindow), keyEquivalent: ",")
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
     * Get currency data
     *
     * @param Any currency code or tag
     * @return Currency currency
     */
    func getCurrency(_ sender: Any) -> Currency? {
        if (sender is Int) {
            let tag: Int = sender as! Int
            
            for (_, currency) in self.currencies {
                if (currency.tag == tag) {
                    return currency
                }
            }
        } else {
            let code: String = sender as! String
            return self.currencies[code]
        }
        
        return nil
    }
    
    /**
     * Get ticker market selected tag by coin unit
     *
     * @param String coin
     * @return Int marketSelected
     */
    func getMarketSelectedTag(_ unit: String) -> Int {
        let coin: Coin = self.getCoin(unit)!
        return UserDefaults.standard.integer(forKey: "marketSelected" + coin.unit)
    }
    
    /**
     * Set selected market
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func setMarketSelectedTag(_ sender: NSMenuItem) {
        if (sender.state == NSOffState) {
            let coinTag: Int = sender.tag / 1000
            let marketTag: Int = sender.tag % 100
            
            let coin: Coin = self.getCoin(coinTag)!
            
            if (marketTag == 0) {
                self.statusMenu.item(withTag: coinTag)!.state = NSOffState
            } else {
                self.statusMenu.item(withTag: coinTag)!.state = NSOnState
            }
            
            for menu in self.statusMenu.item(withTag: coin.tag)!.submenu!.items {
                if (sender.tag == menu.tag) {
                    menu.state = NSOnState
                } else {
                    menu.state = NSOffState
                }
            }
            
            UserDefaults.standard.set(sender.tag, forKey: "marketSelected" + coin.unit)
            
            self.stopTicker()
            self.updateTicker()
            self.startTicker()
        }
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
                /**
                 * Enabled BTC coin at First launch app
                 */
                if (unit == "BTC") {
                    return true
                }
                UserDefaults.standard.set(self.getPreferencesAutoEnabledCoin(), forKey: "is" + coin!.unit + "Enabled")
                return self.getPreferencesAutoEnabledCoin()
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
                UserDefaults.standard.set(self.getPreferencesAutoEnabledMarket(), forKey: "is" + market!.name + "Enabled")
                return self.getPreferencesAutoEnabledMarket()
            } else {
                return isEnabled as! Bool
            }
        }
    }
    
    /**
     * Get coin cost
     *
     * @param String coin unit
     * @param String market name
     * @param Bool isBtcRate
     * @param Bool isTicker
     * @reutn String cost
     */
    func getCost(_ coin: String, _ market: String, _ isBtcRate: Bool, _ isTicker: Bool) -> String {
        let coin: Coin = self.getCoin(coin)!
        let market: Market = self.getMarket(market)!
        
        let stored: Double = self.costs[coin.unit]![market.name]!
        let changed: Double = self.costChanges[coin.unit]![market.name]!
        var cost: Double = 0
        
        if (coin.unit != "BTC" && market.isBtcMarket == true) {
            cost = stored * self.costs["BTC"]![market.name]!
        } else {
            cost = stored
        }
        
        let currency: Currency = self.getPreferencesCurrency() == 0 ? self.getCurrency(market.currency)! : self.getCurrency(self.getPreferencesCurrency())!
        cost = cost * self.getCurrencyRate(market.currency, currency.code)
        
        var text: String = ""
        
        if (cost == 0) {
            if (isTicker == true) {
                return "Loading..."
            } else {
                if (coin.unit != "BTC" && market.isBtcMarket == true && isBtcRate == true) {
                    if (self.getPreferencesMenuDisplayedCurrency() == 1) {
                        return "฿ Loading..."
                    } else {
                        return "BTC Loading..."
                    }
                } else {
                    if (self.getPreferencesMenuDisplayedCurrency() == 1) {
                        return currency.mark + " Loading..."
                    } else {
                        return currency.code + " Loading..."
                    }
                }
            }
        } else {
            if (coin.unit != "BTC" && market.isBtcMarket == true && isBtcRate == true) {
                if (isTicker == true) {
                    if (self.getPreferencesTickerDisplayedCurrency() == 1) {
                        text = "฿ "
                    } else if (self.getPreferencesTickerDisplayedCurrency() == 2) {
                        text = "BTC "
                    }
                    
                    text += String(format:"%0.8f", stored)
                    
                    if (self.getPreferencesTickerDisplayedChange() == true && market.api.isCompare == true) {
                        text += " (" + (changed > 0 ? "+" : "") + String(format:"%0.2f", changed) + "%)"
                    }
                    
                    return text
                } else {
                    if (self.getPreferencesMenuDisplayedCurrency() == 1) {
                        text = "฿ " + String(format:"%0.8f", stored)
                    } else {
                        text = "BTC " + String(format:"%0.8f", stored)
                    }
                    
                    //text += "".padding(toLength: Int((14 - text.characters.count) / 4), withPad: "\t", startingAt: 0)
                    
                    if (self.getPreferencesMenuDisplayedChange() == true && market.api.isCompare == true) {
                        text += " (" + (changed > 0 ? "+" : "") + String(format:"%0.2f", changed) + "%)"
                    }
                    
                    return text
                }
            } else {
                let numberFormatter = NumberFormatter()
                numberFormatter.numberStyle = .decimal
                numberFormatter.format = currency.format
                
                if ((isTicker == true && self.getPreferencesTickerDisplayedCurrency() == 1) || (isTicker == false && self.getPreferencesMenuDisplayedCurrency() == 1)) {
                    text = currency.mark + " "
                } else if ((isTicker == true && self.getPreferencesTickerDisplayedCurrency() == 2) || isTicker == false) {
                    text = currency.code + " "
                }
                
                text += numberFormatter.string(from: NSNumber(value: cost))!
                
                if (isTicker == true && self.getPreferencesTickerDisplayedChange() == true && market.api.isCompare == true) {
                    text += " (" + (changed > 0 ? "+" : "") + String(format:"%0.2f", changed) + "%)"
                }
                
                if (isTicker == false && self.getPreferencesMenuDisplayedChange() == true && market.api.isCompare == true) {
                    text += " (" + (changed > 0 ? "+" : "") + String(format:"%0.2f", changed) + "%)"
                }
                
                return text
            }
        }
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
        
        if (self.getPreferencesFontSize() == 10) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 10.0), NSBaselineOffsetAttributeName: 2.5]
        } else if (self.getPreferencesFontSize() == 12) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins", size: 12.0)!, NSBaselineOffsetAttributeName: 1.0]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 12.0), NSBaselineOffsetAttributeName: 2.0]
        }
        
        for coin in self.coins {
            if (self.isCoinEnabled(coin.unit) == true && self.getMarketSelectedTag(coin.unit) % 100 > 0) {
                if (tickerString.length > 0) {
                    tickerString.append(NSAttributedString(string: " ", attributes: costAttributes))
                }
                
                let marketTag: Int = self.getMarketSelectedTag(coin.unit) % 100
                let isBtcRate: Bool = self.getMarketSelectedTag(coin.unit) % 1000 > 100
                
                let market: Market = self.getMarket(marketTag)!
                
                tickerString.append(NSAttributedString(string: coin.mark, attributes: markAttributes))
                tickerString.append(NSAttributedString(string: " " + self.getCost(coin.unit, market.name, isBtcRate, true), attributes: costAttributes))
            }
        }
        
        if (tickerString.length == 0) {
            self.statusItem.image = NSImage(named: "statusIcon")
            self.statusItem.attributedTitle = nil
        } else {
            self.statusItem.image = nil
            self.statusItem.attributedTitle = tickerString
        }
        
        for coin in self.coins {
            if (self.isCoinEnabled(coin.unit) == true) {
                let menu: NSMenuItem? = self.statusMenu.item(withTag: coin.tag)
                if (menu != nil) {
                    let submenu: NSMenu! = menu!.submenu!
                    
                    for menu in submenu.items {
                        let tag: Int = menu.tag
                        
                        if (tag % 1000 > 0) {
                            let market: Market = self.getMarket(tag % 100)!
                            let isBtcRate: Bool = tag % 1000 > 100
                            
                            let cost: String = self.getCost(coin.unit, market.name, isBtcRate, false)
                            
                            let title = NSMutableAttributedString(string: "")
                            title.append(NSAttributedString(string: market.paddingName(), attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0)]))
                            title.append(NSAttributedString(string: cost, attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0)]))
                            menu.attributedTitle = title
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Get currency rate
     *
     * @param String from
     * @param String to
     * @return Double rate
     */
    func getCurrencyRate(_ from: String, _ to: String) -> Double {
        if (from == to) {
            return 1
        } else {
            return UserDefaults.standard.double(forKey: from + to)
        }
    }
    
    /**
     * Update currency rate
     *
     * @param String from
     * @param String to
     * @return nil
     */
    func updateCurrencyRate(_ from: String, _ to: String) {
        if (from == to || UserDefaults.standard.double(forKey: from + to + "Time") > Date().timeIntervalSince1970 - 60 * 60) {
            return
        }
        
        let session = URLSession.shared
        let jsonUrl = URL(string: "https://api.manana.kr/exchange/rate/" + to + "/" + from + ".json")
        
        let task = session.dataTask(with: jsonUrl!, completionHandler: {
            (data, response, error) -> Void in
            
            do {
                let jsonData = try JSONSerialization.jsonObject(with: data!) as! [[String: Any]]
                
                if (jsonData.count == 1) {
                    let time: Double = Date().timeIntervalSince1970
                    
                    let rate: Double = jsonData[0]["rate"] as! Double
                    UserDefaults.standard.set(rate, forKey: from + to)
                    UserDefaults.standard.set(time, forKey: from + to + "Time")
                }
            } catch _ {}
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
        
        for (from, _) in self.currencies {
            for (to, _) in self.currencies {
                self.updateCurrencyRate(from, to)
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        let DateInFormat = dateFormatter.string(from: Date())
        
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
                                        
                                        for i in 0..<market.api.change.count {
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
                                            let value: Double = self.getDouble(change!) * 100
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
                                        
                                        for i in 0..<market.api.change.count {
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
                                            let value: Double = self.getDouble(change!) * 100
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
    
    /**
     * Convert Any to Double
     *
     * @param Any number
     * @return Double number
     */
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
    
    /**
     * Get Refresh Interval
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func getPreferencesRefreshInterval() -> Int {
        let time: Int = UserDefaults.standard.integer(forKey: "preferencesRefreshTime")
        return time == 0 ? 300 : time
    }
    
    /**
     * Get currency
     *
     * @return Int currency tag
     */
    func getPreferencesCurrency() -> Int {
        return UserDefaults.standard.integer(forKey: "preferencesCurrency")
    }
    
    /**
     * Get Auto update interval
     *
     * @return Int update interval
     */
    func getPreferencesAutoUpdate() -> Int {
        return UserDefaults.standard.integer(forKey: "preferencesAutoUpdate")
    }
    
    /**
     * Get Auto enabled coin
     *
     * @return Bool isAutoEnabled
     */
    func getPreferencesAutoEnabledCoin() -> Bool {
        return UserDefaults.standard.bool(forKey: "preferencesAutoEnabledCoin")
    }
    
    /**
     * Get Auto enabled market
     *
     * @return Bool isAutoEnabled
     */
    func getPreferencesAutoEnabledMarket() -> Bool {
        return UserDefaults.standard.bool(forKey: "preferencesAutoEnabledMarket")
    }
    
    /**
     * Get ticker font size
     *
     * @return Int font size(pt)
     */
    func getPreferencesFontSize() -> Int {
        let fontSize: Int = UserDefaults.standard.integer(forKey: "preferencesFontSize")
        return fontSize == 0 ? 14 : fontSize
    }
    
    /**
     * Get ticker displayed currency
     *
     * @return Int displayedCurrency (0: none, 1: symbol, 2: code)
     */
    func getPreferencesTickerDisplayedCurrency() -> Int {
        return UserDefaults.standard.integer(forKey: "preferencesTickerDisplayedCurrency")
    }
    
    /**
     * Get ticker displayed change
     *
     * @return Bool displayedChange
     */
    func getPreferencesTickerDisplayedChange() -> Bool {
        return UserDefaults.standard.bool(forKey: "preferencesTickerDisplayedChange")
    }
    
    /**
     * Get menu displayed currency
     *
     * @return Int displayedCurrency (1: symbol, 2: code)
     */
    func getPreferencesMenuDisplayedCurrency() -> Int {
        let displayedCurrency: Int = UserDefaults.standard.integer(forKey: "preferencesMenuDisplayedCurrency")
        return displayedCurrency == 0 ? 1 : displayedCurrency
    }
    
    /**
     * Get menu displayed change
     *
     * @return Bool displayedChange
     */
    func getPreferencesMenuDisplayedChange() -> Bool {
        return UserDefaults.standard.bool(forKey: "preferencesMenuDisplayedChange")
    }
    
    /**
     * Check coins.plist update from github.com/moimz/iCoinTicker
     *
     * @param Any sender
     */
    func checkUpdate(_ sender: Any) {
        if (sender is NSButton) {
            let button: NSButton = sender as! NSButton
            let loading: NSProgressIndicator = button.viewWithTag(-1) as! NSProgressIndicator
            button.title = ""
            button.isEnabled = false
            loading.startAnimation(nil)
        } else {
            if (self.getPreferencesAutoUpdate() == -1) {
                return
            } else if (self.getPreferencesAutoUpdate() > 0 && self.checkUpdateDate() < self.getPreferencesAutoUpdate()) {
                Timer.scheduledTimer(timeInterval: Double(self.getPreferencesAutoUpdate() * 60 * 60 * 24), target: self, selector: #selector(AppDelegate.checkUpdate), userInfo: nil, repeats: false)
                return
            }
        }
        
        let session = URLSession.shared
        let updateUrl: URL = URL(string: "https://raw.githubusercontent.com/moimz/iCoinTicker/3.0.0/coins.plist")!
        
        let task = session.dataTask(with: updateUrl, completionHandler: {
            (data, response, error) -> Void in
            
            do {
                if (data != nil) {
                    let plist: NSMutableDictionary = try PropertyListSerialization.propertyList(from: data!, options: [], format: nil) as! NSMutableDictionary
                    
                    let updated: Date = plist["updated"] as! Date
                    if (updated > self.plist["updated"] as! Date) {
                        let fileName = "coins.plist"
                        let documentsUrl: URL = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first as URL!).appendingPathComponent(fileName)
                        
                        let content: String = String(data: data!, encoding: String.Encoding.utf8)!
                        try content.write(to: documentsUrl, atomically: false, encoding: String.Encoding.utf8)
                        
                        self.checkUpdateAlert(updated, sender is NSButton ? sender : nil)
                    } else if (sender is NSButton) {
                        self.checkUpdateAlert(nil, sender)
                    }
                    
                    UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "latestUpdatedTime")
                } else {
                    self.checkUpdateAlert(nil, sender)
                }
            } catch _ {
                if (sender is NSButton) {
                    self.checkUpdateAlert(nil, sender)
                }
            }
        })
        
        task.resume()
    }
    
    /**
     * Check Lastest updated time
     *
     * @return Int date
     */
    func checkUpdateDate() -> Int {
        let latestUpdatedTime: Double = UserDefaults.standard.double(forKey: "latestUpdatedTime")
        
        let now: Double = Date().timeIntervalSince1970
        let date: Int = Int((now - latestUpdatedTime) / 60.0 / 60.0 / 24.0)
        
        return date
    }
    
    /**
     * Show alert message after checking updated coins.plist
     *
     * @param Date? updatedDate
     * @return nil
     */
    func checkUpdateAlert(_ updatedDate: Date?, _ sender: Any?) {
        let isUpdated: Bool = updatedDate != nil
        var title: String = ""
        var message: String = ""
        
        if (isUpdated == true) {
            title = NSLocalizedString("preferences.coin.checkUpdate.true.title", comment:"")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
            
            message = NSLocalizedString("preferences.coin.checkUpdate.true.date", comment:"") + ": " + dateFormatter.string(from: updatedDate!)
            message += "\n\n" + NSLocalizedString("preferences.coin.checkUpdate.true.message", comment:"")
        } else {
            title = NSLocalizedString("preferences.coin.checkUpdate.false.title", comment:"")
            message = NSLocalizedString("preferences.coin.checkUpdate.false.message", comment:"")
        }
        
        DispatchQueue.main.async {
            let alert: NSAlert = NSAlert()
            alert.alertStyle = NSAlertStyle.informational
            alert.messageText = title
            alert.informativeText = message
            if (isUpdated == true) {
                alert.addButton(withTitle: NSLocalizedString("button.relaunch", comment:""))
                alert.addButton(withTitle: NSLocalizedString("button.cancel", comment:""))
            } else {
                alert.addButton(withTitle: NSLocalizedString("button.close", comment:""))
            }
            
            let selected = alert.runModal()
            if (selected == NSAlertFirstButtonReturn) {
                if (isUpdated == true) {
                    self.relaunch()
                } else if (sender != nil) {
                    let button: NSButton = sender as! NSButton
                    let loading: NSProgressIndicator = button.viewWithTag(-1) as! NSProgressIndicator
                    loading.stopAnimation(nil)
                    button.title = NSLocalizedString("preferences.coin.checkUpdate", comment: "")
                    button.isEnabled = true
                }
            } else {
                if (isUpdated == true) {
                    self.plist["updated"] = updatedDate
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
                    
                    let lastUpdate: NSTextField = self.preferencesCoin.viewWithTag(200) as! NSTextField
                    lastUpdate.stringValue = NSLocalizedString("preferences.coin.lastUpdate", comment:"") + " : " + dateFormatter.string(from: self.plist["updated"] as! Date)
                }
                
                if (sender != nil) {
                    let button: NSButton = sender as! NSButton
                    let loading: NSProgressIndicator = button.viewWithTag(-1) as! NSProgressIndicator
                    loading.stopAnimation(nil)
                    button.title = NSLocalizedString("preferences.coin.checkUpdate", comment: "")
                    button.isEnabled = true
                }
                
                
            }
        }
    }
    
    /**
     * Force refresh
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func refresh(_ sender: NSMenuItem) {
        self.initCosts()
        self.stopTicker()
        self.updateTicker()
        self.updateData()
        self.startTicker()
    }
    
    /**
     * Open About window
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func openAboutWindow(_ sender: NSMenuItem) {
        self.aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /**
     * Open Prefrences window and Localizing window
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func openPreferencesWindow(_ sender: NSMenuItem) {
        self.preferencesWindow.makeKeyAndOrderFront(nil)
        self.preferencesWindow.title = NSLocalizedString("menu.preferences", comment: "")
        NSApp.activate(ignoringOtherApps: true)
        
        if (self.preferencesToolbar.selectedItemIdentifier == nil) {
            self.preferencesToolbar.selectedItemIdentifier = "general"
            preferencesViewSelected(self.preferencesToolbar.items[0])
        }
    }
    
    /**
     * Preferences Toolbar Select
     *
     * @param NSToolbarItem sender
     * @ return nil
     */
    func preferencesViewSelected(_ sender: NSToolbarItem) {
        var subview: NSView
        
        switch (sender.itemIdentifier) {
            case "general" :
                subview = self.preferencesGeneral
            
            case "appearance" :
                subview = self.preferencesAppearance
            
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
    
    /**
     * Set Refresh Interval
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesRefreshInterval(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.selectedItem!.tag, forKey: "preferencesRefreshTime")
        
        self.timer.invalidate()
        self.timer = Timer.scheduledTimer(timeInterval: Double(sender.selectedItem!.tag), target: self, selector: #selector(AppDelegate.updateData), userInfo: nil, repeats: true)
    }
    
    /**
     * Set currency
     *
     * @param NSMenuItem sender
     * @return nil
     */
    func setPreferencesCurrency(_ sender: NSMenuItem) {
        UserDefaults.standard.set(sender.tag, forKey: "preferencesCurrency")
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set Auto update
     *
     * @param Any sender
     * @return nil
     */
    func setPreferencesAutoUpdate(_ sender: Any) {
        if (sender is NSPopUpButton) {
            let select: NSPopUpButton = sender as! NSPopUpButton
            UserDefaults.standard.set(select.selectedItem!.tag, forKey: "preferencesAutoUpdate")
        } else if (sender is NSButton) {
            let button: NSButton = sender as! NSButton
            if (button.state == NSOnState) {
                UserDefaults.standard.set(0, forKey: "preferencesAutoUpdate")
                
                let select: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
                select.isEnabled = true
                select.select(select.menu!.item(withTag: 0))
            } else {
                UserDefaults.standard.set(-1, forKey: "preferencesAutoUpdate")
                
                let select: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
                select.isEnabled = true
                select.select(select.menu!.item(withTag: 0))
                select.isEnabled = false
                select.select(select.menu!.item(withTag: 0))
            }
        }
    }
    
    /**
     * Set Auto Enabled Coin
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesAutoEnabledCoin(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "preferencesAutoEnabledCoin")
        } else {
            UserDefaults.standard.set(false, forKey: "preferencesAutoEnabledCoin")
        }
    }
    
    /**
     * Set Auto Enabled Market
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesAutoEnabledMarket(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "preferencesAutoEnabledMarket")
        } else {
            UserDefaults.standard.set(false, forKey: "preferencesAutoEnabledMarket")
        }
    }
    
    /**
     * Toggle ticker font size
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesStartAtLogin(_ sender: NSButton) {
        let launcherAppIdentifier = "com.moimz.iCoinTickerLauncher"
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == NSOnState)
        
        UserDefaults.standard.set(sender.state == NSOnState, forKey:"preferencesStartAtLogin")
        
        self.killLauncher()
    }
    
    /**
     * Set ticker font size
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesFontSize(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.selectedItem!.tag, forKey: "preferencesFontSize")
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set ticker displayed currency
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesTickerDisplayedCurrency(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.selectedItem!.tag, forKey: "preferencesTickerDisplayedCurrency")
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set ticker displayed change
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesTickerDisplayedChange(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "preferencesTickerDisplayedChange")
        } else {
            UserDefaults.standard.set(false, forKey: "preferencesTickerDisplayedChange")
        }
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set menu displayed currency
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesMenuDisplayedCurrency(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(sender.selectedItem!.tag, forKey: "preferencesMenuDisplayedCurrency")
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set menu displayed change
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesMenuDisplayedChange(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "preferencesMenuDisplayedChange")
        } else {
            UserDefaults.standard.set(false, forKey: "preferencesMenuDisplayedChange")
        }
        
        self.stopTicker()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set Enabled Coin
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesCoinEnabled(_ sender: NSButton) {
        let coin: Coin = self.getCoin(sender.tag)!
        
        self.stopTicker()
        
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "is" + coin.unit + "Enabled")
        } else {
            UserDefaults.standard.set(false, forKey: "is" + coin.unit + "Enabled")
        }
        
        self.initMenus()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Set Enabled Market
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesMarketEnabled(_ sender: NSButton) {
        let market: Market = self.getMarket(sender.tag)!
        
        self.stopTicker()
        
        if (sender.state == NSOnState) {
            UserDefaults.standard.set(true, forKey: "is" + market.name + "Enabled")
        } else {
            UserDefaults.standard.set(false, forKey: "is" + market.name + "Enabled")
        }
        
        self.initMenus()
        self.updateTicker()
        self.startTicker()
    }
    
    /**
     * Quit app
     *
     * @param AnyObject sender
     * @return nil
     */
    func quit(_ sender: AnyObject) {
        self.timer.invalidate()
        self.tickerTimer.invalidate()
        NSApplication.shared().terminate(nil)
    }
    
    /**
     * Relaunch app after coin.plist update
     *
     * @return nil
     */
    func relaunch() {
        let task = Process()
        var args = [String]()
        args.append("-c")
        let bundle = Bundle.main.bundlePath
        args.append("sleep 0.2; open \"\(bundle)\"")
        task.launchPath = "/bin/sh"
        task.arguments = args
        task.launch()
        NSApplication.shared().terminate(nil)
    }
    
    /**
     * Donate Button (IAP)
     *
     * @param NSButton sender
     * @return nil
     */
    func donate(_ sender: NSButton) {
        if (sender.identifier == nil) {
            return
        }
        
        let loading: NSProgressIndicator = sender.viewWithTag(-1) as! NSProgressIndicator
        sender.title = ""
        sender.isEnabled = false
        loading.startAnimation(nil)
        
        let item: SKProduct? = self.donations[sender.identifier!]
        if (item != nil) {
            let payment = SKPayment(product: item!)
            SKPaymentQueue.default().add(payment)
        }
    }
    
    /**
     * Show alert message after purchase
     *
     * @param Bool success
     * @return nil
     */
    func donateAlert(_ success: Bool) {
        var title: String = ""
        var message: String = ""
        
        if (success == true) {
            title = NSLocalizedString("preferences.donation.success.title", comment:"")
            message = NSLocalizedString("preferences.donation.success.message", comment:"")
        } else {
            title = NSLocalizedString("preferences.donation.fail.title", comment:"")
            message = NSLocalizedString("preferences.donation.fail.message", comment:"")
        }
        
        DispatchQueue.main.async {
            let alert: NSAlert = NSAlert()
            alert.alertStyle = NSAlertStyle.informational
            alert.messageText = title
            alert.icon = NSImage(named: "Donation")
            alert.informativeText = message
            alert.addButton(withTitle: NSLocalizedString("button.close", comment:""))
            
            let selected = alert.runModal()
            if (selected == NSAlertFirstButtonReturn) {
                for tag in 1...4 {
                    let button: NSButton = self.preferencesDonation.viewWithTag(tag * 10) as! NSButton
                    if (button.isEnabled == false) {
                        let loading: NSProgressIndicator = button.viewWithTag(-1) as! NSProgressIndicator
                        let product: SKProduct? = self.donations[button.identifier!]
                        
                        if (product == nil) {
                            continue
                        }
                        
                        var title: String = ""
                        
                        if (product!.priceLocale.currencyCode != nil) {
                            title += product!.priceLocale.currencyCode!
                        } else if (product!.priceLocale.currencySymbol != nil) {
                            title += product!.priceLocale.currencySymbol!
                        }
                        button.title = title + " " + product!.price.stringValue
                        button.isEnabled = true
                        loading.stopAnimation(nil)
                    }
                }
            }
        }
    }
    
    @IBAction func openUrl(_ sender: AnyObject) {
        NSWorkspace.shared().open(URL(string: "https://github.com/moimz/iCoinTicker/issues")!)
    }
}

/**
 * NSTextField with Keyboard short
 */
class NSTextFieldWithShortcut: NSTextField {
    private let commandKey = NSEventModifierFlags.command.rawValue
    private let commandShiftKey = NSEventModifierFlags.command.rawValue | NSEventModifierFlags.shift.rawValue
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (event.type == NSEventType.keyDown) {
            if ((event.modifierFlags.rawValue & NSEventModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey) {
                switch (event.charactersIgnoringModifiers!) {
                    case "x":
                        if NSApp.sendAction(#selector(NSText.cut(_:)), to:nil, from:self) { return true }
                    
                    case "c":
                        if NSApp.sendAction(#selector(NSText.copy(_:)), to:nil, from:self) { return true }
                    
                    case "v":
                        if NSApp.sendAction(#selector(NSText.paste(_:)), to:nil, from:self) { return true }
                    
                    case "a":
                        if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to:nil, from:self) { return true }
                    
                    default:
                        break
                }
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
}

/**
 * IAP extension
 */
extension AppDelegate: SKPaymentTransactionObserver, SKProductsRequestDelegate {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions as [SKPaymentTransaction] {
            switch (transaction.transactionState) {
                case SKPaymentTransactionState.purchased :
                    SKPaymentQueue.default().finishTransaction(transaction)
                    
                    self.donateAlert(true)
                    break
                
                case SKPaymentTransactionState.failed :
                    
                    SKPaymentQueue.default().finishTransaction(transaction)
                    
                    self.donateAlert(false)
                    break
                
                default:
                    break
            }
        }
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        for product in response.products {
            let tag: Int = Int(product.productIdentifier.replacingOccurrences(of: "com.moimz.iCoinTicker.donation.tier", with: ""))! * 10
            let button: NSButton = self.preferencesDonation.viewWithTag(tag) as! NSButton
            
            var title: String = ""
            if (product.priceLocale.currencyCode != nil) {
                title += product.priceLocale.currencyCode!
            } else if (product.priceLocale.currencySymbol != nil) {
                title += product.priceLocale.currencySymbol!
            }
            button.title = title + " " + product.price.stringValue
            button.action = #selector(AppDelegate.donate)
            button.isEnabled = true
            button.identifier = product.productIdentifier
            
            self.donations[product.productIdentifier] = product
        }
    }
}

/**
 * Table view extension
 */
extension AppDelegate: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if (tableView.identifier == "coins") {
            return self.coins.count
        } else if (tableView.identifier == "markets") {
            return self.markets.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if (tableView.identifier == "coins") {
            let coin: Coin = self.coins[row]
            
            if (tableColumn?.identifier == "unit") {
                let check: NSButton = tableView.make(withIdentifier:(tableColumn?.identifier)!, owner: self) as! NSButton
                check.tag = coin.tag
                check.action = #selector(AppDelegate.setPreferencesCoinEnabled)
                check.state = self.isCoinEnabled(coin.unit) == true ? NSOnState : NSOffState
                
                let title = NSMutableAttributedString(string: "")
                title.append(NSAttributedString(string: coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins", size: 14.0)!]))
                title.append(NSAttributedString(string: " " + coin.unit, attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: 1.5]))
                check.attributedTitle = title
                
                return check
            } else if (tableColumn?.identifier == "name") {
                let cell: NSTableCellView = tableView.make(withIdentifier:(tableColumn?.identifier)!, owner: self) as! NSTableCellView
                cell.textField?.stringValue = coin.name
                
                return cell
            }
        } else if (tableView.identifier == "markets") {
            let market: Market = self.markets[row]
            
            if (tableColumn?.identifier == "market") {
                let check: NSButton = tableView.make(withIdentifier:(tableColumn?.identifier)!, owner: self) as! NSButton
                check.tag = market.tag
                check.title = market.name
                check.action = #selector(AppDelegate.setPreferencesMarketEnabled)
                check.state = self.isMarketEnabled(market.name) == true ? NSOnState : NSOffState
                
                return check
            } else if (tableColumn?.identifier == "currency") {
                let cell: NSTableCellView = tableView.make(withIdentifier:(tableColumn?.identifier)!, owner: self) as! NSTableCellView
                cell.imageView?.image = NSImage(named: market.currency)
                cell.textField?.stringValue = market.currency
                
                return cell
            }
        }
        
        return nil
    }
}
