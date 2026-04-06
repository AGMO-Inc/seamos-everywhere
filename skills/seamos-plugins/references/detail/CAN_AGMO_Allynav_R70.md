# CAN_AGMO_Allynav_R70

- **Machine ID**: 7583
- **Provider Class**: com.bosch.nevonex.can_agmo_allynav_r70.impl.CAN_AGMO_Allynav_R70Provider
- **Category**: Sensor/IMU

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | AGMO_Gyro_ParameterGroup1 | PGN | 0xFFCA | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | Agmo - Allynav_R70 - Angles |
| In | AGMO_Gyro_ParameterGroup2 | PGN | 0xFFCB | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | AGMO - Allynav_R70 - Accel |
| In | AGMO_Gyro_ParameterGroup3 | PGN | 0xFFCC | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | AGMO - Allynav_R70 - AngularRate |

## Signal Fields

### AGMO_Gyro_ParameterGroup1

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Angle_X | FLOAT | deg | - |
| Angle_Y | FLOAT | deg | - |
| Angle_Z | FLOAT | deg | - |

### AGMO_Gyro_ParameterGroup2

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Accel_Y | FLOAT | g | - |
| Accel_X | FLOAT | g | - |
| Accel_Z | FLOAT | g | - |

### AGMO_Gyro_ParameterGroup3

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AngularRate_Y | FLOAT | rad/s | - |
| AngularRate_X | FLOAT | rad/s | - |
| AngularRate_Z | FLOAT | rad/s | - |
