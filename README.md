# film-breakdown

Play-by-play breakdown pipeline for high school football game film.

## What M1 is

M1 is the upload path and nothing else. A coach signs in with Entra ID
(Microsoft's cloud identity service), uploads a Hudl game film, and can only
see film for teams they are assigned to.

Films are 6 to 9 GB Hudl exports over school wifi, so the browser uploads them
directly to Azure Blob Storage (Azure's object storage for large files) using a
short-lived, write-only, single-blob SAS (Shared Access Signature, a scoped
temporary URL that grants one specific permission for a limited time). The film
never passes through app compute.

Nobody watches film in this app. They watch in Hudl. A later rung reads each
film once to produce a play-by-play CSV.

### In scope for M1

- Entra ID sign-in for coaches
- Authorization: a coach sees only the teams and seasons they are assigned to
- The app mints a user delegation SAS using its system-assigned managed identity
  (an Azure-managed credential tied to the App Service, so no secret is stored)
- The browser uploads the film straight to Blob Storage

### Explicitly out of scope for M1

- Upload-time validation, the audit record, and the pipeline trigger. Because the
  app is not in the upload path, these move to the next decision, not this rung.
- The Hudl parser in `lib/breakdown.js` (reserved, not wired in).

## Architecture decisions

See `docs/adr/`. ADR-001 covers direct-to-blob upload with a managed identity and
why the alternatives were rejected: a service principal secret in Key Vault (a
leakable secret would exist), proxying the upload through App Service (230 second
request limit, plus paying for compute that only holds sockets open), and handing
the coach's own Entra token straight to Blob (authorization would then live in
Azure RBAC, so every roster change becomes a privileged operation).

## Constraints

- Infrastructure is Bicep only, no portal clicks. Everything reproducible from
  the template. See `infra/`.
- One resource group per rung, torn down when the rung passes.
- Budget alert deployed before any other resource.
- Node 22, JavaScript, ES modules.
- Deployed and reachable, not just running locally.

## Layout

| Path        | Purpose                                                           |
|-------------|------------------------------------------------------------------|
| `infra/`    | Bicep templates: storage, container, App Service + identity, roles |
| `src/`      | App Service server code: Entra sign-in, authorization, SAS minting |
| `public/`   | Browser upload page                                               |
| `scripts/`  | One-off probes, e.g. verify the identity can get a delegation key |
| `lib/`      | `breakdown.js`, the Hudl playlist parser (reserved, not part of M1) |
| `docs/adr/` | Architecture Decision Records                                     |

M1 ships as a single deployable unit: one App Service serves both `src/` (the
server) and `public/` (the upload page) from the same origin, so the app's own
browser-to-server calls need no CORS rule.

### Deferred decision

The server and browser are separated logically, not physically. When we introduce
an independent front-end deploy (for example the page on Azure Static Web Apps
while the API stays on App Service), split `src/` into `api/` and `web/`. That is
the trigger, and it is a cheap refactor when it fires. Until then, a physical
split would add CORS, dual-origin Entra config, and version-skew risk for no
M1 benefit.
