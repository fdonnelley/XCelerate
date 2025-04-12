import 'package:flutter/material.dart';
import '../../../utils/time_formatter.dart';
import '../model/timing_data.dart';
import '../controller/timing_controller.dart';

class TimerDisplayWidget extends StatelessWidget {
  final TimingController controller;
  const TimerDisplayWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(milliseconds: 10)),
      builder: (context, _) {
        final elapsed = _calculateElapsedTime(controller.startTime, controller.endTime, controller);
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            TimeFormatter.formatDurationWithZeros(elapsed),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        );
      },
    );
  }

  Duration _calculateElapsedTime(DateTime? startTime, Duration? endTime, TimingData timingData) {
    if (timingData.raceStopped || startTime == null) {
      return endTime ?? Duration.zero;
    }
    return DateTime.now().difference(startTime);
  }
}
