import 'package:flutter/material.dart';

import 'theme.dart';

/// Reusable building blocks for the redesigned screens (home, booking,
/// records, profile, staff overview). They follow the M02 design system:
/// 8 px grid, 12 px radius, 48 px touch targets, Primary green.

/// Round avatar with the person's initials.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final Color? background;
  const InitialsAvatar(this.name, {super.key, this.radius = 24, this.background});

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: background ?? Colors.white.withValues(alpha: 0.22),
        child: Text(
          initialsOf(name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
        ),
      );
}

/// Green banner at the top of a tab: greeting / title plus an optional
/// trailing widget and a child that overlaps the content below.
class GradientHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GradientHeader({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28)});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).appBarTheme.backgroundColor ?? AppColors.primary;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dark, Color.lerp(dark, AppColors.success, 0.45)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

/// A square-ish action button: icon in a tinted circle with a label.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final int badge;
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: c, size: 26),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A fixed-height grid of [QuickAction]s inside a card. A fixed row height
/// (instead of an aspect ratio) keeps it from overflowing at large text sizes.
class ActionGrid extends StatelessWidget {
  final List<Widget> children;
  const ActionGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 100 + 22 * (scale - 1).clamp(0.0, 1.2),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// Number with a caption, used in stat rows.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;
  const StatTile({super.key, required this.value, required this.label, this.icon, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(children: [
            if (icon != null) ...[Icon(icon, color: c, size: 22), const SizedBox(height: 4)],
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c)),
            Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

/// Thin progress bar, e.g. places taken in a clinic session.
class MeterBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const MeterBar({super.key, required this.value, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          minHeight: height,
          color: color,
          backgroundColor: AppColors.n200,
        ),
      );
}

/// Coloured message strip: info / warning / success / error.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Widget? action;
  const InfoBanner({super.key, required this.icon, required this.message, this.color = AppColors.primary, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
          if (action != null) action!,
        ]),
      );
}

/// Small rounded label, e.g. a department or blood group.
class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }
}

/// A settings / menu row inside a card: icon, title, optional subtitle.
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  const MenuTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
        minVerticalPadding: 12,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color ?? AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
        onTap: onTap,
      );
}

/// Password strength meter shown under the "Create password" field.
class PasswordStrength extends StatelessWidget {
  final String password;
  const PasswordStrength(this.password, {super.key});

  static int score(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final sc = score(password);
    final labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [AppColors.danger, AppColors.danger, AppColors.accent, AppColors.success, AppColors.success];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Expanded(child: MeterBar(value: (sc + 1) / 5, color: colors[sc])),
        const SizedBox(width: 12),
        Text(labels[sc], style: TextStyle(color: colors[sc], fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
