# Screenshot capture flow

Real captures from the iOS Simulator via an integration-test driver (no mockups).

## Steps

1. Boot the simulator:
   ```bash
   xcrun simctl boot "iPhone 17 Pro Max"
   open -a Simulator
   ```
2. Scaffold the iOS platform folder (if missing) and get dependencies:
   ```bash
   flutter create . --platforms=ios --project-name flutter_meshtastic_ble
   flutter pub get
   ```
3. Drive the screenshot test:
   ```bash
   flutter drive \
     --driver test_driver/integration_test.dart \
     --target integration_test/screenshot_test.dart \
     -d "iPhone 17 Pro Max"
   ```
4. Build the demo GIF from the PNGs:
   ```bash
   cd screenshots
   ffmpeg -y -framerate 1 -pattern_type glob -i '*.png' \
     -vf "scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
     -loop 0 demo.gif
   ```

PNGs + `demo.gif` are written to `screenshots/` and embedded in `README.md`.

## How it works

- `test_driver/integration_test.dart` - `integrationDriver(onScreenshot:)` writes each PNG to `screenshots/<name>.png`.
- `integration_test/screenshot_test.dart` - the app's BLE-backed Riverpod streams are replaced with `ProviderScope` overrides so the screens render real-looking content without any radio hardware:
  - `scanProvider` is overridden with a list of mock Meshtastic LoRa nodes (Meshtastic_Gate, T-Beam_North, Heltec_Field, RAK_Checkpoint) with RSSI values, captured as `01-node-scan`.
  - `receivedPacketsProvider` is overridden with mock decoded participant-ID packets (node, id, timestamp) and the `MeshScreen` is pumped to capture the live mesh log as `02-mesh-log`.
  - A compose variant of the mesh screen seeds the Participant ID field to capture the broadcast-compose state as `03-broadcast` (the BLE permission gate and the simulator soft keyboard are bypassed - the simulator has no BLE or keyboard backend).
  - Each step pumps a fresh `ProviderScope` (keyed) and calls `binding.convertFlutterSurfaceToImage()` + `binding.takeScreenshot('NN-name')`.
