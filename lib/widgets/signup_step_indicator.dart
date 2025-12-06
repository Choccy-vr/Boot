import 'package:flutter/material.dart';

/// A step indicator widget for the signup flow.
/// Shows progress through steps with visual indication of current and completed steps.
class SignupStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const SignupStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          for (int i = 1; i <= totalSteps; i++) ...[
            if (i > 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            _buildStepCircle(i, colorScheme, textTheme),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, ColorScheme colorScheme, TextTheme textTheme) {
    final bool isCompleted = step < currentStep;
    final bool isCurrent = step == currentStep;
    final bool isActive = step <= currentStep;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: isCompleted
            ? Icon(
                Icons.check,
                size: 16,
                color: colorScheme.onPrimary,
              )
            : Text(
                '$step',
                style: textTheme.labelMedium?.copyWith(
                  color: isActive
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
