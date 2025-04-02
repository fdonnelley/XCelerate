import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'widgets/load_results_widget.dart';
import 'controller/load_results_controller.dart';

/// A FlowStep implementation for the load results step in the post-race flow
class LoadResultsStep extends FlowStep {
  /// Controller for managing load results functionality
  final LoadResultsController controller;

  /// Creates a new instance of LoadResultsStep
  LoadResultsStep({
    required this.controller,
  }) : super(
        title: 'Load Results',
        description:
            'Load the results of the race from the assistant devices.',
        // Initialize with a placeholder
        content: SizedBox.shrink(),
      );

  @override
  Widget get content => LoadResultsWidget(controller: controller);

  @override
  bool Function()? get canProceed => () => 
    controller.resultsLoaded && 
    !controller.hasBibConflicts && 
    !controller.hasTimingConflicts;
}
