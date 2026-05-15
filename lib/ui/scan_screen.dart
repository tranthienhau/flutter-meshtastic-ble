import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/mesh_store.dart';
import 'mesh_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _request();
  }

  Future<void> _request() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scan = ref.watch(scanProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Meshtastic Nodes')),
      body: scan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Scan error: $e')),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('Scanning for Meshtastic devices...'));
          }
          return ListView.separated(
            itemCount: devices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = devices[i];
              return ListTile(
                leading: const Icon(Icons.radio),
                title: Text(d.name.isEmpty ? 'Meshtastic' : d.name),
                subtitle: Text('${d.id} • ${d.rssi} dBm'),
                onTap: () async {
                  final c = ref.read(meshClientProvider);
                  await c.connect(d.id);
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MeshScreen(deviceName: d.name)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
