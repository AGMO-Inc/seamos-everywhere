# CAN_AGMO_SteerMotor

- **Machine ID**: 7582
- **Provider Class**: com.bosch.nevonex.can_agmo_steermotor.impl.CAN_AGMO_SteerMotorProvider
- **Category**: Actuator

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Motor_Heartbeat | CAN | 0x7000001 | Cyclic | 100ms | array | DEVELOPMENT | 0.0.1 | AGMO - Steer Motor - Motor Heartbeat |
| Out | Motor_Request | CAN | 0x6000001 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Steer Motor - Motor Request |
| In | Motor_Response_Encoder_Speed | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x1210360 |
| In | Motor_Response_EncoderCountValue | CAN | 0x5800001 | Adhoc | - | FLOAT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x1210460 |
| In | Motor_Response_MotorCurrent | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x1210060 |
| In | Motor_Response_MotorTemperature | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x1210F60 |
| In | Motor_Response_PositionControl | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x200260 |
| In | Motor_Response_PowerSupplyVoltage | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x2210D60 |
| In | Motor_Response_SpeedControl | CAN | 0x5800001 | Adhoc | - | INT | DEVELOPMENT | 0.0.1 | AGMO - Response Multiplexer 0x200060 |

## Signal Fields

### Motor_Heartbeat

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Heartbeat_ControlStatus_HallFailure | INT | - | - |
| Heartbeat_ControlStatus_CANdisconnected | INT | - | - |
| Heartbeat_ControlStatus_MotorStalled | INT | - | - |
| Heartbeat_ControlStatus_Disabled | INT | - | - |
| Heartbeat_ControlStatus_Overvoltage | INT | - | - |
| Heartbeat_ControlStatus_HardwareProtection | INT | - | - |
| Heartbeat_ControlStatus_E2PROM | INT | - | - |
| Heartbeat_ControlStatus_Undervoltage | INT | - | - |
| Heartbeat_ControlStatus_Overcurrent | INT | - | - |
| Heartbeat_ControlStatus_ModeFailure | INT | - | - |

### Motor_Request

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| Byte0 | INT | - | - |
| Byte1 | INT | - | - |
| Byte2 | INT | - | - |
| Byte3 | INT | - | - |
| Byte4 | INT | - | - |
| Byte5 | INT | - | - |
| Byte6 | INT | - | - |
| Byte7 | INT | - | - |
