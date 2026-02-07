# yarGen Database Best Practices

## Database Strategy

### Option 1: Keep Separate (Recommended)
Maintain separate databases for different goodware sources:
- `good-strings-part1.db` through `part11.db` - Downloaded databases
- `good-strings-local.db` - Your custom goodware collection

**Pros:**
- Granular updates (update only changed sources)
- Easier debugging (know which source contains a string)
- Smaller individual files for version control

**Cons:**
- Slightly slower startup (more file reads)
- More files to manage

### Option 2: Merge All
Combine all databases into a single file:
```bash
yargen-util merge -o good-strings-all.db dbs/good-strings-*.db
```

**Pros:**
- Single file to deploy
- Faster startup (one file read)
- Simpler distribution

**Cons:**
- Lose source attribution
- Must regenerate entire database for updates
- Larger file for version control

## Performance Considerations

### Memory Usage
All databases are loaded into memory as hash maps:
- ~8.6M strings ≈ 200-300 MB RAM
- ~200K opcodes ≈ 50-100 MB RAM

### Loading Time
With 24 database files:
- SSD: ~2-5 seconds
- HDD: ~10-30 seconds

Merged single file:
- ~30% faster load time

## Creating Custom Databases

### From Goodware Collection
```bash
# Create new database
yargen-util create -g /opt/goodware -i local -opcodes

# This creates:
# - dbs/good-strings-local.db
# - dbs/good-opcodes-local.db
```

### Incremental Updates
```bash
# Add more samples to existing database
yargen-util append -g /new/goodware -i local -opcodes
```

### Best Practices for Goodware Collection

1. **Quality over quantity**: Better to have 10K clean files than 100K questionable ones
2. **Diversity**: Include various Windows versions, software types, architectures
3. **No malware**: Strictly clean files - any malware strings pollute the database
4. **Version control**: Track what's in your collection

## Database Maintenance

### Periodic Tasks
```bash
# List all databases and sizes
yargen-util list

# Inspect specific database
yargen-util inspect dbs/good-strings-local.db -top 20

# Compare databases
yargen-util inspect db1.db -top 0 > /tmp/db1.txt
yargen-util inspect db2.db -top 0 > /tmp/db2.txt
diff /tmp/db1.txt /tmp/db2.txt
```

### Updating Downloaded Databases
```bash
# Download latest pre-built databases
yargen-util update
```

### Backup Strategy
- Databases are gzipped JSON - highly compressible
- Version control works well (text-based, diffable)
- Keep backups before major updates

## Troubleshooting

### Database Load Errors
If yarGen fails to load databases:
1. Check file permissions
2. Verify gzip integrity: `gunzip -t file.db`
3. Check JSON validity: `zcat file.db | python -m json.tool > /dev/null`

### String Matching Issues
If rules have false positives:
1. Check if strings exist in database: `yargen-util inspect`
2. Consider creating custom scoring rules
3. Add more goodware samples to cover the strings

### Performance Issues
If yarGen is slow:
1. Use SSD for database storage
2. Consider merging databases
3. Reduce database size (remove old/unused entries)
4. Add more RAM (databases are memory-resident)
