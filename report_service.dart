import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'logging_service.dart';

class ReportService {
  static const String _developerEmail = 'shesveetee@gmail.com';
  static const String _baseUrl = 'https://formspree.io/f/'; // Using Formspree for email sending
  static const String _formspreeEndpoint = 'xdorqgpn'; // Formspree endpoint ID
  
  /// Submit a report to the developer
  static Future<bool> submitReport({
    required String reportType,
    required String chatType,
    required String description,
    String? sessionId,
    String? userId,
    List<String>? chatHistory,
  }) async {
    try {
      LoggingService.logInfo('Submitting report from ReportService.submitReport');
      
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();
      
      // Prepare report data
      final reportData = {
        'to': _developerEmail,
        'subject': 'NyxApp Content Report - $reportType',
        'report_type': reportType,
        'chat_type': chatType,
        'description': description,
        'session_id': sessionId ?? 'N/A',
        'user_id': userId ?? 'Anonymous',
        'timestamp': timestamp,
        'app_version': '2.0', // Could be dynamic
        'platform': defaultTargetPlatform.name,
      };
      
      // Add chat history if provided (limited to prevent large payloads)
      if (chatHistory != null && chatHistory.isNotEmpty) {
        final limitedHistory = chatHistory.length > 10 
            ? chatHistory.sublist(chatHistory.length - 10) 
            : chatHistory;
        reportData['recent_chat_history'] = limitedHistory.join('\n---\n');
      }
      
      // Try multiple methods for sending reports
      bool success = await _sendViaFormspree(reportData);
      
      // Fallback 1: Try alternative email service
      if (!success) {
        success = await _sendViaWebhook(reportData);
      }
      
      // Fallback 2: Store locally for manual review
      if (!success) {
        success = await _storeReportLocally(reportData);
        LoggingService.logInfo('Report stored locally as fallback');
      }
      
      if (success) {
        LoggingService.logInfo('Report submitted successfully');
        await _incrementReportCount();
      } else {
        LoggingService.logError('Failed to submit report');
      }
      
      return success;
    } catch (e) {
      LoggingService.logError('Error submitting report: $e');
      return false;
    }
  }
  
  /// Send report via Formspree service
  static Future<bool> _sendViaFormspree(Map<String, dynamic> reportData) async {
    try {
      // Formspree expects specific format
      final formspreeData = {
        '_replyto': 'noreply@nyxapp.com',
        '_subject': reportData['subject'],
        'email': _developerEmail,
        'message': _buildEmailMessage(reportData),
        '_cc': _developerEmail,
      };
      
      final response = await http.post(
        Uri.parse('$_baseUrl$_formspreeEndpoint'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(formspreeData),
      ).timeout(const Duration(seconds: 10));
      
      LoggingService.logInfo('Formspree response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      if (e is SocketException) {
        LoggingService.logError('Network error in Formspree: $e');
      } else if (e is TimeoutException) {
        LoggingService.logError('Timeout error in Formspree: $e');
      } else {
        LoggingService.logError('Formspree send failed: $e');
      }
      return false;
    }
  }
  
  /// Send report via webhook/alternative service
  static Future<bool> _sendViaWebhook(Map<String, dynamic> reportData) async {
    try {
      // Using IFTTT webhook as alternative (more reliable than Zapier)
      const webhookKey = 'YOUR_IFTTT_KEY'; // Would need to be configured
      const webhookUrl = 'https://maker.ifttt.com/trigger/nyx_report/with/key/$webhookKey';
      
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'value1': reportData['report_type'],
          'value2': reportData['chat_type'],
          'value3': _buildEmailMessage(reportData),
        }),
      ).timeout(const Duration(seconds: 10));
      
      LoggingService.logInfo('Webhook response: ${response.statusCode}');
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (e is SocketException) {
        LoggingService.logError('Network error in webhook: $e');
      } else if (e is TimeoutException) {
        LoggingService.logError('Timeout error in webhook: $e');
      } else {
        LoggingService.logError('Webhook send failed: $e');
      }
      return false;
    }
  }
  
  /// Build formatted email message
  static String _buildEmailMessage(Map<String, dynamic> reportData) {
    final buffer = StringBuffer();
    buffer.writeln('NEW CONTENT REPORT FROM NYXAPP');
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('Report Type: ${reportData['report_type']}');
    buffer.writeln('Chat Type: ${reportData['chat_type']}');
    buffer.writeln('Session ID: ${reportData['session_id']}');
    buffer.writeln('User ID: ${reportData['user_id']}');
    buffer.writeln('Timestamp: ${reportData['timestamp']}');
    buffer.writeln('Platform: ${reportData['platform']}');
    buffer.writeln('App Version: ${reportData['app_version']}');
    buffer.writeln('');
    buffer.writeln('DESCRIPTION:');
    buffer.writeln('------------');
    buffer.writeln(reportData['description']);
    
    if (reportData.containsKey('recent_chat_history')) {
      buffer.writeln('');
      buffer.writeln('RECENT CHAT HISTORY:');
      buffer.writeln('-------------------');
      buffer.writeln(reportData['recent_chat_history']);
    }
    
    buffer.writeln('');
    buffer.writeln('This is an automated report from the NyxApp reporting system.');
    
    return buffer.toString();
  }
  
  /// Store report locally as fallback
  static Future<bool> _storeReportLocally(Map<String, dynamic> reportData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reports = prefs.getStringList('pending_reports') ?? [];
      
      reports.add(jsonEncode(reportData));
      await prefs.setStringList('pending_reports', reports);
      
      LoggingService.logInfo('Report stored locally for later transmission');
      return true;
    } catch (e) {
      LoggingService.logError('Failed to store report locally: $e');
      return false;
    }
  }
  
  /// Get pending reports that couldn't be sent
  static Future<List<Map<String, dynamic>>> getPendingReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reports = prefs.getStringList('pending_reports') ?? [];
      
      return reports.map((report) => jsonDecode(report) as Map<String, dynamic>).toList();
    } catch (e) {
      LoggingService.logError('Error getting pending reports: $e');
      return [];
    }
  }
  
  /// Clear pending reports after successful transmission
  static Future<void> clearPendingReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_reports');
      LoggingService.logInfo('Cleared pending reports');
    } catch (e) {
      LoggingService.logError('Error clearing pending reports: $e');
    }
  }
  
  /// Increment report submission count
  static Future<void> _incrementReportCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('total_reports_submitted') ?? 0;
      await prefs.setInt('total_reports_submitted', count + 1);
    } catch (e) {
      LoggingService.logError('Error incrementing report count: $e');
    }
  }
  
  /// Get total number of reports submitted
  static Future<int> getTotalReportsSubmitted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('total_reports_submitted') ?? 0;
    } catch (e) {
      LoggingService.logError('Error getting report count: $e');
      return 0;
    }
  }
  
  /// Retry sending pending reports
  static Future<int> retryPendingReports() async {
    try {
      final pendingReports = await getPendingReports();
      int successCount = 0;
      
      for (final reportData in pendingReports) {
        final success = await _sendViaFormspree(reportData);
        if (success) {
          successCount++;
        }
      }
      
      if (successCount > 0) {
        // Remove successfully sent reports
        final prefs = await SharedPreferences.getInstance();
        final remainingReports = pendingReports.skip(successCount).map((r) => jsonEncode(r)).toList();
        await prefs.setStringList('pending_reports', remainingReports);
        
        LoggingService.logInfo('Successfully retried $successCount pending reports');
      }
      
      return successCount;
    } catch (e) {
      LoggingService.logError('Error retrying pending reports: $e');
      return 0;
    }
  }
}