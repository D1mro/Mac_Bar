import Foundation

/// Обёртка над ungive/mediaremote-adapter.
/// С macOS 15.4 MediaRemote закрыт для обычных приложений, но системный
/// `/usr/bin/perl` доступ имеет — поэтому запускаем скрипт адаптера через него.
final class MediaRemoteAdapter: @unchecked Sendable {
    private let scriptPath: String
    private let frameworkPath: String
    private var streamProcess: Process?

    /// `nil`, если в приложении нет скрипта или фреймворка.
    init?() {
        guard let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
              let frameworks = Bundle.main.privateFrameworksPath
        else { return nil }
        let framework = frameworks + "/MediaRemoteAdapter.framework"
        guard FileManager.default.fileExists(atPath: framework) else { return nil }
        scriptPath = script
        frameworkPath = framework
    }

    /// Поток обновлений: каждая строка stdout — один JSON.
    /// `onExit` получает код выхода (не 0 — адаптер сломан, перезапускать нельзя).
    func startStream(onLine: @escaping @Sendable (Data) -> Void,
                     onExit: @escaping @Sendable (Int32) -> Void) {
        let process = makeProcess(["stream", "--micros", "--debounce=50"])
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let buffer = LineBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            for line in buffer.append(data) { onLine(line) }
        }
        process.terminationHandler = { process in onExit(process.terminationStatus) }

        do {
            try process.run()
            streamProcess = process
        } catch {
            onExit(-1)
        }
    }

    func stopStream() {
        streamProcess?.terminate()
        streamProcess = nil
    }

    /// Разовая команда: `send 2`, `seek 30000000` и т.п.
    func run(_ arguments: [String]) {
        let process = makeProcess(arguments)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    private func makeProcess(_ arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptPath, frameworkPath] + arguments
        return process
    }
}

/// Собирает куски stdout в целые строки (обложка в base64 приходит частями).
private final class LineBuffer: @unchecked Sendable {
    private var data = Data()

    func append(_ chunk: Data) -> [Data] {
        data.append(chunk)
        var lines: [Data] = []
        while let newline = data.firstIndex(of: 0x0A) {
            let line = data[data.startIndex..<newline]
            if !line.isEmpty { lines.append(Data(line)) }
            data.removeSubrange(data.startIndex...newline)
        }
        return lines
    }
}
