// Copyright 2020 Kenton Hamaluik
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_share/flutter_share.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timecop/blocs/projects/projects_bloc.dart';
import 'package:timecop/blocs/settings/bloc.dart';
import 'package:timecop/blocs/settings/settings_bloc.dart';
import 'package:timecop/blocs/timers/bloc.dart';
import 'package:timecop/components/ProjectColour.dart';
import 'package:timecop/l10n.dart';
import 'package:timecop/models/project.dart';
import 'package:timecop/models/timer_entry.dart';

class ExportScreen extends StatefulWidget {
  ExportScreen({Key key}) : super(key: key);

  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class DayGroup {
  final DateTime date;
  List<TimerEntry> timers = [];

  DayGroup(this.date)
  : assert(date != null);
}

class _ExportScreenState extends State<ExportScreen> {
  DateTime _startDate;
  DateTime _endDate;
  List<Project> selectedProjects = [];
  static DateFormat _dateFormat = DateFormat("EE, MMM d, yyyy");

  @override
  void initState() {
    super.initState();
    final ProjectsBloc projects = BlocProvider.of<ProjectsBloc>(context);
    assert(projects != null);
    selectedProjects = <Project>[null].followedBy(projects.state.projects.map((p) => Project.clone(p))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsBloc settingsBloc = BlocProvider.of<SettingsBloc>(context);
    final ProjectsBloc projectsBloc = BlocProvider.of<ProjectsBloc>(context);

    // TODO: break this into components or something so we don't have such a massively unmanagement build function

    return Scaffold(
      appBar: AppBar(
        title: Text(L10N.of(context).tr.export),
        actions: <Widget>[
          IconButton(
            icon: Icon(FontAwesomeIcons.database),
            onPressed: () async {
              var databasesPath = await getDatabasesPath();
              var dbPath = p.join(databasesPath, 'timecop.db');

              // on android, copy it somewhere where it can be shared
              if (Platform.isAndroid) {
                Directory directory = await getExternalStorageDirectory();
                File copiedDB = await File(dbPath).copy(p.join(directory.path, "timecop.db"));
                dbPath = copiedDB.path;
              }
              await FlutterShare.shareFile(title: L10N.of(context).tr.timeCopDatabase(_dateFormat.format(DateTime.now())), filePath: dbPath);
            },
          )
        ],
      ),
      body: ListView(
        children: <Widget>[
          /*Padding(
            padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  L10N.of(context).tr.options,
                  style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w700
                  )
                ),
              ],
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.groupTimers),
              value: settingsState.exportGroupTimers,
              onChanged: (bool value) => settingsBloc.add(SetExportGroupTimers(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),*/
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  L10N.of(context).tr.filter,
                  style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w700
                  )
                ),
              ],
            ),
          ),
          Slidable(
            actionPane: SlidableDrawerActionPane(),
            actionExtentRatio: 0.15,
            child: ListTile(
              leading: Icon(FontAwesomeIcons.calendar),
              title: Text(L10N.of(context).tr.from),
              trailing: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 18, 0),
                child: Text(_startDate == null ? "—" : _dateFormat.format(_startDate)),
              ),
              onTap: () async {
                await DatePicker.showDatePicker(
                  context,
                  currentTime: _startDate,
                  onChanged: (DateTime dt) => setState(() => _startDate = dt),
                  onConfirm: (DateTime dt) => setState(() => _startDate = dt),
                  theme: DatePickerTheme(
                    cancelStyle: Theme.of(context).textTheme.button,
                    doneStyle: Theme.of(context).textTheme.button,
                    itemStyle: Theme.of(context).textTheme.body1,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  )
                );
              },
            ),
            secondaryActions:
              _startDate == null
                ? <Widget>[]
                : <Widget>[
                  IconSlideAction(
                    color: Theme.of(context).errorColor,
                    foregroundColor: Theme.of(context).accentIconTheme.color,
                    icon: FontAwesomeIcons.minusCircle,
                    onTap: () {
                      setState(() {
                        _startDate = null;
                      });
                    },
                  )
                ],
          ),
          Slidable(
            actionPane: SlidableDrawerActionPane(),
            actionExtentRatio: 0.15,
            child: ListTile(
              leading: Icon(FontAwesomeIcons.calendar),
              title: Text(L10N.of(context).tr.to),
              trailing: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 18, 0),
                child: Text(_endDate == null ? "—" : _dateFormat.format(_endDate)),
              ),
              onTap: () async {
                await DatePicker.showDatePicker(
                  context,
                  currentTime: _endDate,
                  onChanged: (DateTime dt) => setState(() => _endDate = dt),
                  onConfirm: (DateTime dt) => setState(() => _endDate = dt),
                  theme: DatePickerTheme(
                    cancelStyle: Theme.of(context).textTheme.button,
                    doneStyle: Theme.of(context).textTheme.button,
                    itemStyle: Theme.of(context).textTheme.body1,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  )
                );
              },
            ),
            secondaryActions:
              _endDate == null
                ? <Widget>[]
                : <Widget>[
                  IconSlideAction(
                    color: Theme.of(context).errorColor,
                    foregroundColor: Theme.of(context).accentIconTheme.color,
                    icon: FontAwesomeIcons.minusCircle,
                    onTap: () {
                      setState(() {
                        _endDate = null;
                      });
                    },
                  )
                ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  L10N.of(context).tr.columns,
                  style: TextStyle(
                    color: Theme.of(context).accentColor,
                    fontWeight: FontWeight.w700
                  )
                ),
              ],
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.project),
              value: settingsState.exportIncludeProject,
              onChanged: (bool value) => settingsBloc.add(SetExportIncludeProject(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.description),
              value: settingsState.exportIncludeDescription,
              onChanged: (bool value) => settingsBloc.add(SetExportIncludeDescription(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.startTime),
              value: settingsState.exportIncludeStartTime,
              onChanged: (bool value) => settingsBloc.add(SetExportIncludeStartTime(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.endTime),
              value: settingsState.exportIncludeEndTime,
              onChanged: (bool value) => settingsBloc.add(SetExportIncludeEndTime(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),
          BlocBuilder<SettingsBloc, SettingsState>(
            bloc: settingsBloc,
            builder: (BuildContext context, SettingsState settingsState) => SwitchListTile(
              title: Text(L10N.of(context).tr.timeH),
              value: settingsState.exportIncludeDurationHours,
              onChanged: (bool value) => settingsBloc.add(SetExportIncludeDurationHours(value)),
              activeColor: Theme.of(context).accentColor,
            ),
          ),
          ListTile(
            title: Text(
              L10N.of(context).tr.includeProjects,
              style: TextStyle(
                color: Theme.of(context).accentColor,
                fontSize: Theme.of(context).textTheme.body1.fontSize,
                fontWeight: FontWeight.w700
              )
            ),
            trailing: Checkbox(
              tristate: true,
              value: selectedProjects.length == projectsBloc.state.projects.length + 1
                ? true
                : (selectedProjects.isEmpty
                  ? false
                  : null),
              activeColor: Theme.of(context).accentColor,
              onChanged: (_) => setState(() {
                if(selectedProjects.length == projectsBloc.state.projects.length + 1) {
                  selectedProjects.clear();
                }
                else {
                  selectedProjects = <Project>[null].followedBy(projectsBloc.state.projects.map((p) => Project.clone(p))).toList();
                }
              }),
            ),
            onTap: () => setState(() {
              if(selectedProjects.length == projectsBloc.state.projects.length + 1) {
                selectedProjects.clear();
              }
              else {
                selectedProjects = <Project>[null].followedBy(projectsBloc.state.projects.map((p) => Project.clone(p))).toList();
              }
            })
          ),
        ]
        .followedBy(
          <Project>[null].followedBy(projectsBloc.state.projects).map(
            (project) => CheckboxListTile(
              secondary: ProjectColour(project: project,),
              title: Text(project?.name ?? L10N.of(context).tr.noProject),
              value: selectedProjects.any((p) => p?.id == project?.id),
              activeColor: Theme.of(context).accentColor,
              onChanged: (_) => setState(() {
                if(selectedProjects.any((p) => p?.id == project?.id)) {
                  selectedProjects.removeWhere((p) => p?.id == project?.id);
                }
                else {
                  selectedProjects.add(project);
                }
              }),
            )
          )
        )
        .followedBy([
          ListTile(), // add some space so the FAB doesn't always overlap the bottom options
        ])
        .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        child: Stack(
        // shenanigans to properly centre the icon (font awesome glyphs are variable
        // width but the library currently doesn't deal with that)
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: 15,
            left: 19,
            child: Icon(FontAwesomeIcons.fileExport),
          )
        ],
      ),
        onPressed: () async {
          final TimersBloc timers = BlocProvider.of<TimersBloc>(context);
          assert(timers != null);
          final ProjectsBloc projects = BlocProvider.of<ProjectsBloc>(context);
          assert(projects != null);

          List<String> headers = [];
          if(settingsBloc.state.exportIncludeProject) {
            headers.add(L10N.of(context).tr.project);
          }
          if(settingsBloc.state.exportIncludeDescription) {
            headers.add(L10N.of(context).tr.description);
          }
          if(settingsBloc.state.exportIncludeStartTime) {
            headers.add(L10N.of(context).tr.startTime);
          }
          if(settingsBloc.state.exportIncludeEndTime) {
            headers.add(L10N.of(context).tr.endTime);
          }
          if(settingsBloc.state.exportIncludeDurationHours) {
            headers.add(L10N.of(context).tr.timeH);
          }

          // TODO: this isn't working..
          /*List<TimerEntry> filteredTimers;
          if(settingsBloc.state.exportGroupTimers && !(settingsBloc.state.exportIncludeStartTime || settingsBloc.state.exportIncludeEndTime)) {
            print("grouping timers...");
            filteredTimers = 
              timers.state.timers
                .where((t) => t.endTime != null)
                .where((t) => selectedProjects.any((p) => p?.id == t.projectID))
                .map((t) => TimerEntry.clone(t))
                .fold(<DayGroup>[], (List<DayGroup> days, TimerEntry t) {
                  // find which day this timer belongs to
                  DayGroup currentDay = days.firstWhere((DayGroup day) => (day.date.year == t.startTime.year && day.date.month == t.startTime.month && day.date.day == t.startTime.day));
                  if(currentDay == null) {
                    currentDay = DayGroup(t.startTime);
                    days.add(currentDay);
                  }

                  // determine if there are any timers this day that match it
                  TimerEntry match = currentDay.timers.firstWhere((TimerEntry et) => et.projectID == t.projectID && et.description == t.description);
                  if(match != null) {
                    // if it does match, just extend its end time
                    currentDay.timers = currentDay.timers.map((TimerEntry et) {
                      if(et.id == match.id) {
                        return TimerEntry.clone(
                          match,
                          endTime: match.endTime.add((t.endTime.difference(t.startTime)))
                        );
                      }
                      else {
                        return et;
                      }
                    }).toList();
                  }
                  else {
                    currentDay.timers.add(t);
                  }

                  return days;
                })
                .expand((DayGroup day) => day.timers)
                .toList();
          }
          else {
            filteredTimers = 
              timers.state.timers
                .where((t) => t.endTime != null)
                .where((t) => selectedProjects.any((p) => p?.id == t.projectID))
                .toList();
          }*/

          List<List<String>> data = <List<String>>[headers]
          .followedBy(
            timers.state.timers
              .where((t) => t.endTime != null)
              .where((t) => selectedProjects.any((p) => p?.id == t.projectID))
              .map(
                (timer) {
                  List<String> row = [];
                  if(settingsBloc.state.exportIncludeProject) {
                    row.add(projects.getProjectByID(timer.projectID)?.name ?? "");
                  }
                  if(settingsBloc.state.exportIncludeDescription) {
                    row.add(timer.description ?? "");
                  }
                  if(settingsBloc.state.exportIncludeStartTime) {
                    row.add(timer.startTime.toUtc().toIso8601String());
                  }
                  if(settingsBloc.state.exportIncludeEndTime) {
                    row.add(timer.endTime.toUtc().toIso8601String());
                  }
                  if(settingsBloc.state.exportIncludeDurationHours) {
                    row.add((timer.endTime.difference(timer.startTime).inSeconds.toDouble() / 3600.0).toStringAsFixed(4));
                  }
                  return row;
                }
              )
          ).toList();
          String csv = ListToCsvConverter().convert(data);

          Directory directory;
          if (Platform.isAndroid) {
            directory = await getExternalStorageDirectory();
          }
          else {
            directory = await getApplicationDocumentsDirectory();
          }
          final String localPath = '${directory.path}/timecop.csv';
          File file = File(localPath);
          await file.writeAsString(csv, flush: true);
          await FlutterShare.shareFile(title: L10N.of(context).tr.timeCopEntries(_dateFormat.format(DateTime.now())), filePath: localPath);
        }
      ),
    );
  }
}
