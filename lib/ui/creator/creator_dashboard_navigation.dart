enum CreatorDashboardNavigationMode { internalWeb, externalMobile }

class CreatorDashboardNavigationPlan {
  const CreatorDashboardNavigationPlan({
    required this.mode,
    required this.destination,
  });

  final CreatorDashboardNavigationMode mode;
  final String destination;
}

/// Pure decision for where "Open Full Dashboard" should go and how —
/// parameterized on `isWeb`/`webOrigin` rather than reading
/// `kIsWeb`/`Uri.base` directly, so it's unit-testable without a browser.
/// Mirrors the existing `marketplaceCheckoutPlatform` /
/// `subscriptionCheckoutPlatform` pattern in this codebase.
///
/// On Web: same-origin, same-tab — `{webOrigin}/creator/dashboard`. Never
/// a different host, never a new browsing context, so the already-
/// persisted Firebase Auth session for this origin survives.
///
/// On mobile (iOS/Android): the fixed production URL, opened externally.
/// A mobile OS browser cannot share the native app's Firebase session —
/// see `CreatorDashboardPage.productionWebDashboardUrl`'s doc comment.
CreatorDashboardNavigationPlan resolveCreatorDashboardNavigation({
  required bool isWeb,
  required String webOrigin,
  required String productionMobileDestination,
}) {
  if (isWeb) {
    return CreatorDashboardNavigationPlan(
      mode: CreatorDashboardNavigationMode.internalWeb,
      destination: '$webOrigin/creator/dashboard',
    );
  }
  return CreatorDashboardNavigationPlan(
    mode: CreatorDashboardNavigationMode.externalMobile,
    destination: productionMobileDestination,
  );
}
