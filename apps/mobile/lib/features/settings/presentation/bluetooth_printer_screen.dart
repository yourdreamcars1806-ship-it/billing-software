import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../theme/app_colors.dart';
import '../../business_selection/providers/business_provider.dart';
import '../../../services/bluetooth_printer_service.dart';

class BluetoothPrinterScreen extends ConsumerStatefulWidget {
  const BluetoothPrinterScreen({super.key});

  @override
  ConsumerState<BluetoothPrinterScreen> createState() =>
      _BluetoothPrinterScreenState();
}

class _BluetoothPrinterScreenState
    extends ConsumerState<BluetoothPrinterScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<BluetoothInfo> _devices = [];
  bool _connected = false;
  bool _btOn = false;
  bool _permOk = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final svc = ref.read(bluetoothPrinterServiceProvider);
    await svc.loadSavedPrinter();
    // Ask permission as soon as this screen opens.
    await svc.ensurePermissions();
    await _refresh();
  }

  Future<void> _requestPermission() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(bluetoothPrinterServiceProvider);
      final ok = await svc.ensurePermissions(openSettingsIfDenied: true);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error =
              'Permission still denied. Open App Settings → Permissions → Nearby devices → Allow.';
        });
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(bluetoothPrinterServiceProvider);
      final permOk = await svc.ensurePermissions();
      final btOn = await svc.isBluetoothOn();
      List<BluetoothInfo> devices = [];
      var connected = false;
      if (permOk && btOn) {
        devices = await svc.pairedDevices();
        connected = await svc.isConnected();
      }
      if (!mounted) return;
      setState(() {
        _permOk = permOk;
        _btOn = btOn;
        _devices = devices;
        _connected = connected;
        _loading = false;
        if (!permOk) {
          _error =
              'Bluetooth permission needed. Tap Allow Bluetooth below.';
        } else if (!btOn) {
          _error = 'Bluetooth is off. Turn it on in phone settings, then refresh.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _loading = false;
        _devices = [];
      });
    }
  }

  Future<void> _connect(BluetoothInfo device) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = ref.read(bluetoothPrinterServiceProvider);
      final perm = await svc.ensurePermissions(openSettingsIfDenied: true);
      if (!perm) {
        throw StateError('Bluetooth permission denied.');
      }
      if (!await svc.isBluetoothOn()) {
        throw StateError('Turn on Bluetooth first.');
      }
      final ok = await svc.connect(device.macAdress);
      if (!ok) throw StateError('Connect failed. Is the printer paired and on?');
      await svc.rememberPrinter(mac: device.macAdress, name: device.name);
      final connected = await svc.isConnected();
      if (!mounted) return;
      setState(() => _connected = connected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected · ${device.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    try {
      await ref.read(bluetoothPrinterServiceProvider).disconnect();
      if (!mounted) return;
      setState(() => _connected = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forget() async {
    setState(() => _busy = true);
    try {
      await ref.read(bluetoothPrinterServiceProvider).clearSavedPrinter();
      if (!mounted) return;
      setState(() => _connected = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved printer cleared')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final brand = AppColors.brand(business?.businessType);
    final svc = ref.watch(bluetoothPrinterServiceProvider);

    return Stack(
      children: [
        AppScaffold(
          title: 'Bluetooth printer',
          showBusinessSwitcher: false,
          fallbackRoute: '/settings',
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const DeskHeader(
                  title: 'Bluetooth printer',
                  subtitle: '80mm thermal · pair in phone Bluetooth first',
                ),
                const SizedBox(height: 14),
                SoftSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _connected ? 'Connected' : 'Not connected',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _connected
                              ? AppColors.success
                              : AppColors.slate700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        svc.savedName != null
                            ? '${svc.savedName} · ${svc.savedMac ?? ''}'
                            : 'No saved printer yet',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.slate500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Permission: ${_permOk ? 'Allowed' : 'Denied'} · Bluetooth: ${_btOn ? 'On' : 'Off'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _permOk && _btOn
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_permOk)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _busy ? null : _requestPermission,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Allow Bluetooth'),
                        ),
                      if (!_permOk) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await openAppSettings();
                                },
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Open App Settings'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_connected)
                            TextButton(
                              onPressed: _busy ? null : _disconnect,
                              child: const Text('Disconnect'),
                            ),
                          if (svc.savedMac != null)
                            TextButton(
                              onPressed: _busy ? null : _forget,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              child: const Text('Forget'),
                            ),
                          const Spacer(),
                          IconButton(
                            onPressed: _busy || _loading ? null : _refresh,
                            icon: Icon(Icons.refresh, color: brand),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SoftSurface(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const SectionLabel('Paired devices'),
                const SizedBox(height: 8),
                const Text(
                  '1) Phone Settings → Bluetooth → pair your 80mm printer\n'
                  '2) Allow Nearby devices for this app\n'
                  '3) Tap the printer below to connect',
                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_permOk)
                  SoftSurface(
                    child: Text(
                      'Allow Bluetooth permission to see paired printers.',
                      style: TextStyle(color: brand, fontWeight: FontWeight.w600),
                    ),
                  )
                else if (_devices.isEmpty)
                  const SoftSurface(
                    child: Text(
                      'No paired Bluetooth devices found. Pair the printer in phone Bluetooth settings first.',
                      style: TextStyle(color: AppColors.slate500),
                    ),
                  )
                else
                  ..._devices.map((d) {
                    final selected = svc.savedMac == d.macAdress;
                    return SoftSurface(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: IconBadge(
                          icon: Icons.print_outlined,
                          color: selected ? brand : AppColors.slate500,
                          size: 40,
                        ),
                        title: Text(
                          d.name.isEmpty ? 'Unknown printer' : d.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          d.macAdress,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                          ),
                        ),
                        trailing: selected && _connected
                            ? Icon(Icons.check_circle, color: brand)
                            : TextButton(
                                onPressed: _busy ? null : () => _connect(d),
                                child: Text(
                                  selected ? 'Reconnect' : 'Connect',
                                ),
                              ),
                        onTap: _busy ? null : () => _connect(d),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        LoadingOverlay(
          isVisible: _busy,
          message: 'Working…',
        ),
      ],
    );
  }
}
