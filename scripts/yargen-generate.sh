#!/bin/bash
# yarGen rule generator wrapper
# Usage: yargen-generate.sh <malware-dir> [options]

set -e

YARGEN_DIR="${YARGEN_DIR:-$HOME/clawd/projects/yarGen-Go/repo}"
MALWARE_DIR="$1"
shift || true

if [ -z "$MALWARE_DIR" ]; then
    echo "Usage: yargen-generate.sh <malware-dir> [options]"
    echo ""
    echo "Options:"
    echo "  -o <file>       Output file (default: yargen_rules.yar)"
    echo "  -a <author>     Author name (default: yarGen)"
    echo "  -r <reference>  Reference string"
    echo "  --opcodes       Include opcode analysis"
    echo "  --score         Show scores as comments"
    echo "  --nosuper       Disable super rules"
    echo ""
    echo "Examples:"
    echo "  yargen-generate.sh ./malware-samples"
    echo "  yargen-generate.sh ./samples -a 'Florian Roth' --opcodes"
    exit 1
fi

if [ ! -d "$YARGEN_DIR" ]; then
    echo "[E] yarGen directory not found: $YARGEN_DIR"
    echo "    Set YARGEN_DIR environment variable or clone yarGen-Go"
    exit 1
fi

cd "$YARGEN_DIR"

if [ ! -f ./yargen ]; then
    echo "[E] yarGen binary not found. Building..."
    go build -o yargen ./cmd/yargen
fi

echo "[+] Generating YARA rules from: $MALWARE_DIR"
./yargen -m "$MALWARE_DIR" "$@"
