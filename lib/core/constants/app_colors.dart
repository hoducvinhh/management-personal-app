import 'package:flutter/material.dart';

class AppColors {
  // Brand / Balance
  static const Color primary = Color(0xFF4F46E5); // Indigo Blue
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4338CA);

  // Income & Expense
  static const Color income = Color(0xFF10B981); // Emerald Green
  static const Color expense = Color(0xFFF43F5E); // Rose Coral

  // Budget Alerts
  static const Color budgetSafe = Color(0xFF10B981); // < 70% Green
  static const Color budgetWarning = Color(0xFFF59E0B); // 70% - 90% Amber
  static const Color budgetDanger = Color(0xFFEF4444); // > 90% Red

  // Dark Theme Palette (Slate OLED)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceLight = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Helper for budget color
  static Color getBudgetColor(double percent) {
    if (percent < 0.70) return budgetSafe;
    if (percent <= 0.90) return budgetWarning;
    return budgetDanger;
  }
}
