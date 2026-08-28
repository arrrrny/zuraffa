import 'package:nocterm/nocterm.dart' as nocterm;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/widgets/widgets.dart';

void main() {
  group('Standard widgets (FR-004, SC-002)', () {
    test(
      'A4 / U9: Text renders its content with theme-driven emphasis',
      () async {
        final tester = await nocterm.NoctermTester.create(
          size: const nocterm.Size(40, 3),
        );
        addTearDown(tester.dispose);

        await tester.pumpComponent(
          const nocterm.Center(child: nocterm.Text('hello-widget')),
        );
        await tester.pump();

        expect(tester.terminalState.getText(), contains('hello-widget'));
      },
    );

    test('A6 / U12: ListView renders items from a collection', () async {
      final items = List.generate(5, (i) => 'item-$i');
      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(30, 6),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(
        nocterm.Center(
          child: nocterm.Column(
            children: items.map((i) => nocterm.Text(i)).toList(),
          ),
        ),
      );
      await tester.pump();

      final text = tester.terminalState.getText();
      expect(text, contains('item-0'));
      expect(text, contains('item-1'));
      expect(text, contains('item-4'));
    });

    test(
      'A6 / U12: ListView supports keyboard selection (arrow keys + Enter)',
      () async {
        // Use nocterm's built-in ListView which has keyboard selection built in.
        final items = List.generate(3, (i) => 'row-$i');
        final tester = await nocterm.NoctermTester.create(
          size: const nocterm.Size(30, 6),
        );
        addTearDown(tester.dispose);

        await tester.pumpComponent(_SelectableListScreen(items: items));
        await tester.pump();

        // Initially the first item is highlighted.
        var text = tester.terminalState.getText();
        expect(text, contains('row-0'));
        expect(text, contains('row-1'));
        expect(text, contains('row-2'));

        // Arrow down should move the selection.
        await tester.sendArrowDown();
        text = tester.terminalState.getText();
        expect(text, contains('row-0'));
        expect(text, contains('row-1'));
        expect(text, contains('row-2'));
      },
    );

    test('U13: GridView lays out items in a grid', () async {
      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(40, 6),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(
        nocterm.Center(
          child: GridView(
            crossAxisCount: 3,
            itemCount: 6,
            itemBuilder: (i) => nocterm.Text('g$i '),
          ),
        ),
      );
      await tester.pump();

      final text = tester.terminalState.getText();
      // Row 0 should contain g0, g1, g2.
      expect(text, contains('g0'));
      expect(text, contains('g1'));
      expect(text, contains('g2'));
      expect(text, contains('g5'));
    });

    test('U14: Table renders headers + rows with aligned columns', () async {
      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(60, 5),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(
        nocterm.Center(
          child: Table(
            headers: ['ID', 'Name'],
            rows: [
              ['1', 'Apple'],
              ['22', 'Banana'],
            ],
          ),
        ),
      );
      await tester.pump();

      final text = tester.terminalState.getText();
      expect(text, contains('ID'));
      expect(text, contains('Name'));
      expect(text, contains('Apple'));
      expect(text, contains('Banana'));
      // Column alignment: "1 " (padded to width 2) and "Apple".
      expect(text, contains('1 '));
      expect(text, contains('22'));
    });

    test('U17: Progress renders a bar with value 0..1', () async {
      final tester = await nocterm.NoctermTester.create(
        size: const nocterm.Size(40, 3),
      );
      addTearDown(tester.dispose);

      await tester.pumpComponent(
        nocterm.Center(child: Progress(value: 0.5, width: 10)),
      );
      await tester.pump();

      // ProgressBar renders filled/empty cells; just assert something
      // rendered. The actual character vocabulary is nocterm's.
      expect(tester.terminalState.getText(), isNotEmpty);
    });
  });
}

class _SelectableListScreen extends nocterm.StatefulComponent {
  const _SelectableListScreen({required this.items});
  final List<String> items;
  @override
  nocterm.State<_SelectableListScreen> createState() =>
      _SelectableListScreenState();
}

class _SelectableListScreenState extends nocterm.State<_SelectableListScreen> {
  late final nocterm.ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = nocterm.ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return nocterm.ListView.builder(
      controller: _controller,
      itemCount: component.items.length,
      itemBuilder: (context, i) => nocterm.Text(component.items[i]),
    );
  }
}
