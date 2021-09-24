import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class DeviceCard extends StatefulWidget {
  DeviceCard({this.device, this.connectionCallback, this.enabled = true});
  final DiscoveredDevice device;
  final Function(DiscoveredDevice) connectionCallback;
  final bool enabled;

  @override
  State<StatefulWidget> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.device.name),
        subtitle: Text(widget.device.id.toString()),
        onTap: () {
          widget.connectionCallback(widget.device);
        },
        enabled: widget.enabled,
        trailing: widget.enabled ? null : Icon(Icons.bluetooth_disabled_outlined),
      )
    );
  }
}