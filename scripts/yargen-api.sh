#!/bin/bash
# yarGen API client for web server integration
# Usage: yargen-api.sh <command> [options]

set -e

YARGEN_HOST="${YARGEN_HOST:-http://127.0.0.1:8080}"

check_server() {
    if ! curl -s "$YARGEN_HOST/api/health" > /dev/null 2>&1; then
        echo "[E] yarGen server not running at $YARGEN_HOST"
        echo "    Start with: yargen serve"
        exit 1
    fi
}

show_usage() {
    echo "yarGen API Client"
    echo ""
    echo "Environment Variables:"
    echo "  YARGEN_HOST    Server URL (default: http://127.0.0.1:8080)"
    echo ""
    echo "Commands:"
    echo "  health                  Check server health"
    echo "  upload <file>           Upload file for processing"
    echo "  generate <job-id> [options]  Generate rules from uploaded files"
    echo "  status <job-id>         Check job status"
    echo "  rules <job-id>          Get generated rules"
    echo "  full <file>             Upload + generate + get rules (one-shot)"
    echo ""
    echo "Examples:"
    echo "  yargen-api.sh health"
    echo "  yargen-api.sh upload malware.exe"
    echo "  yargen-api.sh generate <job-id> -a 'Author Name'"
    echo "  yargen-api.sh full ./samples/malware.exe"
}

if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    health)
        curl -s "$YARGEN_HOST/api/health" | jq . 2>/dev/null || curl -s "$YARGEN_HOST/api/health"
        ;;
    upload)
        if [ $# -eq 0 ]; then
            echo "[E] File path required"
            exit 1
        fi
        FILE="$1"
        if [ ! -f "$FILE" ]; then
            echo "[E] File not found: $FILE"
            exit 1
        fi
        echo "[+] Uploading: $FILE"
        curl -s -X POST -F "file=@$FILE" "$YARGEN_HOST/api/upload" | jq . 2>/dev/null || curl -s -X POST -F "file=@$FILE" "$YARGEN_HOST/api/upload"
        ;;
    generate)
        if [ $# -eq 0 ]; then
            echo "[E] Job ID required"
            exit 1
        fi
        JOB_ID="$1"
        shift
        
        # Build JSON payload
        JSON="{\"job_id\":\"$JOB_ID\""
        while [ $# -gt 0 ]; do
            case "$1" in
                -a|--author) JSON="$JSON,\"author\":\"$2\""; shift 2 ;;
                -r|--reference) JSON="$JSON,\"reference\":\"$2\""; shift 2 ;;
                --show-scores) JSON="$JSON,\"show_scores\":true"; shift ;;
                --exclude-opcodes) JSON="$JSON,\"exclude_opcodes\":true"; shift ;;
                *) shift ;;
            esac
        done
        JSON="$JSON}"
        
        echo "[+] Starting generation for job: $JOB_ID"
        curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$YARGEN_HOST/api/generate" | jq . 2>/dev/null || curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$YARGEN_HOST/api/generate"
        ;;
    status)
        if [ $# -eq 0 ]; then
            echo "[E] Job ID required"
            exit 1
        fi
        curl -s "$YARGEN_HOST/api/jobs/$1" | jq . 2>/dev/null || curl -s "$YARGEN_HOST/api/jobs/$1"
        ;;
    rules)
        if [ $# -eq 0 ]; then
            echo "[E] Job ID required"
            exit 1
        fi
        curl -s "$YARGEN_HOST/api/rules/$1"
        ;;
    full)
        if [ $# -eq 0 ]; then
            echo "[E] File path required"
            exit 1
        fi
        FILE="$1"
        shift
        
        check_server
        
        # Upload
        echo "[+] Uploading file..."
        UPLOAD_RESPONSE=$(curl -s -X POST -F "file=@$FILE" "$YARGEN_HOST/api/upload")
        JOB_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        
        if [ -z "$JOB_ID" ]; then
            echo "[E] Failed to get job ID from upload response"
            echo "$UPLOAD_RESPONSE"
            exit 1
        fi
        
        echo "[+] Job ID: $JOB_ID"
        
        # Generate
        echo "[+] Starting rule generation..."
        JSON="{\"job_id\":\"$JOB_ID\""
        while [ $# -gt 0 ]; do
            case "$1" in
                -a|--author) JSON="$JSON,\"author\":\"$2\""; shift 2 ;;
                -r|--reference) JSON="$JSON,\"reference\":\"$2\""; shift 2 ;;
                *) shift ;;
            esac
        done
        JSON="$JSON}"
        
        curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$YARGEN_HOST/api/generate" > /dev/null
        
        # Wait and poll for completion
        echo "[+] Waiting for generation to complete..."
        for i in {1..60}; do
            STATUS=$(curl -s "$YARGEN_HOST/api/jobs/$JOB_ID" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            echo "    Status: $STATUS"
            if [ "$STATUS" = "completed" ]; then
                break
            elif [ "$STATUS" = "failed" ]; then
                echo "[E] Generation failed"
                exit 1
            fi
            sleep 2
        done
        
        # Get rules
        echo "[+] Retrieving rules..."
        curl -s "$YARGEN_HOST/api/rules/$JOB_ID"
        ;;
    *)
        echo "[E] Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac
