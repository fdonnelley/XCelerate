enum ConnectionStatus {
  connected,
  connecting,
  finished,
  error,
  sending,
  receiving,
  timeout,
  searching,
  found,
}

enum WirelessConnectionError {
  unavailable,
  unknown,
  timeout,
}

enum PopupScreen {
  main,
  qr,
}

enum DeviceName {
  coach,
  bibRecorder,
  raceTimer,
}

enum DeviceType {
  advertiserDevice,
  browserDevice,
}

enum RecordType {
  runnerTime,
  confirmRunner,
  missingRunner,
  extraRunner,
}

enum RaceScreenPage {
  main,
  results,
}

enum ResultFormat {
  plainText,
  googleSheet,
  pdf,
}
