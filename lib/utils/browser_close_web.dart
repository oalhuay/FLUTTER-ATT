import 'dart:html' as html;

Future<bool> tryCloseBrowserWindow() async {
  try {
    html.window.open('', '_self');
    html.window.close();
    return true;
  } catch (_) {
    return false;
  }
}
