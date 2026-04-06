# IMU

- **Machine ID**: 5746
- **Provider Class**: com.bosch.nevonex.imu.impl.IMUProvider
- **Category**: Sensor/IMU

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | accl | - | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | Acceleration Sensor |
| In | angle | - | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | Orientation of vehicle in space |
| In | GetInstallationAngles | NEVONEX | - | Adhoc | - | array | IMPLEMENTED | 0.0.1 | Get installation angles (roll, pitch, yaw) of device installed on machine |
| In | rate | - | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | Angular Rate Sensor |

## Signal Fields

### accl

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| X_AXIS | FLOAT | - | - |
| Y_AXIS | FLOAT | - | - |
| Z_AXIS | FLOAT | - | - |
| TV_SEC | INT | seconds | - |
| TV_NSEC | INT | nanoseconds | - |

### angle

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| ROLL | FLOAT | deg | - |
| PITCH | FLOAT | deg | - |
| YAW | FLOAT | deg | - |

### GetInstallationAngles

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| ROLL | FLOAT | deg | - |
| PITCH | FLOAT | deg | - |
| YAW | FLOAT | deg | - |

### rate

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| X_AXIS | FLOAT | - | - |
| Y_AXIS | FLOAT | - | - |
| Z_AXIS | FLOAT | - | - |
| TV_SEC | INT | seconds | - |
| TV_NSEC | INT | nanoseconds | - |
