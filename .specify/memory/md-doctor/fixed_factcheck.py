#!/usr/bin/env python3
"""
Fixed MD Doctor fact-checking with proper score calculation.
"""

import os
import json
import re
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parents[3]
FACTS_FILE = REPO_ROOT / ".specify/memory/md-doctor/facts.json"
SOURCE_DIR = REPO_ROOT / "lib/src"
TODAY = datetime.now()

def get_mtime(filepath):
    """Get file modification time."""
    return datetime.fromtimestamp(os.path.getmtime(filepath))

def calculate_freshness(modified_date):
    """Calculate freshness score (0-40) based on age."""
    age_days = (TODAY - modified_date).days
    if age_days <= 7:
        return 40
    elif age_days <= 30:
        return 28
    elif age_days <= 90:
        return 16
    elif age_days <= 180:
        return 6
    else:
        return 0

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

def verify_file_exists(filepath):
    """Verify if a file exists."""
    full_path = REPO_ROOT / filepath
    return full_path.exists()

def verify_function_exists(func_name):
    """Verify if a function exists."""
    name = re.escape(func_name)
    declaration = re.compile(
        rf'(?m)^[ \t]*(?:(?:abstract|external|late|static)[ \t]+)*'
        rf'(?:[A-Za-z][\w<>,?. ]*[ \t]+)?{name}[ \t]*'
        rf'\([^;{{}}]*\)[ \t]*(?:(?:async|sync)[ \t]*)?(?:=>|{{)'
    )
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
    """Recalculate scores with proper freshness and accuracy."""
    claims = file_entry.get("claims", [])
    filepath = file_entry.get("path", "")
    
    # Get actual modification time
    full_path = REPO_ROOT / filepath
    if full_path.exists():
        modified_date = get_mtime(full_path)
    else:
        # Use current time as fallback
        modified_date = datetime.now()
    
    # Calculate proper freshness
    freshness = calculate_freshness(modified_date)
    
    if not claims:
        return {
            "path": filepath,
            "created": modified_date.isoformat(),
            "modified": modified_date.isoformat(),
            "hash": "unknown",
            "claims": [],
            "truthfulness": freshness,  # Only freshness, no accuracy
            "verdict": "stale" if freshness < 28 else "truthful",
            "action": "update" if freshness < 28 else "keep",
            "rationale": f"No claims to verify, freshness={freshness}",
            "proposed_path": None
        }
    
    # Run enhanced fact-checking
    check_results = enhanced_factcheck(claims)
    
    # Count results
    verified = sum(1 for r in check_results if r["status"] == "verified")
    contradicted = sum(1 for r in check_results if r["status"] == "contradicted")
    unverifiable = sum(1 for r in check_results if r["status"] == "unverifiable")
    
    # Calculate accuracy (0-60)
    total = verified + contradicted + unverifiable
    if total == 0:
        accuracy = 0
    elif contradicted > 0:
        accuracy = 0  # Any contradiction sets accuracy to 0
    else:
        accuracy = 60 * (verified / total) if total > 0 else 0
    
    # Calculate truthfulness (0-100)
    truthfulness = freshness + accuracy
    
    # Determine verdict
    if truthfulness >= 80 and contradicted == 0:
        verdict = "truthful"
    elif 50 <= truthfulness <= 79:
        verdict = "stale"
    elif truthfulness < 50 or contradicted > 0:
        verdict = "false"
    else:
        verdict = "obsolete"
    
    # Determine action
    if verdict == "truthful":
        action = "keep"
    elif verdict in ["stale", "false"]:
        action = "update"
    else:
        action = "delete"
    
    return {
        "path": filepath,
        "created": modified_date.isoformat(),
        "modified": modified_date.isoformat(),
        "hash": "unknown",
        "claims": claims,
        "truthfulness": int(truthfulness),
        "verdict": verdict,
        "action": action,
        "rationale": f"Freshness={freshness}, Accuracy={int(accuracy)}, Claims={total} (V:{verified}, C:{contradicted}, U:{unverifiable})",
        "proposed_path": None
    }

def main():
    """Main function to fix fact-checking."""
    # Load existing facts
    with open(FACTS_FILE) as f:
        data = json.load(f)
    
    files = data["files"]
    print(f"Fixing fact-checking for {len(files)} files...")
    
    # Recalculate scores
    fixed_files = []
    for i, file_entry in enumerate(files, 1):
        if i % 50 == 0:
            print(f"Processing {i}/{len(files)}...")
        fixed = recalculate_scores(file_entry)
        fixed_files.append(fixed)
    
    # Update data
    data["files"] = fixed_files
    
    # Write back
    with open(FACTS_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    
    # Print summary
    verdicts = {}
    for f in fixed_files:
        v = f["verdict"]
        verdicts[v] = verdicts.get(v, 0) + 1
    
    print(f"\nFixed verdict summary:")
    for v, count in sorted(verdicts.items()):
        print(f"  {v}: {count}")
    
    avg_truth = (
        sum(f["truthfulness"] for f in fixed_files) / len(fixed_files)
        if fixed_files else 0
    )
    print(f"\nAverage truthfulness: {avg_truth:.1f}")
    
    # Show sample results
    print("\n=== SAMPLE TRUTHFUL FILES ===")
    truthful = [f for f in fixed_files if f['verdict'] == 'truthful'][:3]
    for f in truthful:
        print(f'{f["path"]}: {f["truthfulness"]}')
        print(f'  Rationale: {f["rationale"]}')

if __name__ == "__main__":
    main()
