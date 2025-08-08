# NyxApp Reporting System Setup

## Overview
The NyxApp reporting system allows users to report offensive or inappropriate content directly to the developer (shesveetee@gmail.com) from within any chat interface.

## Features Implemented
- ✅ Report button in all chat screens (Nyx Queries, Support Chat, Nautical Nyx)
- ✅ Professional report submission form
- ✅ Multiple report categories (inappropriate content, misinformation, harassment, etc.)
- ✅ Optional chat history inclusion
- ✅ Multi-tier email delivery system with fallbacks
- ✅ Local storage fallback for offline reports
- ✅ User confirmation dialogs

## Email Service Configuration

### Primary Method: Formspree
1. Visit [formspree.io](https://formspree.io)
2. Create a free account
3. Create a new form with endpoint ID
4. Update `_formspreeEndpoint` in `lib/services/report_service.dart`
5. Current placeholder: `xdorqgpn`

### Alternative Method: IFTTT Webhook
1. Visit [ifttt.com](https://ifttt.com)
2. Create an applet: "If webhook then send email"
3. Set trigger name: `nyx_report`
4. Configure email action to send to: `shesveetee@gmail.com`
5. Update webhook key in `report_service.dart`

## File Structure
```
lib/
├── services/
│   └── report_service.dart          # Core reporting functionality
├── screens/
│   ├── report_content_screen.dart   # Report submission UI
│   ├── nyx_queries_screen.dart      # Updated with reporting
│   ├── support_chat_screen.dart     # Updated with reporting
│   ├── nautical_chat_screen.dart    # Updated with reporting
│   └── report_test_screen.dart      # Testing utility
```

## How to Use
1. Open any chat in the app (Nyx Queries, Support Chat, Nautical Nyx)
2. Tap the three-dot menu (⋮) in the top-right corner
3. Select "Report Content" (red flag icon)
4. Fill out the report form:
   - Select report type
   - Describe the issue
   - Optionally include chat history
5. Submit the report

## Report Categories
- **Inappropriate Content**: Offensive, harmful, or inappropriate material
- **Misinformation**: Incorrect or misleading information
- **Harassment**: Bullying or discriminatory content
- **Spam**: Repetitive or unwanted content
- **Technical Issue**: Bugs or technical problems
- **Privacy Concern**: Data privacy or security issues
- **Other**: Any other concerns

## Developer Notifications
Reports are sent to: **shesveetee@gmail.com**

Email format includes:
- Report type and category
- Chat type and session ID
- User description
- Timestamp and platform info
- Optional chat history (last 10 messages)
- App version and platform details

## Fallback System
1. **Primary**: Formspree email service
2. **Secondary**: IFTTT webhook
3. **Tertiary**: Local storage (reports saved for later transmission)

## Testing
Use `ReportTestScreen` to verify the system:
1. Navigate to the test screen
2. Click "Test Report Submission"
3. Check developer email for receipt
4. Verify fallback storage if needed

## Privacy & Security
- All reports are sent securely via HTTPS
- No sensitive user data is transmitted
- Chat history inclusion is optional and user-controlled
- Reports are only used for investigating reported issues
- Local fallback reports are encrypted in device storage

## Maintenance
- Check pending reports with `ReportService.getPendingReports()`
- Retry failed reports with `ReportService.retryPendingReports()`
- Monitor report statistics with `ReportService.getTotalReportsSubmitted()`

## Configuration Requirements
To activate the reporting system:

1. **Set up Formspree account**:
   ```dart
   static const String _formspreeEndpoint = 'YOUR_FORMSPREE_ID';
   ```

2. **Configure IFTTT webhook (optional)**:
   ```dart
   const webhookKey = 'YOUR_IFTTT_KEY';
   ```

3. **Test the system**:
   - Send test reports
   - Verify email delivery
   - Check fallback mechanisms

## Support
For issues with the reporting system, contact: shesveetee@gmail.com