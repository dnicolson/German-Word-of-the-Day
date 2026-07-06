//
//  InnovativeLanguageLearning.swift
//  German Word of the Day
//
//  Created by Dave Nicolson on 02.10.22.
//

import Foundation
import SwiftSoup

class InnovativeLanguageLearning: Source {
    static var name: String = "Innovative Language Learning"
    static func fetchSource() async throws -> (String, String, String, String) {
        let url = URL(string: "https://www.innovativelanguage.com/widgets/wotd/large.php")
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let payload = "language=German&date=".data(using: .utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        let (data, _) = try await session.upload(for: request, from: payload!)
        
        let doc: Document = try SwiftSoup.parse(String(data: data, encoding: .utf8)!)
        let list1: Elements = try doc.select(".wotd-widget-sentence-main-space-text")
        let list1Array: [String?] = list1.array().map { try? $0.text() }
        let list2: Elements = try doc.select(".wotd-widget-sentence-quizmode-space-text")
        let list2Array: [String?] = list2.array().map { try? $0.text() }
        
        let word = list1Array[0]!
        let translation = list2Array[0]!.capitalizingFirstLetter()
        let type = list2Array[1]!.capitalizingFirstLetter()
        var examples = ""

        for (index, sentence) in list1Array[1...].enumerated() {
            examples += "\(sentence!)\n\(list2Array[index + 2]!)"
            if index != list1Array[1...].endIndex - 2 {
                examples += "\n\n"
            }
        }
        
        return (word, translation, type, examples)
    }
}

