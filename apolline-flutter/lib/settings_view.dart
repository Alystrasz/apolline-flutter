import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final EdgeInsets padding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);
  @override
  State<StatefulWidget> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding,
      child: Wrap(
        children: [
          _buildPM1Card()
        ],
      ),
    );
  }
}

Widget _buildPM1Card () {
  return Card(
      child: Wrap(
        children: [
          Container(
              padding: EdgeInsets.only(left: 15, top: 10, bottom: 20),
              child: Text("PM1", style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold
              ))
          ),
          ListTile(
            title: Text("Warning threshold"),
            trailing: Container(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                expands: false,
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "15",
                    suffixIcon: Text("µm/m³")
                ),
              ),
            ),
          ),
          ListTile(
            title: Text("Danger threshold"),
            trailing: Container(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                expands: false,
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "30",
                    suffixIcon: Text("µm/m³")
                ),
              ),
            ),
          )
        ],
      )
  );
}