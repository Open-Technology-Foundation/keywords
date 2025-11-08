# keywords

Extract keywords and keyphrases from text using Anthropic Claude API. Optimized for web search queries and RAG (Retrieval-Augmented Generation) systems.

## Features

- **Pure Bash**: No Python dependencies, only bash, curl, and jq
- **Multiple Models**: Support for Claude Haiku, Sonnet, and Opus
- **Smart Caching**: 24-hour result cache to minimize API calls (SHA256-keyed)
- **Flexible Output**: Text (default), JSON, or CSV formats
- **Stopwords Filtering**: Optional removal of common words before extraction
- **Short Option Bundling**: Combine flags like `-stv` for convenience
- **BCS Compliant**: Follows [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard)
- **Production Ready**: Error handling, validation, shell-safe quoting, and verbose logging
- **Readonly Safety**: Critical variables marked readonly to prevent accidental modification

## Installation

```bash
# Make executable
chmod +x keywords

# Add to PATH (optional)
sudo ln -s "$(pwd)/keywords" /usr/local/bin/
```

## Requirements

**Required:**
- bash 5.2+
- curl (for API calls)
- jq (for JSON processing)
- Anthropic API key

**Optional:**
- [stopwords](https://github.com/Open-Technology-Foundation/stopwords.bash) (for `-S, --stopwords` option)

## Setup

Set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY='your-api-key-here'

# Or add to ~/.bashrc for persistence
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.bashrc
```

## Usage

### Basic Examples

```bash
# Check version
keywords --version

# Extract keywords from file (text output)
keywords document.txt

# From stdin
cat document.txt | keywords
echo "Your text here" | keywords

# With scores (using short option)
keywords -s document.txt

# JSON output with entity extraction (bundled options)
keywords -fes json document.txt
# or long form:
keywords --format json --entities --scores document.txt
```

### Advanced Examples

```bash
# Use Sonnet model for better accuracy
keywords --model sonnet-4-5 document.txt
# or short form:
keywords -m sonnet document.txt

# CSV output with scores and types (bundled)
keywords -fst csv document.txt
# or long form:
keywords --format csv --scores --types document.txt

# Extract more keywords with verbose output
keywords -vn 30 document.txt

# Filter by minimum score with bundled options
keywords -st --min-score 0.7 document.txt

# Remove stopwords before extraction (requires stopwords)
keywords -S document.txt

# Disable caching for fresh results
keywords --no-cache document.txt

# Batch processing with quiet mode
for file in docs/*.txt; do
  keywords -q "$file" > "keywords/$(basename "${file%.txt}").txt"
done
```

## Command-Line Options

```
INPUT:
  FILE                    Input text file (or read from stdin)

OPTIONS:
  -h, --help              Show help message
  -V, --version           Print version
  -m, --model MODEL       Claude model (haiku|sonnet|opus or full name):
                            haiku-4-5  (default, fast & cost-effective)
                            sonnet-4-5 (advanced, better accuracy)
                            opus-4-5   (premium, best quality)
  -n, --max-keywords N    Maximum keywords to extract (default: 20)
  -f, --format FORMAT     Output format:
                            text  (default, one per line)
                            json  (structured with metadata)
                            csv   (term,score,type)
  -s, --scores            Include relevance scores (0.0-1.0)
  -t, --types             Include keyword types
  -e, --entities          Extract named entities separately
  --min-score FLOAT       Minimum relevance score filter (default: 0.0)
  -S, --stopwords         Remove stopwords from input (requires stopwords)
  --no-cache              Disable result caching
  --cache-dir DIR         Cache directory (default: ~/.cache/keywords)
  -v, --verbose           Verbose output
  -q, --quiet             Quiet mode
  --dry-run               Test mode without API calls

SHORT OPTIONS:
  Options can be bundled: -stSv instead of -s -t -S -v
  Options requiring values must come last in bundle
  Note: -S (uppercase) is for stopwords, -s (lowercase) is for scores
```

## Output Formats

### Text (Default)

Simple, one keyword per line:

```
retrieval-augmented generation
RAG systems
Claude API
keyword extraction
semantic search
```

### Text with Scores

```
retrieval-augmented generation|0.95
RAG systems|0.90
Claude API|0.88
```

### JSON

Structured output with metadata:

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

### CSV

```csv
term,score,type
"retrieval-augmented generation",0.95,concept
"Claude API",0.88,technical
"keyword extraction",0.85,concept
```

## Keyword Types

The script categorizes keywords into four types:

- **concept**: Abstract ideas, themes, methodologies
- **technical**: Technologies, tools, frameworks, APIs
- **entity**: People, organizations, locations, products
- **action**: Key processes, activities, operations

## Model Selection

The script uses short model names by default, automatically selecting the latest stable version:

### claude-haiku-4-5 (Default)
- **Aliases**: `haiku`, `haiku-4-5`
- **Best for**: Most use cases
- **Speed**: Fast (1-3 seconds)
- **Cost**: Most economical (~$0.001/extraction)
- **Quality**: Excellent accuracy for keyword extraction

### claude-sonnet-4-5
- **Aliases**: `sonnet`, `sonnet-4-5`
- **Best for**: Complex technical documents
- **Speed**: Moderate (3-7 seconds)
- **Cost**: Medium (~$0.005/extraction)
- **Quality**: Superior nuanced understanding

### claude-opus-4-5
- **Aliases**: `opus`, `opus-4-5`
- **Best for**: Critical accuracy requirements
- **Speed**: Slower (5-15 seconds)
- **Cost**: Highest (~$0.015/extraction)
- **Quality**: Best overall performance

### Using Specific Versions

You can also specify full model IDs with version dates:

```bash
export ANTHROPIC_MODEL='claude-haiku-4-5-20250929'
keywords document.txt
```

## Stopwords Filtering

The `-S, --stopwords` option removes common words (articles, prepositions, conjunctions) from the input text before sending to the API. This can:

- **Reduce noise**: Focus extraction on meaningful content words
- **Lower costs**: Shorter input text means lower API costs
- **Improve relevance**: Remove filler words that don't add semantic value

**Requirements:**
- Install [stopwords.bash](https://github.com/Open-Technology-Foundation/stopwords.bash)
- Ensure `stopwords` command is in your PATH

**Example:**
```bash
# Without stopwords
echo "The quick brown fox jumps over the lazy dog" | keywords

# With stopwords (removes: the, over, the)
echo "The quick brown fox jumps over the lazy dog" | keywords -S
```

**How it works:**
The script calls `stopwords -p` to process the input text, which removes common stopwords while preserving the remaining text structure.

## Caching

Results are cached for 24 hours by default to minimize API costs:

- **Cache location**: `~/.cache/keywords/` (XDG_CACHE_HOME compliant)
- **Cache key**: SHA256 hash of (input text + model + max_keywords + entities flag + min_score)
- **TTL**: 24 hours (stale cache automatically deleted)
- **Disable**: Use `--no-cache` flag
- **Custom location**: Use `--cache-dir /path/to/cache`
- **Clear cache**: `rm -rf ~/.cache/keywords/`

The cache is smart - changing any parameter (model, max keywords, filters) creates a new cache entry.

## Use Cases

### Web Search Query Generation

Extract search terms from long documents:

```bash
keywords --max-keywords 5 article.txt

# With stopword removal for cleaner results
keywords -S --max-keywords 5 article.txt
```

### RAG System Integration

Generate retrieval keywords with scores:

```bash
keywords --format json --scores --entities document.txt

# With stopwords removed for better semantic focus
keywords -Sfse json document.txt
```

### Document Indexing

Batch extract keywords for search indexing:

```bash
for doc in corpus/*.txt; do
  keywords=$(keywords --max-keywords 15 "$doc")
  # Index keywords in your search system
done
```

### Content Analysis

Analyze document themes and topics:

```bash
keywords --format csv --types --scores report.txt
```

## Performance

### Extraction Times (without cache)

- **Haiku model**: 1-3 seconds
- **Sonnet model**: 3-7 seconds
- **Opus model**: 5-15 seconds

### Cached Results

- **Lookup time**: < 50ms
- **Cache hit**: Instant response (no API call)
- **Cost savings**: 100% (no API charges)

### Input Size Limits

- **Minimum**: 50 characters (enforced)
- **Maximum**: 200,000 characters (soft limit, warning shown)
- **Optimal**: 100-10,000 characters per extraction

For large documents, consider extracting from summaries or splitting into sections.

## Error Handling

The script handles common errors gracefully:

- Missing or invalid API key
- Network timeouts (60s default)
- API rate limits
- Invalid input files
- Malformed JSON responses
- File permission issues

## Integration Examples

### With jq for Post-Processing

```bash
# Extract only high-confidence keywords
keywords -f json -s doc.txt | \
  jq '.keywords[] | select(.score > 0.8) | .term'

# Count keywords by type
keywords -f json -t doc.txt | \
  jq '[.keywords[].type] | group_by(.) | map({type: .[0], count: length})'
```

### Pipeline Processing

```bash
# Extract keywords from command output
man bash | keywords --max-keywords 8

# Combine with other tools
curl -s https://example.com/article | \
  html2text | \
  keywords --format csv --scores
```

## Troubleshooting

### "ANTHROPIC_API_KEY environment variable not set"

Set your API key:

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
```

### "Input too short (minimum 50 characters)"

Provide at least 50 characters of text for meaningful keyword extraction.

### "File not found 'filename.txt'"

Check file path and ensure file exists. The script uses shell-safe quoting in error messages.

### "API error 'rate_limit_error': ..."

You've exceeded API rate limits. Solutions:
- Wait and retry
- Use caching (enabled by default)
- Reduce batch processing rate

### "Could not parse valid JSON from response"

Rare API response format issue. The script tries multiple JSON extraction methods. Try:
- Using `--dry-run` to test configuration
- Checking API status
- Retrying the request

### "Large input (250000 chars) may be slow"

Warning for inputs > 200,000 characters. Consider:
- Extracting from document summary
- Processing in chunks
- Using shorter excerpts
- Using `-S` to remove stopwords and reduce input size

### "stopwords not found"

The `-S, --stopwords` option requires the `stopwords` command. Install it:

```bash
# Clone and install stopwords.bash
git clone https://github.com/Open-Technology-Foundation/stopwords.bash
cd stopwords.bash
sudo make install
```

## Development

### Testing

```bash
# Check version
keywords --version

# Test with dry-run mode
keywords --dry-run test-sample.txt

# Test with verbose output and bundled options
keywords -vfes json test-sample.txt

# Test short option bundling (including stopwords)
keywords -stSv test-sample.txt

# shellcheck validation
shellcheck keywords
```

### Sample Files

- `test-sample.txt`: Comprehensive test document
- `test-short.txt`: Minimal test input

## Contributing

This script follows the [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard).

Key standards:
- `set -euo pipefail` for error handling
- `shopt -s inherit_errexit nullglob extglob` for robustness
- 2-space indentation
- `readonly` for immutable variables
- `local` for function-scoped variables
- Shell-safe quoting with `${var@Q}` in messages
- Proper variable quoting throughout
- Standardized messaging icons (◉ ▲ ✓ ✗)
- Single quotes for literal strings

## License

GPL-3

## See Also

- [Anthropic Claude API Documentation](https://docs.anthropic.com/)
- [BASH-CODING-STANDARD](https://github.com/Open-Technology-Foundation/bash-coding-standard)
- [RAG Systems Guide](https://www.anthropic.com/research/retrieval-augmented-generation)
