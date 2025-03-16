import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart' show RunnerRecord;
import 'dart:io';
import '../model/bib_number_model.dart';
import '../model/bib_records_provider.dart';
import '../controller/bib_number_controller.dart';
import '../widget/bib_input_widget.dart';
import '../widget/add_button_widget.dart';
import '../widget/bottom_action_buttons_widget.dart';
import '../widget/keyboard_accessory_bar.dart';
import '../../../../core/components/dialog_utils.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/services/tutorial_manager.dart';
import '../../../../core/theme/typography.dart';
import '../../../../utils/enums.dart';
import '../../../../utils/sheet_utils.dart';
import '../../../../shared/role_functions.dart';
import '../../../../utils/encode_utils.dart';


class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  final List<RunnerRecord> _runners = [];
  DevicesManager devices = DeviceConnectionService.createDevices(
    DeviceName.bibRecorder,
    DeviceType.browserDevice,
  );

  final ScrollController _scrollController = ScrollController();
  final tutorialManager = TutorialManager();

  // Store provider reference for safe disposal
  late BibRecordsProvider _providerReference;
  late BibNumberModel _model;
  late BibNumberController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerReference = Provider.of<BibRecordsProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _model = BibNumberModel(
      initialRunners: _runners, 
      initialDevices: devices
    );
    
    _controller = BibNumberController(
      context: context,
      runners: _runners,
      scrollController: _scrollController,
      devices: devices,
    );
    
    _checkForRunners();
  }

  void _setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
      'add_button_tutorial'
    ]);
  }

  Future<void> _checkForRunners() async {
    if (_runners.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Runners Loaded'),
              content: const Text('There are no runners loaded in the system. Please load runners to continue.'),
              actions: [
                TextButton(
                  child: const Text('Return to Home'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                TextButton(
                  child: const Text('Load Runners'),
                  onPressed: () async {
                    sheet(
                      context: context,
                      title: 'Load Runners',
                      body: deviceConnectionWidget(
                        context,
                        _controller.devices,
                        callback: () {
                          Navigator.pop(context);
                          print('popped sheet');
                          loadRunners();
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  Future<void> loadRunners() async {
    final data = devices.coach?.data;
    
    if (data != null) {
      try {
        // Process data outside of setState
        final runners = await decodeEncodedRunners(data, context);
        
        if (runners == null || runners.isEmpty) {
          DialogUtils.showErrorDialog(context, 
            message: 'Invalid data received from bib recorder. Please try again.');
          return;
        }
        
        final runnerInCorrectFormat = runners.every((runner) => 
          runner.bib.isNotEmpty && 
          runner.name.isNotEmpty && 
          runner.school.isNotEmpty && 
          runner.grade > 0);
        
        if (!runnerInCorrectFormat) {
          DialogUtils.showErrorDialog(context, 
            message: 'Invalid data format received from bib recorder. Please try again.');
          return;
        }

        // Update state after async operations are complete
        setState(() {
          if (_runners.isNotEmpty) _runners.clear();
          _runners.addAll(runners);
        });
        
        debugPrint('Runners loaded: $_runners');
        
        // Close dialog and handle UI updates after state is set
        if (_runners.isNotEmpty && mounted) {
          // Close the "No Runners Loaded" dialog
          Navigator.of(context).pop();
          
          // Setup tutorials after UI has settled
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setupTutorials();
          });

          _controller.devices = DeviceConnectionService.createDevices(
            DeviceName.bibRecorder,
            DeviceType.advertiserDevice,
            data: '',
          );
          
          // Reset the bib number field
          _controller.handleBibNumber('');
        }
      } catch (e) {
        debugPrint('Error loading runners: $e');
        DialogUtils.showErrorDialog(context, 
          message: 'Error processing runner data: $e');
      }
    } else {
      DialogUtils.showErrorDialog(context, 
        message: 'No data received from bib recorder. Please try again.');
    }
  }

  Future<void> _showShareBibNumbersPopup() async {
    // Clear all focus nodes to prevent focus restoration
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    for (var node in provider.focusNodes) {
      node.unfocus();
      // Disable focus restoration for this node
      node.canRequestFocus = false;
    }

    bool confirmed = await _controller.cleanEmptyRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }
    
    confirmed = await _controller.checkDuplicateRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }
    
    confirmed = await _controller.checkUnknownRecords();
    if (!confirmed) {
      _controller.restoreFocusability();
      return;
    }

    final String bibData = _controller.getEncodedBibData();
    _controller.devices.coach?.data = bibData;
    if (!mounted) return;
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: deviceConnectionWidget(
        context,
        _controller.devices,
      ),
    );

    _controller.restoreFocusability();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Use the stored reference instead of accessing Provider in dispose
    for (var node in _providerReference.focusNodes) {
      node.removeListener(() {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorialRoot(
      tutorialManager: tutorialManager,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: Column(
              children: [
                buildRoleBar(context, 'bib recorder', tutorialManager),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Consumer<BibRecordsProvider>(
                    builder: (context, provider, _) {
                      return Text(
                        'Bib Number Count: ${_model.countNonEmptyBibNumbers(context)}',
                        style: AppTypography.bodyRegular
                      );
                    }
                  )
                ),
                Expanded(
                  child: Consumer<BibRecordsProvider>(
                    builder: (context, provider, child) {
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: provider.bibRecords.length + 1,
                        itemBuilder: (context, index) {
                          if (index < provider.bibRecords.length) {
                            return Dismissible(
                              key: ValueKey(provider.bibRecords[index]),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16.0),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                for (var node in provider.focusNodes) {
                                  node.unfocus();
                                  // Disable focus restoration for this node
                                  node.canRequestFocus = false;
                                }
                                bool delete = await DialogUtils.showConfirmationDialog(
                                  context,
                                  title: 'Confirm Deletion',
                                  content: 'Are you sure you want to delete this bib number?',
                                );
                                _controller.restoreFocusability();
                                return delete;
                              },
                              onDismissed: (direction) {
                                setState(() {
                                  _controller.onBibRecordRemoved(index);
                                });
                              },
                              child: BibInputWidget(
                                index: index,
                                record: provider.bibRecords[index],
                                onBibNumberChanged: _controller.handleBibNumber,
                                onSubmitted: () => _controller.handleBibNumber(''),
                              ),
                            );
                          }
                          return AddButtonWidget(
                            tutorialManager: tutorialManager,
                            onTap: () => _controller.handleBibNumber(''),
                          );
                        },
                      );
                    },
                  ),
                ),
                Consumer<BibRecordsProvider>(
                  builder: (context, provider, _) {
                    return provider.isKeyboardVisible 
                      ? const SizedBox.shrink() 
                      : BottomActionButtonsWidget(
                          onShareBibNumbers: _showShareBibNumbersPopup,
                        );
                  },
                ),
                Consumer<BibRecordsProvider>(
                  builder: (context, provider, _) {
                    if (!(Platform.isIOS || Platform.isAndroid) || !provider.isKeyboardVisible || provider.bibRecords.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return KeyboardAccessoryBar(
                      onDone: () => FocusScope.of(context).unfocus(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      )
    );
  }
}
