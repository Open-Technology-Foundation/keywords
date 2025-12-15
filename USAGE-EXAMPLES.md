# Usage Examples

## Version

Check the version:

```bash
$ keywords --version
keywords 1.0.0
```

## Setup

First, set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY='sk-ant-your-key-here'
```

## Basic Usage

### Extract keywords (text output)

```bash
$ keywords test-sample.txt
retrieval-augmented generation
RAG systems
Claude API
keyword extraction
semantic search
vector embeddings
hybrid search
Okusi Group
Anthropic
natural language processing
```

### From stdin

```bash
$ cat test-sample.txt | keywords

$ echo "Machine learning and artificial intelligence are transforming technology." | keywords
```

## Output Formats

### Plain text with scores

```bash
$ keywords --scores test-sample.txt
retrieval-augmented generation|0.95
RAG systems|0.92
Claude API|0.88
keyword extraction|0.85
semantic search|0.82
```

### CSV format

```bash
$ keywords --format csv --scores --types test-sample.txt
term,score,type
"retrieval-augmented generation",0.95,concept
"RAG systems",0.92,concept
"Claude API",0.88,technical
"keyword extraction",0.85,concept
"semantic search",0.82,concept
```

### JSON format

```bash
$ keywords --format json --entities test-sample.txt
{
  "keywords": [
    {
      "term": "retrieval-augmented generation",
      "score": 0.95,
      "type": "concept"
    },
    {
      "term": "Okusi Group",
      "score": 0.87,
      "type": "entity"
    },
    {
      "term": "Gary Dean",
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

## Short Options

Combine short options for brevity:

```bash
# Instead of: -s -t -v
$ keywords -stv test-sample.txt

# Instead of: -f json -e -s
$ keywords -fjes test-sample.txt

# With stopwords: -S (uppercase for stopwords, -s lowercase for scores)
$ keywords -Sst test-sample.txt

# Note: Options requiring values (like -f, -m, -n) must come last in bundled form
$ keywords -st -f json test-sample.txt
```

## Model Selection

### Use Haiku (default - fast and economical)

```bash
$ keywords test-sample.txt
# or explicitly:
$ keywords --model haiku-4-5 test-sample.txt

# Using short model name:
$ keywords -m haiku test-sample.txt
```

### Use Sonnet (better accuracy for complex text)

```bash
$ keywords --model sonnet-4-5 test-sample.txt
# or simply:
$ keywords -m sonnet test-sample.txt
```

### Use Opus (best quality)

```bash
$ keywords --model opus-4-5 test-sample.txt
# or simply:
$ keywords -m opus test-sample.txt
```

### Using specific model versions

```bash
# Use a specific dated version
$ keywords -m claude-haiku-4-5-20250929 test-sample.txt
```

## Advanced Features

### Stopwords Filtering

Remove common words before extraction (requires [stopwords.bash](https://github.com/Open-Technology-Foundation/stopwords.bash)):

```bash
# Remove stopwords for cleaner extraction
$ keywords -S test-sample.txt

# Combine with other options
$ keywords -Sst test-sample.txt

# With JSON output
$ keywords -Sf json test-sample.txt
```

**Benefits:**
- Reduces API costs (shorter input)
- Focuses on meaningful content words
- Removes filler words (the, and, or, etc.)

**Installation:**
```bash
git clone https://github.com/Open-Technology-Foundation/stopwords.bash
cd stopwords.bash
sudo make install
```

### Filter by minimum score

```bash
# Only keywords with score >= 0.8
$ keywords --scores --min-score 0.8 test-sample.txt
retrieval-augmented generation|0.95
RAG systems|0.92
Claude API|0.88
keyword extraction|0.85
semantic search|0.82
```

### Extract more keywords

```bash
# Extract 30 keywords (default is 20)
$ keywords --max-keywords 30 test-sample.txt
```

### Extract with types

```bash
$ keywords --types test-sample.txt
retrieval-augmented generation|concept
RAG systems|concept
Claude API|technical
keyword extraction|concept
Okusi Group|entity
Gary Dean|entity
```

### Disable caching for fresh results

```bash
$ keywords --no-cache test-sample.txt
```

### Custom cache directory

```bash
$ keywords --cache-dir /tmp/keywords-cache test-sample.txt
```

## Batch Processing

### Process multiple files

```bash
# Process all text files in a directory
for file in documents/*.txt; do
  output="keywords/$(basename "${file%.txt}").txt"
  keywords "$file" > "$output"
  echo "Processed: $file -> $output"
done
```

### Generate CSV index

```bash
# Create a CSV index of all documents
echo "file,keywords" > index.csv
for file in docs/*.txt; do
  keywords=$(keywords --max-keywords 5 "$file" | tr '\n' ';')
  echo "\"$file\",\"$keywords\"" >> index.csv
done
```

### JSON batch output

```bash
# Create JSON array of all extractions
echo "[" > all-keywords.json
first=1
for file in docs/*.txt; do
  [[ $first -eq 0 ]] && echo "," >> all-keywords.json
  echo "{\"file\":\"$file\"," >> all-keywords.json
  keywords --format json "$file" | \
    jq '.keywords' | \
    sed 's/^/  "keywords": /' >> all-keywords.json
  echo "}" >> all-keywords.json
  first=0
done
echo "]" >> all-keywords.json
```

## Pipeline Integration

### Extract keywords from web content

```bash
$ curl -s https://example.com/article.html | \
  html2text | \
  keywords --max-keywords 8
```

### Combine with grep for filtering

```bash
$ keywords test-sample.txt | grep -i "API"
Claude API
```

### Use with jq for JSON processing

```bash
# Extract only technical keywords
$ keywords --format json --types test-sample.txt | \
  jq -r '.keywords[] | select(.type == "technical") | .term'

# Count keywords by type
$ keywords --format json --types test-sample.txt | \
  jq '[.keywords[].type] | group_by(.) | map({type: .[0], count: length})'
```

## RAG System Integration

### Generate search queries

```bash
#!/bin/bash
# Generate optimized search query from document

document="$1"
keywords=$(keywords --max-keywords 5 --scores "$document" | \
  cut -d'|' -f1 | \
  head -3 | \
  paste -sd ' OR ' -)

echo "Search query: $keywords"
# Use with your RAG system
```

### Index documents for retrieval

```bash
#!/bin/bash
# Index all documents with keywords

for doc in corpus/*.txt; do
  doc_id=$(basename "${doc%.txt}")
  keywords=$(keywords --format json --scores --types "$doc")

  # Store in your vector database
  # curl -X POST "http://localhost:8000/index" \
  #   -H "Content-Type: application/json" \
  #   -d "{\"id\":\"$doc_id\",\"keywords\":$keywords}"

  echo "Indexed: $doc_id"
done
```

## Caching Behavior

### First run (API call)

```bash
$ time keywords test-sample.txt
keywords: ◉ Reading from 'test-sample.txt'
keywords: ◉ Calling Anthropic API 'claude-haiku-4-5' ...
keywords: ✓ Result cached
keywords: ✓ Extraction complete
keywords: ◉ API calls: 1

real    0m2.341s
```

### Second run (cached)

```bash
$ time keywords test-sample.txt
keywords: ◉ Reading from 'test-sample.txt'
keywords: ✓ Cache hit
keywords: ✓ Extraction complete
keywords: ◉ Cache hits: 1

real    0m0.042s
```

### Clear cache

```bash
# Clear all cached results
$ rm -rf ~/.cache/keywords/

# Or clear cache for specific directory
$ rm -rf /custom/cache/dir/
```

## Error Handling

### No API key

```bash
$ unset ANTHROPIC_API_KEY
$ keywords test.txt
keywords: ✗ ANTHROPIC_API_KEY environment variable not set
```

### File not found

```bash
$ keywords nonexistent.txt
keywords: ✗ File not found: nonexistent.txt
```

### Input too short

```bash
$ echo "short" | keywords
keywords: ◉ Reading from stdin
keywords: ✗ Input too short (minimum 30 characters)
```

## Performance Considerations

### Input Size Limits

The script handles input up to 200,000 characters. Larger inputs will trigger a warning:

```bash
$ keywords very-large-file.txt
keywords: ◉ Reading from 'very-large-file.txt'
keywords: ▲ Large input (250000 chars) may be slow
```

For very large documents, consider:
- Breaking into chunks
- Extracting keywords from sections separately
- Using summary/abstract only
- Using `-S` to remove stopwords and reduce input size

## Testing

### Dry-run mode (no API calls)

```bash
$ keywords --dry-run test-sample.txt
keywords: ◉ Reading from 'test-sample.txt'
keywords: ◉ DRY-RUN: Would call API with 1234 characters
dry-run

keywords: ✓ Extraction complete
```

### Quiet mode (no progress messages)

```bash
$ keywords --quiet test-sample.txt
retrieval-augmented generation
RAG systems
Claude API
```

### Verbose mode (detailed output)

```bash
$ keywords --verbose test-sample.txt
keywords: ◉ Reading from 'test-sample.txt'
keywords: ◉ Calling Anthropic API 'claude-haiku-4-5' ...
keywords: ✓ Result cached

retrieval-augmented generation
RAG systems
Claude API

keywords: ✓ Extraction complete
keywords: ◉ API calls: 1
```

### Combined short options with verbose

```bash
# Extract with scores, types, and verbose output (bundled)
$ keywords -stv test-sample.txt

# With stopwords, scores, and types (note: -S uppercase)
$ keywords -Sst test-sample.txt

# Quiet mode with JSON output
$ keywords -qf json test-sample.txt
```

## Cost Optimization

### Use caching effectively

Cache results for 24 hours to minimize API costs. The script automatically caches based on:
- Input text content
- Model used
- Max keywords
- Entity extraction flag
- Min score threshold

### Use Haiku model by default

Haiku is 20x cheaper than Opus and 5x cheaper than Sonnet, with excellent quality for keyword extraction.

### Batch process with caching enabled

```bash
# Process documents, leveraging cache for duplicates
for doc in documents/*.txt; do
  keywords "$doc" > "keywords/$(basename "$doc")"
done
```

## Integration with CustomKB

```bash
#!/bin/bash
# Enhance CustomKB queries with keyword extraction

query="$1"
keywords=$(echo "$query" | keywords --max-keywords 5)

# Use keywords for hybrid search in CustomKB
# python3 query_manager.py --query "$query" --keywords "$keywords"
```

## Summary Statistics

```bash
# Count total unique keywords from multiple documents
keywords docs/*.txt | sort -u | wc -l

# Find most common keywords
keywords docs/*.txt | sort | uniq -c | sort -rn | head -10
```

## Stopwords Examples

### Basic stopword removal

```bash
# Sample text with stopwords
$ echo "The quick brown fox jumps over the lazy dog" | keywords

# With stopwords removed (removes: the, over)
$ echo "The quick brown fox jumps over the lazy dog" | keywords -S
```

### Stopwords in batch processing

```bash
# Process documents with stopword removal for cost savings
for doc in corpus/*.txt; do
  keywords -S "$doc" > "keywords/$(basename "$doc")"
done
```

### Stopwords with RAG systems

```bash
# Extract cleaner keywords for semantic search
keywords -Sfse json document.txt

# This combines:
# -S: Remove stopwords
# -f json: JSON output format
# -s: Include scores
# -e: Extract named entities
```

### When to use stopwords

**Use `-S` when:**
- Processing long documents (reduces costs)
- Extracting for search queries (removes noise)
- Working with verbose text (articles, reports)
- Cost optimization is important

**Skip `-S` when:**
- Processing technical documentation (preserves structure)
- Short input text (minimal benefit)
- Stopwords may be meaningful in context
- You need to preserve exact phrasing
