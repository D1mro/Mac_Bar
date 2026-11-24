import Foundation

/// Текущая погода (температура + описание) — Open-Meteo, без ключа.
@MainActor
@Observable
final class WeatherService {
    static let shared = WeatherService()

    /// Ключ города в UserDefaults (поле «Город» в настройках).
    static let cityKey = "weatherCity"

    private(set) var temperature: Double?
    private(set) var weatherDescription: String?

    /// Обновить погоду: геокодинг города + текущая температура.
    func update() {
        Task { [weak self] in
            guard let city = UserDefaults.standard.string(forKey: Self.cityKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !city.isEmpty,
                  let coords = await Self.geocode(city)
            else {
                self?.temperature = nil
                self?.weatherDescription = nil
                return
            }
            let current = await Self.currentWeather(coords)
            self?.temperature = current?.temperature
            self?.weatherDescription = current.map(Self.description(of:))
        }
    }

    // MARK: - Open-Meteo

    private struct GeocodeResult: Decodable {
        let latitude: Double
        let longitude: Double
    }

    private struct GeocodeResponse: Decodable {
        let results: [GeocodeResult]?
    }

    private struct CurrentWeather: Decodable {
        let temperature: Double?
        let weathercode: Int?
    }

    private struct ForecastResponse: Decodable {
        let current_weather: CurrentWeather?
    }

    private static func geocode(_ city: String) async -> (Double, Double)? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [URLQueryItem(name: "name", value: city),
                                 URLQueryItem(name: "count", value: "1")]
        let response: GeocodeResponse? = await request(components.url)
        guard let result = response?.results?.first else { return nil }
        return (result.latitude, result.longitude)
    }

    private static func currentWeather(_ coords: (Double, Double)) async -> CurrentWeather? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coords.0)),
            URLQueryItem(name: "longitude", value: String(coords.1)),
            URLQueryItem(name: "current_weather", value: "true"),
        ]
        let response: ForecastResponse? = await request(components.url)
        return response?.current_weather
    }

    private static func request<T: Decodable>(_ url: URL?) async -> T? {
        guard let url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Isle/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Описание погоды по коду Open-Meteo (WMO).
    private static func description(of weather: CurrentWeather) -> String {
        switch weather.weathercode ?? 0 {
        case 0: String(localized: "Ясно")
        case 1, 2, 3: String(localized: "Облачно")
        case 45, 48: String(localized: "Туман")
        case 51, 53, 55, 56, 57: String(localized: "Морось")
        case 61, 63, 65: String(localized: "Дождь")
        case 66, 67: String(localized: "Заморозки")
        case 71, 73, 75: String(localized: "Снег")
        case 77: String(localized: "Снегопад")
        case 80, 81, 82: String(localized: "Ливерная дождь")
        case 85, 86: String(localized: "Снегопад")
        case 95, 96, 99: String(localized: "Гроза")
        default: String(localized: "Погода")
        }
    }
}
