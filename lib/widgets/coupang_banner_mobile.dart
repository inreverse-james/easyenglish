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
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  body {
    margin: 0;
    padding: 0;
  }
</style>
</head>
<body>
<script src="https://ads-partners.coupang.com/g.js"></script>
<script>
new PartnersCoupang.G({
  "id":984745,
  "trackingCode":"AF3922097",
  "subId":null,
  "template":"carousel",
  "width":"320", 
  "height":"50"
});
</script>
</body>
</html>
""");
  }

  @override
  Widget build(BuildContext context) {
    // 웹뷰 자체의 크기를 120x50으로 제한하고 화면 중앙에 배치합니다.
    return Center(
      child: SizedBox(
        width: 320,
        height: 50,
        child: WebViewWidget(
          controller: controller,
        ),
      ),
    );
  }
}