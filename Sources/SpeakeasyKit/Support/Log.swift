import os

enum Log {
    static let subsystem = "com.harshshelar.speakeasy"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let sections = Logger(subsystem: subsystem, category: "sections")
    static let discovery = Logger(subsystem: subsystem, category: "discovery")
    static let mover = Logger(subsystem: subsystem, category: "mover")
    static let rules = Logger(subsystem: subsystem, category: "rules")
    static let settings = Logger(subsystem: subsystem, category: "settings")
}
