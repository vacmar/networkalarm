import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:web_socket_channel/web_socket_channel.dart'; // Works for both web & mobile
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Network Alarm',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SensorPage(),
    );
  }
}

class SensorPage extends StatefulWidget {
  @override
  _SensorPageState createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  final String serverUrl = "http://10.0.8.107:3000";  // Change this to match backend IP
  final String wsUrl = "ws://10.0.8.107:3000";  // WebSocket URL


  WebSocketChannel? channel;
  String sensorData = "Waiting for data...";
  String selectedSensor = "NONE"; // Ensure it matches one of the dropdown options

  final List<String> sensorOptions = [
    "NONE",
    "DHT-22: [Temperature]",
    "FIRE SENSOR: [Fire Detection]",
    "MQ-2: [Smoke]"
  ];

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      // WebSocket only for mobile/desktop
      channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      channel!.stream.listen((message) {
        final data = jsonDecode(message);
        if (data['type'] == "SENSOR_UPDATE" || data['type'] == "SENSOR_DATA") {
          setState(() {
            sensorData = "Sensor: ${data['sensor']} | Value: ${data['value'] ?? 'N/A'}";
          });
        }
      }, onError: (error) {
        print("WebSocket error: $error");
      });
    }

    fetchSensor();
  }

  Future<void> fetchSensor() async {
    try {
      final response = await http.get(Uri.parse("$serverUrl/get-sensor"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (sensorOptions.contains(data['sensor'])) {
          setState(() {
            selectedSensor = data['sensor'];
          });
        }
      }
    } catch (e) {
      print("Error fetching sensor: $e");
    }
  }

  Future<void> setSensor(String sensor) async {
    setState(() {
      selectedSensor = sensor; // ✅ Updates immediately when user selects
    });

    try {
      await http.post(
        Uri.parse("$serverUrl/set-sensor"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sensor": sensor}),
      );
    } catch (e) {
      print("Error setting sensor: $e");
    }
  }

  Future<void> sendSensorData(String sensor, String value) async {
    try {
      await http.post(
        Uri.parse("$serverUrl/sensor-data"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"sensor": sensor, "value": value}),
      );
    } catch (e) {
      print("Error sending sensor data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Network Alarm")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(sensorData, style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedSensor, // ✅ Always reflects the current state
              items: sensorOptions.map((sensor) {
                return DropdownMenuItem(value: sensor, child: Text(sensor));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setSensor(value);
                }
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => sendSensorData(selectedSensor, "25°C"),
              child: Text("Send Test Data"),
            ),
          ],
        ),
      ),
    );
  }
}
