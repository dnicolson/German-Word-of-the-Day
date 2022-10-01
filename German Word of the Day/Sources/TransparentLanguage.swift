//
//  TransparentLanguage.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 02.10.22.
//

import Foundation
import SwiftSoup

class TransparentLanguage: Source {
    static var name: String = "Transparent Language"
    static func fetchSource() async throws -> (String, String, String, String) {
        let url = URL(string: "https://feeds.feedblitz.com/german-word-of-the-day&x=1")
        let configuration = URLSessionConfiguration.ephemeral
        let (data, _) = try await URLSession(configuration: configuration).data(from: url!)
        
        let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
        let cdataTitle: String = try doc.select("title")[1].text()
        let title = cdataTitle.replacingOccurrences(of: "(<\\!\\[CDATA\\[|\\]\\]>)",
                                                    with: "",
                                                    options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let descriptionTable: String = try doc.select("description:eq(1)")[0].text()
        let description: Document = try SwiftSoup.parse(descriptionTable)
        let partOfSpeech: String = try description.select("td")[0].text();
        let exampleSentence: String = try description.select("td")[1].text();
        let sentenceMeaning: String = try description.select("td")[2].text();
        let translationComponents: [String] = title.components(separatedBy: ": ")
        
        let word = translationComponents[0]
        let translation = translationComponents[1].capitalizingFirstLetter()
        let type = partOfSpeech.capitalizingFirstLetter()
        let examples = "\(exampleSentence)\n\(sentenceMeaning)"
        
        return (word, translation, type, examples)
    }
}
