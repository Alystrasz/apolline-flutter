import 'package:apollineflutter/services/user_configuration_service.dart';
import 'package:apollineflutter/utils/pm_card.dart';
import 'package:apollineflutter/utils/pm_filter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsPanel extends StatefulWidget {
  final EdgeInsets padding = EdgeInsets.only(left: 20, right: 20, top: 30, bottom: 10);
  final UserConfigurationService ucS;

  SettingsPanel({@required this.ucS});

  @override
  State<StatefulWidget> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _showWarningNotifications = true;
  bool _showDangerNotifications = true;

  @override
  initState () {
    this._showWarningNotifications = widget.ucS.userConf.showWarningNotifications;
    this._showDangerNotifications = widget.ucS.userConf.showDangerNotifications;
    super.initState();
  }

  List<Widget> _buildAllPMCards () {
    return PMFilter.values.map((value) => PMCard(ucS: widget.ucS, indicator: value)).toList();
  }

  Widget _buildInformationWidget () {
    return Container (
      child: Text(
          "Here, you can specify warning and danger thresholds.\n"
          "Received values lower than warning limit will be considered as normal, "
          "values superior to danger limit will be considered as dangerous."
      ),
    );
  }

  Widget _buildNotificationConfigurationWidget () {
    Function updateWarningState = (bool value) {
      widget.ucS.userConf.showWarningNotifications = value;
      widget.ucS.update();
      setState(() {
        _showWarningNotifications = value;
      });
    };

    Function updateDangerState = (bool value) {
      widget.ucS.userConf.showDangerNotifications = value;
      widget.ucS.update();
      setState(() {
        _showDangerNotifications = value;
      });
    };

    return Container (
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          ListTile(
            title: Text("Receive warning notifications"),
            onTap: () => updateWarningState(!_showWarningNotifications),
            trailing: Checkbox(
              value: _showWarningNotifications,
              onChanged: updateWarningState,
            ),
          ),
          ListTile(
            title: Text("Receive danger notifications"),
            onTap: () => updateDangerState(!_showDangerNotifications),
            trailing: Checkbox(
              value: _showDangerNotifications,
              onChanged: updateDangerState,
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = [
      _buildInformationWidget(),
      _buildNotificationConfigurationWidget(),
      Divider(height: 70)
    ];
    widgets.addAll(_buildAllPMCards());

    return Container(
      child: ListView(
        children: widgets,
        padding: widget.padding
      ),
    );
  }
}