import 'dart:async';

import 'package:flutter/material.dart';
import 'package:generic_search_selector/picker_config.dart';
import 'package:generic_search_selector/search_anchor_picker.dart';


void main() {
  runApp(const DemoApp());
}

/// Simple item model.
class DemoItem {
  const DemoItem({
    required this.id,
    required this.label,
    required this.group,
  });

  final int id;
  final String label;
  final String group;

  @override
  String toString() => label;
}

/// “Provider-like” repository: holds a list and can mutate it.
/// (We keep 6 of these: listA, subA1, subA2, listB, subB1, subB2)
class ItemsRepo<T> extends ChangeNotifier {
  ItemsRepo(this._items);

  List<T> _items;

  List<T> get items => List.unmodifiable(_items);

  Future<List<T>> load() async => items;

  void setAll(List<T> next) {
    _items = List<T>.from(next);
    notifyListeners();
  }

  void addAll(Iterable<T> add, bool Function(T a, T b) same) {
    final out = List<T>.from(_items);
    for (final x in add) {
      if (!out.any((e) => same(e, x))) out.add(x);
    }
    _items = out;
    notifyListeners();
  }

  void removeWhere(bool Function(T x) test) {
    _items = _items.where((x) => !test(x)).toList();
    notifyListeners();
  }
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SearchAnchorPicker Demo',
      theme: ThemeData(useMaterial3: true),
      home: const DemoHome(),
    );
  }
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key});

  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  // ========== 6 “providers” ==========
  late final ItemsRepo<DemoItem> listA = ItemsRepo<DemoItem>(_initialListA());
  late final ItemsRepo<DemoItem> subA1 = ItemsRepo<DemoItem>(_initialSubA1());
  late final ItemsRepo<DemoItem> subA2 = ItemsRepo<DemoItem>(_initialSubA2());

  late final ItemsRepo<DemoItem> listB = ItemsRepo<DemoItem>(_initialListB());
  late final ItemsRepo<DemoItem> subB1 = ItemsRepo<DemoItem>(_initialSubB1());
  late final ItemsRepo<DemoItem> subB2 = ItemsRepo<DemoItem>(_initialSubB2());
  int? selectedRadioId;

  // Screen selections (not counted as “providers”).
  final Set<int> selectedOnScreenA = <int>{};
  final Set<int> selectedOnScreenB = <int>{};

  bool same(DemoItem a, DemoItem b) => a.id == b.id;

  DemoItem? findById(Iterable<DemoItem> xs, int id) {
    for (final x in xs) {
      if (x.id == id) return x;
    }
    return null;
  }

  PickerConfig<DemoItem> configForRepo(ItemsRepo<DemoItem> repo, {String? title}) {
    return PickerConfig<DemoItem>(
      title: title,
      loadItems: (_) => repo.load(),
      idOf: (it) => it.id,
      labelOf: (it) => it.label,
      searchTermsOf: (it) => [it.label, it.group, it.id.toString()],
      iconOf: (it) => Icon(
        it.group.contains('external') ? Icons.public : Icons.person,
        color: it.group.contains('external') ? null : Colors.grey,
      ),
      comparator: (a, b) => a.label.compareTo(b.label),
      selectedFirst: true,
    );
  }

  List<int> _ids(Set<int> s) => s.toList()..sort();

  @override
  void dispose() {
    listA.dispose();
    subA1.dispose();
    subA2.dispose();
    listB.dispose();
    subB1.dispose();
    subB2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainAConfig = configForRepo(listA, title: 'Icon #1 main list');
    final subA1Config = configForRepo(subA1, title: 'Sub A1');
    final subA2Config = configForRepo(subA2, title: 'Sub A2');

    final mainBConfig = configForRepo(listB, title: 'Icon #2 main list');
    final subB1Config = configForRepo(subB1, title: 'Sub B1');
    final subB2Config = configForRepo(subB2, title: 'Sub B2');

    return Scaffold(
      appBar: AppBar(title: const Text('SearchAnchorPicker Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Icon #1:\n'
              '- Sub pickers add/remove items into main list A\n'
              '- Selecting items in main list A toggles chips on screen',
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _CircleIconTrigger(
                  child: SearchAnchorPicker<DemoItem>(
                    config: mainAConfig,
                    initialSelectedIds: _ids(selectedOnScreenA),
                    mode: PickerMode.multi,

                    // Selecting in MAIN list => affects screen selection
                    onToggle: (item, next) async {
                      setState(() {
                        next ? selectedOnScreenA.add(item.id) : selectedOnScreenA.remove(item.id);
                      });
                      return true;
                    },

                    // Header has two sub pickers that modify listA contents
                    headerBuilder: (ctx) {
                      return [
                        _SubPickerTile(
                          title: 'Add/remove from Sub A1',
                          icon: Icons.playlist_add,
                          config: subA1Config,
                          seedIds: listA.items.map((e) => e.id).toList(),
                          onFinish: (ids, {required added, required removed}) async {
                            final addItems = added
                                .map((id) => findById(subA1.items, id))
                                .whereType<DemoItem>()
                                .toList();

                            listA.addAll(addItems, same);
                            listA.removeWhere((x) => removed.contains(x.id));
                          },
                        ),
                        _SubPickerTile(
                          title: 'Add/remove from Sub A2',
                          icon: Icons.playlist_add_check,
                          config: subA2Config,
                          seedIds: listA.items.map((e) => e.id).toList(),
                          onFinish: (ids, {required added, required removed}) async {
                            final addItems = added
                                .map((id) => findById(subA2.items, id))
                                .whereType<DemoItem>()
                                .toList();

                            listA.addAll(addItems, same);
                            listA.removeWhere((x) => removed.contains(x.id));
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.clear_all),
                          title: const Text('Clear screen selection A'),
                          onTap: () {
                            final scope = PickerScope.of<DemoItem>(ctx);
                            setState(() => selectedOnScreenA.clear());
                            scope.setPending(<int>{}); // UI inside overlay
                          },
                        ),
                        const Divider(height: 1),
                      ];
                    },

                    // Trigger builder: icon only (circle ripple)
                    triggerBuilder: (_, open, version) {
                      final has = selectedOnScreenA.isNotEmpty;
                      return IconButton(
                        tooltip: 'Open picker A',
                        iconSize: 40,
                        onPressed: open,
                        icon: Icon(
                          has ? Icons.person_search : Icons.person_search_outlined,
                          color: has ? Colors.green : null,
                        ),
                      );
                    },

                    // When overlay closes, rebuild to reflect latest listA changes, etc.
                    onFinish: (finalIds, {required added, required removed}) async {
                      // no-op in demo
                    },
                    maxHeight: MediaQuery.sizeOf(context).height * 2 / 3,
                    minWidth: 520,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _SelectedChips(title: 'Selected on screen A', ids: selectedOnScreenA)),
              ],
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 28),

            const Text(
              'Icon #2:\n'
              '- Sub pickers toggle chips on screen B (do NOT change main list B)\n'
              '- Selecting items in main list B also toggles chips on screen',
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _CircleIconTrigger(
                  child: SearchAnchorPicker<DemoItem>(
                    config: mainBConfig,
                    initialSelectedIds: _ids(selectedOnScreenB),
                    mode: PickerMode.multi,

                    // Selecting in MAIN list => affects screen selection
                    onToggle: (item, next) async {
                      setState(() {
                        next ? selectedOnScreenB.add(item.id) : selectedOnScreenB.remove(item.id);
                      });
                      return true;
                    },

                    headerBuilder: (ctx) {
                      return [
                        _SubPickerTile(
                          title: 'Select from Sub B1 (to screen)',
                          icon: Icons.person_add_alt_1,
                          config: subB1Config,
                          seedIds: _ids(selectedOnScreenB),
                          onFinish: (ids, {required added, required removed}) async {
                            setState(() {
                              selectedOnScreenB
                                ..addAll(added)
                                ..removeAll(removed);
                            });
                          },
                        ),
                        _SubPickerTile(
                          title: 'Select from Sub B2 (to screen)',
                          icon: Icons.person_add_alt,
                          config: subB2Config,
                          seedIds: _ids(selectedOnScreenB),
                          onFinish: (ids, {required added, required removed}) async {
                            setState(() {
                              selectedOnScreenB
                                ..addAll(added)
                                ..removeAll(removed);
                            });
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.clear_all),
                          title: const Text('Clear screen selection B'),
                          onTap: () {
                            final scope = PickerScope.of<DemoItem>(ctx);
                            setState(() => selectedOnScreenB.clear());
                            scope.setPending(<int>{});
                          },
                        ),
                        const Divider(height: 1),
                      ];
                    },

                    triggerBuilder: (_, open, version) {
                      final has = selectedOnScreenB.isNotEmpty;
                      return IconButton(
                        tooltip: 'Open picker B',
                        iconSize: 40,
                        onPressed: open,
                        icon: Icon(
                          has ? Icons.group_add : Icons.group_add_outlined,
                          color: has ? Colors.green : null,
                        ),
                      );
                    },

                    maxHeight: MediaQuery.sizeOf(context).height * 2 / 3,
                    minWidth: 520,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _SelectedChips(title: 'Selected on screen B', ids: selectedOnScreenB)),
              ],
            ),


            const SizedBox(height: 28),
const Divider(),
const SizedBox(height: 28),

const Text(
  'Icon #3 (radio mode):\n'
  '- Single select\n'
  '- Click selects one item and closes the popup immediately',
),
const SizedBox(height: 8),

Row(
  children: [
    _CircleIconTrigger(
      child: SearchAnchorPicker<DemoItem>(
        config: configForRepo(
          listA,
          title: 'Radio picker demo',
        ),
        mode: PickerMode.radio,

        // Seed selection for radio (0 or 1 item).
        initialSelectedIds: selectedRadioId == null ? const [] : [selectedRadioId!],

        // In radio mode, toggling "true" is the selection action.
        // (The picker itself will close automatically after it sets pending.)
        onToggle: (item, next) async {
          if (!next) return false; // ignore deselect in radio mode
          setState(() => selectedRadioId = item.id);
          return true;
        },

        triggerBuilder: (_, open, version) {
          final has = selectedRadioId != null;
          return IconButton(
            tooltip: 'Open radio picker',
            iconSize: 40,
            onPressed: open,
            icon: Icon(
              has ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: has ? Colors.green : null,
            ),
          );
        },

        // Optional: onFinish fires after close (diff vs open snapshot).
        onFinish: (finalIds, {required added, required removed}) async {
          // In radio, finalIds is either [] or [id].
          // We already set selectedRadioId in onToggle, so this can be a no-op.
        },

        maxHeight: MediaQuery.sizeOf(context).height * 2 / 3,
        minWidth: 520,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected radio item', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (selectedRadioId == null)
                const Text('No selection')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('#$selectedRadioId')),
                    TextButton(
                      onPressed: () => setState(() => selectedRadioId = null),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  ],
),

          ],
        ),
      ),
    );
  }

  // ===== demo data =====

  List<DemoItem> _initialListA() => const [
        DemoItem(id: 1, label: 'A: Alice (internal)', group: 'internal'),
        DemoItem(id: 2, label: 'A: Bob (internal)', group: 'internal'),
      ];

  List<DemoItem> _initialSubA1() => const [
        DemoItem(id: 10, label: 'A1: Charlie (external)', group: 'external'),
        DemoItem(id: 11, label: 'A1: Diana (external)', group: 'external'),
        DemoItem(id: 12, label: 'A1: This label is very very long to force ellipsis tooltip', group: 'external'),
      ];

  List<DemoItem> _initialSubA2() => const [
        DemoItem(id: 20, label: 'A2: Ethan (internal)', group: 'internal'),
        DemoItem(id: 21, label: 'A2: Fiona (internal)', group: 'internal'),
      ];

  List<DemoItem> _initialListB() => const [
        DemoItem(id: 101, label: 'B: Igor (internal)', group: 'internal'),
        DemoItem(id: 102, label: 'B: Julia (internal)', group: 'internal'),
      ];

  List<DemoItem> _initialSubB1() => const [
        DemoItem(id: 110, label: 'B1: Ken (external)', group: 'external'),
        DemoItem(id: 111, label: 'B1: Lina (external)', group: 'external'),
      ];

  List<DemoItem> _initialSubB2() => const [
        DemoItem(id: 120, label: 'B2: Max (internal)', group: 'internal'),
        DemoItem(id: 121, label: 'B2: Nina (internal)', group: 'internal'),
      ];
}

