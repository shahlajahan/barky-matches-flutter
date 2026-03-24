import 'package:flutter/material.dart';

class LocationPickerSheet<T> extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.onSelected,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onSelected;

  @override
  State<LocationPickerSheet<T>> createState() =>
      _LocationPickerSheetState<T>();
}

class _LocationPickerSheetState<T>
    extends State<LocationPickerSheet<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((e) {
      final label = widget.itemLabel(e).toLowerCase();
      return label.contains(_query.toLowerCase());
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return ListTile(
                    title: Text(widget.itemLabel(item)),
                    onTap: () {
                      widget.onSelected(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}