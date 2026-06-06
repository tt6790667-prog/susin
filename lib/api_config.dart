import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URLs for Susin App.
class ApiConfig {
  /// Support tickets API on app.susingroup.com (uploaded under support-api/api/)
  static const String supportApiHost = 'app.susingroup.com';
  static const String supportApiPath = '/support-api/api';
  static const String _supportApiProduction =
      'https://$supportApiHost$supportApiPath';

  static String get supportApiBase {
    if (kIsWeb) {
      final base = Uri.base;
      final host = base.host.toLowerCase();
      if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
        return _supportApiProduction;
      }
      if (host == supportApiHost || host.endsWith('.$supportApiHost')) {
        final port = base.hasPort ? ':${base.port}' : '';
        return '${base.scheme}://${base.host}$port$supportApiPath';
      }
    }
    return _supportApiProduction;
  }

  static String get ticketsUrl => '$supportApiBase/tickets/index.php';
  static String get ticketRepliesUrl => '$supportApiBase/tickets/reply.php';

  static const String centralLoginUrl =
      'https://centralusers.susingroup.com/backend-php/api/auth/login.php';
  static const String docApiBase = 'https://doc.susingroup.com/api';
  static const String ordersApiBase =
      'https://gm.susingroup.com/backend-php/api';
  // Endpoint to fetch available regions for users
  static const String regionsUrl = '${ordersApiBase}/regions.php';
}
