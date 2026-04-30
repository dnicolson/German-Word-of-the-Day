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

    private static func paragraphTexts(from bodyHTML: String) -> [String] {
        let pattern = #"<p(?:>|<em>)(.*?)</p>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let range = NSRange(location: 0, length: bodyHTML.utf16.count)

        return regex?.matches(in: bodyHTML, options: [], range: range).compactMap { match in
            guard let fragmentRange = Range(match.range(at: 1), in: bodyHTML) else {
                return nil
            }

            var fragment = String(bodyHTML[fragmentRange])
            fragment = fragment.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
            fragment = fragment.replacingOccurrences(of: #"</?e>"#, with: "", options: [.regularExpression, .caseInsensitive])

            guard let text = try? SwiftSoup.parseBodyFragment(fragment).text() else {
                return nil
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } ?? []
    }
    
    private static func archiveDate() throws -> Date {
        let startDate = "2011-11-12"
        let endDate = "2026-02-04"
        let ignoredDates: Set<String> = ["2022-09-11", "2023-10-28", "2023-10-29"]
        
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        let start = inputFormatter.date(from: startDate)!
        let end = inputFormatter.date(from: endDate)!
        let totalDays = Calendar.current.dateComponents([.day], from: start, to: end).day! + 1
        let archiveDates = (0..<totalDays).compactMap { offset -> Date? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            return ignoredDates.contains(inputFormatter.string(from: date)) ? nil : date
        }
        guard !archiveDates.isEmpty else {
            throw NSError(domain: "GermanEveryday", code: 1, userInfo: [NSLocalizedDescriptionKey: "No German Everyday archive dates available."])
        }

        let today = Calendar.current.startOfDay(for: Date())
        let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: today).day!
        let dayOffset = ((daysSinceStart % archiveDates.count) + archiveDates.count) % archiveDates.count
        return archiveDates[dayOffset]
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
        
        let fallbackPattern = #"^\s*(.+?)\s+([„"“‚']?[A-ZÄÖÜ][^)\s.!?]*\s+[a-zäöüß].+?[.!?])\s*([A-Z"“].+?)\s*$"#
        let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern)
        
        let word: String = try doc.select("item title")[0].text()
        var translation: String = ""
        var sentenceGerman: String = ""
        var sentenceEnglish: String = ""
        let paragraphs = paragraphTexts(from: bodyHTML)
        if !paragraphs.isEmpty {
            let prefix = "\(word) : "
            let firstParagraph = paragraphs[0]
            translation = firstParagraph.hasPrefix(prefix)
                ? String(firstParagraph.dropFirst(prefix.count)).capitalizingFirstLetter()
                : firstParagraph.capitalizingFirstLetter()

            if paragraphs.count > 1 {
                if paragraphs[1].contains("\n") {
                    let parts = paragraphs[1].split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
                    sentenceGerman = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    sentenceEnglish = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                } else {
                    sentenceGerman = paragraphs[1]
                }
            }

            if sentenceEnglish.isEmpty, paragraphs.count > 2 {
                sentenceEnglish = paragraphs[2].replacingOccurrences(of: #"^\([^)]*\)\s*"#, with: "", options: .regularExpression)
            }
        }

        if translation.isEmpty {
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
