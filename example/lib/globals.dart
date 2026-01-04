import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

extension ScreenDouble on double {
  double get w => this * Globals.screenWidth;
  double get h => this * Globals.screenHeight;
}

class Globals {
  final BuildContext context;
  static Globals? _instance;

  static Globals get instance {
    final instance = _instance;
    if (instance == null) throw AssertionError('Globals not initialized');
    return instance;
  }

  Globals._(this.context);

  FlutterView get view => View.of(context);

  static initialize(BuildContext context) => _instance = Globals._(context);

  static double get rawScreenWidth =>
      instance.view.physicalSize.width / instance.view.devicePixelRatio;

  static double get rawScreenHeight =>
      instance.view.physicalSize.height / instance.view.devicePixelRatio;

  static double get screenWidth => min(rawScreenWidth, 500);

  static double get screenHeight => rawScreenHeight;

  static double get screenPadding => min(min(10, 0.1.w), 0.1.h);

  static double get borderRadiusValue => 0.02.w;

  static BorderRadius get borderRadius =>
      BorderRadius.circular(borderRadiusValue);

  static String? validateNum(String? text, [bool isDouble = true]) {
    text ??= '';
    if (text.isEmpty) return null;
    final value = isDouble ? double.tryParse(text) : int.tryParse(text);
    if (value == null) {
      return 'Value should be of ${isDouble ? 'double' : 'int'} type';
    }
    return null;
  }

  // Constants
  static const kCircularBorderRadiusValue = 1e+5;
  static const kCircularBorder =
      BorderRadius.all(Radius.circular(kCircularBorderRadiusValue));
  static const kDisabledOpacity = 0.3;
  static const kPaddingValue = 10.0;

  // Object Constants
  static const kCreatedAtProperty = 'createdAt';
  static const kUpdatedAtProperty = 'updatedAt';
  static const kIdProperty = 'id';
}

