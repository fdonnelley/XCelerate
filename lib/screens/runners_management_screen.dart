import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:race_timing_app/file_processing.dart';
import 'package:race_timing_app/database_helper.dart';
// import 'package:race_timing_app/models/race.dart';
import '../constants.dart';
import '../utils/dialog_utils.dart';

class RunnersManagementScreen extends StatefulWidget {
  final int raceId;
  final bool isTeam;

  const RunnersManagementScreen({
    super.key, 
    required this.raceId,
    required this.isTeam,
  });

  @override
  State<RunnersManagementScreen> createState() => _RunnersManagementScreenState();
}

class _RunnersManagementScreenState extends State<RunnersManagementScreen> {
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _schoolController = TextEditingController();
  final _bibController = TextEditingController();
  String _searchAttribute = 'Bib Number'; // Initialize with a default value
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _runners = []; // To store runners fetched from the database.
  List<Map<String, dynamic>> _filteredRunners = []; // To store filtered runners.

  late int raceId;
  late bool isTeam;

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    isTeam = widget.isTeam;
    _loadRunners(); // Load runners when the widget is initialized.
  }

  Future<void> _loadRunners() async {
    // Fetch runners from the database
    if (isTeam == true) {
      final teamRunners = await DatabaseHelper.instance.getAllTeamRunners();
      setState(() {
        _runners = teamRunners; // Update the state with the fetched runners, including team runners
        _filteredRunners = _runners; // Initialize _filteredRunners with the fetched runners
      });
    }
    else{
      final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
      setState(() {
        _runners = runners; // Update the state with the fetched runners
        _filteredRunners = _runners; // Initialize _filteredRunners with the fetched runners
      });
    }
  }

  Future<void> _addRunner() async {
    final name = _nameController.text;
    final grade = int.tryParse(_gradeController.text);
    final school = _schoolController.text;
    final bib = _bibController.text;

    if (name.isEmpty || grade == null || school.isEmpty || bib.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (isTeam == true) {
      await DatabaseHelper.instance.insertTeamRunner({
        'name': name,
        'school': school,
        'grade': grade,
        'bib_number': bib,
      });
    }
    else{
      await DatabaseHelper.instance.insertRaceRunner({
        'name': name,
        'school': school,
        'grade': grade,
        'bib_number': bib,
        'race_id': raceId,
      });
    }
    _nameController.clear();
    _gradeController.clear();
    _schoolController.clear();
    _bibController.clear();
    _loadRunners();
    Navigator.of(context).pop(); // Close the popup
  }

  Future<void> _showAddRunnerPopup(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Runner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameController, 'Full Name'),
              _buildTextField(_gradeController, 'Grade', isNumeric: true),
              _buildTextField(_schoolController, 'School'),
              _buildTextField(_bibController, 'Bib Number', isNumeric: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addRunner,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditRunnerPopup(BuildContext context, Map<String, dynamic> runnerData) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
      title: const Text('Edit Runner'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(_nameController, 'Full Name', initialValue: runnerData['name'], isNumeric: false),
            _buildTextField(_gradeController, 'Grade', initialValue: runnerData['grade'].toString(), isNumeric: true),
            _buildTextField(_schoolController, 'School', initialValue: runnerData['school'], isNumeric: false),
            _buildTextField(_bibController, 'Bib Number', initialValue: runnerData['bib_number'], isNumeric: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (isTeam == true) {
              await DatabaseHelper.instance.updateTeamRunner({
                'name': _nameController.text,
                'school': _schoolController.text,
                'grade': int.parse(_gradeController.text),
                'bib_number': _bibController.text,
                'runner_id': runnerData['runner_id'],
              });
            }
            else {
              await DatabaseHelper.instance.updateRaceRunner({
                'name': _nameController.text,
                'school': _schoolController.text,
                'grade': int.parse(_gradeController.text),
                'bib_number': _bibController.text,
                'race_runner_id': runnerData['race_runner_id'],
              });
            }
            _nameController.clear();
            _gradeController.clear();
            _schoolController.clear();
            _bibController.clear();
            _loadRunners();
            Navigator.of(context).pop(); // Close the popup
          },
          child: const Text('Edit'),
        ),
      ],
      ),
    );
  }

  Future<void> _loadSpreadsheet() async {
    await processSpreadsheet(raceId, isTeam);
    _loadRunners(); // Reload runners after processing spreadsheet
  }

  Future<void> _confirmDeleteAllRunners(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete all runners?');
    if (!confirmed) return;
    if (isTeam == true) {
      await DatabaseHelper.instance.clearTeamRunners();
    }
    else {
      await DatabaseHelper.instance.deleteAllRaceRunners(raceId);
    }
    _loadRunners();
  }

  void _filterRunners(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRunners = _runners;
      });
      return;
    }
    setState(() {
      _filteredRunners = _runners.where((runner) {
        if (_searchAttribute == 'Bib Number') {
          return runner['bib_number'].contains(query);
        } else if (_searchAttribute == 'Name') {
          return runner['name'].toLowerCase().contains(query.toLowerCase());
        } else if (_searchAttribute == 'Grade') {
          return runner['grade'].toString().contains(query);
        } else if (_searchAttribute == 'School') {
          return runner['school'].toLowerCase().contains(query.toLowerCase());
        } else {
          return runner['name'].toLowerCase().contains(query.toLowerCase()) ||
                 runner['bib_number'].contains(query);
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Runners Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5.0), // Padding around the button
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.12; // Scalable font size
                        return ElevatedButton(
                          onPressed: () => _showAddRunnerPopup(context),
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(0, constraints.maxWidth * 0.3), // Button height scales
                            padding: EdgeInsets.symmetric(vertical: 5.0),
                            backgroundColor: AppColors.primaryColor,
                          ),
                          child: Text('Add Runner',
                            style: TextStyle(fontSize: fontSize, color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.5), // Padding around the button
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.10;
                        return ElevatedButton(
                          onPressed: _loadSpreadsheet,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(0, constraints.maxWidth * 0.3),
                            padding: EdgeInsets.symmetric(horizontal: 5.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            backgroundColor: AppColors.primaryColor,
                          ),
                          child: Text(
                            'Load Spreadsheet',
                            style: TextStyle(fontSize: fontSize, color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_runners.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Color(0xFF606060)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.primaryColor), 
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.navBarColor),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _filterRunners(value);
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _searchAttribute,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _searchAttribute = newValue!;
                                  _filterRunners(_searchController.text);
                                });
                              },
                              items: <String>['Bib Number', 'Name', 'Grade', 'School']
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete),
                            tooltip: 'Delete All Runners',
                            onPressed: () {
                              _confirmDeleteAllRunners(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (_filteredRunners.isEmpty) 
              Center(
                child: Text(
                  (_searchController.text.isEmpty) ? ((isTeam) ? 'No Runners' : 'No Runners for this race') : 'No Runners found',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredRunners.length,
                itemBuilder: (context, index) {
                  final runner = _filteredRunners[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey[300],
                        child: Text(runner['bib_number']),
                      ),
                      title: Text(runner['name']),
                      subtitle: Text(
                        'School: ${runner['school']} | Grade: ${runner['grade'].toString()}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'Edit') {
                            await _showEditRunnerPopup(context, runner);
                          }
                          else if (value == 'Delete') {
                            final confirmed = await DialogUtils.showConfirmationDialog(context, title: 'Confirm Deletion', content: 'Are you sure you want to delete this runner?');
                            if (!confirmed) return;
                            if (isTeam == true) {
                              await DatabaseHelper.instance.deleteTeamRunner(runner['bib_number']);
                            }
                            else {
                              await DatabaseHelper.instance.deleteRaceRunner(raceId, runner['bib_number']);
                            }
                            _loadRunners();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'Edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'Delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hintText,
      {bool isNumeric = false, String title = '', String? initialValue}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: controller..text = initialValue ?? '',
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Colors.blue, width: 2.0),
              ),
            ),
          ),
        ),
      ]
    );
  }
}