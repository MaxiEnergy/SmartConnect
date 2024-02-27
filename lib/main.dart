import 'dart:async'; // Библиотека для работы с асинхронными операциями
import 'dart:convert'; // Библиотека для работы с кодированием и декодированием JSON
import 'package:flutter/material.dart'; // Основные компоненты Flutter
import 'package:flutter_blue/flutter_blue.dart'; // flutter_blue для работы с Bluetooth

// Главная функция, точка входа в приложение
void main() { 
  runApp(MyApp()); // Запускаем приложение, используя класс MyApp
}

// Определяем класс MyApp, наследуемый от StatelessWidget
class MyApp extends StatelessWidget {
  @override
// Переопределяем метод build, который строит UI приложения 
  Widget build(BuildContext context) {
    return MaterialApp( // Возвращаем MaterialApp, основной виджет приложения
      theme: ThemeData.dark().copyWith( // Устанавливаем темную тему
        scaffoldBackgroundColor: Color(0xFF0B0C10), 
      ),
      // Начальный экран приложения (экран поиска устройств Bluetooth)
      home: FindDevicesScreen(), 
    );
  }
}

// Определяем класс FindDevicesScreen (экран для поиска Bluetooth устройств)
class FindDevicesScreen extends StatelessWidget { 
  @override
  Widget build(BuildContext context) { // Переопределение метода build для построения UI
    return Scaffold( // Виджет Scaffold предоставляет базовую структуру экрана
      appBar: AppBar( // AppBar для отображения заголовка экрана
        title: Text('Поиск устройств'), // Устанавливаем текст заголовка
      ),
      body: RefreshIndicator( // RefreshIndicator для обновления содержимого
        onRefresh: () => // Начало сканирования устройств Bluetooth
            // Асинхронное взаимодействие с потоком результатов сканирования
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)), 
        child: StreamBuilder<List<ScanResult>>(
          // Подписка на поток результатов сканирования Bluetooth устройств
          stream: FlutterBlue.instance.scanResults, 
          initialData: [], // Начальные данные для StreamBuilder - пустой список
          builder: (c, snapshot) {
            // Получаем устройства, фильтруя по имени
            final devices = snapshot.data!.where((result) => 
                result.device.name == 'SmartLight' ||
                result.device.name == 'SmartPulse');
            return ListView.builder( // Создаем виджет для динамического списка устройств
              itemCount: devices.length,
              itemBuilder: (c, index) {
                // Получаем устройство по индексу из списка найденных устройств
                final device = devices.elementAt(index); 
                return ListTile( // Создаем виджет ListTile для каждого устройства
                  title: Center( // Заголовок содержит контейнер с информацией об устройстве
                    child: Container( // Задаем размеры контейнера
                      width: 364,
                      height: 156,
                      decoration: BoxDecoration( // Стиль контейнера
                        color: Color(0xFF1F2833),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center( // Внутри контейнера отображаем имя устройства
                        child: Text(
                          device.device.name,
                          style: // Стиль текста: цвет и размер шрифта
                              TextStyle(color: Color(0xFFC5C6C7), fontSize: 30),
                        ),
                      ),
                    ),
                  ),
                  onTap: () { // Обработчик нажатия на элемент списка
                    if (device.device.name == 'SmartLight') { 
			// Осуществляем переход на соответствующий экран
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => // Переход на экран DeviceScreen
                            DeviceScreen(device: device.device),
                      ));
                    } else if (device.device.name == 'SmartPulse') {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => // Переход на экран SmartPulseDeviceScreen 
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
      floatingActionButton: StreamBuilder<bool>( // Виджет для кнопки процесса сканирования
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) { // Проверяем, идет ли сканирование в данный момент
            return FloatingActionButton( // Отображаем кнопку остановки сканирования
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Color(0xFF45A29E),
            );
          } else {
            return FloatingActionButton( // Отображаем кнопку для начала сканирования
              child: Icon(Icons.search),
              onPressed: () => // Начинаем сканирование с таймаутом в 4 секунды
                  FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
            );
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget { // Класс DeviceScreen для работы с SmartLight
  final BluetoothDevice device; // Поле для хранения экземпляра BluetoothDevice
  DeviceScreen({required this.device}); // Конструктор класса DeviceScreen
  @override // Переопределение метода createState для создания состояния виджета
  _DeviceScreenState createState() => _DeviceScreenState();
}
// Класс SmartPulseDeviceScreen для работы SmartPulse
class SmartPulseDeviceScreen extends StatefulWidget { 
  final BluetoothDevice device;
  SmartPulseDeviceScreen({required this.device});
  @override
  _SmartPulseDeviceScreenState createState() => _SmartPulseDeviceScreenState();
}

class _SmartPulseDeviceScreenState extends
State<SmartPulseDeviceScreen> {
  bool isDeviceConnected = false; // Флаг подключения к устройству
  int batteryLevel = 0; // Уровень заряда батареи устройства
  int pulseRate = 0; // Показатель пульса устройства
  // Управление текстовым полем
  TextEditingController textController = TextEditingController(); 
  // Подписка на поток данных о пульсе и уровне заряда батареи
  StreamSubscription<int>? _pulserateSubscription; 
  StreamSubscription<int>? _batterylevelSubscription;
  @override // Переопределение метода initState, вызываемого при создании состояния виджета
  void initState() {
    super.initState();
    connectToDevice(); // Вызов функции для подключения к устройству
    _pulserateSubscription = // Создание подписки на поток данных о пульсе
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
        // Чтение характеристики устройства (пульс)
        List<int> value = await readCharacteristic( 
            widget.device, Guid('0000fef4-0000-1000-8000-00805f9b34fb'));
          int pulseRate = (value[0]);
          return pulseRate;
    }).listen((pulseRate) {
      setState(() { // Обновление состояния виджета с новым значением пульса
        this.pulseRate = pulseRate;
      });
    });
    // Создание подписки на поток данных об уровне заряда батареи
    _batterylevelSubscription = 
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
        List<int> value = await readCharacteristic( // Чтение характеристики устройства
            widget.device, Guid('0000fef5-0000-1000-8000-00805f9b34fb'));
          int batteryLevel = (value[0]);
          return batteryLevel;
    }).listen((batteryLevel) {
      setState(() { // Обновление состояния виджета с новым значением уровня заряда батареи
        this.batteryLevel = batteryLevel;
      });
    });
  }
  @override // Переопределение метода dispose для очистки ресурсов
  void dispose() { // Отмена подписок на потоки данных о пульсе и уровне заряда батареи
    _pulserateSubscription?.cancel();
    _batterylevelSubscription?.cancel();
    super.dispose(); // Вызов метода dispose у родительского класса
  }

  Future<void> connectToDevice() async { // Асинхронный метод для подключения к устройству
    try {
      await widget.device.connect(); // Попытка подключения к устройству
      setState(() { // Обновление состояния: устройство подключено
        isDeviceConnected = true;
      });
    } catch (e) {
      print("Error connecting to device: $e"); // Вывод ошибки в случае неудачи подключения
    }
  }

  Future<void> disconnectDevice() async { // Асинхронный метод для отключения от устройства
    try {
      await widget.device.disconnect(); // Попытка отключения от устройства
      setState(() {
        isDeviceConnected = false; // Обновление состояния: устройство отключено
      });
    } catch (e) {
      print("Error disconnecting from device: $e"); // Вывод ошибки
    }
  }

  Future<List<int>> readCharacteristic( // Асинхронный метод для чтения характеристики
      BluetoothDevice device, Guid characteristicGuid) async {
    // Получение списка сервисов Bluetooth устройства
    List<BluetoothService> services = await device.discoverServices(); 
    for (BluetoothService service in services) { // Перебор сервисов и их характеристик
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        // Проверка соответствия UUID характеристики
        if (characteristic.uuid == characteristicGuid) { 
          List<int> value = await characteristic.read(); // Чтение значения характеристики
          return value;
        }
      }
    }
    // Вывод исключения, если характеристика не найдена
    throw Exception('Characteristic not found: $characteristicGuid'); 
  }

  Future<void> writeCharacteristic( // Асинхронный метод для записи в характеристику
      BluetoothDevice device, Guid characteristicGuid, List<int> value) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) { // Перебор сервисов и их характеристик
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          await characteristic.write(value); // Запись значения в характеристику
          return;
        }
      }
    }
  }

