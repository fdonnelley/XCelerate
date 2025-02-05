import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/race.dart';
import 'runners_management_screen.dart';
import '../utils/sheet_utils.dart';
import '../utils/app_colors.dart'; // Import AppColors
import '../device_connection_popup.dart';
import '../device_connection_service.dart';

class RaceInfoScreen extends StatefulWidget {
  final int raceId;
  const RaceInfoScreen({
    super.key, 
    required this.raceId,
  });

  @override
  _RaceInfoScreenState createState() => _RaceInfoScreenState();
}

class _RaceInfoScreenState extends State<RaceInfoScreen> with TickerProviderStateMixin {
  late String _name = '';
  late String _location = '';
  late String _date = '';
  late String _distance = '';
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _distanceController;
  late int raceId;
  late AnimationController _slideController;
  bool _showRunners = false;
  Race? race;

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    _loadRaceData();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _loadRaceData() async {
    final raceData = await DatabaseHelper.instance.getRaceById(raceId);
    if (raceData != null) {
      setState(() {
        race = raceData;
        _name = race!.race_name;
        _location = race!.location;
        _date = race!.race_date.toString();
        _distance = race!.distance;
        final stringDate = DateTime.parse(race!.race_date.toString()).toIso8601String().split('T').first;

        _nameController = TextEditingController(text: _name);
        _locationController = TextEditingController(text: _location);
        _dateController = TextEditingController(text: stringDate);
        _distanceController = TextEditingController(text: _distance.toString());
      });
    }
    else {
      print('raceData is null');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _distanceController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required void Function(String) onChanged,
    TextInputType? keyboardType,
    String? hintText,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: prefixIcon,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _goToRunnersScreen(BuildContext context) {
    setState(() {
      _showRunners = true;
    });
    _slideController.forward();
  }

  void _goBackToRaceInfo() {
    _slideController.reverse().then((_) {
      setState(() {
        _showRunners = false;
      });
    });
  }

  Widget _buildContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    return SizedBox(
      width: double.infinity,
      height: screenHeight * 0.92,
      child: Stack(
        children: [
          SizedBox(height: 10),
          createSheetHandle(height: 10, width: 60),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 30),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: 'Race Name',
                      controller: _nameController,
                      onChanged: (value) => setState(() => _name = value),
                      prefixIcon: const Icon(Icons.emoji_events_outlined),
                    ),
                    _buildTextField(
                      label: 'Location',
                      controller: _locationController,
                      onChanged: (value) => setState(() => _location = value),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                    ),
                    _buildTextField(
                      label: 'Date',
                      controller: _dateController,
                      onChanged: (value) {
                        setState(() => _date = value);
                        final date = DateTime.tryParse(value);
                        if (date != null) {
                          setState(() => _date = date.toString());
                        }
                      },
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                            firstDate: DateTime(2000), 
                            lastDate: DateTime(2101), 
                          );
                          if (pickedDate != null) {
                            _dateController.text = pickedDate.toLocal().toString().split(' ')[0];
                            setState(() => _date = pickedDate.toString()); 
                          }
                        },
                      ),
                      hintText: 'YYYY-MM-DD',
                      keyboardType: TextInputType.datetime,
                    ),
                    _buildTextField(
                      label: 'Distance',
                      controller: _distanceController,
                      onChanged: (value) {
                        final doubleDistance = double.tryParse(value);
                        if (doubleDistance != null) {
                          final distancePart = _distance.split(' ')[0];
                          setState(() => _distance.replaceAll(distancePart, doubleDistance.toString()));
                        }
                      },
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                      prefixIcon: const Icon(Icons.straighten),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _goToRunnersScreen(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    fixedSize: const Size(300, 70),
                    backgroundColor: AppColors.mediumColor,
                  ),
                  child: const Text('See Runners', style: TextStyle(fontSize: 25, color: AppColors.backgroundColor)),
                ),
                Center(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          showDeviceConnectionPopup(
                            context,
                            deviceType: DeviceType.advertiserDevice,
                            deviceName: DeviceName.coach,
                            otherDevices: createOtherDeviceList(
                              DeviceName.coach,
                              DeviceType.advertiserDevice,
                              data: 'data',
                            ),
                          );
                        },
                        child: Text('Send Runners Data'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          showDeviceConnectionPopup(
                            context,
                            deviceType: DeviceType.browserDevice,
                            deviceName: DeviceName.coach,
                            otherDevices: createOtherDeviceList(
                              DeviceName.coach,
                              DeviceType.browserDevice,
                              data: 'data',
                            ),
                          );
                        },
                        child: Text('Get Race Results Data'),
                      ),
                    ]
                  )
                ),
              ],
            ),
          ),
          if (_showRunners || _slideController.value > 0)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOut,
              )),
              child: SizedBox.expand(
                child: Material(
                  color: AppColors.backgroundColor,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 8,
                        child: SizedBox(
                          height: 40,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.primaryColor, size: 40),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: ButtonStyle(
                              iconColor: WidgetStateProperty.all(AppColors.primaryColor),
                            ),
                            onPressed: _goBackToRaceInfo,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: RunnersManagementScreen(isTeam: false, raceId: raceId),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return Center(
        child: CircularProgressIndicator(), // Show loading indicator
      );
    }

    bool hasChanges = _name != race!.race_name || 
      _location != race!.location || 
      _date != race!.race_date.toString() || 
      _distance != race!.distance;

    return Column(
      children: [
        // if (!_showRunners) ...[
        //   SizedBox(height: 10),
        //   createSheetHandle(height: 10, width: 60),
        // ],
        // if (_showRunners) ...[
        //   SizedBox(height: 30),
        //   // createSheetHandle(height: 10, width: 60),
        // ],
        Expanded(
          // child: SingleChildScrollView(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 10.0),
                child: _buildContent(),
              ),
            ),
          // ),
        ),
        if (hasChanges) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateRace({
                  'race_id': race?.race_id,
                  'race_name': _name,
                  'location': _location,
                  'race_date': _date,
                  'distance': _distance,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Changes saved successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ],
    );
  }
}