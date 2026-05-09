import 'package:flutter/material.dart';

/// Tokens de cor do design system DublyDesk.
/// Mantenha em sync com Docs/design/DESIGN.md.
class AppColors {
  AppColors._();

  // -------- Dark theme --------
  static const Color darkBackground = Color(0xFF13131B);
  static const Color darkSurfaceCard = Color(0xFF1E293B);
  static const Color darkSurfaceContainer = Color(0xFF1F1F27);
  static const Color darkSurfaceContainerHigh = Color(0xFF292932);
  static const Color darkOutline = Color(0xFF464554);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // -------- Light theme --------
  static const Color lightBackground = Color(0xFFF4F3FF);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainer = Color(0xFFEDEBFF);
  static const Color lightOutline = Color(0xFFD8D6E8);
  static const Color lightTextPrimary = Color(0xFF1B1A27);
  static const Color lightTextSecondary = Color(0xFF46454E);

  // -------- Brand / shared --------
  static const Color primary = Color(0xFF494BD6);
  static const Color primaryLight = Color(0xFFC0C1FF);
  static const Color secondary = Color(0xFF4EDEA3);
  static const Color secondaryDark = Color(0xFF00A572);
  static const Color statusPending = Color(0xFF64748B);
  static const Color error = Color(0xFFEF4444);
  static const Color tertiary = Color(0xFFFFB783);

  // Aux helpers (status, charts)
  static const Color chartBar = primary;
  static const Color chartBarActive = primaryLight;
}