  Future<void> sendTextMessage() async { // Асинхронный метод для отправки сообщения
    String text = textController.text; // Получение текста из текстового поля
    List<int> value = utf8.encode(text); // Кодирование текста (UTF-8)
    try {
      await writeCharacteristic( // Попытка записи закодированного текста в характеристику
        widget.device,
        Guid('0000fef3-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e"); // Вывод ошибки
    }
  }
  @override // Переопределение метода build для построения UI виджета
  Widget build(BuildContext context) {
    return Scaffold( // Использование виджета Scaffold для создания базовой структуры экрана
      appBar: AppBar( // AppBar для отображения заголовка экрана
        title: Text('Управление SmartPulse'),
      ),
      body: Center( // Основное содержимое экрана, размещенное по центру
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Выравнивание элементов колонки
          children: <Widget>[
            // Отображение текущего пульса
            Text('Пульс: $pulseRate', style: TextStyle(fontSize: 24)), 
            // Отображение текущего уровня заряда батареи
            Text('Заряд аккумулятора: $batteryLevel%',
                style: TextStyle(fontSize: 24)), 
            Padding( // Поле для ввода текста
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: textController, // Контроллер для управления текстовым полем
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Пароль для аутентификации',
                ),
              ),
            ),
            ElevatedButton( // Кнопка для отправки текстового сообщения
              onPressed: () {
                sendTextMessage();
              },
              child: Text('Подтвердить'),
            ),
            ElevatedButton( // Кнопка для отключения от устройства
              onPressed: isDeviceConnected ? disconnectDevice : null,
              child: Text('Отключиться от устройства'),
            ),
          ],
        ),
      ),
    );
  }
}
// Класс _DeviceScreenState управляет состоянием DeviceScreen
class _DeviceScreenState extends State<DeviceScreen> { 
  bool isDeviceConnected = false; 
  bool lightMode = false; 
  int lightIntensity = 0; 
  bool isTransparent = true; 
  TextEditingController textController = TextEditingController(); 
  bool inAutoMode = true; 
  // Подписка на поток данных об интенсивности света
  StreamSubscription<int>? _lightIntensitySubscription; 
  @override // Инициализация состояния
  void initState() {
    super.initState();
    connectToDevice(); // Подключение к устройству при инициализации
    _lightIntensitySubscription = // Подписка на поток данных об интенсивности света
        Stream.periodic(Duration(seconds: 1)).asyncMap((_) async {
      List<int> value = await readCharacteristic( // Чтение характеристики устройства
          widget.device, Guid('00002a31-0000-1000-8000-00805f9b34fb'));
      int lightIntensity = (value[0]);
      return lightIntensity;
    }).listen((lightIntensity) {
      setState(() { // Обновление состояния виджета с новым значением интенсивности света
        this.lightIntensity = lightIntensity;
      });
    });
  }
  @override // Очистка ресурсов
  void dispose() {
    _lightIntensitySubscription?.cancel(); // Отмена подписки на поток данных
    super.dispose(); // Вызов метода dispose у родительского класса
  }

