import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';


class CoupangBanner extends StatefulWidget {
  const CoupangBanner({super.key});

  @override
  State<CoupangBanner> createState() => _CoupangBannerState();
}


class _CoupangBannerState extends State<CoupangBanner> {

  late final WebViewController controller;


  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString("""
<html>
<body>

<script src="https://ads-partners.coupang.com/g.js"></script>

<script>
new PartnersCoupang.G({
"id":984745,
"trackingCode":"AF3922097",
"subId":null,
"template":"carousel",
"width":"120",
"height":"50"
});
</script>

</body>
</html>
""");
  }


  @override
  Widget build(BuildContext context) {

    return WebViewWidget(
      controller: controller,
    );

  }
}