import 'package:flutter/material.dart';

import '../models/appointment_item.dart';
import '../models/appointment_service.dart';
import '../models/appointment_status.dart';
import '../services/appointment_repository.dart';
import '../widgets/appointment_card.dart';

class AppointmentListPage extends StatefulWidget {
  const AppointmentListPage({
    super.key,
    required this.service,
    required this.status,
  });

  final AppointmentService service;
  final AppointmentStatus status;

  @override
  State<AppointmentListPage> createState() =>
      _AppointmentListPageState();
}

class _AppointmentListPageState
    extends State<AppointmentListPage> {
  final AppointmentRepository _repository =
      AppointmentRepository();

  late Future<List<AppointmentItem>> _future;

  @override
  void initState() {
    super.initState();

    _future = _repository.getAppointments(
      service: widget.service.type,
      status: widget.status.type,
    );
  }

  Future<void> _refresh() async {
    final future = _repository.getAppointments(
      service: widget.service.type,
      status: widget.status.type,
    );

    setState(() {
      _future = future;
    });

    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.status.title),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppointmentItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState !=
                ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                ),
              );
            }

            final appointments =
                snapshot.data ?? [];

            if (appointments.isEmpty) {
              return const Center(
                child: Text(
                  'No appointments.',
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                return AppointmentCard(
                  item: appointments[index],
                );
              },
            );
          },
        ),
      ),
    );
  }
}