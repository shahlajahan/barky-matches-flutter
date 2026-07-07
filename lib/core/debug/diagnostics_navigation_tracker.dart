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

class DiagnosticsRouteMetadata {
  const DiagnosticsRouteMetadata({
    required this.feature,
    required this.screenName,
    required this.routeName,
    required this.widgetName,
  });

  final String feature;
  final String screenName;
  final String routeName;
  final String widgetName;
}

class DiagnosticsRouteSettings extends RouteSettings {
  const DiagnosticsRouteSettings({
    required this.metadata,
    super.name,
    super.arguments,
  });

  final DiagnosticsRouteMetadata metadata;
}

class DiagnosticsPageRoute<T> extends MaterialPageRoute<T> {
  DiagnosticsPageRoute({
    required Widget page,
    required DiagnosticsRouteMetadata metadata,
    Object? arguments,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
  }) : super(
         builder: (_) => page,
         settings: DiagnosticsRouteSettings(
           metadata: metadata,
           name: metadata.routeName,
           arguments: arguments,
         ),
       );
}

class DiagnosticsTrackedScreen {
  const DiagnosticsTrackedScreen({
    required this.route,
    required this.screenName,
    required this.feature,
    required this.widgetName,
  });

  final String route;
  final String screenName;
  final String feature;
  final String widgetName;
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
  DiagnosticsTrackedScreen _currentTrackedScreen =
      const DiagnosticsTrackedScreen(
        route: 'unknown',
        screenName: 'unknown',
        feature: 'unknown',
        widgetName: 'unknown',
      );
  Route<dynamic>? _activeRoute;
  int _updateGeneration = 0;

