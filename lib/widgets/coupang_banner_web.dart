import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class CoupangBanner extends StatefulWidget {
  const CoupangBanner({super.key});

  @override
  State<CoupangBanner> createState() => _CoupangBannerState();
}

class _CoupangBannerState extends State<CoupangBanner> {
  late final String viewId;

  @override
  void initState() {
    super.initState();

    viewId = "coupang-${DateTime.now().millisecondsSinceEpoch}";

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final iframe = web.HTMLIFrameElement();

        iframe.style
          ..border = "0"
          ..width = "100%"
          ..height = "100%";

        iframe.srcdoc = """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>
html,body{
    margin:0;
    padding:0;
    width:100%;
    height:100%;
    overflow:hidden;

    display:flex;
    justify-content:center;
    align-items:center;
}

#ad-wrapper{
    width:320px;
    height:50px;
    display:flex;
    justify-content:center;
    align-items:center;
}
</style>

</head>

<body>

<div id="ad-wrapper">

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

</div>

</body>
</html>
"""
            .toJS;

        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // 광고가 사용할 최대 폭(좌우 16px 여백)
    final availableWidth = screenWidth - 32;

    // 320 기준 자동 축소
    double scale = availableWidth / 320;

    // 확대는 하지 않음
    if (scale > 1.0) scale = 1.0;

    // 너무 작아지면 제한
    if (scale < 0.75) scale = 0.75;

    return Center(
      child: SizedBox(
        width: 320 * scale,
        height: 50 * scale,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: SizedBox(
            width: 320,
            height: 50,
            child: HtmlElementView(
              viewType: viewId,
            ),
          ),
        ),
      ),
    );
  }
}