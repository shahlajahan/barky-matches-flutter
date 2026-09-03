import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/business_media_service.dart';

/// Seller Settings → Business Media.
///
/// Renders the *authoritative* canonical state streamed from
/// `businesses/{businessId}.businessMedia`, never local optimistic state: the
/// field is server-owned (see firestore.rules), so the only way a change
/// appears here is if `finalizeBusinessMedia` actually committed it. That is
/// what makes "saved" honest, and what makes a failed upload leave the
/// previous image on screen and still usable.
class BusinessMediaPage extends StatefulWidget {
  const BusinessMediaPage({
    super.key,
    required this.businessId,
    this.service,
    this.picker,
    this.onClose,
  });

  final String businessId;

  /// Injectable for tests; production uses the real Firestore/Functions pair.
  final BusinessMediaService? service;
  final ImagePicker? picker;
  final VoidCallback? onClose;

  @override
  State<BusinessMediaPage> createState() => _BusinessMediaPageState();
}

class _BusinessMediaPageState extends State<BusinessMediaPage> {
  late final BusinessMediaService _service =
      widget.service ?? BusinessMediaService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  /// One in-flight operation per role. This is what stops a double tap, and
  /// also stops two conflicting operations on the same role — while still
  /// allowing, say, a cover upload during a gallery upload.
  final Set<BusinessMediaRole> _busy = <BusinessMediaRole>{};

  /// Per-role upload progress, 0..1, shown only while that role is busy.
  final Map<BusinessMediaRole, double> _progress = {};

  /// Per-role last failure, so each section can offer its own retry.
  final Map<BusinessMediaRole, String> _errors = {};

  /// The action to re-run when the user taps Retry for a role.
  final Map<BusinessMediaRole, Future<void> Function()> _retries = {};

  bool _isBusy(BusinessMediaRole role) => _busy.contains(role);

  String _messageFor(AppLocalizations l10n, String code) => switch (code) {
    'unauthenticated' => l10n.businessMediaErrorSignedOut,
    'permission-denied' => l10n.businessMediaErrorNotOwner,
    'failed-precondition' => l10n.businessMediaErrorStale,
    'already-exists' => l10n.businessMediaErrorStale,
    'invalid-argument' => l10n.businessMediaErrorFormat,
    'not-found' => l10n.businessMediaErrorUpload,
    _ => l10n.businessMediaErrorGeneric,
  };

