#!/usr/bin/env python3
"""
Enhanced MD Doctor fact-checking with deeper source code verification.
"""

import os
import json
import re
import subprocess
from pathlib import Path
from datetime import datetime

FACTS_FILE = Path("/Users/ahmettok/Developer/zuraffa/.specify/memory/md-doctor/facts.json")
SOURCE_DIR = Path("/Users/ahmettok/Developer/zuraffa/lib/src")

def run_grep(pattern, path):
    """Run grep and return matches."""
    try:
        result = subprocess.run(
            ['grep', '-r', pattern, str(path)],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout.strip().split('\n') if result.stdout else []
    except:
        return []

def verify_function_exists(func_name):
    """Verify if a function exists in the source code."""
    matches = run_grep(f'function {func_name}', SOURCE_DIR)
    if not matches:
        matches = run_grep(func_name, SOURCE_DIR)
    return len(matches) > 0

def verify_file_exists(filepath):
    """Verify if a file exists."""
    full_path = Path("/Users/ahmettok/Developer/zuraffa") / filepath
    return full_path.exists()

def verify_class_exists(class_name):
    """Verify if a class exists."""
    matches = run_grep(f'class {class_name}', SOURCE_DIR)
    return len(matches) > 0

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
    
    avg_truth = sum(f["truthfulness"] for f in enhanced_files) / len(enhanced_files)
    print(f"\nAverage truthfulness: {avg_truth:.1f}")

if __name__ == "__main__":
    main()
