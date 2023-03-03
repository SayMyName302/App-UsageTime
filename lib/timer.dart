import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

class TimerApp extends StatefulWidget {
  
  final Database database;

  const TimerApp({Key? key, required this.database}) : super(key: key);

  @override
  _TimerAppState createState() => _TimerAppState();
}

class _TimerAppState extends State<TimerApp> with WidgetsBindingObserver {
List<Map<String, dynamic>> yearData = [];
  late Timer _timer;
  int _secondsElapsed = 0;
  late DateTime _currentDate;

  Database get database => widget.database;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
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

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsElapsed++;
        _updateSecondsElapsed(_currentDate, _secondsElapsed);
        displayAllData();
      });
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

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

  String getTimerString() {
    final int hours = _secondsElapsed ~/ 3600;
    final int minutes = (_secondsElapsed % 3600) ~/ 60;
    final int seconds = _secondsElapsed % 60;

    final String hourString = hours > 0 ? '$hours hour ' : '';
    final String minuteString =
        minutes > 0 || hours > 0 ? '$minutes minute ' : '';
    final String secondString = '$seconds second';

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
        
  )
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
       




 