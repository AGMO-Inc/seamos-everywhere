#!/bin/bash
# lib/interface.sh — Shared helpers for interface JSON synthesis.
# Source (don't execute).

# synth_interface_json_entry <branch> <config> <out_file>
#   Append a single entry to the out_file (array; created if not exists).
synth_interface_json_entry() {
  local branch="$1"
  local config="$2"
  local out_file="$3"

  [[ -n "$branch" ]] || { echo "synth: branch required" >&2; return 1; }
  [[ -f "$out_file" ]] || echo '[]' > "$out_file"

  local tmp="${out_file}.tmp.$$"
  jq --arg b "$branch" --arg c "$config" '. + [{branch:$b, config:$c}]' "$out_file" > "$tmp"
  mv "$tmp" "$out_file"
}

# synth_interface_json <offlinedb_path> <selections_path> <out_file>
#   selections: lines of "element_idx interface_idx update_rate_or_ms"
#   (simplified deterministic-from-fixture form for unit testing)
synth_interface_json() {
  local offlinedb="$1"
  local selections="$2"
  local out_file="$3"

  [[ -r "$offlinedb" ]] || { echo "synth: offlineDB.json not readable" >&2; return 1; }
  [[ -r "$selections" ]] || { echo "synth: selections file not readable" >&2; return 1; }

  : > "$out_file"
  echo '[]' > "$out_file"

  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    local el_idx if_idx rate
    el_idx=$(echo "$line" | awk '{print $1}')
    if_idx=$(echo "$line" | awk '{print $2}')
    rate=$(echo "$line" | awk '{print $3}')

    local el_name iface_name default_rate branch config
    el_name=$(jq -r ".elements[$el_idx].name" "$offlinedb")
    iface_name=$(jq -r ".elements[$el_idx].interfaces[$if_idx].interfaceName" "$offlinedb")
    default_rate=$(jq -r ".elements[$el_idx].interfaces[$if_idx].updateRate" "$offlinedb")

    branch="${el_name}/${iface_name}"
    if [[ "$rate" =~ ^[0-9]+$ ]]; then
      config="Cyclic/${rate}ms"
    elif [[ -n "$rate" && "$rate" != "-" ]]; then
      config="$rate"
    else
      config="$default_rate"
    fi

    synth_interface_json_entry "$branch" "$config" "$out_file"
  done < "$selections"
}
