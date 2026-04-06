#!/usr/bin/env python3
"""
parse-fgd.py - Parse a SEAMOS .fgd XML file and generate Markdown detail files
for each plugin (provider).

Usage:
    parse-fgd.py --fgd <path> [--fsp <path>] --output <dir>
"""

import argparse
import os
import re
import xml.etree.ElementTree as ET


# ---------------------------------------------------------------------------
# Namespace constants
# ---------------------------------------------------------------------------
NS_XSI = "http://www.w3.org/2001/XMLSchema-instance"
NS_FCAL = "www.bosch.com/fcal"
NS_XMI = "http://www.omg.org/XMI"

FCAL_TAG = "{" + NS_FCAL + "}"
XSI_TAG = "{" + NS_XSI + "}"
XMI_TAG = "{" + NS_XMI + "}"

MAX_DESC_LENGTH = 120


# ---------------------------------------------------------------------------
# Category classification
# ---------------------------------------------------------------------------
def classify_category(name: str) -> str:
    """Return a category string based on plugin name keywords."""
    if "Serial" in name and "GPS" in name:
        return "Position/Serial"
    if "GPS" in name or "gps" in name:
        return "Position"
    if "IMU" in name or "Gyro" in name or "MTLT" in name or "Allynav" in name:
        return "Sensor/IMU"
    if "Motor" in name or "Steer" in name:
        return "Actuator"
    if "Tractor" in name:
        return "Vehicle Control"
    if "GPIO" in name:
        return "GPIO"
    if "ISOPGN" in name:
        return "ISO Standard"
    if "Platform" in name:
        return "Platform Service"
    if "Implement" in name:
        return "Implement"
    if "TCOperations" in name:
        return "Task Controller"
    return "General"


