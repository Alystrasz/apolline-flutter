import 'dart:async';
import 'package:apollineflutter/twins/SensorTwin.dart';
import 'package:apollineflutter/twins/SensorTwinEvent.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'models/sensormodel.dart';
import 'widgets/maps.dart';
import 'widgets/quality.dart';
import 'widgets/stats.dart';



enum ConnexionType { Normal, Disconnect }


class SensorView extends StatefulWidget {
  SensorView({Key key, this.device}) : super(key: key);
  final BluetoothDevice device;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  @override
  State<StatefulWidget> createState() => _SensorViewState();
}


class _SensorViewState extends State<SensorView> {
  String state = "Connecting to the device...";
  SensorModel lastReceivedData;
  bool isConnected = false;
  bool showErrorAction = false;
  ConnexionType connectType = ConnexionType.Normal;
  SensorTwin _sensor;


  @override
  void initState() {
    super.initState();
    initializeDevice();
  }


  ///
  ///
  Future<void> initializeDevice() async {
    print("Connecting to device");

    try {
      await widget.device.connect();
      /* TODO: voir s'il ya possibilité de négocier le mtu */
    } catch (e) {
      if (e.code != "already_connected") {
        throw e;
      }
    } finally {
      handleDeviceConnect(widget.device);
    }
  }


  void updateState(String st) {
    print(st);
    setState(() {
      state = st;
    });
  }


  ///
  /// Builds up a sensor instance from a Bluetooth device.
  /// Sets up data listeners before starting live data transfer.
  ///
  void handleDeviceConnect(BluetoothDevice device) async {
    if (isConnected) return;
    isConnected = true;
    if (this._sensor != null)
      this._sensor.shutdown();

    updateState("Configuring device");
    this._sensor = SensorTwin(device: device, syncTiming: Duration(minutes: 2));
    this._sensor.on(SensorTwinEvent.live_data, (model) {
      // _handleSensorUpdate(data);
      setState(() {
        lastReceivedData = model;
      });
    });
    this._sensor.on(SensorTwinEvent.sensor_connected, (_) {
      print("--------------------connected--------------");
      if (connectType == ConnexionType.Disconnect && !isConnected) {
        print("-------------------connectedExécute---------");
        setState(() {
          showErrorAction = false;
        });
        handleDeviceConnect(widget.device);
      }
    });
    this._sensor.on(SensorTwinEvent.sensor_disconnected, (_) {
      print("----------------disconnected----------------");
      isConnected = false;
      connectType = ConnexionType.Disconnect; //deconnexion
      setState(() {
        showErrorAction = true;
      });
      showSnackbar("Connection perdu avec le capteur !");
    });
    await this._sensor.init();
    await this._sensor.launchDataLiveTransmission();
    updateState("Waiting for sensor data...");
  }


  ///
  ///Allows you to give information when you are unable to reconnect
  Future<void> showInformation() async {
    var text = "L'appareil sensor est soit éteint ou distant," +
        "veuillez vous assurez que l'appareil est chargé et près de votre téléphone;" +
        " faite un retour en arrière ou fermé et réouvré l'application; " +
        "sinon contactez l'administrateur";
    await showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          children: [
            Text(text),
          ],
        );
      },
    );
  }


  ///use for prevent when setState call after dispose methode.
  @override
  void setState(fn) {
    if (this.mounted) {
      super.setState(fn);
    }
  }

  ///
  ///Display a snackBar
  void showSnackbar(String msg) {
    var snackbar = SnackBar(content: Text(msg));
    if (widget.scaffoldKey != null && widget.scaffoldKey.currentState != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // _scaffoldKey.currentState.hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(snackbar);
      // _scaffoldKey.currentState.showSnackBar(snackbar);
    }
  }


  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  ///
  ///
  List<Widget> _buildAppBarAction() {
    return showErrorAction
        ? <Widget>[
            IconButton(
                icon: Icon(Icons.error),
                onPressed: () {
                  showInformation();
                })
          ]
        : [];
  }

  ///
  ///Called when press back button
  Future<bool> _onWillPop() async {
    Navigator.pop(context, isConnected);
    return false;
  }

  /* UI update only */
  @override
  Widget build(BuildContext context) {
    /* If we are not initialized, display status info */
    if (lastReceivedData == null) {
      return Scaffold(
        key: widget.scaffoldKey,
        appBar: AppBar(
          title: Text(_sensor != null ? _sensor.name : "Connecting to sensor..."),
          leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context, isConnected);
              }),
          actions: _buildAppBarAction(),
        ),
        body: Center(
          child: Column(children: <Widget>[
            CupertinoActivityIndicator(),
            Text(state),
          ]),
        ),
      );
    } else {
      /* We got data : display them */
      return WillPopScope(
        onWillPop: _onWillPop,
        child: MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
                key: widget.scaffoldKey,
                appBar: AppBar(
                  backgroundColor: Colors.green,
                  bottom: TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.home)),
                      Tab(icon: Icon(Icons.insert_chart)),
                      Tab(icon: Icon(Icons.map)),
                    ],
                  ),
                  title: Text('Apolline'),
                ),
                body: TabBarView(physics: NeverScrollableScrollPhysics(), children: [
                  Quality(lastReceivedData: lastReceivedData),
                  Stats(dataSensor: lastReceivedData),
                  MapSample(),
                ])),
          ),
        ),
      );
    }
  }
}
