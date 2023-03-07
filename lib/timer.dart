import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
/// The TimerApp widget is a stateful widget that manages the main timer functionality and communicates with a local database.
/// @param {Database} database: The local database used to store and retrieve timer data.

class TimerApp extends StatefulWidget {
  
  final Database database;

  const TimerApp({Key? key, required this.database}) : super(key: key);

  @override
  _TimerAppState createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> with WidgetsBindingObserver {
 double _percentageDifference = 0.0;
List<Map<String, dynamic>> yearData = [];
  late Timer _timer;
  int _secondsElapsed = 0;
  late DateTime _currentDate;

   /// Getter method for the local database object passed to the TimerApp widget.
   /// @returns {Database}: The local database object.

  Database get database => widget.database;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
  // Initialize instance variables and start timer.

    _currentDate = DateTime.now();
    _getSecondsElapsed();
    _startTimer();
    displayAllData();
_loadYearData();
  
  }




  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance?.removeObserver(this);
    _stopTimer();
  }


 /// Method to start the timer that updates the _secondsElapsed variable every second.

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsElapsed++;
        _updateSecondsElapsed(_currentDate, _secondsElapsed);
        displayAllData();
      });
    });
  }
 /// Method to stop the timer when the TimerApp widget is disposed.
  void _stopTimer() {
    _timer.cancel();
  }


   /// Method to retrieve the seconds elapsed from the local database for the current day.

  Future<void> _getSecondsElapsed() async {
    final List<Map<String, dynamic>> maps = await database.query('timer',
        where: 'date = ?',
        whereArgs: [_currentDate.toString().substring(0, 10)]);
    if (maps.isNotEmpty) {
      setState(() {
        _secondsElapsed = maps.first['seconds_elapsed'] as int;
      });
    }
  }


  /// Method to update the seconds elapsed in the local database for the current day.
  /// If a row already exists for the current day, update that row with the new value.
  /// Otherwise, insert a new row for the current day with the new value.
  /// @param {DateTime} date: The current date.
  /// @param {int} secondsElapsed: The number of seconds elapsed for the current day.



  Future<void> _updateSecondsElapsed(DateTime date, int secondsElapsed) async {
    // Ensure that the database is created
    await database.transaction((txn) async {
      await txn.execute(
        'CREATE TABLE IF NOT EXISTS timer(id INTEGER PRIMARY KEY,date TEXT, seconds_elapsed INTEGER)',
      );
    });
    // Check if there is an existing row in the database for current date
    final count = Sqflite.firstIntValue(await database.rawQuery(
        'SELECT COUNT(*) FROM timer WHERE date = ?',
        [date.toString().substring(0, 10)]));
    if (count == 0) {
      // If there is no existing row, insert the initial value of the timer for current date
      await database.insert('timer', {
        'date': date.toString().substring(0, 10),
        'seconds_elapsed': secondsElapsed
      });
    } else {
      // Otherwise, update the existing row with the new value of the timer for current date
      await database.update(
        'timer',
        {'seconds_elapsed': secondsElapsed},
        where: 'date = ?',
        whereArgs: [date.toString().substring(0, 10)],
      );
    }
  }

/// Fetches the data for the current week from the 'timer' table of the database
///
/// This function uses the current date to determine the first and last day of the current week,
/// then queries the 'timer' table for data between those dates. The data is aggregated by week
/// using the strftime function and sorted in descending order by date. The resulting list of maps
/// contains the total number of seconds elapsed for each week, as well as the date of the last day
/// of the week.
///
/// Returns a [Future] that resolves to a list of maps, where each map has the following keys:
///
/// - 'total_seconds': the total number of seconds elapsed during the week
/// - 'date': the date of the last day of the week, in the format 'yyyy-mm-dd



  Future<List<Map<String, dynamic>>> _getWeekData() async {
final dateToday = DateTime.now();
final firstDayOfWeek = dateToday.subtract(Duration(days: dateToday.weekday - 1));
final lastDayOfWeek = firstDayOfWeek.add(Duration(days: 6));

final db = await widget.database;
final List<Map<String, dynamic>> maps = await db.rawQuery(
  'SELECT SUM(seconds_elapsed) AS total_seconds, date FROM timer WHERE date BETWEEN ? AND ? GROUP BY strftime("%W", date) ORDER BY date DESC',
  [firstDayOfWeek.subtract(Duration(days: 7)).toString().substring(0, 10), lastDayOfWeek.toString().substring(0, 10)],
  
  
);


  
  
return maps;

}
// This method returns a Future that will eventually resolve to a double representing the percentage difference between
// the number of seconds elapsed during the current week and the previous week.

