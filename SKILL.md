---
name: yargen
description: Generate YARA rules from malware samples using yarGen-Go. Manage goodware databases, use CLI or API for rule generation, and integrate with yarGen web server. Use when generating YARA rules, managing goodware databases, creating custom string/opcode databases, or interacting with yarGen web API.
---

# yarGen Skill

Automatic YARA rule generator that extracts strings from malware samples while filtering out goodware strings.

## ⚠️ Important: Initialization Time

**yarGen database initialization takes 2-10 minutes** depending on hardware:
- High-end systems: ~30-60 seconds
- Average systems: 2-5 minutes  
- Lower-end systems: 5-10 minutes

During this time, you'll see messages like:
`[+] Loaded dbs/good-strings-part1.db (1416757 entries)`

**Do not interrupt this process** - the databases are being loaded into memory.

### Single Sample vs. Batch Processing

| Scenario | Method | Recommendation |
|----------|--------|----------------|
| **Single sample** | CLI with `-f` flag | Use `-f` for quick one-offs |
| **Multiple samples** | Start server once | More efficient - databases loaded once |

> 💡 **Recommendation:** If analyzing more than one sample, start the yarGen server (`./yargen serve`) and keep it running. The database initialization happens only once, making subsequent samples much faster to process.

## Quick Start

```bash
# 1. Ensure yarGen is available
export YARGEN_DIR="$HOME/clawd/projects/yarGen-Go/repo"

# 2. Download databases (first time)
$SKILL_DIR/scripts/yargen-db.sh update

# 3. Generate rules from a single file
$SKILL_DIR/scripts/yargen-generate.sh -f ./malware.exe -a "Your Name" --opcodes

# 4. Or generate from a directory
$SKILL_DIR/scripts/yargen-generate.sh -m ./malware-samples -a "Your Name" --opcodes
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

### 1. Single File Analysis (Quick)

Analyze a single sample without starting the server:

```bash
# Using the wrapper script
./yargen-generate.sh -f malware.exe -a "Author Name"

# Or directly with yarGen
./yargen -f malware.exe -a "Author Name" -o rule.yar

# With opcodes (recommended for PE files)
./yargen -f malware.exe -a "Author Name" --opcodes
```

> 💡 **Note:** When using `-f`, yarGen creates a temporary directory internally and cleans it up after processing. This is equivalent to:
> ```bash
> mkdir -p /tmp/yarGen-work && cp sample.exe /tmp/yarGen-work/
> ./yargen -m /tmp/yarGen-work -a "Author" -o rule.yar
> ```

### 2. Submit Sample to Running Server (Batch)

For multiple samples, start the server once and submit samples via API:

```bash
# Start server (if not running) - takes 2-10 min to initialize
cd $YARGEN_DIR && ./yargen serve &

# Wait for: "[+] Starting web server at http://127.0.0.1:8080"

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

### 3. Generate YARA Rules from Directory (CLI)

Use the generate script for batch processing:
```bash
$SKILL_DIR/scripts/yargen-generate.sh -m <malware-dir> [options]

Options:
  -m <dir>        Malware directory (required for batch mode)
  -f <file>       Single file mode (alternative to -m)
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

### 4. Database Management

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

### 5. Web API Integration

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

### Single Sample Analysis (Quick)
1. Run `./yargen -f ./malware.exe --opcodes -a "Author"`
2. Review and post-process generated rule

> 💡 **Note:** This will show a recommendation message suggesting the server mode for multiple samples.

### Batch Processing (Efficient)
1. Start server: `./yargen serve` (wait 2-10 min for initialization)
2. Submit samples: `yargen-util submit -a "Author" sample1.exe`
3. Continue submitting more samples - no re-initialization needed
4. Stop server when done: `pkill -f "yargen serve"`

**Why this is better:** The databases are loaded once and stay in memory. Each subsequent sample processes in seconds instead of minutes.

### Resource Management

The yarGen server keeps all goodware databases in memory (~1-2GB RAM depending on configuration).

**After all work is complete**, stop the service to free memory:
```bash
pkill -f "yargen serve"
```

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
- For single files, use `-f` flag instead of creating temp directories manually
- Start the server once and keep it running when analyzing multiple samples
- Remember to kill the server after all work is done to free up RAM
