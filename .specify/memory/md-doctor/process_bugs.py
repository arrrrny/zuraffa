#!/usr/bin/env python3
"""
MD Doctor: Process all bug directories in .specify/bugs/
Extract claims, fact-check against source, compute truthfulness scores.
"""

import os
import json
import re
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

BUGS_DIR = Path("/Users/ahmettok/Developer/zuraffa/.specify/bugs")
FACTS_FILE = Path("/Users/ahmettok/Developer/zuraffa/.specify/memory/md-doctor/facts.json")
TODAY = datetime(2026, 8, 31)

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

def extract_claims(content, filename):
    """Extract factual claims from markdown content."""
    claims = []
    lines = content.split('\n')
    
    for line in lines:
        line = line.strip()
        
        # Skip empty lines, headers, and meta info
        if not line or line.startswith('#') or line.startswith('- **'):
            continue
            
        # Look for file path claims
        if 'lib/src/' in line or 'lib/' in line:
            # Extract path claims
            paths = re.findall(r'(lib/[\w/]+\.dart)', line)
            for p in paths:
                claims.append(f"File exists: {p}")
        
        # Look for function/method claims
        func_matches = re.findall(r'(\w+)\(\)', line)
        for func in func_matches:
            if len(func) > 3 and func[0].islower():  # Likely a function name
                claims.append(f"Function exists: {func}")
        
        # Look for test claims
        if 'test' in filename.lower() or 'test' in line.lower():
            if 'pass' in line.lower() or 'fail' in line.lower():
                claims.append(f"Test result: {line[:100]}")
        
        # Look for file existence claims
        if 'exists' in line.lower() or 'present' in line.lower():
            claims.append(f"Existence claim: {line[:100]}")
        
        # Look for behavioral claims
        if any(keyword in line.lower() for keyword in ['generates', 'creates', 'emits', 'writes', 'produces']):
            claims.append(f"Behavioral claim: {line[:100]}")
    
    return claims

def fact_check_claim(claim, bugs_dir):
    """Fact-check a single claim against the source code."""
    # Simple fact-checking for file existence
    if claim.startswith("File exists:"):
        filepath = claim.split("File exists:")[1].strip()
        full_path = Path("/Users/ahmettok/Developer/zuraffa") / filepath
        if full_path.exists():
            return "verified"
        else:
            return "contradicted"
    
    # For other claims, mark as unverifiable for now
    return "unverifiable"

def process_bug_directory(bug_dir):
    """Process a single bug directory and extract facts."""
    bug_name = bug_dir.name
    results = []
    
    # Get all .md files in the directory
    md_files = list(bug_dir.glob("*.md"))
    
    for md_file in md_files:
        try:
            content = md_file.read_text(encoding='utf-8')
            modified_date = get_mtime(md_file)
            freshness = calculate_freshness(modified_date)
            
            # Extract claims
            claims = extract_claims(content, md_file.name)
            
            # Fact-check claims
            verified = 0
            contradicted = 0
            unverifiable = 0
            
            for claim in claims:
                result = fact_check_claim(claim, bug_dir)
                if result == "verified":
                    verified += 1
                elif result == "contradicted":
                    contradicted += 1
                else:
                    unverifiable += 1
            
            # Calculate accuracy
            total_claims = verified + contradicted + unverifiable
            if total_claims == 0:
                accuracy = 0
            elif contradicted > 0:
                accuracy = 0  # Any contradiction sets accuracy to 0
            else:
                accuracy = 60 * (verified / total_claims) if total_claims > 0 else 0
            
            # Calculate truthfulness
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
            
            # Build file entry
            file_entry = {
                "path": str(md_file.relative_to(Path("/Users/ahmettok/Developer/zuraffa"))),
                "created": modified_date.isoformat(),
                "modified": modified_date.isoformat(),
                "hash": "unknown",  # Would need git to get actual hash
                "claims": claims[:10],  # Limit to 10 claims for brevity
                "truthfulness": int(truthfulness),
                "verdict": verdict,
                "action": action,
                "rationale": f"Freshness={freshness}, Accuracy={int(accuracy)}, Claims={total_claims} (V:{verified}, C:{contradicted}, U:{unverifiable})",
                "proposed_path": None
            }
            
            results.append(file_entry)
            
        except Exception as e:
            print(f"Error processing {md_file}: {e}")
            continue
    
    return results

def main():
    """Main processing function."""
    all_facts = []
    
    # Process each bug directory
    bug_dirs = sorted([d for d in BUGS_DIR.iterdir() if d.is_dir()])
    
    print(f"Processing {len(bug_dirs)} bug directories...")
    
    for i, bug_dir in enumerate(bug_dirs, 1):
        print(f"[{i}/{len(bug_dirs)}] Processing {bug_dir.name}...")
        facts = process_bug_directory(bug_dir)
        all_facts.extend(facts)
    
    # Write facts.json
    output = {"files": all_facts}
    FACTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(FACTS_FILE, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\nProcessed {len(all_facts)} files total")
    print(f"Facts written to {FACTS_FILE}")
    
    # Print summary
    verdicts = {}
    for fact in all_facts:
        v = fact["verdict"]
        verdicts[v] = verdicts.get(v, 0) + 1
    
    print("\nVerdict summary:")
    for v, count in sorted(verdicts.items()):
        print(f"  {v}: {count}")

if __name__ == "__main__":
    main()
