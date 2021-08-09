import 'dart:async';

import 'package:apollineflutter/twins/SensorTwinEvent.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue/flutter_blue.dart';



///
/// This class acts as a digital twin for air quality sensors.
///
/// Through it, a sensor can be activated, clock-synchronized with a phone,
/// and asked to transmit data.
///
/// Data can be received in two ways:
///   * live; sensor sends data in real time (approximately one point per second)
///   * history; sensor sends all data it gathered in the past.
///
/// To access these data, one can subscribe to data events using the "on" method.
///
class SensorTwin {
  BluetoothCharacteristic _device;
  bool _isSendingData;
  bool _isSendingHistory;
  Map<SensorTwinEvent, SensorTwinEventCallback> _callbacks;


  SensorTwin({@required BluetoothCharacteristic device}) {
    this._device = device;
    this._isSendingData = false;
    this._isSendingHistory = false;
    this._callbacks = Map();
  }


  String get uuid {
    return this._device.uuid.toString();
  }


  /// Starts sending data live (one point every second) through Bluetooth
  /// connection.
  /// Does nothing if data transmission is already in progress.
  Future<void> launchDataLiveTransmission () {
    if (_isSendingData) return null;
    _isSendingData = true;

    return _device.write([0x63, 0]).then((s) {
      print("Requested streaming start");
    }).catchError((e) {
      print(e);
    });
  }

  /// Stops sending data.
  /// Does nothing if data transmission is not in progress.
  /// TODO implement
  Future<void> stopDataLiveTransmission () {
    return null;
  }


  /// Starts sending data stored on the SD card.
  /// Does nothing is history transmission is already in progress.
  /// TODO implement
  Future<void> launchHistoryTransmission () {
    return null;
  }


  /// Synchronises internal clock with phone's time.
  Future<void> synchronizeClock () {
    print("Synchronizing clock");
    String command = "i";
    DateTime now = DateTime.now();
    String time = "${now.hour};${now.minute};${now.second};${now.day};${now.month};${now.year}";
    String clockCommand = "$command$time";

    // converting command to bytes
    List<int> clockCommandBytes = clockCommand.codeUnits;
    // adding NULL at the end of the command
    List<int> finalCommand = new List.from(clockCommandBytes)..addAll([0x0]);

    return _device.write(finalCommand)
        .then((value) { return value; })
        .catchError((e) { print('ERROR WHILE SYNCHRONIZING CLOCK: $e'); });
  }


  /// Registers a function to be called when new data is produced.
  void on (SensorTwinEvent event, SensorTwinEventCallback callback) {
    _callbacks[event] = callback;
  }


  /// Redistributes sensor data to registered callbacks.
  Future<void> _setUpListeners () {
    return _device.setNotifyValue(true).then((s) {
      /* Catch updates on characteristic  */
    }).catchError((e) {
      print(e);
    }).whenComplete(() {

      _device.value.listen((value) {
        String message = String.fromCharCodes(value);

        if (_isSendingData && _callbacks.containsKey(SensorTwinEvent.live_data)) {
          _callbacks[SensorTwinEvent.live_data](message);
        } else if (_isSendingHistory && _callbacks.containsKey(SensorTwinEvent.history_data)) {
          _callbacks[SensorTwinEvent.history_data](message);
        }
      });
    });
  }


  /// Sets up listeners and synchronises sensor clock.
  /// Must be called before starting data transmission.
  Future<void> init () async {
    await _setUpListeners();
    await synchronizeClock();
  }
}