import 'package:flutter/material.dart';

abstract final class TawridColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF0A4FA6);
  static const Color primaryLight  = Color(0xFF1565C0);
  static const Color primaryDark   = Color(0xFF003D82);
  static const Color accent        = Color(0xFF00ACC1);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A4FA6), Color(0xFF0097A7)],
  );

  static const LinearGradient warehouseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4527A0), Color(0xFF7B1FA2)],
  );

  static const LinearGradient pharmacyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00695C), Color(0xFF00897B)],
  );

  // ── Role colors ────────────────────────────────────────────────────────────
  static const Color pharmacy   = Color(0xFF00897B);
  static const Color warehouse  = Color(0xFF5E35B1);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF00C853);
  static const Color warning  = Color(0xFFFF9100);
  static const Color error    = Color(0xFFE53935);
  static const Color info     = Color(0xFF1E88E5);

  // ── Neutrals ───────────────────────────────────────────────────────────────
  static const Color background    = Color(0xFFF0F4FF);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F7FE);
  static const Color border        = Color(0xFFE0E7FF);
  static const Color hint          = Color(0xFF8898AA);
  static const Color textPrimary   = Color(0xFF0D1B3E);
  static const Color textSecondary = Color(0xFF4A5568);

  // ── Status order/tender ───────────────────────────────────────────────────
  static const Color statusPending    = Color(0xFFFF9100);
  static const Color statusAccepted   = Color(0xFF1E88E5);
  static const Color statusProcessing = Color(0xFF5E35B1);
  static const Color statusReady      = Color(0xFF00ACC1);
  static const Color statusDelivering = Color(0xFF039BE5);
  static const Color statusCompleted  = Color(0xFF00C853);
  static const Color statusCancelled  = Color(0xFFE53935);
}
