import 'package:flutter/material.dart';
import '../coach/races_screen/screen/races_screen.dart';
import '../assistant/race_timer/timing_screen/screen/timing_screen.dart';
import '../assistant/bib_number_recorder/bib_number_screen/screen/bib_number_screen.dart';
import '../core/theme/app_colors.dart';
import '../utils/sheet_utils.dart';
import '../core/services/tutorial_manager.dart';
import '../core/components/coach_mark.dart';
import 'role_screen.dart';
import 'settings_screen.dart';

class RoleOption {
  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Widget screen;

  const RoleOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    required this.screen,
  });
}

final List<RoleOption> roleOptions = [
  RoleOption(
    value: 'timer',
    title: 'Timer',
    description: 'Time a race',
    icon: Icons.timer,
    screen: const TimingScreen(),
  ),
  RoleOption(
    value: 'bib recorder',
    title: 'Bib Recorder',
    description: 'Record bib numbers',
    icon: Icons.numbers,
    screen: const BibNumberScreen(),
  ),
];

final List<RoleOption> profileOptions = [
  RoleOption(
    value: 'coach',
    title: 'Coach',
    description: 'Manage races',
    icon: Icons.person_outlined,
    screen: const RacesScreen(),
  ),
  RoleOption(
    value: 'assistant',
    title: 'Assistant',
    description: 'Assist the coach by gathering race results',
    icon: Icons.person,
    screen: const AssistantRoleScreen(showBackArrow: false),
  ),
];

Widget _buildRoleTitle(RoleOption role, String currentRole) {
  return Row(
    children: [
      Icon(role.icon, size: 56, color: role.value == currentRole
                  ? AppColors.selectedRoleTextColor
                  : AppColors.unselectedRoleTextColor),
      SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: role.value == currentRole
                  ? AppColors.selectedRoleTextColor
                  : AppColors.unselectedRoleTextColor,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 150, maxWidth: 190),
            child: Text(
              role.description,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: role.value == currentRole
                    ? AppColors.selectedRoleTextColor
                    : AppColors.unselectedRoleTextColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildRoleListTile(BuildContext context, RoleOption role, String currentRole) {
  return Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: RadioListTile<String>(
      value: role.value,
      groupValue: currentRole,
      onChanged: (value) {
        Navigator.pop(context);
        if (value == currentRole) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => role.screen,
          ),
        );
      },
      controlAffinity: ListTileControlAffinity.trailing,
      tileColor: currentRole == role.value
          ? AppColors.selectedRoleColor
          : AppColors.unselectedRoleColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: _buildRoleTitle(role, currentRole),
      activeColor: AppColors.selectedRoleTextColor,
    ),
  );
}

void changeRole(BuildContext context, String currentRole) {
  sheet(
    context: context,
    title: 'Change Role',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...roleOptions.map((role) => _buildRoleListTile(context, role, currentRole)),
        const SizedBox(height: 30),
      ],
    ),
  );
}

void changeProfile(BuildContext context, String currentProfile) {
  sheet(
    context: context,
    title: 'Change Profile',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...profileOptions.map((role) => _buildRoleListTile(context, role, currentProfile)),
        const SizedBox(height: 30),
      ],
    ),
  );
}

Widget buildRoleBar(BuildContext context, String currentRole, TutorialManager tutorialManager) {
  return Container(
    padding: EdgeInsets.only(bottom: 10, left: 5, right: 0),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          width: 1,
          color: AppColors.darkColor,
        ),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildTopUnusableSpaceSpacing(context),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Role button
            CoachMark(
              id: 'role_bar_tutorial',
              tutorialManager: tutorialManager,
              config: const CoachMarkConfig(
                title: 'Switch Roles',
                alignmentX: AlignmentX.left,
                alignmentY: AlignmentY.bottom,
                description: 'Click here to switch between Coach, Timer, and Bib Recorder roles',
                icon: Icons.touch_app,
                type: CoachMarkType.targeted,
                backgroundColor: Color(0xFF1976D2),
                elevation: 12,
              ),
              child: buildRoleButton(context, currentRole)
            ),
            const SizedBox(width: 8),
            // Settings button
            IconButton(
              icon: Icon(Icons.settings, color: AppColors.darkColor, size: 48),
              onPressed: () {
                final role = (currentRole == 'coach') ? 'coach' : 'assistant';
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingsScreen(currentRole: role)),
                );
              },
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget buildTopUnusableSpaceSpacing(BuildContext context) {
  return SizedBox(height: 50);
}

Widget buildRoleButton(BuildContext context, String currentRole) {
  final TutorialManager tutorialManager = TutorialManager();
  return CoachMark(
    id: 'role_bar_tutorial',
    tutorialManager: tutorialManager,
    config: const CoachMarkConfig(
      title: 'Switch Roles',
      alignmentX: AlignmentX.left,
      alignmentY: AlignmentY.bottom,
      description: 'Click here to switch between Coach and Assistant roles',
      icon: Icons.touch_app,
      type: CoachMarkType.targeted,
      backgroundColor: Color(0xFF1976D2),
      elevation: 12,
    ),
    child: GestureDetector(
      onTap: () {
        changeRole(context, currentRole);
      },
      child: Icon(Icons.person_outline, color: AppColors.darkColor, size: 48)
    ),
  );
  // return TextButton(
  //   onPressed: () => changeRole(context, currentRole),
  //   child: Row(
  //     children: [
  //       Text(
  //         '${currentRole[0].toUpperCase()}${currentRole.substring(1)}',
  //         style: TextStyle(fontSize: 20, color: AppColors.navBarTextColor),
  //       ),
  //       Icon(
  //         Icons.keyboard_arrow_down,
  //         size: 30,
  //         color: AppColors.navBarTextColor,
  //       ),
  //     ],
  //   ), 
  // );
}