  Future<void> connectToDevice() async { // Асинхронный метод для подключения к устройству
    try {
      await widget.device.connect(); // Попытка подключения к устройству
      setState(() {
        isDeviceConnected = true; // Обновление состояния: устройство подключено
      });
    } catch (e) {
      print("Error connecting to device: $e"); // Вывод ошибки в случае неудачи подключения
    }
  }

  Future<void> disconnectDevice() async { // Асинхронный метод для отключения от устройства
    try {
      await widget.device.disconnect(); // Попытка отключения от устройства
      setState(() {
        isDeviceConnected = false; // Обновление состояния: устройство отключено
      });
    } catch (e) {
      print("Error disconnecting from device: $e"); // Вывод ошибки
    }
  }

  Future<void> sendLightMode() async { // Асинхронный метод для отправки режима управления
    List<int> value = [lightMode ? 1 : 0]; // Преобразование состояния lightMode
    try {
      await writeCharacteristic( // Запись значения в характеристику Bluetooth устройства
        widget.device,
        Guid('00002a56-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e"); // Вывод ошибки в случае неудачи записи
    }
  }

  Future<List<int>> readCharacteristic( // Асинхронный метод для чтения характеристики
      BluetoothDevice device, Guid characteristicGuid) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) {
          List<int> value = await characteristic.read(); // Чтение значения характеристики
          return value;
        }
      }
    }
    throw Exception('Characteristic not found: $characteristicGuid');
  }

  Future<void> sendLightEffect(int effect) async { // Асинхронный метод для отправки эффекта
    List<int> value = [effect]; // Преобразование эффекта освещения
    try {
      await writeCharacteristic( // Запись значения в характеристику Bluetooth устройства
        widget.device,
        Guid('00002a59-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e"); // Вывод ошибки в случае неудачи записи
    }
  }

  Future<void> sendTransparentMode() async { // Асинхронный метод для режима прозрачности
    List<int> value = [isTransparent ? 1 : 0]; // Преобразование состояния isTransparent
    try {
      await writeCharacteristic( // Запись значения в характеристику Bluetooth устройства
        widget.device,
        Guid('00002a60-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e"); // Вывод ошибки в случае неудачи записи
    }
  }

  Future<void> sendTextMessage() async { // Асинхронный метод для отправки сообщения
    String text = textController.text; // Получение текста из текстового поля
    List<int> value = utf8.encode(text); // Кодирование текста в формат UTF-8
    try {
      await writeCharacteristic( // Запись закодированного текста в характеристику
        widget.device,
        Guid('00002a61-0000-1000-8000-00805f9b34fb'),
        value,
      );
    } catch (e) {
      print("Error writing to characteristic: $e"); // Вывод ошибки
    }
  }

  Future<void> writeCharacteristic( // Асинхронный метод для записи данных в характеристику 
      BluetoothDevice device, Guid characteristicGuid, List<int> value) async {
    List<BluetoothService> services = await device.discoverServices(); 
    for (BluetoothService service in services) { // Перебор сервисов и их характеристик
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == characteristicGuid) { 
          await characteristic.write(value); // Запись значения в характеристику
          return;
        }
      }
    }
  }
  @override // Переопределение метода build для построения UI виджета
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
            if (isDeviceConnected) // Отображение виджетов от состояния подключения
              Column(
                children: <Widget>[
                  Container( // Отображение автоматического режима и уровня освещенности
                    width: 380,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(20.0), 
                    ),
                    child: Column(
                      children: [
                        Text('Автоматический режим',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        SizedBox(height: 26), // Вертикальный промежуток между элементами
                        if (inAutoMode)
                          Column(children: [
                            Text('Уровень освещенности: $lightIntensity',
                                style: TextStyle(fontSize: 20)),
                            SizedBox(height: 20.8), 
                            ElevatedButton( // Кнопка для переключения режима
                              onPressed: () {
                                setState(() {
                                  inAutoMode = false;
                                  lightMode = false;
                                });
                                sendLightMode();
                              },
                              child: Text('Переключить режим',
                                  style: TextStyle(fontSize: 20)),
                              style: ElevatedButton.styleFrom(
                                  primary: Color(
                                      0xFF45A29E) 
                                  ),
                            ),
                          ]),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  Container( // Контейнер для ручного режима
                    width: 380,
                    height: 320, 
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(20.0), 
                    ),
                    child: Column(
                      children: [
                        Text('Ручной режим',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        if (!inAutoMode) // Отображение элементов ручного режима
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  ElevatedButton( // Кнопки для управления
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(1);
                                    },
                                    child: Text('Белый свет'),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(0xFF45A29E) 
                                        ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(2);
                                    },
                                    child: Text('Градиент'),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(0xFF45A29E) 
                                        ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {});
                                      sendLightEffect(0);
                                    },
                                    child: Text('Выключить'),
                                    style: ElevatedButton.styleFrom(
                                        primary: Color(0xFF45A29E) 
                                        ),
                                  ),
                                ],
                              ),
                              Text('Прозрачный/матовый', // Переключение прозрачности
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
                              TextField( // Текстовое поле для ввода сообщения
                                controller: textController,
                                decoration: InputDecoration(
                                    labelText: 'Введите сообщение'),
                              ),
                              ElevatedButton( // Кнопка для отправки текстового сообщения
                                onPressed: () {
                                  sendTextMessage();
                                },
                                child: Text('Отправить сообщение'),
                                style: ElevatedButton.styleFrom(
                                    primary: Color(0xFF45A29E)
                                    ),
                              ),
                              ElevatedButton( // Кнопка для возврата в автоматический режим
                                onPressed: () {
                                  setState(() {
                                    inAutoMode = true;
                                    lightMode = true;
                                  });
                                  sendLightMode();
                                },
                                style: ElevatedButton.styleFrom(
                                    primary: Color(0xFF45A29E)
                                    ),
                                child: Text('Переключить режим',
                                    style: TextStyle(fontSize: 20)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                      height: 40), 
                  Container( // Контейнер для управления соединением
                    width: 380,
                    height: 160, 
                    decoration: BoxDecoration(
                      color: Color(0xFF1F2833),
                      borderRadius: BorderRadius.circular(20.0), 
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Управление соединением',
                            style: TextStyle(
                                color: Color(0xFF66FCF1), fontSize: 24)),
                        SizedBox(
                            height: 40),
                        Container( // Кнопка для отключения от устройства
                          width: 312,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: disconnectDevice,
                            style: ElevatedButton.styleFrom(
                                primary: Color(0xFF45A29E)
                                ),
                            child: Text('Отключиться от устройства',
                                style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            if (!isDeviceConnected) // Условное отображение сообщения о подключении
              Text('Подключение к устройству...',
                  style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
