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

    private static let unavailableArchiveDateRanges = [
        ("2011-01-28", "2011-02-01"),
        ("2011-02-09", "2011-02-09"),
        ("2011-02-12", "2011-02-12"),
        ("2011-03-08", "2011-03-08"),
        ("2011-04-01", "2011-04-02"),
        ("2011-04-05", "2011-04-05"),
        ("2011-04-12", "2011-04-12"),
        ("2011-04-15", "2011-04-15"),
        ("2011-04-22", "2011-04-22"),
        ("2011-04-26", "2011-04-26"),
        ("2011-04-28", "2011-04-28"),
        ("2011-05-07", "2011-05-07"),
        ("2011-05-11", "2011-05-12"),
        ("2011-05-15", "2011-05-24"),
        ("2011-05-27", "2011-05-27"),
        ("2011-06-02", "2011-06-30"),
        ("2011-07-29", "2011-08-04"),
        ("2011-08-06", "2011-08-08"),
        ("2011-08-11", "2011-08-13"),
        ("2011-08-20", "2011-08-21"),
        ("2011-08-23", "2011-08-24"),
        ("2011-08-26", "2011-08-27"),
        ("2011-08-29", "2011-08-31"),
        ("2011-09-02", "2011-09-03"),
        ("2011-09-20", "2011-09-21"),
        ("2011-09-24", "2011-09-25"),
        ("2011-09-30", "2011-10-05"),
        ("2011-10-09", "2011-10-13"),
        ("2011-10-30", "2011-10-30"),
        ("2011-11-02", "2011-11-02"),
        ("2011-11-07", "2011-11-09"),
        ("2011-11-12", "2011-11-12"),
        ("2011-11-19", "2011-11-25"),
        ("2011-11-27", "2011-12-02"),
        ("2011-12-05", "2012-01-01"),
        ("2012-01-20", "2012-01-21"),
        ("2012-01-27", "2012-01-29"),
        ("2012-02-01", "2012-02-07"),
        ("2012-02-10", "2012-02-11"),
        ("2012-02-13", "2012-02-13"),
        ("2012-02-15", "2012-02-15"),
        ("2012-02-17", "2012-02-18"),
        ("2012-02-20", "2012-03-08"),
        ("2012-03-17", "2012-04-15"),
        ("2012-04-20", "2012-04-26"),
        ("2012-05-04", "2012-07-22"),
        ("2012-07-30", "2012-10-25"),
        ("2012-11-02", "2012-11-22"),
        ("2012-11-29", "2012-11-29"),
        ("2012-12-01", "2012-12-02"),
        ("2012-12-09", "2012-12-14"),
        ("2012-12-17", "2012-12-22"),
        ("2012-12-25", "2012-12-25"),
        ("2012-12-27", "2013-01-03"),
        ("2013-01-12", "2013-02-22"),
        ("2013-03-14", "2013-03-15"),
        ("2013-03-20", "2013-04-18"),
        ("2013-05-16", "2013-05-21"),
        ("2013-05-23", "2013-06-22"),
        ("2013-07-09", "2014-04-30"),
        ("2014-05-26", "2014-05-31"),
        ("2014-07-03", "2014-10-04"),
        ("2014-10-28", "2014-12-23"),
        ("2015-02-09", "2015-07-02"),
        ("2015-07-04", "2015-07-21"),
        ("2015-08-29", "2015-11-08")
    ]

    private static func inputFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private static func archiveDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private static func archiveMonthFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private static func archiveYearFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    private static func isUnavailableArchiveDate(_ date: Date) -> Bool {
        let inputFormatter = inputFormatter()

        for (startDate, endDate) in unavailableArchiveDateRanges {
            let start = inputFormatter.date(from: startDate)!
            let end = inputFormatter.date(from: endDate)!
            if date >= start && date <= end {
                return true
            }
        }

        return false
    }

    private static func archiveDate() throws -> Date {
        let startDate = "2010-11-08"
        let endDate = "2015-11-08"

        let inputFormatter = inputFormatter()
        let start = inputFormatter.date(from: startDate)!
        let end = inputFormatter.date(from: endDate)!
        let totalDays = Calendar.current.dateComponents([.day], from: start, to: end).day! + 1
        let availableDates = (0..<totalDays).compactMap { offset -> Date? in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: start),
                  !isUnavailableArchiveDate(date) else {
                return nil
            }

            return date
        }
        let today = Calendar.current.startOfDay(for: Date())
        let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: today).day!
        let dayOffset = ((daysSinceStart % availableDates.count) + availableDates.count) % availableDates.count

        return availableDates[dayOffset]
    }

    static func fetchSource() async throws -> (String, String, String, String) {
        let monthFormatter = archiveMonthFormatter()
        let yearFormatter = archiveYearFormatter()
        let dayFormatter = archiveDayFormatter()
        let configuration = URLSessionConfiguration.ephemeral
        let date = try archiveDate()

        let month = monthFormatter.string(from: date)
        let year = yearFormatter.string(from: date)
        let archiveDay = dayFormatter.string(from: date)
        let url = URL(string: "https://www.deutsched.com/Features/dailyWord.php?month=\(month)&year=\(year)")!
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

        let rawWord = String(body[wordRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = String(body[translationRange]).capitalizingFirstLetter()
        let sentenceGerman = String(body[sentenceGermanRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceEnglish = String(body[sentenceEnglishRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let examples = "\(sentenceGerman)\n\(sentenceEnglish)"
        let lowercaseWord = rawWord.lowercased()
        let word = rawWord.replacingOccurrences(
            of: #"\s+\((?:v|adj|adv)\.\)$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        let type: String
        if lowercaseWord.hasPrefix("der ") || lowercaseWord.hasPrefix("die ") || lowercaseWord.hasPrefix("das ") {
            type = "Noun"
        } else if lowercaseWord.contains("(v.)") {
            type = "Verb"
        } else if lowercaseWord.contains("(adj.)") {
            type = "Adjective"
        } else if lowercaseWord.contains("(adv.)") {
            type = "Adverb"
        } else {
            type = ""
        }

        return (word, translation, type, examples)
    }
}
