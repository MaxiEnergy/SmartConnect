import 'dart:async'; // Import the dart:async library
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0B0C10), // Устанавливаем цвет фона
      ),
      home: FindDevicesScreen(),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Поиск устройств'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (c, snapshot) {
            final devices = snapshot.data!.where((result) =>
                result.device.name == 'SmartLight' ||
                result.device.name == 'SmartPulse');

            return ListView.builder(
              itemCount: devices.length,
              itemBuilder: (c, index) {
                final device = devices.elementAt(index);
                return ListTile(
                  title: Center(
                    child: Container(
                      width: 364,
                      height: 156,
                      decoration: BoxDecoration(
                        color: Color(0xFF1F2833),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          device.device.name,
                          style:
                              TextStyle(color: Color(0xFFC5C6C7), fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    if (device.device.name == 'SmartLight') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            DeviceScreen(device: device.device),
                      ));
                    } else if (device.device.name == 'SmartPulse') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            SmartPulseDeviceScreen(device: device.device),
                      ));
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Color(0xFF45A29E),
            );
          } else {
            return FloatingActionButton(
              child: Icon(Icons.search),
              onPressed: () =>
                  FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
            );
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  DeviceScreen({required this.device});

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

// New SmartPulseDeviceScreen class starts here

class SmartPulseDeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  SmartPulseDeviceScreen({required this.device});

  @override
  _SmartPulseDeviceScreenState createState() => _SmartPulseDeviceScreenState();
}

class _SmartPulseDeviceScreenState extends State<SmartPulseDeviceScreen> {
  bool isDeviceConnected = false;
  int batteryLevel = 0;
  int pulseRate = 0;
  TextEditingController textController = TextEditingController();
  StreamSubscription<int>? _pulserateSubscription;
  StreamSubscription<int>? _batterylevelSubscription;

