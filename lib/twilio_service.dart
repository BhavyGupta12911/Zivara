import 'dart:convert';
import 'package:http/http.dart' as http;

class TwilioService {
  static const _accountSid = 'Add your account sid here';
  static const _authToken  = 'Add your auth token here';
  static const _fromNumber = 'Add your from number here';

  /// Normalises any Indian number to E.164 (+91XXXXXXXXXX).
  static String _normalise(String raw) {
    String n = raw.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (n.startsWith('+')) return n;           // already E.164
    if (n.startsWith('0')) n = n.substring(1); // remove leading 0
    if (n.length == 10) return '+91$n';         // bare 10-digit Indian number
    return '+$n';                               // best-effort fallback
  }

  static Future<bool> sendSMS({
    required String to,
    required String message,
  }) async {
    final normalized = _normalise(to);
    print('[TwilioService] Attempting SMS to $normalized');

    final uri = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json',
    );
    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': _fromNumber,
          'To':   normalized,
          'Body': message,
        },
      );

      if (response.statusCode != 201) {
        print('[TwilioService] ERROR ${response.statusCode}: ${response.body}');
      } else {
        print('[TwilioService] SUCCESS — message queued for $normalized');
      }

      return response.statusCode == 201;
    } catch (e) {
      print('[TwilioService] EXCEPTION: $e');
      return false;
    }
  }
}