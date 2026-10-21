import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/search/search_query_provider.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Search foundation: input, debounced query and its states. There is no
/// searchable library yet, so a query honestly reports no results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.focusRequest});

  /// When it changes, the field takes focus (e.g. after tapping the search
  /// field on Home).
  final String? focusRequest;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.focusRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.focusRequest;
    if (request != null && request != oldWidget.focusRequest) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final text = context.auraText;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AuraSpacing.screenHorizontal,
                  AuraSpacing.lg,
                  AuraSpacing.screenHorizontal,
                  AuraSpacing.md,
                ),
                child: Semantics(
                  header: true,
                  child: Text(AuraStrings.tabSearch, style: text.largeTitle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpacing.screenHorizontal,
                ),
                child: AuraSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: AuraStrings.searchPlaceholder,
                  onChanged: ref
                      .read(searchQueryProvider.notifier)
                      .onInputChanged,
                ),
              ),
              Expanded(
                // Tapping outside the field hides the keyboard.
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // A convenience for touch only; VoiceOver users dismiss the
                  // keyboard natively, and an unlabeled full-screen "button"
                  // would only confuse them.
                  excludeFromSemantics: true,
                  onTap: _focusNode.unfocus,
                  child: AuraStateSwitcher(
                    child: query.isEmpty
                        ? const AuraEmptyState(
                            key: ValueKey('hint'),
                            icon: CupertinoIcons.search,
                            title: AuraStrings.searchHintTitle,
                            message: AuraStrings.searchHintMessage,
                          )
                        : AuraEmptyState(
                            key: const ValueKey('no-results'),
                            icon: CupertinoIcons.search,
                            title: AuraStrings.searchNoResultsTitle(query),
                            message: AuraStrings.searchNoResultsMessage,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
