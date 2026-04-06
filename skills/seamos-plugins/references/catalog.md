# SEAMOS Plugin Catalog

> This catalog lists all available SEAMOS (NEVONEX) plugins. Read this first to identify the target plugin(s), then load the detail file from `detail/{PluginName}.md`.

## Plugins

| Plugin | Machine ID | Category | Direction | Signals | Description |
|--------|-----------|----------|-----------|---------|-------------|
| CAN_AGMO_Allynav_R70 | 7583 | Sensor/IMU | 3 In | 3 | Gyro sensor — 3-axis angle and angular rate |
| CAN_AGMO_Customized_Tractor | 7585 | Vehicle Control | 5 In / 5 Out | 10 | Tractor control — accel, shift, hydraulic, PTO, FNR |
| CAN_AGMO_MTLT305 | 7584 | Sensor/IMU | 11 In / 4 Out | 15 | Aceinna IMU — acceleration, angle rate, angles, config |
| CAN_AGMO_SteerMotor | 7582 | Actuator | 8 In / 1 Out | 9 | Steering motor — position, speed, current, temperature |
| GPIO_Prototyping | 7576 | GPIO | 7 In / 7 Out | 14 | GPIO I/O — 4 analog in, 3 digital in, 7 digital out |
| GPS_TC | 6676 | Position | 3 In | 3 | Task Controller GPS — position and source info |
| GPSPlugin | 5771 | Position | 4 In / 1 Out | 5 | Internal GPS — position, status, detailed info |
| Implement | 351 | Implement | 634 mixed | 634 | Implement (work tool) interface — comprehensive signal set |
| IMU | 5746 | Sensor/IMU | 4 In | 4 | Internal IMU — acceleration, angle, angular rate |
| ISOPGN | 547 | ISO Standard | 140 In | 140 | ISO 11783 standard signals — engine, fuel, position, etc. |
| Platform_Service | 6679 | Platform Service | 8 Methods | 8 | Cloud upload/download, D2D communication, QR scanner, AgriRouter |
| Serial_Ext_GPS_NMEA0183 | 7586 | Position/Serial | 1 In | 1 | External serial GPS via NMEA 0183 protocol |
| TCOperations | 6691 | Task Controller | 13 In | 13 | Task Controller operations — DDOP, task status, transfer |

## Selection Guide

### By Use Case

- **Position / Navigation** → GPSPlugin, GPS_TC, Serial_Ext_GPS_NMEA0183
- **Attitude / Tilt / Orientation** → IMU, CAN_AGMO_MTLT305, CAN_AGMO_Allynav_R70
- **Vehicle Control** → CAN_AGMO_Customized_Tractor
- **Steering Control** → CAN_AGMO_SteerMotor
- **Implement / Work Tool** → Implement
- **ISO 11783 Standard Data** (engine RPM, fuel level, speed, etc.) → ISOPGN
- **Task Controller** → TCOperations
- **Cloud / File Transfer / Device Communication** → Platform_Service
- **GPIO Direct Control** → GPIO_Prototyping

### By Communication Standard

- **CAN** → CAN_AGMO_SteerMotor, CAN_AGMO_Customized_Tractor
- **PGN (J1939)** → CAN_AGMO_Allynav_R70, CAN_AGMO_MTLT305, ISOPGN
- **NEVONEX** → GPIO_Prototyping
- **Platform API** → Platform_Service, GPSPlugin, GPS_TC, IMU, TCOperations
- **Serial (NMEA 0183)** → Serial_Ext_GPS_NMEA0183
