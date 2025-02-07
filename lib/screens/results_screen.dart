import 'dart:math';
import 'package:collection/collection.dart';
import '../database_helper.dart';
import 'package:flutter/material.dart';
import '../utils/time_formatter.dart';
import '../utils/csv_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/sheet_utils.dart';
import 'share_sheet_screen.dart';

class ResultsScreen extends StatefulWidget {
  final int raceId;

  const ResultsScreen({super.key, required this.raceId});

  @override
  ResultsScreenState createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen> {
  bool _isHeadToHead = false;
  List<Map<String, dynamic>> runners = [];
  late int raceId;

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    _loadRunners();
  }

  Future<void> _loadRunners() async {
    // Fetch runners from the database
    runners = await DatabaseHelper.instance.getRaceResults(raceId);

    List<Map<String, dynamic>> modifiedRunners = runners.map((runner) {
      return {
        ...runner,
        'finishTimeAsDuration': loadDurationFromString(runner['finish_time']),
      };
    }).toList();

    setState(() {
      runners = modifiedRunners; // Update the state with the modified runners
    });
  }

  @override
  Widget build(BuildContext context) {
    final individualResults = _calculateIndividualResults();
    final teamResults = _isHeadToHead
        ? _calculateHeadToHeadTeamResults()
        : _calculateOverallTeamResults();

    return Scaffold(
      // appBar: AppBar(title: const Text('Team Results')),
      body: (runners.isEmpty)
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            SizedBox(height: 8),
            createSheetHandle(height: 10, width: 60),
            SizedBox(height: 16),
            SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Head-to-Head View'),
                          Switch(
                            value: _isHeadToHead,
                            onChanged: (value) {
                              setState(() {
                                _isHeadToHead = value;
                              });
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              double buttonWidth = min(constraints.maxWidth * 0.5, 200);
                              double fontSize = buttonWidth * 0.08;
                              return ElevatedButton.icon(
                                onPressed: () => downloadCsv(teamResults, individualResults),
                                icon: const Icon(Icons.download),
                                label: Text(
                                  'Download CSV Results',
                                  style: TextStyle(fontSize: fontSize),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(200, 60),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                  fixedSize: Size(buttonWidth, 60),
                                ),
                              );
                            },
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (BuildContext context) => ShareSheetScreen(
                                  teamResults: _isHeadToHead
                                    ? _calculateHeadToHeadTeamResults()
                                    : _calculateOverallTeamResults(),
                                  individualResults: _calculateIndividualResults(),
                                  // isHeadToHead: _isHeadToHead,
                                ),
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(100, 60),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // Overall or Head-to-Head Results
                  if (!_isHeadToHead) ...[
                    const Text(
                      'Overall Team Results',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teamResults.length,
                      itemBuilder: (context, index) {
                        final team = teamResults[index];
                        return _buildTeamResultCard(team);
                      },
                    ),
                  ] else ...[
                    const Text(
                      'Head-to-Head Results',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teamResults.length,
                      itemBuilder: (context, index) {
                        final matchup = teamResults[index];
                        return _buildHeadToHeadCard(matchup);
                      },
                    ),
                  ],
                  const Divider(),
                  // Individual Results Section
                  const Text(
                    'Individual Results',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: individualResults.length,
                    itemBuilder: (context, index) {
                      final runner = individualResults[index];
                      return ListTile(
                        title: Text(
                          '${index + 1}. ${runner['name'] ?? 'Unknown Name'} (${runner['school'] ?? 'Unknown School'})',
                        ),
                        subtitle: Text(
                          'Time: ${runner['finish_time'] ?? 'N/A'} | Grade: ${runner['grade'] ?? 'Unknown'} | Bib: ${runner['bib_number'] ?? 'N/A'}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ]
      ),
    );
  }

  // Card for Overall Results
  Widget _buildTeamResultCard(Map<String, dynamic> team) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (team['place'] != null)
                  Text(
                    '${team['place']}. ${team['school']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (team['place'] == null)
                  Text(
                    '${team['school']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  '${team['score']} Points',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scorers: ${team['scorers']}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (team['place'] != null)
              Text(
                'Times: ${team['times']}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // Card for Head-to-Head Results
  Widget _buildHeadToHeadCard(Map<String, dynamic> matchup) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Matchup Header
            Text(
              '${matchup['team1']?['school'] ?? 'Unknown'} vs ${matchup['team2']?['school'] ?? 'Unknown'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Team 1 Result
            _buildTeamComparison(
              rank: '1',
              team: matchup['team1'],
            ),

            const Divider(color: Colors.grey),

            // Team 2 Result
            _buildTeamComparison(
              rank: '2',
              team: matchup['team2'],
            ),
          ],
        ),
      ),
    );
  }

  // Shared Team Comparison Widget
  Widget _buildTeamComparison({required String rank, required Map<String, dynamic> team}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$rank. ${team['school']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${team['score']} Points',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Scorers: ${team['scorers']}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Times: ${team['times']}',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
  
  Future<void> downloadCsv(List<Map<String, dynamic>> teamResults, List<Map<String, dynamic>> individualResults) async {
    try {
      // Generate CSV content
      final csvContent = CsvUtils.generateCsvContent(
        isHeadToHead: _isHeadToHead,
        teamResults: teamResults,
        individualResults: individualResults
      );

      // Define the filename
      final filename = 'race_results.csv';

      // Save CSV file
      final filepath = await CsvUtils.saveCsvWithFileSaver(filename, csvContent);

      if (filepath != '') {
        DialogUtils.showSuccessDialog(context, message: 'CSV saved at $filepath');
      }
      else {
        DialogUtils.showErrorDialog(context, message: 'No location selected for download');
      }

    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'Failed to download CSV: $e');
    }
  }

  List<Map<String, dynamic>> _calculateIndividualResults() {
    final sortedRunners = List<Map<String, dynamic>>.from(runners);
    sortedRunners.sort((a, b) => a['finishTimeAsDuration'].compareTo(b['finishTimeAsDuration']));
    return sortedRunners;
  }

  List<Map<String, dynamic>> _calculateOverallTeamResults() {
    // Normal team scoring logic (all teams considered together)
    return _calculateTeamResults(runners);
  }

  List<Map<String, dynamic>> _calculateHeadToHeadTeamResults() {
    final schools = runners.map((r) => r['school']).toSet().toList();
    final headToHeadResults = <Map<String, dynamic>>[];

    for (int i = 0; i < schools.length; i++) {
      for (int j = i + 1; j < schools.length; j++) {
        final schoolA = schools[i];
        final schoolB = schools[j];
        final filteredRunners = runners
            .where((r) => r['school'] == schoolA || r['school'] == schoolB)
            .toList();

        final teamResults = _calculateTeamResults(filteredRunners);

        // Add the results for the two teams being compared as a group
        final matchup = {
          'team1': teamResults.firstWhere((team) => team['school'] == schoolA, orElse: () => {}),
          'team2': teamResults.firstWhere((team) => team['school'] == schoolB, orElse: () => {}),
        };

        headToHeadResults.add(matchup);
      }
    }

    return headToHeadResults;
  }

  // Get the names of the scoring teams (teams with 5 or more runners)
  // and non-scoring teams
  List<List<String>> _getTeamInfo(List<Map<String, dynamic>> allRunners) {
    final scoringTeams = <String>[];
    final nonScoringTeams = <String>[];

    final teams = groupBy(allRunners, (runner) => runner['school']);

    teams.forEach((school, runners) {
      if (runners.length >= 5) {
        scoringTeams.add(school);
      } else {
        nonScoringTeams.add(school);
      }
    });

    return [scoringTeams, nonScoringTeams];
  }

  // Get the runners corresponding to a given team
  List<Map<String, dynamic>> _getRunnersForTeam(List<Map<String, dynamic>> allRunners, String teamName) {
    return allRunners.where((runner) => runner['school'] == teamName).toList();
  }

  // Get the runners corresponding to a list of teams
  List<Map<String, dynamic>> _getRunnersForTeams(List<Map<String, dynamic>> allRunners, List<String> teams) {
    return allRunners.where((runner) => teams.contains(runner['school'])).toList();
  }

  List<Map<String, dynamic>> _calculateTeamResults(List<Map<String, dynamic>> allRunners) {
    final List<List<String>> teamInfo = _getTeamInfo(allRunners);

    final scoringTeams = teamInfo[0];
    final nonScoringTeams = teamInfo[1];

    final scoringRunners = _getRunnersForTeams(allRunners, scoringTeams);

    // Calculate scores for each team
    final teamScores = <Map<String, dynamic>>[];
    final nonScoringTeamScores = <Map<String, dynamic>>[];
    int place = 1;

    for (var school in scoringTeams) {
      final schoolRunners = _getRunnersForTeam(allRunners, school);

      // Sort runners by time
      schoolRunners.sort((a, b) => a['finishTimeAsDuration'].compareTo(b['finishTimeAsDuration']));

      // Calculate team score and other stats
      final top5 = schoolRunners.take(5).toList();
      final sixthRunner = schoolRunners.length > 5 ? scoringRunners.indexOf(schoolRunners[5]) + 1 : null;
      final seventhRunner = schoolRunners.length > 6 ? scoringRunners.indexOf(schoolRunners[6]) + 1 : null;
      final score = top5.fold<int>(0, (sum, runner) => sum + scoringRunners.indexOf(runner) + 1); // Calculate position based on time
      final scorers = '${top5.map((runner) => '${scoringRunners.indexOf(runner) + 1}').join('+')} ${sixthRunner != null ? '($sixthRunner' : ''}${seventhRunner != null ? '+$seventhRunner' : ''}${sixthRunner != null || seventhRunner != null ? ')' : ''}';

      final split = top5.last['finishTimeAsDuration'] - top5.first['finishTimeAsDuration'];
      final formattedSplit = formatDuration(split);
      final avgTime = top5.fold(Duration.zero, (sum, runner) => sum + runner['finishTimeAsDuration']) ~/ 5;
      String formattedAverage = formatDuration(avgTime);

      teamScores.add({
        'place': place++,
        'school': school,
        'score': score,
        'scorers': scorers,
        'split': formattedSplit,
        'averageTime': formattedAverage,
        'times': '$formattedSplit 1-5 Split | $formattedAverage Avg',
        'sixth_runner': sixthRunner,
        'seventh_runner': seventhRunner,
      });
    }

    for (var school in nonScoringTeams) {
      nonScoringTeamScores.add({
        'place': null,
        'school': school,
        'score': "N/A",
        'scorers': "N/A",
        'times': "N/A",
        'sixth_runner': null,
        'seventh_runner': null,
      });
    }

    // Sort teams by score (and apply tiebreakers if necessary)
    teamScores.sort((a, b) {
      if (a['score'] != b['score']) return a['score'].compareTo(b['score']);
      if (a['sixth_runner'] != b['sixth_runner']) return a['sixth_runner']!.compareTo(b['sixth_runner']!);
      if (a['seventh_runner'] != b['seventh_runner']) return a['seventh_runner']!.compareTo(b['seventh_runner']!);
      return 0;
    });

    nonScoringTeamScores.sort((a, b) => a['school'].compareTo(b['school']));


    return [...teamScores, ...nonScoringTeamScores];
  }

  // String _generateShareText() {
  //   final buffer = StringBuffer();
    
  //   // Add race info
  //   buffer.writeln('Race Results\n');

  //   // Add team results
  //   if (_isHeadToHead) {
  //     final teamResults = _calculateHeadToHeadTeamResults();
  //     buffer.writeln('Head-to-Head Results:');
  //     for (final matchup in teamResults) {
  //       buffer.writeln('\n${matchup['team1']?['school']} vs ${matchup['team2']?['school']}');
  //       buffer.writeln('1. ${matchup['team1']?['school']}: ${matchup['team1']?['score']} points');
  //       buffer.writeln('2. ${matchup['team2']?['school']}: ${matchup['team2']?['score']} points');
  //     }
  //   } else {
  //     final teamResults = _calculateOverallTeamResults();
  //     buffer.writeln('Team Results:');
  //     for (final team in teamResults) {
  //       if (team['place'] != null) {
  //         buffer.writeln('${team['place']}. ${team['school']}: ${team['score']} points');
  //       }
  //     }
  //   }

  //   // Add individual results
  //   buffer.writeln('\nIndividual Results:');
  //   final individualResults = _calculateIndividualResults();
  //   for (int i = 0; i < individualResults.length; i++) {
  //     final runner = individualResults[i];
  //     buffer.writeln('${i + 1}. ${runner['name']} (${runner['school']}) - ${runner['finish_time']}');
  //   }

  //   return buffer.toString();
  // }
}
