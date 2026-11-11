import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Mat Zemin ve Yüzeyler (Minimalist Antrasit - Koyu)
  static const Color bgPrimary = Color(0xFF0F1115);
  static const Color surface = Color(0xFF16191F);
  static const Color surfaceBorder = Color(0xFF242A35);
  static const Color surfaceSubtle = Color(0xFF1E232B);

  // Mat Zemin ve Yüzeyler (Minimalist İskandinav - Aydınlık)
  static const Color bgPrimaryLight = Color(0xFFF7F9FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceBorderLight = Color(0xFFE2E8F0);
  static const Color surfaceSubtleLight = Color(0xFFEDF2F7);

  // Vurgu ve Durum Renkleri (Mat ve Doğal)
  static const Color primarySage = Color(0xFF2D6A4F);
  static const Color primaryLight = Color(0xFF52B788);
  static const Color textPrimary = Color(0xFFF1F3F5);
  static const Color textSecondary = Color(0xFF8A94A6);
  static const Color textMuted = Color(0xFF5A6272);

  // Aydınlık Tema Metin Renkleri
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color statusPending = Color(0xFFD97706);
  static const Color statusResolved = Color(0xFF2D6A4F);
  static const Color statusError = Color(0xFFDC2626);

  // Sade Sıralama Rozet Renkleri (Mat)
  static const Color rankGold = Color(0xFFD4A72C);
  static const Color rankSilver = Color(0xFF94A3B8);
  static const Color rankBronze = Color(0xFFB47B48);

  // Mevcut Servis / Widget Uyumluluk Tokenları
  static const Color primary = primarySage;
  static const Color secondary = primaryLight;
  static const Color tertiary = Color(0xFF74C69D);
  static const Color background = bgPrimary;

  // Atık Türü Renkleri (Mat)
  static const Color plastic = Color(0xFFD97706);
  static const Color glass = primaryLight;
  static const Color paper = Color(0xFF3B82F6);
  static const Color metal = Color(0xFF6B7280);
  static const Color organic = Color(0xFF92400E);

  // Dinamik Tema Çözümleyicileri
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgPrimaryOf(BuildContext context) =>
      isDark(context) ? bgPrimary : bgPrimaryLight;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? surface : surfaceLight;

  static Color surfaceBorderOf(BuildContext context) =>
      isDark(context) ? surfaceBorder : surfaceBorderLight;

  static Color surfaceSubtleOf(BuildContext context) =>
      isDark(context) ? surfaceSubtle : surfaceSubtleLight;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? textPrimary : textPrimaryLight;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? textSecondary : textSecondaryLight;

  static Color textMutedOf(BuildContext context) =>
      isDark(context) ? textMuted : textMutedLight;
}
