import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static File? _logFile;
  static final Logger _logger = Logger('NyxApp');

  static Future<void> initialize() async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/nyx_app.log');
      
      // Ensure log file exists
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }

      // Configure logging
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        final message = '${record.time}: ${record.level.name}: ${record.loggerName}: ${record.message}';
        
        // Print to console
        print(message);
        
        // Write to file
        _writeToFile(message);
      });

      _logger.info('Logging service initialized');
    } catch (e) {
      print('Failed to initialize logging: $e');
    }
  }

  static void _writeToFile(String message) {
    try {
      _logFile?.writeAsStringSync('$message\n', mode: FileMode.append);
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  static void logClaudeApiCall(String mode, String message) {
    _logger.info('Claude API call - Mode: $mode, Message length: ${message.length}');
  }

  static void logClaudeApiResponse(int statusCode, String? response) {
    _logger.info('Claude API response - Status: $statusCode, Response length: ${response?.length ?? 0}');
  }

  static void logClaudeApiError(String error) {
    _logger.severe('Claude API error: $error');
  }

  static void logNetworkError(String url, String error) {
    _logger.severe('Network error for $url: $error');
  }

  static void logInfo(String message) {
    _logger.info(message);
  }

  static void logError(String message) {
    _logger.severe(message);
  }

  static void logWarning(String message) {
    _logger.warning(message);
  }

  static Future<String> getLogFilePath() async {
    if (_logFile != null) {
      return _logFile!.path;
    }
    return 'Log file not initialized';
  }

  static Future<String> getLogContent() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        return await _logFile!.readAsString();
      }
      return 'No log file found';
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
}