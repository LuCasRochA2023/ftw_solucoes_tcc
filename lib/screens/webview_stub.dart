import 'package:flutter/widgets.dart';

class WebView extends StatelessWidget {
  final String? initialUrl;
  final dynamic javascriptMode;
  final void Function(String)? onPageStarted;
  final void Function(String)? onPageFinished;
  const WebView(
      {this.initialUrl,
      this.javascriptMode,
      this.onPageStarted,
      this.onPageFinished});
  @override
  Widget build(BuildContext context) => SizedBox.shrink();
}

enum JavascriptMode {
  unrestricted,
}
