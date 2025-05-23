import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/device_connection_service.dart';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import 'data_package.dart';
import 'dart:math';

class _TransmissionState {
  final Completer<void> completer;
  Timer? retryTimer;
  int retryCount = 0;
  bool isCancelled = false;

  _TransmissionState() : completer = Completer<void>();
}

class ProtocolTerminatedException implements Exception {
  final String message;
  ProtocolTerminatedException([this.message = 'Protocol was terminated']);

  @override
  String toString() => 'ProtocolTerminatedException: $message';
}

class Protocol {
  static const int maxSendAttempts = 4;
  static const int retryTimeoutSeconds = 5;
  static const int chunkSize = 1000;

  final DeviceConnectionService deviceConnectionService;
  final Map<String, Device> connectedDevices =
      {}; // Map of device IDs to devices

  final Map<String, Map<int, Package>> _receivedPackages =
      {}; // Map of device ID to their packages
  final Map<int, _TransmissionState> _pendingTransmissions = {};
  final StreamController<void> _terminationController =
      StreamController<void>.broadcast();

  int _sequenceNumber = 0;
  final List<String> _finishedDevices = [];
  bool _isTerminated = false;
  final Map<String, int> _finishSequenceNumbers = {};

  Protocol({required this.deviceConnectionService});

  void addDevice(Device device) {
    connectedDevices[device.deviceId] = device;
    _receivedPackages[device.deviceId] = {};
    _finishSequenceNumbers[device.deviceId] = 0;
  }

  void removeDevice(String deviceId) {
    if (!connectedDevices.containsKey(deviceId)) return;
    connectedDevices.remove(deviceId);
    _receivedPackages.remove(deviceId);
    _finishSequenceNumbers.remove(deviceId);
  }

  Future<void> terminate() async {
    _isTerminated = true;

    for (var state in _pendingTransmissions.values) {
      state.isCancelled = true;
      state.retryTimer?.cancel();
      if (!state.completer.isCompleted) {
        state.completer.complete();
      }
    }

    _terminationController.add(null);
    clear();
  }

  Future<void> _handleAcknowledgment(Package package, String senderId) async {
    if (_isTerminated) return;

    if (package.number == _finishSequenceNumbers[senderId]) {
      _finishedDevices.add(senderId);
    }

    debugPrint(
        'Received acknowledgment for package ${package.number} from device $senderId');

    final state = _pendingTransmissions[package.number];
    if (state != null && !state.completer.isCompleted) {
      state.completer.complete();
    }
  }

  Future<void> handleMessage(Package package, String senderId) async {
    debugPrint('Handling message from $senderId: ${package.type}');
    if (_isTerminated) return;
    if (package.type != 'ACK' &&
        package.type != 'DATA' &&
        package.type != 'FIN') {
      throw Exception('Invalid package type: ${package.type}');
    }
    debugPrint(
        '[${DateTime.now()}] Received ${package.type} package ${package.number} from $senderId');

    if (package.type == 'ACK') {
      await _handleAcknowledgment(package, senderId);
      return;
    }

    if (package.type == 'DATA' &&
        (package.data == null || !package.checksumsMatch())) {
      debugPrint('Invalid package (${package.number}) from device $senderId');
      return;
    }

    // Store the package if it's a DATA or FIN package
    if (!_receivedPackages.containsKey(senderId)) {
      _receivedPackages[senderId] = {};
    }
    _receivedPackages[senderId]![package.number] = package;

    // Send acknowledgment
    try {
      if (!_isDeviceConnected(senderId)) {
        debugPrint(
            'Cannot send acknowledgment - device $senderId not connected');
        return;
      }

      // For FIN package, mark this device as finished after sending ACK
      if (package.type == 'FIN') {
        debugPrint('[${DateTime.now()}] Received FIN package from $senderId');
        _finishSequenceNumbers[senderId] = package.number;
      }

      await deviceConnectionService.sendMessageToDevice(
        connectedDevices[senderId]!,
        Package(number: package.number, type: 'ACK'),
      );

      if (package.type == 'FIN') {
        debugPrint('[${DateTime.now()}] Marking device $senderId as finished');
        _finishedDevices.add(senderId);
      }
    } catch (e) {
      if (!_isTerminated) {
        debugPrint('Error sending acknowledgment to device $senderId: $e');
        rethrow;
      }
    }
  }

  bool _isDeviceConnected(String senderId) {
    final device = connectedDevices[senderId];
    return device != null;
  }

