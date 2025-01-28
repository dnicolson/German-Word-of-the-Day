//
//  TransparentLanguage.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 02.10.22.
//

import Foundation
import SwiftSoup

class GermanEveryday: Source {
    static var name: String = "German Everyday"
    static func fetchSource() async throws -> (String, String, String, String) {
        let url = URL(string: "https://www.germaneveryday.com/feed/")
        let configuration = URLSessionConfiguration.ephemeral
        let (data, _) = try await URLSession(configuration: configuration).data(from: url!)
        
        let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
        let body: String = try doc.select("item")[0].getAllElements()[8].text()
        let partOfSpeech: String = try doc.select("item category")[0].text().lowercased()
        
        let pattern = "<p>(.*?) : (.*?)</p>.*?<p>(.*?)</p>.*?<p>(.*?)</em></p>"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
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
        }
        
        let type = partOfSpeech.capitalizingFirstLetter()
        let examples = "\(sentenceGerman)\n\(sentenceEnglish)"
        
        return (word, translation, type, examples)
    }
}
