import AppKit
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") || arguments.contains("-h") {
    print(
        """
        tabby-probe · Spike 0 diagnostics for Tabby

        Usage: tabby-probe [run|auto|demo|check|dump] [--out <directory>]

          run    Guided test (default)
          auto   Automated test: drives Mission Control by itself and verifies the results
          demo   Try Tabby: Tab / ⇧Tab / Return inside Mission Control until Ctrl+C (--selftest drives it once)
          geometry  Sample thumbnail frames while Mission Control opens
          drive  Drive Tabby.app (Mission Control + Tab + Return) and verify the focused window
          check  Print permissions and environment
          dump   Save the Dock accessibility tree while Mission Control is open
        """
    )
    exit(0)
}

let command = arguments.first.flatMap(ProbeCommand.init(rawValue:)) ?? .run
let baseDirectory: URL = {
    if let index = arguments.firstIndex(of: "--out"), arguments.indices.contains(index + 1) {
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("probe-results", isDirectory: true)
}()
let formatter = DateFormatter()
formatter.dateFormat = "yyyyMMdd-HHmmss"
let outputDirectory = baseDirectory.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
if command != .check, command != .demo, command != .geometry, command != .drive {
    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let runner = ProbeRunner(outputDirectory: outputDirectory)
Task { @MainActor in
    let status = await runner.run(command)
    exit(status)
}
application.run()