Future<double> getWeeklyPercentageDifference() async {
  // Get today's date and calculate the first day of the current week
  final now = DateTime.now();
  final firstDayOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

  // Calculate the first day of the previous week
  final firstDayOfPreviousWeek = firstDayOfWeek.subtract(Duration(days: 7));

  // Query the database to get the seconds elapsed for the current week
  final currentWeekSecondsElapsed = await _getSecondsElapsedInRange(firstDayOfWeek, now) as int;

  // Query the database to get the seconds elapsed for the previous week
  final previousWeekSecondsElapsed = await _getSecondsElapsedInRange(firstDayOfPreviousWeek, firstDayOfWeek.subtract(Duration(days: 1))) as int;

  // Calculate the percentage difference between the current week and the previous week
  double percentageDifference = 0;
  if (previousWeekSecondsElapsed != 0) {
    percentageDifference = (currentWeekSecondsElapsed - previousWeekSecondsElapsed) / previousWeekSecondsElapsed * 100;
  }

  // Return the percentage difference
  return percentageDifference;
}

// This private method queries the database to get the total number of seconds elapsed between the start and end dates.
// It returns a Future that will eventually resolve to an Object representing the total seconds elapsed (or 0 if no rows were returned).

Future<Object> _getSecondsElapsedInRange(DateTime startDate, DateTime endDate) async {
  // Query the database to get the total seconds elapsed in the specified date range
  final result = await database.rawQuery(
    'SELECT SUM(seconds_elapsed) FROM timer WHERE date BETWEEN ? AND ?',
    [startDate.toString().substring(0, 10), endDate.toString().substring(0, 10)]
  );
  // Return the total seconds elapsed (or 0 if no rows were returned)
  return result.first.values.first ?? 0;
}









Future<List<Map<String, dynamic>>> _getYearData() async {
  final dateToday = DateTime.now();
  final currentYear = dateToday.year;
  final previousYear = currentYear - 1;

  final db = await widget.database;
  final List<Map<String, dynamic>> maps = await db.rawQuery(
    'SELECT SUM(seconds_elapsed) AS total_seconds, strftime("%Y", date) AS year FROM timer WHERE strftime("%Y", date) IN (?, ?) GROUP BY year ORDER BY year DESC',
    [currentYear.toString(), previousYear.toString()],
  );

  return maps;
}





Future<List<Map<String, dynamic>>> _getMonthData() async {
  final dateToday = DateTime.now();
  final currentMonth = dateToday.month;
  final currentYear = dateToday.year;

  final db = await widget.database;
  final List<Map<String, dynamic>> maps = await db.rawQuery(
    'SELECT SUM(seconds_elapsed) AS total_seconds, strftime("%Y-%m", date) AS month FROM timer WHERE strftime("%m", date) >= ? AND strftime("%Y", date) = ? GROUP BY month ORDER BY month DESC',
    [(currentMonth - 3).toString().padLeft(2, '0'), currentYear.toString()]
  );
  return maps;
}





  Future<void> displayAllData() async {
    final List<Map<String, dynamic>> maps = await database.query('timer');
    if (maps.isNotEmpty) {
      maps.forEach((map) {
        print(
            'id: ${map['id']}, date: ${map['date']}, seconds elapsed: ${map['seconds_elapsed']}');
      });
    } else {
      print('No data in table');
    }
    setState(() {});
  }

 // This method returns a string representing the number of hours, minutes, and seconds elapsed e.g converts timer seconds to 1Hr 2Min 1sec format.
