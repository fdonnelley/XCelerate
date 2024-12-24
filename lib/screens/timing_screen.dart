import 'package:race_timing_app/screens/results_screen.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/timing_data.dart';
// import 'package:race_timing_app/bluetooth_service.dart' as app_bluetooth;
import 'package:race_timing_app/database_helper.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:barcode_scan2/barcode_scan2.dart';
// import 'package:race_timing_app/models/race.dart';

class TimingScreen extends StatefulWidget {
  final int raceId;

  const TimingScreen({
    Key? key, 
    required this.raceId,
  }) : super(key: key);


  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> {
  // final List<Map<String, dynamic>> _records = [];
  // DateTime? startTime;
  // final List<TextEditingController> _controllers = [];
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final ScrollController _scrollController = ScrollController();
  late int raceId;
  // List<BluetoothDevice> _availableDevices = [];
  // BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
  }

  void _startRace() {
    final records = Provider.of<TimingData>(context, listen: false).records;
    if (records.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a New Race'),
          content: const Text('Are you sure you want to start a new race? Doing so will clear the existing times.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                setState(() {
                  records.clear();
                  Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now());
                });
              },
              child: const Text('Yes'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        records.clear();
        Provider.of<TimingData>(context, listen: false).changeStartTime(DateTime.now());
      });
    }
  }

  void _stopRace() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the Race'),
        content: const Text('Are you sure you want to stop the race?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              setState(() {
                Provider.of<TimingData>(context, listen: false).changeStartTime(null);
              });
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _logTime() {
    final startTime = Provider.of<TimingData>(context, listen: false).startTime;
    if (startTime == null) return;

    setState(() {
      final now = DateTime.now();
      final difference = now.difference(startTime);

      Provider.of<TimingData>(context, listen: false).addRecord({
        'finish_time': formatDuration(difference),
        'bib_number': null,
        'place': Provider.of<TimingData>(context, listen: false).records.length + 1,
      });

      // Scroll to bottom after adding new record
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    });

    // Add a new controller for the new record
    Provider.of<TimingData>(context, listen: false).addController(TextEditingController());
  }

  void _updateBib(int index, int bib) async {
    final records = Provider.of<TimingData>(context, listen: false).records;
    // Update the bib in the record
    setState(() {
      records[index]['bib_number'] = bib;
    });

    // Fetch runner details from the database
    final runner = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bib, getShared: true);

    // Update the record with runner details if found
    if (runner != null) {
      setState(() {
        records[index]['name'] = runner['name'];
        records[index]['grade'] = runner['grade'];
        records[index]['school'] = runner['school'];
        records[index]['race_runner_id'] = runner['race_runner_id'];
        records[index]['race_id'] = raceId;
      });
    }
    else {
      setState(() {
        records[index]['name'] = null;
        records[index]['grade'] = null;
        records[index]['school'] = null;
        records[index]['race_runner_id'] = null;
        records[index]['race_id'] = null;
      });
    }
  }

  void _scanQRCode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        print('Scanned barcode: ${result.rawContent}');
        _processQRData(result.rawContent);
      }
    } catch (e) {
      _showErrorMessage('Failed to scan QR code: $e');
    }
  }

  void _processQRData(String qrData) async {
    final records = Provider.of<TimingData>(context, listen: false).records;
    try {
      final List<dynamic> bibData = json.decode(qrData);

      if (bibData.isNotEmpty) {
        for (int i = 0; i < bibData.length && i < records.length; i++) {
          setState(() {
            records[i]['bib_number'] = bibData[i];
          });

          final runner = await DatabaseHelper.instance.getRaceRunnerByBib(raceId, bibData[i], getShared: true);
          if (runner != null) {
            setState(() {
              records[i]['name'] = runner['name'];
              records[i]['grade'] = runner['grade'];
              records[i]['school'] = runner['school'];
            });
          }
        }
      } else {
        _showErrorMessage('QR code data is empty.');
      }
    } catch (e) {
      _showErrorMessage('Failed to process QR code data: $e');
    }
  }

  void _showErrorMessage(String message) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the popup
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
  }


  // void _findDevices() async {
  //   final service = app_bluetooth.BluetoothService();
  //   try {
  //     // Check if Bluetooth is enabled
  //     final isOn = await service.isBluetoothOn();
  //     print(isOn);
  //     if (!isOn) {
  //       _showBluetoothOffDialog();
  //       return;
  //     }

  //     await for (final devices in service.getAvailableDevices()) {
  //       setState(() {
  //         _availableDevices = devices;
  //       });
  //     }
  //   } catch (e) {
  //     // Handle other exceptions (optional)
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to scan for devices: $e')),
  //     );
  //   }
  // }

  // void _connectToDevice(BluetoothDevice device) async {
  //   final service = app_bluetooth.BluetoothService();
  //   try {
  //     final connectedDevice = await service.connectToDevice(device);
  //     setState(() {
  //       _connectedDevice = connectedDevice;
  //     });
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to connect: $e')),
  //     );
  //   }
  // }

  // void _syncDataWithDevice() async {
  //   if (_connectedDevice == null) return;

  //   final service = app_bluetooth.BluetoothService();
  //   try {
  //     // Receive bib number data
  //     final rawData = await service.receiveData(_connectedDevice!);
  //     final bibData = String.fromCharCodes(rawData).split(';');

  //     // Match bib numbers with times
  //     for (int i = 0; i < bibData.length && i < _records.length; i++) {
  //       setState(() {
  //         _records[i]['bib_number'] = bibData[i];
  //       });
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Sync failed: $e')),
  //     );
  //   }
  // }

  // void _disconnectDevice() async {
  //   final bluetoothService = app_bluetooth.BluetoothService();
  //   if (_connectedDevice == null) return;

  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Confirm Disconnect'),
  //         content: const Text('Are you sure you want to disconnect?'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(false),
  //           ),
  //           TextButton(
  //             child: const Text('Disconnect'),
  //             onPressed: () => Navigator.of(context).pop(true),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (confirm == true) {
  //     try {
  //       await bluetoothService.disconnectDevice(_connectedDevice!);
  //       setState(() {
  //         _connectedDevice = null; // Clear the connected device
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Disconnected successfully')),
  //       );
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to disconnect: $e')),
  //       );
  //     }
  //   }
  // }

  // void _showBluetoothOffDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Bluetooth Off'),
  //       content: const Text('Please turn on Bluetooth to search for devices.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //           },
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }


  // void _navigateToBibNumbers() {
  //   // Navigate to the BibNumberScreen
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => const BibNumberScreen(),
  //     ),
  //   );
  // }

  // void _navigateToResults() {
  //   // Check if all runners have a non-null bib number
  //   final records = Provider.of<TimingData>(context, listen: false).records;

  //   bool allRunnersHaveBibNumbers = records.every((runner) => runner['bib_number'] != null);

  //   if (allRunnersHaveBibNumbers) {
  //     // Navigate to the results page
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => ResultsScreen(runners: records),
  //       ),
  //     );
  //   } else {
  //     // Show a popup error if any bib number is null
  //     _showErrorMessage('All runners must have a bib number assigned before proceeding.');
  //     // showDialog(
  //     //   context: context,
  //     //   builder: (BuildContext context) {
  //     //     return AlertDialog(
  //     //       title: Text('Error'),
  //     //       content: Text('All runners must have a bib number assigned before proceeding.'),
  //     //       actions: [
  //     //         TextButton(
  //     //           onPressed: () {
  //     //             Navigator.of(context).pop(); // Close the popup
  //     //           },
  //     //           child: Text('OK'),
  //     //         ),
  //     //       ],
  //     //     );
  //     //   },
  //     // );
  //   }
  // }

  void _saveResults() async {
    // Check if all runners have a non-null bib number
    final records = Provider.of<TimingData>(context, listen: false).records;

    bool allRunnersHaveRequiredInfo = records.every((runner) => runner['bib_number'] != null && runner['name'] != null && runner['grade'] != null && runner['school'] != null);

    if (allRunnersHaveRequiredInfo) {
      // Remove the 'bib_number' key from the records before saving since it is not in database
      for (var record in records) {
        record.remove('bib_number');
        record.remove('name');
        record.remove('grade');
        record.remove('school');
      }

      await DatabaseHelper.instance.insertRaceResults(records);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Results saved successfully. Refresh page to view?'),
          action: SnackBarAction(
            label: 'Refresh',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => TimingScreen(raceId: raceId)),
              );
            },
          ),
        ),
      );

      
      // // Navigate to the results page
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (context) => ResultsScreen(raceId: raceId)), // Adjust to your actual results screen widget
      // );
    } else {
      _showErrorMessage('All runners must have a bib number assigned before proceeding.');
    }
  }


  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in Provider.of<TimingData>(context, listen: false).controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTime = Provider.of<TimingData>(context, listen: false).startTime;
    final records = Provider.of<TimingData>(context, listen: false).records;
    final controllers = Provider.of<TimingData>(context, listen: false).controllers;

    return Scaffold(
      // appBar: AppBar(title: const Text('Race Timing')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Race Timer Display
            if (startTime != null)
              StreamBuilder(
                stream: Stream.periodic(const Duration(milliseconds: 10)),
                builder: (context, snapshot) {
                  final currentTime = DateTime.now();
                  final elapsed = currentTime.difference(startTime);
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.1), // 1/10 from left
                    width: MediaQuery.of(context).size.width * 0.75, // 3/4 of screen width
                    child: Text(
                      formatDurationWithZeros(elapsed),
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.1,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        height: 1.0,
                      ),
                      textAlign: TextAlign.left,
                      strutStyle: StrutStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.15,
                        height: 1.0,
                        forceStrutHeight: true,
                      ),
                    ),
                  );
                },
              ),
            // Buttons for Race Control
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Padding around the button
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                      double fontSize = constraints.maxWidth * 0.12; // Scalable font size
                        return ElevatedButton(
                          onPressed: startTime == null ? _startRace : _stopRace,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(0, constraints.maxWidth * 0.5), // Button height scales
                          ),
                          child: Text(
                            startTime == null ? 'Start Race' : 'Stop Race',
                            style: TextStyle(fontSize: fontSize),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if ((startTime == null && records.isEmpty) || (startTime != null))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Padding around the button
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.12;
                          return ElevatedButton(
                            onPressed: startTime != null ? _logTime : null,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, constraints.maxWidth * 0.5),
                            ),
                            child: Text(
                              'Log Time',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (startTime == null && records.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Padding around the button
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.11;
                          return ElevatedButton(
                            onPressed: _scanQRCode,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, constraints.maxWidth * 0.5),
                            ),
                            child: Text(
                              'Load Bib #s',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (startTime == null && records.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0), // Padding around the button
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                        double fontSize = constraints.maxWidth * 0.12;
                          return ElevatedButton(
                            onPressed: _saveResults,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(0, constraints.maxWidth * 0.5),
                            ),
                            child: Text(
                              'Save Results',
                              style: TextStyle(fontSize: fontSize),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),



            // const SizedBox(height: 16),
            // ElevatedButton.icon(
            //   onPressed: _navigateToBibNumbers,
            //   icon: const Icon(Icons.numbers),
            //   label: const Text('Record Bib Numbers'),
            // ),

            // if (startTime == null && records.isNotEmpty) ...[
            //   SizedBox(height: MediaQuery.of(context).size.width * 0.05),
            //   Padding(
            //     padding: const EdgeInsets.only(bottom: 16.0),
            //     child: SizedBox(
            //       height: MediaQuery.of(context).size.width * 0.1,
            //       child: ElevatedButton.icon(
            //         onPressed: _navigateToResults,
            //         icon: const Icon(Icons.bar_chart),
            //         label: Text(
            //           'Go to Results',
            //           style: TextStyle(
            //             fontSize: MediaQuery.of(context).size.width * 0.05,
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
            // ],

            // const SizedBox(height: 8),
            // ElevatedButton.icon(
            //   onPressed: _findDevices,
            //   icon: const Icon(Icons.bluetooth),
            //   label: const Text('Connect via Bluetooth'),
            // ),
            // if (_connectedDevice != null) ...[
            //   const SizedBox(height: 8),
            //   ElevatedButton(
            //     onPressed: _disconnectDevice, // Add disconnect button
            //     child: const Text('Disconnect'),
            //   ),
            //   if (_startTime == null && _records.isNotEmpty)
            //     const SizedBox(height: 8),
            //     ElevatedButton(
            //       onPressed: _syncDataWithDevice,
            //       child: const Text('Sync Data'),
            //     ),
            // ],
            // const SizedBox(height: 16),
            // // Bluetooth Devices List
            // if (_availableDevices.isNotEmpty)
            //   Expanded(
            //     child: ListView.builder(
            //       itemCount: _availableDevices.length,
            //       itemBuilder: (context, index) {
            //         final device = _availableDevices[index];
            //         return Card(
            //           child: ListTile(
            //             title: Text(device.platformName.isNotEmpty
            //                 ? device.platformName
            //                 : 'Unknown Device'),
            //             subtitle: Text(device.remoteId.toString()),
            //             trailing: IconButton(
            //               icon: const Icon(Icons.link),
            //               onPressed: () {
            //                 _connectToDevice(device);
            //               },
            //             ),
            //           ),
            //         );
            //       },
            //     ),
            //   ),
            // if (_connectedDevice != null)
            //   DropdownButton<BluetoothDevice>(
            //     value: _connectedDevice,
            //     items: _availableDevices.map((device) {
            //       return DropdownMenuItem(
            //         value: device,
            //         child: Text(device.platformName),
            //       );
            //     }).toList(),
            //     onChanged: (device) {
            //       if (device != null) _connectToDevice(device);
            //     },
            //   ),
            // Records Section
            if (records.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final controller = controllers[index];
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.width * 0.02,
                        horizontal: MediaQuery.of(context).size.width * 0.02,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Time: ${record['finish_time']}',
                                  style: TextStyle(
                                    fontSize: MediaQuery.of(context).size.width * 0.05,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * 0.25,
                                  child: TextField(
                                    controller: controller,
                                    style: TextStyle(
                                      fontSize: MediaQuery.of(context).size.width * 0.04,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Bib #',
                                      labelStyle: TextStyle(
                                        fontSize: MediaQuery.of(context).size.width * 0.05,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: MediaQuery.of(context).size.width * 0.02,
                                        horizontal: MediaQuery.of(context).size.width * 0.03,
                                      ),
                                    ),
                                    onChanged: (value) => _updateBib(index, int.parse(value)),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width * 0.02),
                            if (record['name'] != null)
                              Text(
                                'Name: ${record['name']}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.035
                                ),
                              ),
                            if (record['grade'] != null)
                              Text(
                                'Grade: ${record['grade']}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.035
                                ),
                              ),
                            if (record['school'] != null)
                              Text(
                                'School: ${record['school']}',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.035
                                ),
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
}
