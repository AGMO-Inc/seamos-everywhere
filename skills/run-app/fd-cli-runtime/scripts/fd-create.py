#!/usr/bin/env python3
"""FeatureDesigner CLI Project Creator

Generates a complete FeatureDesigner project from templates,
replacing the GUI-based project creation workflow.

Plugins are dynamically loaded from reference/idt_model.json
(decrypted from FeatureDesigner's modelenc.json).
"""

import os
import sys
import json
import re
import shutil
import argparse
import copy
from datetime import datetime

# Constants
FCAL_RUNTIME_VERSION = "8.4.18"
FD_VERSION = "8.6.0"
DEFAULT_UI_PORT = 1456
DEFAULT_VERSION = "1.0.0"
REFERENCE_GEN = "/opt/fd-cli/reference/gen"
REFERENCE_GEN_CPP_SDK = "/opt/fd-cli/reference/gen_cpp_sdk"
REFERENCE_GEN_CPP_APP = "/opt/fd-cli/reference/gen_cpp_app"
REFERENCE_GEN_TESTS = "/opt/fd-cli/reference/gen_tests"
WORKSPACE = "/workspace"

# Resolved at module load time
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_JSON = os.path.join(SCRIPT_DIR, "..", "reference", "idt_model.json")

# Default data-type string for FGD arrayLiterals
_DTYPE_DEFAULTS = {
    "INT": "EInt=0",
    "FLOAT": "EFloat=0.0",
    "DOUBLE": "EDouble=0.0",
    "LONG": "ELong=0",
    "BOOLEAN": "EBoolean=false",
    "STRING": "EString=",
    "SHORT": "EShort=0",
    "BYTE": "EByte=0",
}

# ============================================================
# Dynamic Plugin Loading
# ============================================================

PLUGINS = {}  # populated by load_plugins_from_model()


def _parse_mode(iface):
    """Determine operation mode from boolean flags."""
    if iface.get("isAdhocAndcyclic"):
        return "Cyclic"
    if iface.get("isCyclic"):
        return "Cyclic"
    if iface.get("isProcess"):
        return "Process"
    return "Adhoc"


def _parse_mode_value(iface):
    """Extract numeric cycle value from cycleUnit (e.g. '100ms' -> '100')."""
    cu = iface.get("cycleUnit", "")
    m = re.search(r"(\d+)", str(cu))
    return m.group(1) if m else "0"


def _build_provider_class(machine_name):
    """Auto-generate provider class from machine name.

    GPSPlugin    -> com.bosch.nevonex.gpsplugin.impl.GPSPluginProvider
    Implement    -> com.bosch.nevonex.implement.impl.ImplementProvider
    CAN_AGMO_X   -> com.bosch.nevonex.canagmox.impl.CAN_AGMO_XProvider
    """
    package = machine_name.lower().replace("_", "")
    return f"com.bosch.nevonex.{package}.impl.{machine_name}Provider"


def load_plugins_from_model(path=None):
    """Load plugins from idt_model.json into PLUGINS dict."""
    global PLUGINS
    path = path or MODEL_JSON

    if not os.path.exists(path):
        print(f"Warning: Model file not found at {path}", file=sys.stderr)
        print("  Run: scripts/decrypt_model.java to generate reference/idt_model.json", file=sys.stderr)
        return

    with open(path, "r") as f:
        data = json.load(f)

    for element in data.get("elements", []):
        name = str(element["name"])
        machine_id = str(element["id"])

        interfaces = []
        for iface in element.get("interfaces", []):
            iface_name = iface["interfaceName"]
            uid = str(iface["uid"])
            access_method = iface.get("accessMethod", "READ")
            access_type = "Out" if access_method == "WRITE" else "In"
            control = "Publish" if access_method == "WRITE" else "Subscribe"

            return_type_name = iface.get("returnTypeName", "INT")
            mode = _parse_mode(iface)
            mode_value = _parse_mode_value(iface)
            cycle_values = iface.get("cyclicTimeValues", [])
            fil_dep = iface.get("filDependent", "NO") == "YES"
            standard = iface.get("standard", "")
            mac_type = iface.get("machineType", "")
            parent = iface.get("parent", name)
            version = iface.get("apiVersion", "") or "0.0.1"
            unit = iface.get("units", "-")
            description = iface.get("description", "")

            entry = {
                "name": iface_name,
                "id": uid,
                "description": description,
                "access_type": access_type,
                "control": control,
                "mode": mode,
                "mode_value": mode_value,
                "version": version,
                "device_element": parent,
                "device_class": parent,
                "mac_type": mac_type,
                "standard": standard,
                "data_type": return_type_name.lower() if return_type_name == "array" else return_type_name,
                "unit": unit,
                "fil_dependent": fil_dep,
                "cycle_values": cycle_values,
            }

            # Array type
            arr = iface.get("arrayType")
            if arr and return_type_name == "array":
                fields = []
                for lit in arr.get("arrayLiterals", []):
                    ftype = lit.get("type", "INT")
                    fields.append({
                        "name": lit["name"],
                        "unit": lit.get("unit", "-"),
                        "type": ftype,
                        "data_type": _DTYPE_DEFAULTS.get(ftype, f"E{ftype}=0"),
                    })
                entry["array"] = {
                    "name": arr.get("arrayName", ""),
                    "description": arr.get("arrayDesc", ""),
                    "access_type": arr.get("interfaceAccessType", access_method),
                    "fields": fields,
                }

            interfaces.append(entry)

        provider_class = _build_provider_class(name)
        package = name.lower().replace("_", "")

        PLUGINS[name] = {
            "provider_name": f"{name} provider",
            "machine_name": name,
            "machine_id": machine_id,
            "provider_class": provider_class,
            "provider_package": package,
            "interfaces": interfaces,
        }


# ============================================================
# Filtered Plugin Builder
# ============================================================

def build_filtered_plugins(plugin_names, selected_interfaces=None):
    """Build a filtered plugins dict from plugin names and optional interface selection.

    Args:
        plugin_names: list of plugin name strings
        selected_interfaces: {plugin_name: [iface_name, ...]} or None (all interfaces)

    Returns:
        {plugin_name: plugin_data_with_filtered_interfaces}
    """
    result = {}
    for pname in plugin_names:
        p = copy.deepcopy(PLUGINS[pname])
        if selected_interfaces and pname in selected_interfaces:
            chosen = selected_interfaces[pname]
            p["interfaces"] = [i for i in p["interfaces"] if i["name"] in chosen]
        result[pname] = p
    return result


# ============================================================
# Template Generators
# ============================================================

def _xml_escape(s):
    """Minimal XML attribute escaping."""
    return str(s).replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace(">", "&gt;")


def gen_fgd(name, filtered_plugins, port):
    """Generate .fgd (Feature GUI Design) XML"""
    providers_xml = ""
    arrays_xml = ""
    array_idx = 0

    for pname, p in filtered_plugins.items():
        for iface in p["interfaces"]:
            cycle_values = iface["cycle_values"]
            cycles = "\n".join(f'        <cycleValues>{c}</cycleValues>' for c in cycle_values)
            cyclic_unit = cycle_values[0] if cycle_values else ""
            desc = _xml_escape(iface["description"])
            control = iface.get("control", "Subscribe")

            # attributeType depends on data_type
            has_array = "array" in iface and iface["data_type"] == "array"
            if has_array:
                attr_type_xml = f'\n        <attributeType xsi:type="fcal:ARRAY_TYPE" array="//@arrays.{array_idx}"/>'
            else:
                attr_type_xml = ""

            providers_xml += f'''  <providers fname="{p["provider_name"]}">
    <features fname="{p["machine_name"]}" machineID="{p["machine_id"]}">
      <attributes attributeControl="{control}" attributeName="{iface["name"]}" attributeID="{iface["id"]}" attributeDesc="{desc}" attributeStandard="{iface["standard"]}" attributeStandardID="" attributeArtifactUrl="" attributeMacType="{iface["mac_type"]}" attributeFILVersion="" attributeRelVersion="" attributeCreatedby="" attributeMode="{iface["mode"]}" attributeCyclicUnit="{cyclic_unit}" attributeState="Dynamic" attributeStage="RELEASED" attributeApiVersion="{iface["version"]}" attributeUpdateRate="Adhoc/Cyclic" attributeDeviceElement="{iface["device_element"]}" attributeDeviceClass="{iface["device_class"]}" attributeUnit="{iface["unit"]}" attributeDataType="{iface["data_type"]}" attributeFilDependent="{"YES" if iface["fil_dependent"] else "NO"}">{attr_type_xml}
{cycles}
      </attributes>
    </features>
  </providers>
'''
            if has_array:
                a = iface["array"]
                fields = ""
                for i, fld in enumerate(a["fields"]):
                    idx_attr = f' index="{i}"' if i > 0 else ""
                    fields += f'    <arrayLiterals{idx_attr} name="{fld["name"]}" unit="{fld["unit"]}" type="{fld["type"]}" dataType="{fld["data_type"]}"/>\n'
                arrays_xml += f'  <arrays name="{a["name"]}" description="{_xml_escape(a["description"])}" accessType="{a["access_type"]}">\n{fields}  </arrays>\n'
                array_idx += 1

    return f'''<?xml version="1.0" encoding="ASCII"?>
<fcal:Model xmi:version="2.0" xmlns:xmi="http://www.omg.org/XMI" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:fcal="www.bosch.com/fcal" featureName="{name}" featureVersion="{DEFAULT_VERSION}" featureAutoRun="false" featureUIType="CustomUI" featurePort="{port}" featureResFolderType="M">
{providers_xml}{arrays_xml}  <fIdentity/>
</fcal:Model>
'''


def gen_fsp(filtered_plugins):
    """Generate .fsp (Feature Spec) - provider class mappings"""
    lines = []
    for pname, p in filtered_plugins.items():
        key = f'{p["machine_name"]}_Provider'
        lines.append(f'{key}={p["provider_class"]}')
    return "\n".join(lines) + "\n"


def gen_manifest(name, filtered_plugins, port):
    """Generate Manifest.xml"""
    interfaces_xml = ""
    for pname, p in filtered_plugins.items():
        for iface in p["interfaces"]:
            interfaces_xml += f'''      <Interface isFilDependent="{"true" if iface["fil_dependent"] else "false"}" opt="false">
        <Name>{iface["name"]}</Name>
        <Description>{_xml_escape(iface["description"])}</Description>
        <Access_Type>{iface["access_type"]}</Access_Type>
        <Id>{iface["id"]}</Id>
        <OperationMode value="{iface["mode_value"]}">{iface["mode"]}</OperationMode>
        <Version>{iface["version"]}</Version>
      </Interface>
'''

    return f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<Feature>
  <Identity>
    <Brand> </Brand>
    <LegalEntity> </LegalEntity>
    <Company> </Company>
    <ProjectID> </ProjectID>
    <Name>{name}</Name>
    <FeatureType> </FeatureType>
    <FeatureDate> </FeatureDate>
    <FeatureID> </FeatureID>
    <License> </License>
    <Description> </Description>
    <Author> </Author>
    <Version>
      <Major>1</Major>
      <Minor>0</Minor>
      <Patch>0</Patch>
    </Version>
  </Identity>
  <UI>
    <Type>CustomUI</Type>
    <Port>{port}</Port>
    <Context>#!/app</Context>
    <QRScanner>false</QRScanner>
    <AndroidAppID> </AndroidAppID>
    <IOSAppID> </IOSAppID>
  </UI>
  <Dependencies>
    <Interfaces>
{interfaces_xml}    </Interfaces>
    <Libraries>
      <Library>
        <Name> </Name>
        <Version> </Version>
      </Library>
    </Libraries>
    <Development_Environment>
      <FCAL_Runtime_Version>{FCAL_RUNTIME_VERSION}</FCAL_Runtime_Version>
      <FD_Version>{FD_VERSION}</FD_Version>
      <Development_Tools>
        <Development_Tool>
          <Name> </Name>
          <Version> </Version>
          <TargetCompiler> </TargetCompiler>
        </Development_Tool>
      </Development_Tools>
    </Development_Environment>
    <External_Libraries>
      <External_Library>
        <Name> </Name>
        <Version>
          <Major> </Major>
          <Minor> </Minor>
          <Patch> </Patch>
        </Version>
      </External_Library>
    </External_Libraries>
  </Dependencies>
  <ContainerCharacteristics>
    <Name> </Name>
    <ContainerType> </ContainerType>
    <BasePackage> </BasePackage>
    <EntryPoint> </EntryPoint>
    <ExitPoint> </ExitPoint>
    <AutoStart> </AutoStart>
    <DataUpload_Support> </DataUpload_Support>
    <ExternalCloud_API_Support> </ExternalCloud_API_Support>
    <FGF_Integration_Support> </FGF_Integration_Support>
    <Version>
      <Major> </Major>
      <Minor> </Minor>
      <Patch> </Patch>
    </Version>
  </ContainerCharacteristics>
  <MachineStatus>
    <MachineState/>
    <MachineStateError/>
  </MachineStatus>
  <Installation>
    <Method>Docker</Method>
    <AutoInstall>true</AutoInstall>
    <Properties>
      <HasToBeBuilt>true</HasToBeBuilt>
      <DockerFile>Dockerfolder</DockerFile>
      <AutoRun>false</AutoRun>
      <ImageName> </ImageName>
      <FileSystemIn>/app/in/</FileSystemIn>
      <FileSystemOut>/app/out/</FileSystemOut>
      <Mount> </Mount>
    </Properties>
  </Installation>
  <Resource>
    <Cpu> </Cpu>
    <Memory> </Memory>
    <Space> </Space>
    <FolderType>M</FolderType>
  </Resource>
</Feature>
'''


def gen_fdproject_props(name, project_type="java"):
    """Generate FDProject.props"""
    now = datetime.now().strftime("%a %b %d %H:%M:%S %Z %Y")
    if project_type == "cpp":
        return f'''#{now}
CPP_APP_PATH="cmake|{name}_{name}"
CPP_SDK_PATH="cmake|{name}_CPP_SDK"
ecoreVersion="{FCAL_RUNTIME_VERSION}"
projectName="{name}"
version="{FD_VERSION}"
'''
    return f'''#{now}
JAVA_APP_PATH="mvn|{name}"
JAVA_SDK_PATH="mvn|com.bosch.fsp.{name}.gen"
ecoreVersion="{FCAL_RUNTIME_VERSION}"
projectName="{name}"
version="{FD_VERSION}"
'''


def gen_topic_mapping(filtered_plugins):
    """Generate topic_mapping.json"""
    mapping = {}
    for pname, p in filtered_plugins.items():
        machine = p["machine_name"]
        mapping[f"{machine}.machineconnect.sub"] = "/1/+"
        mapping[f"{machine}.machinedata.sub"] = "/0/+"
        for iface in p["interfaces"]:
            key = f'{machine}.{iface["name"][0].lower() + iface["name"][1:]}.sub'
            mapping[key] = f'/{iface["id"]}'
    return json.dumps({"topic_mapping": mapping}, indent=2) + "\n"


def gen_topic_prefixes():
    """Generate topic_prefixes.json"""
    return json.dumps({
        "topic_prefixes": {
            "FCAL2FIL_Publish": "fek",
            "FCAL2FIL_Subscribe": "fek"
        }
    }, indent=2) + "\n"


def gen_interface_extract(filtered_plugins):
    """Generate interface_extract.json"""
    interfaces = []
    for pname, p in filtered_plugins.items():
        for iface in p["interfaces"]:
            interfaces.append({
                "Device Element": iface["device_element"],
                "Description": iface["description"],
                "Update Rate": "Adhoc/Cyclic",
                "Device Class": iface["device_class"],
                "Parameters": {"Unit": iface["unit"], "Datatype": iface["data_type"]},
                "Version": iface["version"],
                "Standard DDI": "",
                "Access": "Read" if iface["access_type"] == "In" else "Write",
                "Standard": iface["standard"],
                "Machine Variant": iface["mac_type"],
                "ID": iface["id"],
                "Name": iface["name"]
            })
    return json.dumps({"interfaces": interfaces}, indent=2) + "\n"


def gen_machine_path(filtered_plugins):
    """Generate machine_path.json"""
    paths = {}
    for pname, p in filtered_plugins.items():
        paths[p["machine_name"]] = p["machine_name"]
    return json.dumps({"machine_path": paths}) + "\n"


def gen_eclipse_project(project_dir_name, nature="com.bosch.fsp.fdfcal.common.fdNature"):
    """Generate .project (Eclipse project descriptor)"""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
\t<name>{project_dir_name}</name>
\t<comment></comment>
\t<projects>
\t</projects>
\t<buildSpec>
\t</buildSpec>
\t<natures>
\t\t<nature>{nature}</nature>
\t</natures>
</projectDescription>
'''


def gen_feature_config(port):
    """Generate feature.config"""
    return json.dumps({
        "mqtt": {
            "host": "127.0.0.1", "port": 1883, "tls_port": 7335,
            "auth_type": "none", "username": "", "password": "",
            "ca_cert": "", "client_cert": "", "client_key": ""
        },
        "log": {
            "path": "./logs/", "backCount": 2, "maxBytes": 1000000,
            "level": "INFO", "type": "FILE", "stacktrace": "yes", "fcl_port": "6563"
        },
        "ui": {"customui_port": port, "fgf_port": 0},
        "fgf_stateRetention": {"table": 20, "chart": 20, "inputRate": 20},
        "featureId": "nevonex_feature",
        "deviceIp": "127.0.0.1",
        "env": "DEV",
        "fsmEnabled": False,
        "ssl_enabled_wsgi": False,
        "device_static_ip": "127.0.0.1",
        "folderPath": {
            "in":  {"rel": "./in/",   "abs": "/var/trans/featureid/incoming/"},
            "out": {"rel": "./out/",  "abs": "/var/trans/featureid/outgoing/"},
            "res": {"size": 5, "rel": "./disk/", "abs": "/var/trans/featureid/resources/"}
        },
        "fif": {"port": 6563}
    }, indent=2) + "\n"


def gen_cpp_feature_config(port):
    """Generate feature.config for C++ projects (relative paths for temp/disk)."""
    return json.dumps({
        "mqtt": {
            "host": "127.0.0.1", "port": 1883, "tls_port": 7335,
            "auth_type": "none", "username": "", "password": "",
            "ca_cert": "", "client_cert": "", "client_key": ""
        },
        "log": {
            "path": "../logs/", "backCount": 2, "maxBytes": 1000000,
            "level": "INFO", "type": "FILE", "stacktrace": "yes", "fcl_port": "6563"
        },
        "ui": {"customui_port": port, "fgf_port": 0},
        "fgf_stateRetention": {"table": 20, "chart": 20, "inputRate": 20},
        "featureId": "nevonex_feature",
        "deviceIp": "127.0.0.1",
        "env": "DEV",
        "fsmEnabled": False,
        "ssl_enabled_wsgi": False,
        "device_static_ip": "127.0.0.1",
        "folderPath": {
            "in":  {"rel": "./temp/download/", "abs": "/var/trans/featureid/incoming/"},
            "out": {"rel": "./temp/upload/",   "abs": "/var/trans/featureid/outgoing/"},
            "res": {"size": 5, "rel": "./disk/", "abs": "/var/trans/featureid/resources/"}
        },
        "fif": {"port": 6563}
    }, indent=2) + "\n"


def gen_app_pom(name):
    """Generate application pom.xml"""
    return f'''<project
    xmlns="http://maven.apache.org/POM/4.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>{name}.{name}</groupId>
    <artifactId>{name}</artifactId>
    <version>{DEFAULT_VERSION}</version>
    <build>
        <sourceDirectory>src</sourceDirectory>
        <resources>
            <resource>
                <directory>src</directory>
                <excludes>
                    <exclude>**/*.java</exclude>
                </excludes>
            </resource>
        </resources>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.10.1</version>
                <configuration>
                    <source>1.8</source>
                    <target>1.8</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-assembly-plugin</artifactId>
                <version>3.4.2</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>single</goal>
                        </goals>
                        <configuration>
                            <archive>
                                <manifest>
                                    <mainClass>
                                        com.bosch.nevonex.main.impl.ApplicationMain
                                    </mainClass>
                                </manifest>
                            </archive>
                            <descriptorRefs>
                                <descriptorRef>jar-with-dependencies</descriptorRef>
                            </descriptorRefs>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
    <dependencies>
        <dependency>
            <groupId>com.bosch.fsp</groupId>
            <artifactId>com.bosch.fsp.runtime</artifactId>
            <version>{FCAL_RUNTIME_VERSION}-SNAPSHOT</version>
        </dependency>
        <dependency>
            <groupId>com.bosch.fsp</groupId>
            <artifactId>{name}</artifactId>
            <version>{DEFAULT_VERSION}</version>
        </dependency>
        <dependency>
            <groupId>commons-io</groupId>
            <artifactId>commons-io</artifactId>
            <version>2.11.0</version>
        </dependency>
        <dependency>
            <groupId>com.google.code.gson</groupId>
            <artifactId>gson</artifactId>
            <version>2.9.0</version>
        </dependency>
        <dependency>
            <groupId>org.apache.logging.log4j</groupId>
            <artifactId>log4j-core</artifactId>
            <version>2.17.2</version>
        </dependency>
        <dependency>
            <groupId>org.apache.commons</groupId>
            <artifactId>commons-lang3</artifactId>
            <version>3.12.0</version>
        </dependency>
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <version>1.4.200</version>
        </dependency>
    </dependencies>
</project>'''


