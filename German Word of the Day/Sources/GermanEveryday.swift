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

        let xml = String(data: data, encoding: .utf8) ?? ""
        let doc: Document = try SwiftSoup.parse(xml)
        let bodyPattern = #"<content:encoded><!\[CDATA\[(.*?)\]\]></content:encoded>"#
        let bodyRegex = try? NSRegularExpression(pattern: bodyPattern, options: [.dotMatchesLineSeparators])
        let bodyMatch = bodyRegex?.firstMatch(in: xml, options: [], range: NSRange(location: 0, length: xml.utf16.count))
        let bodyHTML = bodyMatch.flatMap { Range($0.range(at: 1), in: xml).map { String(xml[$0]) } } ?? ""
        let body: String = bodyHTML.isEmpty ? try doc.select("item description")[0].text() : try SwiftSoup.parseBodyFragment(bodyHTML).text()
        let partOfSpeech: String = try doc.select("item category")[0].text().lowercased()
        
        let pattern = "<p>(.*?) : (.*?)</p>.*?<p>(.*?)</p>.*?<p>(.*?)</em></p>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let fallbackPattern = #"^\s*(.+?)\s+([„"“‚']?[A-ZÄÖÜ][^)\s.!?]*\s+[a-zäöüß].+?[.!?])\s*([A-Z"“].+?)\s*$"#
        let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern)
        
        let word: String = try doc.select("item title")[0].text()
        var translation: String = ""
        var sentenceGerman: String = ""
        var sentenceEnglish: String = ""
        if let match = regex?.firstMatch(in: bodyHTML, options: [], range: NSRange(location: 0, length: bodyHTML.utf16.count)) {
            if let translationRange = Range(match.range(at: 2), in: bodyHTML) {
                translation = String(bodyHTML[translationRange]).capitalizingFirstLetter()
            }
            
            if let sentenceGermanRange = Range(match.range(at: 3), in: bodyHTML) {
                sentenceGerman = String(bodyHTML[sentenceGermanRange])
            }
            
            if let sentenceEnglishRange = Range(match.range(at: 4), in: bodyHTML) {
                sentenceEnglish = String(bodyHTML[sentenceEnglishRange])
            }
        } else {
            let bodyWithoutWordPrefix: String
            if body.hasPrefix("\(word) : ") {
                bodyWithoutWordPrefix = String(body.dropFirst(word.count + 3))
            } else {
                bodyWithoutWordPrefix = body
            }
            
            if let match = fallbackRegex?.firstMatch(in: bodyWithoutWordPrefix, options: [], range: NSRange(location: 0, length: bodyWithoutWordPrefix.utf16.count)) {
                if let translationRange = Range(match.range(at: 1), in: bodyWithoutWordPrefix) {
                    translation = String(bodyWithoutWordPrefix[translationRange]).capitalizingFirstLetter()
                }
                
                if let sentenceGermanRange = Range(match.range(at: 2), in: bodyWithoutWordPrefix) {
                    sentenceGerman = String(bodyWithoutWordPrefix[sentenceGermanRange])
                }
                
                if let sentenceEnglishRange = Range(match.range(at: 3), in: bodyWithoutWordPrefix) {
                    sentenceEnglish = String(bodyWithoutWordPrefix[sentenceEnglishRange])
                }
            } else if bodyWithoutWordPrefix != body {
                translation = bodyWithoutWordPrefix.capitalizingFirstLetter()
            }
        }
        
        let type = partOfSpeech.capitalizingFirstLetter()
        let examples = "\(sentenceGerman)\n\(sentenceEnglish)"
        
        return (word, translation, type, examples)
    }
}
