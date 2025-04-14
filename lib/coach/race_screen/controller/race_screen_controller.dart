import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:xcelerate/coach/race_screen/screen/race_screen.dart';
import 'package:xcelerate/utils/sheet_utils.dart' show sheet;
import '../../../core/components/dialog_utils.dart';
import '../../../utils/enums.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../flows/controller/flow_controller.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/event_bus.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import for color picker
import 'package:geolocator/geolocator.dart'; // Import for geolocation

/// Controller class for the RaceScreen that handles all business logic
class RaceScreenController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  late TabController tabController;
  
  // UI state properties
  bool isLocationButtonVisible = true; // Control visibility of location button
  
  // Runtime state
  int runnersCount = 0;
  
  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userlocationController = TextEditingController();
  
  // Team management
  List<TextEditingController> teamControllers = [];
  List<Color> teamColors = [];
  String? teamsError;
  
  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;

  late MasterFlowController flowController;

  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  BuildContext? _context;

  RaceScreenController({required this.raceId});

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in RaceScreenController. Call setContext() first.');
    return _context!;
  }

  static void showRaceScreen(BuildContext context, int raceId,
      {RaceScreenPage page = RaceScreenPage.main}) {
    sheet(
      context: context,
      body: RaceScreen(
        raceId: raceId,
        page: page,
      ),
      takeUpScreen: false, // Allow sheet to size according to content
      showHeader: true, // Keep the handle
    );
  }

  Future<void> init(BuildContext context) async {
    race = await loadRace();
    _initializeControllers();
    flowController = MasterFlowController(raceController: this);
    loadRunnersCount();
    notifyListeners();
  }

  /// Initialize controllers from race data
  void _initializeControllers() {
    if (race != null) {
      nameController.text = race!.raceName;
      locationController.text = race!.location;
      dateController.text = race!.raceDate != null
          ? DateFormat('yyyy-MM-dd').format(race!.raceDate!)
          : '';
      distanceController.text = race!.distance != -1 ? race!.distance.toString() : '';
      unitController.text = race!.distanceUnit;
      _initializeTeamControllers();
    }
  }

  /// Initialize team controllers from race data
  void _initializeTeamControllers() {
    if (race != null) {
      teamControllers.clear();
      teamColors.clear();
      
      // If no teams exist yet, add one empty controller
      if (race!.teams.isEmpty) {
        teamControllers.add(TextEditingController());
        teamColors.add(Colors.white); // Default first team color
      } else {
        // Create controllers for each team
        for (var i = 0; i < race!.teams.length; i++) {
          var controller = TextEditingController(text: race!.teams[i]);
          teamControllers.add(controller);
          
          // Use the color from race.teamColors if available
          if (i < race!.teamColors.length) {
            teamColors.add(race!.teamColors[i]);
          } else {
            // Create a new color based on index
            teamColors.add(HSLColor.fromAHSL(1.0, (360 / race!.teams.length * i) % 360, 0.7, 0.5).toColor());
          }
        }
      }
    }
  }

  /// Add a new team field
  void addTeamField() {
    teamControllers.add(TextEditingController());
    
    teamColors.add(Colors.white);
    notifyListeners();
  }

  Future<void> saveRaceDetails() async {    
    // Capture the context in a local variable before any async operations
    
    // Parse date
    DateTime? date;
    try {
      if (dateController.text.isNotEmpty) {
        date = DateTime.parse(dateController.text);
      }
    } catch (e) {
      SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD'));
      return;
    }
    
    // Parse distance
    double distance = -1;
    try {
      if (distanceController.text.isNotEmpty) {
        distance = double.parse(distanceController.text);
      }
    } catch (e) {
      SnackBar(content: Text('Invalid distance format'));
      return;
    }
    
    
    // Update the race in database
    await DatabaseHelper.instance.updateRaceField(raceId, 'location', locationController.text);
    await DatabaseHelper.instance.updateRaceField(raceId, 'raceDate', date?.toIso8601String());
    await DatabaseHelper.instance.updateRaceField(raceId, 'distance', distance);
    await DatabaseHelper.instance.updateRaceField(raceId, 'distanceUnit', unitController.text);
    
    await saveTeamData();
    
    // Refresh the race data
    await loadRace();
    notifyListeners();
    
    SnackBar(content: Text('Race details saved!'));
  }


  /// Save team data to database
  Future<void> saveTeamData() async {
    if (race == null) return;
    
    final teams = teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    
    // Convert Color objects to integer values for database storage
    final colors = teamColors.map((color) => color.value).toList();
    
    await DatabaseHelper.instance.updateRaceField(race!.raceId, 'teams', teams);
    await DatabaseHelper.instance.updateRaceField(race!.raceId, 'teamColors', colors);
    
    // Reload race to update state
    race = await loadRace();
    notifyListeners();
  }

  /// Show color picker dialog for team color
  void showColorPicker(StateSetter setSheetState, TextEditingController teamController) {
    final index = teamControllers.indexOf(teamController);
    if (index < 0) return;

    Color pickerColor = teamColors[index];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color for this team'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setSheetState(() {
                  teamColors[index] = pickerColor;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  /// Load the race data and any saved results
  Future<Race?> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    
    // Populate controllers with race data
    if (loadedRace != null) {
      nameController.text = loadedRace.raceName;
      locationController.text = loadedRace.location;
      if (loadedRace.raceDate != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(loadedRace.raceDate!);
      }
      distanceController.text = loadedRace.distance.toString();
      unitController.text = loadedRace.distanceUnit;
    }
    
    return loadedRace;
  }

  /// Update the race flow state
  Future<void> updateRaceFlowState(String newState) async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();
    
    // Publish an event when race flow state changes
    EventBus.instance.fire(EventTypes.raceFlowStateChanged, {
      'raceId': raceId,
      'newState': newState,
      'race': race,
    });
  }

  /// Mark the current flow as completed
  Future<void> markCurrentFlowCompleted(BuildContext context) async {
    if (race == null) return;
    
    // Update to the completed state for the current flow
    String completedState = race!.completedFlowState;
    await updateRaceFlowState(completedState);
    
    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_getFlowDisplayName(race!.flowState)} completed!'))
    );
  }
  
  /// Begin the next flow in the sequence
  Future<void> beginNextFlow(BuildContext context) async {
    if (race == null) return;
    
    // Determine the next non-completed flow state
    String nextState = race!.nextFlowState;
    
    // If the next state is a completed state, skip to the one after that
    if (nextState.contains('completed')) {
      int nextIndex = Race.FLOW_SEQUENCE.indexOf(nextState) + 1;
      if (nextIndex < Race.FLOW_SEQUENCE.length) {
        nextState = Race.FLOW_SEQUENCE[nextIndex];
      }
    }
    
    // Update to the next flow state
    await updateRaceFlowState(nextState);
    
    // If the race is now finished, show a final success message
    if (nextState == Race.FLOW_FINISHED) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Race has been completed! All steps are finished.'))
      );
    } else {
      // Otherwise show which flow we're beginning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beginning ${_getFlowDisplayName(nextState)}'))
      );
    }
    
    // Navigate to the appropriate screen based on the flow
    await flowController.handleFlowNavigation(context, nextState);
  }
  
  /// Helper method to get a user-friendly name for a flow state
  String _getFlowDisplayName(String flowState) {
    if (flowState == Race.FLOW_SETUP || flowState == Race.FLOW_SETUP_COMPLETED) {
      return 'Setup';
    }
    if (flowState == Race.FLOW_PRE_RACE || flowState == Race.FLOW_PRE_RACE_COMPLETED) {
      return 'Pre-Race';
    }
    if (flowState == Race.FLOW_POST_RACE || flowState == Race.FLOW_POST_RACE_COMPLETED) {
      return 'Post-Race';
    }
    if (flowState == Race.FLOW_FINISHED) {
      return 'Race';
    }
    return flowState.replaceAll('-', ' ').split(' ').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    if (race == null) return;
    
    String currentState = race!.flowState;
    
    // If the current state is a completed state, move to the next non-completed state
    if (currentState.contains('-completed')) {
      String nextState;
      
      if (currentState == Race.FLOW_SETUP_COMPLETED) {
        nextState = Race.FLOW_PRE_RACE;
      } else if (currentState == Race.FLOW_PRE_RACE_COMPLETED) {
        nextState = Race.FLOW_POST_RACE;
      } else if (currentState == Race.FLOW_POST_RACE_COMPLETED) {
        nextState = Race.FLOW_FINISHED;
      } else {
        return; // Unknown completed state
      }
      
      // Update to the next flow state
      await updateRaceFlowState(nextState);
      
      // Show a message about which flow we're starting
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beginning ${_getFlowDisplayName(nextState)}'))
      );
    }
    
    // Use the flow controller to handle the navigation
    await flowController.handleFlowNavigation(context, race!.flowState);
  }

  // Validation methods for form fields
  void validateName(String name, StateSetter setSheetState) {
    setSheetState(() {
      nameError = name.isEmpty ? 'Please enter a race name' : null;
    });
  }

  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      locationError = location.isEmpty ? 'Please enter a location' : null;
    });
  }

  void validateDate(String dateString, StateSetter setSheetState) {
    if (dateString.isEmpty) {
      setSheetState(() {
        dateError = 'Please enter a date';
      });
      return;
    }

    try {
      // Just parse to validate format, no need to store the result
      DateFormat('yyyy-MM-dd').parseStrict(dateString);
      setSheetState(() {
        dateError = null;
      });
    } catch (e) {
      setSheetState(() {
        dateError = 'Please enter a valid date (YYYY-MM-DD)';
      });
    }
  }

  void validateDistance(String distanceString, StateSetter setSheetState) {
    if (distanceString.isEmpty) {
      setSheetState(() {
        distanceError = 'Please enter a distance';
      });
      return;
    }

    try {
      final distance = double.parse(distanceString);
      setSheetState(() {
        distanceError = distance <= 0 ? 'Distance must be greater than 0' : null;
      });
    } catch (e) {
      setSheetState(() {
        distanceError = 'Please enter a valid number';
      });
    }
  }
  
  // Date picker method
  Future<void> selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    
    if (picked != null) {
      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      notifyListeners();
    }
  }

  /// Create device connections list for communication
  DevicesManager createDevices(DeviceType deviceType,
      {DeviceName deviceName = DeviceName.coach, String data = ''}) {
    return DeviceConnectionService.createDevices(
      deviceName,
      deviceType,
      data: data,
    );
  }

  /// Get the current location
  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are permanently denied');
        return;
      }

      if (permission == LocationPermission.denied) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are denied');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        DialogUtils.showErrorDialog(context,
            message: 'Location services are disabled');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.first;
      locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      userlocationController.text = locationController.text;
      locationError = null;
      notifyListeners();
      updateLocationButtonVisibility();
    } catch (e) {
      debugPrint('Error getting location: $e');
      DialogUtils.showErrorDialog(context, message: 'Could not get location');
    }
  }

  void updateLocationButtonVisibility() {
    isLocationButtonVisible =
        locationController.text.trim() != userlocationController.text.trim();
    notifyListeners();
  }

  /// Load runners count for this race
  Future<void> loadRunnersCount() async {
    if (race != null) {
      final runners = await DatabaseHelper.instance.getRaceRunners(race!.raceId);
      runnersCount = runners.length;
      notifyListeners();
    }
  }
}

// Global key for navigator context in dialogs
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
