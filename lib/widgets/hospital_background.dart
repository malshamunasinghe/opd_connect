import 'package:flutter/material.dart';

class HospitalBackground extends StatelessWidget {
  final Widget child;

  const HospitalBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBFE6D3), Color(0xFFE3F4EC), Colors.white],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              return Stack(
                children: [
                  _positioned(width * 0.05, height * 0.08, Icons.local_hospital_outlined, 42, -0.16),
                  _positioned(width * 0.82, height * 0.16, Icons.medical_services_outlined, 34, 0.12),
                  _positioned(width * 0.02, height * 0.31, Icons.monitor_heart_outlined, 38, 0.08),
                  _positioned(width * 0.86, height * 0.37, Icons.medication_outlined, 30, -0.18),
                  _positioned(width * 0.08, height * 0.54, Icons.vaccines_outlined, 32, 0.14),
                  _positioned(width * 0.84, height * 0.59, Icons.healing, 40, -0.1),
                  _positioned(width * 0.03, height * 0.76, Icons.emergency_outlined, 36, -0.14),
                  _positioned(width * 0.77, height * 0.82, Icons.local_hospital_outlined, 46, 0.16),
                  _positioned(width * 0.43, height * 0.91, Icons.medical_services_outlined, 28, -0.12),
                ],
              );
            },
          ),
        ),
        child,
      ],
    );
  }

  Widget _positioned(double left, double top, IconData icon, double size, double rotation) {
    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          icon,
          size: size,
          color: const Color(0xFF1B7F57).withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
