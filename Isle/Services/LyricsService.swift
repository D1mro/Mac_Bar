import CryptoKit
import Foundation
import Observation

/// Строка синхронизированного текста.
struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let time: TimeInterval
    let text: String
}

/// Тексты песен с lrclib.net (бесплатно, без ключа) + кэш на диске.
@MainActor
@Observable
final class LyricsService {
    enum State: Equatable, Sendable {
        case idle
        case loading
        case synced([LyricLine])   // с таймкодами — подсвечиваем текущую строку
        case plain(String)         // просто текст
        case notFound
    }

    static let shared = LyricsService()

    private(set) var state: State = .idle

    @ObservationIgnored private var currentKey = ""
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Загрузить текст для трека (повторный вызов для того же трека ничего не делает).
    func load(title: String, artist: String, duration: TimeInterval) {
        let key = "\(artist)\u{1F}\(title)".lowercased()
        guard key != currentKey else { return }
        currentKey = key
        task?.cancel()

        guard !title.isEmpty else {
            state = .idle
            return
        }
        state = .loading
        task = Task {
            let result = await Self.fetch(title: title, artist: artist, duration: duration, key: key)
            guard !Task.isCancelled else { return }
            state = result
        }
    }

    // MARK: - Загрузка (не на главном потоке)

    private struct Cached: Codable {
        let synced: String?
        let plain: String?
    }

    private struct Response: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    nonisolated private static func fetch(title: String, artist: String,
                                          duration: TimeInterval, key: String) async -> State {
        let cacheURL = cacheDirectory.appendingPathComponent(sha256(key) + ".json")
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode(Cached.self, from: data) {
            return state(from: cached)
        }

        // 1. Точный запрос по исполнителю, названию и длительности.
        var exact = URLComponents(string: "https://lrclib.net/api/get")!
        exact.queryItems = [URLQueryItem(name: "artist_name", value: artist),
                            URLQueryItem(name: "track_name", value: title)]
        if duration > 0 {
            exact.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        var found: Response? = await request(exact.url!)

        // 2. Не нашли — поиск, берём первый результат с текстом (лучше с таймкодами).
        if found?.syncedLyrics == nil, found?.plainLyrics == nil {
            var search = URLComponents(string: "https://lrclib.net/api/search")!
            search.queryItems = [URLQueryItem(name: "artist_name", value: artist),
                                 URLQueryItem(name: "track_name", value: title)]
            let results: [Response] = await request(search.url!) ?? []
            found = results.first { $0.syncedLyrics != nil } ?? results.first { $0.plainLyrics != nil }
        }

        let cached = Cached(synced: found?.syncedLyrics, plain: found?.plainLyrics)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(cached).write(to: cacheURL)
        return state(from: cached)
    }

    nonisolated private static func request<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Isle/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    nonisolated private static func state(from cached: Cached) -> State {
        if let synced = cached.synced {
            let lines = parseLRC(synced)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = cached.plain, !plain.isEmpty { return .plain(plain) }
        return .notFound
    }

    /// Разбор LRC: «[01:23.45] текст». У строки может быть несколько таймкодов.
    nonisolated static func parseLRC(_ text: String) -> [LyricLine] {
        let regex = /\[(\d+):(\d+(?:\.\d+)?)\]/
        var entries: [(TimeInterval, String)] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let matches = line.matches(of: regex)
            guard let last = matches.last else { continue }
            let lyric = String(line[last.range.upperBound...]).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let time = (Double(match.output.1) ?? 0) * 60 + (Double(match.output.2) ?? 0)
                entries.append((time, lyric))
            }
        }
        return entries
            .sorted { $0.0 < $1.0 }
            .enumerated()
            .map { LyricLine(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }

    nonisolated private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Isle/Lyrics", isDirectory: true)
    }

    nonisolated private static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
