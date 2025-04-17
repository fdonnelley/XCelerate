import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/dialog_utils.dart';
import 'package:xcelerate/core/theme/typography.dart';
import '../../../shared/role_bar/models/role_enums.dart';

/// Banner widget that displays a tappable instructions prompt.
/// Tapping the banner shows a modal sheet with instructions.
class InstructionsBanner extends StatelessWidget {
  final Role currentRole;
  const InstructionsBanner({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () => showInstructionsSheet(context, currentRole),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // decoration: BoxDecoration(
        //   color: Colors.grey[100],
        //   borderRadius: BorderRadius.circular(8.0),
        //   border: Border.all(color: Colors.grey[300]!),
        // ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Instructions',
                style: AppTypography.bodyRegular,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a modal bottom sheet with placeholder instructions using the shared sheet function and app typography.
  static Future<void> showInstructionsSheet(BuildContext context, Role role) async {
    await DialogUtils.showMessageDialog(
      context,
      title: 'Instructions',
      message: _getInstructions(role),
    );
  }

  /// Returns the instructions for the given role.
  static String _getInstructions(Role role) {
    switch (role) {
      case Role.bibRecorder:
        return 'You record the runners bib numbers during the race. Before the race begins, you will need the coach to share the race runners with you.';
      case Role.timer:
        return 'You time the race. When there is a break in the runners, check with the Bib Recorder to check that your records are the same number. Adjust if needed.';
      case Role.coach:
        return 'You create and manage the races. You will oversee your assistants and will compile and share the race results.';
    }
  }
}
