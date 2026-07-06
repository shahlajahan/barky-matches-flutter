import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../ui/shell/nav_tab.dart';
import 'diagnostics_report.dart';

abstract class DiagnosticsScreenDescriptor {
  const DiagnosticsScreenDescriptor();

  String get diagnosticsScreenName;

  String? get diagnosticsFeature => null;

  String? get diagnosticsRouteName => null;
}

class DiagnosticsNavigationTracker extends NavigatorObserver {
  factory DiagnosticsNavigationTracker() => _instance;

  DiagnosticsNavigationTracker._();

  static final DiagnosticsNavigationTracker _instance =
      DiagnosticsNavigationTracker._();

  DiagnosticsScreenInfo _currentScreen = const DiagnosticsScreenInfo(
    route: 'unknown',
    screenName: 'unknown',
    feature: 'unknown',
  );

  DiagnosticsScreenInfo get currentScreen => _currentScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateFromRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(previousRoute);
    super.didRemove(route, previousRoute);
  }

  void _updateFromRoute(Route<dynamic>? route) {
    if (route == null) {
      return;
    }

    final DiagnosticsScreenDescriptor? descriptor = _screenDescriptor(route);
    final String screenName = _resolveScreenName(route, descriptor);
    final String routeName = _resolveRouteName(route, screenName);
    final String feature = _resolveFeature(route, screenName, descriptor);

    _currentScreen = DiagnosticsScreenInfo(
      route: routeName,
      screenName: screenName,
      feature: feature,
    );
  }

  String _resolveRouteName(Route<dynamic> route, String screenName) {
    final String? explicitName = route.settings.name;
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }

    final String? descriptorRouteName = _screenDescriptor(route)
        ?.diagnosticsRouteName
        ?.trim();
    if (descriptorRouteName != null && descriptorRouteName.isNotEmpty) {
      return descriptorRouteName;
    }

    if (screenName == 'unknown') {
      return 'unknown';
    }

    return '/$screenName';
  }

  String _resolveScreenName(
    Route<dynamic> route,
    DiagnosticsScreenDescriptor? descriptor,
  ) {
    final String? explicitName = route.settings.name;
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return _screenNameFromRouteName(explicitName);
    }

    final String descriptorScreenName =
        _sanitizeTypeName(descriptor?.diagnosticsScreenName);
    if (descriptorScreenName != 'unknown') {
      return descriptorScreenName;
    }

    return _sanitizeTypeName(route.runtimeType.toString());
  }

  String _resolveFeature(
    Route<dynamic> route,
    String screenName,
    DiagnosticsScreenDescriptor? descriptor,
  ) {
    final String? descriptorFeature = descriptor?.diagnosticsFeature?.trim();
    if (descriptorFeature != null && descriptorFeature.isNotEmpty) {
      return descriptorFeature;
    }

    final BuildContext? navigatorContext = route.navigator?.context;
    if (navigatorContext != null) {
      try {
        final AppState appState = navigatorContext.read<AppState>();
        final String feature = _featureFromAppState(appState);
        if (feature.isNotEmpty) {
          return feature;
        }
      } catch (_) {
        // Diagnostics context collection must not fail report creation.
      }
    }

    if (screenName == 'unknown') {
      return 'unknown';
    }

    return screenName;
  }

  DiagnosticsScreenDescriptor? _screenDescriptor(Route<dynamic> route) {
    final BuildContext? subtreeContext = route is ModalRoute<dynamic>
        ? route.subtreeContext
        : null;
    final Widget? widget = subtreeContext?.widget;

    if (widget is DiagnosticsScreenDescriptor) {
      return widget;
    }

    return null;
  }

  String _featureFromAppState(AppState appState) {
    if (appState.currentTab == NavTab.profile &&
        appState.profileSubPage != ProfileSubPage.none) {
      return 'profile.${appState.profileSubPage.name}';
    }

    if (appState.currentTab != NavTab.none) {
      return appState.currentTab.name;
    }

    return '';
  }

  String _screenNameFromRouteName(String routeName) {
    final String trimmed = routeName.trim();
    if (trimmed.isEmpty) {
      return 'unknown';
    }

    final Iterable<String> segments = trimmed
        .split('/')
        .where((String segment) => segment.trim().isNotEmpty);
    if (segments.isEmpty) {
      return trimmed == '/' ? 'root' : trimmed.replaceAll('/', '');
    }

    return _sanitizeTypeName(segments.last);
  }

  String _sanitizeTypeName(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }

    return normalized.replaceFirst(RegExp(r'^_+'), '');
  }
}
