# Contributing

Thank you for contributing to this project!

## Branching

- `main` — stable, thesis-ready code only.
- `dev` — integration branch for features.
- Feature branches: `feat/<short-description>`.
- Bug fix branches: `fix/<short-description>`.

## Commit Style

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(ros): add altitude controller node
fix(matlab): correct drag coefficient formula
docs: update quickstart in README
```

## Code Style

- Python: formatted with **black**, linted with **ruff**, imports sorted by **isort**.
- MATLAB: follow the [MATLAB Style Guidelines 2.0](https://www.mathworks.com/matlabcentral/fileexchange/46056).
- Run `bash scripts/lint.sh` before opening a PR.

## Pull Requests

1. Fork the repository and create a feature branch.
2. Ensure `bash scripts/lint.sh` passes.
3. Add or update tests where applicable.
4. Submit a PR targeting `dev` with a clear description.

## Issues

Use the GitHub issue tracker. Label bugs as `bug` and enhancements as `enhancement`.
