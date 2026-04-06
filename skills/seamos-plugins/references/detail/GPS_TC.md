# GPS_TC

- **Machine ID**: 6676
- **Provider Class**: com.bosch.nevonex.gps_tc.impl.GPS_TCProvider
- **Category**: Position

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Active_TC_GPS_source | NEVONEX | - | Cyclic | 10ms | enum | RELEASED | 0.0.1 | Specifies if the active external GPS source is NMEA2000 or NMEA0183 |
| In | PositionofGpsSensor | NEVONEX | - | Cyclic | 10ms | GPS | RELEASED | 0.0.1 | Absolute position of GPS sensor. |
| In | TcGpsInfo | NEVONEX | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | Gives GPS Quality, Altitude, Position and UTC time in one payload |

## Signal Fields

### TcGpsInfo

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Latitude | DOUBLE | deg | - |
| Longitude | DOUBLE | deg | - |
| Altitude | DOUBLE | m | - |
| PositionTime | DOUBLE | s | - |
| HDOP | FLOAT | - | - |
| PDOP | FLOAT | - | - |
| NumberOfSattelites | INT | - | - |
