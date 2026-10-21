import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/search/search_query_provider.dart';

void main() {
  // testWidgets gives a fake clock for the debounce timer.
  testWidgets('publishes the query once typing pauses', (tester) async {
    final container = ProviderContainer.test();
    final notifier = container.read(searchQueryProvider.notifier);

    notifier.onInputChanged('a');
    await tester.pump(const Duration(milliseconds: 100));
    notifier.onInputChanged('ab');
    await tester.pump(const Duration(milliseconds: 100));
    notifier.onInputChanged(' abc ');

    await tester.pump(
      SearchQueryController.debounce - const Duration(milliseconds: 1),
    );
    expect(container.read(searchQueryProvider), '');

    await tester.pump(const Duration(milliseconds: 1));
    expect(container.read(searchQueryProvider), 'abc');
  });

  testWidgets('clearing the input clears the query immediately', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    final notifier = container.read(searchQueryProvider.notifier);

    notifier.onInputChanged('abc');
    await tester.pump(SearchQueryController.debounce);
    notifier.onInputChanged('   ');

    expect(container.read(searchQueryProvider), '');
    // A pending timer from before must not resurrect the old query.
    await tester.pump(SearchQueryController.debounce);
    expect(container.read(searchQueryProvider), '');
  });
}
