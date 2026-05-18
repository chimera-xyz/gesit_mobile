import 'package:flutter_test/flutter_test.dart';
import 'package:gesit_app/src/config/app_runtime_config.dart';
import 'package:gesit_app/src/data/server_endpoint_resolver.dart';

void main() {
  group('ServerEndpointResolver', () {
    test('probes the configured API endpoint once', () async {
      final probes = <String>[];
      final resolver = ServerEndpointResolver(
        probe: (baseUrl, timeout) async {
          probes.add(baseUrl);
          return true;
        },
      );

      final candidate = await resolver.resolve();

      expect(candidate?.id, 'default');
      expect(candidate?.baseUrl, AppRuntimeConfig.defaultApiBaseUrl);
      expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
    });

    test('ignores saved non-default mobile endpoints', () async {
      final probes = <String>[];
      final resolver = ServerEndpointResolver(
        probe: (baseUrl, timeout) async {
          probes.add(baseUrl);
          return true;
        },
      );

      final candidate = await resolver.resolve(
        preferredBaseUrl: 'http://10.10.10.10:8000',
      );

      expect(candidate?.id, 'default');
      expect(candidate?.baseUrl, AppRuntimeConfig.defaultApiBaseUrl);
      expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
    });

    test(
      'migrates the old Tailscale route to the configured endpoint',
      () async {
        final probes = <String>[];
        final resolver = ServerEndpointResolver(
          probe: (baseUrl, timeout) async {
            probes.add(baseUrl);
            return true;
          },
        );

        final candidate = await resolver.resolve(
          preferredBaseUrl: 'http://100.64.7.96:8000',
        );

        expect(candidate?.id, 'default');
        expect(candidate?.baseUrl, AppRuntimeConfig.defaultApiBaseUrl);
        expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
      },
    );

    test('migrates the previous LAN route to the configured endpoint', () async {
      final probes = <String>[];
      final resolver = ServerEndpointResolver(
        probe: (baseUrl, timeout) async {
          probes.add(baseUrl);
          return true;
        },
      );

      final candidate = await resolver.resolve(
        preferredBaseUrl: 'http://192.168.1.22:8000',
      );

      expect(candidate?.id, 'default');
      expect(candidate?.baseUrl, AppRuntimeConfig.defaultApiBaseUrl);
      expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
    });

    test('returns null when the configured endpoint is unreachable', () async {
      final probes = <String>[];
      final resolver = ServerEndpointResolver(
        probe: (baseUrl, timeout) async {
          probes.add(baseUrl);
          return false;
        },
      );

      final candidate = await resolver.resolve();

      expect(candidate, isNull);
      expect(probes, [AppRuntimeConfig.defaultApiBaseUrl]);
    });
  });
}
