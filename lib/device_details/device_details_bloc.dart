
import 'dart:async';

import 'package:fimber/fimber.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wear_hint/model/ble_device.dart';
import 'package:wear_hint/repository/device_repository.dart';
import 'package:wear_hint/sensor_tag/sensor_tag.dart';
import 'dart:typed_data';
import 'dart:math';

class DeviceDetailsBloc {
  final FlutterBlue _flutterBlue;
  final DeviceRepository _deviceRepository;
  final SensorTagFactory _sensorTagFactory;
  SensorTag _sensorTag;

  BehaviorSubject<BleDevice> _deviceController;

  ValueObservable<BleDevice> get device => _deviceController.stream;

  StreamSubscription connectionSubscription;

  Stream<BleDevice> _devicesInConnectingProcess;

  BehaviorSubject<double> _ambientTemperaturSubject = BehaviorSubject();
  ValueObservable<double> get ambientTemperature => _ambientTemperaturSubject.stream;

  DeviceDetailsBloc(this._flutterBlue, this._deviceRepository, {SensorTagFactory sensorTagFactory})
    : _sensorTagFactory = sensorTagFactory ?? SensorTagFactory() {

    _flutterBlue.setLogLevel(LogLevel.error);
    _deviceController =
        BehaviorSubject<BleDevice>(seedValue: _deviceRepository.pickedDevice.value);

  }

  void init() {
    Fimber.d("init bloc");
    _deviceController.stream.listen((bleDevice) {
      Fimber.d("got bleDevice: $bleDevice");
      if (bleDevice.bluetoothDeviceState == BluetoothDeviceState.disconnected) {
        _devicesInConnectingProcess = (bleDevice as DisconnectedBleDevice).connect();
        _devicesInConnectingProcess.pipe(_deviceController);
        return;
      }
    });
    _deviceController.listen((BleDevice bleDevice) {
      if (bleDevice is ConnectedBleDevice ) {
        _sensorTag = _sensorTagFactory.create(bleDevice)..initAllSensors();
        _sensorTag.ambientTemperature.pipe(_ambientTemperaturSubject);
      }
    });
  }

  void dispose() async {
    _sensorTag?.dispose();
    _ambientTemperaturSubject.close();
    _deviceController.value?.abandon();
    await _deviceController.drain();
    _deviceController.close();
  }

}