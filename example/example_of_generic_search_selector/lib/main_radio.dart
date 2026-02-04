import 'package:flutter/material.dart';
import 'package:generic_search_selector/generic_search_selector.dart';

void main() {
  runApp(const RadioDemoApp());
}

class DemoItem {
  const DemoItem({required this.id, required this.label});
  final int id;
  final String label;

  @override
  String toString() => label;
}

class RadioDemoApp extends StatelessWidget {
  const RadioDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Radio Picker Demo', home: const RadioHome());
  }
}

class RadioHome extends StatefulWidget {
  const RadioHome({super.key});

  @override
  State<RadioHome> createState() => _RadioHomeState();
}

class _RadioHomeState extends State<RadioHome> {
  int? selectedId;
  int? selectedParentId; // For the parent picker test
  int? selectedSubId; // For testing sub-pickers in radio mode

  final List<DemoItem> mainItems = [
    const DemoItem(id: 1, label: 'Main 1'),
    const DemoItem(id: 2, label: 'Main 2'),
    const DemoItem(id: 3, label: 'Main 3'),
  ];

  final List<DemoItem> subItems = [
    const DemoItem(id: 10, label: 'Sub 1'),
    const DemoItem(id: 11, label: 'Sub 2'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radio Demo')),
      body: Column(
        children: [
          // Basic Radio Picker
          SearchAnchorPicker<DemoItem>(
            config: PickerConfig<DemoItem>(
              title: 'Radio Picker',
              loadItems: (_) async => mainItems,
              idOf: (it) => it.id,
              labelOf: (it) => it.label,
              searchTermsOf: (it) => [it.label],
            ),
            mode: PickerMode.radio,
            initialSelectedIds: selectedId == null ? [] : [selectedId!],
            onToggle: (item, next) async {
              if (next) {
                setState(() => selectedId = item.id);
                return true;
              }
              return false; // Cannot deselect in radio mode by clicking again
            },
            triggerBuilder: (context, open, _) => ElevatedButton(
              onPressed: open,
              child: Text(
                selectedId == null ? 'Select Main' : 'Main: $selectedId',
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Radio Picker with Sub-Picker
          SearchAnchorPicker<DemoItem>(
            config: PickerConfig<DemoItem>(
              title: 'Radio Parent',
              loadItems: (_) async => mainItems,
              idOf: (it) => it.id,
              labelOf: (it) => it.label,
              searchTermsOf: (it) => [it.label],
            ),
            mode: PickerMode.radio,
            initialSelectedIds: selectedParentId == null
                ? []
                : [selectedParentId!],
            onToggle: (item, next) async {
              if (next) {
                setState(() => selectedParentId = item.id);
                return true;
              }
              return false;
            },
            headerBuilder: (ctx, actions, _) => [
              ListTile(
                title: const Text('Open Sub Radio'),
                onTap: () {
                  // Navigate to sub picker logic here if needed for testing nesting.
                  // For now, let's keep it simple or implement if user asks for nested radio.
                  // The prompt said "radio sublists", which implies a sub-picker involved.
                },
              ),
              SearchAnchorPicker<DemoItem>(
                config: PickerConfig<DemoItem>(
                  title: 'Radio Sub',
                  loadItems: (_) async => subItems,
                  idOf: (it) => it.id,
                  labelOf: (it) => it.label,
                  searchTermsOf: (it) => [it.label],
                ),
                mode: PickerMode.radio, // Sub picker is also radio
                itemBuilder: (context, item, isSelected, onToggle) {
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (v) => onToggle(v),
                    title: Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.red,
                      ), // Custom styling
                    ),
                    subtitle: const Text('Custom Builder'),
                  );
                },
                triggerChild: const ListTile(
                  title: Text('Sub Radio Trigger (Tile)'),
                ),
                initialSelectedIds: selectedSubId == null
                    ? []
                    : [selectedSubId!],
                onToggle: (item, next) async {
                  if (next) {
                    setState(() => selectedSubId = item.id);
                    return true;
                  }
                  return false;
                },
              ),
            ],
            triggerBuilder: (context, open, _) => ElevatedButton(
              onPressed: open,
              child: Text(
                selectedParentId == null
                    ? 'Open Parent with Sub'
                    : 'Parent: $selectedParentId',
              ),
            ),
          ),

          if (selectedId != null) Text('Selected: $selectedId'),
          if (selectedSubId != null) Text('Sub Selected: $selectedSubId'),
        ],
      ),
    );
  }
}
