#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <vendor-module-dir> <known-good-Module.symvers> <candidate-Module.symvers>" >&2
}

if [[ $# -ne 3 ]]; then
    usage
    exit 2
fi

module_dir="$(realpath "$1")"
known_symvers="$(realpath "$2")"
candidate_symvers="$(realpath "$3")"

if [[ ! -d "${module_dir}" ]]; then
    echo "Vendor module directory not found: ${module_dir}" >&2
    exit 1
fi

for symvers in "${known_symvers}" "${candidate_symvers}"; do
    if [[ ! -f "${symvers}" ]]; then
        echo "Module.symvers not found: ${symvers}" >&2
        exit 1
    fi
done

if ! command -v modprobe >/dev/null 2>&1; then
    echo "modprobe is required to read __versions from the vendor modules." >&2
    exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

requirements="${work_dir}/requirements.tsv"
requirements_unsorted="${work_dir}/requirements-unsorted.tsv"
known_index="${work_dir}/known.tsv"
candidate_index="${work_dir}/candidate.tsv"
vendor_exports_unsorted="${work_dir}/vendor-exports-unsorted.tsv"
vendor_exports="${work_dir}/vendor-exports.tsv"
report="${work_dir}/report.tsv"

found_modules=0
: > "${requirements_unsorted}"
: > "${vendor_exports_unsorted}"
for module in "${module_dir}"/*.ko; do
    if [[ ! -f "${module}" ]]; then
        continue
    fi

    found_modules=$((found_modules + 1))
    module_name="$(basename "${module}")"
    modprobe --dump-modversions "${module}" |
        awk -v module="${module_name}" 'NF >= 2 {
            print module "\t" tolower($1) "\t" $2
        }' >> "${requirements_unsorted}"

    # A requirement that is absent from both kernel Module.symvers files can
    # legitimately be provided by another vendor module.  Record each module's
    # exported symbols so those dependencies are not reported as kernel ABI
    # regressions.
    nm --defined-only "${module}" 2>/dev/null |
        awk -v module="${module_name}" '$NF ~ /^__ksymtab_/ {
            symbol = $NF
            sub(/^__ksymtab_/, "", symbol)
            print symbol "\t" module
        }' >> "${vendor_exports_unsorted}" || true
done

if [[ ${found_modules} -eq 0 ]]; then
    echo "No .ko files found in ${module_dir}" >&2
    exit 1
fi

sort -u "${requirements_unsorted}" > "${requirements}"
sort -u "${vendor_exports_unsorted}" > "${vendor_exports}"

awk 'NF >= 2 { print $2 "\t" tolower($1) }' "${known_symvers}" |
    sort -u > "${known_index}"
awk 'NF >= 2 { print $2 "\t" tolower($1) }' "${candidate_symvers}" |
    sort -u > "${candidate_index}"

awk -v known_file="${known_index}" \
    -v candidate_file="${candidate_index}" \
    -v vendor_exports_file="${vendor_exports}" '
BEGIN {
    FS = OFS = "\t"

    while ((getline line < known_file) > 0) {
        split(line, fields, "\t")
        known[fields[1]] = fields[2]
    }
    close(known_file)

    while ((getline line < candidate_file) > 0) {
        split(line, fields, "\t")
        candidate[fields[1]] = fields[2]
    }
    close(candidate_file)

    while ((getline line < vendor_exports_file) > 0) {
        split(line, fields, "\t")
        if (fields[1] in vendor_provider)
            vendor_provider[fields[1]] = vendor_provider[fields[1]] "," fields[2]
        else
            vendor_provider[fields[1]] = fields[2]
    }
    close(vendor_exports_file)

    print "module", "symbol", "vendor_crc", "known_good_crc", \
        "candidate_crc", "classification", "vendor_provider", \
        "vendor_to_candidate"
}
{
    module = $1
    vendor_crc = $2
    symbol = $3
    known_crc = (symbol in known) ? known[symbol] : "MISSING"
    candidate_crc = (symbol in candidate) ? candidate[symbol] : "MISSING"

    provider = (symbol in vendor_provider) ? vendor_provider[symbol] : "-"

    if (known_crc == "MISSING" && candidate_crc == "MISSING") {
        if (provider != "-")
            classification = "module_dependency"
        else
            classification = "missing_both_unresolved"
    } else if (known_crc != "MISSING" && candidate_crc == "MISSING") {
        classification = "candidate_regression_missing"
    } else if (known_crc == "MISSING" && candidate_crc != "MISSING") {
        classification = "candidate_new_symbol"
    } else if (known_crc == candidate_crc) {
        classification = "stable_from_known"
    } else {
        classification = "crc_drift"
    }

    vendor_status = (candidate_crc == "MISSING") ? "missing" : \
        ((vendor_crc == candidate_crc) ? "same" : "different")

    print module, symbol, vendor_crc, known_crc, candidate_crc, \
        classification, provider, vendor_status
}
' "${requirements}" > "${report}"

cat "${report}"

awk -v modules="${found_modules}" '
BEGIN { FS = OFS = "\t" }
NR == 1 { next }
{
    rows[$6]++
    unique_symbol[$2] = 1
    key = $6 SUBSEP $2
    if (!(key in unique_class)) {
        unique_class[key] = 1
        unique[$6]++
    }
}
END {
    for (symbol in unique_symbol)
        unique_total++

    print "SUMMARY", "modules=" modules, "requirement_rows=" NR - 1, \
        "unique_symbols=" unique_total > "/dev/stderr"

    print "ROWS", \
        "stable_from_known=" rows["stable_from_known"] + 0, \
        "crc_drift=" rows["crc_drift"] + 0, \
        "candidate_regression_missing=" rows["candidate_regression_missing"] + 0, \
        "candidate_new_symbol=" rows["candidate_new_symbol"] + 0, \
        "module_dependency=" rows["module_dependency"] + 0, \
        "missing_both_unresolved=" rows["missing_both_unresolved"] + 0 \
        > "/dev/stderr"

    print "UNIQUE", \
        "stable_from_known=" unique["stable_from_known"] + 0, \
        "crc_drift=" unique["crc_drift"] + 0, \
        "candidate_regression_missing=" unique["candidate_regression_missing"] + 0, \
        "candidate_new_symbol=" unique["candidate_new_symbol"] + 0, \
        "module_dependency=" unique["module_dependency"] + 0, \
        "missing_both_unresolved=" unique["missing_both_unresolved"] + 0 \
        > "/dev/stderr"
}
' "${report}"
