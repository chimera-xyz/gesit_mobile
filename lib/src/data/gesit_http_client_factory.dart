import 'package:http/http.dart' as http;

import 'gesit_http_client_factory_stub.dart'
    if (dart.library.js_interop) 'gesit_http_client_factory_web.dart'
        as delegate;

http.Client createGesitHttpClient() => delegate.createGesitHttpClient();

bool get usesBrowserManagedCookies => delegate.usesBrowserManagedCookies;
