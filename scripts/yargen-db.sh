#!/bin/bash
# yarGen database management utility
# Usage: yargen-db.sh <command> [options]

set -e

YARGEN_DIR="${YARGEN_DIR:-$HOME/clawd/projects/yarGen-Go/repo}"
DBS_DIR="${YARGEN_DBS_DIR:-$YARGEN_DIR/dbs}"

show_usage() {
    echo "yarGen Database Manager"
    echo ""
    echo "Commands:"
    echo "  list                    List all databases with sizes"
    echo "  update                  Download pre-built databases from GitHub"
    echo "  create -g <dir> -i <id> Create new database from goodware directory"
    echo "  append -g <dir> -i <id> Append to existing database"
    echo "  merge -o <out> <db1> <db2> ...  Merge multiple databases"
    echo "  inspect <db>            Show database statistics"
    echo "  compare <db1> <db2>     Compare two databases"
    echo ""
    echo "Examples:"
    echo "  yargen-db.sh list"
    echo "  yargen-db.sh create -g /opt/goodware -i local"
    echo "  yargen-db.sh merge -o combined.db dbs/*.db"
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

if [ ! -d "$YARGEN_DIR" ]; then
    echo "[E] yarGen directory not found: $YARGEN_DIR"
    exit 1
fi

cd "$YARGEN_DIR"

if [ ! -f ./yargen-util ]; then
    echo "[E] yargen-util binary not found. Building..."
    go build -o yargen-util ./cmd/yargen-util
fi

COMMAND="$1"
shift

case "$COMMAND" in
    list)
        echo "=== yarGen Databases ==="
        ./yargen-util list
        ;;
    update)
        echo "[+] Downloading databases..."
        ./yargen-util update
        ;;
    create)
        echo "[+] Creating database..."
        ./yargen-util create "$@"
        ;;
    append)
        echo "[+] Appending to database..."
        ./yargen-util append "$@"
        ;;
    merge)
        echo "[+] Merging databases..."
        ./yargen-util merge "$@"
        ;;
    inspect)
        if [ $# -eq 0 ]; then
            echo "[E] Database file required"
            exit 1
        fi
        ./yargen-util inspect "$@"
        ;;
    compare)
        if [ $# -lt 2 ]; then
            echo "[E] Two database files required"
            exit 1
        fi
        echo "=== Database 1: $1 ==="
        ./yargen-util inspect "$1" -top 0 | head -5
        echo ""
        echo "=== Database 2: $2 ==="
        ./yargen-util inspect "$2" -top 0 | head -5
        ;;
    *)
        echo "[E] Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
