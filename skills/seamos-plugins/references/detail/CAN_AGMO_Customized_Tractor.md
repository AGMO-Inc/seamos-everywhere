# CAN_AGMO_Customized_Tractor

- **Machine ID**: 7585
- **Provider Class**: com.bosch.nevonex.can_agmo_customized_tractor.impl.CAN_AGMO_Customized_TractorProvider
- **Category**: Vehicle Control

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | Receive_ACC_INFO | CAN | 0x490 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Receive_ACC_INFO |
| In | Receive_FNR_INFO | CAN | 0x410 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Receive_FNR_INFO |
| In | Receive_HYD_INFO | CAN | 0x480 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Receive_HYD_INFO |
| In | Receive_PTO_INFO | CAN | 0x430 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Receive_PTO_INFO |
| In | Receive_SFT_INFO | CAN | 0x420 | Adhoc | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Receive_SFT_INFO |
| Out | Send_ACC_CMD | CAN | 0x540 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Send_ACC_CMD |
| Out | Send_FNR_CMD | CAN | 0x500 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Send_FNR_CMD |
| Out | Send_HYD_CMD | CAN | 0x530 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Send_HYD_CMD |
| Out | Send_PTO_CMD | CAN | 0x520 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Send_PTO_CMD |
| Out | Send_SFT_CMD | CAN | 0x510 | Process | - | array | DEVELOPMENT | 0.0.1 | AGMO - Customized Tractor - Send_SFT_CMD |

## Signal Fields

### Receive_ACC_INFO

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TRZ_ACC_SIG1_V | FLOAT | V | - |
| TRZ_ACC_SIG2_V | FLOAT | V | - |
| TRZ_ACC_DIAG | INT | - | - |
| TRZ_ACC_AUTO | INT | - | - |

### Receive_FNR_INFO

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TRZ_FNR_SIG1_V | FLOAT | V | - |
| TRZ_FNR_SIG2_V | FLOAT | V | - |
| TRZ_FNR_DIAG | INT | - | - |
| TRZ_FNR_AUTO | INT | - | - |
| TRZ_FNR_STATE | INT | - | - |

### Receive_HYD_INFO

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TRZ_HYD_SIG1_V | FLOAT | V | - |
| TRZ_HYD_SIG2_V | FLOAT | V | - |
| TRZ_HYD_DIAG | INT | - | - |
| TRZ_HYD_AUTO | INT | - | - |

### Receive_PTO_INFO

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TRZ_PTO_STATE | INT | - | - |
| TRZ_PTO_AUTO | INT | - | - |

### Receive_SFT_INFO

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TRZ_SFT_SIG1_V | FLOAT | V | - |
| TRZ_SFT_SIG2_V | FLOAT | V | - |
| TRZ_SFT_DIAG | INT | - | - |
| TRZ_SFT_AUTO | INT | - | - |
| TRZ_SFT_STATE | INT | - | - |

### Send_ACC_CMD

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AD_Generic_Cmd | INT | - | - |
| AD_Generic_Mode_Cmd | INT | - | - |

### Send_FNR_CMD

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AD_Generic_Cmd | INT | - | - |
| AD_Generic_Mode_Cmd | INT | - | - |

### Send_HYD_CMD

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AD_Generic_Cmd | INT | - | - |
| AD_Generic_Mode_Cmd | INT | - | - |

### Send_PTO_CMD

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AD_Generic_Cmd | INT | - | - |
| AD_Generic_Mode_Cmd | INT | - | - |

### Send_SFT_CMD

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| AD_Generic_Cmd | INT | - | - |
| AD_Generic_Mode_Cmd | INT | - | - |
