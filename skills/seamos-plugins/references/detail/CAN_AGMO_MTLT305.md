# CAN_AGMO_MTLT305

- **Machine ID**: 7584
- **Provider Class**: com.bosch.nevonex.can_agmo_mtlt305.impl.CAN_AGMO_MTLT305Provider
- **Category**: Sensor/IMU

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Aceinna_Accel | PGN | 0xF02D | Cyclic | 10ms | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Aceinna_Accel |
| In | Aceinna_AngleRate | PGN | 0xF02A | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Aceinna_AngleRate |
| In | Aceinna_Angles | PGN | 0xF029 | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Aceinna_Angles |
| In | Feedback_Configuration_Save | PGN | 0xFF51 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Configuration_Save |
| In | Feedback_Digital_Filter | PGN | 0xFF57 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Digital_Filter |
| In | Feedback_Firmware_Version | PGN | 0xFEDA | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Firmware_Version |
| In | Feedback_Hardware_BIT | PGN | 0xFF52 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Hardware_BIT |
| In | Feedback_Orientation | PGN | 0xFF58 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Orientation |
| In | Feedback_Packet_Rate_Divider | PGN | 0xFF55 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Packet_Rate_Divider |
| In | Feedback_Sensor_Status | PGN | 0xFF54 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Sensor_Status |
| In | Feedback_Software_Bit | PGN | 0xFF53 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Feedback_Software_Bit |
| Out | Set_Configuration_Save | PGN | 0xFF51 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Set_Configuration_Save |
| Out | Set_Digital_Filter | PGN | 0xFF57 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Set_Digital_Filter |
| Out | Set_Orientation | PGN | 0xFF58 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Set_Orientation |
| Out | Set_Packet_Rate_Divider | PGN | 0xFF55 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO MTLT305 Set_Packet_Rate_Divider |

## Signal Fields

### Aceinna_Accel

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AccY | FLOAT | m/s2 | - |
| AccX | FLOAT | m/s2 | - |
| AccZ | FLOAT | m/s2 | - |
| LateralAcc_FigureOfMerit | INT | - | - |
| LongiAcc_FigureOfMerit | INT | - | - |
| VerticAcc_FigureOfMerit | INT | - | - |
| Support_Rate_Acc | INT | - | - |

### Aceinna_AngleRate

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| GyroY | FLOAT | deg/s | - |
| GyroX | FLOAT | deg/s | - |
| GyroZ | FLOAT | deg/s | - |
| GyroY_FigureOfMerit | INT | - | - |
| GyroX_FigureOfMerit | INT | - | - |
| GyroZ_FigureOfMerit | INT | - | - |
| AngleRate_Latency | FLOAT | ms | - |

### Aceinna_Angles

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Pitch | FLOAT | deg | - |
| Roll | FLOAT | deg | - |
| Pitch_Compensation | INT | - | - |
| Pitch_FigureOfMerit | INT | - | - |
| Roll_Compensation | INT | - | - |
| Roll_FigureOfMerit | INT | - | - |
| PitchRoll_Latency | FLOAT | ms | - |

### Feedback_Configuration_Save

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Request_Or_Response | INT | - | - |
| Saved_Address | INT | - | - |
| Failure_Or_Success | INT | - | - |

### Feedback_Digital_Filter

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Gyro_Low_Pass | INT | - | - |
| New_Acc_Low_Pass | INT | - | - |

### Feedback_Firmware_Version

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Firm_Version_Major | INT | - | - |
| Firm_Version_Minor | INT | - | - |
| Firm_Version_Patch | INT | - | - |
| Firm_Version_Stage | INT | - | - |
| Firm_Version_Build | INT | - | - |

### Feedback_Hardware_BIT

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| HW_Master_Fai | INT | - | - |
| HW_Error | INT | - | - |
| SW_Error | INT | - | - |
| HW_Reserved0 | INT | - | - |

### Feedback_Orientation

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Orientation_Type | INT | - | - |

### Feedback_Packet_Rate_Divider

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Pocket_Rate | INT | - | - |

### Feedback_Sensor_Status

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Master_Status | INT | - | - |
| Hardware_Status | INT | - | - |
| Software_Status | INT | - | - |
| Sensor_Status | INT | - | - |
| Reserved0 | INT | - | - |
| Unlocked_Eeprom | INT | - | - |
| Algo_Init | INT | - | - |
| Reserved1 | INT | - | - |
| Attitude_Only_Algo | INT | - | - |
| Turn_Switch | INT | - | - |
| Sensor_Over_Range | INT | - | - |
| Reserved3 | INT | - | - |

### Feedback_Software_Bit

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| SW_Software_Error | INT | - | - |
| SW_Algorithm_Error | INT | - | - |
| SW_Data_Error | INT | - | - |
| SW_Initialization_Error | INT | - | - |
| SW_Over_Range | INT | - | - |
| SW_Reserved0 | INT | - | - |
| SW_CalibrationCRC_Error | INT | - | - |
| SW_Reserved1 | INT | - | - |

### Set_Configuration_Save

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Request_Or_Response | INT | - | - |
| Saved_Address | INT | - | - |
| Failure_Or_Success | INT | - | - |

### Set_Digital_Filter

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Gyro_Low_Pass | INT | - | - |
| New_Acc_Low_Pass | INT | - | - |

### Set_Orientation

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Orientation_Type | INT | - | - |

### Set_Packet_Rate_Divider

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Destination_Address | INT | - | - |
| New_Pocket_Rate | INT | - | - |
