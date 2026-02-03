# Contributing

Thanks for your interest in contributing to OpenClaw Helm Chart.

## Getting Started

- Fork the repository and create a feature branch.
- Keep changes focused and include relevant documentation updates.

## Reporting Issues

- Use GitHub issues for bugs and feature requests.
- Provide reproduction steps, expected behavior, and relevant logs.

## Development Workflow

1. Make your changes.
2. Run lint and template checks:

```bash
./scripts/helm-lint.sh
./scripts/helm-test.sh
```

3. Run chart-testing lint:

```bash
ct lint --config ct.yaml
```

4. Open a pull request with a clear description of the change.

## Chart Versioning

- Update `Chart.yaml` version when you change chart behavior.
- Update `CHANGELOG.md` with user-facing changes.
