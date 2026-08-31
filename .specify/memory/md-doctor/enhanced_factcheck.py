#!/usr/bin/env python3
"""
Enhanced MD Doctor fact-checking with deeper source code verification.
"""

import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
FACTS_FILE = REPO_ROOT / ".specify/memory/md-doctor/facts.json"
SOURCE_DIR = REPO_ROOT / "lib/src"

def _dart_code_only(source):
    """Replace Dart comments and strings with spaces, preserving newlines."""
    result = list(source)
    i = 0
    while i < len(source):
        if source.startswith('//', i):
            end = source.find('\n', i)
            end = len(source) if end == -1 else end
        elif source.startswith('/*', i):
            depth = 1
            end = i + 2
            while end < len(source) and depth:
                if source.startswith('/*', end):
                    depth += 1
                    end += 2
                elif source.startswith('*/', end):
                    depth -= 1
                    end += 2
                else:
                    end += 1
        elif source[i] in "'\"":
            quote = source[i]
            marker = quote * 3 if source.startswith(quote * 3, i) else quote
            end = i + len(marker)
            while end < len(source):
                if source.startswith(marker, end):
                    end += len(marker)
                    break
                end += 2 if source[end] == '\\' and len(marker) == 1 else 1
        else:
            i += 1
            continue
        for pos in range(i, min(end, len(result))):
            if result[pos] != '\n':
                result[pos] = ' '
        i = end
    return ''.join(result)


def _dart_sources():
    for path in SOURCE_DIR.rglob('*.dart'):
        yield _dart_code_only(path.read_text(encoding='utf-8'))

def verify_function_exists(func_name):
    """Verify if a function exists in the source code."""
    name = re.escape(func_name)
    declaration = re.compile(
        rf'(?m)^[ \t]*(?:(?:abstract|external|late|static)[ \t]+)*'
        rf'(?:[A-Za-z][\w<>,?. ]*[ \t]+)?{name}[ \t]*'
        rf'\([^;{{}}]*\)[ \t]*(?:(?:async|sync)[ \t]*)?(?:=>|{{)'
    )
    return any(declaration.search(source) for source in _dart_sources())

def verify_file_exists(filepath):
    """Verify if a file exists."""
    full_path = REPO_ROOT / filepath
    return full_path.exists()

def verify_class_exists(class_name):
    """Verify if a class exists."""
    declaration = re.compile(rf'\bclass[ \t]+{re.escape(class_name)}\b')
    return any(declaration.search(source) for source in _dart_sources())

def enhanced_factcheck(claims):
    """Enhanced fact-checking with source code verification."""
    results = []
    
    for claim in claims:
        if claim.startswith("File exists:"):
            filepath = claim.split("File exists:")[1].strip()
            verified = verify_file_exists(filepath)
            results.append({
                "claim": claim,
                "status": "verified" if verified else "contradicted"
            })
        
        elif claim.startswith("Function exists:"):
            func_name = claim.split("Function exists:")[1].strip()
            verified = verify_function_exists(func_name)
            results.append({
                "claim": claim,
                "status": "verified" if verified else "unverifiable"
            })
        
        else:
            results.append({
                "claim": claim,
                "status": "unverifiable"
            })
    
    return results

def recalculate_scores(file_entry):
    """Recalculate scores with enhanced fact-checking."""
    claims = file_entry.get("claims", [])
    
    if not claims:
        return file_entry
    
    # Run enhanced fact-checking
    check_results = enhanced_factcheck(claims)
    
    # Count results
    verified = sum(1 for r in check_results if r["status"] == "verified")
    contradicted = sum(1 for r in check_results if r["status"] == "contradicted")
    unverifiable = sum(1 for r in check_results if r["status"] == "unverifiable")
    
    # Calculate accuracy
    total = verified + contradicted + unverifiable
    if total == 0:
        accuracy = 0
    elif contradicted > 0:
        accuracy = 0  # Any contradiction sets accuracy to 0
    else:
        accuracy = 60 * (verified / total) if total > 0 else 0
    
    # Get freshness from existing entry
    freshness = file_entry.get("truthfulness", 0) - 60  # Extract freshness component
    
    # Recalculate truthfulness
    truthfulness = freshness + accuracy
    
    # Update verdict
    if truthfulness >= 80 and contradicted == 0:
        verdict = "truthful"
    elif 50 <= truthfulness <= 79:
        verdict = "stale"
    elif truthfulness < 50 or contradicted > 0:
        verdict = "false"
    else:
        verdict = "obsolete"
    
    # Update action
    if verdict == "truthful":
        action = "keep"
    elif verdict in ["stale", "false"]:
        action = "update"
    else:
        action = "delete"
    
    # Update entry
    file_entry["truthfulness"] = int(truthfulness)
    file_entry["verdict"] = verdict
    file_entry["action"] = action
    file_entry["rationale"] = f"Enhanced check: V:{verified}, C:{contradicted}, U:{unverifiable} (total:{total})"
    
    return file_entry

def main():
    """Main function to enhance fact-checking."""
    # Load existing facts
    with open(FACTS_FILE) as f:
        data = json.load(f)
    
    files = data["files"]
    print(f"Enhancing fact-checking for {len(files)} files...")
    
    # Recalculate scores
    enhanced_files = []
    for i, file_entry in enumerate(files, 1):
        if i % 50 == 0:
            print(f"Processing {i}/{len(files)}...")
        enhanced = recalculate_scores(file_entry)
        enhanced_files.append(enhanced)
    
    # Update data
    data["files"] = enhanced_files
    
    # Write back
    with open(FACTS_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    
    # Print summary
    verdicts = {}
    for f in enhanced_files:
        v = f["verdict"]
        verdicts[v] = verdicts.get(v, 0) + 1
    
    print(f"\nEnhanced verdict summary:")
    for v, count in sorted(verdicts.items()):
        print(f"  {v}: {count}")
    
    avg_truth = (
        sum(f["truthfulness"] for f in enhanced_files) / len(enhanced_files)
        if enhanced_files else 0
    )
    print(f"\nAverage truthfulness: {avg_truth:.1f}")

if __name__ == "__main__":
    main()
