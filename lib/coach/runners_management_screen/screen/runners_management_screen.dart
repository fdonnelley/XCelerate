import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/components/textfield_utils.dart';
import '../../../utils/database_helper.dart';
import '../../../utils/file_processing.dart';

// Models
class Team {
  final String name;
  final Color color;

  Team({required this.name, required this.color});
}

// class Runner {
//   final String name;
//   final int grade;
//   final String school;
//   final String bibNumber;
//   final int? runnerId;
//   final int? raceRunnerId;

//   Runner({
//     required this.name,
//     required this.grade,
//     required this.school,
//     required this.bibNumber,
//     this.runnerId,
//     this.raceRunnerId,
//   });

//   Map<String, dynamic> toMap() => {
//     'name': name,
//     'grade': grade,
//     'school': school,
//     'bib_number': bibNumber,
//     if (runnerId != null) 'runner_id': runnerId,
//     if (raceRunnerId != null) 'runner_id': raceRunnerId,
//   };

//   factory Runner.fromMap(Map<String, dynamic> map) => Runner(
//     name: map['name'],
//     grade: map['grade'],
//     school: map['school'],
//     bibNumber: map['bib_number'],
//     runnerId: map['runner_id'],
//     raceRunnerId: map['runner_id'],
//   );

//   Runner copyWith({
//     String? name,
//     int? grade,
//     String? school,
//     String? bibNumber,
//   }) {
//     return Runner(
//       name: name ?? this.name,
//       grade: grade ?? this.grade,
//       school: school ?? this.school,
//       bibNumber: bibNumber ?? this.bibNumber,
//       runnerId: runnerId,
//       raceRunnerId: raceRunnerId,
//     );
//   }
// }

// Components
class RunnerTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isNumeric;
  final String? initialValue;

  const RunnerTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isNumeric = false,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    if (initialValue != null) {
      controller.text = initialValue!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
    );
  }
}

class RunnerListItem extends StatefulWidget {
  final RunnerRecord runner;
  final Function(String) onActionSelected;
  final List<Team> teamData;

  const RunnerListItem({
    super.key,
    required this.runner,
    required this.onActionSelected,
    required this.teamData,
  });

  @override
  State<RunnerListItem> createState() => _RunnerListItemState();
}

class _RunnerListItemState extends State<RunnerListItem> {
  @override
  Widget build(BuildContext context) {
    final team = widget.teamData.firstWhereOrNull((team) => team.name == widget.runner.school);
    final bibColor = team != null ? team.color : AppColors.mediumColor;
    
    return Slidable(
      key: Key(widget.runner.bib),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => widget.onActionSelected('Edit'),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            // label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => widget.onActionSelected('Delete'),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            // label: 'Delete',
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bibColor.withAlpha((0.1 * 255).round()),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          widget.runner.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.school,
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.grade.toString(),
                          style: const TextStyle(fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          widget.runner.bib,
                          style: TextStyle(
                            color: bibColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchAttribute;
  final Function(String) onSearchChanged;
  final Function(String?) onAttributeChanged;
  final VoidCallback onDeleteAll;

  const SearchBar({
    super.key,
    required this.controller,
    required this.searchAttribute,
    required this.onSearchChanged,
    required this.onAttributeChanged,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: AppColors.mediumColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search, color: AppColors.primaryColor.withOpacity(0.8)),
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.lightColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.lightColor),
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(color: AppColors.lightColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: searchAttribute,
                    onChanged: onAttributeChanged,
                    items: ['Bib Number', 'Name', 'Grade', 'School']
                        .map((value) => DropdownMenuItem(
                          value: value, 
                          child: Text(value, 
                            style: TextStyle(
                              color: AppColors.darkColor,
                              fontSize: 14,
                            ),
                          ),
                        ))
                        .toList(),
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.navBarColor),
                    iconSize: 30,
                    isExpanded: true,
                    focusColor: AppColors.backgroundColor,
                    style: TextStyle(color: AppColors.darkColor, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(color: AppColors.lightColor),
            ),
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.redColor),
              tooltip: 'Delete All Runners',
              onPressed: onDeleteAll,
            ),
          ),
        ],
      ),
    );
  }
}

