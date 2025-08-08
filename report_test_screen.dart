import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportTestScreen extends StatefulWidget {
  const ReportTestScreen({super.key});

  @override
  State<ReportTestScreen> createState() => _ReportTestScreenState();
}

class _ReportTestScreenState extends State<ReportTestScreen> {
  bool _isSubmitting = false;
  String _result = '';

  Future<void> _testReportSubmission() async {
    setState(() {
      _isSubmitting = true;
      _result = 'Testing...';
    });

    try {
      final success = await ReportService.submitReport(
        reportType: 'technical_issue',
        chatType: 'Test Report System',
        description: 'This is a test report to verify the reporting system is working correctly.',
        sessionId: 'test-session-123',
        userId: 'test-user',
        chatHistory: [
          'User: Hello, testing the system',
          'Nyx: Hi! How can I help you today?',
          'User: Just testing the report feature',
        ],
      );

      setState(() {
        _result = success 
            ? 'SUCCESS: Report submitted successfully!' 
            : 'FAILED: Could not submit report, but it was stored locally.';
      });
    } catch (e) {
      setState(() {
        _result = 'ERROR: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _checkPendingReports() async {
    final pending = await ReportService.getPendingReports();
    setState(() {
      _result = 'Pending reports: ${pending.length}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report System Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Report System',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isSubmitting ? null : _testReportSubmission,
              child: _isSubmitting 
                  ? const CircularProgressIndicator()
                  : const Text('Test Report Submission'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _checkPendingReports,
              child: const Text('Check Pending Reports'),
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _result.isEmpty ? 'No results yet' : _result,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'This test screen verifies that:\n'
              '• Reports can be submitted\n'
              '• Email service is working\n'
              '• Fallback storage is working\n'
              '• Developer receives reports at shesveetee@gmail.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}