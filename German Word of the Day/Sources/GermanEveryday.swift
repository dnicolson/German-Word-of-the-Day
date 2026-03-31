//
//  GermanEveryday.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 02.10.22.
//

import Foundation
import SwiftSoup

class GermanEveryday: Source {
    static var name: String = "German Everyday"
    
    private static func archiveDate() throws -> Date {
        let startDate = "2011-11-12"
        let endDate = "2026-02-04"
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        let start = inputFormatter.date(from: startDate)!
        let end = inputFormatter.date(from: endDate)!
        let totalDays = Calendar.current.dateComponents([.day], from: start, to: end).day! + 1
        let today = Calendar.current.startOfDay(for: Date())
        let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: today).day!
        let dayOffset = ((daysSinceStart % totalDays) + totalDays) % totalDays
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: start)!
    }

    static func fetchSource() async throws -> (String, String, String, String) {
        let date = try archiveDate()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let archiveDate = formatter.string(from: date)
        let url = URL(string: "https://www.germaneveryday.com/\(archiveDate)/feed/")
        
        let configuration = URLSessionConfiguration.ephemeral
        let (data, _) = try await URLSession(configuration: configuration).data(from: url!)
        
        let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
        let body: String = try doc.select("item")[0].getAllElements()[8].text()
        let partOfSpeech: String = try doc.select("item category")[0].text().lowercased()
        
        let pattern = "<p>(.*?) : (.*?)</p>.*?<p>(.*?)</p>.*?<p>(.*?)</em></p>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let fallbackPattern = #"^\s*(.+)\s+([A-ZÄÖÜ„"“‚'].+?[.!?])\s*([A-Z"“].+?)\s*$"#
        let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: .caseInsensitive)
        
        var word: String = ""
        var translation: String = ""
        var sentenceGerman: String = ""
        var sentenceEnglish: String = ""
        if let match = regex?.firstMatch(in: body, options: [], range: NSRange(location: 0, length: body.utf16.count)) {
            if let wordRange = Range(match.range(at: 1), in: body) {
                word = String(body[wordRange])
            }
            
            if let translationRange = Range(match.range(at: 2), in: body) {
                translation = String(body[translationRange]).capitalizingFirstLetter()
            }
            
            if let sentenceGermanRange = Range(match.range(at: 3), in: body) {
                sentenceGerman = String(body[sentenceGermanRange])
            }
            
            if let sentenceEnglishRange = Range(match.range(at: 4), in: body) {
                sentenceEnglish = String(body[sentenceEnglishRange])
            }
        } else if let match = fallbackRegex?.firstMatch(in: body, options: [], range: NSRange(location: 0, length: body.utf16.count)) {
            if let translationRange = Range(match.range(at: 1), in: body) {
                translation = String(body[translationRange]).capitalizingFirstLetter()
            }
            
            if let sentenceGermanRange = Range(match.range(at: 2), in: body) {
                sentenceGerman = String(body[sentenceGermanRange])
            }
            
            if let sentenceEnglishRange = Range(match.range(at: 3), in: body) {
                sentenceEnglish = String(body[sentenceEnglishRange])
            }
            
            word = try doc.select("item title")[0].text()
        }
        
        let type = partOfSpeech.capitalizingFirstLetter()
        let examples = "\(sentenceGerman)\n\(sentenceEnglish)"
        
        return (word, translation, type, examples)
    }
}
