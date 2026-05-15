import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'mesh_protocol.dart';

/// Wraps a Meshtastic BLE peripheral: scan, connect, write ToRadio, listen for
/// FromRadio frames. Decoded packets surface as [MeshPacket] on [packets].
class MeshClient {
  final _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  final _packetsCtrl = StreamController<MeshPacket>.broadcast();
  Stream<MeshPacket> get packets => _packetsCtrl.stream;

  String? _connectedId;
  String? get connectedId => _connectedId;

  Stream<DiscoveredDevice> scan() => _ble.scanForDevices(
        withServices: [MeshtasticUuids.service],
        scanMode: ScanMode.lowLatency,
      );

  Future<void> connect(String deviceId) async {
    await disconnect();
    final completer = Completer<void>();
    _connSub = _ble
        .connectToDevice(
      id: deviceId,
      servicesWithCharacteristicsToDiscover: {
        MeshtasticUuids.service: [
          MeshtasticUuids.toRadio,
          MeshtasticUuids.fromRadio,
          MeshtasticUuids.fromNum,
        ],
      },
      connectionTimeout: const Duration(seconds: 10),
    )
        .listen((u) {
      if (u.connectionState == DeviceConnectionState.connected) {
        _connectedId = deviceId;
        _subscribeFromRadio(deviceId);
        if (!completer.isCompleted) completer.complete();
      }
      if (u.connectionState == DeviceConnectionState.disconnected) {
        _connectedId = null;
      }
    });
    return completer.future;
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    await _connSub?.cancel();
    _notifySub = null;
    _connSub = null;
    _connectedId = null;
  }

  void _subscribeFromRadio(String deviceId) {
    final ch = QualifiedCharacteristic(
      serviceId: MeshtasticUuids.service,
      characteristicId: MeshtasticUuids.fromNum,
      deviceId: deviceId,
    );
    _notifySub = _ble.subscribeToCharacteristic(ch).listen((_) async {
      await _drainFromRadio(deviceId);
    });
  }

  Future<void> _drainFromRadio(String deviceId) async {
    final ch = QualifiedCharacteristic(
      serviceId: MeshtasticUuids.service,
      characteristicId: MeshtasticUuids.fromRadio,
      deviceId: deviceId,
    );
    while (true) {
      final bytes = await _ble.readCharacteristic(ch);
      if (bytes.isEmpty) break;
      final id = decodeParticipantId(bytes);
      if (id != null) {
        _packetsCtrl.add(MeshPacket(
          fromNode: 0xFFFFFFFF,
          toNode: 0,
          participantId: id,
          ts: DateTime.now(),
        ));
      }
    }
  }

  Future<void> sendParticipantId(int id) async {
    final deviceId = _connectedId;
    if (deviceId == null) throw StateError('Not connected');
    final ch = QualifiedCharacteristic(
      serviceId: MeshtasticUuids.service,
      characteristicId: MeshtasticUuids.toRadio,
      deviceId: deviceId,
    );
    await _ble.writeCharacteristicWithResponse(
      ch,
      value: encodeParticipantId(id),
    );
  }

  void dispose() {
    disconnect();
    _packetsCtrl.close();
  }
}
