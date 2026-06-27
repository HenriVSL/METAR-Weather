import Foundation

// MARK: - Networking Service

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case dataError
}

struct AirportInfo {
    let name: String
    let frequencies: [AirportFrequency]
}

class WeatherService {
    func fetchRawMetars(for icaos: [String]) async throws -> [String: String] {
        guard !icaos.isEmpty else { return [:] }
        
        let idList = icaos.joined(separator: ",")
        let urlString = "https://aviationweather.gov/api/data/metar?ids=\(idList)&format=raw"

        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        // Always pull a fresh report rather than a cached response.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // A browser User-Agent avoids the API rejecting the default URLSession one.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard response is HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard let rawText = String(data: data, encoding: .utf8) else {
            throw NetworkError.dataError
        }

        var metarMap: [String: String] = [:]
        for line in rawText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Strip out automated prefixes so the line starts with the ICAO code.
            let cleanLine = trimmed
                .replacingOccurrences(of: "METAR ", with: "")
                .replacingOccurrences(of: "SPECI ", with: "")

            if let firstWord = cleanLine.components(separatedBy: .whitespaces).first,
               icaos.contains(firstWord), metarMap[firstWord] == nil {
                metarMap[firstWord] = cleanLine
            }
        }

        return metarMap
    }

    func fetchAirportInfo(for icaos: [String]) async throws -> [String: AirportInfo] {
        guard !icaos.isEmpty else { return [:] }

        let idList = icaos.joined(separator: ",")
        let urlString = "https://aviationweather.gov/api/data/airport?ids=\(idList)&format=json"

        guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let jsonArray = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
            return [:]
        }

        var result: [String: AirportInfo] = [:]
        for entry in jsonArray {
            guard let icao = entry["icaoId"] as? String,
                  let rawName = entry["name"] as? String else { continue }

            let name = rawName.capitalized

            var freqs: [AirportFrequency] = []
            if let freqString = entry["freqs"] as? String {
                for part in freqString.split(separator: ";") {
                    let components = part.split(separator: ",")
                    if components.count == 2 {
                        freqs.append(AirportFrequency(type: String(components[0]), freq: String(components[1])))
                    }
                }
            }

            result[icao] = AirportInfo(name: name, frequencies: freqs)
        }
        return result
    }
}
