//
//  main.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 01.10.22.
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
