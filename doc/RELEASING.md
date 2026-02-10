# Releasing diff-review.nvim

This project uses tag-based releases. A GitHub Release is created automatically when a tag
matching `vX.Y.Z` is pushed.

## Prepare

1. Ensure `main` is green in CI.
2. Update `CHANGELOG.md` under `Unreleased`.
3. Decide the next version using SemVer (`MAJOR.MINOR.PATCH`).

## Release

```bash
git checkout main
git pull
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin vX.Y.Z
```

## Verify

- Confirm the GitHub Release was created from the pushed tag.
- Ensure release notes look correct and tests passed.
