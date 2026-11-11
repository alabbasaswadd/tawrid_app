import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// أيقونات نظام التصميم — SVG مُصدَّرة من Figma (٢٤×٢٤، خط ٢px).
// تُلوَّن ديناميكياً عبر color، وبلون IconTheme الحالي عند إغفاله.
enum AppIcons {
  search('search'),
  scanBarcode('scan_barcode'),
  bell('bell'),
  home('home'),
  tag('tag'),
  clipboardList('clipboard_list'),
  fileText('file_text'),
  user('user'),
  sliders('sliders'),
  gift('gift'),
  plus('plus'),
  chevronBackRtl('chevron_back_rtl'),
  chevronForwardRtl('chevron_forward_rtl'),
  clock('clock'),
  mapPin('map_pin'),
  warehouse('warehouse'),
  package('package'),
  truck('truck'),
  pill('pill'),
  check('check'),
  x('x'),
  alertTriangle('alert_triangle'),
  pencil('pencil'),
  calendar('calendar'),
  eye('eye'),
  chevronDown('chevron_down'),
  chevronUp('chevron_up'),
  shoppingCart('shopping_cart'),
  logOut('log_out');

  const AppIcons(this._name);
  final String _name;

  String get asset => 'assets/icons/$_name.svg';
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {this.size = 24, this.color, super.key});

  final AppIcons icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      icon.asset,
      width: size,
      height: size,
      colorFilter: effective != null
          ? ColorFilter.mode(effective, BlendMode.srcIn)
          : null,
    );
  }
}
