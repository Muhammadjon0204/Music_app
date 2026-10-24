import 'package:flutter/services.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';

/// The bridge page with [link]'s official widget URL filled in.
Future<String> loadBridgePage(SoundCloudLink link) async {
  final template = await rootBundle.loadString('assets/soundcloud/bridge.html');
  return template.replaceFirst(
    '{{WIDGET_URL}}',
    _attribute('${link.widgetUrl}'),
  );
}

/// Escapes a value for an HTML attribute in double quotes.
String _attribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