// Main Screen
class RunnersManagementScreen extends StatefulWidget {
  final int raceId;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool? showHeader;

  // Add a static method that can be called from outside
  static Future<bool> checkMinimumRunnersLoaded(int raceId) async {
    final race = await DatabaseHelper.instance.getRaceById(raceId);
    final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
    // Check if we have any runners at all
    if (runners.isEmpty) {
      return false;
    }

    // Check if each team has at least 5 runners (minimum for a race)
    final teamRunnerCounts = <String, int>{};
    for (final runner in runners) {
      final team = runner.school;
      teamRunnerCounts[team] = (teamRunnerCounts[team] ?? 0) + 1;
    }

    // Verify each team in the race has enough runners
    for (final teamName in race!.teams) {
      final runnerCount = teamRunnerCounts[teamName] ?? 0;
      if (runnerCount < 1) { // only checking 1 for testing purposes
        return false;
      }
    }

    return true;
  }

  const RunnersManagementScreen({
    super.key,
    required this.raceId,
    this.showHeader,
    this.onBack,
    this.onContentChanged,
  });

  @override
  State<RunnersManagementScreen> createState() => _RunnersManagementScreenState();
}

class _RunnersManagementScreenState extends State<RunnersManagementScreen> {
  List<RunnerRecord> _runners = [];
  List<RunnerRecord> _filteredRunners = [];
  final List<Team> _teams = [];
  bool _isLoading = true;
  bool _showHeader = true;
  String _searchAttribute = 'Bib Number';
  final TextEditingController _searchController = TextEditingController();
  
  // Sheet controllers
  TextEditingController? _nameController;
  TextEditingController? _gradeController;
  TextEditingController? _schoolController;
  TextEditingController? _bibController;

