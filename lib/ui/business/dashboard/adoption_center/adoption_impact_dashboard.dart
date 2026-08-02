import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_header.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_card.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_metric_grid.dart';
import 'package:barky_matches_fixed/ui/shared/dashboard/dashboard_panel.dart';

class AdoptionImpactDashboard extends StatefulWidget {
  const AdoptionImpactDashboard({
    super.key,
    required this.businessId,
    required this.onAddAnimal,
  });

  final String businessId;
  final VoidCallback onAddAnimal;

  @override
  State<AdoptionImpactDashboard> createState() =>
      _AdoptionImpactDashboardState();
}

class _AdoptionImpactDashboardState extends State<AdoptionImpactDashboard> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _petsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream;
  int _days = 7;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _setStreams();
  }

  @override
  void didUpdateWidget(covariant AdoptionImpactDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.businessId != widget.businessId) _setStreams();
  }

  void _setStreams() {
    _petsStream = FirebaseFirestore.instance
        .collection('adoption_pets')
        .where('businessId', isEqualTo: widget.businessId)
        .snapshots();
    _requestsStream = FirebaseFirestore.instance
        .collection('adoption_requests')
        .where('targetOwnerId', isEqualTo: widget.businessId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _petsStream,
      builder: (context, petsSnapshot) {
        if (petsSnapshot.hasError) {
          return _errorState('Unable to load adoption animals.');
        }
        if (!petsSnapshot.hasData) return const _LoadingState();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requestsStream,
          builder: (context, requestsSnapshot) {
            if (requestsSnapshot.hasError) {
              return _errorState('Unable to load adoption applications.');
            }
            if (!requestsSnapshot.hasData) return const _LoadingState();

            final pets = petsSnapshot.data!.docs
                .map(_AdoptionAnimal.fromDocument)
                .toList();
            final requests = requestsSnapshot.data!.docs
                .map(_AdoptionRequest.fromDocument)
                .toList();
            return _DashboardContent(
              pets: pets,
              requests: requests,
              onAddAnimal: widget.onAddAnimal,
              days: _days,
              onDaysChanged: (value) => setState(() => _days = value),
              touchedIndex: _touchedIndex,
              onTouched: (value) => setState(() => _touchedIndex = value),
            );
          },
        );
      },
    );
  }

  Widget _errorState(String message) => Center(child: Text(message));
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.pets,
    required this.requests,
    required this.onAddAnimal,
    required this.days,
    required this.onDaysChanged,
    required this.touchedIndex,
    required this.onTouched,
  });

  final List<_AdoptionAnimal> pets;
  final List<_AdoptionRequest> requests;
  final VoidCallback onAddAnimal;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final int? touchedIndex;
  final ValueChanged<int?> onTouched;

  int get adoptedCount => pets.where((pet) => pet.isAdopted).length;
  int get availableCount => pets.where((pet) => pet.isAvailable).length;
  int get pendingCount => requests.where((request) => request.isPending).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalPets = pets.length;
    final successRate = totalPets == 0 ? null : adoptedCount / totalPets * 100;
    final averageDays = _averageAdoptionDays();
    final trend = _buildTrend();
    final adopted = pets.where((pet) => pet.isAdopted).toList()
      ..sort(
        (a, b) =>
            (b.adoptedAt ?? DateTime(0)).compareTo(a.adoptedAt ?? DateTime(0)),
      );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DashboardHeader(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.adoptionImpactOverview, style: _HeroTitle.style),
              const SizedBox(height: 4),
              Text(
                l10n.adoptionPerformanceShelterActivity,
                style: _HeroSubtitle.style,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (availableCount == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.info, color: Color(0xFF9E1B4F)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.noAnimalsAvailableAdoption)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onAddAnimal,
                    icon: const Icon(LucideIcons.plus),
                    label: Text(l10n.adoptionFirstAnimal),
                  ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 5
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            return DashboardMetricGrid(
              columns: columns,
              childAspectRatio: columns == 5 ? 1.75 : 2.1,
              items: [
                _metric(
                  'Animals Adopted',
                  '$adoptedCount',
                  LucideIcons.heartHandshake,
                ),
                _metric(
                  'Available Animals',
                  '$availableCount',
                  LucideIcons.heart,
                ),
                _metric(
                  'Pending Applications',
                  '$pendingCount',
                  LucideIcons.clock3,
                ),
                _metric(
                  'Adoption Success Rate',
                  successRate == null
                      ? '--'
                      : '${successRate.toStringAsFixed(0)}%',
                  LucideIcons.badgeCheck,
                ),
                _metric(
                  'Average Adoption Time',
                  averageDays == null
                      ? '--'
                      : '${averageDays.toStringAsFixed(0)} days',
                  LucideIcons.timer,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _TrendPanel(
          points: trend,
          days: days,
          onDaysChanged: onDaysChanged,
          touchedIndex: touchedIndex,
          onTouched: onTouched,
        ),
        const SizedBox(height: 24),
        _SpeciesPanel(pets: pets),
        const SizedBox(height: 24),
        _RecentAdoptionsPanel(
          title: 'Latest Adoptions',
          pets: adopted.take(5).toList(),
          emptyText: 'No adoptions yet.',
        ),
        const SizedBox(height: 24),
        _RecentlyAddedAnimalsPanel(pets: pets),
      ],
    );
  }

  DashboardMetricData _metric(String label, String value, IconData icon) =>
      DashboardMetricData(label: label, value: value, icon: icon);

  double? _averageAdoptionDays() {
    final durations = pets
        .where(
          (pet) =>
              pet.isAdopted && pet.createdAt != null && pet.adoptedAt != null,
        )
        .map((pet) => pet.adoptedAt!.difference(pet.createdAt!).inHours / 24)
        .where((days) => days >= 0)
        .toList();
    if (durations.isEmpty) return null;
    return durations.reduce((a, b) => a + b) / durations.length;
  }

  List<_TrendPoint> _buildTrend() {
    final now = DateTime.now();
    final monthly = days == 365;
    final start = monthly
        ? DateTime(now.year, now.month - 11, 1)
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: days - 1));
    return List.generate(monthly ? 12 : days, (index) {
      final date = monthly
          ? DateTime(start.year, start.month + index, 1)
          : start.add(Duration(days: index));
      final adopted = pets.where((pet) {
        final adoptedAt = pet.adoptedAt;
        if (!pet.isAdopted || adoptedAt == null) return false;
        return monthly
            ? adoptedAt.year == date.year && adoptedAt.month == date.month
            : adoptedAt.year == date.year &&
                  adoptedAt.month == date.month &&
                  adoptedAt.day == date.day;
      }).toList();
      return _TrendPoint(
        date: date,
        count: adopted.length,
        dogs: adopted
            .where((pet) => pet.species.toLowerCase().contains('dog'))
            .length,
        cats: adopted
            .where((pet) => pet.species.toLowerCase().contains('cat'))
            .length,
        hasSpecies: adopted.any((pet) => pet.species.trim().isNotEmpty),
      );
    });
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.points,
    required this.days,
    required this.onDaysChanged,
    required this.touchedIndex,
    required this.onTouched,
  });
  final List<_TrendPoint> points;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final int? touchedIndex;
  final ValueChanged<int?> onTouched;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasData = points.any((point) => point.count > 0);
    final maxValue = points.fold<int>(
      0,
      (max, point) => math.max(max, point.count),
    );
    final maxY = math.max(1, maxValue + (maxValue * .15).ceil()).toDouble();
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.adoptionTrend, style: _PanelTitle.style),
              ),
              DropdownButton<int>(
                value: days,
                isDense: true,
                items: [
                  DropdownMenuItem(
                    value: 7,
                    child: Text(l10n.vetRevenueRange7Days),
                  ),
                  DropdownMenuItem(
                    value: 30,
                    child: Text(l10n.vetRevenueRange30Days),
                  ),
                  DropdownMenuItem(
                    value: 365,
                    child: Text(l10n.creatorTimeframe12m),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onDaysChanged(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            SizedBox(
              height: 220,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.heartHandshake,
                      color: Color(0xFF9E1B4F),
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.noAdoptionsYet,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.completedAdoptionsEmpty,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: points.length > 12 ? 5 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat(
                                points.length == 12 ? 'MMM' : 'd',
                              ).format(points[index].date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: points[i].count.toDouble(),
                            width: points.length <= 12 ? 22 : 14,
                            color: i == touchedIndex
                                ? const Color(0xFF7F123F)
                                : const Color(0xFF9E1B4F),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchCallback: (event, response) =>
                        onTouched(response?.spot?.touchedBarGroupIndex),
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF24151E),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                            '${DateFormat.yMMMd().format(points[groupIndex].date)}\n'
                            'Adoptions: ${points[groupIndex].count}'
                            '${points[groupIndex].hasSpecies ? '\nDogs: ${points[groupIndex].dogs}\nCats: ${points[groupIndex].cats}' : ''}',
                            const TextStyle(color: Colors.white, height: 1.35),
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeciesPanel extends StatelessWidget {
  const _SpeciesPanel({required this.pets});
  final List<_AdoptionAnimal> pets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adopted = pets.where((pet) => pet.isAdopted).toList();
    if (adopted.isEmpty || adopted.every((pet) => pet.species.trim().isEmpty)) {
      return DashboardPanel(
        child: _EmptyPanel(
          title: l10n.speciesBreakdown,
          message: 'No adoption activity yet.',
        ),
      );
    }
    final counts = <String, int>{'Dogs': 0, 'Cats': 0, 'Others': 0};
    for (final pet in adopted) {
      final species = pet.species.toLowerCase();
      counts[species.contains('dog')
              ? 'Dogs'
              : species.contains('cat')
              ? 'Cats'
              : 'Others'] =
          counts[species.contains('dog')
              ? 'Dogs'
              : species.contains('cat')
              ? 'Cats'
              : 'Others']! +
          1;
    }
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.speciesBreakdown, style: _PanelTitle.style),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 46,
                    sectionsSpace: 3,
                    sections: [
                      for (final entry in counts.entries)
                        PieChartSectionData(
                          value: entry.value.toDouble(),
                          color: _speciesColor(entry.key),
                          showTitle: false,
                          radius: 55,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in counts.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _speciesColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.key}: ${entry.value}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _speciesColor(String species) => switch (species) {
    'Dogs' => const Color(0xFF9E1B4F),
    'Cats' => const Color(0xFFE83E8C),
    _ => const Color(0xFFB99BA8),
  };
}

class _RecentAdoptionsPanel extends StatelessWidget {
  const _RecentAdoptionsPanel({
    required this.title,
    required this.pets,
    required this.emptyText,
  });
  final String title;
  final List<_AdoptionAnimal> pets;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _PanelTitle.style),
          const SizedBox(height: 12),
          if (pets.isEmpty)
            Text(emptyText, style: const TextStyle(color: Colors.black54))
          else
            for (final pet in pets)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.heartHandshake,
                      color: Color(0xFF9E1B4F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name.isEmpty ? 'Unnamed animal' : pet.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${pet.species.isEmpty ? l10n.speciesUnavailable : pet.species} • ${l10n.adopted}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    if (pet.adoptedAt != null)
                      Text(
                        DateFormat.yMMMd().format(pet.adoptedAt!),
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _RecentlyAddedAnimalsPanel extends StatelessWidget {
  const _RecentlyAddedAnimalsPanel({required this.pets});
  final List<_AdoptionAnimal> pets;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...pets]
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.recentlyAddedAnimals, style: _PanelTitle.style),
          const SizedBox(height: 16),
          if (sorted.isEmpty)
            Text(l10n.noAnimalsAdded, style: TextStyle(color: Colors.black54))
          else
            for (final pet in sorted.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _AnimalThumbnail(url: pet.coverImageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name.isEmpty ? 'Unnamed animal' : pet.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            pet.species.isEmpty
                                ? l10n.speciesUnavailable
                                : pet.species,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    if (pet.createdAt != null)
                      Text(
                        DateFormat.yMMMd().format(pet.createdAt!),
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AnimalThumbnail extends StatelessWidget {
  const _AnimalThumbnail({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: Color(0xFFF7EAF0),
        child: Icon(Icons.pets, color: Color(0xFF9E1B4F)),
      );
    }
    return ClipOval(
      child: Image.network(
        url!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFF7EAF0),
          child: Icon(Icons.pets, color: Color(0xFF9E1B4F)),
        ),
      ),
    );
  }
}

class _AdoptionAnimal {
  const _AdoptionAnimal({
    required this.name,
    required this.species,
    required this.status,
    required this.createdAt,
    required this.adoptedAt,
    required this.isVisible,
    required this.coverImageUrl,
  });
  final String name;
  final String species;
  final String status;
  final DateTime? createdAt;
  final DateTime? adoptedAt;
  final bool isVisible;
  final String? coverImageUrl;
  bool get isAdopted => status == 'adopted';
  bool get isAvailable => isVisible && status == 'available';

  factory _AdoptionAnimal.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : null;
    return _AdoptionAnimal(
      name: '${data['name'] ?? ''}',
      species: '${data['species'] ?? data['petType'] ?? ''}',
      status: '${data['status'] ?? ''}',
      createdAt: date(data['createdAt']),
      adoptedAt: date(data['adoptedAt']),
      isVisible: data['isVisible'] != false,
      coverImageUrl: data['coverImageUrl']?.toString(),
    );
  }
}

class _AdoptionRequest {
  const _AdoptionRequest(this.status);
  final String status;
  bool get isPending => status == 'pending';
  factory _AdoptionRequest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => _AdoptionRequest('${doc.data()['status'] ?? ''}');
}

class _TrendPoint {
  const _TrendPoint({
    required this.date,
    required this.count,
    required this.dogs,
    required this.cats,
    required this.hasSpecies,
  });
  final DateTime date;
  final int count;
  final int dogs;
  final int cats;
  final bool hasSpecies;
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: _PanelTitle.style),
      const SizedBox(height: 16),
      const Center(child: Icon(Icons.pets, color: Color(0xFF9E1B4F), size: 28)),
      const SizedBox(height: 10),
      Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
      if (title == 'Species Breakdown') ...[
        const SizedBox(height: 4),
        Center(
          child: Text(
            AppLocalizations.of(context)!.speciesStatisticsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ),
      ],
    ],
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _HeroTitle {
  static const style = TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );
}

class _HeroSubtitle {
  static const style = TextStyle(color: Colors.white70);
}

class _PanelTitle {
  static const style = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
}
