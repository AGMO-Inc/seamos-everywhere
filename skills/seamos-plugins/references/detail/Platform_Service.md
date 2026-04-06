# Platform_Service

- **Machine ID**: 6679
- **Provider Class**: N/A — Platform_Service is a composite plugin with sub-services (Cloud, Device2Device, QRScanner, AgriRouter). It does not follow the standard `{PluginName}Provider` injection pattern. See `usage-patterns/java.md` § Platform Service Methods for the correct usage.
- **Category**: Platform Service

## Interfaces

### Cloud (Machine ID: 6680)

| Direction | Method | Mode | Stage | API Ver | Description |
|-----------|--------|------|-------|---------|-------------|
| Method | Download | Cyclic | Released | 0.0.1 | Download a file/message from the cloud to the feature. |
| Method | Upload Data | Cyclic | Released | 0.0.1 | upload data in String format to the cloud from the feature. |
| Method | Upload File | Cyclic | Released | 0.0.1 | upload a file to the cloud from the feature. |

### Device2Device (Machine ID: 6681)

| Direction | Method | Mode | Stage | API Ver | Description |
|-----------|--------|------|-------|---------|-------------|
| Method | Receive | Cyclic | Released | 0.0.1 | receive a file/command to the feature from the device. |
| Method | Send Command | Cyclic | Released | 0.0.1 | send a command to the device from the feature. |
| Method | Send File | Cyclic | Released | 0.0.1 | send a file to the device from the feature. |

### QRScanner (Machine ID: 6733)

| Direction | Method | Mode | Stage | API Ver | Description |
|-----------|--------|------|-------|---------|-------------|
| Method | Read QR Code | Cyclic | Released | 0.0.1 | Read code using scanner to the feature. |

### AgriRouter (Machine ID: 7530)

| Direction | Method | Mode | Stage | API Ver | Description |
|-----------|--------|------|-------|---------|-------------|
| Method | Upload AgriRouter File | Cyclic | Released | 0.0.1 | Upload an Agri-Router file to the Cloud. |
