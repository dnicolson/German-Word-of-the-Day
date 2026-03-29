//
//  Deutsched.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 29.03.26.
//

import Foundation
import SwiftSoup

class Deutsched: Source {
    static var name: String = "Deutsched"
    
    private static func archiveDate() throws -> Date {
        let startDate = "2010-11-08"
        let endDate = "2015-11-08"
        
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
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "M"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM dd, yyyy"
        
        let month = monthFormatter.string(from: date)
        let year = yearFormatter.string(from: date)
        let archiveDay = dayFormatter.string(from: date)
        let url = URL(string: "https://www.deutsched.com/Features/dailyWord.php?month=\(month)&year=\(year)")!
        
        let configuration = URLSessionConfiguration.ephemeral
        let (data, _) = try await URLSession(configuration: configuration).data(from: url)
        
        let doc = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
        let body = try doc.text()
        let escapedDate = NSRegularExpression.escapedPattern(for: archiveDay)
        let pattern = #"(?s)\b\#(escapedDate)\b\s+(.+?)\s+-\s+(.+?)\s+(.+?)\s+-\s+(.+?)(?=\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{2},\s+\d{4}\b|\s+Archives\b|$)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(body.startIndex..., in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let wordRange = Range(match.range(at: 1), in: body),
              let translationRange = Range(match.range(at: 2), in: body),
              let sentenceGermanRange = Range(match.range(at: 3), in: body),
              let sentenceEnglishRange = Range(match.range(at: 4), in: body) else {
            throw NSError(domain: "Deutsched", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not parse Deutsched archive entry for \(archiveDay)."])
        }
        
        let word = String(body[wordRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = String(body[translationRange]).capitalizingFirstLetter()
        let sentenceGerman = String(body[sentenceGermanRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceEnglish = String(body[sentenceEnglishRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let examples = "\(sentenceGerman)\n\(sentenceEnglish)"
        let lowercaseWord = word.lowercased()
        
        let type: String
        if lowercaseWord.hasPrefix("der ") || lowercaseWord.hasPrefix("die ") || lowercaseWord.hasPrefix("das ") {
            type = "Noun"
        } else if word.contains("(v.)") {
            type = "Verb"
        } else if word.contains("(adj.)") {
            type = "Adjective"
        } else if word.contains("(adv.)") {
            type = "Adverb"
        } else {
            type = ""
        }
        
        return (word, translation, type, examples)
    }
}
