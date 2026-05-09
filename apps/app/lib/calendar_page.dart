import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime focusedDay = DateTime.now();
  DateTime? selectedDay;
  Map<String, List> events = {};

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    final response =
        await http.get(Uri.parse('http://10.0.2.2:3000/schedules'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      Map<String, List> temp = {};

      for (var item in data) {
        final date = item['data'];
        temp.putIfAbsent(date, () => []);
        temp[date]!.add(item);
      }

      setState(() {
        events = temp;
      });
    }
  }

  List getEventsForDay(DateTime day) {
    final key = day.toString().split(' ')[0];
    return events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = getEventsForDay(selectedDay ?? focusedDay);

    return Scaffold(
      appBar: AppBar(title: Text("Calendário")),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: focusedDay,
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                selectedDay = selected;
                focusedDay = focused;
              });
            },
            eventLoader: getEventsForDay,
          ),
          Expanded(
            child: ListView(
              children: selectedEvents.map<Widget>((item) {
                return ListTile(
                  title: Text(item['projeto']),
                  subtitle: Text(
                      "${item['hora_inicio']} - ${item['hora_fim']}"),
                  trailing:
                      Text("R\$ ${item['valor_total']}"),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}