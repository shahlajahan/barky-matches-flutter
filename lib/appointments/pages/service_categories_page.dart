import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import '../models/appointment_service.dart';
import '../services/appointment_repository.dart';
import '../widgets/appointment_service_card.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class ServiceCategoriesPage extends StatefulWidget {
  const ServiceCategoriesPage({super.key});

  @override
  State<ServiceCategoriesPage> createState() => _ServiceCategoriesPageState();
}

class _ServiceCategoriesPageState extends State<ServiceCategoriesPage> {
  final AppointmentRepository _repository = AppointmentRepository();

  late Future<List<AppointmentService>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getServices();
  }

  Future<void> _refresh() async {
    final future = _repository.getServices();

    setState(() {
      _future = future;
    });

    await future;
  }
  /*
  @override
Widget build(BuildContext context) {
  debugPrint('🚀 SERVICE CATEGORIES PAGE BUILD');

  return const ColoredBox(
    color: Colors.green,
    child: Center(
      child: Text(
        'NEW PAGE',
        style: TextStyle(fontSize: 40),
      ),
    ),
  );
}
*/

  @override
  Widget build(BuildContext context) {
    debugPrint('🚀 SERVICE CATEGORIES PAGE BUILD');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<AppointmentService>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty) {
  return Center(
    child: Text(
      AppLocalizations.of(context)!.noAppointmentsFound,
    ),
  );
}

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];

              return AppointmentServiceCard(
                service: service,
                onTap: () {
                  context.read<AppState>().openAppointmentStatuses(service);
                },
              );
            },
          );
        },
      ),
    );
  }
}
