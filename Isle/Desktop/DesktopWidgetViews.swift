import SwiftUI

/// Общий фон виджета на рабочем столе.
private struct WidgetBox<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

/// Часы с датой.
struct ClockWidgetView: View {
    var body: some View {
        WidgetBox {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 1) {
                    Text(context.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Text(context.date.formatted(date: .omitted, time: .standard))
                        .font(.system(size: 21, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

/// Что сейчас играет.
struct MusicWidgetView: View {
    @State private var player = NowPlayingService.shared

    var body: some View {
        WidgetBox {
            if player.hasMedia {
                HStack(spacing: 8) {
                    if let artwork = player.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(player.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            } else {
                Label(String(localized: "Ничего не играет"), systemImage: "music.note")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

/// Погода в выбранном городе.
struct WeatherWidgetView: View {
    @State private var weather = WeatherService.shared

    var body: some View {
        WidgetBox {
            if let temperature = weather.temperature {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.0f°C", temperature))
                            .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(weather.weatherDescription ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            } else {
                Label(String(localized: "Погода недоступна"), systemImage: "thermometer")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}