# ---------------------------------------------------------------------------
# .fsp parser — maps provider name → Java class path
# ---------------------------------------------------------------------------
def load_fsp(fsp_path: str) -> dict:
    """
    Parse a .fsp properties file.
    Each line: PluginName_Provider=com.example.ClassName
    Returns a dict: { "PluginName": "com.example.ClassName" }
    """
    mapping = {}
    if not fsp_path or not os.path.isfile(fsp_path):
        return mapping

    with open(fsp_path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            # Strip trailing _Provider suffix from the key
            plugin_name = re.sub(r"_Provider$", "", key.strip())
            mapping[plugin_name] = value.strip()

    return mapping


# ---------------------------------------------------------------------------
# Array index extraction helper
# ---------------------------------------------------------------------------
def extract_array_index(array_ref: str) -> int:
    """
    Extract integer index from an array reference like "//@arrays.5".
    Returns -1 if parsing fails.
    """
    match = re.search(r"//@arrays\.(\d+)$", array_ref or "")
    if match:
        return int(match.group(1))
    return -1


# ---------------------------------------------------------------------------
# .fgd XML parser
# ---------------------------------------------------------------------------
def parse_fgd(fgd_path: str):
    """
    Parse the .fgd XML file.

    Returns:
        providers  : list of provider dicts
        arrays     : list of array dicts (ordered by position in file)
    """
    tree = ET.parse(fgd_path)
    root = tree.getroot()

    # -----------------------------------------------------------------------
    # Parse all <arrays> elements (they appear after providers at the end)
    # Each array is referenced by its positional index: //@arrays.N
    # -----------------------------------------------------------------------
    raw_arrays = []
    for arr in root.findall("arrays"):
        name = arr.get("name", "")
        description = arr.get("description", "")
        fields = []
        for lit in arr.findall("arrayLiterals"):
            fields.append({
                "name": lit.get("name", ""),
                "type": lit.get("type", ""),
                "unit": lit.get("unit", "-"),
                "desc": lit.get("description", lit.get("elemDesc", "")),
            })
        # Also support <arrayElements> child tag variant
        for elem in arr.findall("arrayElements"):
            fields.append({
                "name": elem.get("elemName", ""),
                "type": elem.get("elemType", ""),
                "unit": elem.get("elemUnit", "-"),
                "desc": elem.get("elemDesc", ""),
            })
        raw_arrays.append({
            "name": name,
            "description": description,
            "fields": fields,
        })

    # -----------------------------------------------------------------------
    # Parse <providers> elements
    # -----------------------------------------------------------------------
    providers = []
    for prov_elem in root.findall("providers"):
        prov_name_raw = prov_elem.get("fname", "")
        # Strip trailing " provider" suffix to get the plugin name
        plugin_name = re.sub(r"\s+provider$", "", prov_name_raw, flags=re.IGNORECASE)

        feat_elem = prov_elem.find("features")
        if feat_elem is None:
            continue

        machine_id = feat_elem.get("machineID", "")

        # Collect direct <attributes> on <features>
        direct_attrs = _parse_attributes(feat_elem, raw_arrays)

        # Collect <elements> sub-groups (e.g. Platform_Service)
        elements = []
        for elem in feat_elem.findall("elements"):
            elem_name = elem.get("fname", "")
            elem_machine_id = elem.get("machineID", "")
            elem_attrs = _parse_attributes(elem, raw_arrays)
            if elem_attrs:
                elements.append({
                    "name": elem_name,
                    "machineID": elem_machine_id,
                    "attributes": elem_attrs,
                })

        providers.append({
            "plugin_name": plugin_name,
            "machineID": machine_id,
            "attributes": direct_attrs,
            "elements": elements,
        })

    return providers, raw_arrays


def _parse_attributes(parent_elem, raw_arrays: list) -> list:
    """
    Parse <attributes> children of a given XML element.
    Returns a list of attribute dicts.
    """
    attrs = []
    for attr in parent_elem.findall("attributes"):
        control = attr.get("attributeControl", "")
        name = attr.get("attributeName", "")
        attr_id = attr.get("attributeID", "")
        desc = attr.get("attributeDesc", "")
        standard = attr.get("attributeStandard", "")
        standard_id = attr.get("attributeStandardID", "")
        mode = attr.get("attributeMode", "")
        cyclic_unit = attr.get("attributeCyclicUnit", "") or "-"
        stage = attr.get("attributeStage", "")
        api_version = attr.get("attributeApiVersion", "")
        data_type = attr.get("attributeDataType", "")

        # Determine type/direction from <attributeType>
        attr_type_elem = attr.find("attributeType")
        xsi_type = ""
        array_ref = ""
        if attr_type_elem is not None:
            xsi_type = attr_type_elem.get(f"{XSI_TAG}type", "")
            array_ref = attr_type_elem.get("array", "")

        is_method = "METHOD_TYPE" in xsi_type

        # Map direction
        if is_method:
            direction = "Method"
        elif control == "Subscribe":
            direction = "In"
        elif control == "Publish":
            direction = "Out"
        else:
            direction = control or "-"

        # Resolve array fields
        array_fields = []
        if array_ref:
            idx = extract_array_index(array_ref)
            if 0 <= idx < len(raw_arrays):
                array_fields = raw_arrays[idx]["fields"]

        # Normalize desc — remove embedded carriage returns / newlines
        clean_desc = re.sub(r"[\r\n]+", " ", desc).strip()
        clean_desc = re.sub(r"\s{2,}", " ", clean_desc)
        # Truncate long descriptions — detailed field info is in Signal Fields section
        if len(clean_desc) > MAX_DESC_LENGTH:
            clean_desc = clean_desc[:MAX_DESC_LENGTH].rstrip() + " …"

        attrs.append({
            "control": control,
            "direction": direction,
            "name": name,
            "id": attr_id,
            "desc": clean_desc,
            "standard": standard,
            "standard_id": standard_id,
            "mode": mode,
            "cyclic_unit": cyclic_unit,
            "stage": stage,
            "api_version": api_version,
            "data_type": data_type,
            "is_method": is_method,
            "array_ref": array_ref,
            "array_fields": array_fields,
        })
    return attrs


# ---------------------------------------------------------------------------
# Markdown generation helpers
# ---------------------------------------------------------------------------
def _escape_pipe(text: str) -> str:
    """Escape pipe characters inside Markdown table cells."""
    return text.replace("|", "\\|")


def _row(*cells) -> str:
    """Format a Markdown table row."""
    return "| " + " | ".join(_escape_pipe(str(c)) for c in cells) + " |"


def _table_header(*headers) -> list:
    """Return header + separator rows for a Markdown table."""
    header_row = "| " + " | ".join(headers) + " |"
    sep_row = "|" + "|".join("-" * (len(h) + 2) for h in headers) + "|"
    return [header_row, sep_row]


def generate_markdown(provider: dict, fsp_map: dict) -> str:
    """Generate the full Markdown content for a single provider/plugin."""
    plugin_name = provider["plugin_name"]
    machine_id = provider["machineID"]
    provider_class = fsp_map.get(plugin_name, "-")
    category = classify_category(plugin_name)

    lines = []
    lines.append(f"# {plugin_name}")
    lines.append("")
    lines.append(f"- **Machine ID**: {machine_id}")
    lines.append(f"- **Provider Class**: {provider_class}")
    lines.append(f"- **Category**: {category}")
    lines.append("")

    has_elements = bool(provider["elements"])
    has_direct_attrs = bool(provider["attributes"])

    lines.append("## Interfaces")
    lines.append("")

    if has_direct_attrs:
        # Render direct attributes as a flat signal table
        lines += _table_header(
            "Direction", "Signal", "Standard", "Standard ID",
            "Mode", "Cycle", "DataType", "Stage", "API Ver", "Description"
        )
        for attr in provider["attributes"]:
            lines.append(_row(
                attr["direction"],
                attr["name"],
                attr["standard"] or "-",
                attr["standard_id"] or "-",
                attr["mode"] or "-",
                attr["cyclic_unit"] if attr["cyclic_unit"] else "-",
                attr["data_type"] or "-",
                attr["stage"] or "-",
                attr["api_version"] or "-",
                attr["desc"] or "-",
            ))
        lines.append("")

    if has_elements:
        # Render each element group; detect whether it contains methods or signals
        for group in provider["elements"]:
            lines.append(f"### {group['name']} (Machine ID: {group['machineID']})")
            lines.append("")
            all_methods = all(a["is_method"] for a in group["attributes"]) if group["attributes"] else False
            if all_methods:
                lines += _table_header(
                    "Direction", "Method", "Mode", "Stage", "API Ver", "Description"
                )
                for attr in group["attributes"]:
                    lines.append(_row(
                        attr["direction"],
                        attr["name"],
                        attr["mode"] or "-",
                        attr["stage"] or "-",
                        attr["api_version"] or "-",
                        attr["desc"] or "-",
                    ))
            else:
                lines += _table_header(
                    "Direction", "Signal", "Standard", "Standard ID",
                    "Mode", "Cycle", "DataType", "Stage", "API Ver", "Description"
                )
                for attr in group["attributes"]:
                    lines.append(_row(
                        attr["direction"],
                        attr["name"],
                        attr["standard"] or "-",
                        attr["standard_id"] or "-",
                        attr["mode"] or "-",
                        attr["cyclic_unit"] if attr["cyclic_unit"] else "-",
                        attr["data_type"] or "-",
                        attr["stage"] or "-",
                        attr["api_version"] or "-",
                        attr["desc"] or "-",
                    ))
            lines.append("")

    if not has_direct_attrs and not has_elements:
        lines.append("*No interfaces defined.*")
        lines.append("")

    # Signal Fields section (for direct attributes and element attributes with array types)
    array_signals = [
        a for a in provider["attributes"] if a["array_fields"]
    ]
    # Also include array signals from elements
    for group in provider["elements"]:
        array_signals.extend([a for a in group["attributes"] if a["array_fields"]])
    if array_signals:
        lines.append("## Signal Fields")
        lines.append("")
        for attr in array_signals:
            lines.append(f"### {attr['name']}")
            lines.append("")
            lines += _table_header("Field", "Type", "Unit", "Description")
            for field in attr["array_fields"]:
                lines.append(_row(
                    field["name"],
                    field["type"] or "-",
                    field["unit"] or "-",
                    field["desc"] or "-",
                ))
            lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(
        description="Parse a SEAMOS .fgd XML file and generate Markdown plugin detail files."
    )
    parser.add_argument(
        "--fgd",
        required=True,
        metavar="FGD_PATH",
        help="Path to the .fgd XML file",
    )
    parser.add_argument(
        "--fsp",
        required=False,
        metavar="FSP_PATH",
        default=None,
        help="Path to the .fsp provider mapping file (optional)",
    )
    parser.add_argument(
        "--output",
        required=True,
        metavar="OUTPUT_DIR",
        help="Output directory for generated .md files",
    )
    args = parser.parse_args()

    # Validate input paths
    if not os.path.isfile(args.fgd):
        parser.error(f"FGD file not found: {args.fgd}")

    # Create output directory if it does not exist
    os.makedirs(args.output, exist_ok=True)

    # Load .fsp provider mapping
    fsp_map = load_fsp(args.fsp)

    # Parse .fgd
    print(f"Parsing: {args.fgd}")
    providers, _arrays = parse_fgd(args.fgd)
    print(f"Found {len(providers)} providers, {len(_arrays)} array definitions")

    # Generate one .md file per provider
    generated = 0
    for provider in providers:
        plugin_name = provider["plugin_name"]
        # Sanitize filename: replace spaces and special chars with underscores
        safe_name = re.sub(r"[^A-Za-z0-9_\-]", "_", plugin_name)
        out_path = os.path.join(args.output, f"{safe_name}.md")

        content = generate_markdown(provider, fsp_map)

        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(content)

        sig_count = len(provider["attributes"]) + sum(
            len(g["attributes"]) for g in provider["elements"]
        )
        print(f"  [{generated + 1:>2}] {plugin_name} → {os.path.basename(out_path)}  ({sig_count} signals/methods)")
        generated += 1

    print(f"\nDone. {generated} files written to: {args.output}")


if __name__ == "__main__":
    main()
