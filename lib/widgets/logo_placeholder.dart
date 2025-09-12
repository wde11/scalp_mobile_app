import 'package:flutter/material.dart';

class LogoPlaceholder extends StatelessWidget {
  final double? height;
  const LogoPlaceholder({super.key, this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Image.asset('assets/images/scalp_logo_w_v2.png'),
    );
  }
}
