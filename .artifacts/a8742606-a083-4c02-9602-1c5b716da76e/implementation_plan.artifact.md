# Implementation Plan - Fix Bluetooth Permissions

This plan addresses the "Bluetooth permission missing in manifest" error by correctly declaring permissions in `AndroidManifest.xml`, ensuring `minSdkVersion` is compatible, and refining the runtime permission request logic.

## User Review Required

> [!IMPORTANT]
> - After applying these changes, you **must** uninstall the app from your device and run `flutter clean` followed by `flutter run`. This is necessary because permission changes in the manifest often do not take effect when simply hot-reloading or re-installing over an existing build.

## Proposed Changes

### [Component: Android Configuration]

#### [MODIFY] [AndroidManifest.xml](file:///run/media/tienpham/App/flutter_newcar/android/app/src/main/AndroidManifest.xml)
- Add `xmlns:tools="http://schemas.android.com/tools"` to the `<manifest>` tag.
- Add comprehensive Bluetooth and Location permissions:
    - `BLUETOOTH_SCAN` (with `neverForLocation` flag for Android 12+).
    - `BLUETOOTH_CONNECT` (Android 12+).
    - `BLUETOOTH` and `BLUETOOTH_ADMIN` (maxSdkVersion 30).
    - `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`.
- Add `android.hardware.bluetooth_le` feature.

#### [MODIFY] [build.gradle.kts](file:///run/media/tienpham/App/flutter_newcar/android/app/build.gradle.kts)
- Explicitly set `minSdk = 21` to ensure compatibility with `flutter_blue_plus`.

### [Component: UI - Pairing]

#### [MODIFY] [pair_device_screen.dart](file:///run/media/tienpham/App/flutter_newcar/lib/screens/driver/pair_device_screen.dart)
- Update `_startScan` to handle version-specific permissions:
    - Use `device_info_plus` (if available) or check `Platform` to determine Android version.
    - Request `bluetoothScan` and `bluetoothConnect` on Android 12+ (API 31+).
    - Request `location` on Android 11 and below.
- Add logic to show a dialog or SnackBar with "Open Settings" instructions if permissions are permanently denied.
- Add `debugPrint` logs for each permission status.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no syntax errors.

### Manual Verification
1. **Uninstall App:** Remove FloodGuard from the test device.
2. **Clean & Build:** Run `flutter clean` and `flutter run`.
3. **Permissions Flow:**
    - On Android 12+, verify that the app asks for "Nearby devices" (Scan/Connect).
    - On Android 11-, verify that the app asks for "Location".
4. **Scan:** Verify that the "Bluetooth permission missing" error no longer appears in logs and scanning starts successfully.
