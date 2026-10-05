import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Keeps the original SVG proportions while displaying its embedded icon
/// separately. The icon's alpha channel was used as a white mask in the SVG.
class HomeLogo extends StatelessWidget {
  const HomeLogo({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ruamport',
    image: true,
    child: SizedBox(
      width: 100,
      height: 36,
      child: FittedBox(
        child: SizedBox(
          width: 162,
          height: 52,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 3,
                width: 49,
                height: 49,
                child: Image.asset(
                  'assets/branding/ruamport_icon.png',
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  excludeFromSemantics: true,
                ),
              ),
              SvgPicture.asset(
                'assets/branding/ruamport_wordmark.svg',
                width: 162,
                height: 52,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
