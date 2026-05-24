import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/green_memorial/create_memorial_page.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class GreenMemorialPage extends StatelessWidget {
  const GreenMemorialPage({super.key});

  // TODO(green-memorial): Future memorial fields:
  // petId, petName, petPhoto, story, treeType, visibility, plantedAt,
  // location, likesCount, commentsCount.

  @override
  Widget build(BuildContext context) {
    final ownerId = context.select<AppState, String?>((s) => s.currentUserId);

    return SafeArea(
      top: false,
      child: Container(
        color: AppTheme.bg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
          children: [
            _Header(
              onCreate: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateMemorialPage()),
                );

                if (!context.mounted || created != true) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Memorial created.')),
                );
              },
            ),
            const SizedBox(height: 16),
            const _InfoCard(
              icon: Icons.local_florist,
              title: 'Plant a tree in memory of your pet',
            ),
            const _InfoCard(
              icon: Icons.favorite,
              title: 'Share their story with the PetSupo community',
            ),
            const _InfoCard(
              icon: Icons.eco,
              title: 'Keep their memory alive through nature',
            ),
            const SizedBox(height: 18),
            const _SectionTitle('My Memorials'),
            _MyMemorials(ownerId: ownerId),
            const SizedBox(height: 18),
const _SectionTitle('Community Memorials'),
const SizedBox(height: 8),
_CommunityMemorials(),
const SizedBox(height: 18),
            const _SectionTitle('Memorial Map'),
const SizedBox(height: 8),
SizedBox(
  height: 320,
  child: _MemorialMap(),
),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onCreate;

  const _Header({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(opacity: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_florist, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Green Memorial',
                  style: AppTheme.h1(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Plant a tree in memory of your beloved pet.',
            style: AppTheme.body(color: Colors.white.withValues(alpha: 0.86)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Memorial'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _InfoCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.cardShadow(opacity: 0.06),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: AppTheme.body(weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppTheme.h2()),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({
    this.text =
        'No memorials yet. Create the first memory for your beloved pet.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, color: AppTheme.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTheme.body(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _MyMemorials extends StatelessWidget {
  final String? ownerId;

  const _MyMemorials({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    if (ownerId == null || ownerId!.isEmpty) {
      return const _EmptyState(text: 'Sign in to see your memorials.');
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('green_memorials')
          .where('ownerId', isEqualTo: ownerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPanel();
        }

        if (snapshot.hasError) {
          return const _EmptyState(text: 'Could not load memorials right now.');
        }

        final docs = snapshot.data?.docs.toList() ?? [];
        docs.sort((a, b) {
          final aDate = _timestampToDate(a.data()['createdAt']);
          final bDate = _timestampToDate(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return const _EmptyState();
        }

        return Column(
          children: docs.map((doc) {
            return _MemorialCard(data: doc.data());
          }).toList(),
        );
      },
    );
  }
}

class _MemorialCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MemorialCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
final petName = (data['petName'] ?? '').toString();
final ownerName = (data['ownerName'] ?? '').toString();
final story = (data['story'] ?? '').toString();
final treeType = (data['treeType'] ?? '').toString();
final petPhoto = (data['petPhoto'] ?? '').toString();
final createdAt = _timestampToDate(data['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppTheme.cardShadow(opacity: 0.04),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PetImage(path: petPhoto),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Untitled Memorial' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.h3(),
                ),
                if (petName.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text(
      'In memory of $petName 🌱',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTheme.caption(
        size: 12,
        color: AppTheme.success,
      ),
    ),
  ),
                const SizedBox(height: 4),
                Text(
  [
    if (treeType.isNotEmpty) '🌳 $treeType',
    _formatDate(createdAt),
  ].join(' - '),
  style: AppTheme.caption(size: 12),
),
                const SizedBox(height: 6),
                Text(
                  story,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(size: 13, color: AppTheme.muted),
                ),
                if (ownerName.isNotEmpty) ...[
  const SizedBox(height: 6),
  Text(
    'By $ownerName',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppTheme.caption(size: 11),
  ),
],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetImage extends StatelessWidget {
  final String path;

  const _PetImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final value = path.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        height: 58,
        child: value.isEmpty
            ? _fallback()
            : value.startsWith('http')
            ? Image.network(
                value,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              )
            : Image.file(
                File(value),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(Icons.local_florist, color: AppTheme.success),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _MemorialMap extends StatefulWidget {
  @override
  State<_MemorialMap> createState() => _MemorialMapState();
}

class _MemorialMapState extends State<_MemorialMap> {
  GoogleMapController? _mapController;

  static const LatLng _fallback = LatLng(
    41.0082,
    28.9784,
  );

  final Set<Factory<OneSequenceGestureRecognizer>>
    _gestureRecognizers = {
  Factory<OneSequenceGestureRecognizer>(
    () => EagerGestureRecognizer(),
  ),
};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('green_memorials')
          .where('visibility', isEqualTo: 'Public')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const _LoadingPanel();
        }

        if (snapshot.hasError) {
          return const _EmptyState(
            text: 'Could not load memorial map.',
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final Set<Marker> markers = {};

        for (final doc in docs) {
          final data = doc.data();

          final lat = data['lat'];
          final lng = data['lng'];

          if (lat == null || lng == null) {
            continue;
          }

          final petName =
              (data['petName'] ?? '').toString();

          final title =
              (data['title'] ?? '').toString();

          markers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(
                lat.toDouble(),
                lng.toDouble(),
              ),
              infoWindow: InfoWindow(
                title: petName.isEmpty
                    ? 'Green Memorial'
                    : 'In memory of $petName 🌱',
                snippet: title,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(
            AppTheme.radiusCard,
          ),
        child: GoogleMap(
  initialCameraPosition: const CameraPosition(
    target: _fallback,
    zoom: 11,
  ),

  markers: markers,

  mapType: MapType.normal,

  gestureRecognizers: _gestureRecognizers,

  zoomControlsEnabled: true,
  zoomGesturesEnabled: true,
  scrollGesturesEnabled: true,
  rotateGesturesEnabled: true,
  tiltGesturesEnabled: true,

  myLocationEnabled: true,
  myLocationButtonEnabled: true,

  compassEnabled: true,
  buildingsEnabled: true,
  trafficEnabled: false,

  onMapCreated: (controller) async {
    _mapController = controller;

    if (markers.isNotEmpty) {
      final first = markers.first.position;

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: first,
            zoom: 13,
          ),
        ),
      );
    } else {
      final pos = await Geolocator.getCurrentPosition();

      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              pos.latitude,
              pos.longitude,
            ),
            zoom: 13,
          ),
        ),
      );
    }
  },
),
        );
      },
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlaceholderPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTheme.caption(size: 13))),
        ],
      ),
    );
  }
}

DateTime _timestampToDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Just now';

  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
class _CommunityMemorials extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
    .collection('green_memorials')
    .where('visibility', isEqualTo: 'Public')
    .orderBy('createdAt', descending: true)
    .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPanel();
        }

        if (snapshot.hasError) {
  debugPrint(
    '❌ COMMUNITY MEMORIAL ERROR: ${snapshot.error}',
  );

  return _EmptyState(
    text: '${snapshot.error}',
  );
}
        final docs = snapshot.data?.docs.toList() ?? [];

        docs.sort((a, b) {
          final aDate = _timestampToDate(a.data()['createdAt']);
          final bDate = _timestampToDate(b.data()['createdAt']);
          return bDate.compareTo(aDate);
        });

        if (docs.isEmpty) {
          return const _EmptyState(
            text: 'No memorial trees have been planted yet 🌱',
          );
        }

        return Column(
          children: docs.map((doc) {
            return _MemorialCard(data: doc.data());
          }).toList(),
        );
      },
    );
  }
}