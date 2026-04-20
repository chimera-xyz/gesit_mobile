import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client createGesitHttpClient() {
  final client = BrowserClient()..withCredentials = true;
  return client;
}

bool get usesBrowserManagedCookies => true;
