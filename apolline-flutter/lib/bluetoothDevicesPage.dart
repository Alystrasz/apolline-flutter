import 'dart:async';

import 'package:apollineflutter/sensor_view.dart';
import 'package:apollineflutter/settings_view.dart';
import 'package:apollineflutter/utils/device_connection_status.dart';
import 'package:apollineflutter/widgets/device_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_blue/flutter_blue.dart' as fblue;
import 'package:apollineflutter/services/local_persistant_service.dart';
import 'package:apollineflutter/services/user_configuration_service.dart';
import 'package:apollineflutter/services/service_locator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:grant_and_activate/grant_and_activate.dart' as grant;
import 'package:grant_and_activate/utils/classes.dart';



class BluetoothDevicesPage extends StatefulWidget {
  BluetoothDevicesPage({Key key}) : super(key: key);
  final fblue.FlutterBlue flutterBlue = fblue.FlutterBlue.instance;
  final flutterReactiveBle = FlutterReactiveBle();

  @override
  _BluetoothDevicesPageState createState() => _BluetoothDevicesPageState();
}


class _BluetoothDevicesPageState extends State<BluetoothDevicesPage> {
  bool timeout = true;
  Set<DiscoveredDevice> devices = Set();
  Set<DiscoveredDevice> pairedDevices = Set();
  Set<DiscoveredDevice> unConnectableDevices = Set();
  StreamSubscription _devicesScanSubscription;

  ///user configuration in the ui
  UserConfigurationService ucS = locator<UserConfigurationService>();

