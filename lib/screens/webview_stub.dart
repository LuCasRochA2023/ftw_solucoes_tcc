import 'package:flutter/widgets.dart';

class WebView extends StatelessWidget {
  final String? initialUrl;
  final dynamic javascriptMode;
  final void Function(String)? onPageStarted;
  final void Function(String)? onPageFinished;
  const WebView(
      {super.key, this.initialUrl,
      this.javascriptMode,
      this.onPageStarted,
      this.onPageFinished});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

enum JavascriptMode {
  unrestricted,
}
