import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// Meshtastic GATT service + characteristic UUIDs.
/// Reference: https://meshtastic.org/docs/development/device/client-api/
class MeshtasticUuids {
  static final service = Uuid.parse('6ba1b218-15a8-461f-9fa8-5dcae273eafd');

  /// Write phone-to-radio ToRadio protobuf
  static final toRadio = Uuid.parse('f75c76d2-129e-4dad-a1dd-7866124401e7');

  /// Read radio-to-phone FromRadio protobuf
  static final fromRadio = Uuid.parse('2c55e69e-4993-11ed-b878-0242ac120002');

  /// Notify when new FromRadio data is queued
  static final fromNum = Uuid.parse('ed9da18c-a800-4f66-a670-aa7547e34453');
}

/// Minimal subset of the Meshtastic packet that we expose to the UI.
/// Real wire format is protobuf; we keep the fields the rescue/host app cares
/// about: a numeric participant id and the originating node.
class MeshPacket {
  final int fromNode;
  final int toNode;
  final int participantId;
  final DateTime ts;
  final int? rssi;
  final int? snr;

  const MeshPacket({
    required this.fromNode,
    required this.toNode,
    required this.participantId,
    required this.ts,
    this.rssi,
    this.snr,
  });
}

/// Hand-rolled encoder for a numeric "participant id" payload.
/// On a real Meshtastic device this would be wrapped in a TextMessage protobuf
/// posted to the primary channel; here we keep the over-the-air envelope intact
/// (varint port + uint32 id) so the host firmware can read it as-is.
List<int> encodeParticipantId(int id) {
  final out = <int>[];
  _writeVarint(out, 1 << 3); // field 1, wire type 0 (varint)
  _writeVarint(out, id);
  return out;
}

int? decodeParticipantId(List<int> bytes) {
  if (bytes.isEmpty) return null;
  var i = 0;
  final tag = _readVarint(bytes, i);
  i += _varintSize(tag.value);
  if (tag.value != (1 << 3)) return null;
  final id = _readVarint(bytes, i);
  return id.value;
}

void _writeVarint(List<int> out, int v) {
  while (v > 0x7f) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v & 0x7f);
}

class _Varint {
  final int value;
  _Varint(this.value);
}

_Varint _readVarint(List<int> bytes, int offset) {
  var result = 0;
  var shift = 0;
  var i = offset;
  while (i < bytes.length) {
    final b = bytes[i++];
    result |= (b & 0x7f) << shift;
    if ((b & 0x80) == 0) return _Varint(result);
    shift += 7;
  }
  return _Varint(result);
}

int _varintSize(int v) {
  var n = 1;
  while (v > 0x7f) {
    n++;
    v >>= 7;
  }
  return n;
}
