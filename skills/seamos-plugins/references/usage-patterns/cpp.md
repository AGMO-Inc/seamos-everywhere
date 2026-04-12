# C++ Usage Patterns

> Code generation patterns for SeamOS C++ apps. Placeholders use `{PluginName}`, `{SignalName}`, `{type}`.

## Provider Registration

C++ provider registration is a 3-step process spread across main() and the ApplicationMain lifecycle callbacks.

**Step 1 — Register providers in main():**
```cpp
// In main() — register each provider by enum literal
std::vector<std::string> vec;
vec.push_back(common::getLiteral(ProviderEnum::{PluginName}Provider));
sa->initialize(vec);
```

**Step 2 — Set provider on controller in onStart(AbstractMachineProvider_ptr):**
```cpp
if ({PluginName}Provider_ptr p = ::ecore::as<{PluginName}Provider>(provider)) {
    m_mainController->set{PluginName}Provider(p);
}
```

**Step 3 — Receive machine + register listener in onStart(AbstractMachine_ptr):**
```cpp
if ({PluginName}_ptr obj = ::ecore::as<{PluginName}>(machine)) {
    MachineConnectListener *listener = new MachineConnectListener();
    listener->setMainController(getMainController());
    obj->addListeners(listener);
}
```

**Example** (GPSPlugin):
```cpp
vec.push_back(common::getLiteral(ProviderEnum::GPSPluginProvider));
sa->initialize(vec);

if (GPSPluginProvider_ptr p = ::ecore::as<GPSPluginProvider>(provider)) {
    m_mainController->setGPSPluginProvider(p);
}

if (GPSPlugin_ptr obj = ::ecore::as<GPSPlugin>(machine)) {
    MachineConnectListener *listener = new MachineConnectListener();
    listener->setMainController(getMainController());
    obj->addListeners(listener);
}
```

## Reading Signals (Subscribe / In)

```cpp
// Get current value
{type} value = {machine}->get{SignalName}();

// Check validity
bool valid = {machine}->is{SignalName}_Valid();

// Get timestamp
long timestamp = {machine}->get{SignalName}_Timestamp();
```

**Example** (GPS position):
```cpp
AbsolutePosition_ptr pos = gpsPlugin->getGPSSensorPosition();
bool isValid = gpsPlugin->isGPSSensorPosition_Valid();
long ts = gpsPlugin->getGPSSensorPosition_Timestamp();
```

## Writing Signals (Publish / Out)

Calling a setter automatically publishes to the FIL layer via MQTT.

```cpp
{machine}->set{SignalName}(value);
// → Auto-publishes to FIL (MQTT topic: fek/{interface_id})
```

**Example** (motor command):
```cpp
canSteerMotor->setMotor_Request(requestData);
```

## Change Detection (Timer-based Polling)

> **Note:** Unlike Java which uses `PropertyChangeListener` for event-driven signal updates, C++ uses a timer-based polling model. `MainController::run()` is called at a fixed interval (default 1000ms) to read and process signal values.

```cpp
// 1-second interval timer (created once in addProcessTimer)
ProcessTimer(m_mainController, 1000);

// MainController::run() — called every interval
void MainController::run() {
    {PluginName}Provider_ptr provider = get{PluginName}Provider();
    if (provider != nullptr) {
        // Read and process signals here
    }
}
```

**Example** (polling CAN_AGMO_SteerMotor signals):
```cpp
void MainController::run() {
    CAN_AGMO_SteerMotorProvider_ptr provider = getCAN_AGMO_SteerMotorProvider();
    if (provider != nullptr) {
        CAN_AGMO_SteerMotor_ptr motor = provider->getCAN_AGMO_SteerMotor();
        if (motor != nullptr && motor->isMotor_Feedback_Valid()) {
            int32_t feedback = motor->getMotor_Feedback();
            // Process feedback value
        }
    }
}
```

## Platform Service Methods

```cpp
platformService->uploadData(dataString);    // Cloud upload
platformService->uploadFile(filePath);      // Cloud upload
platformService->download(targetPath);      // Cloud download
platformService->sendCommand(deviceId, command); // Device-to-Device
platformService->sendFile(deviceId, filePath);   // Device-to-Device
platformService->readQRCode();              // QR Scanner
platformService->uploadAgriRouterFile(filePath); // AgriRouter
```

> **Note:** The C++ `PlatformServicesEnum` is currently empty in the reference implementation. Platform Service method patterns follow the same structure as Java but with pointer-based access.

## Protected Region

> **Note:** C++ generated code uses Protected Region markers to preserve user code during regeneration. Add the keyword `ENABLED` before `START` to activate a region:
> ```cpp
> /*PROTECTED REGION ID(MainControllerImpl_runStart) ENABLED START*/
> // Your code here — preserved during regeneration
> /*PROTECTED REGION END*/
> ```

## Key Interfaces

| C++ | Java | Role |
|-----|------|------|
| `AbstractMachineProvider` | `IMachineProvider` | Base interface for all providers |
| `AbstractMachine` | `IMachine` | Base interface for machine data classes |
| `{PluginName}` | `I{PluginName}` | Plugin-specific machine interface |
| `{PluginName}Provider` | `{PluginName}Provider` | Plugin provider implementation |
| `IController` / `MainController` | `FCALController` | MQTT subscribe/publish controller |
| `ApplicationMain` | `NEVONEXApplication` | App base class |
| `::nevonex::{plugin_pkg}` | `com.bosch.nevonex.{plugin_pkg}` | Plugin namespace/package |

## Communication Flow

Write path:
```
App (MainController::run())
  → Machine->set{Signal}(value)
    → FCALController publish
      → MQTT topic: fek/{interface_id}
        → FIL (Feature Interface Layer)
          → CAN Bus / Hardware
```

Read path:
```
CAN Bus / Hardware
  → FIL → MQTT topic: fek/{interface_id}
    → FCALController setMachineUpdate
      → Machine object updated
        → MainController::run() polls updated values
```

## Language Detection

To determine if a project uses C++:
- Check for `.fgd` filename containing `_cpp`
- Check for `.gen` project with `.cppjet` templates
- Check `FDProject.props` for language setting
