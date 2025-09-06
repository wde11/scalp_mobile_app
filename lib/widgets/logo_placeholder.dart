import 'package:flutter/material.dart';

class LogoPlaceholder extends StatelessWidget {
  final double? height;
  const LogoPlaceholder({Key? key, this.height}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Image.asset('assets/images/scalp_logo_w_v2.png'),
    );
  }
}
