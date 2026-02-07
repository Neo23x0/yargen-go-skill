---
name: yargen
description: Generate YARA rules from malware samples using yarGen-Go. Manage goodware databases, use CLI or API for rule generation, and integrate with yarGen web server. Use when generating YARA rules, managing goodware databases, creating custom string/opcode databases, or interacting with yarGen web API.
---

# yarGen Skill

Automatic YARA rule generator that extracts strings from malware samples while filtering out goodware strings.

## Quick Start

```bash
# 1. Ensure yarGen is available
export YARGEN_DIR="$HOME/clawd/projects/yarGen-Go/repo"

# 2. Download databases (first time)
$SKILL_DIR/scripts/yargen-db.sh update

# 3. Generate rules
$SKILL_DIR/scripts/yargen-generate.sh ./malware-samples -a "Your Name" --opcodes
```

## Prerequisites

yarGen-Go must be cloned and built:
```bash
git clone https://github.com/Neo23x0/yarGen-Go.git ~/clawd/projects/yarGen-Go
cd ~/clawd/projects/yarGen-Go
go build -o yargen ./cmd/yargen
go build -o yargen-util ./cmd/yargen-util
./yargen-util update
```

## Core Capabilities

### 1. Submit Sample (Easiest)

Submit a sample to a running yarGen server and get rules back:

```bash
# Start server (if not running)
cd $YARGEN_DIR && ./yargen serve &

# Submit sample - simplest usage
./yargen-util submit malware.exe

# With options (flags must come BEFORE the sample file)
./yargen-util submit -a "Florian Roth" -show-scores -v malware.exe

# Save to file
./yargen-util submit -o rules.yar -wait 300 malware.exe
```

**Important:** Flags must come **before** the sample file (Go flag parsing limitation).

Options:
| Flag | Description | Default |
|------|-------------|---------|
| `-a <author>` | Author name in rule meta | `yarGen` |
| `-r <reference>` | Reference string (URL, report) | none |
| `-show-scores` | Include string scores as comments | false |
| `-no-opcodes` | Skip opcode analysis (faster) | false |
| `-o <file>` | Save rules to file | stdout |
| `-wait <sec>` | Max wait time for large files | 600 (10min) |
| `-v` | Verbose progress output | false |
| `-server <url>` | yarGen server URL | `http://127.0.0.1:8080` |

### 2. Generate YARA Rules (CLI)

Use the generate script:
```bash
$SKILL_DIR/scripts/yargen-generate.sh <malware-dir> [options]

Options:
  -o <file>       Output file (default: yargen_rules.yar)
  -a <author>     Author name
  -r <reference>  Reference string
  --opcodes       Include opcode analysis
  --score         Show scores as comments
```

Or use yarGen directly:
```bash
cd $YARGEN_DIR
./yargen -m ./malware --opcodes -a "Author"
```

### 3. Database Management

Use the database script:
```bash
$SKILL_DIR/scripts/yargen-db.sh <command>

Commands:
  list              List all databases
  update            Download pre-built databases
  create            Create from goodware directory
  append            Append to existing database
  merge             Merge multiple databases
  inspect           Show database stats
```

See [database-guide.md](references/database-guide.md) for detailed best practices.

### 4. Web API Integration

Start the server:
```bash
cd $YARGEN_DIR
./yargen serve --port 8080
```

Use the API client script:
```bash
# Check server
$SKILL_DIR/scripts/yargen-api.sh health

# Upload and generate (one-shot)
$SKILL_DIR/scripts/yargen-api.sh full ./malware.exe -a "Author"

# Or step by step:
$SKILL_DIR/scripts/yargen-api.sh upload malware.exe
# → Copy job_id from output
$SKILL_DIR/scripts/yargen-api.sh generate <job-id> -a "Author"
$SKILL_DIR/scripts/yargen-api.sh rules <job-id>
```

See [api-reference.md](references/api-reference.md) for complete API documentation.

## Workflows

### First-Time Setup
1. Clone and build yarGen-Go
2. Run `yargen-db.sh update` to download databases
3. Optionally create custom database: `yargen-db.sh create -g /opt/goodware -i local`

### Daily Usage - CLI
1. Place samples in a directory
2. Run `yargen-generate.sh ./samples --opcodes`
3. Review and post-process generated rules

### Daily Usage - API
1. Ensure server is running: `./yargen serve`
2. Use `yargen-api.sh full <file>` for one-shot processing
3. Or integrate API calls into automation

### Database Maintenance
1. `yargen-db.sh list` - Check database sizes
2. `yargen-db.sh inspect <db>` - Review contents
3. `yargen-db.sh update` - Get latest pre-built DBs
4. `yargen-db.sh append -g <dir> -i local` - Add to custom DB

## Database Strategy

### Keep Separate (Default)
- Multiple `good-strings-part*.db` files
- Your `good-strings-local.db`
- yarGen merges them at runtime

### Merge for Performance
```bash
yargen-util merge -o combined.db dbs/good-strings-*.db
```

See [database-guide.md](references/database-guide.md) for trade-offs.

## Configuration

Create `config/config.yaml` for LLM integration:
```yaml
llm:
  provider: "openai"
  model: "gpt-4o-mini"
  api_key: "${OPENAI_API_KEY}"

database:
  dbs_dir: "./dbs"
```

## Tips

- Use `--opcodes` for executable files (adds opcode analysis)
- Use `--score` to see string scoring in rule comments
- Custom databases help reduce false positives for your environment
- The web API is useful for automation and integrations
