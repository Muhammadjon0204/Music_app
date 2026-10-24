import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/widget_view/bridge_page.dart';
import 'package:web/web.dart' as web;

/// Browsers embed the widget directly.
bool get soundCloudWidgetSupported => true;

Widget buildSoundCloudWidget({
  required SoundCloudLink link,
  required SoundCloudPlayerController controller,
}) => _IframeWidget(link: link, controller: controller);

class _IframeWidget extends StatefulWidget {
  const _IframeWidget({required this.link, required this.controller});

  final SoundCloudLink link;
  final SoundCloudPlayerController controller;

  @override
  State<_IframeWidget> createState() => _IframeWidgetState();
}

class _IframeWidgetState extends State<_IframeWidget> {
  web.HTMLIFrameElement? _frame;
  late final JSFunction _onMessage = _receive.toJS;

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('message', _onMessage);
    widget.controller.send = (command) =>
        _frame?.contentWindow?.postMessage(jsonEncode(command).toJS, '*'.toJS);
  }

  /// Only messages from this widget's own frame are accepted.
  void _receive(web.MessageEvent event) {
    final frame = _frame;
    if (frame == null || event.source != frame.contentWindow) return;
    final data = event.data;
    if (data.isA<JSString>()) {
      widget.controller.handleMessage((data as JSString).toDart);
    }
  }

  Future<void> _fill(web.HTMLIFrameElement frame) async {
    frame
      ..allow = 'autoplay; encrypted-media'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    _frame = frame;
    // Same-origin document, so its script can talk to this page.
    frame.srcdoc = (await loadBridgePage(widget.link)).toJS;
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessage);
    widget.controller.send = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: (element) =>
        unawaited(_fill(element as web.HTMLIFrameElement)),
  );
}