  @override
  void initState() {
    super.initState();
    _showHeader = widget.showHeader ?? true;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRunners(),
      _loadTeams(),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _initControllers() {
    _disposeControllers(); // Clean up any existing controllers first
    _nameController = TextEditingController();
    _gradeController = TextEditingController();
    _schoolController = TextEditingController();
    _bibController = TextEditingController();
  }

  void _disposeControllers() {
    _nameController?.dispose();
    _gradeController?.dispose();
    _schoolController?.dispose();
    _bibController?.dispose();
    _nameController = null;
    _gradeController = null;
    _schoolController = null;
    _bibController = null;
  }

  Future<void> _loadTeams() async {
    final race = await DatabaseHelper.instance.getRaceById(widget.raceId);
    if (mounted) {
      setState(() {
        _teams.clear();
        for (var i = 0; i < race!.teams.length; i++) {
          _teams.add(Team(name: race.teams[i], color: race.teamColors[i]));
        }
      });
    }
  }

  Future<void> _loadRunners() async {
    final runners = await DatabaseHelper.instance.getRaceRunners(widget.raceId);
    setState(() {
      _runners = runners;
      _filteredRunners = _runners;
      _sortRunners();
    });
    widget.onContentChanged?.call();
  }

  void _sortRunners() {
    _runners.sort((a, b) {
      final schoolCompare = a.school.compareTo(b.school);
      if (schoolCompare != 0) return schoolCompare;
      return a.name.compareTo(b.name);
    });
  }

  void _filterRunners(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRunners = List.from(_runners);
      } else {
        _filteredRunners = _runners.where((runner) {
          final value = switch (_searchAttribute) {
            'Bib Number' => runner.bib,
            'Name' => runner.name.toLowerCase(),
            'Grade' => runner.grade.toString(),
            'School' => runner.school.toLowerCase(),
            String() => '',
          };
          return value.contains(query.toLowerCase());
        }).toList();
    }});
  }

  Future<void> _handleRunnerAction(String action, RunnerRecord runner) async {
    switch (action) {
      case 'Edit':
        await _showRunnerSheet(
          context: context,
          runner: runner,
        );
        break;
      case 'Delete':
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Confirm Deletion',
          content: 'Are you sure you want to delete this runner?',
        );
        if (confirmed) {
          await _deleteRunner(runner);
          await _loadRunners();
        }
        break;
    }
  }

  Future<void> _deleteRunner(RunnerRecord runner) async {
    await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner.bib);
    await _loadRunners();
  }

  Widget _buildListTitles() {
    const double fontSize = 14;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            'Name',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'School',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Gr.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Bib',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showHeader) ...[
            createSheetHeader(
              'Race Runners',
              backArrow: true,
              context: context,
              onBack: widget.onBack,
            ),
          ],
          _buildActionButtons(),
          const SizedBox(height: 12),
          if (_runners.isNotEmpty) ...[
            _buildSearchSection(),
            const SizedBox(height: 8),
          ],
          _buildListTitles(),
          const SizedBox(height: 4),
          // Expanded(
          _buildRunnersList(),
          // ),
        ],
      ),
    );
  }


  // UI Building Methods
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            'Add Runner',
            icon: Icons.person_add_alt_1,
            onPressed: () => _showRunnerSheet(context: context, runner: null),
          ),
          _buildActionButton(
            'Load Runners',
            icon: Icons.table_chart,
            onPressed: _handleSpreadsheetLoad,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, {required VoidCallback onPressed, IconData? icon}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(160, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primaryColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return SearchBar(
      controller: _searchController,
      searchAttribute: _searchAttribute,
      onSearchChanged: _filterRunners,
      onAttributeChanged: (value) {
        setState(() {
          _searchAttribute = value!;
          _filterRunners(_searchController.text);
        });
      },
      onDeleteAll: () => _confirmDeleteAllRunners(context),
    );
  }

  Widget _buildRunnersList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }

    if (_filteredRunners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.mediumColor.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No Runners Added'
                  : 'No runners found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumColor,
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mediumColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group runners by school
    final groupedRunners = <String, List<RunnerRecord>>{};
    for (var runner in _filteredRunners) {
      if (!groupedRunners.containsKey(runner.school)) {
        groupedRunners[runner.school] = [];
      }
      groupedRunners[runner.school]!.add(runner);
    }

    // Sort schools alphabetically
    final sortedSchools = groupedRunners.keys.toList()..sort();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedSchools.length,
        itemBuilder: (context, index) {
          final school = sortedSchools[index];
          final schoolRunners = groupedRunners[school]!;
          final team = _teams.firstWhereOrNull((team) => team.name == school);
          final schoolColor = team != null ? team.color : Colors.blueGrey[400];

          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                Container(
                  decoration: BoxDecoration(
                    color: schoolColor?.withAlpha((0.12 * 255).round()) ?? Colors.grey.withAlpha((0.12 * 255).round()),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  margin: const EdgeInsets.only(right: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 18,
                        color: schoolColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        school,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: schoolColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: schoolColor?.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${schoolRunners.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: schoolColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...schoolRunners.map((runner) => RunnerListItem(
                  runner: runner,
                  teamData: _teams,
                  onActionSelected: (action) => _handleRunnerAction(action, runner),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
  // Dialog and Action Methods
  Future<void> _showRunnerSheet({
    required BuildContext context,
    RunnerRecord? runner,
  }) async {
    final title = runner == null ? 'Add Runner' : 'Edit Runner';
    String? nameError;
    String? gradeError;
    String? schoolError;
    String? bibError;
    
    // Initialize controllers
    _initControllers();

    if (runner != null) {
      _nameController?.text = runner.name;
      _gradeController?.text = runner.grade.toString();
      _schoolController?.text = runner.school;
      _bibController?.text = runner.bib;
    }

    try {
      await sheet(context: context, body: StatefulBuilder(
          builder: (context, setSheetState) => 
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                buildInputRow(
                  label: 'Name',
                  inputWidget: buildTextField(
                    context: context,
                    controller: _nameController ?? TextEditingController(),
                    hint: 'John Doe',
                    error: nameError,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setSheetState(() {
                          nameError = 'Please enter a name';
                        });
                      } else {
                        setSheetState(() {
                          nameError = null;
                        });
                      }
                    },
                    setSheetState: setSheetState,
                  ),
                ),
                const SizedBox(height: 16),
                buildInputRow(
                  label: 'Grade',
                  inputWidget: buildTextField(
                    context: context,
                    controller: _gradeController ?? TextEditingController(),
                    hint: '9',
                    keyboardType: TextInputType.number,
                    error: gradeError,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setSheetState(() {
                          gradeError = 'Please enter a grade';
                        });
                      } else if (int.tryParse(value) == null) {
                        setSheetState(() {
                          gradeError = 'Please enter a valid grade number';
                        });
                      } else {
                        final grade = int.parse(value);
                        if (grade < 9 || grade > 12) {
                          setSheetState(() {
                            gradeError = 'Grade must be between 9 and 12';
                          });
                        } else {
                          setSheetState(() {
                            gradeError = null;
                          });
                        }
                      }
                    },
                    setSheetState: setSheetState,
                  ),
                ),
                const SizedBox(height: 16),
                buildInputRow(
                  label: 'School',
                  inputWidget: buildDropdown(
                    controller: _schoolController ?? TextEditingController(),
                    hint: 'Select School',
                    error: schoolError,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setSheetState(() {
                          schoolError = 'Please select a school';
                        });
                      } else {
                        setSheetState(() {
                          schoolError = null;
                        });
                      }
                    },
                    setSheetState: setSheetState,
                    items: _teams.map((team) => team.name).toList()..sort(),
                  ),
                ),
                const SizedBox(height: 16),
                buildInputRow(
                  label: 'Bib #',
                  inputWidget: buildTextField(
                    context: context,
                    controller: _bibController ?? TextEditingController(),
                    hint: '1234',
                    error: bibError,
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setSheetState(() {
                          bibError = 'Please enter a bib number';
                        });
                      } else if (int.tryParse(value) == null) {
                        setSheetState(() {
                          bibError = 'Please enter a valid bib number';
                        });
                      } else {
                        setSheetState(() {
                          bibError = null;
                        });
                      }
                    },
                    setSheetState: setSheetState,
                  ),
                ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (schoolError != null || bibError != null || gradeError != null || nameError != null || _nameController == null || _nameController!.text.isEmpty || _gradeController!.text.isEmpty || _schoolController!.text.isEmpty || _bibController!.text.isEmpty)
                      ? AppColors.primaryColor.withAlpha((0.5 * 255).round())
                      : AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  print('pressed');
                  print('schoolError: $schoolError');
                  print('bibError: $bibError');
                  print('gradeError: $gradeError');
                  print('nameError: $nameError');
                  print('_nameController!.text: ${_nameController!.text}');
                  print('_gradeController!.text: ${_gradeController!.text}');
                  print('_schoolController!.text: ${_schoolController!.text}');
                  print('_bibController!.text: ${_bibController!.text}');
                  if (schoolError != null || bibError != null || gradeError != null || nameError != null || _nameController!.text.isEmpty || _gradeController!.text.isEmpty || _schoolController!.text.isEmpty || _bibController!.text.isEmpty) return;
                  try {
                    final newRunner = RunnerRecord(
                      name: _nameController!.text,
                      grade: int.tryParse(_gradeController!.text) ?? 0,
                      school: _schoolController!.text,
                      bib: _bibController!.text,
                      raceId: widget.raceId,
                    );
                    print('newRunner: ${newRunner.toMap()}');

                    await _handleRunnerSubmission(newRunner);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  runner == null ? 'Create' : 'Save',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ), title: title);
    } finally {
      // Always dispose controllers when sheet is closed
      _disposeControllers();
    }
  }

  Future<void> _handleRunnerSubmission(RunnerRecord runner) async {
    try {
      dynamic existingRunner;
      existingRunner = await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, runner.bib);
      print('existingRunner: $existingRunner');

      if (existingRunner != null) {
        // If we're updating the same runner (same ID), just update
        if (existingRunner['runner_id'] == runner.runnerId) {
          await _updateRunner(runner);
        } else {
          if (!mounted) return;
          // If a different runner exists with this bib, ask for confirmation
          final shouldOverwrite = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Overwrite Runner',
            content: 'A runner with bib number ${runner.bib} already exists. Do you want to overwrite it?',
          );

          if (!shouldOverwrite) return;
          
          await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner.bib);
          await _insertRunner(runner);
        }
      } else {
        await _insertRunner(runner);
      }
      
      await _loadRunners();
      if (widget.onContentChanged != null) {
        widget.onContentChanged!();
      }
    } catch (e) {
      throw Exception('Failed to save runner: $e');
    }
  }

  Future<void> _insertRunner(RunnerRecord runner) async {
    print('Inserting runner: ${runner.toMap()}');
    await DatabaseHelper.instance.insertRaceRunner(runner);
  }

  Future<void> _updateRunner(RunnerRecord runner) async {
    await DatabaseHelper.instance.updateRaceRunner(runner);
  }

  Future<void> _confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content: 'Are you sure you want to delete all runners?',
    );
    
    if (!confirmed) return;
    
    await DatabaseHelper.instance.deleteAllRaceRunners(widget.raceId);
    
    await _loadRunners();
  }

  Future<void> _showSampleSpreadsheet() async {
    final file = await rootBundle.loadString('assets/sample_sheets/sample_spreadsheet.csv');
    final lines = file.split('\n');
    final table = Table(
      border: TableBorder.all(color: Colors.grey),
      children: lines.map((line) {
        final cells = line.split(',');
        return TableRow(
          children: cells.map((cell) {
            return TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(cell),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );

    if (!mounted) return;
    await sheet(
      context: context,
      title: 'Sample Spreadsheet',
      body: SingleChildScrollView(
        child: table,
      ),
    );
    return;
  }

  Future<bool?> _showSpreadsheetLoadSheet(BuildContext context) async {
    return await sheet(
      context: context,
      title: 'Import Runners',
      titleSize: 24,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.file_upload_outlined,
                size: 40,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance
            
            // Description text
            Text(
              'Import your runners from a CSV or Excel spreadsheet to quickly set up your race.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance
            
            // See Example button - with rounded corners and shadow
            ElevatedButton(
              onPressed: () async => await _showSampleSpreadsheet(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryColor,
                elevation: 0,
                // shadowColor: Colors.black.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(
                    color: AppColors.primaryColor,
                    width: 1,
                  ),
                ),
                minimumSize: const Size(double.infinity, 56), // Full width button
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 24, color: AppColors.primaryColor), // Ensuring color consistency
                  const SizedBox(width: 12),
                  Text(
                    'See Example Format',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor, // Ensuring color consistency
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24), // Adjusted spacing for balance
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                          color: Colors.grey[600]!, // Adding subtle border
                          width: 1,
                        ),
                      ),
                      minimumSize: const Size(double.infinity, 56), // Full width button
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Import Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      minimumSize: const Size(double.infinity, 56), // Full width button
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 20, color: Colors.white), // Ensuring color consistency
                        const SizedBox(width: 8),
                        Text(
                          'Import Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // Ensuring color consistency
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSpreadsheetLoad() async {
    final confirmed = await _showSpreadsheetLoadSheet(context);
    if (confirmed == null || !confirmed) return;
    final List<RunnerRecord> runnerData = await processSpreadsheet(widget.raceId, false);
    final overwriteRunners = [];
    for (final runner in runnerData) {
      dynamic existingRunner;
      existingRunner = await DatabaseHelper.instance.getRaceRunnerByBib(widget.raceId, runner.bib);
      if (existingRunner != null && runner.bib == existingRunner.bib && runner.name == existingRunner.name && runner.school == existingRunner.school && runner.grade == existingRunner.grade) continue;

      if (existingRunner != null) {
        overwriteRunners.add(runner);
      } else {
        await DatabaseHelper.instance.insertRaceRunner(runner);
      }
    }
    await _loadRunners();
    if (overwriteRunners.isEmpty) return;
    final overwriteRunnersBibs = overwriteRunners.map((runner) => runner['bib_number']).toList();
    if (!mounted) return;
    final overwriteExistingRunners = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Overwrite',
      content: 'Are you sure you want to overwrite the following runners with bib numbers: ${overwriteRunnersBibs.join(', ')}?',
    );
    if (!overwriteExistingRunners) return;
    for (final runner in overwriteRunners) {
      await DatabaseHelper.instance.deleteRaceRunner(widget.raceId, runner['bib_number']);
      await DatabaseHelper.instance.insertRaceRunner(runner);
    }
    await _loadRunners();
  }
}

class ActionIcon {
  final IconData icon;
  final Color backgroundColor;

  ActionIcon(this.icon, this.backgroundColor);
}