import 'package:flutter/material.dart';

class AppColors {
  // Brand / Balance
  static const Color primary = Color(0xFF6366F1); // Vivid Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);

  // Vibrant Signature Tab Colors
  static const Color tabOverview = Color(0xFF0EA5E9); // Vivid Sky Blue
  static const Color tabHistory = Color(0xFFF97316); // Bright Amber Orange
  static const Color tabBudget = Color(0xFF8B5CF6); // Royal Violet
  static const Color tabStats = Color(0xFF10B981); // Emerald Mint

  // Multi-Color Vibrant Accents
  static const Color cyan = Color(0xFF06B6D4);
  static const Color orange = Color(0xFFF97316);
  static const Color pink = Color(0xFFEC4899);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color teal = Color(0xFF14B8A6);

  // Income & Expense
  static const Color income = Color(0xFF10B981); // Emerald Green
  static const Color expense = Color(0xFFF43F5E); // Rose Coral

  // Budget Alerts
  static const Color budgetSafe = Color(0xFF10B981); // < 70% Green
  static const Color budgetWarning = Color(0xFFF59E0B); // 70% - 90% Amber
  static const Color budgetDanger = Color(0xFFEF4444); // > 90% Red

  // Aurora & Neon Multi-Color Gradients
  static const List<Color> heroGradient = [
    Color(0xFF312E81), // Deep Royal Indigo
    Color(0xFF6366F1), // Electric Indigo
    Color(0xFF8B5CF6), // Royal Violet
    Color(0xFFEC4899), // Neon Pink
    Color(0xFFF97316), // Warm Orange
  ];

  static const List<Color> fabGradient = [
    Color(0xFF06B6D4), // Cyan
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Neon Pink
  ];

  static const List<Color> budgetCardGradient = [
    Color(0xFF7C3AED), // Violet
    Color(0xFFC026D3), // Fuchsia
    Color(0xFFF43F5E), // Coral Red
  ];

  static const List<Color> statsCardGradient = [
    Color(0xFF0D9488), // Teal
    Color(0xFF0284C7), // Sky Blue
    Color(0xFF6366F1), // Indigo
  ];

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
