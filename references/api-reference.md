# yarGen API Reference

## Overview

yarGen provides both a CLI tool and a web API for generating YARA rules from malware samples.

## Server Endpoints

### Health Check
```
GET /api/health
```
Returns server status and configuration.

### File Upload
```
POST /api/upload
Content-Type: multipart/form-data

Parameters:
  - file: Binary file(s) to upload

Response:
  {
    "id": "<job-id>",
    "status": "uploaded",
    "files": [...],
    "created_at": "..."
  }
```

### Generate Rules
```
POST /api/generate
Content-Type: application/json

Request Body:
  {
    "job_id": "<job-id>",
    "author": "Author Name",
    "reference": "Reference string",
    "show_scores": false,
    "exclude_opcodes": false
  }

Response:
  {
    "id": "<job-id>",
    "status": "generating" | "completed" | "failed",
    ...
  }
```

### Job Status
```
GET /api/jobs/<job-id>
```
Returns current job status and metadata.

### Get Rules
```
GET /api/rules/<job-id>
```
Returns generated YARA rules as text.

## CLI Commands

### yargen (Rule Generator)
```bash
# Basic usage
yargen -m ./malware-samples

# With options
yargen -m ./samples \
  -o rules.yar \
  -a "Author Name" \
  -r "Reference" \
  --opcodes \
  --score
```

### yargen-util (Database Manager)
```bash
# Download pre-built databases
yargen-util update

# Create custom database
yargen-util create -g /path/to/goodware -i mydb

# List databases
yargen-util list

# Inspect database
yargen-util inspect ./dbs/good-strings-mydb.db -top 10

# Merge databases
yargen-util merge -o combined.db db1.db db2.db
```

## Database Structure

yarGen uses gzipped JSON databases:

- `good-strings-<id>.db` - String whitelist (Counter: string -> count)
- `good-opcodes-<id>.db` - Opcode whitelist (Counter: opcode -> count)

All databases are merged at runtime using `Counter.Update()` which sums counts.

## Configuration

Config file location: `config/config.yaml`

```yaml
llm:
  provider: "openai"  # openai, anthropic, gemini, ollama
  model: "gpt-4o-mini"
  api_key: "${OPENAI_API_KEY}"
  endpoint: ""  # For Ollama: http://localhost:11434

database:
  dbs_dir: "./dbs"
  scoring_db: "~/.yargen/scoring.db"

server:
  host: "127.0.0.1"
  port: 8080
```

## Workflow Examples

### CLI Workflow
```bash
# 1. Download databases
yargen-util update

# 2. Create custom database (optional)
yargen-util create -g /opt/goodware -i local

# 3. Generate rules
yargen -m ./malware -o output.yar --opcodes
```

### API Workflow
```bash
# 1. Start server
yargen serve

# 2. Upload files
curl -F "file=@malware.exe" http://localhost:8080/api/upload
# → Get job_id from response

# 3. Generate rules
curl -X POST http://localhost:8080/api/generate \
  -H "Content-Type: application/json" \
  -d '{"job_id":"...","author":"Name"}'

# 4. Poll for completion
curl http://localhost:8080/api/jobs/<job-id>

# 5. Get rules
curl http://localhost:8080/api/rules/<job-id>
```

## Database Recommendations

| Approach | Use Case |
|----------|----------|
| Keep separate | Multiple sources, granular updates |
| Merge | Single deployment, faster load |

All databases are merged in-memory at runtime regardless of file organization.
