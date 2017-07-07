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
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    
    @IBOutlet weak var aboutWindow: NSWindow!
    
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var preferencesToolbar: NSToolbar!
    @IBOutlet weak var preferencesGeneral: NSView!
    @IBOutlet weak var preferencesAppearance: NSView!
    @IBOutlet weak var preferencesCoin: NSView!
    @IBOutlet weak var preferencesNotification: NSView!
    @IBOutlet weak var preferencesDonation: NSView!
    
    @IBOutlet weak var notificationEditWindow: NSWindow!
    
    let preferences: NSUbiquitousKeyValueStore = NSUbiquitousKeyValueStore()
    
    struct Coin {
        let unit: String
        let name: String
        let tag: Int
        let mark: String
        let marketParams: [String: String]
        let markets: [Market]
        
        init(_ key: String, _ value: NSMutableDictionary) {
            let appDelegate = NSApplication.shared().delegate as! AppDelegate
            
            self.unit = key
            self.name = value["name"] as! String
            self.tag = value["tag"] as! Int
            self.mark = String(Character(UnicodeScalar(Int(value["mark"] as! String, radix: 16)!)!))
            
            let marketParams: [String: String] = value["marketParams"] as! [String: String]
            self.marketParams = marketParams
            
            var markets: [Market] = []
            for market in appDelegate.markets {
                if (marketParams[market.name] != nil) {
                    markets.append(market)
                }
            }
            self.markets = markets
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
        let display: String
        let tag: Int
        let currency: String
        let isCombination: Bool
        let isBtcMarket: Bool
        let api: Api
        
        init(_ key: String,_ value: NSMutableDictionary) {
            self.name = key
            self.display = value["display"] as? String == nil ? key : value["display"] as! String
            self.tag = value["tag"] as! Int
            self.currency = value["currency"] as! String
            self.isCombination = value["isCombination"] as! Bool
            self.isBtcMarket = value["isBtcMarket"] as! Bool
            self.api = Api(value["api"] as! NSMutableDictionary)
        }
        
        func paddingName() -> String {
            return self.display + "".padding(toLength: Int((20 - self.display.characters.count) / 4), withPad: "\t", startingAt: 0)
        }
    }
    
    struct NotificationSetting {
        let coin: Coin
        let market: Market
        let currency: Currency
        let price: Double
        let rule: String
        let repeated: Bool
        let enabled: Bool
        
        init(_ value: NSDictionary) {
            let appDelegate = NSApplication.shared().delegate as! AppDelegate
            
            self.coin = appDelegate.getCoin(value["coin"] as! Int)!
            self.market = appDelegate.getMarket(value["market"] as! Int)!
            self.currency = appDelegate.getCurrency(value["currency"] as! String)!
            self.price = value["price"] as! Double
            self.rule = value["rule"] as! String
            self.repeated = value["repeated"] as! Bool
            self.enabled = value["enabled"] as! Bool
        }
        
        func getCost() -> Double {
            let appDelegate = NSApplication.shared().delegate as! AppDelegate
            var cost: Double = appDelegate.costs[self.coin.unit]![self.market.name]!
            
            if (self.coin.unit != "BTC" && self.market.isBtcMarket == true && self.currency.code != "BTC") {
                cost = cost * appDelegate.costs["BTC"]![self.market.name]!
            }
            
            return cost * appDelegate.getCurrencyRate(self.market.currency, self.currency.code)
        }
        
        func isSatisfied() -> Bool {
            if (self.enabled == false) {
                return false
            }
            
            if (self.rule == ">=" && self.getCost() >= self.price) {
                return true
            }
            
            if (self.rule == "<=" && self.getCost() <= self.price) {
                return true
            }
            
            return false
        }
        
        func notify(_ index: Int) {
            if (self.isSatisfied() == true) {
                let appDelegate = NSApplication.shared().delegate as! AppDelegate
                
                let numberFormatter = NumberFormatter()
                numberFormatter.format = self.currency.format
                
                let price = self.currency.code + " " + numberFormatter.string(from: NSNumber(value: self.getCost()))!
                appDelegate.showCostNotification(self.coin, price)
                
                if (self.repeated == false) {
                    let notification: NSMutableDictionary = appDelegate.notifications[index].mutableCopy() as! NSMutableDictionary
                    notification.setValue(false, forKey: "enabled")
                    
                    appDelegate.notifications[index] = notification as NSDictionary
                    appDelegate.setStorage("notifications", appDelegate.notifications)
                    
                    let tableView: NSTableView = appDelegate.preferencesNotification.viewWithTag(10) as! NSTableView
                    let tableViewSelected: IndexSet = tableView.selectedRowIndexes
                    tableView.reloadData()
                    tableView.selectRowIndexes(tableViewSelected, byExtendingSelection: false)
                }
            }
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
    
    var notifications: [NSDictionary] = []
    
    var donations: [String: SKProduct] = [:]
    
    var tickerTimer: Timer = Timer()
    var notificationTimer = Timer()
    var timer: Timer = Timer()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.preferences.synchronize()
        
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
        
        self.notifications = self.getStorage("notifications") == nil ? [] : self.getStorage("notifications") as! [NSDictionary]
        
        self.startNotification()
        
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
            let coin: Coin = Coin(key, value)
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
        
        let currency: NSPopUpButton = self.preferencesGeneral.viewWithTag(20) as! NSPopUpButton
        let currencyDefault: NSMenuItem = NSMenuItem(title: NSLocalizedString("preferences.general.currency.default", comment: ""), action: #selector(AppDelegate.setPreferencesCurrency), keyEquivalent: "")
        currencyDefault.tag = 0
        currency.menu!.addItem(currencyDefault)
        
        for (_, value) in self.currencies {
            if (value.code == "BTC") {
                continue
            }
            
            let menu: NSMenuItem = NSMenuItem(title: value.mark + " " + value.code, action: #selector(AppDelegate.setPreferencesCurrency), keyEquivalent: "")
            menu.tag = value.tag
            menu.image = NSImage(named: value.code)
            
            currency.menu!.addItem(menu)
        }
        
        let autoUpdate: NSButton = self.preferencesGeneral.viewWithTag(100) as! NSButton
        autoUpdate.action = #selector(AppDelegate.setPreferencesAutoUpdate)
        
        let autoUpdateSelect: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
        autoUpdateSelect.action = #selector(AppDelegate.setPreferencesAutoUpdate)
        
        let autoEnabledCoin: NSButton = self.preferencesGeneral.viewWithTag(102) as! NSButton
        autoEnabledCoin.action = #selector(AppDelegate.setPreferencesAutoEnabledCoin)
        
        let autoEnabledMarket: NSButton = self.preferencesGeneral.viewWithTag(103) as! NSButton
        autoEnabledMarket.action = #selector(AppDelegate.setPreferencesAutoEnabledMarket)
        
        let startAtLogin: NSButton! = self.preferencesGeneral.viewWithTag(1000) as! NSButton
        startAtLogin.action = #selector(AppDelegate.setPreferencesStartAtLogin)
        
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
        
        let tickerDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(20) as! NSPopUpButton
        tickerDisplayedCurrency.action = #selector(AppDelegate.setPreferencesTickerDisplayedCurrency)
        
        let tickerDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(30) as! NSButton
        tickerDisplayedChange.action = #selector(AppDelegate.setPreferencesTickerDisplayedChange)
        
        let menuDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(120) as! NSPopUpButton
        menuDisplayedCurrency.action = #selector(AppDelegate.setPreferencesMenuDisplayedCurrency)
        
        let menuDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(130) as! NSButton
        menuDisplayedChange.action = #selector(AppDelegate.setPreferencesMenuDisplayedChange)
        
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
         * Init Preferences Notification Panel
         */
        for view in self.preferencesNotification.subviews {
            if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                textField.stringValue = NSLocalizedString("preferences.notification." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let notifications: NSTableView = self.preferencesNotification.viewWithTag(10) as! NSTableView
        notifications.tableColumn(withIdentifier: "coin")?.headerCell.title = NSLocalizedString("preferences.notification.coin", comment: "")
        notifications.tableColumn(withIdentifier: "market")?.headerCell.title = NSLocalizedString("preferences.notification.market", comment: "")
        notifications.tableColumn(withIdentifier: "rule")?.headerCell.title = NSLocalizedString("preferences.notification.rule", comment: "")
        notifications.tableColumn(withIdentifier: "status")?.headerCell.title = NSLocalizedString("preferences.notification.status", comment: "")
        notifications.delegate = self
        notifications.dataSource = self
        notifications.doubleAction = #selector(AppDelegate.openNotificationEditSheet)
        
        
        let addButton: NSButton = self.preferencesNotification.viewWithTag(100) as! NSButton
        addButton.action = #selector(AppDelegate.openNotificationEditSheet)
        
        let removeButton: NSButton = self.preferencesNotification.viewWithTag(200) as! NSButton
        removeButton.action = #selector(AppDelegate.removeNotifications)
        
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
        
        /**
         * Init Preferences Notification Panel
         */
        
        /**
         * Init Notification Edit Window
         */
        let notificationEditView: NSView = self.notificationEditWindow.contentView!
        for view in notificationEditView.subviews {
            if (view is NSPopUpButton) {
                let button: NSPopUpButton = view as! NSPopUpButton
                for menu in button.menu!.items {
                    menu.title = NSLocalizedString("notification.edit." + menu.title, comment: "")
                }
            } else if (view is NSButton) {
                let button: NSButton = view as! NSButton
                button.title = NSLocalizedString("notification.edit." + button.title, comment: "")
            } else if (view is NSTextField) {
                let textField: NSTextField = view as! NSTextField
                if (textField.tag == -1) {
                    continue
                }
                textField.stringValue = NSLocalizedString("notification.edit." + textField.stringValue, comment: "") + (view.tag == 1 ? " : " : "")
            }
        }
        
        let coinButton: NSPopUpButton = notificationEditView.viewWithTag(10) as! NSPopUpButton
        for coin in self.coins {
            let menu: NSMenuItem = NSMenuItem()
            let title = NSMutableAttributedString(string: "")
            title.append(NSAttributedString(string: coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 12.0)!]))
            title.append(NSAttributedString(string: " " + coin.unit + " (" + coin.name + ")", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 13.0), NSBaselineOffsetAttributeName: -0.5]))
            menu.attributedTitle = title
            menu.tag = coin.tag
            coinButton.menu!.addItem(menu)
        }
        coinButton.action = #selector(AppDelegate.setNotificationEditSheet)
        
        let marketButton: NSPopUpButton = notificationEditView.viewWithTag(20) as! NSPopUpButton
        for market in self.markets {
            let menu: NSMenuItem = NSMenuItem()
            menu.title = market.name
            menu.tag = market.tag
            menu.image = NSImage(named: market.currency)
            marketButton.menu!.addItem(menu)
        }
        marketButton.action = #selector(AppDelegate.setNotificationEditSheet)
        
        let currencyButton: NSPopUpButton = notificationEditView.viewWithTag(30) as! NSPopUpButton
        for (code, currency) in self.currencies {
            let menu: NSMenuItem = NSMenuItem()
            menu.title = currency.code + " (" + currency.mark + ")"
            menu.tag = currency.tag
            menu.identifier = code
            currencyButton.menu!.addItem(menu)
        }
        currencyButton.action = #selector(AppDelegate.setNotificationEditSheet)
        
        let priceInput: NSTextField = notificationEditView.viewWithTag(40) as! NSTextField
        priceInput.stringValue = "0"
        
        let saveButton: NSButton = notificationEditView.viewWithTag(100) as! NSButton
        saveButton.title = NSLocalizedString("button.save", comment: "")
        saveButton.action = #selector(AppDelegate.closeNotificationEditSheet)
        
        let closeButton: NSButton = notificationEditView.viewWithTag(200) as! NSButton
        closeButton.title = NSLocalizedString("button.close", comment: "")
        closeButton.action = #selector(AppDelegate.closeNotificationEditSheet)
    }
    
    func initPreferences() {
        /**
         * Init Preferences General
         */
        let refreshInterval: NSPopUpButton = self.preferencesGeneral.viewWithTag(10) as! NSPopUpButton
        refreshInterval.select(refreshInterval.menu!.item(withTag: self.getPreferencesRefreshInterval()))
        
        let currency: NSPopUpButton = self.preferencesGeneral.viewWithTag(20) as! NSPopUpButton
        currency.select(currency.menu!.item(withTag: self.getPreferencesCurrency()))
        
        let autoUpdate: NSButton = self.preferencesGeneral.viewWithTag(100) as! NSButton
        autoUpdate.state = self.getPreferencesAutoUpdate() == -1 ? NSOffState : NSOnState
        
        let autoUpdateSelect: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
        if (self.getPreferencesAutoUpdate() == -1) {
            autoUpdateSelect.isEnabled = false
            autoUpdateSelect.select(autoUpdateSelect.menu?.item(withTag: 0))
        } else {
            autoUpdateSelect.isEnabled = true
            autoUpdateSelect.select(autoUpdateSelect.menu?.item(withTag: self.getPreferencesAutoUpdate()))
        }
        
        let autoEnabledCoin: NSButton = self.preferencesGeneral.viewWithTag(102) as! NSButton
        autoEnabledCoin.state = self.getPreferencesAutoEnabledCoin() == true ? NSOnState : NSOffState
        
        let autoEnabledMarket: NSButton = self.preferencesGeneral.viewWithTag(103) as! NSButton
        autoEnabledMarket.state = self.getPreferencesAutoEnabledMarket() == true ? NSOnState : NSOffState
        
        let startAtLogin: NSButton! = self.preferencesGeneral.viewWithTag(1000) as! NSButton
        startAtLogin.state = self.getPreferencesStartAtLogin() == true ? NSOnState : NSOffState
        
        /**
         * Init Preferences Appearance
         */
        let fontSize: NSPopUpButton! = self.preferencesAppearance.viewWithTag(10) as! NSPopUpButton
        fontSize.select(fontSize.menu!.item(withTag: self.getPreferencesFontSize()))
        
        let tickerDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(20) as! NSPopUpButton
        tickerDisplayedCurrency.select(tickerDisplayedCurrency.menu!.item(withTag: self.getPreferencesTickerDisplayedCurrency()))
        
        let tickerDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(30) as! NSButton
        tickerDisplayedChange.state = self.getPreferencesTickerDisplayedChange() == true ? NSOnState : NSOffState
        
        let menuDisplayedCurrency: NSPopUpButton! = self.preferencesAppearance.viewWithTag(120) as! NSPopUpButton
        menuDisplayedCurrency.select(menuDisplayedCurrency.menu!.item(withTag: self.getPreferencesMenuDisplayedCurrency()))
        
        let menuDisplayedChange: NSButton! = self.preferencesAppearance.viewWithTag(130) as! NSButton
        menuDisplayedChange.state = self.getPreferencesMenuDisplayedChange() == true ? NSOnState : NSOffState
        
        /**
         * Init Preferences Coin
         */
        let coins: NSTableView = self.preferencesCoin.viewWithTag(10) as! NSTableView
        coins.reloadData()
        
        let markets: NSTableView = self.preferencesCoin.viewWithTag(20) as! NSTableView
        markets.reloadData()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY.MM.dd HH:mm:ss"
        
        let lastUpdate: NSTextField = self.preferencesCoin.viewWithTag(200) as! NSTextField
        lastUpdate.stringValue = NSLocalizedString("preferences.coin.lastUpdate", comment:"") + " : " + dateFormatter.string(from: self.plist["updated"] as! Date)
        
        /**
         * Init Preferences Notification
         */
        let notifications: NSTableView = self.preferencesNotification.viewWithTag(10) as! NSTableView
        notifications.reloadData()
        
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
                title.append(NSAttributedString(string: coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 14.0)!]))
                title.append(NSAttributedString(string: " " + coin.unit + " (" + coin.name + ")", attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: -0.5]))
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
                        
                        if (coin.unit != "BTC" && market.isBtcMarket == true) {
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
        let marketSelected = self.getStorage("preferencesMarketSelected") as? NSDictionary
        if (marketSelected == nil || marketSelected![coin.unit] == nil) {
            return 0
        } else {
            let marketSelectedTag = marketSelected![coin.unit] as! Int
            if (self.getMarket(marketSelectedTag % 100) == nil) {
                return 0
            } else {
                return marketSelectedTag
            }
        }
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
            
            let marketSelected: NSMutableDictionary = self.getStorage("preferencesMarketSelected") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesMarketSelected") as! NSDictionary).mutableCopy() as! NSMutableDictionary
            marketSelected.setValue(sender.tag, forKey: coin.unit)
            self.setStorage("preferencesMarketSelected", marketSelected)
            
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
            let enabledCoins = self.getStorage("preferencesEnabledCoins") as? NSDictionary
            if (enabledCoins == nil || enabledCoins![unit] == nil) {
                if (unit == "BTC") {
                    let enabledCoins: NSMutableDictionary = self.getStorage("preferencesEnabledCoins") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesEnabledCoins") as? NSDictionary)?.mutableCopy() as! NSMutableDictionary
                    enabledCoins.setValue(true, forKey: "BTC")
                    self.setStorage("preferencesEnabledCoins", enabledCoins)
                    
                    return true
                } else {
                    let enabledCoins: NSMutableDictionary = self.getStorage("preferencesEnabledCoins") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesEnabledCoins") as? NSDictionary)?.mutableCopy() as! NSMutableDictionary
                    enabledCoins.setValue(self.getPreferencesAutoEnabledCoin(), forKey: unit)
                    self.setStorage("preferencesEnabledCoins", enabledCoins)
                    
                    return self.getPreferencesAutoEnabledCoin()
                }
            }
            
            return enabledCoins![unit] as! Bool
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
            let enabledMarkets = self.getStorage("preferencesEnabledMarkets") as? NSDictionary
            if (enabledMarkets == nil || enabledMarkets![name] == nil) {
                let enabledMarkets: NSMutableDictionary = self.getStorage("preferencesEnabledMarkets") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesEnabledMarkets") as? NSDictionary)?.mutableCopy() as! NSMutableDictionary
                enabledMarkets.setValue(self.getPreferencesAutoEnabledMarket(), forKey: name)
                self.setStorage("preferencesEnabledMarkets", enabledMarkets)
                
                return self.getPreferencesAutoEnabledMarket()
            } else {
                return enabledMarkets![name] as! Bool
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
        
        if (coin.unit != "BTC" && market.isBtcMarket == true && isBtcRate == false) {
            cost = stored * self.costs["BTC"]![market.name]!
        } else {
            cost = stored
        }
        
        var currency: Currency
        if (coin.unit != "BTC" && market.isBtcMarket == true && isBtcRate == true) {
            currency = self.getCurrency("BTC")!
        } else {
            currency = self.getPreferencesCurrency() == 0 ? self.getCurrency(market.currency)! : self.getCurrency(self.getPreferencesCurrency())!
        }
        
        cost = cost * self.getCurrencyRate(market.currency, currency.code)
        
        var text: String = ""
        
        if (cost == 0) {
            if (isTicker == true) {
                return "Loading..."
            } else {
                if (self.getPreferencesMenuDisplayedCurrency() == 1) {
                    return currency.mark + " Loading..."
                } else {
                    return currency.code + " Loading..."
                }
            }
        } else {
            let numberFormatter = NumberFormatter()
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
        
        var markAttributes: [String: Any] = [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 14.0)!]
        var costAttributes: [String: Any] = [NSFontAttributeName: NSFont.systemFont(ofSize: 14.0), NSBaselineOffsetAttributeName: -0.5]
        
        if (self.getPreferencesFontSize() == 10) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 12.0)!]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 10.0)]
        } else if (self.getPreferencesFontSize() == 12) {
            markAttributes = [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 12.0)!]
            costAttributes = [NSFontAttributeName: NSFont.systemFont(ofSize: 12.0), NSBaselineOffsetAttributeName: -0.5]
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
     * Start notification timer
     *
     * @return nil
     */
    func startNotification() {
        self.stopNotification()
        self.notificationTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(AppDelegate.notify), userInfo: nil, repeats: true)
    }
    
    /**
     * Stop notification timer
     *
     * @return nil
     */
    func stopNotification() {
        self.notificationTimer.invalidate()
    }
    
    /**
     * notify
     *
     * @return nil
     */
    func notify() {
        for index in 0..<self.notifications.count {
            NotificationSetting(self.notifications[index]).notify(index)
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
        if (from == to || from == "BTC" || to == "BTC") {
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
        if (from == to || from == "BTC" || to == "BTC" || UserDefaults.standard.double(forKey: from + to + "Time") > Date().timeIntervalSince1970 - 60 * 60) {
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
                                    
                                    if (key == "*") {
                                        let keyname: [String: Any]? = last as? [String: Any]
                                        if (keyname != nil) {
                                            for (_, object) in keyname! {
                                                last = object
                                            }
                                        } else {
                                            last = nil
                                            break
                                        }
                                    } else if (Int(key) == nil) {
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
                                            
                                            if (key == "*") {
                                                let keyname: [String: Any]? = change as? [String: Any]
                                                if (keyname != nil) {
                                                    for (_, object) in keyname! {
                                                        change = object
                                                    }
                                                } else {
                                                    change = nil
                                                    break
                                                }
                                            } else if (Int(key) == nil) {
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
                                            
                                            if (key == "*") {
                                                let keyname: [String: Any]? = first as? [String: Any]
                                                if (keyname != nil) {
                                                    for (_, object) in keyname! {
                                                        first = object
                                                    }
                                                } else {
                                                    first = nil
                                                    break
                                                }
                                            } else if (Int(key) == nil) {
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
        return self.getStorage("preferencesRefreshTime") == nil ? 300 : self.getStorage("preferencesRefreshTime") as! Int
    }
    
    /**
     * Get currency
     *
     * @return Int currency tag
     */
    func getPreferencesCurrency() -> Int {
        return self.getStorage("preferencesCurrency") == nil ? 0 : self.getStorage("preferencesCurrency") as! Int
    }
    
    /**
     * Get Auto update interval
     *
     * @return Int update interval
     */
    func getPreferencesAutoUpdate() -> Int {
        return self.getStorage("preferencesAutoUpdate") == nil ? 0 : self.getStorage("preferencesAutoUpdate") as! Int
    }
    
    /**
     * Get Auto enabled coin
     *
     * @return Bool isAutoEnabled
     */
    func getPreferencesAutoEnabledCoin() -> Bool {
        return self.getStorage("preferencesAutoEnabledCoin") == nil ? false : self.getStorage("preferencesAutoEnabledCoin") as! Bool
    }
    
    /**
     * Get Auto enabled market
     *
     * @return Bool isAutoEnabled
     */
    func getPreferencesAutoEnabledMarket() -> Bool {
        return self.getStorage("preferencesAutoEnabledMarket") == nil ? false : self.getStorage("preferencesAutoEnabledMarket") as! Bool
    }
    
    /**
     * Get start at login option
     *
     * @return Bool isStartAtLogin
     */
    func getPreferencesStartAtLogin() -> Bool {
        let launcherAppIdentifier = "com.moimz.iCoinTickerLauncher"
        let startAtLogin = self.getStorage("preferencesStartAtLogin") as? Bool
        
        if (startAtLogin == nil) {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, false)
            return false
        } else {
            SMLoginItemSetEnabled(launcherAppIdentifier as CFString, startAtLogin!)
            return startAtLogin!
        }
    }
    
    /**
     * Get ticker font size
     *
     * @return Int font size(pt)
     */
    func getPreferencesFontSize() -> Int {
        return self.getStorage("preferencesFontSize") == nil ? 14 : self.getStorage("preferencesFontSize") as! Int
    }
    
    /**
     * Get ticker displayed currency
     *
     * @return Int displayedCurrency (0: none, 1: symbol, 2: code)
     */
    func getPreferencesTickerDisplayedCurrency() -> Int {
        return self.getStorage("preferencesTickerDisplayedCurrency") == nil ? 0 : self.getStorage("preferencesTickerDisplayedCurrency") as! Int
    }
    
    /**
     * Get ticker displayed change
     *
     * @return Bool displayedChange
     */
    func getPreferencesTickerDisplayedChange() -> Bool {
        return self.getStorage("preferencesTickerDisplayedChange") == nil ? false : self.getStorage("preferencesTickerDisplayedChange") as! Bool
    }
    
    /**
     * Get menu displayed currency
     *
     * @return Int displayedCurrency (1: symbol, 2: code)
     */
    func getPreferencesMenuDisplayedCurrency() -> Int {
        return self.getStorage("preferencesTickerDisplayedCurrency") == nil ? 1 : self.getStorage("preferencesTickerDisplayedCurrency") as! Int
    }
    
    /**
     * Get menu displayed change
     *
     * @return Bool displayedChange
     */
    func getPreferencesMenuDisplayedChange() -> Bool {
        return self.getStorage("preferencesMenuDisplayedChange") == nil ? false : self.getStorage("preferencesMenuDisplayedChange") as! Bool
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
        let updateUrl: URL = URL(string: "https://raw.githubusercontent.com/moimz/iCoinTicker/master/coins.plist")!
        
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
                alert.addButton(withTitle: NSLocalizedString("button.cancel", comment:""))
            }
            
            if (self.preferencesWindow.isVisible == true) {
                alert.beginSheetModal(for: self.preferencesWindow, completionHandler: {
                    (selected) -> Void in
                    
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
                })
            } else {
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
        
        self.initPreferences()
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
            
            case "notification" :
                subview = self.preferencesNotification
            
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
     * Open sheet for notification edit
     *
     * @param Any sender
     * @return nil
     */
    func openNotificationEditSheet(_ sender: Any) {
        let notificationEditView: NSView = self.notificationEditWindow.contentView!
        
        let coinButton: NSPopUpButton = notificationEditView.viewWithTag(10) as! NSPopUpButton
        let marketButton: NSPopUpButton = notificationEditView.viewWithTag(20) as! NSPopUpButton
        let currencyButton: NSPopUpButton = notificationEditView.viewWithTag(30) as! NSPopUpButton
        let priceInput: NSTextField = notificationEditView.viewWithTag(40) as! NSTextField
        let ruleButton: NSPopUpButton = notificationEditView.viewWithTag(50) as! NSPopUpButton
        let enabledButton: NSButton = notificationEditView.viewWithTag(60) as! NSButton
        let repeatedButton: NSButton = notificationEditView.viewWithTag(70) as! NSButton
        
        if (sender is NSTableView || sender is IndexSet) {
            var index: Int? = nil
            
            if (sender is NSTableView) {
                let tableView: NSTableView = sender as! NSTableView
                
                if (tableView.clickedRow == -1) {
                    return
                }
                
                index = tableView.clickedRow
            } else {
                let indexes: NSIndexSet = sender as! NSIndexSet
                if (indexes.count != 1) {
                    return
                }
                
                index = indexes.firstIndex
            }
            
            if (index == nil || index == -1) {
                return
            }
            
            let notification: NotificationSetting = NotificationSetting(self.notifications[index!])
            
            coinButton.selectItem(withTag: notification.coin.tag)
            self.setNotificationEditSheet(coinButton)
            
            marketButton.selectItem(withTag: notification.market.tag)
            self.setNotificationEditSheet(marketButton)
            
            currencyButton.selectItem(withTag: notification.currency.tag)
            self.setNotificationEditSheet(currencyButton)
            
            let numberFormatter: NumberFormatter = priceInput.formatter as! NumberFormatter
            priceInput.stringValue = numberFormatter.string(from: NSNumber(value: notification.price))!
            
            ruleButton.selectItem(withTag: notification.rule == ">=" ? 10 : 20)
            
            enabledButton.state = notification.enabled == true ? NSOnState : NSOffState
            repeatedButton.state = notification.repeated == true ? NSOnState : NSOffState
            
            notificationEditView.identifier = NSNumber(value: index!).stringValue
        } else {
            coinButton.selectItem(at: 0)
            self.setNotificationEditSheet(coinButton)
            
            marketButton.selectItem(at: 0)
            self.setNotificationEditSheet(marketButton)
            
            currencyButton.selectItem(withTag: self.getPreferencesCurrency())
            self.setNotificationEditSheet(currencyButton)
            
            ruleButton.selectItem(at: 0)
            
            enabledButton.state = NSOnState
            repeatedButton.state = NSOffState
            
            notificationEditView.identifier = nil
        }
        
        self.preferencesWindow.beginSheet(self.notificationEditWindow, completionHandler: nil)
        self.notificationEditWindow.makeKeyAndOrderFront(nil)
    }
    
    /**
     * Set edit value in notification edit sheet
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setNotificationEditSheet(_ sender: NSPopUpButton) {
        let notificationEditView: NSView = self.notificationEditWindow.contentView!
        
        if (sender.tag == 10) {
            let coin: Coin = self.getCoin(sender.selectedItem!.tag)!
            
            let marketButton: NSPopUpButton = notificationEditView.viewWithTag(20) as! NSPopUpButton
            let selectedMarketTag: Int = marketButton.selectedItem!.tag
            marketButton.menu!.removeAllItems()
            
            for market in coin.markets {
                let menu: NSMenuItem = NSMenuItem()
                menu.title = market.name
                menu.tag = market.tag
                menu.image = NSImage(named: market.currency)
                marketButton.menu!.addItem(menu)
            }
            
            if (marketButton.menu!.item(withTag: selectedMarketTag) == nil) {
                marketButton.selectItem(at: 0)
            } else {
                marketButton.selectItem(withTag: selectedMarketTag)
            }
            
            self.setNotificationEditSheet(marketButton)
        } else if (sender.tag == 20) {
            let coin: Coin = self.getCoin((notificationEditView.viewWithTag(10) as! NSPopUpButton).selectedItem!.tag)!
            let market: Market = self.getMarket(sender.selectedItem!.tag)!
            
            let currencyButton: NSPopUpButton = notificationEditView.viewWithTag(30) as! NSPopUpButton
            let selectedCurrencyTag: Int = currencyButton.selectedItem!.tag
            currencyButton.menu!.removeAllItems()
            
            for (code, currency) in self.currencies {
                if (code == "BTC" && (coin.unit == "BTC" || market.isBtcMarket == false)) {
                    continue
                }
                let menu: NSMenuItem = NSMenuItem()
                menu.title = currency.code + " (" + currency.mark + ")"
                menu.tag = currency.tag
                menu.identifier = code
                currencyButton.menu!.addItem(menu)
            }
            
            if (currencyButton.menu!.item(withTag: selectedCurrencyTag) == nil) {
                currencyButton.selectItem(at: 0)
            } else {
                currencyButton.selectItem(withTag: selectedCurrencyTag)
            }
            
            self.setNotificationEditSheet(currencyButton)
        } else if (sender.tag == 30) {
            let coinButton: NSPopUpButton = notificationEditView.viewWithTag(10) as! NSPopUpButton
            let coin: Coin = self.getCoin(coinButton.selectedItem!.tag)!
            
            let marketButton: NSPopUpButton = notificationEditView.viewWithTag(20) as! NSPopUpButton
            let market: Market = self.getMarket(marketButton.selectedItem!.tag)!
            
            let currency: Currency = self.getCurrency(sender.selectedItem!.identifier!)!
            
            let priceInput: NSTextField = notificationEditView.viewWithTag(40) as! NSTextField
            let numberFormatter = priceInput.formatter as! NumberFormatter
            numberFormatter.format = currency.format
            
            var cost: Double = 0
            if (market.isBtcMarket == true && coin.unit != "BTC" && currency.code == "BTC") {
                cost = self.costs[coin.unit]![market.name]!
                priceInput.stringValue = numberFormatter.string(from: NSNumber(value: cost))!
            } else {
                if (market.isBtcMarket == true && coin.unit != "BTC") {
                    cost = self.costs[coin.unit]![market.name]! * self.costs["BTC"]![market.name]!
                } else {
                    cost = self.costs[coin.unit]![market.name]!
                }
                
                cost = cost * self.getCurrencyRate(market.currency, currency.code)
                priceInput.stringValue = numberFormatter.string(from: NSNumber(value: cost))!
            }
        }
    }
    
    /**
     * Save notifications
     *
     * @param Int lists index
     * @return nil
     */
    func saveNotifications(_ index: Int) {
        self.stopNotification()
        
        let notificationEditView: NSView = self.notificationEditWindow.contentView!
        
        let coinButton: NSPopUpButton = notificationEditView.viewWithTag(10) as! NSPopUpButton
        let coin: Int = coinButton.selectedItem!.tag
        
        let marketButton: NSPopUpButton = notificationEditView.viewWithTag(20) as! NSPopUpButton
        let market: Int = marketButton.selectedItem!.tag
        
        let currencyButton: NSPopUpButton = notificationEditView.viewWithTag(30) as! NSPopUpButton
        let currency: String = currencyButton.selectedItem!.identifier!
        
        let priceInput: NSTextField = notificationEditView.viewWithTag(40) as! NSTextField
        let price: Double = Double(priceInput.stringValue.replacingOccurrences(of: ",", with: "")) == nil ? 0 : Double(priceInput.stringValue.replacingOccurrences(of: ",", with: ""))!
        
        let ruleButton: NSPopUpButton = notificationEditView.viewWithTag(50) as! NSPopUpButton
        let rule: String = ruleButton.selectedItem!.tag == 10 ? ">=" : "<="
        
        let enabledButton: NSButton = notificationEditView.viewWithTag(60) as! NSButton
        let enabled: Bool = enabledButton.state == NSOnState
        
        let repeatedButton: NSButton = notificationEditView.viewWithTag(70) as! NSButton
        let repeated: Bool = repeatedButton.state == NSOnState
        
        let notification: NSMutableDictionary = NSMutableDictionary()
        notification.setValue(coin, forKey: "coin")
        notification.setValue(market, forKey: "market")
        notification.setValue(currency, forKey: "currency")
        notification.setValue(price, forKey: "price")
        notification.setValue(rule, forKey: "rule")
        notification.setValue(enabled, forKey: "enabled")
        notification.setValue(repeated, forKey: "repeated")
        
        if (index == -1) {
            self.notifications.append(notification)
        } else {
            self.notifications[index] = notification
        }
        
        self.setStorage("notifications", notifications)
        
        let tableView: NSTableView = self.preferencesNotification.viewWithTag(10) as! NSTableView
        tableView.reloadData()
        if (index > -1) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else if (self.notifications.count > 0) {
            tableView.selectRowIndexes(IndexSet(integer: self.notifications.count - 1), byExtendingSelection: false)
        }
        
        self.startNotification()
    }
    
    /**
     * Remove notifications
     *
     * @param Any sender
     * @return nil
     */
    func removeNotifications(_ sender: Any) {
        self.stopNotification()
        
        let tableView: NSTableView = self.preferencesNotification.viewWithTag(10) as! NSTableView
        
        let indexes: NSIndexSet = tableView.selectedRowIndexes as NSIndexSet
        if (indexes.count == 0) {
            return
        }
        
        let alert: NSAlert = NSAlert()
        alert.alertStyle = NSAlertStyle.informational
        alert.messageText = NSLocalizedString("preferences.notification.remove", comment: "")
        alert.informativeText = NSLocalizedString("preferences.notification.removeHelp", comment: "").replacingOccurrences(of: "{COUNT}", with: NSNumber(value: indexes.count).stringValue)
        alert.addButton(withTitle: NSLocalizedString("button.delete", comment:""))
        alert.addButton(withTitle: NSLocalizedString("button.cancel", comment:""))
        
        alert.beginSheetModal(for: self.preferencesWindow, completionHandler: {
            (selected) -> Void in
            
            if (selected == NSAlertFirstButtonReturn) {
                var notifications: [NSDictionary] = []
                for i in 0..<self.notifications.count {
                    if (indexes.contains(i) == false) {
                        notifications.append(self.notifications[i])
                    }
                }
                
                self.notifications = notifications
                self.setStorage("notifications", self.notifications)
                tableView.reloadData()
            }
            
            self.startNotification()
        })
    }
    
    /**
     * Close or Save notification edit sheet
     *
     * @param NSButton sender
     * @return nil
     */
    func closeNotificationEditSheet(_ sender: NSButton) {
        if (sender.tag == 100) {
            let notificationEditView: NSView = self.notificationEditWindow.contentView!
            let index: Int = notificationEditView.identifier == nil ? -1 : Int(notificationEditView.identifier!)!
            self.saveNotifications(index)
        }
        
        self.preferencesWindow.endSheet(self.notificationEditWindow)
    }
    
    /**
     * Set Refresh Interval
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesRefreshInterval(_ sender: NSPopUpButton) {
        self.setStorage("preferencesRefreshTime", sender.selectedItem!.tag)
        
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
        self.setStorage("preferencesCurrency", sender.tag)
        
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
            self.setStorage("preferencesAutoUpdate", select.selectedItem!.tag)
        } else if (sender is NSButton) {
            let button: NSButton = sender as! NSButton
            if (button.state == NSOnState) {
                self.setStorage("preferencesAutoUpdate", 0)
                
                let select: NSPopUpButton = self.preferencesGeneral.viewWithTag(101) as! NSPopUpButton
                select.isEnabled = true
                select.select(select.menu!.item(withTag: 0))
            } else {
                self.setStorage("preferencesAutoUpdate", -1)
                
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
        self.setStorage("preferencesAutoEnabledCoin", sender.state == NSOnState)
    }
    
    /**
     * Set Auto Enabled Market
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesAutoEnabledMarket(_ sender: NSButton) {
        self.setStorage("preferencesAutoEnabledMarket", sender.state == NSOnState)
    }
    
    /**
     * Toggle start at login option
     *
     * @param NSButton sender
     * @return nil
     */
    func setPreferencesStartAtLogin(_ sender: NSButton) {
        let launcherAppIdentifier = "com.moimz.iCoinTickerLauncher"
        SMLoginItemSetEnabled(launcherAppIdentifier as CFString, sender.state == NSOnState)
        
        self.setStorage("preferencesStartAtLogin", sender.state == NSOnState)
        self.killLauncher()
    }
    
    /**
     * Set ticker font size
     *
     * @param NSPopUpButton sender
     * @return nil
     */
    func setPreferencesFontSize(_ sender: NSPopUpButton) {
        self.setStorage("preferencesFontSize", sender.selectedItem!.tag)
        
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
        self.setStorage("preferencesTickerDisplayedCurrency", sender.selectedItem!.tag)
        
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
        self.setStorage("preferencesTickerDisplayedChange", sender.state == NSOnState)
        
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
        self.setStorage("preferencesMenuDisplayedCurrency", sender.selectedItem!.tag)
        
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
        self.setStorage("preferencesMenuDisplayedChange", sender.state == NSOnState)
        
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
        let enabledCoins: NSMutableDictionary = self.getStorage("preferencesEnabledCoins") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesEnabledCoins") as! NSDictionary).mutableCopy() as! NSMutableDictionary
        
        self.stopTicker()
        
        enabledCoins.setValue(sender.state == NSOnState, forKey: coin.unit)
        self.setStorage("preferencesEnabledCoins", enabledCoins)
        
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
        let enabledMarkets: NSMutableDictionary = self.getStorage("preferencesEnabledMarkets") as? NSDictionary == nil ? NSMutableDictionary() : (self.getStorage("preferencesEnabledMarkets") as! NSDictionary).mutableCopy() as! NSMutableDictionary
        
        self.stopTicker()
        
        enabledMarkets.setValue(sender.state == NSOnState, forKey: market.name)
        self.setStorage("preferencesEnabledMarkets", enabledMarkets)
        
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
            alert.icon = NSImage(named: "donation")
            alert.informativeText = message
            alert.addButton(withTitle: NSLocalizedString("button.close", comment:""))
            
            if (self.preferencesWindow.isVisible == true) {
                alert.beginSheetModal(for: self.preferencesWindow, completionHandler: {
                    (selected) -> Void in
                    
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
                })
            } else {
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
    }
    
    /**
     * Cost changed notification
     *
     * @param Coin coin
     * @param String price
     * @return nil
     */
    func showCostNotification(_ coin:Coin, _ price: String) {
        let notification = NSUserNotification()
        notification.title = NSLocalizedString("notification.cost.title", comment: "").replacingOccurrences(of: "{COIN}", with: coin.name)
        notification.subtitle = price
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    /**
     * Get value in storage for key
     */
    func getStorage(_ key: String) -> Any? {
        return self.preferences.object(forKey: key)
    }
    
    /**
     * Set value in storage for key
     */
    func setStorage(_ key:String, _ value: Any) {
        self.preferences.set(value, forKey: key)
        self.preferences.synchronize()
    }
    
    @IBAction func openUrl(_ sender: AnyObject) {
        NSWorkspace.shared().open(URL(string: "https://github.com/moimz/iCoinTicker/issues")!)
    }
}

/**
 * NSTextField with Keyboard short
 */
class NSTableViewWithShortcut: NSTableView {
    private let commandKey = NSEventModifierFlags.command.rawValue
    private let commandShiftKey = NSEventModifierFlags.command.rawValue | NSEventModifierFlags.shift.rawValue
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if (event.type == NSEventType.keyDown) {
            if ((event.modifierFlags.rawValue & NSEventModifierFlags.deviceIndependentFlagsMask.rawValue) == commandKey) {
                switch (event.keyCode) {
                    case 0x00 :
                        self.selectAll(nil)
                        return true
                    
                    default :
                        break
                }
            } else {
                switch (event.keyCode) {
                    case 0x33 :
                        let appDelegate = NSApplication.shared().delegate as! AppDelegate
                        if (self.selectedRowIndexes.count > 0) {
                            appDelegate.removeNotifications(self)
                            return true
                        }
                        break
                    
                    case 0x24 :
                        if (self.selectedRowIndexes.count == 1) {
                            let appDelegate = NSApplication.shared().delegate as! AppDelegate
                            appDelegate.openNotificationEditSheet(self.selectedRowIndexes)
                            return true
                        }
                        break
                    
                    default :
                        break
                }
            }
        }
        
        return super.performKeyEquivalent(with: event)
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
                switch (event.keyCode) {
                    case 0x07 :
                        if NSApp.sendAction(#selector(NSText.cut(_:)), to:nil, from:self) { return true }
                        
                    case 0x08 :
                        if NSApp.sendAction(#selector(NSText.copy(_:)), to:nil, from:self) { return true }
                    
                    case 0x09 :
                        if NSApp.sendAction(#selector(NSText.paste(_:)), to:nil, from:self) { return true }
                    
                    case 0x00 :
                        if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to:nil, from:self) { return true }
                    
                    default :
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
        } else if (tableView.identifier == "notifications") {
            return self.notifications.count
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
                title.append(NSAttributedString(string: coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 12.0)!]))
                title.append(NSAttributedString(string: " " + coin.unit, attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 13.0), NSBaselineOffsetAttributeName: -1.5]))
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
        } else if (tableView.identifier == "notifications") {
            let cell: NSTableCellView = tableView.make(withIdentifier:(tableColumn?.identifier)!, owner: self) as! NSTableCellView
            let notification: NotificationSetting = NotificationSetting(self.notifications[row])
            
            if (tableColumn?.identifier == "coin") {
                let title = NSMutableAttributedString(string: "")
                title.append(NSAttributedString(string: notification.coin.mark, attributes: [NSFontAttributeName: NSFont(name: "cryptocoins-icons", size: 12.0)!]))
                title.append(NSAttributedString(string: " " + notification.coin.unit, attributes: [NSFontAttributeName: NSFont.systemFont(ofSize: 13.0), NSBaselineOffsetAttributeName: -1.5]))
                
                cell.textField?.attributedStringValue = title
            }
            
            if (tableColumn?.identifier == "market") {
                cell.textField?.stringValue = notification.market.name
            }
            
            if (tableColumn?.identifier == "rule") {
                let numberFormatter = NumberFormatter()
                numberFormatter.format = notification.currency.format
                
                cell.textField?.stringValue = notification.rule + " " + notification.currency.code + " " + numberFormatter.string(from: NSNumber(value: notification.price))!
            }
            
            if (tableColumn?.identifier == "status") {
                cell.textField?.stringValue = notification.enabled == true ? (notification.repeated == true ? NSLocalizedString("preferences.notification.status.repeated", comment: "") : NSLocalizedString("preferences.notification.status.enabled", comment: "")) : NSLocalizedString("preferences.notification.status.disabled", comment: "")
            }
            
            return cell
        }
        
        return nil
    }
}
