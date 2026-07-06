enum AppointmentStatusType {
  pending,
  approved,
  completed,
  cancelled,
}

class AppointmentStatus {
  final AppointmentStatusType type;

  final String title;

  final int count;

  const AppointmentStatus({
    required this.type,
    required this.title,
    required this.count,
  });

  String get id => type.name;

  bool get hasItems => count > 0;
}