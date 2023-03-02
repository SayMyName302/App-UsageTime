import 'package:error/timer.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'timer_database.db'),
    onCreate: (db, version) {
      db.execute(
     'CREATE TABLE IF NOT EXISTS timer(id INTEGER PRIMARY KEY,date TEXT, seconds_elapsed INTEGER, week_usagetime INTEGER, week_startdate TEXT, week_enddate TEXT)',
      );
    
    },
    version: 2,
  );
  runApp(MaterialApp(
    initialRoute: "/HomeScreen",
    routes: {
      "/": (context) => TimerApp(database: database),
    },
  ));
}


class bsdk extends StatelessWidget {
  const bsdk({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.light,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.light,
      ),
    );
  }
}
