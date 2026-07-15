import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/update/app_update_gate.dart';
import '../features/trip/presentation/passenger_home_page.dart';
import '../shared/theme/rapigo_theme.dart';

class RapigoPassengerApp extends ConsumerStatefulWidget {
  const RapigoPassengerApp({super.key});

  @override
  ConsumerState<RapigoPassengerApp> createState() => _RapigoPassengerAppState();
}

class _RapigoPassengerAppState extends ConsumerState<RapigoPassengerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAPIGO',
      debugShowCheckedModeBanner: false,
      theme: RapigoTheme.light(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: _StablePassengerViewport(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const PassengerAppUpdateGate(
        appId: 'rapigo_passenger',
        child: PassengerHomePage(),
      ),
    );
  }
}

class _StablePassengerViewport extends StatelessWidget {
  const _StablePassengerViewport({required this.child});

  static const double _minimumDesignWidth = 390;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width >= _minimumDesignWidth) {
          return child;
        }

        final scale = width / _minimumDesignWidth;
        final scaledHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight / scale
            : constraints.maxHeight;

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _minimumDesignWidth,
                height: scaledHeight,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
