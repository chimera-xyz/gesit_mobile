import 'package:http/http.dart' as http;

http.Client createGesitHttpClient() => http.Client();

bool get usesBrowserManagedCookies => false;
