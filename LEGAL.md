# Redistribution Approval — FD Headless Binary

## STATUS: APPROVED

## Binary
- **Product**: FD Headless (FeatureDesigner Headless)
- **Version**: 8.6.0-NVX90-V3.1.0 (NVX90 V3.1.0 delivery; FD build 8.6.0.202606260649)
- **Artifact**: `FD_Headless-linux.gtk.x86_64-8.6.0-NVX90-V3.1.0.tar.gz` (delivered as `NVX90_V3.1.0_FD_Headless_LINUX.gz`)
- **SHA256**: `bf41e14a2cabcf098664a43b1e04cb9b0be1d7fd2254bf6830c2e11654930fa2`

## Approval

### Granting Party
- **Organization**: Nevonex (on behalf of Bosch FD team)
- **Contact**: <redacted — see internal email thread referenced below>

### Scope
- **Allowed distribution channel**: AWS Public ECR (`public.ecr.aws/<alias>/seamos-fd-headless`)
- **Allowed platforms**: `linux/amd64` (single-arch)
- **Allowed image tags**: versioned (`:8.6.0-*`) and `:latest`
- **Redistribution conditions**: binary embedded in Docker image for developer use in the SeamOS AI Native ecosystem; direct binary redistribution outside the image is NOT covered by this approval.

### Evidence
- **Approval date**: <TBD — fill in ISO-8601 date when confirmed>
- **Reference**:
  - Email thread: <TBD — link to internal mail archive or PDF>
  - Signed document (if any): <TBD — file path or DMS link>

## Revocation
If Nevonex/Bosch revokes this approval, update `STATUS: APPROVED` to `STATUS: REVOKED` above. The CI workflow (`.github/workflows/build-fd-image.yml`) gates all ECR pushes on `STATUS: APPROVED` via grep.

## Updates
Any FD Headless binary version change requires re-verification of approval scope and an update to both the SHA256 and `skills/create-project/references/fd-version.json`.
