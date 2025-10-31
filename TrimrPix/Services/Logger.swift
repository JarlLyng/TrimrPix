//
//  Logger.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import OSLog

/// Log severity levels for application logging
/// Used to categorize log messages by importance and severity
enum LogLevel: String, CaseIterable {
    /// Debug information for development and troubleshooting
    case debug = "DEBUG"
    /// General informational messages about application flow
    case info = "INFO"
    /// Warnings about potentially problematic situations
    case warning = "WARNING"
    /// Error conditions that don't stop the application
    case error = "ERROR"
    /// Critical errors that may cause application failure
    case fault = "FAULT"
}

/// Protocol defining the logging interface
/// Enables dependency injection and testing by allowing mock implementations
protocol LoggerProtocol {
    /// Logs a message with the specified severity level
    /// - Parameters:
    ///   - level: The severity level of the log message
    ///   - message: The message to log
    ///   - file: Source file name (automatically captured)
    ///   - function: Function name (automatically captured)
    ///   - line: Line number (automatically captured)
    func log(_ level: LogLevel, message: String, file: String, function: String, line: Int)
    
    /// Logs a debug-level message
    func debug(_ message: String, file: String, function: String, line: Int)
    
    /// Logs an info-level message
    func info(_ message: String, file: String, function: String, line: Int)
    
    /// Logs a warning-level message
    func warning(_ message: String, file: String, function: String, line: Int)
    
    /// Logs an error-level message
    func error(_ message: String, file: String, function: String, line: Int)
    
    /// Logs a fault-level message
    func fault(_ message: String, file: String, function: String, line: Int)
    
    /// Logs an error object
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Optional context message
    ///   - file: Source file name
    ///   - function: Function name
    ///   - line: Line number
    func logError(_ error: Error, context: String?, file: String, function: String, line: Int)
}

// Provide default parameter values via a protocol extension so callers
// don't need to pass file/function/line everywhere.
extension LoggerProtocol {
    func log(_ level: LogLevel, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level, message: message, file: file, function: function, line: line)
    }
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, file: file, function: function, line: line)
    }
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, file: file, function: function, line: line)
    }
    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        fault(message, file: file, function: function, line: line)
    }
    func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        logError(error, context: context, file: file, function: function, line: line)
    }
}

/// Centralized logging service implementation using OSLog
/// Provides structured logging with different severity levels using Apple's unified logging system
final class Logger: LoggerProtocol {
    /// Shared singleton instance
    static let shared = Logger()
    
    private let osLogger: OSLog
    private let subsystem = "com.jarllyng.TrimrPix"
    
    /// Private initializer to enforce singleton pattern
    private init() {
        osLogger = OSLog(subsystem: subsystem, category: "Application")
    }
    
    /// Main logging method
    /// Formats and logs messages using OSLog for integration with Console.app
    /// - Parameters:
    ///   - level: Log severity level
    ///   - message: Log message
    ///   - file: Source file name (defaults to #file)
    ///   - function: Function name (defaults to #function)
    ///   - line: Line number (defaults to #line)
    func log(_ level: LogLevel, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.rawValue)] \(fileName):\(line) \(function) - \(message)"
        
        switch level {
        case .debug:
            os_log("%{public}@", log: osLogger, type: .debug, logMessage)
        case .info:
            os_log("%{public}@", log: osLogger, type: .info, logMessage)
        case .warning:
            os_log("%{public}@", log: osLogger, type: .default, logMessage)
        case .error:
            os_log("%{public}@", log: osLogger, type: .error, logMessage)
        case .fault:
            os_log("%{public}@", log: osLogger, type: .fault, logMessage)
        }
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message: message, file: file, function: function, line: line)
    }
    
    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.fault, message: message, file: file, function: function, line: line)
    }
    
    /// Logs an error object with context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Optional context message
    ///   - file: Source file name
    ///   - function: Function name
    ///   - line: Line number
    func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Error: \(error.localizedDescription)"
        if let context = context {
            message = "\(context) - \(message)"
        }
        
        if let trimrPixError = error as? TrimrPixError {
            log(.error, message: "\(message) | Technical: \(trimrPixError.technicalDescription)", file: file, function: function, line: line)
        } else {
            log(.error, message: message, file: file, function: function, line: line)
        }
    }
}

// MARK: - Convenience Global Functions

/// Global convenience function for debug logging
/// - Parameter message: The message to log
func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, file: file, function: function, line: line)
}

/// Global convenience function for info logging
/// - Parameter message: The message to log
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, file: file, function: function, line: line)
}

/// Global convenience function for warning logging
/// - Parameter message: The message to log
func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, file: file, function: function, line: line)
}

/// Global convenience function for error logging
/// - Parameter message: The message to log
func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, file: file, function: function, line: line)
}

/// Global convenience function for fault logging
/// - Parameter message: The message to log
func logFault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.fault(message, file: file, function: function, line: line)
}

/// Global convenience function for logging error objects
/// - Parameters:
///   - error: The error to log
///   - context: Optional context message
func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.logError(error, context: context, file: file, function: function, line: line)
}

