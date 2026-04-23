import 'dart:convert';

import 'models.dart';

class DiscoveredPeer {
  const DiscoveredPeer({
    required this.peerId,
    required this.label,
  });

  final String peerId;
  final String label;
}

abstract interface class SyncTransport {
  String get transportId;
  Future<List<DiscoveredPeer>> discoverPeers();
  Future<String> exportPayload(ExportPayload payload);
  Future<ExportPayload> importPayload(String serializedPayload);
}

class ManualJsonSyncTransport implements SyncTransport {
  const ManualJsonSyncTransport();

  @override
  String get transportId => 'manual_json';

  @override
  Future<List<DiscoveredPeer>> discoverPeers() async {
    return const [];
  }

  @override
  Future<String> exportPayload(ExportPayload payload) async {
    return const JsonEncoder.withIndent('  ').convert(payload.toJson());
  }

  @override
  Future<ExportPayload> importPayload(String serializedPayload) async {
    return ExportPayload.fromJson(
      (jsonDecode(serializedPayload) as Map).cast<String, Object?>(),
    );
  }
}
