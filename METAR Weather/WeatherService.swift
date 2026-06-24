import Foundation

// MARK: - Networking Service

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case dataError
}

class WeatherService {
    func fetchRawMetars(for icaos: [String]) async throws -> [String: String] {
        guard !icaos.isEmpty else { return [:] }
        
        let idList = icaos.joined(separator: ",")
        
        // Removed the hours=2 as you suggested
        let urlString = "https://aviationweather.gov/api/data/metar?ids=\(idList)&format=raw"
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // 1. FORCE CACHE BUSTING: Ignore Xcode's local cached responses
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // 2. Standard Safari User-Agent to bypass any strict WAF rules
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // 3. Print the status code to the Xcode console
        print("API Response Status: \(httpResponse.statusCode)")
        
        guard let rawText = String(data: data, encoding: .utf8) else {
            throw NetworkError.dataError
        }
        
        // 4. Print the exact string payload to the Xcode console
        print("API Payload:\n\(rawText)")
        
        var metarMap: [String: String] = [:]
                let lines = rawText.components(separatedBy: .newlines)
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Strip out automated prefixes so the line starts with the ICAO code
                    let cleanLine = trimmed
                        .replacingOccurrences(of: "METAR ", with: "")
                        .replacingOccurrences(of: "SPECI ", with: "")
                    
                    if let firstWord = cleanLine.components(separatedBy: .whitespaces).first, icaos.contains(firstWord) {
                        if metarMap[firstWord] == nil {
                            metarMap[firstWord] = cleanLine
                        }
                    }
                }
        
        return metarMap
    }
}
