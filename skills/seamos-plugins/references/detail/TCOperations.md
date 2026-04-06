# TCOperations

- **Machine ID**: 6691
- **Provider Class**: com.bosch.nevonex.tcoperations.impl.TCOperationsProvider
- **Category**: Task Controller

## Interfaces

| Direction | Signal | Standard | Standard ID | Mode | Cycle | DataType | Stage | API Ver | Description |
|-----------|--------|----------|-------------|------|-------|----------|-------|---------|-------------|
| In | CopyDDOP | NEVONEX | - | Adhoc | - | STRING | RELEASED | 0.0.1 | To Copy DDOP File to Feature Directory |
| Out | DeleteTaskdata | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | Feature Developer have to send "True" to delete all Files and folders in Taskdata as Applied folder. If Feature Develope … |
| In | GetTCStatus | ISOBUS | n.a. | Cyclic | 10ms | INT | RELEASED | 0.0.1 | Current Status of Task Controller (0 if off 1 if ON) |
| In | NRP_Offsets | NEVONEX | - | Cyclic | 10ms | array | RELEASED | 0.0.1 | Updates the values of NRP_ConnectorOffset_mm, NRP_GpsReceiverXOffset_mm and NRP_GpsReceiverYOffset_mm. |
| Out | ReceiveFile | NEVONEX | - | Process | - | array | RELEASED | 0.0.1 | This interface is used for transferring Task files in .tar format from TC/Geosuite Task folder to FEATURE accessible fol … |
| In | RunngTsk | NEVONEX | NA | Adhoc | - | array | RELEASED | 0.0.1 | TaskID and TaskDesignator of Running Task |
| Out | SendFile | NEVONEX | - | Process | - | array | RELEASED | 0.0.1 | This interface is used for transferring Task files in .tar format to Geosuite Task folder (no need to mention the path). … |
| Out | SetDDOPCopyPath | NEVONEX | - | Process | - | STRING | RELEASED | 0.0.1 | To Set folder path for DDOP Copy |
| Out | spotSprayCoverage | NEVONEX | - | Process | - | enum | RELEASED | 0.0.1 | Spot spray coverage specifies when the section has to start spraying once it enters a field boundary. entireSection -> S … |
| Out | StartProgram | NEVONEX | - | Process | - | BOOLEAN | RELEASED | 0.0.1 | Geosuite feature could be used only if this interface is enabled. Payload ‘1’ will start Geosuite. Payload ‘0’ will stop … |
| In | TaskdataEmptyStatus | NEVONEX | - | Adhoc | - | BOOLEAN | RELEASED | 0.0.1 | Returns "True" when Task data folder is empty. Returns "False" , when Task data folder is not empty. |
| In | TaskStatus | NEVONEX | - | Cyclic | 10ms | enum | RELEASED | 0.0.1 | Provides current status of task 0 = TASKSTATUS_NOT_SET, 1 = TASKSTATUS_INITIAL, 2 = TASKSTATUS_RUNNING, 3 = TASKSTATUS_P … |
| In | TransferStatus | NEVONEX | - | Adhoc | - | array | RELEASED | 0.0.1 | Provides status of copy operations with id |

## Signal Fields

### NRP_Offsets

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| NRP_ConnectorOffset_mm | INT | mm | - |
| NRP_GpsReceiverXOffset_mm | INT | mm | - |
| NRP_GpsReceiverYOffset_mm | INT | mm | - |

### ReceiveFile

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| id | INT | - | - |
| file | STRING | - | - |

### RunngTsk

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| TaskID | STRING | NA | - |
| TaskDesignator | STRING | NA | - |
| deviceUniqueID | STRING | NA | - |
| fieldBoundary | DOUBLE | ha | - |
| workedArea | DOUBLE | ha | - |
| remainingArea | DOUBLE | ha | - |

### SendFile

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| id | INT | - | - |
| file | STRING | - | - |

### TransferStatus

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| id | INT | - | - |
| status | TransferStatus | enum | - |
