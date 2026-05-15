import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh_client.dart';
import 'mesh_protocol.dart';

final meshClientProvider = Provider<MeshClient>((ref) {
  final c = MeshClient();
  ref.onDispose(c.dispose);
  return c;
});

final scanProvider = StreamProvider.autoDispose<List<DiscoveredDevice>>((ref) {
  final c = ref.watch(meshClientProvider);
  final found = <String, DiscoveredDevice>{};
  final ctrl = StreamController<List<DiscoveredDevice>>();
  final sub = c.scan().listen((d) {
    found[d.id] = d;
    ctrl.add(found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi)));
  });
  ref.onDispose(() {
    sub.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});

final receivedPacketsProvider =
    StreamProvider.autoDispose<List<MeshPacket>>((ref) {
  final c = ref.watch(meshClientProvider);
  final list = <MeshPacket>[];
  final ctrl = StreamController<List<MeshPacket>>();
  final sub = c.packets.listen((p) {
    list.insert(0, p);
    if (list.length > 100) list.removeLast();
    ctrl.add(List.unmodifiable(list));
  });
  ref.onDispose(() {
    sub.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});
