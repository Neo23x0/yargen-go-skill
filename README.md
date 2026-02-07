# yarGen Skill

An **LLM Agent Skill** for automated YARA rule generation using [yarGen-Go](https://github.com/Neo23x0/yarGen-Go). Embeds expertise from the creator of the original yarGen tool into your AI assistant's context for generating high-quality, low-false-positive YARA rules from malware samples.

## 🎯 What This Skill Does

The **yargen-skill** transforms your LLM agent into a YARA rule generation expert, capable of:

- **Generating** YARA rules from single samples or batch directories
- **Filtering** out goodware strings to reduce false positives
- **Managing** goodware databases (download, create, merge, inspect)
- **Submitting** samples to yarGen server for one-shot rule generation
- **Integrating** via CLI or REST API for automation workflows

All through natural language conversation — just ask for rules from your samples.

## 📦 Installation

### Option 1: Clone and Copy (Recommended)

```bash
# Clone the repository
git clone https://github.com/YOURORG/yargen-skill.git

# Copy to your agent's skills folder
cp -r yargen-skill ~/.openclaw/skills/
```

### Option 2: Package as .skill File

```bash
# Clone the repository
git clone https://github.com/YOURORG/yargen-skill.git
cd yargen-skill

# Package the skill (requires OpenClaw skill-creator)
python3 ~/.npm-global/lib/node_modules/openclaw/skills/skill-creator/scripts/package_skill.py . .

# Install the packaged skill
cp yargen.skill ~/.openclaw/skills/
```

### Supported Platforms

This skill works with any LLM agent that supports skill files:

- **OpenClaw** — `~/.openclaw/skills/`
- **Claude Desktop** — (skills folder location varies)
- **Other MCP-based agents** — Check your platform's documentation

## 🚀 Prerequisites

Before using this skill, yarGen-Go must be installed:

```bash
# Clone and build yarGen-Go
git clone https://github.com/Neo23x0/yarGen-Go.git ~/clawd/projects/yarGen-Go
cd ~/clawd/projects/yarGen-Go
go build -o yargen ./cmd/yargen
go build -o yargen-util ./cmd/yargen-util

# Download goodware databases
./yargen-util update
```

## 🚀 Usage

Once installed, the skill activates automatically when you discuss YARA rule generation. Just ask:

### Use Case 1: Submit Single Sample
> "Generate a YARA rule for this malware sample"

The skill will:
- Start the yarGen server if not running
- Submit the sample via `yargen-util submit`
- Return the generated rule with metadata

```bash
# Simple usage
yargen-util submit malware.exe

# With custom author and verbose output
yargen-util submit -a "Florian Roth" -show-scores -v malware.exe

# Save to file with timeout
yargen-util submit -o rules.yar -wait 300 malware.exe
```

### Use Case 2: Batch Generate from Directory
> "Generate rules for all samples in this directory"

The skill handles:
- Scanning all files recursively
- Extracting strings and opcodes
- Filtering against goodware databases
- Writing consolidated rule file

```bash
# Generate from directory
yargen-generate.sh ./malware-samples -a "Your Name" --opcodes

# Direct yarGen usage
./yargen -m ./malware --opcodes -a "Author Name" -o output.yar
```

### Use Case 3: Database Management
> "Update my goodware databases" or "Create a custom database from my files"

The skill manages:
- Downloading pre-built databases from GitHub
- Creating custom databases from your goodware collection
- Merging databases for faster loading
- Inspecting database contents and statistics

```bash
# Update pre-built databases
yargen-db.sh update

# Create custom database from your goodware
yargen-db.sh create -g /opt/goodware -i local

# List all databases
yargen-db.sh list

# Merge databases for performance
yargen-db.sh merge -o combined.db dbs/good-strings-*.db
```

### Use Case 4: API Integration
> "Set up yarGen API for my automation pipeline"

The skill provides:
- REST API client scripts
- One-shot submission workflows
- Job status polling
- Rule retrieval

```bash
# Start server
./yargen serve --port 8080

# Check health
yargen-api.sh health

# One-shot: upload, generate, get rules
yargen-api.sh full ./malware.exe -a "Author"

# Or step by step
yargen-api.sh upload malware.exe      # → returns job_id
yargen-api.sh generate <job_id> -a "Author"
yargen-api.sh rules <job_id>
```

## 📚 What's Included

### Core Capabilities

The skill provides four main workflows:

1. **Submit** — Easiest way to get rules from single samples
2. **Generate** — Batch processing from directories
3. **Database** — Goodware database management
4. **API** — REST API integration for automation

### Database Strategy

The skill teaches the trade-offs between:

| Approach | Pros | Cons |
|----------|------|------|
| **Separate DBs** (default) | Easy to update individual parts | Slightly slower startup |
| **Merged DB** | Faster loading | Must rebuild to update |

### Goodware Databases

Pre-built databases from the yarGen-Go repository:
- `good-strings-part1-11.db` — String databases (~15M entries)
- `good-opcodes-part1-11.db` — Opcode databases (~24M entries)

Plus your custom databases:
- `good-strings-local.db` — Your goodware strings
- `good-opcodes-local.db` — Your goodware opcodes

### Submit Command Options

| Flag | Description | Default |
|------|-------------|---------|
| `-a <author>` | Author name in rule meta | `yarGen` |
| `-r <reference>` | Reference string (URL, report) | none |
| `-show-scores` | Include string scores as comments | false |
| `-no-opcodes` | Skip opcode analysis (faster) | false |
| `-o <file>` | Save rules to file | stdout |
| `-wait <sec>` | Max wait time for large files | 600 (10min) |
| `-v` | Verbose progress output | false |

**Important:** Flags must come **before** the sample file (Go flag parsing limitation).

## 🏗️ Repository Structure

```
yargen/
├── SKILL.md                      # Main skill documentation
├── README.md                     # This file
├── scripts/
│   ├── yargen-generate.sh        # CLI rule generation wrapper
│   ├── yargen-db.sh              # Database management script
│   ├── yargen-api.sh             # REST API client
│   ├── yargen-submit.sh          # Bash submit wrapper (legacy)
│   └── yargen-util-submit.patch.go # Reference: native Go implementation
└── references/
    ├── api-reference.md          # Complete REST API documentation
    └── database-guide.md         # Database best practices
```

## 🧪 Example Workflows

### First-Time Setup
1. Build yarGen-Go binaries
2. Run `yargen-db.sh update` to download databases
3. Optionally create custom database: `yargen-db.sh create -g /opt/goodware -i local`

### Daily Usage - Submit
```bash
# Quick rule from single sample
yargen-util submit -a "Security Team" ./suspected_malware.exe

# With all options
yargen-util submit -a "Florian Roth" -r "https://analysis/123" \
  -show-scores -o rules.yar -v ./malware.exe
```

### Daily Usage - Batch
```bash
# Process entire directory
yargen-generate.sh ./daily-samples -a "SOC Team" --opcodes

# Review and post-process
cat yargen_rules.yar | less
```

### Database Maintenance
```bash
# Check database status
yargen-db.sh list

# Update monthly
yargen-db.sh update

# Add new goodware to custom DB
yargen-db.sh append -g /new/goodware -i local
```

## 🤝 Contributing

Contributions welcome! Areas to help:

- Additional workflow examples
- New API integrations
- Database optimization guides
- Documentation improvements

## 📄 License

This skill is designed for use with yarGen-Go by Florian Roth. See the yarGen-Go repository for licensing details:

- [yarGen-Go](https://github.com/Neo23x0/yarGen-Go)

## 🙏 Acknowledgments

- **Florian Roth** (@cyb3rops) — Creator of the original yarGen and yarGen-Go
- **YARA HQ** — Community organization for YARA excellence
- **Victor M. Alvarez** — Creator of YARA
