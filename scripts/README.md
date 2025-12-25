# Scripts

This directory contains utility scripts for managing the snap.nvim project.

## Version Management

### `set-version.sh`

Synchronizes the version number between `lua/snap/globals/versions/plugin.lua` and all version references in `README.md`. Optionally updates the backend version as well.

**Usage:**

```bash
# Set version to a specific version (updates plugin.lua and README.md)
./scripts/set-version.sh 1.4.0

# Use version from plugin.lua (updates README.md only)
./scripts/set-version.sh

# Also update backend version
./scripts/set-version.sh 1.4.0 --backend
```

**What it does:**

- Updates `lua/snap/globals/versions/plugin.lua` to the specified version (format: `"X.Y.Z"`)
- Updates all version references in `README.md` to `vX.Y.Z` format
- Optionally updates `lua/snap/globals/versions/backend.lua` if `--backend` flag is used
- Validates version format before applying changes

### `validate-version.sh`

Validates that versions in `plugin.lua` and `README.md` match. Also validates backend version if backend files have changed since the last release.

**Usage:**

```bash
# Validate versions (without tag context)
./scripts/validate-version.sh

# Validate versions for a specific tag (checks backend changes)
./scripts/validate-version.sh v1.4.0
```

**What it validates:**

- Plugin version matches all README version references
- If backend files (`backend/**` or `lua/snap/globals/versions/backend.lua`) have changed since the last tag:
  - Backend version must match the tag version
- If no previous tag exists, assumes backend has changes

**Exit codes:**

- `0` - All versions match
- `1` - Version mismatch detected or error occurred

## Release Workflow

### Before Creating a Release

1. **Update the version in `plugin.lua`:**

   ```bash
   # Edit lua/snap/globals/versions/plugin.lua manually, or use:
   ./scripts/set-version.sh 1.4.0
   ```

2. **Synchronize versions:**

   ```bash
   ./scripts/set-version.sh
   ```

   This will update all version references in `README.md` to match `plugin.lua`.

3. **If backend files changed, update backend version:**

   ```bash
   # Update backend version to match plugin version
   ./scripts/set-version.sh 1.4.0 --backend
   ```

4. **Validate versions match:**

   ```bash
   # Validate for the tag you're about to push
   ./scripts/validate-version.sh v1.4.0
   ```

5. **Commit the changes:**

   ```bash
   git add lua/snap/globals/versions/plugin.lua README.md
   # If backend version was updated:
   git add lua/snap/globals/versions/backend.lua
   git commit -m "chore: bump version to 1.4.0"
   ```

6. **Create and push the tag:**

   ```bash
   git tag v1.4.0
   git push origin v1.4.0
   ```

   The git pre-push hook will automatically validate versions before allowing the tag push.

### Using `release.sh`

The `release.sh` script automates the release process:

```bash
VERSION=1.4.0 ./scripts/release.sh
```

This script will:

1. Check that the working directory is clean
2. Set the version in both files
3. Validate versions match
4. Create a GitHub release with the tag

## Git Hooks

### Pre-push Hook

Git hooks are automatically managed by [`simple-git-hooks`](https://github.com/toplenboren/simple-git-hooks). The hooks are installed automatically when you run `bun install` (via the `prepare` script).

The pre-push hook prevents pushing tags when:

- Versions in `plugin.lua` and `README.md` don't match
- The tag name doesn't match the version in `plugin.lua` (e.g., tag `v1.3.0` but plugin version is `1.4.0`)
- Backend files have changed since the last release, but the backend version doesn't match the tag version

If validation fails, the push will be blocked and you'll be prompted to fix the version issues.

**Backend version validation:**

- The hook checks if any files in `backend/**` or `lua/snap/globals/versions/backend.lua` have changed since the previous tag
- If changes are detected, the backend version must match the tag version
- If no previous tag exists, it assumes backend has changes and validates accordingly

**Configuration:**

- Hook configuration: `.simple-git-hooks.json`
- Hook script: `scripts/pre-push-hook.sh`

**To manually reinstall hooks:**

```bash
bun run prepare
# or
bunx simple-git-hooks
```
