//
//  Log.swift
//  taz
//
//  Created by Norbert Thies on 21.08.17.
//  Copyright © 2017 Norbert Thies. All rights reserved.
//

import UIKit

/// Protocol to adopt from classes which like to use self.log, ...
public protocol DoesLog {
  //...
}

extension DoesLog {
  
  func log(_ msg: String? = nil, logLevel: LogMessage.LogLevel = .Info, file: String = #file,
            line: Int = #line, function: String = #function) {
    Log.log(msg, object: self, logLevel: logLevel, file: file, line: line, function: function)
  }
  
  func debug(_ msg: String? = nil, file: String = #file, line: Int = #line,
              function: String = #function) {
    Log.debug(msg, object: self, file: file, line: line, function: function)
  }
  
  func error(_ msg: String? = nil, file: String = #file, line: Int = #line,
               function: String = #function) {
    Log.error(msg, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  func exception(_ msg: String? = nil, _ exc: Exception? = nil, file: String = #file, line: Int = #line,
                   function: String = #function) -> Exception {
    return Log.exception(msg, exc: exc, object: self, file: file, function: function)
  }
  
  @discardableResult
  func exception(_ msg: String? = nil, _ exc: Error, file: String = #file, line: Int = #line,
                   function: String = #function) -> Exception {
    return Log.exception(msg, exc: exc, object: self, file: file, function: function)
  }
  
}


/// Common base classes to adopt DoesLog
extension UIView: DoesLog {}
extension UIViewController: DoesLog {}


/// class2s returns the classname of the passed object
fileprivate func class2s(_ object: Any?) -> String? {
  var cn: String? = nil
  if let obj = object {
    cn = String(describing: type(of: obj))
  }
  return cn
}

/// A message to log
public class LogMessage: CustomStringConvertible {
  
  /// LogLevel
  public enum LogLevel: Int, CustomStringConvertible {
    case Debug  = 1
    case Info   = 2
    case Error  = 3
    case Fatal  = 4
    public var description: String { return toString() }
    public func toString() -> String {
      switch self {
        case .Info:  return "Info"
        case .Debug: return "Debug"
        case .Error: return "Error"
        case .Fatal: return "Fatal"
      }
    }
  } // enum LogMessage.LogLevel
  
  public struct Options: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    static let Exception = Options(rawValue: 1<<0)
  } // struct LogMessage.Options
  
  // total number of messages produced
  private static var _messageCount = 0
  // serial queue to synchronize access to _messageCount
  private static var countQueue = DispatchQueue(label: "north.messageCount")
  /// number of messages logged in this session
  public static var messageCount: Int { return countQueue.sync { _messageCount } }
  
  public var serialNumber: Int = 0
  public var tstamp: UsTime
  public var logLevel: LogLevel
  public var options: Options = []
  public var fileName: String
  public var className: String?
  public var funcName: String
  public var line: Int
  public var message: String?
  
  public var fileBaseName: String { return (fileName as NSString).lastPathComponent }
  
  public var description: String { return toString() }
  
  public init( level: LogLevel, className: String?, fileName: String, funcName: String,
               line: Int, message: String? ) {
    self.tstamp = UsTime.now()
    self.logLevel = level
    self.className = className
    self.fileName = fileName
    self.funcName = funcName
    self.line = line
    self.message = message
    LogMessage.countQueue.sync { [weak self] in
      LogMessage._messageCount += 1
      self?.serialNumber = LogMessage._messageCount
    }
  }
  
  public convenience init( level: LogLevel, object: Any?, fileName: String, funcName: String,
                           line: Int, message: String? ) {
    self.init( level: level, className: class2s(object), fileName: fileName, funcName: funcName,
               line: line, message: message )
  }
  
  /// toString returns a minimalistic string representing the current message
  public func toString() -> String {
    let t = tstamp.date.components()
    var s = String( format: "(%02d %02d:%02d:%02d) ", serialNumber, t.hour!,
                    t.minute!, t.second! )
    if let cn = className { s += cn + "." }
    s += "\(funcName) \(logLevel)"
    if options.contains(.Exception) { s += " Exception" }
    if let str = message { s += ":\n  " + str }
    else {
      s += ":\n  at line \(line) in file \(fileBaseName)"
    }
    return s
  }
  
} // class LogMessage

/// A LogMessage that can be thrown as an exception
public class Exception: LogMessage, Error {

  /// A previous Exception causing this Exception
  public var previous: Exception? = nil
  
  /// An optional enclosed previous Error (exception)
  public var enclosedError: Error? = nil
  
  /// The localized description from the Error protocol
  public var localizedDescription: String { return toString() }

