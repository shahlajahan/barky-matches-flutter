import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'admin_search_item.dart';
import 'admin_search_service.dart';

class AdminSearchPage extends StatefulWidget {
  const AdminSearchPage({super.key});

  @override
  State<AdminSearchPage> createState() => _AdminSearchPageState();
}

class _AdminSearchPageState extends State<AdminSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final AdminSearchService _service = AdminSearchService();

  Timer? _debounce;
  bool _isLoading = false;
  String _query = '';
  AdminSearchEntityType? _selectedType;
  List<AdminSearchItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.loadRecent(type: _selectedType);
      if (!mounted) return;
      setState(() => _items = data);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String value) async {
    final trimmed = value.trim();

    setState(() {
      _query = trimmed;
      _isLoading = true;
    });

    try {
      final data = await _service.search(
        query: trimmed,
        type: _selectedType,
      );

      if (!mounted) return;
      setState(() => _items = data);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onTypeChanged(AdminSearchEntityType? type) async {
    setState(() {
      _selectedType = type;
    });

    await _runSearch(_controller.text);
  }

  IconData _iconForType(AdminSearchEntityType type) {
    switch (type) {
      case AdminSearchEntityType.user:
        return Icons.person_outline;
      case AdminSearchEntityType.dog:
        return Icons.pets_outlined;
      case AdminSearchEntityType.business:
        return Icons.storefront_outlined;
      case AdminSearchEntityType.report:
        return Icons.flag_outlined;
      case AdminSearchEntityType.complaint:
        return Icons.gavel_outlined;
    }
  }

  String _labelForType(AdminSearchEntityType? type) {
    switch (type) {
      case null:
        return 'All';
      case AdminSearchEntityType.user:
        return 'Users';
      case AdminSearchEntityType.dog:
        return 'Dogs';
      case AdminSearchEntityType.business:
        return 'Businesses';
      case AdminSearchEntityType.report:
        return 'Reports';
      case AdminSearchEntityType.complaint:
        return 'Complaints';
    }
  }

  Color _statusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'approved' || s == 'resolved' || s == 'closed') {
      return Colors.green;
    }
    if (s == 'pending' || s == 'open' || s == 'under_review') {
      return Colors.orange;
    }
    if (s == 'rejected' || s == 'suspended') {
      return Colors.red;
    }
    return Colors.grey;
  }

  Future<void> _openItem(AdminSearchItem item) async {
    debugPrint('Open admin search item → ${item.entityType} / ${item.entityId}');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Open ${adminSearchEntityTypeToString(item.entityType)}: ${item.entityId}',
        ),
      ),
    );
  }

  Widget _buildTypeChip(AdminSearchEntityType? type) {
    final isSelected = _selectedType == type;

    return ChoiceChip(
      label: Text(_labelForType(type)),
      selected: isSelected,
      onSelected: (_) => _onTypeChanged(type),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _controller,
      onChanged: _onQueryChanged,
      decoration: InputDecoration(
        hintText: 'Search users, dogs, businesses, reports, complaints...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  _runSearch('');
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildItemCard(AdminSearchItem item) {
    final updatedText = item.updatedAt != null
        ? DateFormat('dd MMM yyyy • HH:mm').format(item.updatedAt!)
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openItem(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade200,
                child: Icon(
                  _iconForType(item.entityType),
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if ((item.status ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(item.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.status!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(item.status),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _metaChip(
                          adminSearchEntityTypeToString(item.entityType),
                          Icons.category_outlined,
                        ),
                        if ((item.badge ?? '').isNotEmpty)
                          _metaChip(item.badge!, Icons.verified_outlined),
                        if (updatedText != null)
                          _metaChip(updatedText, Icons.schedule_outlined),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'No recent admin records found.'
              : 'No results found for "$_query".',
          style: const TextStyle(fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) => _buildItemCard(_items[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Admin Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip(null),
                  const SizedBox(width: 8),
                  _buildTypeChip(AdminSearchEntityType.user),
                  const SizedBox(width: 8),
                  _buildTypeChip(AdminSearchEntityType.dog),
                  const SizedBox(width: 8),
                  _buildTypeChip(AdminSearchEntityType.business),
                  const SizedBox(width: 8),
                  _buildTypeChip(AdminSearchEntityType.report),
                  const SizedBox(width: 8),
                  _buildTypeChip(AdminSearchEntityType.complaint),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}