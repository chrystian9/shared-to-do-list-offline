import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ExportPayloadResolver = Future<String> Function(String householdId);

class LanPeerInfo {
  const LanPeerInfo({
    required this.deviceId,
    required this.memberName,
    required this.host,
    required this.port,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String memberName;
  final String host;
  final int port;
  final DateTime lastSeenAt;
}

class LanSyncServer {
  HttpServer? _server;
  RawDatagramSocket? _announceSocket;
  Timer? _announceTimer;

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
    await _startAnnouncements(
      port: server.port,
      deviceId: deviceId,
      memberName: memberName,
    );

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
    _announceTimer?.cancel();
    _announceTimer = null;
    _announceSocket?.close();
    _announceSocket = null;
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

  Future<void> _startAnnouncements({
    required int port,
    required String deviceId,
    required String memberName,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _announceSocket = socket;

    void sendAnnouncement() {
      final message = jsonEncode({
        'kind': 'shared_lists_offline_peer',
        'deviceId': deviceId,
        'memberName': memberName,
        'port': port,
      });
      socket.send(
        utf8.encode(message),
        InternetAddress('255.255.255.255'),
        LanPeerDiscovery.discoveryPort,
      );
    }

    sendAnnouncement();
    _announceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => sendAnnouncement(),
    );
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

class LanPeerDiscovery {
  static const int discoveryPort = 4041;

  RawDatagramSocket? _socket;

  Future<void> start({
    required void Function(LanPeerInfo peer) onPeerDiscovered,
  }) async {
    if (_socket != null) {
      return;
    }

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
    _socket = socket;

    socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      final datagram = socket.receive();
      if (datagram == null) {
        return;
      }

      try {
        final decoded = jsonDecode(utf8.decode(datagram.data));
        if (decoded is! Map) {
          return;
        }
        if (decoded['kind'] != 'shared_lists_offline_peer') {
          return;
        }
        final deviceId = decoded['deviceId'];
        final memberName = decoded['memberName'];
        final port = decoded['port'];
        if (deviceId is! String || memberName is! String || port is! int) {
          return;
        }

        onPeerDiscovered(
          LanPeerInfo(
            deviceId: deviceId,
            memberName: memberName,
            host: datagram.address.address,
            port: port,
            lastSeenAt: DateTime.now(),
          ),
        );
      } catch (_) {
        // Ignore malformed discovery datagrams.
      }
    });
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
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
