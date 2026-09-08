import 'package:flutter/material.dart';

/// Centralized color palette for the Rahbar app,
/// pulled from the splash / signup / login designs.
class AppColors {
  AppColors._(); // prevent instantiation

  // ---- Backgrounds ----
  static const Color background = Color(0xFFFCEEE9); // soft blush background
  static const Color ringColor = Color(
    0xFFF2D9CF,
  ); // lighter ring behind the logo circle

  // ---- Brand ----
  static const Color primaryPurple = Color(
    0xFF7C3F62,
  ); // logo circle + primary button
  static const Color primaryPurpleDark = Color(
    0xFF5E2F4B,
  ); // pressed/hover state

  // ---- Text ----
  static const Color title = Color(0xFF262631); // near-black serif heading
  static const Color subtitle = Color(0xFF9B95A3); // muted grey supporting text
  static const Color fieldLabel = Color(0xFF6B6675); // grey field labels
  static const Color onPrimary =
      Colors.white; // text/icons on the purple button

  // ---- Buttons / borders ----
  static const Color outlineButtonBorder = Color(
    0xFFE7D9D4,
  ); // outlined button border

  // ---- Form fields ----
  static const Color fieldFill = Colors.white;
  static const Color fieldBorder = Color(0xFFF0E2DC);
  static const Color fieldHint = Color(0xFFB6AFB9);
  static const Color helperText = Color(0xFFB0A9B3);
  static const Color success = Color(0xFF4E9A6B); // validated field checkmark

  // ---- Alerts ----
  static const Color alertDanger = Color(
    0xFFD64545,
  ); // error / destructive alerts
  static const Color alertMaroon = Color(
    0xFF7C2F3E,
  ); // deeper maroon accent for buttons/badges
  static const Color alertMaroonLight = Color(
    0xFFA85C6B,
  ); // lighter maroon accent for buttons/badges

  // ---- Misc ----
  static const Color homeIndicator = Color(
    0xFF262631,
  ); // bottom drag-handle bar
  static const Color eveningDark = Color(
    0xFF2E2438,
  ); // dark plum, evening/night themed surface
  static const Color eveningCard = Color(
    0xFF3D3247,
  ); // card surface on top of eveningDark background
}
