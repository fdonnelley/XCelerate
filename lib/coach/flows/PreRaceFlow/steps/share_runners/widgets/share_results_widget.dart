import 'package:flutter/material.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/services/device_connection_service.dart';

class ShareResultsWidget extends StatelessWidget {
  final DevicesManager devices;
  const ShareResultsWidget({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: deviceConnectionWidget(context, devices, inSheet: false));
  }
}
