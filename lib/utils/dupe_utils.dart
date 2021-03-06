import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';

class DupeUtils {
  DupeUtils._();
  static final DupeUtils services = DupeUtils._();

  getNotificationTimeAndScheduleNotification() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool notifyFive =
        prefs.getBool('nFive') != null ? prefs.getBool('nFive') : true;
    bool notifySix =
        prefs.getBool('nSix') != null ? prefs.getBool('nSix') : true;

    DBProvider.db.getNotificationTime().then((value) {
      if (value.length > 5 && notifyFive) {
        _createScheduledNotification(
          value[5],
          5,
          'Ready For Back to Back Dupe Sale',
          'Your dupe sale count for last 30 hours is now 5. Go, Grab some \$GTA.',
        );
      } else if (value.length <= 5) {
        cancelScheduledNotification(5);
      }
      if (value.length > 6 && notifySix) {
        _createScheduledNotification(
          value[6],
          6,
          'Dupe Sale Cooldown Achieved',
          'Your dupe sale count for last 30 hours is now below 7. You can start selling.',
        );
      } else if (value.length <= 6) {
        cancelScheduledNotification(6);
      }
    });
  }

  _createScheduledNotification(
      int time, int id, String title, String body) async {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        new FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid;
    var initializationSettingsIOS;
    var initializationSettings;
    initializationSettingsAndroid =
        new AndroidInitializationSettings('app_icon');
    initializationSettingsIOS = new IOSInitializationSettings(
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );
    initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    FlutterLocalNotificationsPlugin().initialize(
      initializationSettings,
      onSelectNotification: _onSelectNotification,
    );

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'GENERAL',
      'Dupe Notifications',
      'This channel will provide notification when you are below your sale limit and you can do dupe sale again.',
      importance: Importance.High,
      priority: Priority.High,
      enableVibration: true,
      playSound: true,
      color: Colors.blue,
      channelShowBadge: true,
      styleInformation: BigTextStyleInformation(''),
      ticker: 'Dupe Notifications',
    );
    var iOSChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        id,
        title,
        body,
        DateTime.fromMillisecondsSinceEpoch(time).add(Duration(hours: 30)),
        //DateTime.now().add(Duration(seconds: 10)),
        platformChannelSpecifics);
  }

  Future _onSelectNotification(String payload) async {
    //
  }
  Future _onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    //
  }

  cancelScheduledNotification(int id) {
    FlutterLocalNotificationsPlugin().cancel(id);
  }

  Future<bool> checkStoragePermission(BuildContext context) async {
    bool permission = false;
    var status = await Permission.storage.status;
    if (status.isUndetermined || status == PermissionStatus.denied) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
      ].request();
      if (statuses[Permission.storage] == PermissionStatus.granted)
        permission = true;
      else if (statuses[Permission.storage] == PermissionStatus.denied) {
        Scaffold.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission Denied!'),
          ),
        );
      }
    } else if (status == PermissionStatus.permanentlyDenied) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Please allow STORAGE permission from device settings.'),
        ),
      );
    } else {
      permission = true;
    }

    return permission;
  }

  Future<bool> createBackup() async {
    bool status = false;
    final databasePath = await getDatabasesPath();
    final sourcePath = join(databasePath, 'dupeboard.db');
    File sourceFile = File(sourcePath);
    List content = await sourceFile.readAsBytes();

    final targetDir = await getExternalStorageDirectory();
    final rootDir = targetDir.path.startsWith('/storage/emulated')
        ? targetDir.path.substring(1, 19)
        : targetDir.path.substring(1, 18);

    final now = DateTime.now();
    String fileSuffix = DateFormat("yMMddHHmm").format(now);
    await new Directory('$rootDir/Dupeboard').create(recursive: true);
    final targetPath =
        join('$rootDir/Dupeboard', 'BACKUP_$fileSuffix.dupeboard.bin');
    File targetFile = File(targetPath);
    await targetFile.writeAsBytes(content, flush: true).then((value) {
      status = value.path.isNotEmpty;
    });
    return status;
  }

  restoreBackup() async {
    bool status = false;
    File backupFile = await FilePicker.getFile(
        type: FileType.custom, allowedExtensions: ['bin']);
    if (backupFile != null) {
      File sourceFile = File(backupFile.path);
      List content = await sourceFile.readAsBytes();

      final targetDir = await getDatabasesPath();
      final targetPath = join(targetDir, 'dupeboard.db');
      File targetFile = File(targetPath);
      await targetFile.writeAsBytes(content, flush: true).then((value) {
        status = value.path.isNotEmpty;
      });
    }

    return status;
  }

  checkForUpdates() async {
    var githubAPI = 'https://api.github.com/repos/arnobk/dupeboard/releases';

    var releaseInfo = await http.get(githubAPI);
    if (releaseInfo.statusCode == 200) {
      if (json.decode(releaseInfo.body).toString() != '[]') {
        return json.decode(releaseInfo.body)[0]['tag_name'];
      } else {
        return 'N/A'; // No Release Found
      }
    } else {
      throw Exception('Unable to check for updates.');
    }
  }
}
