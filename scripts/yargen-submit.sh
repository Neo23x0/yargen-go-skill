#!/bin/bash
# yarGen submit - Submit sample to server and get rules back
# Usage: yargen-submit.sh <sample-file> [options]

set -e

YARGEN_HOST="${YARGEN_HOST:-http://127.0.0.1:8080}"
MAX_WAIT="${MAX_WAIT:-600}"  # 10 minutes max wait
POLL_INTERVAL=3

show_usage() {
    echo "yarGen Submit - Command-line sample submission"
    echo ""
    echo "Usage: yargen-submit.sh <sample-file> [options]"
    echo ""
    echo "Options:"
    echo "  -a, --author <name>       Author name (default: yarGen)"
    echo "  -r, --reference <ref>     Reference string"
    echo "  --show-scores             Include scores in rule comments"
    echo "  --no-opcodes              Disable opcode analysis"
    echo "  -o, --output <file>       Save rules to file (default: stdout)"
    echo "  --wait <seconds>          Max wait time (default: 600 = 10min)"
    echo "  -v, --verbose             Show progress messages"
    echo ""
    echo "Environment:"
    echo "  YARGEN_HOST    Server URL (default: http://127.0.0.1:8080)"
    echo ""
    echo "Examples:"
    echo "  yargen-submit.sh malware.exe"
    echo "  yargen-submit.sh malware.exe -a 'Florian Roth' --show-scores"
    echo "  yargen-submit.sh malware.exe -o rules.yar --wait 300"
}

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "[E] curl is required but not installed"
    exit 1
fi

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

SAMPLE_FILE=""
AUTHOR="yarGen"
REFERENCE=""
SHOW_SCORES="false"
EXCLUDE_OPCODES="false"
OUTPUT_FILE=""
VERBOSE="false"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -a|--author)
            AUTHOR="$2"
            shift 2
            ;;
        -r|--reference)
            REFERENCE="$2"
            shift 2
            ;;
        --show-scores)
            SHOW_SCORES="true"
            shift
            ;;
        --no-opcodes)
            EXCLUDE_OPCODES="true"
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --wait)
            MAX_WAIT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -*)
            echo "[E] Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$SAMPLE_FILE" ]; then
                SAMPLE_FILE="$1"
            else
                echo "[E] Only one sample file allowed"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$SAMPLE_FILE" ]; then
    echo "[E] Sample file required"
    show_usage
    exit 1
fi

if [ ! -f "$SAMPLE_FILE" ]; then
    echo "[E] File not found: $SAMPLE_FILE"
    exit 1
fi

# Check server
if [ "$VERBOSE" = "true" ]; then
    echo "[*] Checking server at $YARGEN_HOST ..."
fi

if ! curl -s "$YARGEN_HOST/api/health" > /dev/null 2>&1; then
    echo "[E] yarGen server not running at $YARGEN_HOST"
    echo "    Start with: cd ~/clawd/projects/yarGen-Go/repo && ./yargen serve"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$SAMPLE_FILE" 2>/dev/null || stat -c%s "$SAMPLE_FILE" 2>/dev/null || echo "unknown")
FILE_NAME=$(basename "$SAMPLE_FILE")

if [ "$VERBOSE" = "true" ]; then
    echo "[+] Submitting: $FILE_NAME ($FILE_SIZE bytes)"
    echo "[+] Author: $AUTHOR"
fi

# Upload file
if [ "$VERBOSE" = "true" ]; then
    echo "[*] Uploading file..."
fi

UPLOAD_RESPONSE=$(curl -s -X POST -F "file=@$SAMPLE_FILE" "$YARGEN_HOST/api/upload")

# Extract job ID
JOB_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$JOB_ID" ]; then
    echo "[E] Failed to get job ID from server"
    echo "    Response: $UPLOAD_RESPONSE"
    exit 1
fi

if [ "$VERBOSE" = "true" ]; then
    echo "[+] Job ID: $JOB_ID"
    echo "[*] Starting rule generation..."
fi

# Build generation request
JSON="{\"job_id\":\"$JOB_ID\",\"author\":\"$AUTHOR\""
if [ -n "$REFERENCE" ]; then
    JSON="$JSON,\"reference\":\"$REFERENCE\""
fi
if [ "$SHOW_SCORES" = "true" ]; then
    JSON="$JSON,\"show_scores\":true"
fi
if [ "$EXCLUDE_OPCODES" = "true" ]; then
    JSON="$JSON,\"exclude_opcodes\":true"
fi
JSON="$JSON}"

# Start generation
curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$YARGEN_HOST/api/generate" > /dev/null

# Poll for completion
if [ "$VERBOSE" = "true" ]; then
    echo "[*] Waiting for generation (max ${MAX_WAIT}s)..."
fi

ELAPSED=0
LAST_STATUS=""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    STATUS_RESPONSE=$(curl -s "$YARGEN_HOST/api/jobs/$JOB_ID")
    STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$STATUS" != "$LAST_STATUS" ]; then
        LAST_STATUS="$STATUS"
        if [ "$VERBOSE" = "true" ]; then
            echo "    Status: $STATUS"
        fi
    fi
    
    if [ "$STATUS" = "completed" ]; then
        break
    elif [ "$STATUS" = "failed" ]; then
        echo "[E] Rule generation failed"
        ERROR=$(echo "$STATUS_RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$ERROR" ]; then
            echo "    Error: $ERROR"
        fi
        exit 1
    fi
    
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ "$STATUS" != "completed" ]; then
    echo "[E] Timeout waiting for generation (waited ${ELAPSED}s)"
    echo "    Job ID: $JOB_ID"
    echo "    Check status: curl $YARGEN_HOST/api/jobs/$JOB_ID"
    exit 1
fi

# Get rules
if [ "$VERBOSE" = "true" ]; then
    echo "[+] Retrieving generated rules..."
fi

RULES=$(curl -s "$YARGEN_HOST/api/rules/$JOB_ID")

# Output
if [ -n "$OUTPUT_FILE" ]; then
    echo "$RULES" > "$OUTPUT_FILE"
    echo "[+] Rules saved to: $OUTPUT_FILE"
else
    echo "$RULES"
fi

if [ "$VERBOSE" = "true" ]; then
    RULE_COUNT=$(echo "$RULES" | grep -c "^rule " || echo "0")
    echo "[+] Generated $RULE_COUNT rule(s)"
fi
