import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class VetPreVisitFormSettingsPage extends StatefulWidget {
  final String businessId;

  const VetPreVisitFormSettingsPage({super.key, required this.businessId});

  @override
  State<VetPreVisitFormSettingsPage> createState() =>
      _VetPreVisitFormSettingsPageState();
}

class _VetPreVisitFormSettingsPageState
    extends State<VetPreVisitFormSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _selectedServiceId;
  final Map<String, _ServicePreVisitFormDraft> _formsByServiceId = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    debugPrint('🩺 PREVISIT SETTINGS LOAD businessId=${widget.businessId}');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      final data = doc.data() ?? {};
      final settings = _settingsFromBusiness(data);
      debugPrint('🩺 PREVISIT RAW DATA = $settings');

      final preVisitForms = _asMap(settings['preVisitForms']);

      final loadedForms = <String, _ServicePreVisitFormDraft>{};

      preVisitForms.forEach((serviceId, value) {
        final normalizedId = serviceId.toString().trim();
        if (normalizedId.isEmpty) return;
        loadedForms[normalizedId] = _ServicePreVisitFormDraft.fromMap(
          _asMap(value),
        );
      });

      // Backward compatibility for old global settings. This only migrates
      // in-memory when there are actual questions.
      if (loadedForms.isEmpty) {
        final legacyQuestions = _listOfMaps(settings['questions'])
            .map(_PreVisitQuestionDraft.fromMap)
            .where((question) => question.question.trim().isNotEmpty)
            .toList();

        if (settings['enabled'] == true && legacyQuestions.isNotEmpty) {
          for (final serviceId in _stringList(settings['enabledServiceIds'])) {
            loadedForms[serviceId] = _ServicePreVisitFormDraft(
              enabled: true,
              questions: legacyQuestions
                  .map((question) => question.copy())
                  .toList(),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _formsByServiceId
          ..clear()
          ..addAll(loadedForms);
        _loading = false;
      });
    } catch (e) {
      debugPrint('🩺 PREVISIT SETTINGS LOAD error=$e');

      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load pre-visit settings: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;

    final error = _validateForms();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final formsPayload = <String, dynamic>{};
    _formsByServiceId.forEach((serviceId, form) {
      final formPayload = form.toMap();
      debugPrint(
        '🩺 PREVISIT SAVE serviceId=$serviceId questions=${form.questions.length}',
      );
      formsPayload[serviceId] = formPayload;
    });

    setState(() => _saving = true);
    debugPrint(
      '🩺 PREVISIT SETTINGS SAVE businessId=${widget.businessId} services=${formsPayload.keys.toList()}',
    );

    try {
      final businessRef = FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId);

      await businessRef.set({
        'sectorData': {
          'veterinary': {
            'preVisitFormSettings': {
              'preVisitForms': formsPayload,
              'enabled': FieldValue.delete(),
              'enabledServiceIds': FieldValue.delete(),
              'questions': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final verifyDoc = await businessRef.get();
      final verifySettings = _settingsFromBusiness(verifyDoc.data());
      debugPrint('🩺 PREVISIT RAW DATA = $verifySettings');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pre-visit form settings saved')),
      );
    } catch (e) {
      debugPrint('🩺 PREVISIT SETTINGS SAVE error=$e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _validateForms() {
    for (final entry in _formsByServiceId.entries) {
      final serviceId = entry.key;
      final form = entry.value;

      for (final question in form.questions) {
        if (question.question.trim().isEmpty) {
          return 'Question text cannot be empty for $serviceId.';
        }

        if (question.isChoiceType) {
          if (question.cleanOptions.isEmpty) {
            return 'Choice questions must have options for $serviceId.';
          }

          if (question.options.any((option) => option.trim().isEmpty)) {
            return 'Option values cannot be empty for $serviceId.';
          }
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Pre-visit forms'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _saving || _loading ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.save),
            label: Text(_saving ? 'Saving...' : 'Save settings'),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _servicesSection(),
                  const SizedBox(height: 14),
                  _selectedServiceFormSection(),
                  const SizedBox(height: 88),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.clipboardList, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service pre-visit forms',
                  style: AppTheme.h2(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Each service can have its own medical intake questions.',
                  style: AppTheme.caption(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _servicesSection() {
    return _section(
      title: 'Services',
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('businesses')
              .doc(widget.businessId)
              .collection('services')
              .where('isActive', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Services could not be loaded.',
                style: AppTheme.caption(color: Colors.red),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Text(
                'No active services yet. Add services before creating forms.',
                style: AppTheme.caption(),
              );
            }

            _selectedServiceId ??= docs.first.id;

            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] ?? doc.id).toString();
                final selected = _selectedServiceId == doc.id;
                final form = _formForService(doc.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.card.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppTheme.card
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    title: Text(title, style: AppTheme.h3(size: 15)),
                    subtitle: Text(
                      form.enabled
                          ? '${form.questions.length} question(s)'
                          : 'Form disabled',
                      style: AppTheme.caption(),
                    ),
                    trailing: Switch.adaptive(
                      value: form.enabled,
                      activeThumbColor: AppTheme.accent,
                      onChanged: (value) {
                        setState(() {
                          _selectedServiceId = doc.id;
                          form.enabled = value;
                        });
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedServiceId = doc.id);
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _selectedServiceFormSection() {
    final serviceId = _selectedServiceId;

    if (serviceId == null) {
      return const SizedBox.shrink();
    }

    final form = _formForService(serviceId);

    return _section(
      title: 'Questions for $serviceId',
      trailing: TextButton.icon(
        onPressed: () => _addQuestion(serviceId),
        icon: const Icon(LucideIcons.plus, size: 18),
        label: const Text('Add'),
      ),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: form.enabled,
          activeThumbColor: AppTheme.accent,
          title: Text('Enable for this service', style: AppTheme.h3(size: 15)),
          subtitle: Text(
            'Only this service will ask these questions.',
            style: AppTheme.caption(),
          ),
          onChanged: (value) {
            setState(() => form.enabled = value);
          },
        ),
        const SizedBox(height: 10),
        if (form.questions.isEmpty)
          Text('No questions for this service yet.', style: AppTheme.caption())
        else
          ...form.questions.asMap().entries.map((entry) {
            return _questionCard(serviceId, entry.key, entry.value);
          }),
      ],
    );
  }

  Widget _questionCard(
    String serviceId,
    int index,
    _PreVisitQuestionDraft question,
  ) {
    final form = _formForService(serviceId);

    return Container(
      margin: EdgeInsets.only(top: index == 0 ? 0 : 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: question.question,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'e.g. Has your pet eaten today?',
                  ),
                  onChanged: (value) => question.question = value,
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.arrowUp),
                onPressed: index == 0
                    ? null
                    : () {
                        setState(() {
                          final item = form.questions.removeAt(index);
                          form.questions.insert(index - 1, item);
                        });
                      },
              ),
              IconButton(
                icon: const Icon(LucideIcons.arrowDown),
                onPressed: index == form.questions.length - 1
                    ? null
                    : () {
                        setState(() {
                          final item = form.questions.removeAt(index);
                          form.questions.insert(index + 1, item);
                        });
                      },
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, color: Colors.red),
                onPressed: () {
                  setState(() => form.questions.removeAt(index));
                },
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: question.type,
            decoration: const InputDecoration(labelText: 'Question type'),
            items: const [
              DropdownMenuItem(value: 'text', child: Text('Text')),
              DropdownMenuItem(value: 'multiline', child: Text('Long text')),
              DropdownMenuItem(value: 'boolean', child: Text('Yes / No')),
              DropdownMenuItem(
                value: 'single_select',
                child: Text('Single choice'),
              ),
              DropdownMenuItem(
                value: 'multi_select',
                child: Text('Multiple choice'),
              ),
              DropdownMenuItem(value: 'number', child: Text('Number')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                question.type = value;
                if (!question.isChoiceType) {
                  question.options.clear();
                } else if (question.options.isEmpty) {
                  question.options.add('');
                }
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: question.required,
            activeThumbColor: AppTheme.accent,
            title: Text('Required', style: AppTheme.body()),
            onChanged: (value) {
              setState(() => question.required = value);
            },
          ),
          if (question.isChoiceType) ...[
            const SizedBox(height: 8),
            Text('Options', style: AppTheme.h3(size: 15)),
            const SizedBox(height: 8),
            ...question.options.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: entry.value,
                        decoration: InputDecoration(
                          labelText: 'Option ${entry.key + 1}',
                        ),
                        onChanged: (value) {
                          question.options[entry.key] = value;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: question.options.length == 1
                          ? null
                          : () {
                              setState(() {
                                question.options.removeAt(entry.key);
                              });
                            },
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() => question.options.add(''));
              },
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add option'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTheme.h2())),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow(opacity: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  _ServicePreVisitFormDraft _formForService(String serviceId) {
    return _formsByServiceId.putIfAbsent(
      serviceId,
      () => _ServicePreVisitFormDraft(enabled: false, questions: []),
    );
  }

  void _addQuestion(String serviceId) {
    setState(() {
      _formForService(serviceId).questions.add(
        _PreVisitQuestionDraft(
          id: FirebaseFirestore.instance.collection('_').doc().id,
          question: '',
          type: 'text',
          required: false,
          options: [],
        ),
      );
    });
  }
}

class _ServicePreVisitFormDraft {
  bool enabled;
  final List<_PreVisitQuestionDraft> questions;

  _ServicePreVisitFormDraft({required this.enabled, required this.questions});

  factory _ServicePreVisitFormDraft.fromMap(Map<String, dynamic> data) {
    return _ServicePreVisitFormDraft(
      enabled: data['enabled'] == true,
      questions: _listOfMaps(
        data['questions'],
      ).map(_PreVisitQuestionDraft.fromMap).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'questions': questions.map((question) => question.toMap()).toList(),
    };
  }
}

class _PreVisitQuestionDraft {
  final String id;
  String question;
  String type;
  bool required;
  final List<String> options;

  _PreVisitQuestionDraft({
    required this.id,
    required this.question,
    required this.type,
    required this.required,
    required this.options,
  });

  bool get isChoiceType => type == 'single_select' || type == 'multi_select';

  List<String> get cleanOptions =>
      options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  _PreVisitQuestionDraft copy() {
    return _PreVisitQuestionDraft(
      id: id,
      question: question,
      type: type,
      required: required,
      options: List<String>.from(options),
    );
  }

  factory _PreVisitQuestionDraft.fromMap(Map<String, dynamic> data) {
    return _PreVisitQuestionDraft(
      id: (data['id'] ?? FirebaseFirestore.instance.collection('_').doc().id)
          .toString(),
      question: (data['question'] ?? '').toString(),
      type: _normalizeType((data['type'] ?? 'text').toString()),
      required: data['required'] == true,
      options: _stringList(data['options']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question.trim(),
      'type': type,
      'required': required,
      'options': isChoiceType ? cleanOptions : <String>[],
    };
  }
}

Map<String, dynamic> _settingsFromBusiness(Map<String, dynamic>? data) {
  final sectorData = _asMap((data ?? {})['sectorData']);
  final veterinary = _asMap(sectorData['veterinary']);
  return _asMap(veterinary['preVisitFormSettings']);
}

String _normalizeType(String value) {
  switch (value) {
    case 'yes_no':
    case 'boolean':
      return 'boolean';
    case 'single_choice':
    case 'single_select':
      return 'single_select';
    case 'multi_choice':
    case 'multi_select':
      return 'multi_select';
    case 'multiline':
      return 'multiline';
    case 'number':
      return 'number';
    case 'text':
    default:
      return 'text';
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(Object? value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
