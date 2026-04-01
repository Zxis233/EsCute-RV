#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILELIST="${FILELIST:-$ROOT_DIR/filelist.f}"
TOP_MODULE="${TOP_MODULE:-CPU_TOP}"
SYNLIG_BIN="${SYNLIG_BIN:-synlig}"
SYNLIG_FRONTEND="${SYNLIG_FRONTEND:-read_systemverilog}"
SYNLIG_SYNTH_ARGS="${SYNLIG_SYNTH_ARGS:-}"
SYNLIG_USE_DEFER="${SYNLIG_USE_DEFER:-1}"
SYNLIG_USE_IROM_BLACKBOX="${SYNLIG_USE_IROM_BLACKBOX:-1}"
SYNLIG_USE_DRAM_BLACKBOX="${SYNLIG_USE_DRAM_BLACKBOX:-1}"

OUT_DIR="$ROOT_DIR/prj/synlig"
LOG_FILE="$OUT_DIR/sythesis.log"
JSON_OUT="$OUT_DIR/${TOP_MODULE}_synlig.json"
VERILOG_OUT="$OUT_DIR/${TOP_MODULE}_synlig.v"
BLACKBOX_DIR="$ROOT_DIR/user/tools/synlig_blackboxes"
WORK_ROOT="$OUT_DIR/work"

mkdir -p "$OUT_DIR"
mkdir -p "$WORK_ROOT"
RUN_DIR="$(mktemp -d "$WORK_ROOT/run.XXXXXX")"

if [[ ! -f "$FILELIST" ]]; then
    echo "error: filelist not found: $FILELIST" >&2
    exit 1
fi

include_args=()
rtl_files=()
declare -A seen_rtl=()

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="${raw_line%$'\r'}"
    line="$(trim "${line%%#*}")"

    [[ -z "$line" ]] && continue
    [[ "$line" == "read_slang" ]] && continue

    if [[ "$line" == -I* ]]; then
        include_path="$(trim "${line#-I}")"
        if [[ "$include_path" != /* ]]; then
            include_path="$ROOT_DIR/${include_path#./}"
        fi
        include_args+=("-I$include_path")
        continue
    fi

    if [[ "$line" == *.sv ]]; then
        base_name="${line##*/}"

        case "$line" in
            *"/sim/"*|*"/data/"*)
                continue
                ;;
        esac

        case "$base_name" in
            IROM.sv)
                [[ "$SYNLIG_USE_IROM_BLACKBOX" == "1" ]] && continue
                ;;
            DRAM.sv)
                [[ "$SYNLIG_USE_DRAM_BLACKBOX" == "1" ]] && continue
                ;;
            tb_*|test_tb.sv)
                continue
                ;;
        esac

        if [[ "$line" != /* ]]; then
            line="$ROOT_DIR/${line#./}"
        fi
        if [[ -z "${seen_rtl[$line]:-}" ]]; then
            rtl_files+=("$line")
            seen_rtl["$line"]=1
        fi
    fi
done < "$FILELIST"

while IFS= read -r src_file; do
    base_name="${src_file##*/}"
    case "$base_name" in
        IROM.sv)
            [[ "$SYNLIG_USE_IROM_BLACKBOX" == "1" ]] && continue
            ;;
        DRAM.sv)
            [[ "$SYNLIG_USE_DRAM_BLACKBOX" == "1" ]] && continue
            ;;
    esac
    if [[ -z "${seen_rtl[$src_file]:-}" ]]; then
        rtl_files+=("$src_file")
        seen_rtl["$src_file"]=1
    fi
done < <(find "$ROOT_DIR/user/src" -maxdepth 1 -type f -name '*.sv' | sort)

if [[ "$SYNLIG_USE_IROM_BLACKBOX" == "1" ]]; then
    stub_file="$BLACKBOX_DIR/IROM_blackbox.sv"
    if [[ -z "${seen_rtl[$stub_file]:-}" ]]; then
        rtl_files+=("$stub_file")
        seen_rtl["$stub_file"]=1
    fi
fi

if [[ "$SYNLIG_USE_DRAM_BLACKBOX" == "1" ]]; then
    stub_file="$BLACKBOX_DIR/DRAM_blackbox.sv"
    if [[ -z "${seen_rtl[$stub_file]:-}" ]]; then
        rtl_files+=("$stub_file")
        seen_rtl["$stub_file"]=1
    fi
fi

if [[ "${#rtl_files[@]}" -eq 0 ]]; then
    echo "error: no RTL files were collected from $FILELIST" >&2
    exit 1
fi

printf -v read_cmd '%s -noassert' "$SYNLIG_FRONTEND"
if [[ "$SYNLIG_USE_DEFER" == "1" ]]; then
    printf -v read_cmd '%s -defer' "$read_cmd"
fi
for arg in "${include_args[@]}" "${rtl_files[@]}"; do
    printf -v read_cmd '%s %q' "$read_cmd" "$arg"
done

printf -v json_cmd 'write_json %q' "$JSON_OUT"
printf -v verilog_cmd 'write_verilog -noattr %q' "$VERILOG_OUT"

link_cmd=""
if [[ "$SYNLIG_USE_DEFER" == "1" ]]; then
    link_cmd="read_systemverilog -link; "
fi

synlig_script="${read_cmd}; ${link_cmd}hierarchy -check -top ${TOP_MODULE}; check; synth -top ${TOP_MODULE} ${SYNLIG_SYNTH_ARGS}; stat -top ${TOP_MODULE}; ${json_cmd}; ${verilog_cmd}"

echo "[INFO] Running Synlig synthesis for top=${TOP_MODULE}"
echo "[INFO] Log: $LOG_FILE"
echo "[INFO] JSON: $JSON_OUT"
echo "[INFO] Verilog: $VERILOG_OUT"
echo "[INFO] Work dir: $RUN_DIR"
echo "[INFO] IROM mode: $([[ "$SYNLIG_USE_IROM_BLACKBOX" == "1" ]] && echo blackbox || echo rtl)"
echo "[INFO] DRAM mode: $([[ "$SYNLIG_USE_DRAM_BLACKBOX" == "1" ]] && echo blackbox || echo rtl)"

set +e
(
    cd "$RUN_DIR"
    "$SYNLIG_BIN" -D YOSYS -L "$LOG_FILE" -p "$synlig_script"
)
synlig_rc=$?
set -e

if [[ $synlig_rc -ne 0 ]]; then
    {
        echo
        echo "[ERROR] Synlig synthesis failed with exit code ${synlig_rc}."
        if [[ $synlig_rc -eq 139 ]]; then
            echo "[ERROR] Exit code 139 indicates a Synlig segmentation fault."
        fi
    } | tee -a "$LOG_FILE" >&2
    exit "$synlig_rc"
fi

echo "[INFO] Synlig synthesis completed successfully." | tee -a "$LOG_FILE"