  DiagnosticsScreenInfo get currentScreen => _currentScreen;
  DiagnosticsTrackedScreen get currentTrackedScreen => _currentTrackedScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(route, refreshAfterBuild: true);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(previousRoute, refreshAfterBuild: true);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _updateFromRoute(newRoute, refreshAfterBuild: true);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _updateFromRoute(previousRoute, refreshAfterBuild: true);
    super.didRemove(route, previousRoute);
  }

  void _updateFromRoute(
    Route<dynamic>? route, {
    bool refreshAfterBuild = false,
  }) {
    if (route == null) {
      return;
    }

    _activeRoute = route;
    final DiagnosticsRouteMetadata? metadata = _routeMetadata(route);
    if (metadata != null) {
      _setCurrentScreen(
        route: metadata.routeName,
        screenName: metadata.screenName,
        feature: metadata.feature,
        widgetName: metadata.widgetName,
      );

      if (refreshAfterBuild) {
        _schedulePostFrameRouteRefresh(route);
      }
      return;
    }

    final DiagnosticsScreenDescriptor? descriptor = _screenDescriptor(route);
    final String? routeWidgetName = _routeWidgetName(route);
    final String screenName = _resolveScreenName(
      route,
      descriptor,
      routeWidgetName,
    );
    final String routeName = _resolveRouteName(route, screenName);
    final String feature = _resolveFeature(
      route,
      routeName,
      screenName,
      descriptor,
      routeWidgetName,
    );

    _setCurrentScreen(
      route: routeName,
      screenName: screenName,
      feature: feature,
      widgetName: routeWidgetName ?? 'unknown',
    );

    if (refreshAfterBuild) {
      _schedulePostFrameRouteRefresh(route);
    }
  }

  void _setCurrentScreen({
    required String route,
    required String screenName,
    required String feature,
    required String widgetName,
  }) {
    _currentScreen = DiagnosticsScreenInfo(
      route: route,
      screenName: screenName,
      feature: feature,
    );
    _currentTrackedScreen = DiagnosticsTrackedScreen(
      route: route,
      screenName: screenName,
      feature: feature,
      widgetName: widgetName,
    );
  }

  DiagnosticsRouteMetadata? _routeMetadata(Route<dynamic> route) {
    final RouteSettings settings = route.settings;
    if (settings is DiagnosticsRouteSettings) {
      return settings.metadata;
    }

    return null;
  }

  void _schedulePostFrameRouteRefresh(Route<dynamic> route) {
    final int generation = ++_updateGeneration;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_activeRoute != route || generation != _updateGeneration) {
        return;
      }

      if (!route.isCurrent) {
        return;
      }

      _updateFromRoute(route);
    });
  }

  String _resolveRouteName(Route<dynamic> route, String screenName) {
    final String? explicitName = route.settings.name;
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return explicitName.trim();
    }

    final String? descriptorRouteName = _screenDescriptor(
      route,
    )?.diagnosticsRouteName?.trim();
    if (descriptorRouteName != null && descriptorRouteName.isNotEmpty) {
      return descriptorRouteName;
    }

    if (screenName == 'unknown') {
      return 'unknown';
    }

    return _routeNameFromScreenName(screenName);
  }

  String _resolveScreenName(
    Route<dynamic> route,
    DiagnosticsScreenDescriptor? descriptor,
    String? routeWidgetName,
  ) {
    final String? explicitName = route.settings.name;
    if (explicitName != null && explicitName.trim().isNotEmpty) {
      return _screenNameFromRouteName(explicitName);
    }

    final String descriptorScreenName = _sanitizeTypeName(
      descriptor?.diagnosticsScreenName,
    );
    if (descriptorScreenName != 'unknown') {
      return descriptorScreenName;
    }

    final String widgetScreenName = _sanitizeTypeName(routeWidgetName);
    if (widgetScreenName != 'unknown') {
      return _screenNameFromWidgetName(widgetScreenName);
    }

    return _sanitizeTypeName(route.runtimeType.toString());
  }

  String _resolveFeature(
    Route<dynamic> route,
    String routeName,
    String screenName,
    DiagnosticsScreenDescriptor? descriptor,
    String? routeWidgetName,
  ) {
    final String? descriptorFeature = descriptor?.diagnosticsFeature?.trim();
    if (descriptorFeature != null && descriptorFeature.isNotEmpty) {
      return descriptorFeature;
    }

    final String routeFeature = _featureFromRouteName(routeName);
    if (routeFeature.isNotEmpty) {
      return routeFeature;
    }

    final String widgetFeature = _featureFromScreenName(
      routeWidgetName ?? screenName,
    );
    if (widgetFeature.isNotEmpty) {
      return widgetFeature;
    }

    if (!route.isFirst) {
      if (screenName == 'unknown') {
        return 'unknown';
      }

      return screenName;
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
      return widget as DiagnosticsScreenDescriptor;
    }

    return null;
  }

  String? _routeWidgetName(Route<dynamic> route) {
    final BuildContext? subtreeContext = route is ModalRoute<dynamic>
        ? route.subtreeContext
        : null;
    if (subtreeContext == null) {
      return null;
    }

    final Widget rootWidget = subtreeContext.widget;
    final String rootWidgetName = _candidateWidgetName(rootWidget);
    if (rootWidgetName != 'unknown') {
      return rootWidgetName;
    }

    if (subtreeContext is! Element) {
      return null;
    }

    return _firstPageWidgetName(subtreeContext);
  }

  String? _firstPageWidgetName(Element root) {
    String? result;

    void visit(Element element) {
      if (result != null) {
        return;
      }

      final String widgetName = _candidateWidgetName(element.widget);
      if (widgetName != 'unknown') {
        result = widgetName;
        return;
      }

      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);

    return result;
  }

  String _candidateWidgetName(Widget widget) {
    final String widgetName = _sanitizeTypeName(widget.runtimeType.toString());
    if (widgetName == 'unknown' ||
        _isFrameworkRouteWidget(widgetName) ||
        !_isPageWidgetName(widgetName)) {
      return 'unknown';
    }

    return widgetName;
  }

  bool _isPageWidgetName(String widgetName) {
    return widgetName.endsWith('Page') ||
        widgetName.endsWith('Screen') ||
        widgetName.endsWith('View') ||
        widgetName.endsWith('Dashboard');
  }

  bool _isFrameworkRouteWidget(String widgetName) {
    return widgetName.startsWith('_') ||
        widgetName == 'Builder' ||
        widgetName == 'Offstage' ||
        widgetName == 'PageStorage' ||
        widgetName == 'FocusScope' ||
        widgetName == 'RepaintBoundary' ||
        widgetName == 'Semantics' ||
        widgetName == 'AnimatedBuilder' ||
        widgetName == 'PrimaryScrollController' ||
        widgetName == 'Actions' ||
        widgetName == 'Shortcuts' ||
        widgetName == 'HeroControllerScope' ||
        widgetName == 'Overlay' ||
        widgetName == 'Navigator' ||
        widgetName == 'Scaffold' ||
        widgetName == 'Material' ||
        widgetName == 'MediaQuery' ||
        widgetName == 'SafeArea';
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

  String _routeNameFromScreenName(String screenName) {
    final String snakeName = _screenNameFromWidgetName(screenName);
    if (snakeName.isEmpty) {
      return 'unknown';
    }

    return '/${snakeName.replaceAll('_', '/')}';
  }

  String _screenNameFromWidgetName(String widgetName) {
    return _snakeCase(widgetName)
        .replaceFirst(RegExp(r'_page$'), '')
        .replaceFirst(RegExp(r'_screen$'), '')
        .replaceFirst(RegExp(r'_view$'), '');
  }

  String _featureFromRouteName(String routeName) {
    final String trimmed = routeName.trim();
    if (trimmed.isEmpty || trimmed == 'unknown') {
      return '';
    }

    final List<String> segments = trimmed
        .split('/')
        .where((String segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return '';
    }

    return _featureFromScreenName(segments.first);
  }

  String _featureFromScreenName(String screenName) {
    final String snakeName = _snakeCase(screenName);
    if (snakeName.isEmpty || snakeName == 'unknown') {
      return '';
    }

    return snakeName.split('_').first;
  }

  String _sanitizeTypeName(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return 'unknown';
    }

    return normalized.replaceFirst(RegExp(r'^_+'), '');
  }

  String _snakeCase(String value) {
    final String sanitized = _sanitizeTypeName(value);
    if (sanitized == 'unknown') {
      return '';
    }

    return sanitized
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (Match match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
  }
}
