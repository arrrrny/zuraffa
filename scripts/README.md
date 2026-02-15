# Scripts Directory

This directory contains helpful scripts for common tasks related to the Zuraffa project.

## delete_tag.sh

A script to delete both local and remote Git tags by version number.

### Usage

```bash
./delete_tag.sh <version_number>
```

### Example

```bash
./delete_tag.sh 3.0.7
```

This will:
1. Delete the local tag `v3.0.7`
2. Delete the remote tag `v3.0.7` from the origin repository

### Notes

- The script automatically prepends "v" to the version number to form the tag name (e.g., `v3.0.7`)
- If the local tag doesn't exist, it will still attempt to delete the remote tag
- If the remote tag doesn't exist, it will show a message but won't fail