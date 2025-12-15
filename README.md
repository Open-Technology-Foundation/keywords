# keywords

Extract keywords and keyphrases from text using the Anthropic Claude API. Optimized for web search queries and RAG (Retrieval-Augmented Generation) systems.

```bash
$ echo "Machine learning transforms how we process data" | keywords
machine learning
data processing
transformation
ML
data analysis
```

---

## Quick Start

### Installation

```bash
git clone https://github.com/Open-Technology-Foundation/keywords.git
cd keywords
chmod +x keywords
sudo ln -s "$(pwd)/keywords" /usr/local/bin/   # Optional: add to PATH
```

### Requirements

| Dependency | Required | Purpose |
|------------|----------|---------|
| bash 5.2+  | Yes | Script runtime |
| curl       | Yes | API calls |
| jq         | Yes | JSON processing |
| [stopwords](https://github.com/Open-Technology-Foundation/stopwords.bash) | No | Optional `-S` flag |

```bash
# Ubuntu/Debian
sudo apt install curl jq

# macOS
brew install curl jq
```

### Setup

```bash
export ANTHROPIC_API_KEY='sk-ant-your-key-here'

# Persist in ~/.bashrc
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.bashrc
```

### Basic Usage

```bash
# From file
keywords document.txt

# From stdin
cat document.txt | keywords
echo "Your text here" | keywords

# With scores
keywords -s document.txt

# JSON output with entities
keywords -f json -e document.txt

# Bundled short options
keywords -stv document.txt
```

---

## Command Reference

```
keywords [OPTIONS] [FILE]

INPUT:
  FILE                    Input text file (or read from stdin)

MODEL OPTIONS:
  -m, --model MODEL       Claude model (haiku|sonnet|opus or full name)
                            haiku-4-5  (default, fast & cost-effective)
                            sonnet-4-5 (advanced, better accuracy)
                            opus-4-5   (premium, best quality)
  --temperature FLOAT     LLM temperature 0.0-1.0 (default: 0.1)
  --max-tokens N          Maximum response tokens (default: 2000)
  --timeout SECONDS       API timeout in seconds (default: 60)

EXTRACTION OPTIONS:
  -n, --max-keywords N    Maximum keywords to extract (default: 20)
  -s, --scores            Include relevance scores (0.0-1.0)
  -t, --types             Include keyword types (concept/technical/entity/action)
  -e, --entities          Extract named entities separately
  --min-score FLOAT       Minimum relevance score filter (default: 0.0)
  -S, --stopwords         Remove stopwords before extraction (requires stopwords)

OUTPUT OPTIONS:
  -f, --format FORMAT     Output format: text (default), json, csv
  -o, --output FILE       Write output to file instead of stdout

CACHE OPTIONS:
  --no-cache              Disable result caching
  --cache-dir DIR         Cache directory (default: ~/.cache/keywords)

GENERAL OPTIONS:
  -v, --verbose           Verbose output (default)
  -q, --quiet             Quiet mode (no progress messages)
  --dry-run               Test mode without API calls
  -h, --help              Show help message
  -V, --version           Print version

SHORT OPTION BUNDLING:
  Options can be bundled: -stSv instead of -s -t -S -v
  Options requiring values must come last: -st -f json
  Note: -S (uppercase) = stopwords, -s (lowercase) = scores

ENVIRONMENT:
  ANTHROPIC_API_KEY       Required: Your Anthropic API key
  ANTHROPIC_MODEL         Override default model
```

---

## Output Formats

### Text (Default)

One keyword per line, simple and pipeline-friendly:

```
retrieval-augmented generation
RAG systems
Claude API
keyword extraction
```

With scores (`-s`):
```
retrieval-augmented generation|0.95
RAG systems|0.92
Claude API|0.88
```

With types (`-t`):
```
retrieval-augmented generation|concept
Claude API|technical
Okusi Group|entity
```

With both (`-st`):
```
retrieval-augmented generation|0.95|concept
Claude API|0.88|technical
data processing|0.82|action
```

### JSON (`-f json`)

Structured output with full metadata:

```json
{
  "keywords": [
    {
      "term": "retrieval-augmented generation",
      "score": 0.95,
      "type": "concept"
    },
    {
      "term": "Claude API",
      "score": 0.88,
      "type": "technical"
    },
    {
      "term": "Okusi Group",
      "score": 0.85,
      "type": "entity"
    }
  ],
  "metadata": {
    "model": "claude-haiku-4-5-20250929",
    "timestamp": "2025-11-07T13:30:00Z",
    "extraction_method": "llm",
    "api_calls": 1,
    "cache_hits": 0
  }
}
```

### CSV (`-f csv`)

Spreadsheet-compatible format with proper quoting:

```csv
term,score,type
"retrieval-augmented generation",0.95,concept
"Claude API",0.88,technical
"keyword extraction",0.85,concept
```

### Keyword Types

Keywords are categorized into four semantic types:

| Type | Description | Examples |
|------|-------------|----------|
| `concept` | Abstract ideas, themes, methodologies | RAG systems, machine learning |
| `technical` | Technologies, tools, frameworks, APIs | Claude API, Python, Docker |
| `entity` | People, organizations, locations, products | Anthropic, Gary Dean, Indonesia |
| `action` | Key processes, activities, operations | data processing, extraction |

---

## Model Selection

### Available Models

| Model | Aliases | Speed | Cost | Best For |
|-------|---------|-------|------|----------|
| claude-haiku-4-5 | `haiku`, `haiku-4-5` | 1-3s | ~$0.001/call | Most use cases (default) |
| claude-sonnet-4-5 | `sonnet`, `sonnet-4-5` | 3-7s | ~$0.005/call | Complex technical documents |
| claude-opus-4-5 | `opus`, `opus-4-5` | 5-15s | ~$0.015/call | Critical accuracy requirements |

### Usage Examples

```bash
# Default (Haiku)
keywords document.txt

# Use Sonnet for complex analysis
keywords -m sonnet document.txt

# Use Opus for critical accuracy
keywords -m opus-4-5 document.txt

# Specific dated version
keywords -m claude-haiku-4-5-20250929 document.txt

# Via environment variable
export ANTHROPIC_MODEL='claude-sonnet-4-5'
keywords document.txt
```

### Model Selection Guide

**Use Haiku (default) when:**
- Processing many documents (cost-effective)
- Speed matters more than nuance
- Standard keyword extraction tasks

**Use Sonnet when:**
- Analyzing complex technical documentation
- Need better understanding of context
- Extracting from academic or scientific text

**Use Opus when:**
- Critical accuracy requirements
- Complex multi-domain documents
- Quality matters more than cost/speed

---

## Caching System

The script implements intelligent caching to minimize API costs and improve performance.

### How It Works

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Input Text │ ──▶ │ SHA256 Hash  │ ──▶ │ Cache Key   │
│  + Options  │     │  Generation  │     │             │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                 │
                    ┌──────────────┐             ▼
                    │   Cache Hit  │◀── Check ~/.cache/keywords/
                    │   (< 24h)    │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                                 ▼
    Return Cached                     Call API
    (instant)                         Save to Cache
```

### Cache Key Components

The cache key is a SHA256 hash of:
- Input text content
- Model name
- Max keywords setting
- Entity extraction flag
- Minimum score threshold

Changing any parameter creates a new cache entry.

### Cache Location

```bash
# Default location (XDG compliant)
~/.cache/keywords/

# Custom location
keywords --cache-dir /tmp/my-cache document.txt

# Respects XDG_CACHE_HOME
export XDG_CACHE_HOME=/custom/cache
keywords document.txt  # Uses /custom/cache/keywords/
```

### Cache Management

```bash
# Bypass cache for fresh results
keywords --no-cache document.txt

# Clear all cached results
rm -rf ~/.cache/keywords/

# View cache contents
ls -la ~/.cache/keywords/
```

### Performance Comparison

| Scenario | Time | API Cost |
|----------|------|----------|
| First run (API call) | 1-3s | ~$0.001 |
| Cached result | <50ms | $0.00 |
| Cache miss (different params) | 1-3s | ~$0.001 |

---

## Advanced Features

### Stopwords Filtering (`-S`)

Remove common words before API extraction to reduce noise and costs.

```bash
# Without stopwords
echo "The quick brown fox jumps over the lazy dog" | keywords

# With stopwords removed
echo "The quick brown fox jumps over the lazy dog" | keywords -S
```

**Benefits:**
- Reduces API input size (lower costs)
- Focuses extraction on meaningful content
- Removes filler words (the, and, or, a, etc.)

**Requirements:**
```bash
git clone https://github.com/Open-Technology-Foundation/stopwords.bash
cd stopwords.bash
sudo make install
```

**When to use:**
| Use `-S` | Skip `-S` |
|----------|-----------|
| Long documents | Technical docs with structure |
| Verbose text (articles, reports) | Short input text |
| Cost optimization needed | Stopwords may be meaningful |
| Search query generation | Exact phrasing matters |

### Score Filtering (`--min-score`)

Filter keywords by relevance threshold:

```bash
# Only high-confidence keywords (score >= 0.8)
keywords --min-score 0.8 -s document.txt

# Output:
# machine learning|0.95
# data processing|0.88
# (keywords with score < 0.8 excluded)
```

### Entity Extraction (`-e`)

Prioritize named entity extraction:

```bash
keywords -e document.txt

# Emphasizes: organizations, people, products, locations
```

### Temperature Control

Adjust output variation:

```bash
# Lower = more consistent (default: 0.1)
keywords --temperature 0.0 document.txt

# Higher = more varied
keywords --temperature 0.5 document.txt
```

### Output to File (`-o`)

```bash
# Write directly to file
keywords -o results.txt document.txt

# Combine with format
keywords -f json -o results.json document.txt
```

---

## Architecture

### Script Design

Single-file Bash script (591 lines) with modular function design:

```
keywords (591 lines)
├── Dependency checks (curl, jq)
├── Configuration & defaults
├── Helper functions
│   ├── show_help(), show_version()
│   ├── log(), warn(), die()
│   └── expand_model_name()
├── Caching layer
│   ├── generate_cache_key()
│   ├── get_cached_result()
│   └── save_to_cache()
├── API layer
│   ├── build_prompt()
│   ├── call_anthropic_api()
│   └── parse_json_result()
├── Output layer
│   ├── format_as_text()
│   ├── format_as_csv()
│   └── format_as_json()
└── main()
    ├── Argument parsing
    ├── Input validation
    └── Orchestration
```

### Key Design Decisions

| Feature | Implementation | Rationale |
|---------|----------------|-----------|
| Pure Bash | No Python/Node deps | Portability, simplicity |
| SHA256 cache keys | Content-addressable | Deterministic, collision-resistant |
| 3 JSON parse strategies | Fallback chain | API response robustness |
| `${var@Q}` quoting | Shell-safe messages | Security, proper escaping |
| Atomic cache writes | temp file + mv | Concurrency safety |
| `readonly` variables | Immutable config | Accidental modification prevention |

### Exit Codes

| Code | Meaning | Examples |
|------|---------|----------|
| 0 | Success | Extraction completed |
| 1 | Runtime error | API failure, file not found, missing API key |
| 2 | Usage error | Invalid option, invalid format, invalid model |

### Coding Standard

Follows [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard):

- `set -euo pipefail` with `shopt -s inherit_errexit nullglob extglob`
- 2-space indentation
- `declare`/`local` for all variables
- `[[` over `[`; `((...))` for arithmetic
- `var+=1` instead of `((var++))` (safe with `set -e`)
- Standardized message icons: ◉ (info), ▲ (warning), ✓ (success), ✗ (error)
- Scripts end with `#fin` marker

---

## Testing

The project includes a comprehensive test suite with 181 tests across 8 test files.

### Running Tests

```bash
# Run all tests (mocked, no API calls)
./tests/run-all-tests.sh

# Run with live API tests
KEYWORDS_TEST_LIVE=1 ./tests/run-all-tests.sh

# Run individual suite
./tests/test-argument-parsing.sh
./tests/test-caching.sh
```

### Test Suites

| Suite | Tests | Coverage |
|-------|-------|----------|
| test-argument-parsing.sh | 62 | All CLI options, flags, bundling |
| test-input-validation.sh | 19 | File input, stdin, length, binary detection |
| test-error-handling.sh | 16 | Exit codes, error messages, verbose/quiet |
| test-caching.sh | 10 | Cache directory, key generation, --no-cache |
| test-api-integration.sh | 14 | Mocked API + optional live tests |
| test-output-formats.sh | 32 | Text, CSV, JSON with flag combinations |
| test-json-parsing.sh | 14 | JSON structure, fixture validation |
| test-dry-run.sh | 14 | Dry-run behavior and outputs |
| **Total** | **181** | **Comprehensive** |

### Test Features

- **Mocked API tests**: Use PATH manipulation to intercept curl
- **Isolated environments**: Each test uses temporary directories
- **Live API tests**: Optional real API validation
- **BCS test framework**: Shared test-helpers.sh with assertions

### Validation

```bash
# ShellCheck validation
shellcheck keywords
shellcheck tests/*.sh

# Dry-run test
keywords --dry-run test-sample.txt
```

---

## Use Cases

### Web Search Query Generation

```bash
# Extract top 5 search terms
keywords -n 5 article.txt

# With stopword removal for cleaner queries
keywords -Sn 5 article.txt
```

### RAG System Integration

```bash
# Generate retrieval keywords with scores
keywords -f json -se document.txt

# Extract for vector search
keywords=$(keywords -n 10 "$doc")
# Pass to embedding model...
```

### Document Indexing

```bash
# Batch extract for search index
for doc in corpus/*.txt; do
  doc_id=$(basename "${doc%.txt}")
  keywords -f json -st "$doc" > "index/${doc_id}.json"
done
```

### Content Analysis

```bash
# Analyze document themes
keywords -f csv -st report.txt | column -t -s,

# Count keyword types
keywords -f json -t doc.txt | jq '[.keywords[].type] | group_by(.) | map({type: .[0], count: length})'
```

### Pipeline Processing

```bash
# Extract from web content
curl -s https://example.com/article | html2text | keywords -n 8

# Filter high-confidence only
keywords -f json -s doc.txt | jq -r '.keywords[] | select(.score > 0.8) | .term'

# Combine multiple documents
cat docs/*.txt | keywords -n 20
```

### Batch Processing

```bash
# Process directory with quiet mode
for file in docs/*.txt; do
  keywords -qo "keywords/$(basename "${file%.txt}").txt" "$file"
done

# Create CSV index
echo "file,keywords" > index.csv
for file in docs/*.txt; do
  kw=$(keywords -n 5 "$file" | tr '\n' ';')
  echo "\"$file\",\"$kw\"" >> index.csv
done
```

---

## Performance & Cost Optimization

### Performance Benchmarks

| Scenario | Haiku | Sonnet | Opus |
|----------|-------|--------|------|
| First call (API) | 1-3s | 3-7s | 5-15s |
| Cached result | <50ms | <50ms | <50ms |
| API cost per call | ~$0.001 | ~$0.005 | ~$0.015 |

### Input Size Limits

| Limit | Value | Behavior |
|-------|-------|----------|
| Minimum | 30 chars | Error: "too short" |
| Warning | 200,000 chars | Warning shown, continues |
| Optimal | 100-10,000 chars | Best performance |

### Cost Optimization Strategies

1. **Use caching** (enabled by default)
   ```bash
   # Automatic 24-hour cache
   keywords document.txt  # First call: API
   keywords document.txt  # Second call: Cache (free)
   ```

2. **Use Haiku model** (20x cheaper than Opus)
   ```bash
   keywords document.txt  # Default: haiku
   ```

3. **Use stopwords filtering** (reduces input size)
   ```bash
   keywords -S large-document.txt
   ```

4. **Batch with cache reuse**
   ```bash
   # Process duplicates efficiently
   for doc in documents/*.txt; do
     keywords "$doc" > "keywords/$(basename "$doc")"
   done
   ```

5. **Extract from summaries** (for large documents)
   ```bash
   head -100 large-doc.txt | keywords
   ```

---

## Error Handling & Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `curl not found (required)` | Missing dependency | `sudo apt install curl` |
| `jq not found (required)` | Missing dependency | `sudo apt install jq` |
| `ANTHROPIC_API_KEY not set` | No API key | `export ANTHROPIC_API_KEY='...'` |
| `File not found` | Invalid path | Check file exists |
| `Input too short (minimum 30)` | Text < 30 chars | Provide more text |
| `Input file appears to be binary` | Non-text file | Convert to text first |
| `stopwords not found` | Missing optional dep | Install stopwords.bash |

### API Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `authentication_error` | Invalid API key | Check ANTHROPIC_API_KEY |
| `rate_limit_error` | Too many requests | Wait, use caching |
| `overloaded_error` | API overloaded | Retry later |
| `Could not parse valid JSON` | API response issue | Retry, check API status |

### Binary File Handling

```bash
# PDFs
pdftotext document.pdf - | keywords

# HTML
curl -s https://example.com | html2text | keywords

# Word documents
pandoc document.docx -t plain | keywords
```

### Large File Handling

```bash
# Split into chunks
split -l 1000 large-file.txt chunk_
for chunk in chunk_*; do
  keywords "$chunk" >> all-keywords.txt
done

# Extract from summary only
head -500 large-file.txt | keywords

# Use stopwords to reduce size
keywords -S large-file.txt
```

---

## Contributing

This project follows the [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard).

### Key Standards

- `set -euo pipefail` for error handling
- `shopt -s inherit_errexit nullglob extglob` for robustness
- 2-space indentation (mandatory)
- `readonly` for immutable variables
- `local` for function-scoped variables
- Shell-safe quoting with `${var@Q}`
- Standardized icons: ◉ ▲ ✓ ✗
- Single quotes for literal strings
- Scripts end with `#fin`

### Development Workflow

```bash
# Validate with ShellCheck
shellcheck keywords

# Run tests
./tests/run-all-tests.sh

# Test without API calls
keywords --dry-run test-sample.txt

# Test with verbose output
keywords -v test-sample.txt
```

---

## License

GPL-3.0

---

## See Also

- [Anthropic Claude API Documentation](https://docs.anthropic.com/)
- [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard)
- [stopwords.bash](https://github.com/Open-Technology-Foundation/stopwords.bash)
- [RAG Systems Guide](https://www.anthropic.com/research/retrieval-augmented-generation)

---

## Version History

- **1.0.0** - Initial release
  - Pure Bash implementation
  - Haiku/Sonnet/Opus model support
  - Smart caching with SHA256 keys
  - Text/JSON/CSV output formats
  - Comprehensive test suite (181 tests)
