import Foundation

/// Checks for real, legitimate update sources: Apple's own Software Update (which is
/// also how macOS delivers hardware driver updates — there is no separate third-party
/// path for that on Mac) and, if present, outdated Homebrew packages.
final class SoftwareUpdateService {
    static let shared = SoftwareUpdateService()

    func checkAll(completion: @escaping ([UpdateItem]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [UpdateItem] = []
            results.append(contentsOf: self.checkMacOSUpdates())
            results.append(contentsOf: self.checkHomebrewUpdates())
            DispatchQueue.main.async { completion(results) }
        }
    }

    private func run(_ path: String, _ args: [String]) -> String {
        guard FileManager.default.fileExists(atPath: path) else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Runs `softwareupdate -l`, Apple's own command-line updater. This is the real
    /// mechanism macOS uses to ship driver/firmware updates, since they're bundled
    /// into the OS rather than distributed separately.
    private func checkMacOSUpdates() -> [UpdateItem] {
        let output = run("/usr/sbin/softwareupdate", ["-l"])
        var items: [UpdateItem] = []
        for rawLine in output.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("* Label:") || line.hasPrefix("- Label:") else { continue }
            let label = line
                .replacingOccurrences(of: "* Label:", with: "")
                .replacingOccurrences(of: "- Label:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !label.isEmpty {
                items.append(UpdateItem(name: label, detail: "Available from Apple Software Update", source: .macOS))
            }
        }
        return items
    }

    private func checkHomebrewUpdates() -> [UpdateItem] {
        let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        guard let brew = brewPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return [] }
        let output = run(brew, ["outdated"])
        return output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { UpdateItem(name: $0, detail: "Outdated Homebrew package", source: .homebrew) }
    }
}
