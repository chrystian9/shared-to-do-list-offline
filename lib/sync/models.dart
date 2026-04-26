import '../domain/models/operation.dart';

enum MessageType {
  hello,
  capability,
  auth,
  householdOffer,
  summaryRequest,
  summaryResponse,
  opsRequest,
  opsChunk,
  snapshotOffer,
  snapshotChunk,
  ack,
  nack,
  error,
  complete,
}

class ProtocolMessage {
  const ProtocolMessage({
    required this.messageId,
    required this.sessionId,
    required this.type,
    required this.protocolVersion,
    required this.body,
  });

  final String messageId;
  final String sessionId;
  final MessageType type;
  final int protocolVersion;
  final Map<String, Object?> body;

  Map<String, Object?> toJson() {
    return {
      'messageId': messageId,
      'sessionId': sessionId,
      'type': type.name,
      'protocolVersion': protocolVersion,
      'body': body,
    };
  }

  factory ProtocolMessage.fromJson(Map<String, Object?> json) {
    return ProtocolMessage(
      messageId: json['messageId'] as String,
      sessionId: json['sessionId'] as String,
      type: MessageType.values.byName(json['type'] as String),
      protocolVersion: json['protocolVersion'] as int,
      body: (json['body'] as Map).cast<String, Object?>(),
    );
  }
}

class ReplicaSummary {
  const ReplicaSummary({
    required this.householdId,
    required this.protocolVersion,
    required this.schemaVersion,
    required this.deviceId,
    required this.maxLamport,
    required this.operationCount,
    required this.opsDigest,
  });

  final String householdId;
  final int protocolVersion;
  final int schemaVersion;
  final String deviceId;
  final int maxLamport;
  final int operationCount;
  final String opsDigest;

  Map<String, Object?> toJson() {
    return {
      'householdId': householdId,
      'protocolVersion': protocolVersion,
      'schemaVersion': schemaVersion,
      'deviceId': deviceId,
      'maxLamport': maxLamport,
      'operationCount': operationCount,
      'opsDigest': opsDigest,
    };
  }
}

class ExportPayload {
  const ExportPayload({
    required this.summary,
    required this.operations,
  });

  final ReplicaSummary summary;
  final List<CrdtOperation> operations;

  Map<String, Object?> toJson() {
    return {
      'summary': summary.toJson(),
      'operations': operations.map((operation) => operation.toJson()).toList(),
    };
  }

  factory ExportPayload.fromJson(Map<String, Object?> json) {
    final summaryJson = (json['summary'] as Map).cast<String, Object?>();
    final opsJson = (json['operations'] as List).cast<Map>();
    return ExportPayload(
      summary: ReplicaSummary(
        householdId: summaryJson['householdId'] as String,
        protocolVersion: summaryJson['protocolVersion'] as int,
        schemaVersion: summaryJson['schemaVersion'] as int,
        deviceId: summaryJson['deviceId'] as String,
        maxLamport: summaryJson['maxLamport'] as int,
        operationCount: summaryJson['operationCount'] as int,
        opsDigest: summaryJson['opsDigest'] as String,
      ),
      operations: opsJson
          .map((entry) => CrdtOperation.fromJson(entry.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}

class InvitationPayload {
  const InvitationPayload({
    required this.householdId,
    required this.householdName,
    required this.inviterMemberName,
    required this.protocolVersion,
    required this.schemaVersion,
    required this.exportPayload,
  });

  final String householdId;
  final String householdName;
  final String inviterMemberName;
  final int protocolVersion;
  final int schemaVersion;
  final ExportPayload exportPayload;

  Map<String, Object?> toJson() {
    return {
      'kind': 'household_invite',
      'householdId': householdId,
      'householdName': householdName,
      'inviterMemberName': inviterMemberName,
      'protocolVersion': protocolVersion,
      'schemaVersion': schemaVersion,
      'exportPayload': exportPayload.toJson(),
    };
  }

  factory InvitationPayload.fromJson(Map<String, Object?> json) {
    return InvitationPayload(
      householdId: json['householdId'] as String,
      householdName: json['householdName'] as String,
      inviterMemberName: json['inviterMemberName'] as String? ?? 'Family member',
      protocolVersion: json['protocolVersion'] as int,
      schemaVersion: json['schemaVersion'] as int,
      exportPayload: ExportPayload.fromJson(
        (json['exportPayload'] as Map).cast<String, Object?>(),
      ),
    );
  }
}
