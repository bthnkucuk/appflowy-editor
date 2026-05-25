<!-- See CONTRIBUTING.md for setup, gates, and commit conventions. -->

## Summary

<!-- 1–3 bullets: what changed and why. -->

## Type

- [ ] Bug fix
- [ ] Feature
- [ ] Performance
- [ ] Refactor / cleanup
- [ ] CI / build / docs

## Test plan

<!-- How did you verify? Manual steps, automated tests, before/after numbers. -->

## Checklist

- [ ] `fvm flutter analyze .` clean
- [ ] `fvm dart format --output=none --set-exit-if-changed lib test example/lib example/test` clean
- [ ] `fvm flutter test` passes locally
- [ ] If lifecycle / dispose touched: `fvm flutter test test/leak/` passes (or expected diff documented)
- [ ] Linked any relevant `ROADMAP.md` item (e.g. H1.4)
