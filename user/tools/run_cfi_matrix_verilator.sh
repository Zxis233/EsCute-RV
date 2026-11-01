#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

WAVE_FORMAT="${WAVE_FORMAT:-fst}"
PRINT_INFO="${PRINT_INFO:-0}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/prj/verilator/cfi_matrix}"
WAVE_DIR="${WAVE_DIR:-${OUT_DIR}/waves}"
LOG_DIR="${LOG_DIR:-${OUT_DIR}/logs}"
BUILD_HEX=1
DRY_RUN=0
FAIL_ON_LOG_EROR="${FAIL_ON_LOG_EROR:-0}"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--skip-build] [--dry-run]

Build and run the 12 CFI C-test variants with Verilator waveform dumping.

Environment:
  OUT_DIR=<dir>             Output root. Default: prj/verilator/cfi_matrix
  WAVE_FORMAT=fst|vcd       Waveform format. Default: fst
  PRINT_INFO=0|1            Forwarded to the testbench. Default: 0
  FAIL_ON_LOG_EROR=0|1      Treat testbench [EROR] lines as script failures.
                            Default: 0, because these bare-metal loops can
                            finish by testbench timeout while still producing
                            useful waves.

Outputs:
  \$OUT_DIR/waves/<case>.<fst|vcd>
  \$OUT_DIR/logs/<case>.log
  \$OUT_DIR/summary.txt
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build)
            BUILD_HEX=0
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "${WAVE_FORMAT}" in
    fst|vcd)
        WAVE_EXT="${WAVE_FORMAT}"
        ;;
    *)
        echo "Unsupported WAVE_FORMAT='${WAVE_FORMAT}', expected fst or vcd" >&2
        exit 2
        ;;
esac

CASES=(
    jop_zicfilp_cfi_off_rt_off
    jop_zicfilp_cfi_off_rt_on
    jop_zicfilp_cfi_on_rt_off
    jop_zicfilp_cfi_on_rt_on
    cop_zicfilp_cfi_off_rt_off
    cop_zicfilp_cfi_off_rt_on
    cop_zicfilp_cfi_on_rt_off
    cop_zicfilp_cfi_on_rt_on
    rop_zicfiss_cfi_off_rt_off
    rop_zicfiss_cfi_off_rt_on
    rop_zicfiss_cfi_on_rt_off
    rop_zicfiss_cfi_on_rt_on
)

run_cmd() {
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    if [[ "${DRY_RUN}" -eq 0 ]]; then
        "$@"
    fi
}

if [[ "${BUILD_HEX}" -eq 1 ]]; then
    run_cmd make -C "${REPO_ROOT}/user/data/c/jop_example" matrix
    run_cmd make -C "${REPO_ROOT}/user/data/c/cop_example" matrix
    run_cmd make -C "${REPO_ROOT}/user/data/c/rop_example" matrix
fi

run_cmd mkdir -p "${WAVE_DIR}" "${LOG_DIR}"
run_cmd make -C "${REPO_ROOT}" SIM=verilator WAVE_FORMAT="${WAVE_FORMAT}" compile

SUMMARY="${OUT_DIR}/summary.txt"
if [[ "${DRY_RUN}" -eq 0 ]]; then
    printf 'case,wave,log,exit_code,result\n' > "${SUMMARY}"
else
    printf '+ write summary: %q\n' "${SUMMARY}"
fi

FAILED=0

for case_name in "${CASES[@]}"; do
    hex_file="${REPO_ROOT}/user/data/hex/${case_name}.hex"
    wave_file="${WAVE_DIR}/${case_name}.${WAVE_EXT}"
    log_file="${LOG_DIR}/${case_name}.log"

    if [[ "${DRY_RUN}" -eq 0 && ! -f "${hex_file}" ]]; then
        echo "Missing hex file: ${hex_file}" >&2
        FAILED=1
        continue
    fi

    cmd=(
        make -C "${REPO_ROOT}"
        SIM=verilator
        run
        TESTCASE="${hex_file}"
        DUMPWAVE=1
        WAVE_FORMAT="${WAVE_FORMAT}"
        WAV_FILE="${wave_file}"
        PRINT_INFO="${PRINT_INFO}"
    )

    printf '+'
    printf ' %q' "${cmd[@]}"
    printf ' > %q 2>&1\n' "${log_file}"

    if [[ "${DRY_RUN}" -eq 1 ]]; then
        continue
    fi

    if "${cmd[@]}" > "${log_file}" 2>&1; then
        exit_code=0
    else
        exit_code=$?
        FAILED=1
    fi

    result="$(grep -E '\[(PASS|FAIL|EROR)\]' "${log_file}" | tail -n 1 || true)"
    if [[ -z "${result}" ]]; then
        result="no PASS/FAIL/EROR marker"
    fi

    if [[ ! -s "${wave_file}" ]]; then
        result="${result}; missing waveform"
        FAILED=1
    fi

    if [[ "${FAIL_ON_LOG_EROR}" -eq 1 && "${result}" == *"[EROR]"* ]]; then
        FAILED=1
    fi

    printf '%s,%s,%s,%d,%s\n' \
        "${case_name}" "${wave_file}" "${log_file}" "${exit_code}" "${result}" >> "${SUMMARY}"
    printf '[%s] %s\n' "${case_name}" "${result}"
done

if [[ "${DRY_RUN}" -eq 0 ]]; then
    echo "Summary: ${SUMMARY}"
    echo "Waves:   ${WAVE_DIR}"
    echo "Logs:    ${LOG_DIR}"
fi

exit "${FAILED}"