String getTimerString() {
  // Calculate the number of hours, minutes, and seconds
  final int hours = _secondsElapsed ~/ 3600;
  final int minutes = (_secondsElapsed % 3600) ~/ 60;
  final int seconds = _secondsElapsed % 60;

  // Create strings representing the hours, minutes, and seconds
  final String hourString = hours > 0 ? '$hours hour ' : '';
  final String minuteString =
      minutes > 0 || hours > 0 ? '$minutes minute ' : '';
  final String secondString = '$seconds second';

  // Combine the strings and return the result
  return '$hourString$minuteString$secondString';
}

   Future<void> _loadYearData() async {
    final data = await _getYearData();
    setState(() {
      yearData = data;
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Timer App'),
    ),
    body: SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'This week and previous week',
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getWeekData(),
            builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (BuildContext context, int index) {
                    final date = DateTime.parse(data[index]['date']);
                    final totalSeconds = data[index]['total_seconds'] as int;
                    final duration = Duration(seconds: totalSeconds);
                    final weekText = index == 0 ? 'Current Week' : 'Previous Week';
                    return ListTile(
                      title: Text('$weekText (${DateFormat.yMd().format(date.subtract(Duration(days: date.weekday - 1)))} - ${DateFormat.yMd().format(date.add(Duration(days: 7 - date.weekday)))})'),
                      subtitle: Text('Total time: ${duration.inHours} hours, ${(duration.inMinutes % 60).toString().padLeft(2, '0')} minutes, ${(duration.inSeconds % 60).toString().padLeft(2, '0')} seconds'),
          
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              }
              return const CircularProgressIndicator();
            },
          ),



          const SizedBox(height: 16),
          Text(
            'This month and previous 3 months',
            style: Theme.of(context).textTheme.headline6,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getMonthData(),
            builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
              if (snapshot.hasData) {
                final data = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (BuildContext context, int index) {
                    final month = DateTime.parse('${data[index]['month']}-01');
                    final totalSeconds = data[index]['total_seconds'] as int;
                    final duration = Duration(seconds: totalSeconds);
                    final monthText = index == 0 ? 'Current Month' : 'Previous Month';
                    return ListTile(
                      title: Text('$monthText (${DateFormat.yMMM().format(month)})'),
                      subtitle: Text('Total time: ${duration.inHours} hours, ${(duration.inMinutes % 60).toString().padLeft(2, '0')} minutes, ${(duration.inSeconds % 60).toString().padLeft(2, '0')} seconds'),
           
                    );
                  },
                );
              } else if (snapshot.hasError) {
                return Text('${snapshot.error}');
              }
              return const CircularProgressIndicator();
            },
          ),
          
           const SizedBox(height: 16),
 
     FutureBuilder<List<Map<String, dynamic>>>(
    future: _getYearData(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final yearData = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int index = 0; index < yearData!.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildYearTile(yearData[index]),
              ),
          ],
        );
      } else if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      } else {
        return Center(child: CircularProgressIndicator());
      }
    },
        
  ),
  const SizedBox(height: 19,),
  
 FutureBuilder<double>(
          future: getWeeklyPercentageDifference(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              final percentageDifference = snapshot.data!;
              return Text(
                'Weekly percentage difference: ${percentageDifference.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 16.0),
              );
            }
          },
        ),
      
    
  
        ]
      )
    )
    );
}

 Widget _buildYearTile(Map<String, dynamic> yearData) {
  final year = yearData['year'];
  final totalSeconds = yearData['total_seconds'];
  final duration = Duration(seconds: totalSeconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$year usage:', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 4.0),
      Text('$hours hours, $minutes minutes, $seconds seconds'),
    ],
  );
}
@override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      final newDate = DateTime.now();
      if (_currentDate.day != newDate.day) {
        // New date, reset seconds elapsed and update _currentDate
        _updateSecondsElapsed(_currentDate, _secondsElapsed);
        setState(() {
          _currentDate = newDate;
          _secondsElapsed = 0;
        });
      }
      _startTimer();
    }
  }
}
       




 