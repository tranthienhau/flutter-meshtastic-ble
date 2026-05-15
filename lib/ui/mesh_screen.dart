import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mesh_store.dart';

class MeshScreen extends ConsumerStatefulWidget {
  final String deviceName;
  const MeshScreen({super.key, required this.deviceName});

  @override
  ConsumerState<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends ConsumerState<MeshScreen> {
  final _idCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final packets = ref.watch(receivedPacketsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName.isEmpty ? 'Mesh' : widget.deviceName),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idCtrl,
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
                  onPressed: () async {
                    final id = int.tryParse(_idCtrl.text);
                    if (id == null) return;
                    await ref
                        .read(meshClientProvider)
                        .sendParticipantId(id);
                    _idCtrl.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Broadcast id $id over LoRa')),
                      );
                    }
                  },
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
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                      child: Text('Waiting for mesh traffic...'));
                }
                return ListView.builder(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