  /// Initialisation with a previous Exception or Error
  public init( level: LogLevel, className: String?, fileName: String, funcName: String,
               line: Int, message: String?, exc: Error? ) {
    super.init(level:level, className:className, fileName:fileName, funcName:funcName,
               line:line, message:message)
    if let exception = exc as? Exception {
      self.previous = exception
    }
    else if let error = exc {
      self.enclosedError = exc
      if let msg = message {
        self.message = msg + "\n  " + "Enclosed Error: \(error.localizedDescription)"
      }
      else {
        self.message = "Enclosed Error: \(error.localizedDescription)"
      }
    }
    self.options.insert(.Exception)
  }
  
} // class Exception


/// A base class defining where to log to. This implementation simply
/// logs to the standard output
public class Logger {
  
  // previous/next in list of Loggers
  fileprivate var prev: Logger? = nil
  fileprivate var next: Logger? = nil
  
  public func append( _ logger: Logger ) {
    self.next = logger.next
    logger.next = self
    self.prev = logger
  }
  
  public func removeFromList() {
    if let prev = self.prev { prev.next = self.next }
    if let next = self.next { next.prev = self.prev }
  }
  
  /// whether to log to this destination
  public var isEnabled = true
  
  /// log a message to the standard output
  public func log( _ msg: LogMessage ) {
    print( msg )
  }
  
} // class Logger


/// The class used to log to various destinations
public class Log {
  
  /// minimal log level (.Info by default)
  static var minLogLevel: LogMessage.LogLevel = .Info
  
  // serial queue to synchronize access to _messageCount
  private static var logQueue = DispatchQueue(label: "north.logging")
  
  // head/tail of Loggers
  static private var head: Logger? = nil
  static private var tail: Logger? = nil
  
  /// Dictionary of classes to debug
  static public var debugClasses: [String:Bool] = [:]
  
  /// isDebugClass returns true if a class of given name is to debug
  static public func isDebugClass( _ className: String? ) -> Bool {
    var ret = false
    if let cn = className {
      if let val = debugClasses[cn] { ret = val }
    }
    return ret
  }
  
  /// appendLogger appends a logging destination (derived from class Logger)
  /// to the list of loggers
  static public func appendLogger( _ lg: Logger ) {
    if let tail = self.tail { tail.append(lg) }
    else { self.head = lg; self.tail = lg }
  }
  
  /// removeLogger removes a logging destination from the list of Loggers
  static public func removeLogger( _ lg: Logger ) {
    if lg === head { head = lg.next }
    if lg === tail { tail = lg.prev }
    lg.removeFromList()
  }
  
  /// logs a LogMessage
  static public func log( _ msg: LogMessage ) {
    guard (msg.logLevel.rawValue >= minLogLevel.rawValue) ||
          isDebugClass(msg.className) else { return }
    logQueue.sync {
      if head == nil {
        head = Logger()
        tail = head
      }
      var logger = head
      while let lg = logger {
        if lg.isEnabled { lg.log( msg ) }
        logger = lg.next
      }
    }
  }
  
  /// log to certain output
  @discardableResult
  public static func log( _ message: String? = nil, object: Any? = nil,
    logLevel: LogMessage.LogLevel = .Info, file: String = #file, line: Int = #line,
    function: String = #function ) -> LogMessage {
    let msg = LogMessage( level: logLevel, object: object, fileName: file, funcName: function,
                          line: line, message: message )
    log(msg)
    return msg
  }
  
  @discardableResult
  public static func debug( _ msg: String? = nil, object: Any? = nil, file: String = #file, line: Int = #line,
                            function: String = #function ) -> LogMessage {
    return Log.log( msg, object: object, logLevel: .Debug, file: file, line: line, function: function )
  }

  @discardableResult
  public static func error( _ msg: String? = nil, object: Any? = nil, file: String = #file, line: Int = #line,
                            function: String = #function ) -> LogMessage {
    return Log.log( msg, object: object, logLevel: .Error, file: file, line: line, function: function )
  }

  @discardableResult
  public static func exception( _ message: String? = nil, exc: Error? = nil, object: Any? = nil,
                          logLevel: LogMessage.LogLevel = .Error, file: String = #file, line: Int = #line,
                          function: String = #function ) -> Exception {
    let msg = Exception( level: logLevel, className: class2s(object), fileName: file, funcName: function,
                         line: line, message: message, exc: exc )
    log(msg)
    return msg
  }
  
  @discardableResult
  public static func exception( _ exc: Error, _ message: String? = nil, object: Any? = nil,
                                logLevel: LogMessage.LogLevel = .Error, file: String = #file, line: Int = #line,
                                function: String = #function ) -> Exception {
    let msg = Exception( level: logLevel, className: class2s(object), fileName: file, funcName: function,
                         line: line, message: message, exc: exc )
    log(msg)
    return msg
  }
  
} // class Log