  @override
  void initState() {
    super.initState();
    connectToDevice();
    _pulserateSubscription =
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
      List<int> value = await readCharacteristic(
          widget.device, Guid('0000fef4-0000-1000-8000-00805f9b34fb'));
      int pulseRate = (value[0]);
      return pulseRate;
    }).listen((pulseRate) {
      setState(() {
        this.pulseRate = pulseRate;
      });
    });
    _batterylevelSubscription =
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
      List<int> value = await readCharacteristic(
          widget.device, Guid('0000fef5-0000-1000-8000-00805f9b34fb'));
      int batteryLevel = (value[0]);
      return batteryLevel;
    }).listen((batteryLevel) {
      setState(() {
        this.batteryLevel = batteryLevel;
      });
    });
  }

  @override
  void dispose() {
    _pulserateSubscription?.cancel();
    _batterylevelSubscription?.cancel();
    super.dispose();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isDeviceConnected = true;
      });
      // Set up notifications for characteristics here
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        isDeviceConnected = false;
      });
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  Future<List<int>> readCharacteristic(
      BluetoothDevice device, Guid characteristicGuid) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          List<int> value = await characteristic.read();
          return value;
        }
      }
    }
    throw Exception('Characteristic not found: $characteristicGuid');
  }

  Future<void> writeCharacteristic(
      BluetoothDevice device, Guid characteristicGuid, List<int> value) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          await characteristic.write(value);
          return;
        }
      }
    }
  }

  Future<void> sendTextMessage() async {
    String text = textController.text;
    List<int> value = utf8.encode(text); // Кодируем текст в формат UTF-8
    try {
      await writeCharacteristic(
        widget.device,
        Guid('0000fef3-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Управление SmartPulse'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Пульс: $pulseRate', style: TextStyle(fontSize: 24)),
            Text('Заряд аккумулятора: $batteryLevel%',
                style: TextStyle(fontSize: 24)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: textController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Пароль для аутентификации',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                sendTextMessage();
              },
              child: Text('Подтвердить'),
            ),
            ElevatedButton(
              onPressed: isDeviceConnected ? disconnectDevice : null,
              child: Text('Отключиться от устройства'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool isDeviceConnected = false;
  bool lightMode = false;
  int lightIntensity = 0;
  bool isTransparent = true;
  TextEditingController textController = TextEditingController();
  bool inAutoMode = true;

  StreamSubscription<int>? _lightIntensitySubscription;

  @override
  void initState() {
    super.initState();
    connectToDevice();

    // Add the listener for the characteristic at an interval
    _lightIntensitySubscription =
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
      List<int> value = await readCharacteristic(
          widget.device, Guid('00002a31-0000-1000-8000-00805f9b34fb'));
      int lightIntensity = (value[0]);
      return lightIntensity;
    }).listen((lightIntensity) {
      setState(() {
        this.lightIntensity = lightIntensity;
      });
    });
  }

  @override
  void dispose() {
    _lightIntensitySubscription?.cancel();
    super.dispose();
  }

  Future<void> connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() {
        isDeviceConnected = true;
      });
    } catch (e) {
      print("Error connecting to device: $e");
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await widget.device.disconnect();
      setState(() {
        isDeviceConnected = false;
      });
    } catch (e) {
      print("Error disconnecting from device: $e");
    }
  }

  Future<void> sendLightMode() async {
    List<int> value = [lightMode ? 1 : 0];
    try {
      await writeCharacteristic(
        widget.device,
        Guid('00002a56-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e");
    }
  }

  Future<List<int>> readCharacteristic(
      BluetoothDevice device, Guid characteristicGuid) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          List<int> value = await characteristic.read();
          return value;
        }
      }
    }
    throw Exception('Characteristic not found: $characteristicGuid');
  }

  Future<void> sendLightEffect(int effect) async {
    List<int> value = [effect];
    try {
      await writeCharacteristic(
        widget.device,
        Guid('00002a59-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e");
    }
  }

  Future<void> sendTransparentMode() async {
    List<int> value = [isTransparent ? 1 : 0];
    try {
      await writeCharacteristic(
        widget.device,
        Guid('00002a60-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e");
    }
  }

  Future<void> sendTextMessage() async {
    String text = textController.text;
    List<int> value = utf8.encode(text); // Кодируем текст в формат UTF-8
    try {
      await writeCharacteristic(
        widget.device,
        Guid('00002a61-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e");
    }
  }

  Future<void> writeCharacteristic(
      BluetoothDevice device, Guid characteristicGuid, List<int> value) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          await characteristic.write(value);
          return;
        }
      }
    }
  } // Остальной код остается без изменений...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Управление SmartLight'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (isDeviceConnected)
              Column(
                children: <Widget>[
                  Container(
                    width: 380,
                    height:
                        160, // Увеличиваем высоту для учета вертикального расстояния
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(
                          20.0), // Задаем радиус скругления углов
                    ),
                    child: Column(
                      children: [
                        Text('Автоматический режим',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        SizedBox(height: 26),
                        if (inAutoMode) //
                          Column(children: [
                            Text('Уровень освещенности: $lightIntensity',
                                style: TextStyle(fontSize: 20)),
                            SizedBox(height: 20.8), //
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  inAutoMode = false;
                                  lightMode = false;
                                });
                                sendLightMode();
                              },
                              child: Text('Переключить режим',
                                  style: TextStyle(
                                      color: Color(0xFFC5C6C7), fontSize: 20)),
                              style: ElevatedButton.styleFrom(
                                  primary: Color(
                                      0xFF45A29E) // Устанавливаем цвет кнопки
                                  ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                  SizedBox(height: 40), //
                  Container(
                    width: 380,
                    height:
                        320, // Увеличиваем высоту для учета вертикального расстояния
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(
                          20.0), // Задаем радиус скругления углов
                    ),

                    child: Column(
                      children: [
                        Text('Ручной режим',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        if (!inAutoMode)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(1);
                                    },
                                    child: Text('Белый свет',
                                        style: TextStyle(
                                            color: Color(0xFFC5C6C7))),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(
                                            0xFF45A29E) //Устанавливаем цвет кнопки
                                        ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(2);
                                    },
                                    child: Text('Градиент',
                                        style: TextStyle(
                                            color: Color(0xFFC5C6C7))),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(
                                            0xFF45A29E) // Устанавливаем цвет кнопки
                                        ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(0);
                                    },
                                    child: Text('Выключить',
                                        style: TextStyle(
                                            color: Color(0xFFC5C6C7))),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(
                                            0xFF45A29E) // Устанавливаем цвет кнопки
                                        ),
                                  ),
                                ],
                              ),
                              Text('Прозрачный/матовый',
                                  style: TextStyle(fontSize: 20)),
                              Switch(
                                value: isTransparent,
                                onChanged: (value) {
                                  setState(() {
                                    isTransparent = value;
                                  });
                                  sendTransparentMode();
                                },
                              ),
                              TextField(
                                controller: textController,
                                decoration: InputDecoration(
                                    labelText: 'Введите сообщение'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  sendTextMessage();
                                },
                                child: Text('Отправить сообщение',
                                    style: TextStyle(color: Color(0xFFC5C6C7))),
                                style: ElevatedButton.styleFrom(
                                    primary: Color(
                                        0xFF45A29E) // Устанавливаем цвет кнопки
                                    ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    inAutoMode = true;
                                    lightMode = true;
                                  });
                                  sendLightMode();
                                },
                                style: ElevatedButton.styleFrom(
                                    primary: Color(
                                        0xFF45A29E) // Устанавливаем цвет кнопки
                                    ),
                                child: Text('Переключить режим',
                                    style: TextStyle(
                                        color: Color(0xFFC5C6C7),
                                        fontSize: 20)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                      height: 40), // Дополнительное вертикальное расстояние
                  Container(
                    width: 380,
                    height:
                        160, // Увеличиваем высоту для учета вертикального расстояния
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(
                          20.0), // Задаем радиус скругления углов
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Управление соединением',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        SizedBox(
                            height:
                                40), // Дополнительное вертикальное расстояние
                        Container(
                          width: 312,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: disconnectDevice,
                            style: ElevatedButton.styleFrom(
                                primary: Color(
                                    0xFF45A29E) // Устанавливаем цвет кнопки
                                ),
                            child: Text('Отключиться от устройства',
                                style: TextStyle(
                                    color: Color(0xFFC5C6C7), fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            if (!isDeviceConnected)
              Text('Подключение к устройству...',
                  style: TextStyle(color: Color(0xFFC5C6C7), fontSize: 24)),
          ],
        ),
      ),
    );
  }
  // Остальной код остается без изменений...
}
