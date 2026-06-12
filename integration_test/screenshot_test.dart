import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_meshtastic_ble/data/mesh_protocol.dart';
import 'package:flutter_meshtastic_ble/data/mesh_store.dart';
import 'package:flutter_meshtastic_ble/ui/mesh_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  // Mock Meshtastic LoRa nodes discovered over BLE.
  DiscoveredDevice node(String id, String name, int rssi) => DiscoveredDevice(
        id: id,
        name: name,
        serviceData: const {},
        manufacturerData: Uint8List(0),
        rssi: rssi,
        serviceUuids: const [],
      );

  final mockDevices = <DiscoveredDevice>[
    node('AA:BB:CC:11:22:33', 'Meshtastic_Gate', -52),
    node('AA:BB:CC:44:55:66', 'T-Beam_North', -67),
    node('AA:BB:CC:77:88:99', 'Heltec_Field', -74),
    node('AA:BB:CC:AA:BB:CC', 'RAK_Checkpoint', -88),
  ];

  final mockPackets = <MeshPacket>[
    MeshPacket(
        fromNode: 0xA1B2C3D4,
        toNode: 0,
        participantId: 4821,
        ts: DateTime(2026, 6, 12, 10, 14, 03),
        rssi: -71,
        snr: 9),
    MeshPacket(
        fromNode: 0x5566AABB,
        toNode: 0,
        participantId: 1097,
        ts: DateTime(2026, 6, 12, 10, 13, 41),
        rssi: -83,
        snr: 6),
    MeshPacket(
        fromNode: 0x0099EE11,
        toNode: 0,
        participantId: 3350,
        ts: DateTime(2026, 6, 12, 10, 13, 12),
        rssi: -90,
        snr: 4),
  ];

  Widget app(Key key, Widget home) => ProviderScope(
        key: key,
        overrides: [
          scanProvider.overrideWith((ref) => Stream.value(mockDevices)),
          receivedPacketsProvider
              .overrideWith((ref) => Stream.value(mockPackets)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF67C28D),
            brightness: Brightness.dark,
          ),
          home: home,
        ),
      );

  testWidgets('capture meshtastic ble flow', (tester) async {
    // 01 - Node scan list (BLE scan overridden with mock Meshtastic nodes).
    await tester.pumpWidget(app(const ValueKey('scan'), const _ReadyScan()));
    await tester.pumpAndSettle();
    await shoot(tester, '01-node-scan');

    // 02 - Mesh screen with live received participant-ID packets.
    await tester.pumpWidget(app(
        const ValueKey('mesh'), const MeshScreen(deviceName: 'Meshtastic_Gate')));
    await tester.pumpAndSettle();
    await shoot(tester, '02-mesh-log');

    // 03 - Composing a participant-ID broadcast (pre-filled field + log).
    await tester.pumpWidget(app(const ValueKey('compose'),
        const _ComposingMesh(deviceName: 'Meshtastic_Gate')));
    await tester.pumpAndSettle();
    await shoot(tester, '03-broadcast');
  });
}

/// Mirrors [MeshScreen] but seeds the participant-ID field with a value so the
/// broadcast-compose state renders without driving the simulator soft keyboard.
class _ComposingMesh extends ConsumerWidget {
  final String deviceName;
  const _ComposingMesh({required this.deviceName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packets = ref.watch(receivedPacketsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(deviceName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: '7042'),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Participant ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Broadcast'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Received packets',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Expanded(
            child: packets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  return ListTile(
                    leading: const Icon(Icons.cell_tower),
                    title: Text('ID ${p.participantId}'),
                    subtitle: Text(
                        'from 0x${p.fromNode.toRadixString(16)} • ${p.ts.toLocal()}'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps [ScanScreen]'s populated state without the runtime BLE permission
/// gate (permission_handler has no simulator backend), so the scan list of
/// mock Meshtastic nodes renders directly.
class _ReadyScan extends ConsumerWidget {
  const _ReadyScan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meshtastic Nodes')),
      body: scan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Scan error: $e')),
        data: (devices) => ListView.separated(
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = devices[i];
            return ListTile(
              leading: const Icon(Icons.radio),
              title: Text(d.name.isEmpty ? 'Meshtastic' : d.name),
              subtitle: Text('${d.id} • ${d.rssi} dBm'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        ),
      ),
    );
  }
}
