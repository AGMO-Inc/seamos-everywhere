# Java Usage Patterns

> Code generation patterns for SeamOS Java apps. Placeholders use `{PluginName}`, `{SignalName}`, `{type}`.

## Provider Injection

The Controller receives Machine objects via setter injection during app startup.

```java
// In ApplicationMain.onStart() — called for each provider
void initializeMachineProviders(IMachineProvider provider) {
    if (provider instanceof {PluginName}Provider) {
        I{PluginName} instance = (({PluginName}Provider) provider).get{PluginName}();
        if (instance != null) {
            getController().set{PluginName}(instance);
        }
    }
}
```

**Example** (GPSPlugin):
```java
if (provider instanceof GPSPluginProvider) {
    IGPSPlugin gpsPlugin = ((GPSPluginProvider) provider).getGPSPlugin();
    if (gpsPlugin != null) {
        getController().setGPSPlugin(gpsPlugin);
    }
}
```

## Reading Signals (Subscribe / In)

```java
// Get current value
{type} value = {machine}.get{SignalName}();

// Check validity
boolean valid = {machine}.is{SignalName}_Valid();

// Get timestamp
long timestamp = {machine}.get{SignalName}_Timestamp();
```

**Example** (GPS position):
```java
AbsolutePosition pos = gpsPlugin.getGPSSensorPosition();
boolean isValid = gpsPlugin.isGPSSensorPosition_Valid();
long ts = gpsPlugin.getGPSSensorPosition_Timestamp();
```

## Writing Signals (Publish / Out)

Calling a setter automatically publishes to the FIL layer via MQTT.

```java
{machine}.set{SignalName}(value);
// → Auto-publishes to FIL (MQTT topic: fek/{interface_id})
```

**Example** (motor command):
```java
canSteerMotor.setMotor_Request(requestData);
```

## Change Detection (PropertyChangeListener)

Register a listener to react to signal updates in real time.

```java
{machine}.addPropertyChangeListener(new PropertyChangeListener() {
    @Override
    public void propertyChange(PropertyChangeEvent event) {
        String signalName = event.getPropertyName();
        Object newValue = event.getNewValue();
        // Handle signal update
    }
});
```

**Example** (gyro updates):
```java
canAllynav.addPropertyChangeListener(event -> {
    if ("aGMO_Gyro_ParameterGroup1".equals(event.getPropertyName())) {
        Object gyroData = event.getNewValue();
        // Process gyro data
    }
});
```

## Platform Service Methods

Platform_Service uses a different pattern — method invocation instead of getter/setter.

```java
// Cloud upload
platformService.uploadData(dataString);
platformService.uploadFile(filePath);
platformService.download(targetPath);

// Device-to-Device
platformService.sendCommand(deviceId, command);
platformService.sendFile(deviceId, filePath);

// QR Scanner
platformService.readQRCode();

// AgriRouter
platformService.uploadAgriRouterFile(filePath);
```

## Key Interfaces

| Interface | Package | Role |
|-----------|---------|------|
| `IMachineProvider` | `com.bosch.fsp.runtime.feature` | Base interface for all providers |
| `IMachine` | `com.bosch.fsp.runtime.feature` | Base interface for machine data classes |
| `I{PluginName}` | `com.bosch.nevonex.{plugin_pkg}` | Plugin-specific machine interface |
| `{PluginName}Provider` | `com.bosch.nevonex.{plugin_pkg}.impl` | Plugin provider implementation |
| `FCALController` | `com.bosch.fsp.runtime.feature` | MQTT subscribe/publish controller |
| `NEVONEXApplication` | `com.bosch.fsp.runtime.feature` | App base class |

## Communication Flow

```
App (Controller)
  → Machine.set{Signal}(value)
    → FCALController.publish()
      → MQTT topic: fek/{interface_id}
        → FIL (Feature Interface Layer)
          → CAN Bus / Hardware
```

```
CAN Bus / Hardware
  → FIL → MQTT topic: fek/{interface_id}
    → FCALController.setMachineUpdate()
      → Machine object updated
        → PropertyChangeEvent fired
          → Controller listener handles update
```

## Language Detection

To determine if a project uses Java:
- Check for `.fgd` filename containing `_java`
- Check for `.gen` project with `.javajet` templates
- Check `FDProject.props` for language setting
