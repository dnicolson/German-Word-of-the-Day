//
//  AppDelegate.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 01.10.22.
//

import Cocoa
import LaunchAtLogin

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

extension NSAttributedString {
    func height(withWidth width: CGFloat) -> CGFloat {
        let height = boundingRect(
            with: CGSize(width: width, height: CGFloat(MAXFLOAT)),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil).size.height

        return ceil(height)
    }
}

protocol Source {
    static var name: String { get }
    static func fetchSource() async throws -> (String, String, String, String)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusItem: NSStatusItem!
    var definitionMenuItem: NSMenuItem!
    var activeSource: String!
    var timer = Timer()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🇩🇪"
        }
        
        if (UserDefaults.standard.array(forKey: "Sources") == nil) {
            var sources: [[String: AnyObject]] = []
            for source in getSources() {
                sources.append(["name": source, "state": true] as [String: AnyObject])
            }
            UserDefaults.standard.set(sources, forKey: "Sources")
        }

        cycleSource()
        updateSource()

        setupMenus()
        
        DistributedNotificationCenter.default.addObserver(self, selector: #selector(interfaceModeChanged(sender:)), name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"), object: nil)
    }
    
    @objc func interfaceModeChanged(sender: NSNotification) {
        updateSource()
    }
    
    func getSources() -> [String] {
        let expectedClassCount = objc_getClassList(nil, 0)
        let allClasses = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(expectedClassCount))
        let autoreleasingAllClasses = AutoreleasingUnsafeMutablePointer<AnyClass>(allClasses)
        let actualClassCount:Int32 = objc_getClassList(autoreleasingAllClasses, expectedClassCount)

        var classes = [AnyClass]()
        for i in 0 ..< actualClassCount {
            let currentClass: AnyClass = allClasses[Int(i)]
            if currentClass.self is Source.Type {
                classes.append(currentClass)
            }
        }

        return classes.map { ($0 as! Source.Type).name }
    }
    
    func cycleSource() {
        let sources = (UserDefaults.standard.array(forKey: "Sources") as? [[String: Any]])!.filter() { $0["state"] as! Bool == true }
        if sources.count == 0 {
            return
        }
        
        if activeSource == nil || sources.count == 1 {
            activeSource = sources[0]["name"] as? String
        } else {
            if let index = sources.firstIndex(where: {$0["name"] as? String == activeSource}) {
                if (index + 1 == sources.count) {
                    activeSource = sources[0]["name"] as? String
                } else {
                    activeSource = sources[index + 1]["name"] as? String
                }
            }
        }
    }

    func updateSource() {
        if activeSource == nil, let menuItem = definitionMenuItem, let button = statusItem.button {
            button.title = "🇩🇪"
            menuItem.title = ""
            menuItem.view = nil
            return
        }
        
        timer.invalidate()

        let moduleName = Bundle.main.infoDictionary!["CFBundleName"] as! String
        let className = moduleName.replacingOccurrences(of: " ", with: "_") + "." + self.activeSource.replacingOccurrences(of: " ", with: "")
        let sourceClass: Source.Type = NSClassFromString(className) as! Source.Type

        Task {
            let (word, translation, type, examples) = await {
                do {
                    return try await sourceClass.fetchSource()
                } catch {
                    print("Request failed with error: \(error)")
                    return ("⚠️", error.localizedDescription, "", "")
                }
            }()

            DispatchQueue.main.async { [self] in
                updateDefinition(word: word, translation: translation, type: type, examples: examples)
                let interval: TimeInterval = word == "⚠️" ? 10 : 60 * 60
                timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [self] _ in
                    cycleSource()
                    updateSource()
                }
            }
        }
    }
    
    func updateDefinition(word: String, translation: String, type: String, examples: String) {
        if let button = statusItem.button {
            button.title = word
        }
        if let menuItem = definitionMenuItem {
            menuItem.view = definitionView(translation: translation, type: type, examples: examples)
        }
    }
    
    func definitionView(translation: String, type: String, examples: String) -> NSView {
        var textColor: String, secondaryTextColor: String
        if NSApp.effectiveAppearance.name == NSAppearance.Name.darkAqua {
            textColor = "rgba(255,255,255,1)"
            secondaryTextColor = "rgba(255,255,255,0.5)"
        } else {
            textColor = "rgba(0,0,0,1)"
            secondaryTextColor = "rgba(0,0,0,0.5)"
        }

        let html = """
<style>
a {text-decoration: none !important;}
* {font-family:system-ui;padding:0;}
.word {color:\(textColor);font-size:13px;padding:6px 0;max-width:150px;}
.type {color:\(secondaryTextColor);font-size:13px;padding:6px 0;vertical-align:top;}
.examples {color:\(textColor);font-size:12px;}
.examples p {margin-bottom:6px;}
.source {color:\(secondaryTextColor);font-size:11px;padding-top:6px;padding-right:13px;}
</style>
<table width="100%">
  <tr>
    <td align="left" class="word">\(translation)</td>
    <td align="right" class="type">\(type)</td>
  </tr>
  <tr>
    <td colspan="2" class="examples"><p>\(examples.replacingOccurrences(of: "\n\n", with: "</p><p>").replacingOccurrences(of: "\n", with: "<br>"))</p></td>
  </tr>
  <tr>
    <td colspan="2" align="right" class="source">\(activeSource!)</td>
  </tr>
</table>
"""
        
        let data = Data(html.utf8)
        let definition = try! NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: NSNumber(value: String.Encoding.utf8.rawValue)], documentAttributes: nil)

        let width = 300;
        let height = Int(definition.height(withWidth: CGFloat(width - 28)))
        let frameRect = NSRect(x: 14, y: -12, width: width - 28, height: height)
        let textView = NSTextView(frame: frameRect)
        textView.textStorage?.setAttributedString(definition)
        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        
        let view = NSView()
        view.frame = CGRect(x: 0, y: 0, width: width, height: height - 12)
        view.addSubview(textView)

        let button = NSButton(frame: CGRect(x: width - 24, y: 5, width: 10, height: 10))
        button.target = self
        button.title = "↻"
        button.isBordered = false
        button.action = #selector(cycleButton)
        view.addSubview(button)
        
        return view
    }
    
    @objc func cycleButton(_ sender: NSButton) {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = CGFloat.pi * 2
        animation.toValue = 0
        animation.duration = 1
        animation.repeatCount = Float.infinity
        sender.layer?.position = NSPoint(x: NSMidX(sender.frame), y: NSMidY(sender.frame))
        sender.layer?.anchorPoint = NSPoint(x: 0.5, y: 0.5)
        sender.layer?.add(animation, forKey: "rotate")

        cycleSource()
        updateSource()
     }
    
    func setupMenus() {
        let menu = NSMenu()
                
        definitionMenuItem = NSMenuItem()
        definitionMenuItem.title = ""
        menu.addItem(definitionMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let sources = NSMenuItem(title: "Sources", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for source in (UserDefaults.standard.array(forKey: "Sources") as? [[String: Any]])! {
            let sourceMenu = NSMenuItem(title: source["name"] as! String, action: #selector(didSelectSource), keyEquivalent: "")
            sourceMenu.state = source["state"] as! NSControl.StateValue
            submenu.addItem(sourceMenu)
        }
        sources.submenu = submenu
        menu.addItem(sources)

        let openAtLogin = NSMenuItem(title: "Open at Login", action: #selector(didSelectOpenAtLogin), keyEquivalent: "")
        openAtLogin.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(openAtLogin)
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func didSelectOpenAtLogin(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        LaunchAtLogin.isEnabled = sender.state == .on
    }
    
    @objc func didSelectSource(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on

        if var sources = UserDefaults.standard.array(forKey: "Sources") as? [[String: Any]] {
            for index in 0..<sources.count {
                if sources[index]["name"] as! String == sender.title {
                    sources[index]["state"] = sender.state
                }
            }
            UserDefaults.standard.set(sources, forKey: "Sources")
        }

        activeSource = nil
        cycleSource()
        updateSource()
    }
}
