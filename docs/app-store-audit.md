# App Store Audit

An agent skill for auditing iOS and iPadOS releases against current official Apple requirements. It examines release evidence, checks relevant Apple documentation during each audit, and separates confirmed issues from missing verification.

## Install locally

From the parent skills folder:

```bash
npx skills add . --skill app-store-audit
```

Select your coding agent when prompted. Add `-g` to install across projects. A browser/search tool is needed to verify current Apple requirements; without one, the audit explicitly marks currency unverified.

Once this repository is hosted, replace `OWNER/REPOSITORY` below with its actual GitHub path:

```bash
npx skills add OWNER/REPOSITORY --skill app-store-audit
```

No npm package publication is required: `skills` discovers the `SKILL.md` in this repository.

## Use

```text
Use $app-store-audit to audit this app before submission.
We plan to submit on [date] in [storefronts].
Inspect the Release configuration and available submission materials.
Report current Apple requirements, confirmed findings, and unverified checks.
```

For a rejection:

```text
Use $app-store-audit to investigate this App Review rejection: [message].
Map each concern to the implementation and current Apple rules.
Recommend concrete fixes and verification steps.
```

## Coverage

- Release configuration, archive evidence, and dated submission requirements.
- Privacy manifests, SDKs, permissions, data flows, and store disclosures.
- Login, account lifecycle, purchases, subscriptions, and regional conditions.
- Runtime readiness, reviewer access, metadata, media, and age ratings.
- Feature-specific requirements discovered from the current guidelines.

Reports include prioritized findings, evidence locations, direct Apple citations, remediation, and a coverage table. Source-only audits leave runtime, backend, archive, and App Store Connect checks unverified where evidence is absent. Audit mode does not publish, submit, or modify the app. Request fixes explicitly when needed.

The skill does not guarantee App Review approval. It is independent of Apple and does not redistribute Apple's guidelines.

## Sources and maintenance

The skill starts with Apple's [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [submission guidance](https://developer.apple.com/app-store/submitting/), and [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/). It follows applicable feature and regional documentation during each audit instead of storing SDK versions or deadlines as permanent rules.

The implementation lives in [app-store-audit/SKILL.md](../app-store-audit/SKILL.md). Supporting references describe source discovery and evidence checks. Update the workflow when audit behavior needs improvement; current policy text remains at Apple.