def gen_application_main(name, filtered_plugins):
    """Generate ApplicationMain.java scaffold matching SDK API."""
    pascal_name = name[0].upper() + name[1:]

    # Build plugin-specific imports and initializeMachineProviders body
    provider_imports = ""
    plugin_iface_imports = ""
    init_body = ""

    first = True
    for pname, p in filtered_plugins.items():
        provider_cls = p["provider_class"].rsplit(".", 1)[1]
        provider_pkg = p["provider_package"]
        field_name = pname[0].lower() + pname[1:]
        iface_type = f"I{pname}"

        provider_imports += f"import com.bosch.nevonex.{provider_pkg}.{iface_type};\n"
        provider_imports += f"import com.bosch.nevonex.{provider_pkg}.impl.{provider_cls};\n"

        prefix = "if" if first else "else if"
        init_body += f'''
        {prefix} (provider instanceof {provider_cls}) {{
            {iface_type} {field_name} = (({provider_cls}) (provider)).get{pname}();
            if ({field_name} != null) {{
                getController().set{pname}({field_name});
                FCALLogs.getInstance().log.debug("{provider_cls}   loaded " + (provider != null));
            }}
        }}
'''
        first = False

    return f'''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.logger.FCALLogs;

import com.bosch.fsp.runtime.feature.IMachineConnectListener;
import com.bosch.fsp.runtime.feature.IMachineProvider;

import com.bosch.fsp.runtime.feature.application.NEVONEXApplication;

import com.bosch.nevonex.common.HMIServicesEnum;
import com.bosch.nevonex.common.PlatformServicesEnum;
import com.bosch.nevonex.common.ProviderEnum;

import com.bosch.nevonex.customui.impl.UIWebServiceProvider;

import com.bosch.nevonex.main.IApplicationMain;

{provider_imports}
import java.util.List;

import org.eclipse.emf.ecore.EClass;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Application entry point for {name}.
 * Generated by fd-cli create.
 */
public class ApplicationMain extends NEVONEXApplication implements IApplicationMain {{

    @Override
    protected EClass eStaticClass() {{ return MainPackage.Literals.APPLICATION_MAIN; }}

    protected boolean timerTriggered = false;

    public boolean isTimerTriggered() {{ return timerTriggered; }}
    public void setTimerTriggered(boolean value) {{ timerTriggered = value; }}

    private {pascal_name} controller;

    protected ApplicationMain() {{
        super();
        setFeatureManager(new FeatureManagerListener());
        setiIgnitionStateListener(new IgnitionStateListener());
    }}

    public void setController({pascal_name} controller) {{
        this.controller = controller;
    }}

    public {pascal_name} getController() {{
        return controller;
    }}

    /**
     * Application Main class
     *
     * @param args arguments to be passed to the application if any
     * @throws Exception exception while running the application
     */
    public static void main(final String[] args) throws Exception {{
        try {{
            ApplicationMain sa = new ApplicationMain();
            sa.setFeatureID("");
            sa.setController(new {pascal_name}());

            List<ProviderEnum> providerValues = ProviderEnum.VALUES;
            String[] providerarr = new String[providerValues.size()];
            int index = 0;
            for (ProviderEnum providerEnum : providerValues) {{
                providerarr[index] = providerEnum.getName();
                index++;
            }}

            List<PlatformServicesEnum> pfServiceValues = PlatformServicesEnum.VALUES;
            String[] serviceNames = new String[pfServiceValues.size()];
            index = 0;
            for (PlatformServicesEnum pfsEnum : pfServiceValues) {{
                serviceNames[index] = pfsEnum.getName();
                index++;
            }}

            List<HMIServicesEnum> hmiServiceValues = HMIServicesEnum.VALUES;
            String[] hmiServiceNames = new String[hmiServiceValues.size()];
            index = 0;
            for (HMIServicesEnum hmiEnum : hmiServiceValues) {{
                hmiServiceNames[index] = hmiEnum.getLiteral();
                index++;
            }}

            sa.initialize(providerarr, serviceNames, hmiServiceNames);

            sa.addCustomUISupport();

            sa.addListenersForUserDefinedControls();

            sa.startProviders();

            sa.waitForStop();
        }} finally {{
            // exit the app
        }}
    }}

    @Override
    protected IMachineConnectListener getMachineConnectListener() {{
        return new MachineConnectListener();
    }}

    @Override
    public void onStart(IMachineProvider provider) {{
        initializeMachineProviders(provider);
    }}

    private void addCustomUISupport() throws Exception {{
        UIWebsocketEndPoint wsEndPoint = UIWebsocketEndPoint.getInstance();
        controller.setWsEndPoint(wsEndPoint);
        UIWebServiceProvider.getInstance().openWebsocket("/socket", wsEndPoint);
    }}

    public void addListenersForUserDefinedControls() {{
    }}

    public void initializeMachineProviders(IMachineProvider provider) {{
{init_body}
        addProcessTimer();
    }}

    public void addProcessTimer() {{
        if (!timerTriggered) {{
            ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
            if (getController() != null) {{
                scheduler.scheduleAtFixedRate(getController(), 0, 1, TimeUnit.SECONDS);
                timerTriggered = true;
            }}
        }} else {{
            FCALLogs.getInstance().log.debug("Timer already created.");
        }}
    }}
}}
'''


def gen_controller_class(name, filtered_plugins):
    """Generate the controller class ({Name}.java) with plugin fields."""
    pascal_name = name[0].upper() + name[1:]

    # Build fields, imports, getters/setters
    plugin_imports = ""
    fields = ""
    accessors = ""

    for pname, p in filtered_plugins.items():
        provider_pkg = p["provider_package"]
        iface_type = f"I{pname}"
        field_name = pname[0].lower() + pname[1:]

        plugin_imports += f"import com.bosch.nevonex.{provider_pkg}.{iface_type};\n"
        fields += f"    private {iface_type} {field_name};\n"
        accessors += f'''
    public {iface_type} get{pname}() {{
        return {field_name};
    }}

    public void set{pname}({iface_type} new{pname}) {{
        {field_name} = new{pname};
    }}
'''

    return f'''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.logger.FCALLogs;

{plugin_imports}
import com.bosch.nevonex.main.I{pascal_name};
import com.bosch.nevonex.main.IUIWebsocketEndPoint;

import org.apache.commons.lang3.exception.ExceptionUtils;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.impl.EObjectImpl;

/**
 * Controller class for {name}.
 * Generated by fd-cli create.
 */
public class {pascal_name} extends EObjectImpl implements I{pascal_name} {{

    @Override
    protected EClass eStaticClass() {{
        return MainPackage.Literals.{_to_upper_snake(pascal_name)};
    }}

{fields}    private IUIWebsocketEndPoint wsEndPoint;

    public {pascal_name}() {{
        super();
    }}

    @Override
    public synchronized void run() {{
        try {{
            // User logic here
            // wsEndPoint.broadcastMessage("message");
        }} catch (Exception e) {{
            FCALLogs.getInstance().log.error(ExceptionUtils.getRootCauseMessage(e));
        }}
    }}

    public IUIWebsocketEndPoint getWsEndPoint() {{
        return wsEndPoint;
    }}

    public void setWsEndPoint(IUIWebsocketEndPoint newWsEndPoint) {{
        wsEndPoint = newWsEndPoint;
    }}
{accessors}}}
'''


def gen_feature_manager_listener():
    """Generate FeatureManagerListener.java"""
    return '''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.logger.FCALLogs;

import com.bosch.fsp.runtime.feature.application.AbstractFeatureNotification;

import com.bosch.nevonex.main.IFeatureManagerListener;

import org.eclipse.emf.ecore.EClass;

/**
 * Feature manager notification listener.
 * Generated by fd-cli create.
 */
public class FeatureManagerListener extends AbstractFeatureNotification implements IFeatureManagerListener {

    public FeatureManagerListener() {
        super();
    }

    @Override
    protected EClass eStaticClass() { return MainPackage.Literals.FEATURE_MANAGER_LISTENER; }

    @Override
    public void handleFeatureStart(String message) {
        FCALLogs.getInstance().log.info("Feature started callback - " + message);
    }

    @Override
    public void handleFeatureStop(String message) {
        FCALLogs.getInstance().log.info("Feature is about to stop. Reason - " + message);
    }
}
'''


def gen_ignition_state_listener():
    """Generate IgnitionStateListener.java"""
    return '''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.runtime.feature.application.AbstractIgnitionStateListener;

import com.bosch.nevonex.main.IIgnitionStateListener;

import org.eclipse.emf.ecore.EClass;

/**
 * Ignition state listener.
 * Generated by fd-cli create.
 */
public class IgnitionStateListener extends AbstractIgnitionStateListener implements IIgnitionStateListener {

    public IgnitionStateListener() {
        super();
    }

    @Override
    protected EClass eStaticClass() { return MainPackage.Literals.IGNITION_STATE_LISTENER; }

    @Override
    public void handleIgnitionOn() {
        // Logic to be implemented for ignition On
    }

    @Override
    public void handleIgnitionOff() {
        // Logic to be implemented for ignition Off
    }
}
'''


def gen_machine_connect_listener():
    """Generate MachineConnectListener.java"""
    return '''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.logger.FCALLogs;

import com.bosch.fsp.runtime.feature.IMachine;
import com.bosch.fsp.runtime.feature.MachineDisConnectionInfo;

import com.bosch.fsp.runtime.feature.application.AbstractMachineConnectListener;

import com.bosch.nevonex.main.IMachineConnectListener;

import org.eclipse.emf.ecore.EClass;

/**
 * Machine connect/disconnect listener.
 * Generated by fd-cli create.
 */
public class MachineConnectListener extends AbstractMachineConnectListener implements IMachineConnectListener {

    public MachineConnectListener() {
        super();
    }

    @Override
    protected EClass eStaticClass() { return MainPackage.Literals.MACHINE_CONNECT_LISTENER; }

    @Override
    public void machineConnected(IMachine machine) throws Exception {
        String name = getMachineName(machine);
        int index = getMachineIndex(machine);
        if (index != -1) {
            FCALLogs.getInstance().log.info("machine '" + name + "' with index " + index + " connected.");
        } else {
            FCALLogs.getInstance().log.info("machine '" + name + "' connected.");
        }
    }

    @Override
    public void machineDisconnected(IMachine machine, MachineDisConnectionInfo info) throws Exception {
        String name = getMachineName(machine);
        int index = getMachineIndex(machine);
        if (index != -1) {
            FCALLogs.getInstance().log.info("machine '" + name + "' with index " + index + " disconnected. " + info);
        } else {
            FCALLogs.getInstance().log.info("machine '" + name + "' disconnected. " + info);
        }
    }
}
'''


def gen_ui_websocket_endpoint():
    """Generate UIWebsocketEndPoint.java"""
    return '''package com.bosch.nevonex.main.impl;

import com.bosch.fsp.logger.FCALLogs;

import com.bosch.fsp.runtime.feature.GracefulFeatureStop;

import com.bosch.nevonex.customui.impl.AbstractWebsocketEndPoint;

import com.bosch.nevonex.main.IUIWebsocketEndPoint;

import java.io.IOException;

import org.eclipse.emf.ecore.EClass;

import org.eclipse.jetty.websocket.api.Session;
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage;
import org.eclipse.jetty.websocket.api.annotations.WebSocket;

/**
 * WebSocket endpoint for custom UI communication.
 * Generated by fd-cli create.
 */
@WebSocket
public class UIWebsocketEndPoint extends AbstractWebsocketEndPoint implements IUIWebsocketEndPoint {

    @Override
    protected EClass eStaticClass() { return MainPackage.Literals.UI_WEBSOCKET_END_POINT; }

    private UIWebsocketEndPoint() {
        super();
    }

    private static UIWebsocketEndPoint instance = null;

    public static UIWebsocketEndPoint getInstance() {
        if (instance == null) {
            instance = new UIWebsocketEndPoint();
            instance.createTimerForHeartBeat();
        }
        return instance;
    }

    @OnWebSocketMessage
    public void message(Session session, String message) throws IOException {
        if (GracefulFeatureStop.getInstance().isFeatureStopped()) {
            FCALLogs.getInstance().log
                    .debug("The feature is going to be stopped, so HMI messages cannot be processed.");
            return;
        }
        FCALLogs.getInstance().log.debug(message);
    }
}
'''


# ============================================================
# EMF Helper Utilities
# ============================================================

def _to_upper_snake(name):
    """CamelCase to UPPER_SNAKE_CASE: GPSPlugin->GPS_PLUGIN, TestJava->TEST_JAVA"""
    s = re.sub(r'([a-z])([A-Z])', r'\1_\2', name)
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', s)
    return s.upper()


def _emf_field_name(name):
    """CamelCase to Java field name (EMF convention).
    GPSPlugin->gpsPlugin, IMU->imu, TestJava->testJava"""
    i = 0
    while i < len(name) and name[i].isupper():
        i += 1
    if i > 1 and i < len(name):
        return name[:i-1].lower() + name[i-1:]
    elif i >= len(name):
        return name.lower()
    else:
        return name[0].lower() + name[1:]


# ============================================================
# Dynamic Plugin SDK Package Generators
# ============================================================

def _write_java(filepath, content):
    """Write a Java source file."""
    with open(filepath, "w") as f:
        f.write(content)


def _gen_plugin_interface(name, pkg):
    """Generate I{Name}.java — minimal plugin interface."""
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg};

import com.bosch.fsp.runtime.feature.IMachine;

import com.bosch.nevonex.common.ITopicObject;

import com.bosch.nevonex.types.IPropertyChange;

/**
 * @generated
 */
public interface I{name} extends ITopicObject, IPropertyChange, IMachine {{
}} // I{name}
'''


def _gen_plugin_provider_interface(name, pkg):
    """Generate I{Name}Provider.java — provider interface."""
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg};

import com.bosch.fsp.runtime.feature.IMachineProvider;

import com.bosch.nevonex.types.IPropertyChange;

/**
 * @generated
 */
public interface I{name}Provider extends IPropertyChange, IMachineProvider {{
\tI{name} get{name}();
}} // I{name}Provider
'''


def _gen_plugin_factory_interface(name, pkg):
    """Generate I{PkgPascal}Factory.java — factory interface."""
    pkg_pascal = pkg[0].upper() + pkg[1:]
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg};

/**
 * @generated
 */
public interface I{pkg_pascal}Factory {{
\tI{pkg_pascal}Factory INSTANCE = com.bosch.nevonex.{pkg}.impl.{pkg_pascal}Factory.eINSTANCE;
\tI{name} create{name}();
\tI{name}Provider create{name}Provider();
}} //I{pkg_pascal}Factory
'''


def _gen_plugin_impl(name, pkg):
    """Generate {Name}.java — plugin implementation (extends TopicObject)."""
    pkg_pascal = pkg[0].upper() + pkg[1:]
    upper = _to_upper_snake(name)
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg}.impl;

import com.bosch.fsp.runtime.feature.IMachine;

import com.bosch.nevonex.common.impl.TopicObject;

import com.bosch.nevonex.fcb.IFCALController;

import com.bosch.nevonex.{pkg}.I{name};

import com.bosch.nevonex.types.IPropertyChange;

import com.bosch.nevonex.types.impl.TypesPackage;

import java.beans.PropertyChangeEvent;
import java.beans.PropertyChangeListener;

import java.lang.reflect.InvocationTargetException;

import java.util.Collection;
import java.util.List;

import org.eclipse.emf.common.util.BasicEList;
import org.eclipse.emf.common.util.EList;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.InternalEObject;

import org.eclipse.emf.ecore.util.EDataTypeUniqueEList;

/**
 * @generated
 */
public class {name} extends TopicObject implements I{name} {{
\tprotected EList<PropertyChangeListener> listeners;
\tprotected IFCALController controller;

\tprotected {name}() {{
\t\tsuper();
\t}}

\t@Override
\tprotected EClass eStaticClass() {{
\t\treturn {pkg_pascal}Package.Literals.{upper};
\t}}

\tpublic List<PropertyChangeListener> getListeners() {{
\t\tif (listeners == null) {{
\t\t\tlisteners = new EDataTypeUniqueEList<PropertyChangeListener>(PropertyChangeListener.class, this,
\t\t\t\t\t{pkg_pascal}Package.{upper}__LISTENERS);
\t\t}}
\t\treturn listeners;
\t}}

\tpublic IFCALController getController() {{
\t\tif (controller != null && controller.eIsProxy()) {{
\t\t\tInternalEObject oldController = (InternalEObject) controller;
\t\t\tcontroller = (IFCALController) eResolveProxy(oldController);
\t\t}}
\t\treturn controller;
\t}}

\tpublic IFCALController basicGetController() {{
\t\treturn controller;
\t}}

\tprivate void setController(IFCALController newController) {{
\t\tcontroller = newController;
\t}}

\tpublic void addPropertyChangeListener(PropertyChangeListener listener) {{
\t\tif (listeners == null) {{
\t\t\tlisteners = new BasicEList<>();
\t\t}}
\t\tlisteners.add(listener);
\t}}

\tpublic void removePropertyChangeListener(PropertyChangeListener listener) {{
\t\tif (listeners != null) {{
\t\t\tlisteners.remove(listener);
\t\t}}
\t}}

\tpublic void notifyPropertyChange(String name, Object oldValue, Object newValue) {{
\t\tif (listeners != null) {{
\t\t\tfor (PropertyChangeListener listener : this.listeners) {{
\t\t\t\tlistener.propertyChange(new PropertyChangeEvent(this, name, oldValue, newValue));
\t\t\t}}
\t\t}}
\t}}

\t@Override
\tpublic Object eGet(int featureID, boolean resolve, boolean coreType) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}__LISTENERS:
\t\t\treturn getListeners();
\t\tcase {pkg_pascal}Package.{upper}__CONTROLLER:
\t\t\tif (resolve)
\t\t\t\treturn getController();
\t\t\treturn basicGetController();
\t\t}}
\t\treturn super.eGet(featureID, resolve, coreType);
\t}}

\t@SuppressWarnings("unchecked")
\t@Override
\tpublic void eSet(int featureID, Object newValue) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}__LISTENERS:
\t\t\tgetListeners().clear();
\t\t\tgetListeners().addAll((Collection<? extends PropertyChangeListener>) newValue);
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}__CONTROLLER:
\t\t\tsetController((IFCALController) newValue);
\t\t\treturn;
\t\t}}
\t\tsuper.eSet(featureID, newValue);
\t}}

\t@Override
\tpublic void eUnset(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}__LISTENERS:
\t\t\tgetListeners().clear();
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}__CONTROLLER:
\t\t\tsetController((IFCALController) null);
\t\t\treturn;
\t\t}}
\t\tsuper.eUnset(featureID);
\t}}

\t@Override
\tpublic boolean eIsSet(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}__LISTENERS:
\t\t\treturn listeners != null && !listeners.isEmpty();
\t\tcase {pkg_pascal}Package.{upper}__CONTROLLER:
\t\t\treturn controller != null;
\t\t}}
\t\treturn super.eIsSet(featureID);
\t}}

\t@Override
\tpublic int eBaseStructuralFeatureID(int derivedFeatureID, Class<?> baseClass) {{
\t\tif (baseClass == IPropertyChange.class) {{
\t\t\tswitch (derivedFeatureID) {{
\t\t\tcase {pkg_pascal}Package.{upper}__LISTENERS:
\t\t\t\treturn TypesPackage.PROPERTY_CHANGE__LISTENERS;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\tif (baseClass == IMachine.class) {{
\t\t\tswitch (derivedFeatureID) {{
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eBaseStructuralFeatureID(derivedFeatureID, baseClass);
\t}}

\t@Override
\tpublic int eDerivedStructuralFeatureID(int baseFeatureID, Class<?> baseClass) {{
\t\tif (baseClass == IPropertyChange.class) {{
\t\t\tswitch (baseFeatureID) {{
\t\t\tcase TypesPackage.PROPERTY_CHANGE__LISTENERS:
\t\t\t\treturn {pkg_pascal}Package.{upper}__LISTENERS;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\tif (baseClass == IMachine.class) {{
\t\t\tswitch (baseFeatureID) {{
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eDerivedStructuralFeatureID(baseFeatureID, baseClass);
\t}}

\t@Override
\tpublic int eDerivedOperationID(int baseOperationID, Class<?> baseClass) {{
\t\tif (baseClass == IPropertyChange.class) {{
\t\t\tswitch (baseOperationID) {{
\t\t\tcase TypesPackage.PROPERTY_CHANGE___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\t\treturn {pkg_pascal}Package.{upper}___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER;
\t\t\tcase TypesPackage.PROPERTY_CHANGE___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\t\treturn {pkg_pascal}Package.{upper}___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER;
\t\t\tcase TypesPackage.PROPERTY_CHANGE___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT:
\t\t\t\treturn {pkg_pascal}Package.{upper}___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\tif (baseClass == IMachine.class) {{
\t\t\tswitch (baseOperationID) {{
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eDerivedOperationID(baseOperationID, baseClass);
\t}}

\t@Override
\tpublic Object eInvoke(int operationID, EList<?> arguments) throws InvocationTargetException {{
\t\tswitch (operationID) {{
\t\tcase {pkg_pascal}Package.{upper}___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\taddPropertyChangeListener((PropertyChangeListener) arguments.get(0));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\tremovePropertyChangeListener((PropertyChangeListener) arguments.get(0));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT:
\t\t\tnotifyPropertyChange((String) arguments.get(0), arguments.get(1), arguments.get(2));
\t\t\treturn null;
\t\t}}
\t\treturn super.eInvoke(operationID, arguments);
\t}}

\t@Override
\tpublic String toString() {{
\t\tif (eIsProxy())
\t\t\treturn super.toString();
\t\tStringBuffer result = new StringBuffer(super.toString());
\t\tresult.append(" (listeners: ");
\t\tresult.append(listeners);
\t\tresult.append(')');
\t\treturn result.toString();
\t}}
}} //{name}
'''


def _gen_plugin_provider_impl(name, pkg):
    """Generate {Name}Provider.java — provider implementation (most complex)."""
    pkg_pascal = pkg[0].upper() + pkg[1:]
    upper = _to_upper_snake(name)
    field = _emf_field_name(name)
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg}.impl;

import com.bosch.fsp.logger.FCALLogs;
import com.bosch.fsp.logger.LoggerConstants;

import com.bosch.fsp.runtime.feature.IMachine;
import com.bosch.fsp.runtime.feature.IMachineProvider;
import com.bosch.fsp.runtime.feature.MachineConnectionInfo;

import com.bosch.fsp.runtime.feature.exception.CommunicationException;
import com.bosch.fsp.runtime.feature.exception.MachineInitException;
import com.bosch.fsp.runtime.feature.exception.NevonexException;

import com.bosch.fsp.runtime.util.internal.Util;

import com.bosch.nevonex.common.IAbsolutePosition;
import com.bosch.nevonex.common.ITopicObject;

import com.bosch.nevonex.common.impl.CommonFactory;

import com.bosch.nevonex.fcb.IFCALController;

import com.bosch.nevonex.fcb.impl.ConnectionFactory;
import com.bosch.nevonex.fcb.impl.FCALController;
import com.bosch.nevonex.fcb.impl.PublishConnectionFactory;

import com.bosch.nevonex.{pkg}.I{name};
import com.bosch.nevonex.{pkg}.I{name}Provider;

import com.bosch.nevonex.types.IArrayType;
import com.bosch.nevonex.types.IPropertyChange;

import com.bosch.nevonex.types.impl.TypesPackage;

import java.beans.PropertyChangeEvent;
import java.beans.PropertyChangeListener;

import java.io.InputStream;

import java.lang.reflect.InvocationTargetException;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.lang3.exception.ExceptionUtils;

import org.eclipse.emf.common.notify.NotificationChain;

import org.eclipse.emf.common.util.BasicEList;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.Enumerator;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EClassifier;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.InternalEObject;

import org.eclipse.emf.ecore.impl.EObjectImpl;

import org.eclipse.emf.ecore.util.EDataTypeUniqueEList;

import org.w3c.dom.Element;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * @generated
 */