  /// Runs [action] under the role's busy lock, recording progress and any
  /// failure. A second call while the role is busy is ignored outright, so a
  /// double tap can never start two uploads or append a gallery entry twice.
  Future<void> _run(
    BusinessMediaRole role,
    Future<void> Function() action,
  ) async {
    if (_isBusy(role)) return;
    setState(() {
      _busy.add(role);
      _progress[role] = 0;
      _errors.remove(role);
      _retries.remove(role);
    });
    try {
      await action();
    } on BusinessMediaException catch (error) {
      if (!mounted) return;
      setState(() {
        _errors[role] = error.code;
        _retries[role] = action;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errors[role] = 'unavailable';
        _retries[role] = action;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(role);
          _progress.remove(role);
        });
      }
    }
  }

  Future<File?> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    return picked == null ? null : File(picked.path);
  }

  Future<void> _pickAndUpload(
    BusinessMediaRole role,
    BusinessMedia current,
  ) async {
    if (_isBusy(role)) return;
    if (role == BusinessMediaRole.gallery && current.galleryIsFull) {
      final l10n = AppLocalizations.of(context)!;
      _showMessage(l10n.businessMediaGalleryFull);
      return;
    }
    final file = await _pickImage();
    if (file == null) return;
    await _run(role, () async {
      await _service.upload(
        businessId: widget.businessId,
        role: role,
        file: file,
        current: current,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress[role] = value.clamp(0.0, 1.0));
        },
      );
    });
  }

  Future<void> _confirmAndRemove(
    BusinessMediaRole role,
    BusinessMedia current, {
    String? path,
  }) async {
    if (_isBusy(role)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.businessMediaRemoveConfirmTitle),
        content: Text(l10n.businessMediaRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.businessMediaCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.businessMediaRemoveConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      role,
      () => _service.remove(
        businessId: widget.businessId,
        role: role,
        current: current,
        path: path,
      ),
    );
  }

  Future<void> _reorder(
    BusinessMedia current,
    int oldIndex,
    int newIndex,
  ) async {
    if (_isBusy(BusinessMediaRole.gallery)) return;
    final paths = current.gallery.map((item) => item.path).toList();
    if (oldIndex < 0 || oldIndex >= paths.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= paths.length || target == oldIndex) return;
    final moved = paths.removeAt(oldIndex);
    paths.insert(target, moved);
    await _run(
      BusinessMediaRole.gallery,
      () => _service.reorderGallery(
        businessId: widget.businessId,
        current: current,
        orderedPaths: paths,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.businessMediaTitle),
        leading: widget.onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onClose,
                tooltip: l10n.businessMediaCancel,
              ),
      ),
      body: StreamBuilder<BusinessMedia>(
        stream: _service.watch(widget.businessId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final media = snapshot.data ?? const BusinessMedia();
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth > 700 ? 32.0 : 16.0;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal,
                  vertical: 16,
                ),
                children: [
                  Text(
                    l10n.businessMediaDescription,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _singleImageSection(
                    l10n: l10n,
                    role: BusinessMediaRole.logo,
                    label: l10n.businessMediaLogo,
                    emptyLabel: l10n.businessMediaNoLogo,
                    addLabel: l10n.businessMediaAddLogo,
                    changeLabel: l10n.businessMediaChangeLogo,
                    removeLabel: l10n.businessMediaRemoveLogo,
                    item: media.logo,
                    media: media,
                    height: 120,
                  ),
                  const SizedBox(height: 28),
                  _singleImageSection(
                    l10n: l10n,
                    role: BusinessMediaRole.cover,
                    label: l10n.businessMediaCover,
                    emptyLabel: l10n.businessMediaNoCover,
                    addLabel: l10n.businessMediaAddCover,
                    changeLabel: l10n.businessMediaChangeCover,
                    removeLabel: l10n.businessMediaRemoveCover,
                    item: media.cover,
                    media: media,
                    height: 170,
                  ),
                  const SizedBox(height: 28),
                  _gallerySection(l10n, media),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, String optional, {String? trailing}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Text(optional, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        if (trailing != null)
          Text(trailing, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _singleImageSection({
    required AppLocalizations l10n,
    required BusinessMediaRole role,
    required String label,
    required String emptyLabel,
    required String addLabel,
    required String changeLabel,
    required String removeLabel,
    required BusinessMediaItem? item,
    required BusinessMedia media,
    required double height,
  }) {
    final busy = _isBusy(role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(label, l10n.businessMediaOptional),
        const SizedBox(height: 12),
        Semantics(
          label: label,
          image: item != null,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: item == null
                ? Center(
                    child: Text(
                      emptyLabel,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : _networkImage(l10n, item.url),
          ),
        ),
        const SizedBox(height: 12),
        if (busy) _progressRow(l10n, role),
        if (!busy)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickAndUpload(role, media),
                icon: const Icon(Icons.upload_outlined),
                label: Text(item == null ? addLabel : changeLabel),
              ),
              if (item != null)
                TextButton.icon(
                  onPressed: () => _confirmAndRemove(role, media),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(removeLabel),
                ),
            ],
          ),
        _errorRow(l10n, role),
      ],
    );
  }

  Widget _gallerySection(AppLocalizations l10n, BusinessMedia media) {
    final busy = _isBusy(BusinessMediaRole.gallery);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          l10n.businessMediaGallery,
          l10n.businessMediaOptional,
          trailing: l10n.businessMediaGalleryCount(
            media.gallery.length,
            BusinessMedia.galleryMaxItems,
          ),
        ),
        const SizedBox(height: 12),
        if (media.gallery.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              l10n.businessMediaNoPhotos,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: !busy,
            itemCount: media.gallery.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(media, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = media.gallery[index];
              return Padding(
                key: ValueKey(item.path),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        height: 66,
                        child: _networkImage(l10n, item.url),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.businessMediaRemovePhoto,
                      onPressed: busy
                          ? null
                          : () => _confirmAndRemove(
                              BusinessMediaRole.gallery,
                              media,
                              path: item.path,
                            ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        if (busy) _progressRow(l10n, BusinessMediaRole.gallery),
        if (!busy)
          ElevatedButton.icon(
            onPressed: media.galleryIsFull
                ? null
                : () => _pickAndUpload(BusinessMediaRole.gallery, media),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(l10n.businessMediaAddPhotos),
          ),
        if (media.galleryIsFull && !busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.businessMediaGalleryFull,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        _errorRow(l10n, BusinessMediaRole.gallery),
      ],
    );
  }

  Widget _progressRow(AppLocalizations l10n, BusinessMediaRole role) {
    final value = _progress[role];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: l10n.businessMediaUploading,
        value: value == null ? null : '${(value * 100).round()}%',
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(l10n.businessMediaUploading),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: value == null || value <= 0 ? null : value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorRow(AppLocalizations l10n, BusinessMediaRole role) {
    final code = _errors[role];
    if (code == null) return const SizedBox.shrink();
    final retry = _retries[role];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _messageFor(l10n, code),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (retry != null)
            TextButton(
              onPressed: () => _run(role, retry),
              child: Text(l10n.businessMediaRetry),
            ),
        ],
      ),
    );
  }

  /// Renders a stored image, falling back to a neutral placeholder rather than
  /// letting a broken or revoked reference throw into the widget tree.
  Widget _networkImage(AppLocalizations l10n, String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            l10n.businessMediaImageUnavailable,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
