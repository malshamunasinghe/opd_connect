import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';
import '../services/db.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Buttons - primary, secondary (outlined) and danger, each >= 48 px tall.
// A built-in loading state gives the tap feedback asked for in M02 issue U5.
// ---------------------------------------------------------------------------

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  const PrimaryButton(this.label, {super.key, this.onPressed, this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    return icon == null || loading
        ? ElevatedButton(onPressed: loading ? null : onPressed, child: child)
        : ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => icon == null
      ? OutlinedButton(onPressed: onPressed, child: Text(label))
      : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
}

class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const DangerButton(this.label, {super.key, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.danger,
      foregroundColor: Colors.white,
    );
    final child = loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
        : Text(label);
    return icon == null || loading
        ? ElevatedButton(style: style, onPressed: loading ? null : onPressed, child: child)
        : ElevatedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon), label: child);
  }
}

// ---------------------------------------------------------------------------
// Input field with the label above the box (easier to read than a floating
// label for older users).
// ---------------------------------------------------------------------------

class AppInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextCapitalization capitalization;
  final bool enabled;

  const AppInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.suffix,
    this.onChanged,
    this.capitalization = TextCapitalization.none,
    this.enabled = true,
  });

  /// Phone and number fields accept digits only, so letters cannot be typed.
  List<TextInputFormatter>? _formatters() {
    if (keyboardType == TextInputType.phone) {
      return [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(12)];
    }
    if (keyboardType == TextInputType.number) {
      return [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.grid * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            validator: validator,
            // The "invalid" message appears as soon as the user has typed in
            // the field, not only when they press the submit button.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            inputFormatters: _formatters(),
            keyboardType: keyboardType,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            onChanged: onChanged,
            enabled: enabled,
            textCapitalization: capitalization,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Token chip - filled for the user's own token, muted for the token being
// served (M02 lo-fi feedback: "which token is mine?").
// ---------------------------------------------------------------------------

class TokenChip extends StatelessWidget {
  final String label;
  final bool filled;
  final double fontSize;
  final Color? color;
  const TokenChip(this.label, {super.key, this.filled = true, this.fontSize = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouch, minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? c : AppColors.n200,
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: filled ? Colors.white : AppColors.n600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appointment card
// ---------------------------------------------------------------------------

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final String statusText;
  final VoidCallback? onTap;
  final Widget? footer;
  final bool highlight;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.statusText,
    this.onTap,
    this.footer,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final t = Theme.of(context).textTheme;
    return Card(
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              side: const BorderSide(color: AppColors.primary, width: 2))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.grid * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TokenChip(a.tokenLabel, filled: a.isActive, fontSize: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.department, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(a.hospitalName, style: t.bodySmall),
                      ],
                    ),
                  ),
                  StatusPill(status: a.status, text: statusText),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event, size: 20, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Flexible(child: Text(formatDay(a.date), style: t.bodyMedium)),
                  const SizedBox(width: 16),
                  const Icon(Icons.schedule, size: 20, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Text(a.startTime, style: t.bodyMedium),
                ],
              ),
              if (a.doctorName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.medical_services_outlined, size: 20, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Flexible(child: Text(a.doctorName, style: t.bodyMedium)),
                ]),
              ],
              if (a.bookedFor == 'other') ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.family_restroom, size: 20, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('For ${a.patientName}${a.relation.isEmpty ? '' : ' (${a.relation})'}',
                        style: t.bodyMedium),
                  ),
                ]),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final String text;
  const StatusPill({super.key, required this.status, required this.text});

  static Color colorFor(String status) {
    switch (status) {
      case AppointmentStatus.serving:
        return AppColors.success;
      case AppointmentStatus.completed:
        return AppColors.n600;
      case AppointmentStatus.cancelled:
        return AppColors.danger;
      case AppointmentStatus.noShow:
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator "Step 1 of 3" (M02 issue U2 fix).
// ---------------------------------------------------------------------------

class StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final String stepWord;
  const StepIndicator({super.key, required this.current, required this.total, required this.stepWord});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$stepWord $current / $total',
      child: Row(
        children: [
          Text('$stepWord $current / $total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          for (var i = 1; i <= total; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.primary : AppColors.n200,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// System states - loading, empty and error (M02 Section 6 "System states").
// ---------------------------------------------------------------------------

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: 16), Text(message!)],
        ]),
      );
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyView({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: AppColors.n400),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              PrimaryButton(actionLabel!, onPressed: onAction),
            ],
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(friendlyError(error), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SecondaryButton('Try again', onPressed: onRetry),
            ],
          ]),
        ),
      );
}

/// Stream wrapper that shows the three system states. Unlike a plain
/// StreamBuilder it keeps showing the last data while it re-subscribes to a
/// new stream instance, so rebuilds never flash a loading spinner.
class StreamView<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext, T) builder;
  final String? loadingMessage;
  const StreamView({super.key, required this.stream, required this.builder, this.loadingMessage});

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  StreamSubscription<T>? _sub;
  T? _data;
  bool _hasData = false;
  Object? _error;

  void _listen() {
    _sub?.cancel();
    _sub = widget.stream.listen(
      (d) => setState(() {
        _data = d;
        _hasData = true;
        _error = null;
      }),
      onError: (Object e) => setState(() => _error = e),
    );
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant StreamView<T> old) {
    super.didUpdateWidget(old);
    if (!identical(old.stream, widget.stream)) _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && !_hasData) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() => _error = null);
          _listen();
        },
      );
    }
    if (!_hasData) return LoadingView(message: widget.loadingMessage);
    return widget.builder(context, _data as T);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const InfoRow(this.label, this.value, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[Icon(icon, size: 20, color: AppColors.n600), const SizedBox(width: 8)],
          SizedBox(
              width: 130, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 14))),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String formatDay(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
String formatDateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.n900,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Runs [action], showing a SnackBar with a friendly message on failure.
/// Returns true on success.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
    return false;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  String cancelLabel = 'Back',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: danger ? AppColors.danger : AppColors.primary),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Prompts for a short text (e.g. a reason). Returns null if cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool required = true,
  int maxLines = 3,
}) async {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
          validator: (v) {
            final t = (v ?? '').trim();
            if (required && t.isEmpty) return 'Required';
            if (t.length > 300) return 'Keep it under 300 characters';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return res;
}
