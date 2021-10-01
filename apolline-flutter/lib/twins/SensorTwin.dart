import 'dart:async';

import 'package:apollineflutter/models/data_point_model.dart';
import 'package:apollineflutter/services/influxdb_client.dart';
import 'package:apollineflutter/services/location_service.dart';
import 'package:apollineflutter/services/realtime_data_service.dart';
import 'package:apollineflutter/services/service_locator.dart';
import 'package:apollineflutter/services/sqflite_service.dart';
import 'package:apollineflutter/twins/SensorTwinEvent.dart';
import 'package:apollineflutter/utils/position.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../gattsample.dart';



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
  QualifiedCharacteristic _characteristic;
  Stream<ConnectionStateUpdate> _deviceStream;
  StreamSubscription _deviceStreamSubscription;
  StreamSubscription _characteristicStream;
  DiscoveredDevice _device;
  bool _isSendingData;
  bool _isSendingHistory;
  Map<SensorTwinEvent, SensorTwinEventCallback> _callbacks;

  // use for influxDB to send data to the back
  InfluxDBAPI _service;
  SqfLiteService _sqfLiteService;
  Duration _synchronizationTiming;
  RealtimeDataService _dataService = locator<RealtimeDataService>();
  Timer _syncTimer;

  SimpleLocationService _locationService;
  Position _currentPosition;
  DeviceConnectionState _currentState;


  SensorTwin({@required DiscoveredDevice device, @required Duration syncTiming}) {
    this._device = device;
    this._isSendingData = false;
    this._isSendingHistory = false;
    this._callbacks = Map();
    this._service = InfluxDBAPI();
    this._sqfLiteService = SqfLiteService();
    this._synchronizationTiming = syncTiming;
  }


  String get name {
    return this._device.name;
  }


  /// Starts sending data live (one point every second) through Bluetooth
  /// connection.
  /// Does nothing if data transmission is already in progress.
  Future<void> launchDataLiveTransmission () async {
    if (_isSendingData) return null;
    _isSendingData = true;

    return FlutterReactiveBle().writeCharacteristicWithResponse(_characteristic, value: [0x63, 0]);
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

    return FlutterReactiveBle().writeCharacteristicWithResponse(_characteristic, value: finalCommand);
  }


  /// Registers a function to be called when new data is produced.
  void on (SensorTwinEvent event, SensorTwinEventCallback callback) {
    _callbacks[event] = callback;
  }

  /// Redistributes sensor status updates to registered callbacks.
  Future<void> _setUpStatusListener () async {
    this._deviceStream = FlutterReactiveBle().connectToDevice(id: _device.id).asBroadcastStream(onCancel: (state) {
      state.cancel();
    });
    this._deviceStreamSubscription = this._deviceStream.listen((ConnectionStateUpdate status) async {
      this._currentState = status.connectionState;
      print('Device connection state changed: ${this._currentState}');

      switch(status.connectionState) {
        case DeviceConnectionState.connected:
          if (_callbacks.containsKey(SensorTwinEvent.sensor_connected))
            _callbacks[SensorTwinEvent.sensor_connected]("connected");
          break;
        case DeviceConnectionState.disconnected:
          this._handleDisconnection();
          if (_callbacks.containsKey(SensorTwinEvent.sensor_disconnected))
            _callbacks[SensorTwinEvent.sensor_disconnected]("disconnected");
          break;
        default:
          break;
      }
    });
  }

  Future<void> _handleDisconnection () async {
    this.shutdown();
    await init();
  }

  /// Redistributes sensor data to registered callbacks.
  Future<void> _setUpDataListener () async {
    this._characteristicStream = FlutterReactiveBle().subscribeToCharacteristic(this._characteristic).listen((data) {
      String message = String.fromCharCodes(data);
      if (_isSendingData && _callbacks.containsKey(SensorTwinEvent.live_data)) {
        DataPointModel model = _handleSensorUpdate(message);
        _callbacks[SensorTwinEvent.live_data](model);
      } else if (_isSendingHistory && _callbacks.containsKey(SensorTwinEvent.history_data)) {
        _callbacks[SensorTwinEvent.history_data](message);
      }
    });
  }

  /// Filters out a Bluetooth device's services and characteristics to find the
  /// one that will allow us to receive data from the sensor.
  Future<bool> _loadUpSensorCharacteristic () async {
    List<DiscoveredService> services = await FlutterReactiveBle().discoverServices(_device.id);
    Iterable<DiscoveredService> sensorServices = services.where((service) => service.serviceId.toString().toLowerCase() == BlueSensorAttributes.dustSensorServiceUUID);
    if (sensorServices.length == 0) {
      return false;
    }
    this._characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(BlueSensorAttributes.dustSensorServiceUUID),
        characteristicId: Uuid.parse(BlueSensorAttributes.dustSensorCharacteristicUUID),
        deviceId: this._device.id
    );
    return true;
  }

  void _initLocationService () {
    this._locationService = SimpleLocationService();
    this._locationService.locationStream.listen((p) {
      this._currentPosition = p;
    });
  }

  void _initSynchronizationTimer () {
    this._syncTimer = Timer.periodic(_synchronizationTiming, (Timer t) => _synchronizationCallback());
  }

  /// Retrieves all data points from local database that have not been sent
  /// to InfluxDB yet, and sends them.
  /// Points that have been sent to backend are marked as synchronized, and are
  /// deleted from local database if they're more than one-week-old.
  void _synchronizationCallback () async {
    // find not-synchronized data
    List<DataPointModel> dataPoints = await _sqfLiteService.getNotSynchronizedModels();
    if (dataPoints.length == 0) return;


    // if a lot of data points have not been sent to the backend, we avoid
    // doing a HTTP call with a giant payload; we rather use several HTTP calls
    // each containing MAX_MODELS_COUNT models.
    const int MAX_MODELS_COUNT = 150;
    int modelsCount = dataPoints.length;
    int callsCount = (modelsCount/MAX_MODELS_COUNT).ceil();

    for (int i=0; i<callsCount; i++) {
      int lowerBound = i * MAX_MODELS_COUNT;
      int upperBound = i == callsCount - 1
          ? modelsCount
          : lowerBound + MAX_MODELS_COUNT;

      // Send data to influxDB
      List<DataPointModel> models = dataPoints.sublist(lowerBound, upperBound);
      print('Sending ${models.length} data points to InfluxDB');
      await _service.write(DataPointModel.sensorsFmtToInfluxData(models));

      // Update local data in sqfLite
      List<int> ids = models.map((model) => model.id).toList();
      await _sqfLiteService.setModelsAsSynchronized(ids);
    }

    // Avoiding using too much disk space
    _sqfLiteService.removeOldModels();
  }

  /// Called when data is received from the sensor
  DataPointModel _handleSensorUpdate (String message) {
    if (!message.contains('\n')) return null;
    print("Got full line: " + message);
    List<String> values = message.split(';');

    var model = DataPointModel(values: values, sensorName: this.name, position: _currentPosition);
    _dataService.update(model);
    /* insert to sqflite */
    _sqfLiteService.addDataPoint(model.toJSON());

    return model;
  }

  /// Sets up listeners and synchronises sensor clock.
  /// Must be called before starting data transmission.
  Future<bool> init () async {
    bool serviceFound = await _loadUpSensorCharacteristic();
    if (!serviceFound)
      return false;

    await _setUpStatusListener();

    ConnectionStateUpdate data = await this._deviceStream.first;
    if (data.connectionState == DeviceConnectionState.connected) {
      await _setUpDataListener();
      await synchronizeClock();
      _initLocationService();
      _initSynchronizationTimer();
      return true;
    } else {
      return false;
    }
  }

  /// Releases resources associated with the sensor.
  void shutdown () {
    this._callbacks = Map();
    this._syncTimer?.cancel();
    this._service.client?.close();
    this._dataService?.stop();
    this._locationService?.close();
    try {
      this._deviceStreamSubscription.cancel();
      this._characteristicStream.cancel();
    } catch (err) {
      print("Couldn't disconnect from sensor (probably because it is not reachable).");
    }
  }
}