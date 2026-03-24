import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'dog.dart';
import 'playmate_page.dart';
import 'play_date_scheduling_page.dart';

class PlaydateFlowRouter extends StatefulWidget {
  const PlaydateFlowRouter({super.key});

  @override
  State<PlaydateFlowRouter> createState() => _PlaydateFlowRouterState();
}

class _PlaydateFlowRouterState extends State<PlaydateFlowRouter> {
  String? _lastParkKey;
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = context.read<AppState>();
    final park = appState.pendingPlaydatePark;

    if (park == null) return;

    // ✅ یک کلید پایدار برای تشخیص تغییر پارک
    final parkKey = (park['name'] ?? '').toString();
    if (parkKey.isEmpty) return;

    // اگر همون پارکه، دوباره اجرا نکن
    if (_lastParkKey == parkKey) return;

    _lastParkKey = parkKey;

    // جلوگیری از دوبار اجرا شدن پشت سر هم
    if (_running) return;
    _running = true;

    final List<Dog> myDogs = appState.allDogs
        .where((d) => d.ownerId == appState.currentUserId)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
  debugPrint('🚦 PlaydateFlowRouter started for park=$parkKey');

  try {
    // ✅ گزینه 1: اگر می‌خوای کلاً از DogPark مستقیم بره Scheduling
    final bool skipPlaymateStep = true;

    // ✅ گزینه 2: یا فقط وقتی انتخاب سگ قبلاً انجام شده، Playmate رو skip کن
    final bool alreadyHasRequesterDog =
        (appState.selectedRequesterDogId != null &&
         appState.selectedRequesterDogId!.isNotEmpty);

    if (!skipPlaymateStep && !alreadyHasRequesterDog) {
      final Dog? selectedDog = await Navigator.push<Dog>(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: SafeArea(
              child: PlaymatePage(
                dogs: myDogs,
                currentUserId: appState.currentUserId!,
                favoriteDogs: appState.favoriteDogs,
                onToggleFavorite: appState.onToggleFavorite,
                mode: PlaymatePageMode.selectDogForPlaydate,
              ),
            ),
          ),
        ),
      );

      if (!mounted) return;

      if (selectedDog == null) {
        debugPrint('❌ PlaydateFlow cancelled');
        appState.clearPlaydateFlow();
        return;
      }

      // اگر می‌خوای انتخاب سگ تو Scheduling هم sync بشه:
      // appState.selectedRequesterDogId = selectedDog.id;  // فقط اگر این فیلد ست‌پذیره
    }

    // ✅ مستقیم برو Scheduling
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlayDateSchedulingPage(),
      ),
    );

    if (!mounted) return;

    debugPrint('✅ PlaydateFlow finished');
    appState.clearPlaydateFlow();
  } finally {
    _running = false;
  }
});
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

}