public class {name}Provider extends EObjectImpl implements I{name}Provider {{
\tprotected EList<PropertyChangeListener> listeners;
\tprotected IFCALController controller;
\tprotected I{name} {field};

\tpublic {name}Provider() {{
\t\tsuper();
\t}}

\tprivate Map<String, ITopicObject> indexToObjectMap = new HashMap<>();

\tpublic boolean acceptDom(String root) {{
\t\treturn "{pkg}".equalsIgnoreCase(root);
\t}}

\tprivate void updateAttributes(EObject impObject, Node childNode, Map<String, EClassifier> classifiersMap,
\t\t\tMap<String, EStructuralFeature> featuresMap, int machineIndex, String path) {{
\t\tNodeList childNodes = childNode.getChildNodes();
\t\tfor (int i = 0; i < childNodes.getLength(); i++) {{
\t\t\tNode childItem = childNodes.item(i);
\t\t\tif (childItem.getNodeType() != Node.ELEMENT_NODE) {{
\t\t\t\tcontinue;
\t\t\t}}
\t\t\tString itemName = childItem.getNodeName().toLowerCase();
\t\t\tif (!classifiersMap.containsKey(itemName) && featuresMap.containsKey(itemName)) {{
\t\t\t\tString value = Util.getChildNodeValue((Element) childNode, itemName);
\t\t\t\ttry {{
\t\t\t\t\tEStructuralFeature childEStructuralFeature = featuresMap.get(itemName);
\t\t\t\t\tString dataType = childEStructuralFeature.getEType().getName();
\t\t\t\t\tif (dataType.equalsIgnoreCase("EInt")) {{
\t\t\t\t\t\tInteger integer = Integer.valueOf(value);
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, integer);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("EFloat")) {{
\t\t\t\t\t\tFloat floatVal = Float.valueOf(value);
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, floatVal);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("EBoolean")) {{
\t\t\t\t\t\tBoolean bool;
\t\t\t\t\t\ttry {{
\t\t\t\t\t\t\tint booleanValue = Integer.parseInt(value);
\t\t\t\t\t\t\tbool = (booleanValue == 1) ? true : false;
\t\t\t\t\t\t}} catch (NumberFormatException nfe) {{
\t\t\t\t\t\t\tbool = Boolean.valueOf(value.toString());
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, bool);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("EDouble")) {{
\t\t\t\t\t\tDouble doubleVal = Double.valueOf(value);
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, doubleVal);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("ELong")) {{
\t\t\t\t\t\tLong longVal = Long.valueOf(value);
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, longVal);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("EString")) {{
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, value);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("IntArray")) {{
\t\t\t\t\t\tString[] splitArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\tint[] valueArray = new int[splitArray.length];
\t\t\t\t\t\tfor (int j = 0; j < valueArray.length; j++) {{
\t\t\t\t\t\t\tvalueArray[j] = Integer.valueOf(splitArray[j]);
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, valueArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("FloatArray")) {{
\t\t\t\t\t\tString[] splitArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\tfloat[] valueArray = new float[splitArray.length];
\t\t\t\t\t\tfor (int j = 0; j < valueArray.length; j++) {{
\t\t\t\t\t\t\tvalueArray[j] = Float.valueOf(splitArray[j]);
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, valueArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("DoubleArray")) {{
\t\t\t\t\t\tString[] splitArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\tdouble[] valueArray = new double[splitArray.length];
\t\t\t\t\t\tfor (int j = 0; j < valueArray.length; j++) {{
\t\t\t\t\t\t\tvalueArray[j] = Double.valueOf(splitArray[j]);
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, valueArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("LongArray")) {{
\t\t\t\t\t\tString[] splitArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\tlong[] valueArray = new long[splitArray.length];
\t\t\t\t\t\tfor (int j = 0; j < valueArray.length; j++) {{
\t\t\t\t\t\t\tvalueArray[j] = Long.valueOf(splitArray[j]);
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, valueArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("BooleanArray")) {{
\t\t\t\t\t\tString[] splitArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\tboolean[] booleanArray = new boolean[splitArray.length];
\t\t\t\t\t\tint[] valueArray = new int[splitArray.length];
\t\t\t\t\t\tfor (int j = 0; j < valueArray.length; j++) {{
\t\t\t\t\t\t\ttry {{
\t\t\t\t\t\t\t\tint booleanValue = Integer.parseInt(splitArray[j]);
\t\t\t\t\t\t\t\tbooleanArray[j] = (booleanValue == 1) ? true : false;
\t\t\t\t\t\t\t}} catch (NumberFormatException nfe) {{
\t\t\t\t\t\t\t\tbooleanArray[j] = Boolean.valueOf(splitArray[j]);
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, booleanArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("StringArray")) {{
\t\t\t\t\t\tString[] valueArray = value.replace("[", "").replace("]", "").trim().split(",");
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, valueArray);
\t\t\t\t\t}} else if (dataType.equalsIgnoreCase("AbsolutePosition")) {{
\t\t\t\t\t\tIAbsolutePosition abPos = CommonFactory.eINSTANCE.createAbsolutePosition();
\t\t\t\t\t\tNamedNodeMap map = childItem.getAttributes();
\t\t\t\t\t\tfor (int index = 0; index < map.getLength(); index++) {{
\t\t\t\t\t\t\tNode nodeItem = map.item(index);
\t\t\t\t\t\t\tif (map.item(index).getNodeName().equalsIgnoreCase("alt")) {{
\t\t\t\t\t\t\t\tDouble doubleVal = Double.valueOf(nodeItem.getNodeValue());
\t\t\t\t\t\t\t\tabPos.setAltitude(doubleVal);
\t\t\t\t\t\t\t}} else if (map.item(index).getNodeName().equalsIgnoreCase("lan")) {{
\t\t\t\t\t\t\t\tDouble doubleVal = Double.valueOf(nodeItem.getNodeValue());
\t\t\t\t\t\t\t\tabPos.setLongitude(doubleVal);
\t\t\t\t\t\t\t}} else if (map.item(index).getNodeName().equalsIgnoreCase("lat")) {{
\t\t\t\t\t\t\t\tDouble doubleVal = Double.valueOf(nodeItem.getNodeValue());
\t\t\t\t\t\t\t\tabPos.setLatitude(doubleVal);
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t}}
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, abPos);
\t\t\t\t\t}} else if (Enumerator.class
\t\t\t\t\t\t\t.isAssignableFrom(childEStructuralFeature.getEType().getInstanceClass())) {{
\t\t\t\t\t\tObject newObj = childEStructuralFeature.getEType().getInstanceClass()
\t\t\t\t\t\t\t\t.getMethod("get", int.class)
\t\t\t\t\t\t\t\t.invoke(childEStructuralFeature.getEType().eClass().getClass(), Integer.valueOf(value));
\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, newObj);
\t\t\t\t\t}} else if (IArrayType.class
\t\t\t\t\t\t\t.isAssignableFrom(childEStructuralFeature.getEType().getInstanceClass())) {{
\t\t\t\t\t\tEObject eObject = childEStructuralFeature.getEType().getEPackage().getEFactoryInstance()
\t\t\t\t\t\t\t\t.create((EClass) childEStructuralFeature.getEType());
\t\t\t\t\t\tif (eObject instanceof IArrayType) {{
\t\t\t\t\t\t\tNodeList list = childItem.getChildNodes();
\t\t\t\t\t\t\tfor (int j = 0; j < list.getLength(); j++) {{
\t\t\t\t\t\t\t\tNode item = list.item(j);
\t\t\t\t\t\t\t\tif (item.getNodeType() == Node.ELEMENT_NODE) {{
\t\t\t\t\t\t\t\t\tString nodeName = item.getNodeName();
\t\t\t\t\t\t\t\t\t((IArrayType) eObject).setArrayFeature(nodeName, item.getTextContent());
\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\timpObject.eSet(childEStructuralFeature, eObject);
\t\t\t\t\t\t}}
\t\t\t\t\t}}
\t\t\t\t}} catch (Exception e) {{
\t\t\t\t\tFCALLogs.getInstance().log.error(LoggerConstants.LOG_SDK_PREFIX + itemName + " for '"
\t\t\t\t\t\t\t+ impObject.getClass().getSimpleName() + "' is not defined properly. " + value);
\t\t\t\t}}
\t\t\t}}
\t\t}}
\t\tif (impObject instanceof ITopicObject) {{
\t\t\t((ITopicObject) impObject).setIndex(machineIndex);
\t\t\tindexToObjectMap.put(path, (ITopicObject) impObject);
\t\t}}
\t}}

\tpublic void notifyPropertyChange(Object source, String name, Object oldValue, Object newValue) {{
\t\tif (listeners != null) {{
\t\t\tfor (PropertyChangeListener listener : this.listeners) {{
\t\t\t\tlistener.propertyChange(new PropertyChangeEvent(source, name, oldValue, newValue));
\t\t\t}}
\t\t}}
\t}}

\t@Override
\tprotected EClass eStaticClass() {{
\t\treturn {pkg_pascal}Package.Literals.{upper}_PROVIDER;
\t}}

\tpublic List<PropertyChangeListener> getListeners() {{
\t\tif (listeners == null) {{
\t\t\tlisteners = new EDataTypeUniqueEList<PropertyChangeListener>(PropertyChangeListener.class, this,
\t\t\t\t\t{pkg_pascal}Package.{upper}_PROVIDER__LISTENERS);
\t\t}}
\t\treturn listeners;
\t}}

\tpublic IFCALController getController() {{
\t\tif (controller != null && controller.eIsProxy()) {{
\t\t\tInternalEObject oldController = (InternalEObject) controller;
\t\t\tcontroller = (IFCALController) eResolveProxy(oldController);
\t\t}}
\t\treturn controller;
\t}}

\tpublic IFCALController basicGetController() {{
\t\treturn controller;
\t}}

\tprivate void setController(IFCALController newController) {{
\t\tcontroller = newController;
\t}}

\tpublic I{name} get{name}() {{
\t\treturn {field};
\t}}

\tpublic NotificationChain basicSet{name}(I{name} new{name}, NotificationChain msgs) {{
\t\t{field} = new{name};
\t\treturn msgs;
\t}}

\tprivate void set{name}(I{name} new{name}) {{
\t\tif (new{name} != {field}) {{
\t\t\tNotificationChain msgs = null;
\t\t\tif ({field} != null)
\t\t\t\tmsgs = ((InternalEObject) {field}).eInverseRemove(this,
\t\t\t\t\t\tEOPPOSITE_FEATURE_BASE - {pkg_pascal}Package.{upper}_PROVIDER__{upper}, null, msgs);
\t\t\tif (new{name} != null)
\t\t\t\tmsgs = ((InternalEObject) new{name}).eInverseAdd(this,
\t\t\t\t\t\tEOPPOSITE_FEATURE_BASE - {pkg_pascal}Package.{upper}_PROVIDER__{upper}, null, msgs);
\t\t\tmsgs = basicSet{name}(new{name}, msgs);
\t\t\tif (msgs != null)
\t\t\t\tmsgs.dispatch();
\t\t}}
\t}}

\tpublic void createMachines(InputStream stream) throws MachineInitException {{
\t\ttry {{
\t\t\tElement root = Util.getDomRootElement(stream);
\t\t\tList<Node> secondLevelNodeList = new ArrayList<Node>();
\t\t\tif ("root".equalsIgnoreCase(root.getNodeName())) {{
\t\t\t\tNodeList childNodes = root.getChildNodes();
\t\t\t\tfor (int i = 0; i < childNodes.getLength(); i++) {{
\t\t\t\t\tNode secondLevelNode = childNodes.item(i);
\t\t\t\t\tif (secondLevelNode.getNodeType() == Node.ELEMENT_NODE
\t\t\t\t\t\t\t&& acceptDom(secondLevelNode.getNodeName())) {{
\t\t\t\t\t\tsecondLevelNodeList.add(secondLevelNode);
\t\t\t\t\t}}
\t\t\t\t}}
\t\t\t}} else {{
\t\t\t\tif (root.getNodeType() == Node.ELEMENT_NODE && acceptDom(root.getNodeName())) {{
\t\t\t\t\tsecondLevelNodeList.add(root);
\t\t\t\t}}
\t\t\t}}
\t\t\tif (secondLevelNodeList.isEmpty()) {{
\t\t\t\tFCALLogs.getInstance().log.debug(LoggerConstants.LOG_SDK_PREFIX
\t\t\t\t\t\t+ "Dom is not acceptable for this provider " + getClass().getSimpleName());
\t\t\t\treturn;
\t\t\t}}
\t\t\tFCALLogs.getInstance().log.debug(LoggerConstants.LOG_SDK_PREFIX + "Creating {name}s...");

\t\t\tMap<String, EClassifier> classifiersMap = new HashMap<>();
\t\t\tEList<EClassifier> classifiers = eClass().getEPackage().getEClassifiers();
\t\t\tfor (EClassifier eClassifier : classifiers) {{
\t\t\t\tclassifiersMap.put(eClassifier.getName().toLowerCase(), eClassifier);
\t\t\t}}
\t\t\tObject newValue = null;
\t\t\tfor (Node secondNode : secondLevelNodeList) {{
\t\t\t\tint index = 0;
\t\t\t\tString value = Util.getChildNodeValue((Element) secondNode, "index");
\t\t\t\ttry {{
\t\t\t\t\tindex = Integer.valueOf(value);
\t\t\t\t}} catch (NumberFormatException e) {{
\t\t\t\t\tFCALLogs.getInstance().log.debug(LoggerConstants.LOG_SDK_PREFIX
\t\t\t\t\t\t\t+ "Index is not available for the machine " + secondNode.getNodeName());
\t\t\t\t}}

\t\t\t\tString name = "{pkg}";
\t\t\t\tif (classifiersMap.containsKey(name) && classifiersMap.get(name) != null) {{
\t\t\t\t\tEClassifier classifier = classifiersMap.get(name);
\t\t\t\t\tEObject impObject = eClass().getEPackage().getEFactoryInstance().create((EClass) classifier);
\t\t\t\t\tEStructuralFeature feature = null;
\t\t\t\t\tEList<EReference> references = eClass().getEReferences();
\t\t\t\t\tfor (EReference reference : references) {{
\t\t\t\t\t\tif (reference.getEType().equals(classifier)) {{
\t\t\t\t\t\t\tfeature = reference;
\t\t\t\t\t\t\tbreak;
\t\t\t\t\t\t}}
\t\t\t\t\t}}
\t\t\t\t\tif (feature != null) {{
\t\t\t\t\t\tif (feature.isMany()) {{
\t\t\t\t\t\t\tObject object = this.eGet(feature);
\t\t\t\t\t\t\tif (object instanceof Collection<?>) {{
\t\t\t\t\t\t\t\tCollection collection = (Collection) object;
\t\t\t\t\t\t\t\tboolean found = false;
\t\t\t\t\t\t\t\tfor (Object object2 : collection) {{
\t\t\t\t\t\t\t\t\tif (object2 instanceof ITopicObject
\t\t\t\t\t\t\t\t\t\t\t&& ((ITopicObject) object2).getIndex() == index) {{
\t\t\t\t\t\t\t\t\t\tfound = true;
\t\t\t\t\t\t\t\t\t\tbreak;
\t\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t\tif (found) {{
\t\t\t\t\t\t\t\t\tcontinue;
\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t\tif (newValue == null) {{
\t\t\t\t\t\t\t\t\tnewValue = new ArrayList<>();
\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t\t((List) newValue).add(impObject);
\t\t\t\t\t\t\t\tcollection.add(impObject);
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t}} else {{
\t\t\t\t\t\t\tObject object = this.eGet(feature);
\t\t\t\t\t\t\tif (object instanceof ITopicObject && ((ITopicObject) object).getIndex() == index) {{
\t\t\t\t\t\t\t\tcontinue;
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\tthis.eSet(feature, impObject);
\t\t\t\t\t\t\tnewValue = impObject;
\t\t\t\t\t\t}}
\t\t\t\t\t}}
\t\t\t\t\tEStructuralFeature controllerFeature = impObject.eClass().getEStructuralFeature("controller");
\t\t\t\t\tif (controllerFeature != null) {{
\t\t\t\t\t\timpObject.eSet(controllerFeature, controller);
\t\t\t\t\t}}
\t\t\t\t\tEList<EStructuralFeature> features = impObject.eClass().getEStructuralFeatures();
\t\t\t\t\tMap<String, EStructuralFeature> featuresMap = new HashMap<>();
\t\t\t\t\tfor (EStructuralFeature feature2 : features) {{
\t\t\t\t\t\tfeaturesMap.put(feature2.getName().toLowerCase(), feature2);
\t\t\t\t\t}}
\t\t\t\t\tString path = name + "/" + index;
\t\t\t\t\tupdateAttributes(impObject, secondNode, classifiersMap, featuresMap, index, path);
\t\t\t\t\tconstructChildTypes(secondNode, impObject, path);
\t\t\t\t}}
\t\t\t}}
\t\t\tif (newValue != null) {{
\t\t\t\tnotifyPropertyChange("root", null, newValue);
\t\t\t}}
\t\t}} catch (Exception e) {{
\t\t\tFCALLogs.getInstance().log.error(LoggerConstants.LOG_SDK_PREFIX
\t\t\t\t\t+ "Exception while initializing machine data: " + ExceptionUtils.getRootCauseMessage(e));
\t\t\tthrow new MachineInitException("Exception while initializing machine data", e);
\t\t}}
\t}}

\tpublic void constructChildTypes(Node parent, Object parentObj, String path) {{
\t\tif (parentObj instanceof EObject) {{
\t\t\tMap<String, EClassifier> classifiersMap = new HashMap<>();
\t\t\tEList<EClassifier> classifiers = eClass().getEPackage().getEClassifiers();
\t\t\tfor (EClassifier eClassifier : classifiers) {{
\t\t\t\tclassifiersMap.put(eClassifier.getName().toLowerCase(), eClassifier);
\t\t\t}}
\t\t\tEObject parentMO = (EObject) parentObj;
\t\t\tNodeList childNodes = parent.getChildNodes();
\t\t\tfor (int i = 0; i < childNodes.getLength(); i++) {{
\t\t\t\tNode childItem = childNodes.item(i);
\t\t\t\tif (childItem.getNodeType() == Node.ELEMENT_NODE) {{
\t\t\t\t\tString itemName = childItem.getNodeName().toLowerCase();
\t\t\t\t\tif (classifiersMap.containsKey(itemName) && classifiersMap.get(itemName) != null) {{
\t\t\t\t\t\tEClassifier childClassifier = classifiersMap.get(itemName);
\t\t\t\t\t\tEObject childObj = eClass().getEPackage().getEFactoryInstance()
\t\t\t\t\t\t\t\t.create((EClass) childClassifier);
\t\t\t\t\t\tEStructuralFeature feature = null;
\t\t\t\t\t\tEList<EReference> references = parentMO.eClass().getEReferences();
\t\t\t\t\t\tfor (EReference reference : references) {{
\t\t\t\t\t\t\tif (reference.getEType().equals(childClassifier)) {{
\t\t\t\t\t\t\t\tfeature = reference;
\t\t\t\t\t\t\t\tbreak;
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t}}
\t\t\t\t\t\tif (feature != null) {{
\t\t\t\t\t\t\tif (feature.isMany()) {{
\t\t\t\t\t\t\t\tObject object = parentMO.eGet(feature);
\t\t\t\t\t\t\t\tif (object instanceof Collection<?>) {{
\t\t\t\t\t\t\t\t\t((Collection) object).add(childObj);
\t\t\t\t\t\t\t\t}}
\t\t\t\t\t\t\t}} else {{
\t\t\t\t\t\t\t\tparentMO.eSet(feature, childObj);
\t\t\t\t\t\t\t}}
\t\t\t\t\t\t}}
\t\t\t\t\t\tEList<EStructuralFeature> features = childObj.eClass().getEStructuralFeatures();
\t\t\t\t\t\tMap<String, EStructuralFeature> featuresMap = new HashMap<>();
\t\t\t\t\t\tfor (EStructuralFeature feature2 : features) {{
\t\t\t\t\t\t\tfeaturesMap.put(feature2.getName().toLowerCase(), feature2);
\t\t\t\t\t\t}}
\t\t\t\t\t\tint index = 0;
\t\t\t\t\t\tString value = Util.getChildNodeValue((Element) childItem, "index");
\t\t\t\t\t\ttry {{
\t\t\t\t\t\t\tindex = Integer.valueOf(value);
\t\t\t\t\t\t}} catch (NumberFormatException e) {{
\t\t\t\t\t\t\tFCALLogs.getInstance().log.debug(LoggerConstants.LOG_SDK_PREFIX
\t\t\t\t\t\t\t\t\t+ " Index is not available for the machine " + childItem.getNodeName());
\t\t\t\t\t\t}}
\t\t\t\t\t\tString fullPath = path + "/" + itemName + "/" + index;
\t\t\t\t\t\tupdateAttributes(childObj, childItem, classifiersMap, featuresMap, index, fullPath);
\t\t\t\t\t\tEStructuralFeature controllerFeature = childObj.eClass().getEStructuralFeature("controller");
\t\t\t\t\t\tif (controllerFeature != null) {{
\t\t\t\t\t\t\tchildObj.eSet(controllerFeature, controller);
\t\t\t\t\t\t}}
\t\t\t\t\t\tconstructChildTypes(childItem, childObj, fullPath);
\t\t\t\t\t}}
\t\t\t\t}}
\t\t\t}}
\t\t}}
\t}}

\tpublic void initMachineProvider() throws MachineInitException {{
\t\ttry {{
\t\t\tthis.controller = new FCALController();
\t\t\tConnectionFactory.getInstance().getProviders().add(this);
\t\t\tPublishConnectionFactory.getInstance();
\t\t}} catch (Exception e) {{
\t\t\tthrow new MachineInitException("Exception while initializing the machine provider.", e);
\t\t}}
\t}}

\tpublic void startMachineProvider() throws MachineInitException {{
\t\ttry {{
\t\t\tConnectionFactory.getInstance().initConnectionFactory();
\t\t\tPublishConnectionFactory.getInstance().initConnectionFactory();
\t\t}} catch (CommunicationException e) {{
\t\t\tthrow new MachineInitException(e.getMessage(), e);
\t\t}}
\t}}

\tpublic ITopicObject getTopicElement(String index) {{
\t\treturn indexToObjectMap.get(index);
\t}}

\tpublic void onConnectionStatusChange(IMachine machine, MachineConnectionInfo info) {{
\t\tnotifyPropertyChange(machine, MachineConnectionInfo.CONNECT_PROPERTY, null, info);
\t}}

\tpublic void stopMachineProvider() throws NevonexException {{
\t\ttry {{
\t\t\tConnectionFactory.getInstance().terminateConnectionFactory();
\t\t\tPublishConnectionFactory.getInstance().terminateConnectionFactory();
\t\t}} catch (Exception e) {{
\t\t\tthrow new NevonexException(e.getMessage(), e);
\t\t}}
\t}}

\tpublic void addPropertyChangeListener(PropertyChangeListener listener) {{
\t\tif (listeners == null) {{
\t\t\tlisteners = new BasicEList<>();
\t\t}}
\t\tlisteners.add(listener);
\t}}

\tpublic void removePropertyChangeListener(PropertyChangeListener listener) {{
\t\tif (listeners != null) {{
\t\t\tlisteners.remove(listener);
\t\t}}
\t}}

\tpublic void notifyPropertyChange(String name, Object oldValue, Object newValue) {{
\t\tif (listeners != null) {{
\t\t\tfor (PropertyChangeListener listener : this.listeners) {{
\t\t\t\tlistener.propertyChange(new PropertyChangeEvent(this, name, oldValue, newValue));
\t\t\t}}
\t\t}}
\t}}

\t@Override
\tpublic NotificationChain eInverseRemove(InternalEObject otherEnd, int featureID, NotificationChain msgs) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__{upper}:
\t\t\treturn basicSet{name}(null, msgs);
\t\t}}
\t\treturn super.eInverseRemove(otherEnd, featureID, msgs);
\t}}

\t@Override
\tpublic Object eGet(int featureID, boolean resolve, boolean coreType) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__LISTENERS:
\t\t\treturn getListeners();
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER:
\t\t\tif (resolve)
\t\t\t\treturn getController();
\t\t\treturn basicGetController();
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__{upper}:
\t\t\treturn get{name}();
\t\t}}
\t\treturn super.eGet(featureID, resolve, coreType);
\t}}

\t@SuppressWarnings("unchecked")
\t@Override
\tpublic void eSet(int featureID, Object newValue) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__LISTENERS:
\t\t\tgetListeners().clear();
\t\t\tgetListeners().addAll((Collection<? extends PropertyChangeListener>) newValue);
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER:
\t\t\tsetController((IFCALController) newValue);
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__{upper}:
\t\t\tset{name}((I{name}) newValue);
\t\t\treturn;
\t\t}}
\t\tsuper.eSet(featureID, newValue);
\t}}

\t@Override
\tpublic void eUnset(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__LISTENERS:
\t\t\tgetListeners().clear();
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER:
\t\t\tsetController((IFCALController) null);
\t\t\treturn;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__{upper}:
\t\t\tset{name}((I{name}) null);
\t\t\treturn;
\t\t}}
\t\tsuper.eUnset(featureID);
\t}}

\t@Override
\tpublic boolean eIsSet(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__LISTENERS:
\t\t\treturn listeners != null && !listeners.isEmpty();
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER:
\t\t\treturn controller != null;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__{upper}:
\t\t\treturn {field} != null;
\t\t}}
\t\treturn super.eIsSet(featureID);
\t}}

\t@Override
\tpublic int eBaseStructuralFeatureID(int derivedFeatureID, Class<?> baseClass) {{
\t\tif (baseClass == IMachineProvider.class) {{
\t\t\tswitch (derivedFeatureID) {{
\t\t\tcase {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER:
\t\t\t\treturn TypesPackage.IMACHINE_PROVIDER__CONTROLLER;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eBaseStructuralFeatureID(derivedFeatureID, baseClass);
\t}}

\t@Override
\tpublic int eDerivedStructuralFeatureID(int baseFeatureID, Class<?> baseClass) {{
\t\tif (baseClass == IMachineProvider.class) {{
\t\t\tswitch (baseFeatureID) {{
\t\t\tcase TypesPackage.IMACHINE_PROVIDER__CONTROLLER:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER__CONTROLLER;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eDerivedStructuralFeatureID(baseFeatureID, baseClass);
\t}}

\t@Override
\tpublic int eDerivedOperationID(int baseOperationID, Class<?> baseClass) {{
\t\tif (baseClass == IMachineProvider.class) {{
\t\t\tswitch (baseOperationID) {{
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___CREATE_MACHINES__INPUTSTREAM:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___CREATE_MACHINES__INPUTSTREAM;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___CONSTRUCT_CHILD_TYPES__NODE_OBJECT_STRING:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___CONSTRUCT_CHILD_TYPES__NODE_OBJECT_STRING;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___INIT_MACHINE_PROVIDER:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___INIT_MACHINE_PROVIDER;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___START_MACHINE_PROVIDER:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___START_MACHINE_PROVIDER;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___GET_TOPIC_ELEMENT__STRING:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___GET_TOPIC_ELEMENT__STRING;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___ON_CONNECTION_STATUS_CHANGE__IMACHINE_MACHINECONNECTIONINFO:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___ON_CONNECTION_STATUS_CHANGE__IMACHINE_MACHINECONNECTIONINFO;
\t\t\tcase TypesPackage.IMACHINE_PROVIDER___STOP_MACHINE_PROVIDER:
\t\t\t\treturn {pkg_pascal}Package.{upper}_PROVIDER___STOP_MACHINE_PROVIDER;
\t\t\tdefault:
\t\t\t\treturn -1;
\t\t\t}}
\t\t}}
\t\treturn super.eDerivedOperationID(baseOperationID, baseClass);
\t}}

\t@Override
\tpublic Object eInvoke(int operationID, EList<?> arguments) throws InvocationTargetException {{
\t\tswitch (operationID) {{
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___CREATE_MACHINES__INPUTSTREAM:
\t\t\ttry {{
\t\t\t\tcreateMachines((InputStream) arguments.get(0));
\t\t\t\treturn null;
\t\t\t}} catch (Throwable throwable) {{
\t\t\t\tthrow new InvocationTargetException(throwable);
\t\t\t}}
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___CONSTRUCT_CHILD_TYPES__NODE_OBJECT_STRING:
\t\t\tconstructChildTypes((Node) arguments.get(0), (Object) arguments.get(1), (String) arguments.get(2));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___INIT_MACHINE_PROVIDER:
\t\t\ttry {{
\t\t\t\tinitMachineProvider();
\t\t\t\treturn null;
\t\t\t}} catch (Throwable throwable) {{
\t\t\t\tthrow new InvocationTargetException(throwable);
\t\t\t}}
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___START_MACHINE_PROVIDER:
\t\t\ttry {{
\t\t\t\tstartMachineProvider();
\t\t\t\treturn null;
\t\t\t}} catch (Throwable throwable) {{
\t\t\t\tthrow new InvocationTargetException(throwable);
\t\t\t}}
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___GET_TOPIC_ELEMENT__STRING:
\t\t\treturn getTopicElement((String) arguments.get(0));
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___ON_CONNECTION_STATUS_CHANGE__IMACHINE_MACHINECONNECTIONINFO:
\t\t\tonConnectionStatusChange((IMachine) arguments.get(0), (MachineConnectionInfo) arguments.get(1));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___STOP_MACHINE_PROVIDER:
\t\t\ttry {{
\t\t\t\tstopMachineProvider();
\t\t\t\treturn null;
\t\t\t}} catch (Throwable throwable) {{
\t\t\t\tthrow new InvocationTargetException(throwable);
\t\t\t}}
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\taddPropertyChangeListener((PropertyChangeListener) arguments.get(0));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER:
\t\t\tremovePropertyChangeListener((PropertyChangeListener) arguments.get(0));
\t\t\treturn null;
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT:
\t\t\tnotifyPropertyChange((String) arguments.get(0), arguments.get(1), arguments.get(2));
\t\t\treturn null;
\t\t}}
\t\treturn super.eInvoke(operationID, arguments);
\t}}

\t@Override
\tpublic String toString() {{
\t\tif (eIsProxy())
\t\t\treturn super.toString();
\t\tStringBuffer result = new StringBuffer(super.toString());
\t\tresult.append(" (listeners: ");
\t\tresult.append(listeners);
\t\tresult.append(')');
\t\treturn result.toString();
\t}}
}} //{name}Provider
'''


def _gen_plugin_factory_impl(name, pkg):
    """Generate {PkgPascal}Factory.java — factory implementation."""
    pkg_pascal = pkg[0].upper() + pkg[1:]
    upper = _to_upper_snake(name)
    field = _emf_field_name(name)
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg}.impl;

import com.bosch.nevonex.{pkg}.*;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;

import org.eclipse.emf.ecore.impl.EFactoryImpl;

import org.eclipse.emf.ecore.plugin.EcorePlugin;

/**
 * @generated
 */
public class {pkg_pascal}Factory extends EFactoryImpl implements I{pkg_pascal}Factory {{
\tpublic static final {pkg_pascal}Factory eINSTANCE = init();

\tpublic static {pkg_pascal}Factory init() {{
\t\ttry {{
\t\t\t{pkg_pascal}Factory the{pkg_pascal}Factory = ({pkg_pascal}Factory) EPackage.Registry.INSTANCE
\t\t\t\t\t.getEFactory({pkg_pascal}Package.eNS_URI);
\t\t\tif (the{pkg_pascal}Factory != null) {{
\t\t\t\treturn the{pkg_pascal}Factory;
\t\t\t}}
\t\t}} catch (Exception exception) {{
\t\t\tEcorePlugin.INSTANCE.log(exception);
\t\t}}
\t\treturn new {pkg_pascal}Factory();
\t}}

\tpublic {pkg_pascal}Factory() {{
\t\tsuper();
\t}}

\t@Override
\tpublic EObject create(EClass eClass) {{
\t\tswitch (eClass.getClassifierID()) {{
\t\tcase {pkg_pascal}Package.{upper}:
\t\t\treturn create{name}();
\t\tcase {pkg_pascal}Package.{upper}_PROVIDER:
\t\t\treturn create{name}Provider();
\t\tdefault:
\t\t\tthrow new IllegalArgumentException("The class '" + eClass.getName() + "' is not a valid classifier");
\t\t}}
\t}}

\tpublic I{name} create{name}() {{
\t\t{name} {field} = new {name}();
\t\treturn {field};
\t}}

\tpublic I{name}Provider create{name}Provider() {{
\t\t{name}Provider {field}Provider = new {name}Provider();
\t\treturn {field}Provider;
\t}}

\tpublic {pkg_pascal}Package get{pkg_pascal}Package() {{
\t\treturn ({pkg_pascal}Package) getEPackage();
\t}}

\t@Deprecated
\tpublic static {pkg_pascal}Package getPackage() {{
\t\treturn {pkg_pascal}Package.eINSTANCE;
\t}}
}} //{pkg_pascal}Factory
'''


def _gen_plugin_package_impl(name, pkg):
    """Generate {PkgPascal}Package.java — EMF package metadata."""
    pkg_pascal = pkg[0].upper() + pkg[1:]
    upper = _to_upper_snake(name)
    field = _emf_field_name(name)
    return f'''/**
Copyright (c) Robert Bosch GmbH. All rights reserved.
*/
package com.bosch.nevonex.{pkg}.impl;

import com.bosch.nevonex.common.impl.CommonPackage;

import com.bosch.nevonex.customui.impl.CustomuiPackage;

import com.bosch.nevonex.exception.impl.ExceptionPackage;

import com.bosch.nevonex.fcal.impl.FcalPackage;

import com.bosch.nevonex.fcb.impl.FcbPackage;

import com.bosch.nevonex.{pkg}.I{name};
import com.bosch.nevonex.{pkg}.I{name}Provider;
import com.bosch.nevonex.{pkg}.I{pkg_pascal}Factory;

import com.bosch.nevonex.types.impl.TypesPackage;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EReference;

import org.eclipse.emf.ecore.impl.EPackageImpl;

/**
 * @generated
 */
public class {pkg_pascal}Package extends EPackageImpl {{
\tpublic static final String eNAME = "{pkg}";
\tpublic static final String eNS_URI = "com.bosch.nevonex.{pkg}";
\tpublic static final String eNS_PREFIX = "{pkg}";
\tpublic static final {pkg_pascal}Package eINSTANCE = com.bosch.nevonex.{pkg}.impl.{pkg_pascal}Package.init();

\tpublic static final int {upper} = 0;
\tpublic static final int {upper}__INDEX = CommonPackage.TOPIC_OBJECT__INDEX;
\tpublic static final int {upper}__LISTENERS = CommonPackage.TOPIC_OBJECT_FEATURE_COUNT + 0;
\tpublic static final int {upper}__CONTROLLER = CommonPackage.TOPIC_OBJECT_FEATURE_COUNT + 1;
\tpublic static final int {upper}_FEATURE_COUNT = CommonPackage.TOPIC_OBJECT_FEATURE_COUNT + 2;
\tpublic static final int {upper}___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER = CommonPackage.TOPIC_OBJECT_OPERATION_COUNT + 0;
\tpublic static final int {upper}___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER = CommonPackage.TOPIC_OBJECT_OPERATION_COUNT + 1;
\tpublic static final int {upper}___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT = CommonPackage.TOPIC_OBJECT_OPERATION_COUNT + 2;
\tpublic static final int {upper}_OPERATION_COUNT = CommonPackage.TOPIC_OBJECT_OPERATION_COUNT + 3;

\tpublic static final int {upper}_PROVIDER = 1;
\tpublic static final int {upper}_PROVIDER__LISTENERS = TypesPackage.PROPERTY_CHANGE__LISTENERS;
\tpublic static final int {upper}_PROVIDER__CONTROLLER = TypesPackage.PROPERTY_CHANGE_FEATURE_COUNT + 0;
\tpublic static final int {upper}_PROVIDER__{upper} = TypesPackage.PROPERTY_CHANGE_FEATURE_COUNT + 1;
\tpublic static final int {upper}_PROVIDER_FEATURE_COUNT = TypesPackage.PROPERTY_CHANGE_FEATURE_COUNT + 2;
\tpublic static final int {upper}_PROVIDER___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER = TypesPackage.PROPERTY_CHANGE___ADD_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER;
\tpublic static final int {upper}_PROVIDER___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER = TypesPackage.PROPERTY_CHANGE___REMOVE_PROPERTY_CHANGE_LISTENER__PROPERTYCHANGELISTENER;
\tpublic static final int {upper}_PROVIDER___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT = TypesPackage.PROPERTY_CHANGE___NOTIFY_PROPERTY_CHANGE__STRING_OBJECT_OBJECT;
\tpublic static final int {upper}_PROVIDER___CREATE_MACHINES__INPUTSTREAM = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 0;
\tpublic static final int {upper}_PROVIDER___CONSTRUCT_CHILD_TYPES__NODE_OBJECT_STRING = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 1;
\tpublic static final int {upper}_PROVIDER___INIT_MACHINE_PROVIDER = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 2;
\tpublic static final int {upper}_PROVIDER___START_MACHINE_PROVIDER = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 3;
\tpublic static final int {upper}_PROVIDER___GET_TOPIC_ELEMENT__STRING = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 4;
\tpublic static final int {upper}_PROVIDER___ON_CONNECTION_STATUS_CHANGE__IMACHINE_MACHINECONNECTIONINFO = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 5;
\tpublic static final int {upper}_PROVIDER___STOP_MACHINE_PROVIDER = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 6;
\tpublic static final int {upper}_PROVIDER_OPERATION_COUNT = TypesPackage.PROPERTY_CHANGE_OPERATION_COUNT + 7;

\tprivate EClass {field}EClass = null;
\tprivate EClass {field}ProviderEClass = null;

\tprivate {pkg_pascal}Package() {{
\t\tsuper(eNS_URI, ((EFactory) I{pkg_pascal}Factory.INSTANCE));
\t}}

\tprivate static boolean isInited = false;

\tpublic static {pkg_pascal}Package init() {{
\t\tif (isInited)
\t\t\treturn ({pkg_pascal}Package) EPackage.Registry.INSTANCE.getEPackage({pkg_pascal}Package.eNS_URI);

\t\tObject registered{pkg_pascal}Package = EPackage.Registry.INSTANCE.get(eNS_URI);
\t\t{pkg_pascal}Package the{pkg_pascal}Package = registered{pkg_pascal}Package instanceof {pkg_pascal}Package
\t\t\t\t? ({pkg_pascal}Package) registered{pkg_pascal}Package
\t\t\t\t: new {pkg_pascal}Package();

\t\tisInited = true;

\t\tObject registeredPackage = EPackage.Registry.INSTANCE.getEPackage(CommonPackage.eNS_URI);
\t\tCommonPackage theCommonPackage = (CommonPackage) (registeredPackage instanceof CommonPackage ? registeredPackage
\t\t\t\t: CommonPackage.eINSTANCE);
\t\tregisteredPackage = EPackage.Registry.INSTANCE.getEPackage(FcbPackage.eNS_URI);
\t\tFcbPackage theFcbPackage = (FcbPackage) (registeredPackage instanceof FcbPackage ? registeredPackage
\t\t\t\t: FcbPackage.eINSTANCE);
\t\tregisteredPackage = EPackage.Registry.INSTANCE.getEPackage(TypesPackage.eNS_URI);
\t\tTypesPackage theTypesPackage = (TypesPackage) (registeredPackage instanceof TypesPackage ? registeredPackage
\t\t\t\t: TypesPackage.eINSTANCE);
\t\tregisteredPackage = EPackage.Registry.INSTANCE.getEPackage(FcalPackage.eNS_URI);
\t\tFcalPackage theFcalPackage = (FcalPackage) (registeredPackage instanceof FcalPackage ? registeredPackage
\t\t\t\t: FcalPackage.eINSTANCE);
\t\tregisteredPackage = EPackage.Registry.INSTANCE.getEPackage(ExceptionPackage.eNS_URI);
\t\tExceptionPackage theExceptionPackage = (ExceptionPackage) (registeredPackage instanceof ExceptionPackage
\t\t\t\t? registeredPackage
\t\t\t\t: ExceptionPackage.eINSTANCE);
\t\tregisteredPackage = EPackage.Registry.INSTANCE.getEPackage(CustomuiPackage.eNS_URI);
\t\tCustomuiPackage theCustomuiPackage = (CustomuiPackage) (registeredPackage instanceof CustomuiPackage
\t\t\t\t? registeredPackage
\t\t\t\t: CustomuiPackage.eINSTANCE);

\t\tthe{pkg_pascal}Package.createPackageContents();
\t\ttheCommonPackage.createPackageContents();
\t\ttheFcbPackage.createPackageContents();
\t\ttheTypesPackage.createPackageContents();
\t\ttheFcalPackage.createPackageContents();
\t\ttheExceptionPackage.createPackageContents();
\t\ttheCustomuiPackage.createPackageContents();

\t\tthe{pkg_pascal}Package.initializePackageContents();
\t\ttheCommonPackage.initializePackageContents();
\t\ttheFcbPackage.initializePackageContents();
\t\ttheTypesPackage.initializePackageContents();
\t\ttheFcalPackage.initializePackageContents();
\t\ttheExceptionPackage.initializePackageContents();
\t\ttheCustomuiPackage.initializePackageContents();

\t\tthe{pkg_pascal}Package.freeze();

\t\tEPackage.Registry.INSTANCE.put({pkg_pascal}Package.eNS_URI, the{pkg_pascal}Package);
\t\treturn the{pkg_pascal}Package;
\t}}

\tpublic EClass get{name}() {{
\t\treturn {field}EClass;
\t}}

\tpublic EReference get{name}_Controller() {{
\t\treturn (EReference) {field}EClass.getEStructuralFeatures().get(0);
\t}}

\tpublic EClass get{name}Provider() {{
\t\treturn {field}ProviderEClass;
\t}}

\tpublic EReference get{name}Provider_{name}() {{
\t\treturn (EReference) {field}ProviderEClass.getEStructuralFeatures().get(0);
\t}}

\tpublic I{pkg_pascal}Factory get{pkg_pascal}Factory() {{
\t\treturn (I{pkg_pascal}Factory) getEFactoryInstance();
\t}}

\tprivate boolean isCreated = false;

\tpublic void createPackageContents() {{
\t\tif (isCreated)
\t\t\treturn;
\t\tisCreated = true;

\t\t{field}EClass = createEClass({upper});
\t\tcreateEReference({field}EClass, {upper}__CONTROLLER);

\t\t{field}ProviderEClass = createEClass({upper}_PROVIDER);
\t\tcreateEReference({field}ProviderEClass, {upper}_PROVIDER__{upper});
\t}}

\tprivate boolean isInitialized = false;

\tpublic void initializePackageContents() {{
\t\tif (isInitialized)
\t\t\treturn;
\t\tisInitialized = true;

\t\tsetName(eNAME);
\t\tsetNsPrefix(eNS_PREFIX);
\t\tsetNsURI(eNS_URI);

\t\tCommonPackage theCommonPackage = (CommonPackage) EPackage.Registry.INSTANCE.getEPackage(CommonPackage.eNS_URI);
\t\tTypesPackage theTypesPackage = (TypesPackage) EPackage.Registry.INSTANCE.getEPackage(TypesPackage.eNS_URI);
\t\tFcbPackage theFcbPackage = (FcbPackage) EPackage.Registry.INSTANCE.getEPackage(FcbPackage.eNS_URI);

\t\t{field}EClass.getESuperTypes().add(theCommonPackage.getTopicObject());
\t\t{field}EClass.getESuperTypes().add(theTypesPackage.getPropertyChange());
\t\t{field}EClass.getESuperTypes().add(theTypesPackage.getIMachine());
\t\t{field}ProviderEClass.getESuperTypes().add(theTypesPackage.getPropertyChange());
\t\t{field}ProviderEClass.getESuperTypes().add(theTypesPackage.getIMachineProvider());

\t\tinitEClass({field}EClass, I{name}.class, "{name}", !IS_ABSTRACT, !IS_INTERFACE,
\t\t\t\tIS_GENERATED_INSTANCE_CLASS);
\t\tinitEReference(get{name}_Controller(), theFcbPackage.getFCALController(), null, "controller", null, 0, 1,
\t\t\t\tI{name}.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, !IS_COMPOSITE, IS_RESOLVE_PROXIES,
\t\t\t\t!IS_UNSETTABLE, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);

\t\tinitEClass({field}ProviderEClass, I{name}Provider.class, "{name}Provider", !IS_ABSTRACT, !IS_INTERFACE,
\t\t\t\tIS_GENERATED_INSTANCE_CLASS);
\t\tinitEReference(get{name}Provider_{name}(), this.get{name}(), null, "{field}", null, 0, 1,
\t\t\t\tI{name}Provider.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, IS_COMPOSITE, !IS_RESOLVE_PROXIES,
\t\t\t\t!IS_UNSETTABLE, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);

\t\tcreateResource(eNS_URI);
\t}}

\tpublic interface Literals {{
\t\tpublic static final EClass {upper} = eINSTANCE.get{name}();
\t\tpublic static final EReference {upper}__CONTROLLER = eINSTANCE.get{name}_Controller();
\t\tpublic static final EClass {upper}_PROVIDER = eINSTANCE.get{name}Provider();
\t\tpublic static final EReference {upper}_PROVIDER__{upper} = eINSTANCE.get{name}Provider_{name}();
\t}}
}} //{pkg_pascal}Package
'''


def generate_plugin_sdk_packages(dst_src_dir, filtered_plugins):
    """Generate SDK packages for plugins not already present in the reference gen."""
    for pname, pdata in filtered_plugins.items():
        pkg = pdata["provider_package"]
        pkg_dir = os.path.join(dst_src_dir, "com", "bosch", "nevonex", pkg)
        if os.path.exists(pkg_dir):
            continue  # Already exists in reference (e.g. gpsplugin)

        # Create package directories
        os.makedirs(pkg_dir, exist_ok=True)
        impl_dir = os.path.join(pkg_dir, "impl")
        os.makedirs(impl_dir, exist_ok=True)

        pkg_pascal = pkg[0].upper() + pkg[1:]

        # Interface files (3)
        _write_java(os.path.join(pkg_dir, f"I{pname}.java"),
                     _gen_plugin_interface(pname, pkg))
        _write_java(os.path.join(pkg_dir, f"I{pname}Provider.java"),
                     _gen_plugin_provider_interface(pname, pkg))
        _write_java(os.path.join(pkg_dir, f"I{pkg_pascal}Factory.java"),
                     _gen_plugin_factory_interface(pname, pkg))

        # Implementation files (4)
        _write_java(os.path.join(impl_dir, f"{pname}.java"),
                     _gen_plugin_impl(pname, pkg))
        _write_java(os.path.join(impl_dir, f"{pname}Provider.java"),
                     _gen_plugin_provider_impl(pname, pkg))
        _write_java(os.path.join(impl_dir, f"{pkg_pascal}Factory.java"),
                     _gen_plugin_factory_impl(pname, pkg))
        _write_java(os.path.join(impl_dir, f"{pkg_pascal}Package.java"),
                     _gen_plugin_package_impl(pname, pkg))

        print(f"    Generated SDK package: com.bosch.nevonex.{pkg}/ (7 Java files)")


# ============================================================
# EMF Interface Generators
# ============================================================

def gen_iface_application_main():
    """Generate IApplicationMain.java"""
    return '''package com.bosch.nevonex.main;

import com.bosch.fsp.runtime.feature.IMachineProvider;

import org.eclipse.emf.ecore.EObject;

/** @generated */
public interface IApplicationMain extends EObject {
\tboolean isTimerTriggered();
\tvoid setTimerTriggered(boolean value);
\tvoid addListenersForUserDefinedControls();
\tvoid initializeMachineProviders(IMachineProvider provider);
\tvoid addProcessTimer();
} // IApplicationMain
'''


def gen_iface_application_input_data(filtered_plugins):
    """Generate IApplicationInputData.java (plugin-dependent)."""
    imports = ""
    methods = ""
    for pname, p in filtered_plugins.items():
        pkg = p["provider_package"]
        iface = f"I{pname}"
        imports += f"import com.bosch.nevonex.{pkg}.{iface};\n"
        methods += f"\t{iface} get{pname}();\n"
        methods += f"\tvoid set{pname}({iface} value);\n"
    return f'''package com.bosch.nevonex.main;

{imports}
import org.eclipse.emf.ecore.EObject;

/** @generated */
public interface IApplicationInputData extends EObject {{
{methods}}} // IApplicationInputData
'''


def gen_iface_controller(name):
    """Generate I{Name}.java (controller interface)."""
    pascal = name[0].upper() + name[1:]
    return f'''package com.bosch.nevonex.main;

/** @generated */
public interface I{pascal} extends Runnable, IApplicationInputData {{
\tIUIWebsocketEndPoint getWsEndPoint();
\tvoid setWsEndPoint(IUIWebsocketEndPoint value);
}} // I{pascal}
'''


def gen_iface_feature_manager_listener():
    """Generate IFeatureManagerListener.java"""
    return '''package com.bosch.nevonex.main;

import org.eclipse.emf.ecore.EObject;

/** @generated */
public interface IFeatureManagerListener extends EObject {
} // IFeatureManagerListener
'''


def gen_iface_ignition_state_listener():
    """Generate IIgnitionStateListener.java"""
    return '''package com.bosch.nevonex.main;

import org.eclipse.emf.ecore.EObject;

/** @generated */
public interface IIgnitionStateListener extends EObject {
} // IIgnitionStateListener
'''


def gen_iface_machine_connect_listener():
    """Generate IMachineConnectListener.java"""
    return '''package com.bosch.nevonex.main;

import org.eclipse.emf.ecore.EObject;

/** @generated */
public interface IMachineConnectListener extends EObject {
} // IMachineConnectListener
'''


def gen_iface_ui_websocket_endpoint():
    """Generate IUIWebsocketEndPoint.java"""
    return '''package com.bosch.nevonex.main;

import com.bosch.nevonex.customui.IAbstractWebsocketEndPoint;

/** @generated */
public interface IUIWebsocketEndPoint extends IAbstractWebsocketEndPoint {
} // IUIWebsocketEndPoint
'''


def gen_iface_main_factory(name):
    """Generate IMainFactory.java"""
    pascal = name[0].upper() + name[1:]
    return f'''package com.bosch.nevonex.main;

/** @generated */
public interface IMainFactory {{
\tIMainFactory INSTANCE = com.bosch.nevonex.main.impl.MainFactory.eINSTANCE;
\tIApplicationMain createApplicationMain();
\tIApplicationInputData createApplicationInputData();
\tI{pascal} create{pascal}();
\tIFeatureManagerListener createFeatureManagerListener();
\tIMachineConnectListener createMachineConnectListener();
\tIIgnitionStateListener createIgnitionStateListener();
\tIUIWebsocketEndPoint createUIWebsocketEndPoint();
\tISampleGetService createSampleGetService();
\tISamplePostService createSamplePostService();
\tISamplePutService createSamplePutService();
\tISampleDeleteService createSampleDeleteService();
}} //IMainFactory
'''


def gen_iface_sample_service(name, method):
    """Generate ISample{Method}Service.java (Get/Post/Put/Delete)."""
    pascal = name[0].upper() + name[1:]
    cls = f"Sample{method}Service"
    return f'''package com.bosch.nevonex.main;

import com.bosch.nevonex.customui.INevonexRoute;

/** @generated */
public interface I{cls} extends INevonexRoute {{
\tI{pascal} getController();
\tvoid setController(I{pascal} value);
}} // I{cls}
'''


# ============================================================
# EMF Impl Generators (new classes)
# ============================================================

def gen_application_input_data(filtered_plugins):
    """Generate ApplicationInputData.java (plugin-dependent)."""
    plugins = []
    for pname, p in filtered_plugins.items():
        plugins.append({
            "name": pname,
            "iface": f"I{pname}",
            "package": p["provider_package"],
            "field": _emf_field_name(pname),
            "upper_snake": _to_upper_snake(pname),
        })

    imports = ""
    for pl in plugins:
        imports += f"import com.bosch.nevonex.{pl['package']}.{pl['iface']};\n"

    fields = ""
    accessors = ""
    eget_cases = ""
    eset_cases = ""
    eunset_cases = ""
    eisset_cases = ""

    for i, pl in enumerate(plugins):
        fields += f"\tprotected {pl['iface']} {pl['field']};\n"
        accessors += f'''
\tpublic {pl['iface']} get{pl['name']}() {{
\t\tif ({pl['field']} != null && ((EObject) {pl['field']}).eIsProxy()) {{
\t\t\tInternalEObject old = (InternalEObject) {pl['field']};
\t\t\t{pl['field']} = ({pl['iface']}) eResolveProxy(old);
\t\t}}
\t\treturn {pl['field']};
\t}}
\tpublic {pl['iface']} basicGet{pl['name']}() {{ return {pl['field']}; }}
\tpublic void set{pl['name']}({pl['iface']} value) {{ {pl['field']} = value; }}
'''
        eget_cases += f"\t\tcase MainPackage.APPLICATION_INPUT_DATA__{pl['upper_snake']}:\n"
        eget_cases += f"\t\t\tif (resolve) return get{pl['name']}();\n"
        eget_cases += f"\t\t\treturn basicGet{pl['name']}();\n"

        eset_cases += f"\t\tcase MainPackage.APPLICATION_INPUT_DATA__{pl['upper_snake']}:\n"
        eset_cases += f"\t\t\tset{pl['name']}(({pl['iface']}) newValue);\n"
        eset_cases += f"\t\t\treturn;\n"

        eunset_cases += f"\t\tcase MainPackage.APPLICATION_INPUT_DATA__{pl['upper_snake']}:\n"
        eunset_cases += f"\t\t\tset{pl['name']}(({pl['iface']}) null);\n"
        eunset_cases += f"\t\t\treturn;\n"

        eisset_cases += f"\t\tcase MainPackage.APPLICATION_INPUT_DATA__{pl['upper_snake']}:\n"
        eisset_cases += f"\t\t\treturn {pl['field']} != null;\n"

    return f'''package com.bosch.nevonex.main.impl;

{imports}
import com.bosch.nevonex.main.IApplicationInputData;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.InternalEObject;

import org.eclipse.emf.ecore.impl.EObjectImpl;

/** @generated */
public class ApplicationInputData extends EObjectImpl implements IApplicationInputData {{
{fields}
\tprotected ApplicationInputData() {{ super(); }}

\t@Override
\tprotected EClass eStaticClass() {{ return MainPackage.Literals.APPLICATION_INPUT_DATA; }}
{accessors}
\t@Override
\tpublic Object eGet(int featureID, boolean resolve, boolean coreType) {{
\t\tswitch (featureID) {{
{eget_cases}\t\t}}
\t\treturn super.eGet(featureID, resolve, coreType);
\t}}

\t@Override
\tpublic void eSet(int featureID, Object newValue) {{
\t\tswitch (featureID) {{
{eset_cases}\t\t}}
\t\tsuper.eSet(featureID, newValue);
\t}}

\t@Override
\tpublic void eUnset(int featureID) {{
\t\tswitch (featureID) {{
{eunset_cases}\t\t}}
\t\tsuper.eUnset(featureID);
\t}}

\t@Override
\tpublic boolean eIsSet(int featureID) {{
\t\tswitch (featureID) {{
{eisset_cases}\t\t}}
\t\treturn super.eIsSet(featureID);
\t}}
}} //ApplicationInputData
'''


def gen_main_factory(name):
    """Generate MainFactory.java"""
    pascal = name[0].upper() + name[1:]
    upper = _to_upper_snake(pascal)
    ctrl_field = _emf_field_name(pascal)

    # Build create methods and switch cases
    classes = [
        ("ApplicationMain", "IApplicationMain", "applicationMain"),
        ("ApplicationInputData", "IApplicationInputData", "applicationInputData"),
        (pascal, f"I{pascal}", ctrl_field),
        ("FeatureManagerListener", "IFeatureManagerListener", "featureManagerListener"),
        ("MachineConnectListener", "IMachineConnectListener", "machineConnectListener"),
        ("IgnitionStateListener", "IIgnitionStateListener", "ignitionStateListener"),
    ]
    sample_services = [
        ("SampleGetService", "ISampleGetService", "sampleGetService"),
        ("SamplePostService", "ISamplePostService", "samplePostService"),
        ("SamplePutService", "ISamplePutService", "samplePutService"),
        ("SampleDeleteService", "ISampleDeleteService", "sampleDeleteService"),
    ]

    switch_cases = ""
    create_methods = ""

    for cls_name, iface, var in classes:
        pkg_const = _to_upper_snake(cls_name)
        switch_cases += f"\t\tcase MainPackage.{pkg_const}: return create{cls_name}();\n"
        if cls_name == "UIWebsocketEndPoint":
            create_methods += f"\tpublic {iface} create{cls_name}() {{ return UIWebsocketEndPoint.getInstance(); }}\n"
        else:
            create_methods += f"\tpublic {iface} create{cls_name}() {{ return new {cls_name}(); }}\n"

    # UIWebsocketEndPoint special case
    switch_cases += f"\t\tcase MainPackage.UI_WEBSOCKET_END_POINT: return createUIWebsocketEndPoint();\n"
    create_methods += f"\tpublic IUIWebsocketEndPoint createUIWebsocketEndPoint() {{ return UIWebsocketEndPoint.getInstance(); }}\n"

    for cls_name, iface, var in sample_services:
        pkg_const = _to_upper_snake(cls_name)
        switch_cases += f"\t\tcase MainPackage.{pkg_const}: return create{cls_name}();\n"
        create_methods += f"\tpublic {iface} create{cls_name}() {{ return new {cls_name}(); }}\n"

    return f'''package com.bosch.nevonex.main.impl;

import com.bosch.nevonex.main.*;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;

import org.eclipse.emf.ecore.impl.EFactoryImpl;

import org.eclipse.emf.ecore.plugin.EcorePlugin;

/** @generated */
public class MainFactory extends EFactoryImpl implements IMainFactory {{
\tpublic static final MainFactory eINSTANCE = init();

\tpublic static MainFactory init() {{
\t\ttry {{
\t\t\tMainFactory f = (MainFactory) EPackage.Registry.INSTANCE.getEFactory(MainPackage.eNS_URI);
\t\t\tif (f != null) return f;
\t\t}} catch (Exception e) {{ EcorePlugin.INSTANCE.log(e); }}
\t\treturn new MainFactory();
\t}}

\tpublic MainFactory() {{ super(); }}

\t@Override
\tpublic EObject create(EClass eClass) {{
\t\tswitch (eClass.getClassifierID()) {{
{switch_cases}\t\tdefault: throw new IllegalArgumentException("The class '" + eClass.getName() + "' is not a valid classifier");
\t\t}}
\t}}

{create_methods}
\tpublic MainPackage getMainPackage() {{ return (MainPackage) getEPackage(); }}

\t@Deprecated
\tpublic static MainPackage getPackage() {{ return MainPackage.eINSTANCE; }}
}} //MainFactory
'''


def gen_main_package(name, filtered_plugins):
    """Generate MainPackage.java (~1600 lines of EMF metadata)."""
    pascal = name[0].upper() + name[1:]
    upper_name = _to_upper_snake(pascal)
    ctrl_field = _emf_field_name(pascal)

    plugins = []
    for pname, p in filtered_plugins.items():
        plugins.append({
            "name": pname, "iface": f"I{pname}", "package": p["provider_package"],
            "upper_snake": _to_upper_snake(pname),
            "emf_field": _emf_field_name(pname) + "EClass",
            "field": _emf_field_name(pname),
        })
    np = len(plugins)

    # Classifier IDs
    ctrl_id = 5 + np
    fixed_after = [
        ("FEATURE_MANAGER_LISTENER", ctrl_id + 1),
        ("MACHINE_CONNECT_LISTENER", ctrl_id + 2),
        ("IGNITION_STATE_LISTENER", ctrl_id + 3),
        ("UI_WEBSOCKET_END_POINT", ctrl_id + 4),
        ("SAMPLE_GET_SERVICE", ctrl_id + 5),
        ("SAMPLE_POST_SERVICE", ctrl_id + 6),
        ("SAMPLE_PUT_SERVICE", ctrl_id + 7),
        ("SAMPLE_DELETE_SERVICE", ctrl_id + 8),
    ]

    # --- Imports ---
    imp = "import com.bosch.fsp.runtime.feature.IMachineProvider;\n\n"
    for pl in plugins:
        imp += f"import com.bosch.nevonex.{pl['package']}.{pl['iface']};\n"
    if plugins:
        imp += "\n"
    imp += (
        f"import com.bosch.nevonex.main.IApplicationInputData;\n"
        f"import com.bosch.nevonex.main.IApplicationMain;\n"
        f"import com.bosch.nevonex.main.IFeatureManagerListener;\n"
        f"import com.bosch.nevonex.main.IIgnitionStateListener;\n"
        f"import com.bosch.nevonex.main.IMachineConnectListener;\n"
        f"import com.bosch.nevonex.main.IMainFactory;\n"
        f"import com.bosch.nevonex.main.ISampleDeleteService;\n"
        f"import com.bosch.nevonex.main.ISampleGetService;\n"
        f"import com.bosch.nevonex.main.ISamplePostService;\n"
        f"import com.bosch.nevonex.main.ISamplePutService;\n"
        f"import com.bosch.nevonex.main.I{pascal};\n"
        f"import com.bosch.nevonex.main.IUIWebsocketEndPoint;\n"
    )

    # --- Constants ---
    c = ""
    # APPLICATION_MAIN
    c += "\tpublic static final int APPLICATION_MAIN = 0;\n"
    c += "\tpublic static final int APPLICATION_MAIN__TIMER_TRIGGERED = 0;\n"
    c += "\tpublic static final int APPLICATION_MAIN_FEATURE_COUNT = 1;\n"
    c += "\tpublic static final int APPLICATION_MAIN___ADD_LISTENERS_FOR_USER_DEFINED_CONTROLS = 0;\n"
    c += "\tpublic static final int APPLICATION_MAIN___INITIALIZE_MACHINE_PROVIDERS__IMACHINEPROVIDER = 1;\n"
    c += "\tpublic static final int APPLICATION_MAIN___ADD_PROCESS_TIMER = 2;\n"
    c += "\tpublic static final int APPLICATION_MAIN_OPERATION_COUNT = 3;\n"
    # MACHINE_PROVIDER, PROPERTY_CHANGE_LISTENER, RUNNABLE
    for cname, cid in [("MACHINE_PROVIDER", 1), ("PROPERTY_CHANGE_LISTENER", 2), ("RUNNABLE", 3)]:
        c += f"\tpublic static final int {cname} = {cid};\n"
        c += f"\tpublic static final int {cname}_FEATURE_COUNT = 0;\n"
        c += f"\tpublic static final int {cname}_OPERATION_COUNT = 0;\n"
    # APPLICATION_INPUT_DATA
    c += "\tpublic static final int APPLICATION_INPUT_DATA = 4;\n"
    for i, pl in enumerate(plugins):
        c += f"\tpublic static final int APPLICATION_INPUT_DATA__{pl['upper_snake']} = {i};\n"
    c += f"\tpublic static final int APPLICATION_INPUT_DATA_FEATURE_COUNT = {np};\n"
    c += f"\tpublic static final int APPLICATION_INPUT_DATA_OPERATION_COUNT = 0;\n"
    # Plugin external classes
    for i, pl in enumerate(plugins):
        pid = 5 + i
        c += f"\tpublic static final int {pl['upper_snake']} = {pid};\n"
        c += f"\tpublic static final int {pl['upper_snake']}_FEATURE_COUNT = 0;\n"
        c += f"\tpublic static final int {pl['upper_snake']}_OPERATION_COUNT = 0;\n"
    # Controller
    c += f"\tpublic static final int {upper_name} = {ctrl_id};\n"
    for i, pl in enumerate(plugins):
        c += f"\tpublic static final int {upper_name}__{pl['upper_snake']} = RUNNABLE_FEATURE_COUNT + {i};\n"
    c += f"\tpublic static final int {upper_name}__WS_END_POINT = RUNNABLE_FEATURE_COUNT + {np};\n"
    c += f"\tpublic static final int {upper_name}_FEATURE_COUNT = RUNNABLE_FEATURE_COUNT + {np + 1};\n"
    c += f"\tpublic static final int {upper_name}_OPERATION_COUNT = RUNNABLE_OPERATION_COUNT + 0;\n"
    # Fixed classes after controller
    for cname, cid in fixed_after[:4]:  # non-service ones (no features)
        c += f"\tpublic static final int {cname} = {cid};\n"
        c += f"\tpublic static final int {cname}_FEATURE_COUNT = 0;\n"
        c += f"\tpublic static final int {cname}_OPERATION_COUNT = 0;\n"
    for cname, cid in fixed_after[4:]:  # sample services (1 feature: controller)
        c += f"\tpublic static final int {cname} = {cid};\n"
        c += f"\tpublic static final int {cname}__CONTROLLER = 0;\n"
        c += f"\tpublic static final int {cname}_FEATURE_COUNT = 1;\n"
        c += f"\tpublic static final int {cname}_OPERATION_COUNT = 0;\n"

    # --- Fields ---
    f = "\tprivate EClass applicationMainEClass = null;\n"
    f += "\tprivate EClass machineProviderEClass = null;\n"
    f += "\tprivate EClass propertyChangeListenerEClass = null;\n"
    f += "\tprivate EClass runnableEClass = null;\n"
    f += "\tprivate EClass applicationInputDataEClass = null;\n"
    for pl in plugins:
        f += f"\tprivate EClass {pl['emf_field']} = null;\n"
    f += f"\tprivate EClass {ctrl_field}EClass = null;\n"
    f += "\tprivate EClass featureManagerListenerEClass = null;\n"
    f += "\tprivate EClass machineConnectListenerEClass = null;\n"
    f += "\tprivate EClass ignitionStateListenerEClass = null;\n"
    f += "\tprivate EClass uiWebsocketEndPointEClass = null;\n"
    f += "\tprivate EClass sampleGetServiceEClass = null;\n"
    f += "\tprivate EClass samplePostServiceEClass = null;\n"
    f += "\tprivate EClass samplePutServiceEClass = null;\n"
    f += "\tprivate EClass sampleDeleteServiceEClass = null;\n"

    # --- Getters ---
    g = "\tpublic EClass getApplicationMain() { return applicationMainEClass; }\n"
    g += "\tpublic EAttribute getApplicationMain_TimerTriggered() { return (EAttribute) applicationMainEClass.getEStructuralFeatures().get(0); }\n"
    g += "\tpublic EOperation getApplicationMain__AddListenersForUserDefinedControls() { return applicationMainEClass.getEOperations().get(0); }\n"
    g += "\tpublic EOperation getApplicationMain__InitializeMachineProviders__IMachineProvider() { return applicationMainEClass.getEOperations().get(1); }\n"
    g += "\tpublic EOperation getApplicationMain__AddProcessTimer() { return applicationMainEClass.getEOperations().get(2); }\n"
    g += "\tpublic EClass getMachineProvider() { return machineProviderEClass; }\n"
    g += "\tpublic EClass getPropertyChangeListener() { return propertyChangeListenerEClass; }\n"
    g += "\tpublic EClass getRunnable() { return runnableEClass; }\n"
    g += "\tpublic EClass getApplicationInputData() { return applicationInputDataEClass; }\n"
    for i, pl in enumerate(plugins):
        g += f"\tpublic EReference getApplicationInputData_{pl['name']}() {{ return (EReference) applicationInputDataEClass.getEStructuralFeatures().get({i}); }}\n"
    for pl in plugins:
        g += f"\tpublic EClass get{pl['name']}() {{ return {pl['emf_field']}; }}\n"
    g += f"\tpublic EClass get{pascal}() {{ return {ctrl_field}EClass; }}\n"
    g += f"\tpublic EReference get{pascal}_WsEndPoint() {{ return (EReference) {ctrl_field}EClass.getEStructuralFeatures().get(0); }}\n"
    g += "\tpublic EClass getFeatureManagerListener() { return featureManagerListenerEClass; }\n"
    g += "\tpublic EClass getMachineConnectListener() { return machineConnectListenerEClass; }\n"
    g += "\tpublic EClass getIgnitionStateListener() { return ignitionStateListenerEClass; }\n"
    g += "\tpublic EClass getUIWebsocketEndPoint() { return uiWebsocketEndPointEClass; }\n"
    for svc in ["SampleGetService", "SamplePostService", "SamplePutService", "SampleDeleteService"]:
        sf = _emf_field_name(svc)
        g += f"\tpublic EClass get{svc}() {{ return {sf}EClass; }}\n"
        g += f"\tpublic EReference get{svc}_Controller() {{ return (EReference) {sf}EClass.getEStructuralFeatures().get(0); }}\n"
    g += "\tpublic IMainFactory getMainFactory() { return (IMainFactory) getEFactoryInstance(); }\n"

    # --- createPackageContents ---
    cr = "\t\tapplicationMainEClass = createEClass(APPLICATION_MAIN);\n"
    cr += "\t\tcreateEAttribute(applicationMainEClass, APPLICATION_MAIN__TIMER_TRIGGERED);\n"
    cr += "\t\tcreateEOperation(applicationMainEClass, APPLICATION_MAIN___ADD_LISTENERS_FOR_USER_DEFINED_CONTROLS);\n"
    cr += "\t\tcreateEOperation(applicationMainEClass, APPLICATION_MAIN___INITIALIZE_MACHINE_PROVIDERS__IMACHINEPROVIDER);\n"
    cr += "\t\tcreateEOperation(applicationMainEClass, APPLICATION_MAIN___ADD_PROCESS_TIMER);\n"
    cr += "\t\tmachineProviderEClass = createEClass(MACHINE_PROVIDER);\n"
    cr += "\t\tpropertyChangeListenerEClass = createEClass(PROPERTY_CHANGE_LISTENER);\n"
    cr += "\t\trunnableEClass = createEClass(RUNNABLE);\n"
    cr += "\t\tapplicationInputDataEClass = createEClass(APPLICATION_INPUT_DATA);\n"
    for pl in plugins:
        cr += f"\t\tcreateEReference(applicationInputDataEClass, APPLICATION_INPUT_DATA__{pl['upper_snake']});\n"
    for pl in plugins:
        cr += f"\t\t{pl['emf_field']} = createEClass({pl['upper_snake']});\n"
    cr += f"\t\t{ctrl_field}EClass = createEClass({upper_name});\n"
    cr += f"\t\tcreateEReference({ctrl_field}EClass, {upper_name}__WS_END_POINT);\n"
    cr += "\t\tfeatureManagerListenerEClass = createEClass(FEATURE_MANAGER_LISTENER);\n"
    cr += "\t\tmachineConnectListenerEClass = createEClass(MACHINE_CONNECT_LISTENER);\n"
    cr += "\t\tignitionStateListenerEClass = createEClass(IGNITION_STATE_LISTENER);\n"
    cr += "\t\tuiWebsocketEndPointEClass = createEClass(UI_WEBSOCKET_END_POINT);\n"
    for svc, svc_u in [("sampleGetService", "SAMPLE_GET_SERVICE"), ("samplePostService", "SAMPLE_POST_SERVICE"),
                        ("samplePutService", "SAMPLE_PUT_SERVICE"), ("sampleDeleteService", "SAMPLE_DELETE_SERVICE")]:
        cr += f"\t\t{svc}EClass = createEClass({svc_u});\n"
        cr += f"\t\tcreateEReference({svc}EClass, {svc_u}__CONTROLLER);\n"

    # --- initializePackageContents ---
    ini = ""
    # Supertypes
    ini += f"\t\t{ctrl_field}EClass.getESuperTypes().add(this.getRunnable());\n"
    ini += f"\t\t{ctrl_field}EClass.getESuperTypes().add(this.getApplicationInputData());\n"
    # initEClass calls
    ini += '\t\tinitEClass(applicationMainEClass, IApplicationMain.class, "ApplicationMain", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEAttribute(getApplicationMain_TimerTriggered(), ecorePackage.getEBoolean(), "timerTriggered", null, 0, 1, IApplicationMain.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, !IS_UNSETTABLE, !IS_ID, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);\n'
    ini += '\t\tinitEOperation(getApplicationMain__AddListenersForUserDefinedControls(), null, "addListenersForUserDefinedControls", 0, 1, IS_UNIQUE, IS_ORDERED);\n'
    ini += '\t\tEOperation op = initEOperation(getApplicationMain__InitializeMachineProviders__IMachineProvider(), null, "initializeMachineProviders", 0, 1, IS_UNIQUE, IS_ORDERED);\n'
    ini += '\t\taddEParameter(op, this.getMachineProvider(), "provider", 0, 1, IS_UNIQUE, IS_ORDERED);\n'
    ini += '\t\tinitEOperation(getApplicationMain__AddProcessTimer(), null, "addProcessTimer", 0, 1, IS_UNIQUE, IS_ORDERED);\n'
    ini += '\t\tinitEClass(machineProviderEClass, IMachineProvider.class, "MachineProvider", IS_ABSTRACT, IS_INTERFACE, !IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(propertyChangeListenerEClass, PropertyChangeListener.class, "PropertyChangeListener", IS_ABSTRACT, IS_INTERFACE, !IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(runnableEClass, Runnable.class, "Runnable", IS_ABSTRACT, IS_INTERFACE, !IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(applicationInputDataEClass, IApplicationInputData.class, "ApplicationInputData", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    for pl in plugins:
        ini += f'\t\tinitEReference(getApplicationInputData_{pl["name"]}(), this.get{pl["name"]}(), null, "{pl["field"]}", null, 1, 1, IApplicationInputData.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, !IS_COMPOSITE, IS_RESOLVE_PROXIES, !IS_UNSETTABLE, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);\n'
    for pl in plugins:
        ini += f'\t\tinitEClass({pl["emf_field"]}, {pl["iface"]}.class, "{pl["name"]}", IS_ABSTRACT, IS_INTERFACE, !IS_GENERATED_INSTANCE_CLASS);\n'
    ini += f'\t\tinitEClass({ctrl_field}EClass, I{pascal}.class, "{pascal}", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    ini += f'\t\tinitEReference(get{pascal}_WsEndPoint(), this.getUIWebsocketEndPoint(), null, "wsEndPoint", null, 0, 1, I{pascal}.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, !IS_COMPOSITE, IS_RESOLVE_PROXIES, !IS_UNSETTABLE, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);\n'
    ini += '\t\tinitEClass(featureManagerListenerEClass, IFeatureManagerListener.class, "FeatureManagerListener", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(machineConnectListenerEClass, IMachineConnectListener.class, "MachineConnectListener", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(ignitionStateListenerEClass, IIgnitionStateListener.class, "IgnitionStateListener", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    ini += '\t\tinitEClass(uiWebsocketEndPointEClass, IUIWebsocketEndPoint.class, "UIWebsocketEndPoint", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
    for svc_p, svc_i in [("SampleGetService", "ISampleGetService"), ("SamplePostService", "ISamplePostService"),
                          ("SamplePutService", "ISamplePutService"), ("SampleDeleteService", "ISampleDeleteService")]:
        sf = _emf_field_name(svc_p)
        ini += f'\t\tinitEClass({sf}EClass, {svc_i}.class, "{svc_p}", !IS_ABSTRACT, !IS_INTERFACE, IS_GENERATED_INSTANCE_CLASS);\n'
        ini += f'\t\tinitEReference(get{svc_p}_Controller(), this.get{pascal}(), null, "controller", null, 0, 1, {svc_i}.class, !IS_TRANSIENT, !IS_VOLATILE, IS_CHANGEABLE, !IS_COMPOSITE, IS_RESOLVE_PROXIES, !IS_UNSETTABLE, IS_UNIQUE, !IS_DERIVED, IS_ORDERED);\n'

    # --- Literals ---
    lit = "\t\tpublic static final EClass APPLICATION_MAIN = eINSTANCE.getApplicationMain();\n"
    lit += "\t\tpublic static final EAttribute APPLICATION_MAIN__TIMER_TRIGGERED = eINSTANCE.getApplicationMain_TimerTriggered();\n"
    lit += "\t\tpublic static final EOperation APPLICATION_MAIN___ADD_LISTENERS_FOR_USER_DEFINED_CONTROLS = eINSTANCE.getApplicationMain__AddListenersForUserDefinedControls();\n"
    lit += "\t\tpublic static final EOperation APPLICATION_MAIN___INITIALIZE_MACHINE_PROVIDERS__IMACHINEPROVIDER = eINSTANCE.getApplicationMain__InitializeMachineProviders__IMachineProvider();\n"
    lit += "\t\tpublic static final EOperation APPLICATION_MAIN___ADD_PROCESS_TIMER = eINSTANCE.getApplicationMain__AddProcessTimer();\n"
    lit += "\t\tpublic static final EClass MACHINE_PROVIDER = eINSTANCE.getMachineProvider();\n"
    lit += "\t\tpublic static final EClass PROPERTY_CHANGE_LISTENER = eINSTANCE.getPropertyChangeListener();\n"
    lit += "\t\tpublic static final EClass RUNNABLE = eINSTANCE.getRunnable();\n"
    lit += "\t\tpublic static final EClass APPLICATION_INPUT_DATA = eINSTANCE.getApplicationInputData();\n"
    for pl in plugins:
        lit += f"\t\tpublic static final EReference APPLICATION_INPUT_DATA__{pl['upper_snake']} = eINSTANCE.getApplicationInputData_{pl['name']}();\n"
    for pl in plugins:
        lit += f"\t\tpublic static final EClass {pl['upper_snake']} = eINSTANCE.get{pl['name']}();\n"
    lit += f"\t\tpublic static final EClass {upper_name} = eINSTANCE.get{pascal}();\n"
    lit += f"\t\tpublic static final EReference {upper_name}__WS_END_POINT = eINSTANCE.get{pascal}_WsEndPoint();\n"
    lit += "\t\tpublic static final EClass FEATURE_MANAGER_LISTENER = eINSTANCE.getFeatureManagerListener();\n"
    lit += "\t\tpublic static final EClass MACHINE_CONNECT_LISTENER = eINSTANCE.getMachineConnectListener();\n"
    lit += "\t\tpublic static final EClass IGNITION_STATE_LISTENER = eINSTANCE.getIgnitionStateListener();\n"
    lit += "\t\tpublic static final EClass UI_WEBSOCKET_END_POINT = eINSTANCE.getUIWebsocketEndPoint();\n"
    for svc_p, svc_u in [("SampleGetService", "SAMPLE_GET_SERVICE"), ("SamplePostService", "SAMPLE_POST_SERVICE"),
                          ("SamplePutService", "SAMPLE_PUT_SERVICE"), ("SampleDeleteService", "SAMPLE_DELETE_SERVICE")]:
        lit += f"\t\tpublic static final EClass {svc_u} = eINSTANCE.get{svc_p}();\n"
        lit += f"\t\tpublic static final EReference {svc_u}__CONTROLLER = eINSTANCE.get{svc_p}_Controller();\n"

    return f'''package com.bosch.nevonex.main.impl;

{imp}
import java.beans.PropertyChangeListener;
import java.lang.Runnable;

import org.eclipse.emf.ecore.EAttribute;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EOperation;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EReference;

import org.eclipse.emf.ecore.impl.EPackageImpl;

/** @generated */
public class MainPackage extends EPackageImpl {{
\tpublic static final String eNAME = "main";
\tpublic static final String eNS_URI = "com.bosch.nevonex.main";
\tpublic static final String eNS_PREFIX = "main";
\tpublic static final MainPackage eINSTANCE = com.bosch.nevonex.main.impl.MainPackage.init();

{c}
{f}
\tprivate MainPackage() {{
\t\tsuper(eNS_URI, IMainFactory.INSTANCE instanceof EFactory ? (EFactory) IMainFactory.INSTANCE : new MainFactory());
\t}}

\tpublic static MainPackage init() {{
\t\tObject registeredMainPackage = EPackage.Registry.INSTANCE.getEPackage(eNS_URI);
\t\tMainPackage theMainPackage = registeredMainPackage instanceof MainPackage ? (MainPackage) registeredMainPackage : new MainPackage();
\t\ttheMainPackage.createPackageContents();
\t\ttheMainPackage.initializePackageContents();
\t\ttheMainPackage.freeze();
\t\tEPackage.Registry.INSTANCE.put(MainPackage.eNS_URI, theMainPackage);
\t\treturn theMainPackage;
\t}}

{g}
\tprivate boolean isCreated = false;
\tpublic void createPackageContents() {{
\t\tif (isCreated) return;
\t\tisCreated = true;
{cr}\t}}

\tprivate boolean isInitialized = false;
\tpublic void initializePackageContents() {{
\t\tif (isInitialized) return;
\t\tisInitialized = true;
\t\tsetName(eNAME);
\t\tsetNsPrefix(eNS_PREFIX);
\t\tsetNsURI(eNS_URI);
{ini}\t\tcreateResource(eNS_URI);
\t}}

\tpublic interface Literals {{
{lit}\t}}
}} //MainPackage
'''


def gen_sample_service(name, method):
    """Generate Sample{Method}Service.java impl (Get/Post/Put/Delete)."""
    pascal = name[0].upper() + name[1:]
    cls = f"Sample{method}Service"
    upper = _to_upper_snake(cls)
    return f'''package com.bosch.nevonex.main.impl;

import com.bosch.nevonex.customui.impl.NevonexRoute;

import com.bosch.nevonex.main.I{cls};
import com.bosch.nevonex.main.I{pascal};

import com.google.gson.JsonObject;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.InternalEObject;

import spark.Request;
import spark.Response;

/** @generated */
public class {cls} extends NevonexRoute implements I{cls} {{
\tprotected I{pascal} controller;

\tprotected {cls}() {{ super(); }}

\tprotected Object processService(Request request, Response response) {{
\t\tJsonObject message = new JsonObject();
\t\tmessage.addProperty("status", "success");
\t\treturn message.toString();
\t}}

\t@Override
\tprotected EClass eStaticClass() {{ return MainPackage.Literals.{upper}; }}

\tpublic I{pascal} getController() {{
\t\tif (controller != null && controller.eIsProxy()) {{
\t\t\tInternalEObject old = (InternalEObject) controller;
\t\t\tcontroller = (I{pascal}) eResolveProxy(old);
\t\t}}
\t\treturn controller;
\t}}
\tpublic I{pascal} basicGetController() {{ return controller; }}
\tpublic void setController(I{pascal} value) {{ controller = value; }}

\t@Override
\tpublic Object eGet(int featureID, boolean resolve, boolean coreType) {{
\t\tswitch (featureID) {{
\t\tcase MainPackage.{upper}__CONTROLLER:
\t\t\tif (resolve) return getController();
\t\t\treturn basicGetController();
\t\t}}
\t\treturn super.eGet(featureID, resolve, coreType);
\t}}

\t@Override
\tpublic void eSet(int featureID, Object newValue) {{
\t\tswitch (featureID) {{
\t\tcase MainPackage.{upper}__CONTROLLER:
\t\t\tsetController((I{pascal}) newValue);
\t\t\treturn;
\t\t}}
\t\tsuper.eSet(featureID, newValue);
\t}}

\t@Override
\tpublic void eUnset(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase MainPackage.{upper}__CONTROLLER:
\t\t\tsetController((I{pascal}) null);
\t\t\treturn;
\t\t}}
\t\tsuper.eUnset(featureID);
\t}}

\t@Override
\tpublic boolean eIsSet(int featureID) {{
\t\tswitch (featureID) {{
\t\tcase MainPackage.{upper}__CONTROLLER:
\t\t\treturn controller != null;
\t\t}}
\t\treturn super.eIsSet(featureID);
\t}}
}} //{cls}
'''


# ============================================================
# EMF Util Generators
# ============================================================

def gen_main_adapter_factory(name, filtered_plugins):
    """Generate MainAdapterFactory.java"""
    pascal = name[0].upper() + name[1:]
    plugins = []
    for pname, p in filtered_plugins.items():
        plugins.append({"name": pname, "iface": f"I{pname}", "package": p["provider_package"]})

    plugin_imports = ""
    for pl in plugins:
        plugin_imports += f"import com.bosch.nevonex.{pl['package']}.{pl['iface']};\n"

    # Switch cases
    sw = ""
    sw += "\t\t@Override\n\t\tpublic Adapter caseApplicationMain(IApplicationMain object) { return createApplicationMainAdapter(); }\n"
    sw += "\t\t@Override\n\t\tpublic Adapter caseMachineProvider(IMachineProvider object) { return createMachineProviderAdapter(); }\n"
    sw += "\t\t@Override\n\t\tpublic Adapter casePropertyChangeListener(PropertyChangeListener object) { return createPropertyChangeListenerAdapter(); }\n"
    sw += "\t\t@Override\n\t\tpublic Adapter caseRunnable(Runnable object) { return createRunnableAdapter(); }\n"
    sw += "\t\t@Override\n\t\tpublic Adapter caseApplicationInputData(IApplicationInputData object) { return createApplicationInputDataAdapter(); }\n"
    for pl in plugins:
        sw += f"\t\t@Override\n\t\tpublic Adapter case{pl['name']}({pl['iface']} object) {{ return create{pl['name']}Adapter(); }}\n"
    sw += f"\t\t@Override\n\t\tpublic Adapter case{pascal}(I{pascal} object) {{ return create{pascal}Adapter(); }}\n"
    for cls in ["FeatureManagerListener", "MachineConnectListener", "IgnitionStateListener", "UIWebsocketEndPoint",
                "SampleGetService", "SamplePostService", "SamplePutService", "SampleDeleteService"]:
        sw += f"\t\t@Override\n\t\tpublic Adapter case{cls}(I{cls} object) {{ return create{cls}Adapter(); }}\n"
    sw += "\t\t@Override\n\t\tpublic Adapter defaultCase(EObject object) { return createEObjectAdapter(); }\n"

    # Adapter create methods
    am = ""
    for cls in ["ApplicationMain", "MachineProvider", "PropertyChangeListener", "Runnable", "ApplicationInputData"]:
        am += f"\tpublic Adapter create{cls}Adapter() {{ return null; }}\n"
    for pl in plugins:
        am += f"\tpublic Adapter create{pl['name']}Adapter() {{ return null; }}\n"
    am += f"\tpublic Adapter create{pascal}Adapter() {{ return null; }}\n"
    for cls in ["FeatureManagerListener", "MachineConnectListener", "IgnitionStateListener", "UIWebsocketEndPoint",
                "SampleGetService", "SamplePostService", "SamplePutService", "SampleDeleteService"]:
        am += f"\tpublic Adapter create{cls}Adapter() {{ return null; }}\n"
    am += "\tpublic Adapter createEObjectAdapter() { return null; }\n"

    return f'''package com.bosch.nevonex.main.util;

import com.bosch.fsp.runtime.feature.IMachineProvider;

{plugin_imports}
import com.bosch.nevonex.main.*;

import com.bosch.nevonex.main.impl.MainPackage;

import java.beans.PropertyChangeListener;

import org.eclipse.emf.common.notify.Adapter;
import org.eclipse.emf.common.notify.Notifier;
import org.eclipse.emf.common.notify.impl.AdapterFactoryImpl;
import org.eclipse.emf.ecore.EObject;

/** @generated */
public class MainAdapterFactory extends AdapterFactoryImpl {{
\tprotected static MainPackage modelPackage;

\tpublic MainAdapterFactory() {{
\t\tif (modelPackage == null) modelPackage = MainPackage.eINSTANCE;
\t}}

\t@Override
\tpublic boolean isFactoryForType(Object object) {{
\t\tif (object == modelPackage) return true;
\t\tif (object instanceof EObject) return ((EObject) object).eClass().getEPackage() == modelPackage;
\t\treturn false;
\t}}

\tprotected MainSwitch<Adapter> modelSwitch = new MainSwitch<Adapter>() {{
{sw}\t}};

\t@Override
\tpublic Adapter createAdapter(Notifier target) {{ return modelSwitch.doSwitch((EObject) target); }}

{am}}} //MainAdapterFactory
'''


def gen_main_switch(name, filtered_plugins):
    """Generate MainSwitch.java"""
    pascal = name[0].upper() + name[1:]
    upper_name = _to_upper_snake(pascal)
    plugins = []
    for pname, p in filtered_plugins.items():
        plugins.append({"name": pname, "iface": f"I{pname}", "package": p["provider_package"],
                         "upper_snake": _to_upper_snake(pname)})

    plugin_imports = ""
    for pl in plugins:
        plugin_imports += f"import com.bosch.nevonex.{pl['package']}.{pl['iface']};\n"

    # doSwitch cases
    ds = ""
    ds += "\t\tcase MainPackage.APPLICATION_MAIN: {\n"
    ds += "\t\t\tIApplicationMain v = (IApplicationMain) theEObject;\n"
    ds += "\t\t\tT result = caseApplicationMain(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    ds += "\t\tcase MainPackage.MACHINE_PROVIDER: {\n"
    ds += "\t\t\tIMachineProvider v = (IMachineProvider) theEObject;\n"
    ds += "\t\t\tT result = caseMachineProvider(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    ds += "\t\tcase MainPackage.PROPERTY_CHANGE_LISTENER: {\n"
    ds += "\t\t\tPropertyChangeListener v = (PropertyChangeListener) theEObject;\n"
    ds += "\t\t\tT result = casePropertyChangeListener(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    ds += "\t\tcase MainPackage.RUNNABLE: {\n"
    ds += "\t\t\tRunnable v = (Runnable) theEObject;\n"
    ds += "\t\t\tT result = caseRunnable(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    ds += "\t\tcase MainPackage.APPLICATION_INPUT_DATA: {\n"
    ds += "\t\t\tIApplicationInputData v = (IApplicationInputData) theEObject;\n"
    ds += "\t\t\tT result = caseApplicationInputData(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    for pl in plugins:
        ds += f"\t\tcase MainPackage.{pl['upper_snake']}: {{\n"
        ds += f"\t\t\t{pl['iface']} v = ({pl['iface']}) theEObject;\n"
        ds += f"\t\t\tT result = case{pl['name']}(v);\n"
        ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
        ds += "\t\t\treturn result;\n\t\t}\n"

    # Controller: check supertypes (Runnable, ApplicationInputData)
    ds += f"\t\tcase MainPackage.{upper_name}: {{\n"
    ds += f"\t\t\tI{pascal} v = (I{pascal}) theEObject;\n"
    ds += f"\t\t\tT result = case{pascal}(v);\n"
    ds += "\t\t\tif (result == null) result = caseRunnable(v);\n"
    ds += "\t\t\tif (result == null) result = caseApplicationInputData(v);\n"
    ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
    ds += "\t\t\treturn result;\n\t\t}\n"

    for cls, upper in [("FeatureManagerListener", "FEATURE_MANAGER_LISTENER"),
                       ("MachineConnectListener", "MACHINE_CONNECT_LISTENER"),
                       ("IgnitionStateListener", "IGNITION_STATE_LISTENER"),
                       ("UIWebsocketEndPoint", "UI_WEBSOCKET_END_POINT"),
                       ("SampleGetService", "SAMPLE_GET_SERVICE"),
                       ("SamplePostService", "SAMPLE_POST_SERVICE"),
                       ("SamplePutService", "SAMPLE_PUT_SERVICE"),
                       ("SampleDeleteService", "SAMPLE_DELETE_SERVICE")]:
        ds += f"\t\tcase MainPackage.{upper}: {{\n"
        ds += f"\t\t\tI{cls} v = (I{cls}) theEObject;\n"
        ds += f"\t\t\tT result = case{cls}(v);\n"
        ds += "\t\t\tif (result == null) result = defaultCase(theEObject);\n"
        ds += "\t\t\treturn result;\n\t\t}\n"

    ds += "\t\tdefault: return defaultCase(theEObject);\n"

    # case methods
    cm = ""
    for cls in ["ApplicationMain", "MachineProvider", "PropertyChangeListener", "Runnable", "ApplicationInputData"]:
        iface = f"I{cls}" if cls not in ("Runnable", "PropertyChangeListener") else cls
        if cls == "MachineProvider":
            iface = "IMachineProvider"
        cm += f"\tpublic T case{cls}({iface} object) {{ return null; }}\n"
    for pl in plugins:
        cm += f"\tpublic T case{pl['name']}({pl['iface']} object) {{ return null; }}\n"
    cm += f"\tpublic T case{pascal}(I{pascal} object) {{ return null; }}\n"
    for cls in ["FeatureManagerListener", "MachineConnectListener", "IgnitionStateListener", "UIWebsocketEndPoint",
                "SampleGetService", "SamplePostService", "SamplePutService", "SampleDeleteService"]:
        cm += f"\tpublic T case{cls}(I{cls} object) {{ return null; }}\n"
    cm += "\t@Override\n\tpublic T defaultCase(EObject object) { return null; }\n"

    return f'''package com.bosch.nevonex.main.util;

import com.bosch.fsp.runtime.feature.IMachineProvider;

{plugin_imports}
import com.bosch.nevonex.main.*;

import com.bosch.nevonex.main.impl.MainPackage;

import java.beans.PropertyChangeListener;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.util.Switch;

/** @generated */
public class MainSwitch<T> extends Switch<T> {{
\tprotected static MainPackage modelPackage;

\tpublic MainSwitch() {{
\t\tif (modelPackage == null) modelPackage = MainPackage.eINSTANCE;
\t}}

\t@Override
\tprotected boolean isSwitchFor(EPackage ePackage) {{ return ePackage == modelPackage; }}

\t@Override
\tprotected T doSwitch(int classifierID, EObject theEObject) {{
\t\tswitch (classifierID) {{
{ds}\t\t}}
\t}}

{cm}}} //MainSwitch
'''


# ============================================================
# SDK Test Generator (plugin-dynamic)
# ============================================================

# Utility methods for SDKTest.java — plugin-independent, always the same.
_SDK_TEST_UTILS = r'''
    public static EStructuralFeature getFeatureByInterfaceAddress(String address) {
        for (String childKey : featureToAddressMap.keySet()) {
            if (childKey.endsWith(".sub")) {
                if (address.equals(featureToAddressMap.get(childKey))) {
                    String name = childKey.split("\\.")[0];
                    String feature = childKey.split("\\.")[1];
                    EClass eClass = getEClassByName(name.toLowerCase());
                    if (eClass != null && eClass.getEStructuralFeature(feature) != null) {
                        return eClass.getEStructuralFeature(feature);
                    }
                }
            }
        }
        return null;
    }

    public static Object getRandomValue(EStructuralFeature att, Properties prop) {
        Random rd = new Random();
        if (prop == null) {
            throw new IllegalArgumentException("Exception while reading the Simulator.properties file");
        }
        if (att != null) {
            if (att.getEType().getName().equalsIgnoreCase("EFLOAT")) {
                float min = (float) getMinMaxRange(prop, "float", 0);
                float max = (float) getMinMaxRange(prop, "float", 1);
                if (min >= max) throw new IllegalArgumentException("bound must be greater than origin");
                return (rd.nextFloat() * (max - min)) + min;
            } else if (att.getEType().getName().equalsIgnoreCase("EDOUBLE")) {
                double min = (double) getMinMaxRange(prop, "double", 0);
                double max = (double) getMinMaxRange(prop, "double", 1);
                return ThreadLocalRandom.current().nextDouble(min, max);
            } else if (att.getEType().getName().equalsIgnoreCase("EINT")) {
                int min = (int) getMinMaxRange(prop, "int", 0);
                int max = (int) getMinMaxRange(prop, "int", 1);
                return ThreadLocalRandom.current().nextInt(min, max);
            } else if (att.getEType().getName().equalsIgnoreCase("ELONG")) {
                long min = (long) getMinMaxRange(prop, "long", 0);
                long max = (long) getMinMaxRange(prop, "long", 1);
                return ThreadLocalRandom.current().nextLong(min, max);
            } else if (att.getEType().getName().equalsIgnoreCase("ESTRING")) {
                String range = prop.getProperty("string");
                int length = 7;
                if (range != null && !range.isEmpty()) length = Integer.parseInt(range.trim());
                StringBuilder buffer = new StringBuilder(length);
                for (int i = 0; i < length; i++) {
                    int c = 97 + (int) (rd.nextFloat() * (122 - 97 + 1));
                    buffer.append((char) c);
                }
                return buffer.toString();
            } else if (att.getEType().getName().equalsIgnoreCase("EBOOLEAN")) {
                return 1;
            } else if (att.getEType().getName().equalsIgnoreCase("INTARRAY")) {
                int min = (int) getMinMaxRange(prop, "int", 0);
                int max = (int) getMinMaxRange(prop, "int", 1);
                return new int[]{ThreadLocalRandom.current().nextInt(min, max), ThreadLocalRandom.current().nextInt(min, max), ThreadLocalRandom.current().nextInt(min, max)};
            } else if (att.getEType().getName().equalsIgnoreCase("DOUBLEARRAY")) {
                double min = (double) getMinMaxRange(prop, "double", 0);
                double max = (double) getMinMaxRange(prop, "double", 1);
                return new double[]{ThreadLocalRandom.current().nextDouble(min, max), ThreadLocalRandom.current().nextDouble(min, max), ThreadLocalRandom.current().nextDouble(min, max)};
            } else if (att.getEType().getName().equalsIgnoreCase("FLOATARRAY")) {
                float min = (float) getMinMaxRange(prop, "float", 0);
                float max = (float) getMinMaxRange(prop, "float", 1);
                if (min >= max) throw new IllegalArgumentException("bound must be greater than origin");
                return new float[]{(rd.nextFloat() * (max - min)) + min, (rd.nextFloat() * (max - min)) + min, (rd.nextFloat() * (max - min)) + min};
            } else if (att.getEType().getName().equalsIgnoreCase("LONGARRAY")) {
                long min = (long) getMinMaxRange(prop, "long", 0);
                long max = (long) getMinMaxRange(prop, "long", 1);
                return new long[]{ThreadLocalRandom.current().nextLong(min, max), ThreadLocalRandom.current().nextLong(min, max), ThreadLocalRandom.current().nextLong(min, max)};
            } else if (att.getEType().getName().equalsIgnoreCase("BOOLEANARRAY")) {
                return new int[]{1, 0, 1};
            } else if (att.getEType().getName().equalsIgnoreCase("STRINGARRAY")) {
                String range = prop.getProperty("string");
                int length = 7;
                if (range != null && !range.isEmpty()) length = Integer.parseInt(range.trim());
                StringBuilder buffer = new StringBuilder(length);
                for (int i = 0; i < length; i++) {
                    int c = 97 + (int) (rd.nextFloat() * (122 - 97 + 1));
                    buffer.append((char) c);
                }
                return new String[]{buffer.toString()};
            } else if (att.getEType().getName().equalsIgnoreCase("AbsolutePosition")) {
                IAbsolutePosition position = CommonFactory.eINSTANCE.createAbsolutePosition();
                position.setLatitude(49 + rd.nextFloat());
                position.setLongitude(9 + rd.nextFloat());
                return position;
            } else if (Enumerator.class.isAssignableFrom(att.getEType().getInstanceClass())) {
                try {
                    Object object = att.getEType().getInstanceClass().getField("VALUES").get(att.getEType().eClass().getClass());
                    if ((object instanceof List) && !((List) object).isEmpty()) {
                        Object enumLiteral = ((List) object).get(0);
                        if (((List) object).size() > 1) enumLiteral = ((List) object).get(1);
                        if (enumLiteral instanceof Enumerator) return ((Enumerator) enumLiteral).getValue();
                    }
                } catch (Exception e) {
                    FCALLogs.getInstance().log.info("Exception while getting the enum value for the interface " + att.getName(), e);
                }
            } else if (com.bosch.nevonex.types.IArrayType.class.isAssignableFrom(att.getEType().getInstanceClass())) {
                org.eclipse.emf.ecore.EObject eObject = att.getEType().getEPackage().getEFactoryInstance().create((EClass) att.getEType());
                String[] featureNames = ((com.bosch.nevonex.types.IArrayType) eObject).getFeatureNames();
                for (String featureName : featureNames) {
                    try {
                        EStructuralFeature feature = eObject.eClass().getEStructuralFeature(featureName);
                        Object value = getRandomValue(feature, prop);
                        if (Enumerator.class.isAssignableFrom(feature.getEType().getInstanceClass())) {
                            value = feature.getEType().getInstanceClass().getMethod("get", int.class)
                                .invoke(feature.getEType().eClass().getClass(), Integer.valueOf(value.toString()));
                        } else if (feature.getEType().getName().equalsIgnoreCase("EBoolean") && value instanceof Integer) {
                            value = (((Integer) value).intValue() == 1) ? true : false;
                        } else if (feature.getEType().getInstanceClassName().equalsIgnoreCase("boolean[]")) {
                            int[] intArray = (int[]) value;
                            boolean[] booleanArray = new boolean[intArray.length];
                            for (int i = 0; i < booleanArray.length; i++) {
                                booleanArray[i] = (intArray[i] == 1) ? true : false;
                            }
                            value = booleanArray;
                        }
                        eObject.eSet(feature, value);
                    } catch (Exception e) {
                        FCALLogs.getInstance().log.info("Exception while setting the array feature " + featureName, e);
                    }
                }
                return eObject;
            }
        }
        return null;
    }

    public static Properties readSimulatorPropertiesFile() {
        Properties prop = null;
        try {
            FileInputStream fis = new FileInputStream("Simulator.properties");
            prop = new Properties();
            prop.load(fis);
            fis.close();
        } catch (IOException e1) {
            FCALLogs.getInstance().log.info("Exception while reading the Simulator.properties file");
        }
        return prop;
    }

    private static Object getMinMaxRange(Properties prop, String datatype, int index) {
        if (prop != null) {
            String range = prop.getProperty(datatype);
            if (range != null && !range.isEmpty()) {
                String[] values = range.split(",");
                if (values[index] != null) {
                    switch (datatype) {
                    case "int": return Integer.parseInt(values[index].trim());
                    case "long": return Long.parseLong(values[index].trim());
                    case "float": return Float.parseFloat(values[index].trim());
                    case "double": return Double.parseDouble(values[index].trim());
                    }
                }
            }
        }
        return Math.random();
    }
'''


def gen_sdk_test(name, filtered_plugins, available_fcal_types=None):
    """Generate SDKTest.java dynamically based on selected plugins.

    Args:
        available_fcal_types: set of EMF class names found in SDK fcal package
                              (e.g. {"GPS_INFO_R"}). If None, all array interfaces included.
    """

    # Build structured plugin info
    plugins = []
    for pname, p in filtered_plugins.items():
        pkg = p["provider_package"]
        pkg_cap = pkg[0].upper() + pkg[1:]

        read_interfaces = []
        for iface in p["interfaces"]:
            if iface.get("array") and iface.get("control") == "Subscribe":
                arr = iface["array"]
                # EMF class name = arrayName + "_R" (ecore convention for Subscribe types)
                emf_class = arr["name"] + "_R"
                # Skip if this class doesn't exist in the SDK
                if available_fcal_types is not None and emf_class not in available_fcal_types:
                    continue
                iface_pascal = iface["name"][0].upper() + iface["name"][1:]
                iface_camel = iface["name"][0].lower() + iface["name"][1:]
                read_interfaces.append({
                    "name": iface["name"],
                    "pascal": iface_pascal,
                    "camel": iface_camel,
                    "id": iface["id"],
                    "array_name": arr["name"],
                    "emf_class": emf_class,
                })

        plugins.append({
            "name": pname,
            "pkg": pkg,
            "pkg_cap": pkg_cap,
            "field": pkg + "Provider",
            "provider": pname + "Provider",
            "machine": pname,
            "getter": "get" + pname + "()",
            "package_class": pkg_cap + "Package",
            "interfaces": read_interfaces,
        })

    L = []  # output lines

    # --- Package ---
    L.append("package com.bosch.nevonex.sdk.test;")
    L.append("")

    # --- Standard imports ---
    L.extend([
        "import static org.junit.Assert.assertEquals;",
        "import static org.junit.Assert.assertNotNull;",
        "import static org.junit.Assert.assertTrue;",
        "import java.beans.PropertyChangeEvent;",
        "import java.beans.PropertyChangeListener;",
        "import org.eclipse.emf.ecore.EStructuralFeature;",
        "import java.util.List;",
        "import java.util.Properties;",
        "import org.junit.Test;",
        "import java.io.FileInputStream;",
        "import java.io.IOException;",
        "import org.eclipse.emf.ecore.EClass;",
        "import java.util.Random;",
        "import java.util.Map;",
        "import java.util.HashMap;",
        "import java.util.concurrent.ThreadLocalRandom;",
        "import org.eclipse.emf.common.util.Enumerator;",
        "import com.bosch.nevonex.common.IAbsolutePosition;",
        "import com.bosch.nevonex.common.impl.CommonFactory;",
        "import com.bosch.nevonex.common.ProviderEnum;",
        "import com.bosch.fsp.logger.FCALLogs;",
        "import com.bosch.fsp.runtime.feature.exception.NevonexException;",
        "import com.bosch.fsp.runtime.registry.FCALRuntime;",
        "import org.junit.BeforeClass;",
        "import com.bosch.nevonex.fcb.impl.FcbPackage;",
        "import com.bosch.nevonex.fcal.impl.FcalPackage;",
        "import com.bosch.nevonex.types.impl.TypesPackage;",
    ])

    # --- Plugin-specific imports ---
    for pl in plugins:
        L.append(f"import com.bosch.nevonex.{pl['pkg']}.impl.{pl['package_class']};")
        L.append(f"import com.bosch.nevonex.{pl['pkg']}.impl.{pl['provider']};")
        L.append(f"import com.bosch.nevonex.{pl['pkg']}.impl.{pl['machine']};")

    L.extend(["", "", "public class SDKTest {"])

    # --- Fields ---
    L.append("    private static TestFilClient filClient = TestFilClient.getInstance();")
    L.append("    private static Properties prop;")
    L.append("    private static Map<String, String> featureToAddressMap = new HashMap<>();")
    for pl in plugins:
        L.append(f"    private static {pl['provider']} {pl['field']};")
    L.append("")

    # --- setUp ---
    L.extend([
        "    @BeforeClass",
        "    public static void setUp() throws Exception {",
        "        initialize();",
        "        initializeDom();",
        "        prop = readSimulatorPropertiesFile();",
        "        initMaps();",
        "    }",
        "",
    ])

    # --- initialize ---
    L.extend([
        "    private static void initialize() throws NevonexException {",
        "        FCALRuntime runtime = new FCALRuntime();",
        "        List<ProviderEnum> providerValues = ProviderEnum.VALUES;",
        "        String[] providerarr = new String[providerValues.size()];",
        "        int index = 0;",
        "        for (ProviderEnum providerEnum : providerValues) {",
        "            providerarr[index] = providerEnum.getName();",
        "            index++;",
        "        }",
        "        runtime.startRuntime(providerarr, new String[0], new String[0]);",
        "        runtime.initialize();",
        "        runtime.startProviders();",
    ])
    for pl in plugins:
        L.append(f'        {pl["field"]} = ({pl["provider"]}) runtime.getMachineProvider("{pl["provider"]}");')
    L.extend([
        '        FCALLogs.getInstance().log.info("Runtime started ...");',
        "    }",
        "",
    ])

    # --- initializeDom ---
    wait_cond = " || ".join(f'{pl["field"]}.{pl["getter"]} == null' for pl in plugins)
    L.extend([
        "    private static void initializeDom() throws Exception {",
        '        filClient.createDom(TestFilClient.TOPIC_CREATION, "./data/sample_data.xml");',
        f"        while ({wait_cond}) {{",
        "            Thread.sleep(5000);",
        "        }",
        "    }",
        "",
    ])

    # --- initMaps ---
    L.append("    public static void initMaps() {")
    for pl in plugins:
        L.append(f'        featureToAddressMap.put("{pl["name"]}.machineconnect.sub", "/1/+");')
        L.append(f'        featureToAddressMap.put("{pl["name"]}.machinedata.sub", "/0/+");')
        for iface in pl["interfaces"]:
            L.append(f'        featureToAddressMap.put("{pl["name"]}.{iface["camel"]}.sub", "/{iface["id"]}");')
    L.extend(["    }", ""])

    # --- testMachineDomBuild ---
    L.extend(["    @Test", "    public void testMachineDomBuild() {"])
    for pl in plugins:
        var = pl["name"][0].lower() + pl["name"][1:]
        L.append(f'        {pl["machine"]} {var} = ({pl["machine"]}) {pl["field"]}.{pl["getter"]};')
        L.append(f'        assertNotNull({var});')
    L.extend(["    }", ""])

    # --- testSubscribe per interface ---
    for pl in plugins:
        for iface in pl["interfaces"]:
            fcal = f"com.bosch.nevonex.fcal.I{iface['emf_class']}"
            var = pl["name"][0].lower() + pl["name"][1:] + "_"
            L.extend([
                "    @Test",
                f"    public void testSubscribe{pl['name']}{iface['name']}() throws Exception {{",
                f'        String address = "/{iface["id"]}";',
                "        EStructuralFeature feature = getFeatureByInterfaceAddress(address);",
                f"        {fcal} value = ({fcal}) getRandomValue(feature, prop);",
                f"        {pl['machine']} {var} = ({pl['machine']}) {pl['field']}.{pl['getter']};",
                f"        {var}.eUnset(feature);",
                f'        filClient.publishValue("{pl["name"]}" + address, value, "0", "0");',
                "        int k = 0;",
                f"        while (!{var}.eIsSet(feature)) {{",
                "            Thread.sleep(250);",
                "            if (++k == 20) break;",
                "        }",
                f"        assertTrue({var}.eIsSet(feature));",
                f"        {fcal} testTemp = ({fcal}) {var}.get{iface['pascal']}();",
                "        Object[] expected = value.getArrayValues();",
                "        Object[] actual = testTemp.getArrayValues();",
                "        for (int i = 0; i < expected.length; i++) {",
                "            if (expected[i].getClass().isArray() && actual[i].getClass().isArray()) {",
                "                if (expected[i] instanceof int[] && actual[i] instanceof int[]) {",
                "                    org.junit.Assert.assertArrayEquals((int[]) expected[i], (int[]) actual[i]);",
                "                } else if (expected[i] instanceof float[] && actual[i] instanceof float[]) {",
                "                    org.junit.Assert.assertArrayEquals((float[]) expected[i], (float[]) actual[i], 0.001f);",
                "                } else if (expected[i] instanceof double[] && actual[i] instanceof double[]) {",
                "                    org.junit.Assert.assertArrayEquals((double[]) expected[i], (double[]) actual[i], 0.001);",
                "                } else if (expected[i] instanceof long[] && actual[i] instanceof long[]) {",
                "                    org.junit.Assert.assertArrayEquals((long[]) expected[i], (long[]) actual[i]);",
                "                } else if (expected[i] instanceof boolean[] && actual[i] instanceof boolean[]) {",
                "                    org.junit.Assert.assertArrayEquals((boolean[]) expected[i], (boolean[]) actual[i]);",
                "                } else {",
                "                    org.junit.Assert.assertArrayEquals((Object[]) expected[i], (Object[]) actual[i]);",
                "                }",
                "            } else {",
                "                assertEquals(expected[i], actual[i]);",
                "            }",
                "        }",
                "    }",
                "",
            ])

    # --- getEClassByName ---
    L.extend(["    public static EClass getEClassByName(String name) {", "        switch (name) {"])
    for pl in plugins:
        L.append(f'        case "{pl["name"].lower()}":')
        L.append(f'            return {pl["package_class"]}.eINSTANCE.get{pl["machine"]}();')
        for iface in pl["interfaces"]:
            L.append(f'        case "{iface["emf_class"].lower()}":')
            L.append(f'            return FcalPackage.eINSTANCE.get{iface["emf_class"]}();')
    L.extend([
        '        case "fcalcontroller":',
        "            return FcbPackage.eINSTANCE.getFCALController();",
        '        case "imachineprovider":',
        "            return TypesPackage.eINSTANCE.getIMachineProvider();",
        "        }",
        "        return null;",
        "    }",
        "",
    ])

    # --- Utility methods (plugin-independent) ---
    L.append(_SDK_TEST_UTILS)

    L.append("}")
    return "\n".join(L) + "\n"


def gen_app_classpath():
    """Generate .classpath for application project"""
    return '''<?xml version="1.0" encoding="UTF-8"?>
<classpath>
\t<classpathentry kind="src" path="src"/>
\t<classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER/org.eclipse.jdt.internal.debug.ui.launcher.StandardVMType/JavaSE-1.8"/>
\t<classpathentry kind="con" path="org.eclipse.m2e.MAVEN2_CLASSPATH_CONTAINER"/>
\t<classpathentry kind="output" path="bin"/>
</classpath>
'''


def gen_app_eclipse_project(name):
    """Generate .project for application project"""
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
\t<name>{name}</name>
\t<comment></comment>
\t<projects>
\t</projects>
\t<buildSpec>
\t\t<buildCommand>
\t\t\t<name>org.eclipse.jdt.core.javabuilder</name>
\t\t\t<arguments>
\t\t\t</arguments>
\t\t</buildCommand>
\t\t<buildCommand>
\t\t\t<name>org.eclipse.m2e.core.maven2Builder</name>
\t\t\t<arguments>
\t\t\t</arguments>
\t\t</buildCommand>
\t</buildSpec>
\t<natures>
\t\t<nature>org.eclipse.m2e.core.maven2Nature</nature>
\t\t<nature>org.eclipse.jdt.core.javanature</nature>
\t\t<nature>org.eclipse.pde.PluginNature</nature>
\t</natures>
</projectDescription>
'''


# ============================================================
# Interactive Wizard
# ============================================================

def interactive_plugin_selection():
    """Interactive plugin selection with interface counts"""
    print("\nAvailable Plugins:")
    print(f"  {'#':>3}  {'Name':<30}  {'ID':>6}  {'Interfaces':>10}")
    print(f"  {'─'*3}  {'─'*30}  {'─'*6}  {'─'*10}")
    plugin_list = list(PLUGINS.keys())
    for i, pname in enumerate(plugin_list, 1):
        p = PLUGINS[pname]
        n_ifaces = len(p["interfaces"])
        print(f"  {i:>3}  {pname:<30}  {p['machine_id']:>6}  {n_ifaces:>10}")
    print()

    selected = input("Select plugins (comma-separated numbers, e.g. 1,2): ").strip()
    if not selected:
        print("No plugins selected. Using GPSPlugin as default.")
        return ["GPSPlugin"]

    indices = [int(x.strip()) for x in selected.split(",")]
    result = []
    for idx in indices:
        if 1 <= idx <= len(plugin_list):
            result.append(plugin_list[idx - 1])
        else:
            print(f"Warning: invalid selection {idx}, skipping")

    if not result:
        print("No valid plugins selected. Using GPSPlugin as default.")
        return ["GPSPlugin"]

    return result


def interactive_interface_selection(plugin_names):
    """Interactive interface selection from chosen plugins.

    Returns:
        {plugin_name: [selected_iface_name, ...]} or None if 'all' chosen
    """
    print("\nInterfaces from selected plugins:\n")
    iface_map = []  # (global_idx, plugin_name, iface_name)
    global_idx = 1

    for pname in plugin_names:
        p = PLUGINS[pname]
        ifaces = p["interfaces"]
        print(f"  {pname} ({len(ifaces)} interfaces):")
        for iface in ifaces:
            direction = "IN " if iface["access_type"] == "In" else "OUT"
            dtype = iface["data_type"]
            mode = iface["mode"]
            print(f"    {global_idx:>3}  {iface['name']:<30}  {direction}  {dtype:<10}  {mode}")
            iface_map.append((global_idx, pname, iface["name"]))
            global_idx += 1
    print()

    selected = input("Select interfaces (comma-separated numbers, or 'all'): ").strip()
    if not selected or selected.lower() == "all":
        return None

    indices = set()
    for part in selected.split(","):
        part = part.strip()
        if part.isdigit():
            indices.add(int(part))

    result = {}
    for idx, pname, iname in iface_map:
        if idx in indices:
            result.setdefault(pname, []).append(iname)

    if not result:
        print("No valid interfaces selected. Using all interfaces.")
        return None

    total = sum(len(v) for v in result.values())
    print(f"  Selected {total} interface(s).")
    return result


def interactive_project_type_selection():
    """Interactive project type selection.

    Returns:
        "java" or "cpp"
    """
    print("\nProject type:")
    print("    1  Java (Recommended)")
    print("    2  C++ (CPP)")
    print()

    selected = input("Select project type (1 or 2, default: 1): ").strip()
    if selected == "2":
        return "cpp"
    return "java"


# ============================================================
# Project Creation - Java
# ============================================================

def copy_gen_project(name, filtered_plugins):
    """Copy reference gen project and rename for new project.
    Dynamically generates SDK packages for plugins not in the reference."""
    src = REFERENCE_GEN
    dst = os.path.join(WORKSPACE, name, f"com.bosch.fsp.{name}.gen")

    if not os.path.exists(src):
        print(f"Error: Reference gen project not found at {src}")
        return False

    # Copy entire directory
    shutil.copytree(src, dst)

    # Remove target/ if present
    target_dir = os.path.join(dst, "target")
    if os.path.exists(target_dir):
        shutil.rmtree(target_dir)

    # Rename "agnote" references in build files
    rename_map = {
        "pom.xml": [("agnote", name)],
        ".project": [("com.bosch.fsp.agnote.gen", f"com.bosch.fsp.{name}.gen")],
    }

    for filename, replacements in rename_map.items():
        filepath = os.path.join(dst, filename)
        if os.path.exists(filepath):
            with open(filepath, "r") as f:
                content = f.read()
            for old, new in replacements:
                content = content.replace(old, new)
            with open(filepath, "w") as f:
                f.write(content)

    # Generate SDK packages for plugins not in reference
    dst_src_dir = os.path.join(dst, "src")
    generate_plugin_sdk_packages(dst_src_dir, filtered_plugins)

    print(f"  Created: com.bosch.fsp.{name}.gen/ (SDK)")
    return True


def copy_gen_tests_project(name, filtered_plugins, port):
    """Copy reference gen.tests project and customize for new project."""
    src = REFERENCE_GEN_TESTS
    dst = os.path.join(WORKSPACE, name, f"com.bosch.fsp.{name}.gen.tests")

    if not os.path.exists(src):
        print(f"Warning: Reference gen.tests not found at {src}, skipping.")
        return False

    # Copy entire directory
    shutil.copytree(src, dst)

    # Remove build artifacts if present
    for d in ["bin", "target", "testlib"]:
        artifact_dir = os.path.join(dst, d)
        if os.path.exists(artifact_dir):
            shutil.rmtree(artifact_dir)

    # PascalCase name
    pascal_name = name[0].upper() + name[1:]

    # Replace agnote/Agnote placeholders with project name
    replacements = [
        ("Agnote", pascal_name),
        ("agnote", name),
    ]

    for dirpath, _, filenames in os.walk(dst):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            if _is_text_file(fpath):
                _replace_in_text_file(fpath, replacements)

    # Regenerate plugin-dependent Manifest.xml
    manifest_path = os.path.join(dst, "data", "Manifest.xml")
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    with open(manifest_path, "w") as f:
        f.write(gen_manifest(name, filtered_plugins, port))

    # Update feature.config with correct port
    config_path = os.path.join(dst, "feature.config")
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            config = f.read()
        config = re.sub(r'"customui_port"\s*:\s*\d+', f'"customui_port": {port}', config)
        with open(config_path, "w") as f:
            f.write(config)

    # Update Simulator.properties uiFolderLocation
    sim_path = os.path.join(dst, "Simulator.properties")
    if os.path.exists(sim_path):
        with open(sim_path, "r") as f:
            content = f.read()
        content = re.sub(
            r'uiFolderLocation=.*',
            f'uiFolderLocation=/workspace/{name}/{name}/ui',
            content,
        )
        with open(sim_path, "w") as f:
            f.write(content)

    # Scan gen SDK to find available fcal data type classes
    gen_sdk_fcal = os.path.join(WORKSPACE, name, f"com.bosch.fsp.{name}.gen",
                                "src", "com", "bosch", "nevonex", "fcal")
    available_fcal_types = set()
    if os.path.isdir(gen_sdk_fcal):
        for fname in os.listdir(gen_sdk_fcal):
            if (fname.startswith("I") and fname.endswith(".java")
                    and fname not in ("IFcalFactory.java", "IBulkProcessor.java")):
                available_fcal_types.add(fname[1:-5])  # e.g. "GPS_INFO_R"

    # Regenerate SDKTest.java based on selected plugins (replaces hardcoded template)
    sdk_test_path = os.path.join(dst, "src", "com", "bosch", "nevonex", "sdk", "test", "SDKTest.java")
    os.makedirs(os.path.dirname(sdk_test_path), exist_ok=True)
    with open(sdk_test_path, "w") as f:
        f.write(gen_sdk_test(name, filtered_plugins, available_fcal_types or None))

    print(f"  Created: com.bosch.fsp.{name}.gen.tests/ (Test Simulator)")
    return True


def create_feature_design_project(name, filtered_plugins, port, project_type="java"):
    """Create the feature design project (com.bosch.fsp.{name}/)"""
    project_dir = os.path.join(WORKSPACE, name, f"com.bosch.fsp.{name}")
    os.makedirs(project_dir, exist_ok=True)

    files = {
        f"{name}.fgd": gen_fgd(name, filtered_plugins, port),
        f"{name}.fsp": gen_fsp(filtered_plugins),
        "Manifest.xml": gen_manifest(name, filtered_plugins, port),
        "FDProject.props": gen_fdproject_props(name, project_type),
        "topic_mapping.json": gen_topic_mapping(filtered_plugins),
        "topic_prefixes.json": gen_topic_prefixes(),
        "interface_extract.json": gen_interface_extract(filtered_plugins),
        "machine_path.json": gen_machine_path(filtered_plugins),
        ".project": gen_eclipse_project(f"com.bosch.fsp.{name}"),
    }

    for fname, content in files.items():
        with open(os.path.join(project_dir, fname), "w") as f:
            f.write(content)

    print(f"  Created: com.bosch.fsp.{name}/ (Feature Design)")


def create_application_project(name, filtered_plugins, port):
    """Create the Java application project ({name}/)"""
    project_dir = os.path.join(WORKSPACE, name, name)
    src_dir = os.path.join(project_dir, "src", "com", "bosch", "nevonex", "main", "impl")
    os.makedirs(src_dir, exist_ok=True)

    # Create standard directories
    for d in ["in", "out", "logs", "disk", "bin"]:
        os.makedirs(os.path.join(project_dir, d), exist_ok=True)

    files = {
        "pom.xml": gen_app_pom(name),
        "Manifest.xml": gen_manifest(name, filtered_plugins, port),
        "feature.config": gen_feature_config(port),
        ".project": gen_app_eclipse_project(name),
        ".classpath": gen_app_classpath(),
    }

    for fname, content in files.items():
        with open(os.path.join(project_dir, fname), "w") as f:
            f.write(content)

    # EMF interfaces (main/ package)
    iface_dir = os.path.join(project_dir, "src", "com", "bosch", "nevonex", "main")
    pascal_name = name[0].upper() + name[1:]
    iface_files = {
        "IApplicationMain.java": gen_iface_application_main(),
        "IApplicationInputData.java": gen_iface_application_input_data(filtered_plugins),
        f"I{pascal_name}.java": gen_iface_controller(name),
        "IFeatureManagerListener.java": gen_iface_feature_manager_listener(),
        "IIgnitionStateListener.java": gen_iface_ignition_state_listener(),
        "IMachineConnectListener.java": gen_iface_machine_connect_listener(),
        "IUIWebsocketEndPoint.java": gen_iface_ui_websocket_endpoint(),
        "IMainFactory.java": gen_iface_main_factory(name),
        "ISampleGetService.java": gen_iface_sample_service(name, "Get"),
        "ISamplePostService.java": gen_iface_sample_service(name, "Post"),
        "ISamplePutService.java": gen_iface_sample_service(name, "Put"),
        "ISampleDeleteService.java": gen_iface_sample_service(name, "Delete"),
    }
    for fname, content in iface_files.items():
        with open(os.path.join(iface_dir, fname), "w") as f:
            f.write(content)

    # Impl classes (main/impl/ package)
    java_files = {
        "ApplicationMain.java": gen_application_main(name, filtered_plugins),
        f"{pascal_name}.java": gen_controller_class(name, filtered_plugins),
        "FeatureManagerListener.java": gen_feature_manager_listener(),
        "IgnitionStateListener.java": gen_ignition_state_listener(),
        "MachineConnectListener.java": gen_machine_connect_listener(),
        "UIWebsocketEndPoint.java": gen_ui_websocket_endpoint(),
        "ApplicationInputData.java": gen_application_input_data(filtered_plugins),
        "MainFactory.java": gen_main_factory(name),
        "MainPackage.java": gen_main_package(name, filtered_plugins),
        "SampleGetService.java": gen_sample_service(name, "Get"),
        "SamplePostService.java": gen_sample_service(name, "Post"),
        "SamplePutService.java": gen_sample_service(name, "Put"),
        "SampleDeleteService.java": gen_sample_service(name, "Delete"),
    }
    for fname, content in java_files.items():
        with open(os.path.join(src_dir, fname), "w") as f:
            f.write(content)

    # Util classes (main/util/ package)
    util_dir = os.path.join(project_dir, "src", "com", "bosch", "nevonex", "main", "util")
    os.makedirs(util_dir, exist_ok=True)
    util_files = {
        "MainAdapterFactory.java": gen_main_adapter_factory(name, filtered_plugins),
        "MainSwitch.java": gen_main_switch(name, filtered_plugins),
    }
    for fname, content in util_files.items():
        with open(os.path.join(util_dir, fname), "w") as f:
            f.write(content)

    print(f"  Created: {name}/ (Application)")


# ============================================================
# Project Creation - C++
# ============================================================

def _cpp_name_variants(name):
    """Generate name variants for C++ template substitution.

    Returns dict with: lower, upper, pascal, original
    """
    # PascalCase: capitalize first letter, and letter after each underscore
    parts = name.split("_")
    pascal = "".join(p[0].upper() + p[1:] if p else "" for p in parts)
    return {
        "lower": name.lower(),
        "upper": name.upper(),
        "pascal": pascal,
        "original": name,
    }


def _replace_in_text_file(filepath, replacements):
    """Apply a list of (old, new) replacements to a text file."""
    try:
        with open(filepath, "r", errors="ignore") as f:
            content = f.read()
        for old, new in replacements:
            content = content.replace(old, new)
        with open(filepath, "w") as f:
            f.write(content)
    except (UnicodeDecodeError, IsADirectoryError):
        pass


def _is_text_file(filepath):
    """Check if a file is likely a text file based on extension."""
    text_exts = {
        ".txt", ".cmake", ".cmake.in", ".xml", ".sh", ".hpp", ".cpp",
        ".json", ".gdl", ".ecore", ".prefs",
        ".properties", ".in", ".md", ".java", ".MF",
    }
    text_dotfiles = {".project", ".classpath", ".gitignore"}
    basename = os.path.basename(filepath)
    _, ext = os.path.splitext(filepath)
    return ext.lower() in text_exts or basename in text_dotfiles


def _rename_in_tree(root_dir, old_str, new_str):
    """Rename files and directories containing old_str in their name."""
    # Rename files first (bottom-up to handle nested paths)
    for dirpath, dirnames, filenames in os.walk(root_dir, topdown=False):
        for fname in filenames:
            if old_str in fname:
                old_path = os.path.join(dirpath, fname)
                new_path = os.path.join(dirpath, fname.replace(old_str, new_str))
                os.rename(old_path, new_path)
        for dname in dirnames:
            if old_str in dname:
                old_path = os.path.join(dirpath, dname)
                new_path = os.path.join(dirpath, dname.replace(old_str, new_str))
                os.rename(old_path, new_path)


def copy_cpp_sdk_project(name):
    """Copy reference C++ SDK project and rename for new project."""
    src = REFERENCE_GEN_CPP_SDK
    dst = os.path.join(WORKSPACE, name, f"{name}_CPP_SDK")

    if not os.path.exists(src):
        print(f"Error: Reference C++ SDK project not found at {src}")
        return False

    shutil.copytree(src, dst)

    v = _cpp_name_variants(name)

    # Text replacements (order: longest first to avoid partial matches)
    replacements = [
        ("AGNOTE", v["upper"]),
        ("agnote", v["lower"]),
    ]

    for dirpath, _, filenames in os.walk(dst):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            if _is_text_file(fpath):
                _replace_in_text_file(fpath, replacements)

    # Rename files: AGNOTE -> upper, agnote -> lower
    _rename_in_tree(dst, "AGNOTE", v["upper"])
    _rename_in_tree(dst, "agnote", v["lower"])

    print(f"  Created: {name}_CPP_SDK/ (C++ SDK)")
    return True


def create_cpp_application_project(name, filtered_plugins, port):
    """Copy reference C++ app project, rename, and regenerate plugin-dependent files."""
    src = REFERENCE_GEN_CPP_APP
    dst = os.path.join(WORKSPACE, name, f"{name}_{name}")

    if not os.path.exists(src):
        print(f"Error: Reference C++ app project not found at {src}")
        return False

    shutil.copytree(src, dst)

    v = _cpp_name_variants(name)

    # Text replacements (order: most specific first)
    replacements = [
        ("Agnote", v["pascal"]),
        ("AGNOTE", v["upper"]),
        ("agnote", v["lower"]),
    ]

    for dirpath, _, filenames in os.walk(dst):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            if _is_text_file(fpath):
                _replace_in_text_file(fpath, replacements)

    # Rename files
    _rename_in_tree(dst, "Agnote", v["pascal"])
    _rename_in_tree(dst, "AGNOTE", v["upper"])
    _rename_in_tree(dst, "agnote", v["lower"])

    # Regenerate plugin-dependent files
    manifest_path = os.path.join(dst, "Manifest.xml")
    with open(manifest_path, "w") as f:
        f.write(gen_manifest(name, filtered_plugins, port))

    config_path = os.path.join(dst, "config", "feature.config")
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        f.write(gen_cpp_feature_config(port))

    # Create standard directories
    for d in ["temp/download", "temp/upload", "disk", "ui"]:
        os.makedirs(os.path.join(dst, d), exist_ok=True)

    print(f"  Created: {name}_{name}/ (C++ Application)")
    return True


# ============================================================
# Project Orchestrator
# ============================================================

def create_project(name, plugins=None, port=DEFAULT_UI_PORT,
                   interactive=False, project_type=None, selected_interfaces=None):
    """Create a complete FeatureDesigner project"""
    project_root = os.path.join(WORKSPACE, name)

    if os.path.exists(project_root):
        print(f"Error: Project '{name}' already exists at {project_root}")
        sys.exit(1)

    # --- Determine plugins, interfaces, and project type ---
    if plugins:
        # CLI mode: plugins explicitly provided
        for p in plugins:
            if p not in PLUGINS:
                print(f"Error: Unknown plugin '{p}'")
                print(f"Available: {', '.join(PLUGINS.keys())}")
                sys.exit(1)
        if project_type is None:
            project_type = "java"
    elif interactive or sys.stdin.isatty():
        # Interactive wizard mode
        plugins = interactive_plugin_selection()
        selected_interfaces = interactive_interface_selection(plugins)
        print("\n  UI Type: CustomUI (fixed)")
        if project_type is None:
            project_type = interactive_project_type_selection()
    else:
        # Non-interactive default
        plugins = ["GPSPlugin"]
        if project_type is None:
            project_type = "java"

    # Build filtered plugins dict
    filtered_plugins = build_filtered_plugins(plugins, selected_interfaces)

    total_ifaces = sum(len(p["interfaces"]) for p in filtered_plugins.values())
    print(f"\n{'='*60}")
    print(f"  Creating project: {name}")
    print(f"  Type: {project_type.upper()}")
    print(f"  Plugins: {', '.join(plugins)} ({total_ifaces} interfaces)")
    print(f"  UI Port: {port}")
    print(f"  Location: {project_root}")
    print(f"{'='*60}\n")

    os.makedirs(project_root, exist_ok=True)

    # 1. Feature Design Project (common to both types)
    create_feature_design_project(name, filtered_plugins, port, project_type)

    if project_type == "cpp":
        # 2a. Java SDK Gen Project (needed for gen.tests compilation)
        copy_gen_project(name, filtered_plugins)
        # 2b. C++ SDK Project
        copy_cpp_sdk_project(name)
        # 3. C++ Application Project
        create_cpp_application_project(name, filtered_plugins, port)
    else:
        # 2. Java SDK Gen Project
        copy_gen_project(name, filtered_plugins)
        # 3. Java Application Project
        create_application_project(name, filtered_plugins, port)

    # 4. Test Simulator Project (common to both types)
    copy_gen_tests_project(name, filtered_plugins, port)

    print(f"\nProject '{name}' created successfully!")
    print(f"\nNext steps:")
    print(f"  1. Build:  fd-commands.sh build {name}")
    print(f"  2. Run:    fd-commands.sh run {name}")
    print(f"  3. Test:   fd-commands.sh test {name}")


# ============================================================
# CLI Entry Point
# ============================================================

def cmd_list_plugins(verbose=False):
    """List all available plugins in table format"""
    total_ifaces = sum(len(p["interfaces"]) for p in PLUGINS.values())
    print(f"\nAvailable Plugins ({len(PLUGINS)}, {total_ifaces} interfaces total):\n")
    print(f"  {'Name':<30}  {'ID':>6}  {'Interfaces':>10}  {'Standard':<10}  Description")
    print(f"  {'─'*30}  {'─'*6}  {'─'*10}  {'─'*10}  {'─'*30}")

    for pname in sorted(PLUGINS.keys()):
        p = PLUGINS[pname]
        n_ifaces = len(p["interfaces"])
        # Collect unique standards
        standards = sorted(set(iface["standard"] for iface in p["interfaces"] if iface["standard"]))
        std_str = ",".join(standards) if standards else "-"
        # First interface description as summary
        desc = p["interfaces"][0]["description"][:30] if p["interfaces"] else "-"
        print(f"  {pname:<30}  {p['machine_id']:>6}  {n_ifaces:>10}  {std_str:<10}  {desc}")

    if verbose:
        print(f"\n{'─'*90}")
        for pname in sorted(PLUGINS.keys()):
            p = PLUGINS[pname]
            print(f"\n  {pname} (ID: {p['machine_id']}, Provider: {p['provider_class']})")
            # Count by type
            read_count = sum(1 for i in p["interfaces"] if i["access_type"] == "In")
            write_count = sum(1 for i in p["interfaces"] if i["access_type"] == "Out")
            print(f"    Read: {read_count}, Write: {write_count}")
            for iface in p["interfaces"][:10]:
                arr_info = ""
                if "array" in iface:
                    fields = ", ".join(f["name"] for f in iface["array"]["fields"])
                    arr_info = f" [{fields}]"
                direction = "IN " if iface["access_type"] == "In" else "OUT"
                print(f"    {direction} {iface['name']} (ID:{iface['id']}, {iface['data_type']}, {iface['mode']}){arr_info}")
            if len(p["interfaces"]) > 10:
                print(f"    ... and {len(p['interfaces']) - 10} more interfaces")

    print()


def main():
    load_plugins_from_model()

    parser = argparse.ArgumentParser(description="FeatureDesigner CLI Project Creator")
    subparsers = parser.add_subparsers(dest="command")

    # create command
    create_parser = subparsers.add_parser("create", help="Create a new project")
    create_parser.add_argument("name", help="Project name")
    create_parser.add_argument("--plugins", "-p", help="Comma-separated plugin names (e.g. GPSPlugin,Implement)")
    create_parser.add_argument("--port", type=int, default=DEFAULT_UI_PORT, help=f"CustomUI port (default: {DEFAULT_UI_PORT})")
    create_parser.add_argument("--type", "-t", choices=["java", "cpp"], default=None, help="Project type (default: java)")

    # list-plugins command
    list_parser = subparsers.add_parser("list-plugins", help="List available plugins")
    list_parser.add_argument("--verbose", "-v", action="store_true", help="Show interface details")

    args = parser.parse_args()

    if args.command == "create":
        plugins = args.plugins.split(",") if args.plugins else None
        create_project(args.name, plugins=plugins, port=args.port, project_type=args.type)

    elif args.command == "list-plugins":
        cmd_list_plugins(verbose=args.verbose)

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