class _CircleIconTrigger extends StatelessWidget {
  const _CircleIconTrigger({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        radius: 28,
        containedInkWell: true,
        highlightShape: BoxShape.circle,
        child: ClipOval(child: child),
      ),
    );
  }
}

/// Sub-picker shown as a header tile that opens its own overlay.
class _SubPickerTile extends StatelessWidget {
  const _SubPickerTile({
    required this.title,
    required this.icon,
    required this.config,
    required this.seedIds,
    required this.onFinish,
  });

  final String title;
  final IconData icon;
  final PickerConfig<DemoItem> config;

  /// Which ids should be selected when opening the sub picker.
  final List<int> seedIds;

  final OnFinish onFinish;

  @override
  Widget build(BuildContext context) {
    return SearchAnchorPicker<DemoItem>(
      config: config,
      initialSelectedIds: seedIds,
      mode: PickerMode.multi,
      triggerChild: ListTile(
        leading: Icon(icon),
        title: Text(title),
      ),
      onFinish: onFinish,
      maxHeight: MediaQuery.sizeOf(context).height * 2 / 3,
      minWidth: 520,
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({
    required this.title,
    required this.ids,
  });

  final String title;
  final Set<int> ids;

  @override
  Widget build(BuildContext context) {
    final list = ids.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Text('No selection')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in list)
                    Chip(
                      label: Text('#$id'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
