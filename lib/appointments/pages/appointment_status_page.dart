import 'package:flutter/material.dart';

import '../models/appointment_service.dart';
import '../models/appointment_status.dart';
import '../services/appointment_repository.dart';
import '../widgets/appointment_status_card.dart';
import 'appointment_list_page.dart';

class AppointmentStatusPage extends StatefulWidget {
  const AppointmentStatusPage({
    super.key,
    required this.service,
  });

  final AppointmentService service;

  @override
  State<AppointmentStatusPage> createState() =>
      _AppointmentStatusPageState();
}

class _AppointmentStatusPageState
    extends State<AppointmentStatusPage> {
  final AppointmentRepository _repository = AppointmentRepository();

  late Future<List<AppointmentStatus>> _future;

  @override
  void initState() {
    super.initState();

    _future = _repository.getStatuses(
      widget.service.type,
    );
  }

  Future<void> _refresh() async {
    final future = _repository.getStatuses(
      widget.service.type,
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
        title: Text(widget.service.title),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppointmentStatus>>(
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

            final statuses = snapshot.data ?? [];

            if (statuses.isEmpty) {
              return const Center(
                child: Text(
                  'No appointments.',
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: statuses.length,
              itemBuilder: (context, index) {
                final status = statuses[index];

                return AppointmentStatusCard(
                  status: status,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppointmentListPage(
                          service: widget.service,
                          status: status,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}