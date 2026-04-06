# Serial_Ext_GPS_NMEA0183

- **Machine ID**: 7586
- **Provider Class**: com.bosch.nevonex.serial_ext_gps_nmea0183.impl.Serial_Ext_GPS_NMEA0183Provider
- **Category**: Position/Serial

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Serial_Ext_GPS_NMEA0183_Data | NEVONEX | - | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | NMEA0183 GPS data |

## Signal Fields

### Serial_Ext_GPS_NMEA0183_Data

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| UTC_ms | STRING | ms | - |
| Latitude | DOUBLE | - | - |
| Longitude | DOUBLE | - | - |
| GPS_Quality_Indicator | INT | - | - |
| No_Satellites | INT | - | - |
| Altitude | FLOAT | m | - |
| Geoidal_Separation | FLOAT | m | - |
| DGPS_Age | FLOAT | s | - |
| Differential_Ref_Station | INT | - | - |
| Selection_Mode | STRING | - | - |
| Fix_Type | INT | - | - |
| PDOP | FLOAT | - | - |
| HDOP | FLOAT | - | - |
| VDOP | FLOAT | - | - |
| Status | INT | - | - |
| Speed | FLOAT | knots | - |
| Course | FLOAT | - | - |
| Magnetic_variation | FLOAT | - | - |
| FAA_Mode_Indicator | STRING | - | - |
| Heading | FLOAT | deg | - |
| HeadingTrue | INT | - | - |
