#!/usr/bin/env python3
"""Batch fetch open bug issues into the speckit-bug-*/ workflow (issue.md + assessment.md).

Mirrors the /skill:speckit-bug-fetch contract:
  - writes .specify/bugs/<slug>/issue.md
  - seeds .specify/bugs/<slug>/assessment.md if missing (never overwrites)
The slug is `issue-<N>-<kebab-title>` for traceability and uniqueness.
"""
import json, subprocess, re, os, sys, datetime

REPO = "arrrrny/zuraffa"
BUGS = [222,223,224,230,231,232,233,234,235,236,237,238,245,246,247,248,249,250,256,272,276,281,284,294,299,302,304,310,312,321,333,337,349,370,375,377,409,410,411,412,414,415,416,418,419,420,441,442]

ALREADY = {"pure-dart-flutter-generation","regression-308-forward-refs-cwd","regression-321-make-cwd"}

def slugify(title, num):
    t = title.lower()
    t = re.sub(r'\[[^\]]*\]', ' ', t)
    t = re.sub(r'[^a-z0-9]+', '-', t)
    t = re.sub(r'-+', '-', t).strip('-')
    t = t[:60].strip('-')
    return f"issue-{num}-{t}"

def gh(*args):
    r = subprocess.run(["gh"]+list(args), capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} -> {r.returncode}\n{r.stderr}")
    return r.stdout

os.chdir("/workspace/zuraffa")
root = ".specify/bugs"
now = datetime.datetime.now(datetime.timezone.utc).isoformat()

created = []
skipped = []
for num in BUGS:
    try:
        raw = gh("issue", "view", str(num), "--repo", REPO,
                 "--json", "title,state,author,labels,body,comments,url")
    except RuntimeError as e:
        skipped.append((num, f"fetch-failed: {e}"))
        continue
    d = json.loads(raw)
    title = d.get("title") or f"issue {num}"
    state = (d.get("state") or "OPEN").lower()
    author = (d.get("author") or {}).get("login", "unknown")
    labels = ", ".join(l["name"] for l in (d.get("labels") or [])) or "none"
    severity = "unknown"
    for l in (d.get("labels") or []):
        if l["name"].lower().startswith("severity:"):
            severity = l["name"].split(":",1)[1]
    body = d.get("body") or ""
    url = d.get("url") or f"https://github.com/{REPO}/issues/{num}"
    comments = d.get("comments") or []
    slug = slugify(title, num)
    bdir = os.path.join(root, slug)
    if os.path.exists(bdir):
        skipped.append((num, f"dir-exists: {slug}"))
        continue
    os.makedirs(bdir, exist_ok=True)

    comments_md = "\n".join(
        f"**{c.get('author',{}).get('login','?')}** ({c.get('createdAt','?')}):\n\n{c.get('body','')}" for c in comments
    ) or "None."

    issue_md = f"""# Bug Issue: {title}

- **Slug**: {slug}
- **Fetched**: {now}
- **Issue**: {num}
- **URL**: {url}
- **State**: {state}
- **Severity**: {severity}
- **Author**: {author}
- **Labels**: {labels}

## Body

{body}

## Comments

{comments_md}
"""
    assess_md = f"""# Bug Assessment: {title}

- **Slug**: {slug}
- **Created**: {now}
- **Source**: {url}
- **Verdict**: likely valid, needs reproduction
- **Severity**: {severity}

## Report (verbatim or summarized)

{title} — see {url}.

## Symptom

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Reproduction

[NEEDS CLARIFICATION — parse from issue body above.]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: …]
"""
    with open(os.path.join(bdir,"issue.md"),"w") as f: f.write(issue_md)
    with open(os.path.join(bdir,"assessment.md"),"w") as f: f.write(assess_md)
    created.append((num, slug))

print("CREATED:", len(created))
for n,s in created: print(f"  #{n} -> {s}")
print("SKIPPED:", len(skipped))
for n,why in skipped: print(f"  #{n}: {why}")
