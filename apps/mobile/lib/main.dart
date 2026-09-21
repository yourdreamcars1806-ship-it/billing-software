import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'features/business_selection/providers/business_provider.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate600, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Paint first frame immediately — avoids stuck black splash while Supabase boots.
  runApp(const ProviderScope(child: _BootstrapApp()));
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  Object? _initError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      ).timeout(const Duration(seconds: 12));
    } catch (e, st) {
      debugPrint('Supabase init failed: $e\n$st');
      if (mounted) {
        setState(() => _initError = e);
      }
      return;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 52, color: AppColors.error),
                  const SizedBox(height: 14),
                  const Text(
                    'Could not connect',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _initError.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.slate600),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initError = null;
                        _ready = false;
                      });
                      _boot();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(
          backgroundColor: Color(0xFFF3F4F6),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 16),
                Text(
                  'Starting Billing Atelier…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const BillingApp();
  }
}

class BillingApp extends ConsumerStatefulWidget {
  const BillingApp({super.key});

  @override
  ConsumerState<BillingApp> createState() => _BillingAppState();
}

class _BillingAppState extends ConsumerState<BillingApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeBusinessProvider.notifier).loadSavedBusiness();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final businessType = ref.watch(
      activeBusinessProvider.select((b) => b?.businessType),
    );

    return MaterialApp.router(
      title: 'Billing Atelier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(businessType),
      routerConfig: router,
    );
  }
}
