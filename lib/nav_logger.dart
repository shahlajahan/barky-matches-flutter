import 'package:flutter/material.dart';

class NavLogger extends NavigatorObserver {
  void _log(String action, Route<dynamic>? route, Route<dynamic>? previousRoute) {
    debugPrint('🧭 $action: ${route?.settings.name ?? route.runtimeType} '
        'from ${previousRoute?.settings.name ?? previousRoute.runtimeType}');
  }

  @override
  void didPush(Route route, Route? previousRoute) => _log('PUSH', route, previousRoute);

  @override
  void didPop(Route route, Route? previousRoute) => _log('POP', route, previousRoute);

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) =>
      _log('REPLACE', newRoute, oldRoute);

  @override
  void didRemove(Route route, Route? previousRoute) => _log('REMOVE', route, previousRoute);
}
