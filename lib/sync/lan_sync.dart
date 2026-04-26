import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ExportPayloadResolver = Future<String> Function(String householdId);

class LanSyncServer {
  HttpServer? _server;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start({
    required int port,
    required String deviceId,
    required String memberName,
    required ExportPayloadResolver onExportRequested,
  }) async {
    if (_server != null) {
      return;
    }

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _server = server;

    unawaited(
      server.forEach((request) async {
        try {
          final path = request.uri.path;
          if (request.method == 'GET' && path == '/health') {
            await _writeJsonResponse(
              request.response,
              HttpStatus.ok,
              {
                'deviceId': deviceId,
                'memberName': memberName,
                'port': server.port,
              },
            );
            return;
          }

          if (request.method == 'POST' && path == '/export') {
            final body = await utf8.decoder.bind(request).join();
            final decoded = jsonDecode(body);
            if (decoded is! Map || decoded['householdId'] is! String) {
              await _writeJsonResponse(
                request.response,
                HttpStatus.badRequest,
                {'error': 'Invalid request payload.'},
              );
              return;
            }

            final householdId = decoded['householdId'] as String;
            final payload = await onExportRequested(householdId);
            await _writeTextResponse(request.response, HttpStatus.ok, payload);
            return;
          }

          await _writeJsonResponse(
            request.response,
            HttpStatus.notFound,
            {'error': 'Not found.'},
          );
        } catch (error) {
          await _writeJsonResponse(
            request.response,
            HttpStatus.internalServerError,
            {'error': '$error'},
          );
        }
      }),
    );
  }

  Future<void> stop() async {
    final current = _server;
    if (current == null) {
      return;
    }
    _server = null;
    await current.close(force: true);
  }

  static Future<List<String>> localIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    final addresses = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          addresses.add(address.address);
        }
      }
    }
    return addresses.toList()..sort();
  }

  Future<void> _writeJsonResponse(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _writeTextResponse(
    HttpResponse response,
    int statusCode,
    String body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.text;
    response.write(body);
    await response.close();
  }
}

class LanSyncClient {
  static Future<String> fetchPayload({
    required String host,
    required int port,
    required String householdId,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.http('$host:$port', '/export'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'householdId': householdId}));

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Peer returned ${response.statusCode}: $body');
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}