  void setupBackgroundConfig () async {
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: "notifications.background.title".tr(),
      notificationText: "notifications.background.body".tr(),
      notificationImportance: AndroidNotificationImportance.Default,
      notificationIcon: AndroidResource(name: 'logo_apolline', defType: 'drawable'),
    );
    FlutterBackground.initialize(androidConfig: androidConfig);
  }

  @override
  void initState() {
    super.initState();
    setupBackgroundConfig();
    this.ucS.addListener(() {
      LocalKeyValuePersistance.saveObject(UserConfigurationService.USER_CONF_KEY, ucS.userConf.toJson());
    });
    initializeDevice();
  }

  ///
  ///Permet de tester si le bluetooth est activé ou pas
  Future<void> initializeDevice() async {
    dynamic result = await grant.checkPermissionsAndActivateServices([Feature.Bluetooth, Feature.Location]);
    if (result.allOk) {
      _performDetection();
    } else {
      showPermissionsDialog();
    }
  }

  ///
  ///Afficher un message pour activer le bluetooth et la geoloc
  void showPermissionsDialog() {
    Widget okbtn = TextButton(
      child: Text("OK"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );

    AlertDialog alert = AlertDialog(
      title: Text("devicesView.permissionsPopUp.title").tr(),
      content: Text("devicesView.permissionsPopUp.message").tr(),
      actions: [okbtn],
    );

    showDialog(
      context: context,
      builder: (context) => alert,
    );
  }

  void _stopSearchingForDevices() {
    setState(() {
      timeout = true;
    });
    this._devicesScanSubscription.cancel();
  }

  /* Starts BLE detection */
  void _performDetection() {
    setState(() {
      pairedDevices = Set();
      devices = Set();
      unConnectableDevices = Set();
    });


    // Start scanning
    setState(() {
      timeout = false;
    });

    this._devicesScanSubscription = widget.flutterReactiveBle.scanForDevices(scanMode: ScanMode.lowLatency, withServices: []).listen((device) {
      if (device.name.length > 0 && devices.where((element) => element.name == device.name).length == 0) {
        setState(() {
          devices.add(device);
        });
      }
    }, onError: (obj) {
      print(obj);
    });
    Timer(Duration(seconds: 10), () => _stopSearchingForDevices());



    /*
    widget.flutterBlue.startScan(timeout: Duration(seconds: 10)).then((val) {
      setState(() {
        timeout = true;
      });
    });

    widget.flutterBlue.connectedDevices.asStream().listen((List<fblue.BluetoothDevice> ds) {
      for (fblue.BluetoothDevice device in ds) {
        setState(() {
          pairedDevices.add(device);
          devices.remove(device);
        });
      }
    });
    /* For each result, insert into the detected devices list if not already present */
    widget.flutterBlue.scanResults.listen((results) {
      for (fblue.ScanResult r in results) {
        if (r.device.name.length > 0) {
          setState(() {
            devices.add(r.device);
          });
        }
      }
    });*/
  }


  /* Build the UI list of detected devices */
  List<Widget> _buildDevicesList() {
    List<Widget> wList = [];

    if (pairedDevices.length > 0) {
      wList.add(Container(
        child: Text("devicesView.pairedDevicesLabel").tr(),
        margin: EdgeInsets.only(top: 10, bottom: 10)
      ));

      pairedDevices.forEach((device) {
        wList.add(
            DeviceCard(
                device: device,
                connectionCallback: connectToDevice,
                enabled: !unConnectableDevices.contains(device)
            )
        );
        devices.remove(device);
      });
    }

    if (devices.length > 0) {
      wList.add(Container(
        margin: EdgeInsets.only(top: pairedDevices.length > 0 ? 30 : 10, bottom: 10),
        child: Text("devicesView.availableDevicesLabel").tr()
      ));

      devices.forEach((device) {
        wList.add(
            DeviceCard(
              device: device,
              connectionCallback: connectToDevice,
              enabled: !unConnectableDevices.contains(device)
            )
        );
      });
    }

    if (pairedDevices.length == 0 && devices.length == 0) {
      wList.add(Container(
          margin: EdgeInsets.only(top: pairedDevices.length > 0 ? 30 : 10, bottom: 10),
          child: Text("devicesView.noDevicesLabel").tr()
      ));
    }

    //for (var i=0; i<100; i++)
      //wList.add(Card(child: ListTile(title: Text("bonsoir"), subtitle: Text("Hello there"),)));

    return wList;
  }

  /* Handles a click on a device entry */
  void connectToDevice(DiscoveredDevice device) async {
    /* Stop scanning, if not already stopped */
    fblue.FlutterBlue.instance.stopScan();
    /* We selected a device - go to the device screen passing information about the selected device */
    DeviceConnectionStatus status = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Container() /*SensorView(device: device)*/),
    );

    switch (status) {
      case DeviceConnectionStatus.CONNECTED:
        setState(() {
          devices.remove(device);
          pairedDevices.add(device);
        });
        break;
      case DeviceConnectionStatus.DISCONNECTED:
        setState(() {
          devices.remove(device);
          pairedDevices.remove(device);
        });
        break;
      case DeviceConnectionStatus.UNABLE_TO_CONNECT:
      case DeviceConnectionStatus.INCOMPATIBLE:
        setState(() {
          unConnectableDevices.add(device);
        });
        break;
    }
  }

  ///
  ///Exécuter lorsqu'on clique sur le button Annalyser ou Arreter
  void _onPressLookforButton() {
    if (timeout == true) {
      initializeDevice();
    } else {
      this._stopSearchingForDevices();
    }
  }

  List<Widget> _buildChildrenButton() {
    const btnStyle = TextStyle(color: Colors.white);

    if (timeout) {
      return <Widget>[
        // ignore: missing_required_param
        TextButton(child: Text("devicesView.analysisButton.analyse", style: btnStyle,).tr()),
      ];
    } else {
      return <Widget>[
        SizedBox(
          child: CircularProgressIndicator(backgroundColor: Theme.of(context).primaryColor, color: Colors.white,),
          width: 20,
          height: 20,
        ),
        // ignore: missing_required_param
        TextButton(child: Text("devicesView.analysisButton.cancel", style: btnStyle).tr()),
      ];
    }
  }

  List<Widget> _buildAppBarAction() {
    List<Widget> wList = <Widget>[
      TextButton(
        onPressed: () {
          _onPressLookforButton();
        },
        child: Row(children: _buildChildrenButton()),
      ),
    ];
    return wList;
  }

  /* UI update only */
  @override
  Widget build(BuildContext context) {
    /* Scan for BLE devices (should be once) */
    //_performDetection();

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("devicesView.title").tr(),
        actions: _buildAppBarAction(),
      ),
      body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Container(
            child: ListView(
              children: _buildDevicesList(),
              padding: EdgeInsets.all(17)
            )
          )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.settings),
        onPressed: () => showModalBottomSheet(context: context, builder: (context) => SettingsPanel(ucS: ucS,)),
      ),
    );
  }
}
