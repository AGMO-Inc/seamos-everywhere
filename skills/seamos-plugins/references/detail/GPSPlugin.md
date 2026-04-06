# GPSPlugin

- **Machine ID**: 5771
- **Provider Class**: com.bosch.nevonex.gpsplugin.impl.GPSPluginProvider
- **Category**: Position

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | GPSSensorPosition | NEVONEX | - | Cyclic | 1000ms | GPS | RELEASED | 0.0.1 | Internal GPS sensor information. Data members [ Latitude -> Default value -99.99 Longitude -> Default value -99.99 ] If … |
| In | internalGpsDetailedInfo | NEVONEX | - | Cyclic | 1000ms | array | IMPLEMENTED | 0.0.1 | Internal GPS sensor information. Data members description: Latitude -> Latitude is the angular distance of a place North … |
| In | InternalGPSInfo | NEVONEX | - | Cyclic | 1000ms | array | RELEASED | 0.0.1 | Internal GPS sensor information. Data members [ Latitude -> Default value -99.99 Longitude -> Default value -99.99 Altit … |
| In | InternalGPSStatus | NEVONEX | - | Cyclic | 1000ms | enum | RELEASED | 0.0.1 | Status of Internal GPS (Active or InActive) |
| Out | OnBoardGPSTxOnCAN | NEVONEX | - | Process | - | BOOLEAN | IMPLEMENTED | 0.0.1 | Provides GPS position from OnBoard GPS sensor to CAN network - SPN 584 & SPN 585, enable/disable, by default, enable whe … |

## Signal Fields

### internalGpsDetailedInfo

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Latitude | DOUBLE | degree | - |
| Longitude | DOUBLE | degree | - |
| Altitude | DOUBLE | meters | - |
| TimeStamp | STRING | milliseconds | - |
| HorizontalAccuracy | FLOAT | meters | - |
| VerticalAccuracy | FLOAT | meters | - |
| HorizontalDil | FLOAT | - | - |
| PositionDil | FLOAT | - | - |
| VerticalDil | FLOAT | - | - |
| TimeDil | FLOAT | - | - |
| Speed | FLOAT | km/hr | - |
| Course | FLOAT | degree | - |
| NumberOfSatellites | INT | - | - |

### InternalGPSInfo

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Latitude | DOUBLE | deg | - |
| Longitude | DOUBLE | deg | - |
| Altitude | DOUBLE | m | - |
| PositionTime | DOUBLE | s | - |
| HDOP | FLOAT | - | - |
| PDOP | FLOAT | - | - |
| NumberOfSattelites | INT | - | - |
