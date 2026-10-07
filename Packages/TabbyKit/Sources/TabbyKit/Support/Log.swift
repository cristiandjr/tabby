import OSLog

public enum Log {
    public static let subsystem = "io.github.cristiandjr.tabby"

    public static func logger(_ category: String, subsystem: String = Log.subsystem) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
