import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart';
import 'package:xcelerate/coach/race_screen/model/race_result.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import 'package:xcelerate/utils/enums.dart';

class TimingData {
  List<TimingRecord> records;
  DateTime? startTime;
  String endTime;

  TimingData({
    this.records = const [],
    this.startTime,
    required this.endTime,
  });

  void addRecord(dynamic record) {
    if (record is TimingRecord) {
      records.add(record);
    } else if (record is RunnerRecord) {
      // Convert RunnerRecord to TimingRecord
      records.add(TimingRecord(
        elapsedTime: '',
        isConfirmed: false,
        conflict: null,
        type: RecordType.runnerTime,
        runnerId: record.runnerId,
        raceId: record.raceId,
        name: record.name,
        school: record.school,
        grade: record.grade,
        bib: record.bib,
        error: record.error,
      ));
    }
  }

  // Helper method to merge runner data into a timing record
  void mergeRunnerData(TimingRecord timingRecord, RunnerRecord runnerRecord) {
    final index = records.indexWhere((record) => record.runnerId == runnerRecord.runnerId);
    if (index != -1) {
      records[index] = timingRecord.copyWith(
        runnerId: runnerRecord.runnerId,
        raceId: runnerRecord.raceId,
        name: runnerRecord.name,
        school: runnerRecord.school,
        grade: runnerRecord.grade,
        bib: runnerRecord.bib,
        error: runnerRecord.error,
      );
    }
  }

  void updateRecord(int runnerId, TimingRecord updatedRecord) {
    final index = records.indexWhere((record) => record.runnerId == runnerId);
    if (index != -1) {
      records[index] = updatedRecord;
    }
  }

  void removeRecord(int runnerId) {
    records.removeWhere((record) => record.runnerId == runnerId);
  }

  void clearRecords() {
    records.clear();
    startTime = null;
    endTime = '';
  }

  // Get all RunnerRecord info from the TimingRecords
  List<RunnerRecord> get runnerRecords => records.where((record) => 
    record.runnerId != null || record.bib != null
  ).map((record) => RunnerRecord(
    runnerId: record.runnerId,
    raceId: record.raceId ?? 0,
    name: record.name ?? '',
    school: record.school ?? '',
    grade: record.grade ?? 0,
    bib: record.bib ?? '',
    error: record.error,
  )).toList();



  // Get all RunnerRecord info from the TimingRecords
  List<RaceResult> get raceResults => records.where((record) => 
    record.type == RecordType.runnerTime && record.runnerId != null && record.place != null && record.elapsedTime != ''
  ).map((record) => RaceResult(
    runnerId: record.runnerId,
    raceId: record.raceId ?? 0,
    place: record.place,
    finishTime: record.elapsedTime,
  )).toList();

  int get numberOfConfirmedTimes => records.where((record) => record.isConfirmed).length;
  int get numberOfTimes => records.length;

  Map<String, dynamic> toJson() => {
    'records': records.map((r) => r.toMap()).toList(),
    'end_time': endTime,
  };

  factory TimingData.fromJson(Map<String, dynamic> json) {
    return TimingData(
      records: (json['records'] as List?)
          ?.map((r) => TimingRecord.fromMap(r as Map<String, dynamic>))
          .toList() ?? [],
      endTime: json['end_time'] != null ? json['end_time'] as String : '',
    );
  }
}