  Future<void> _sendPackageWithRetry(Package package, String senderId) async {
    final startTime = DateTime.now();
    debugPrint(
        '[${startTime.toString()}] Starting _sendPackageWithRetry for package ${package.number}');

    if (_isTerminated) {
      debugPrint('Protocol terminated, cannot send package');
      throw ProtocolTerminatedException(
          'Cannot send package - protocol is terminated');
    }

    final state = _TransmissionState();
    _pendingTransmissions[package.number] = state;

    Future<void> attemptSend() async {
      try {
        if (!state.isCancelled && _isDeviceConnected(senderId)) {
          final attemptTime = DateTime.now();
          debugPrint(
              '[${attemptTime.toString()}] Attempt ${state.retryCount + 1}/$maxSendAttempts to send package');
          await deviceConnectionService.sendMessageToDevice(
              connectedDevices[senderId]!, package);
        } else if (!state.isCancelled && !_isDeviceConnected(senderId)) {
          state.completer
              .completeError('Device disconnected during transmission');
          throw Exception('Device disconnected during transmission');
        }
      } catch (e) {
        debugPrint(
            'Failed to send package ${package.number} to device $senderId: $e');
        rethrow;
      }
    }

    void scheduleRetry() {
      state.retryTimer = Timer(
        Duration(seconds: retryTimeoutSeconds),
        () async {
          if (state.isCancelled || state.completer.isCompleted) return;

          if (state.retryCount < maxSendAttempts - 1) {
            state.retryCount++;
            final retryTime = DateTime.now();
            debugPrint(
                '[${retryTime.toString()}] Retrying package ${package.number} (attempt ${state.retryCount + 1})');
            await attemptSend();
            scheduleRetry();
          } else {
            final failTime = DateTime.now();
            debugPrint(
                '[${failTime.toString()}] Failed to send package after ${state.retryCount + 1} attempts');
            state.completer.completeError(
                'Failed to send package after ${state.retryCount + 1} attempts');
          }
        },
      );
    }

    void cleanup() {
      state.retryTimer?.cancel();
      _pendingTransmissions.remove(package.number);
    }

    debugPrint(
        '[${DateTime.now().toString()}] Starting package send attempt for ${package.type} (seq: ${package.number})');

    try {
      await attemptSend();
      scheduleRetry();

      // Wait for acknowledgment or failure
      try {
        await state.completer.future;
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        debugPrint(
            '[${endTime.toString()}] Package ${package.number} successfully sent and acknowledged after ${duration.inMilliseconds}ms');
      } catch (e) {
        final errorTime = DateTime.now();
        final duration = errorTime.difference(startTime);
        debugPrint(
            '[${errorTime.toString()}] Failed to send package ${package.number} after ${duration.inMilliseconds}ms: $e');
        rethrow;
      } finally {
        cleanup();
      }
    } catch (e) {
      cleanup();
      throw Exception('Failed to send package: $e');
    }
  }

  Future<void> sendData(String data, String senderId) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException(
          'Cannot send data - protocol is terminated');
    }

    if (!connectedDevices.containsKey(senderId)) {
      throw Exception('Device $senderId not connected');
    }

    try {
      debugPrint('Starting to send data to device $senderId');
      // Split data into chunks
      final chunks = <String>[];
      for (var i = 0; i < data.length; i += chunkSize) {
        chunks.add(data.substring(i, min(i + chunkSize, data.length)));
      }
      debugPrint('Split data into ${chunks.length} chunks');

      // Send each chunk as a DATA package
      for (var i = 0; i < chunks.length; i++) {
        _sequenceNumber++;
        final package = Package(
          number: _sequenceNumber,
          type: 'DATA',
          data: chunks[i],
        );
        debugPrint('Sending chunk ${i + 1}/${chunks.length}');
        await _sendPackageWithRetry(package, senderId);
      }

      // Send FIN package to mark end of transmission
      _finishSequenceNumbers[senderId] = _sequenceNumber + 1;
      final finPackage = Package(
        number: _finishSequenceNumbers[senderId]!,
        type: 'FIN',
      );
      debugPrint('Sending FIN package');
      await _sendPackageWithRetry(finPackage, senderId);

      debugPrint(
          'Successfully sent ${chunks.length} chunks to device $senderId');
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      debugPrint('Error sending data to device $senderId: $e');
      rethrow;
    }
  }

  Future<String> receiveDataFromDevice(String deviceId) async {
    if (_isTerminated) {
      throw ProtocolTerminatedException(
          'Cannot receive data - protocol is terminated');
    }

    try {
      // Wait for either completion or termination
      await Future.any([
        Future.doWhile(() async {
          if (_finishedDevices.contains(deviceId) || _isTerminated) {
            return false;
          }
          await Future.delayed(
              Duration(milliseconds: 100)); // Reduced delay for faster response
          return true;
        }),
        _terminationController.stream.first,
      ]);

      if (_isTerminated) {
        debugPrint('Data reception terminated');
        throw ProtocolTerminatedException('Data reception interrupted');
      }
      debugPrint('Data reception complete, gathering results');

      Map<int, Package> packages = _receivedPackages[deviceId] ?? {};
      if (packages.isEmpty) {
        throw Exception('No packages received from $deviceId');
      }
      final List<Package> sortedPackages = _receivedPackages[deviceId]!
          .values
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));

      // Filter only DATA packages and verify sequence
      final List<Package> dataPackages =
          sortedPackages.where((p) => p.type == 'DATA').toList();

      if (dataPackages.isEmpty) {
        throw Exception('No DATA packages received from $deviceId');
      }

      // Verify we have all packages in sequence
      bool hasAllPackages = true;
      for (var i = 0; i < dataPackages.length; i++) {
        if (dataPackages[i].number != i + 1) {
          hasAllPackages = false;
          break;
        }
      }

      if (!hasAllPackages) {
        throw Exception('Missing packages in sequence from $deviceId');
      }

      // Combine data chunks
      final dataChunks = dataPackages
          .where((p) => p.data != null)
          .map((p) => p.data!)
          .toList();

      if (dataChunks.isEmpty) {
        throw Exception('No valid DATA packages received from $deviceId');
      }
      return dataChunks.join();
    } catch (e) {
      if (_isTerminated) {
        rethrow;
      }
      debugPrint('Error receiving data: $e');
      rethrow;
    }
  }

  void clear() {
    for (var state in _pendingTransmissions.values) {
      state.retryTimer?.cancel();
    }

    _pendingTransmissions.clear();
    _receivedPackages.clear();
    _sequenceNumber = 0;
    _finishedDevices.clear();
    _finishSequenceNumbers.clear();
  }

  void dispose() {
    try {
      terminate();
    } catch (e) {
      if (e is ProtocolTerminatedException) {
        return;
      }
      debugPrint('Error terminating protocol: $e');
      rethrow;
    }
  }
}
