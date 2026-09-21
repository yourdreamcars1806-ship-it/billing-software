import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'escpos_receipt_builder.dart';

const _prefMac = 'bt_printer_mac';
const _prefName = 'bt_printer_name';

final bluetoothPrinterServiceProvider = Provider<BluetoothPrinterService>((ref) {
  return BluetoothPrinterService();
});

class BluetoothPrinterService {
  String? _savedMac;
  String? _savedName;

  String? get savedMac => _savedMac;
  String? get savedName => _savedName;

  Future<void> loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    _savedMac = prefs.getString(_prefMac);
    _savedName = prefs.getString(_prefName);
  }

  Future<void> rememberPrinter({
    required String mac,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMac, mac);
    await prefs.setString(_prefName, name);
    _savedMac = mac;
    _savedName = name;
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefMac);
    await prefs.remove(_prefName);
    _savedMac = null;
    _savedName = null;
    await disconnect();
  }

  /// Android 12+ needs a runtime prompt for Nearby devices.
  /// print_bluetooth_thermal only *checks* permission — it does not request it.
  Future<bool> ensurePermissions({bool openSettingsIfDenied = false}) async {
    if (!Platform.isAndroid) {
      return PrintBluetoothThermal.isPermissionBluetoothGranted;
    }

    final toRequest = <Permission>[
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (final p in toRequest) {
      statuses[p] = await p.status;
    }

    final needAsk = statuses.entries.any(
      (e) => e.value.isDenied || e.value.isRestricted,
    );
    if (needAsk) {
      statuses = await toRequest.request();
    }

    final connectOk =
        statuses[Permission.bluetoothConnect]?.isGranted == true;
    final scanStatus = statuses[Permission.bluetoothScan];
    final scanOk =
        scanStatus?.isGranted == true || scanStatus?.isLimited == true;

    // Older Android (<12): CONNECT/SCAN map to granted automatically.
    var ok = connectOk && scanOk;
    if (!ok) {
      // Fallback — package check (true below API 31).
      ok = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    }

    if (!ok && openSettingsIfDenied) {
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      if (permanentlyDenied) {
        await openAppSettings();
      }
    }

    return ok;
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  Future<bool> isConnected() => PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> pairedDevices() async {
    final ok = await ensurePermissions(openSettingsIfDenied: true);
    if (!ok) {
      throw StateError(
        'Bluetooth permission denied. Tap "Allow Bluetooth" or enable Nearby devices in App Settings.',
      );
    }
    final on = await isBluetoothOn();
    if (!on) {
      throw StateError(
        'Bluetooth is off. Turn on Bluetooth, then pull to refresh.',
      );
    }
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list;
  }

  Future<bool> connect(String mac) async {
    final ok = await ensurePermissions(openSettingsIfDenied: true);
    if (!ok) return false;
    if (!await isBluetoothOn()) return false;

    final connected = await PrintBluetoothThermal.connectionStatus;
    if (connected) {
      final current = _savedMac;
      if (current == mac) return true;
      await PrintBluetoothThermal.disconnect;
    }
    return PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  /// Connect (saved or given MAC) and print ESC/POS bytes.
  Future<void> printReceipt({
    required List<int> bytes,
    String? mac,
    String? name,
  }) async {
    final targetMac = mac ?? _savedMac;
    if (targetMac == null || targetMac.isEmpty) {
      throw StateError(
        'No printer selected. Pair printer in phone Bluetooth, then choose it in Settings.',
      );
    }

    final ok = await ensurePermissions(openSettingsIfDenied: true);
    if (!ok) {
      throw StateError(
        'Bluetooth permission denied. Allow Nearby devices for this app.',
      );
    }
    if (!await isBluetoothOn()) {
      throw StateError('Turn on Bluetooth first.');
    }

    var linked = await PrintBluetoothThermal.connectionStatus;
    if (!linked) {
      linked = await connect(targetMac);
    }
    if (!linked) {
      throw StateError(
        'Could not connect to printer. Pair it in phone Bluetooth settings first.',
      );
    }

    if (name != null && name.isNotEmpty) {
      await rememberPrinter(mac: targetMac, name: name);
    } else if (_savedMac != targetMac) {
      await rememberPrinter(mac: targetMac, name: _savedName ?? 'Printer');
    }

    final sent = await PrintBluetoothThermal.writeBytes(bytes);
    if (!sent) {
      throw StateError('Print failed. Check paper and printer power.');
    }
  }

  Future<List<int>> buildInvoiceBytes(EscPosReceiptData data) {
    return EscPosReceiptBuilder().build(data);
  }
}
