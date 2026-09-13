# ADR-001: Uploading game film to Blob Storage

Date: 2026-09-06
Status: Accepted

## Context

Coaches upload game film from Hudl exports. One game is 6 to 9 GB, uploaded from
a laptop on school wifi, which is slow and drops.

Nobody watches video inside this app. Coaches watch film in Hudl. Our pipeline
reads each film once to produce a play-by-play CSV, and after that the film is
dead weight.

A coach may only see film for teams they are assigned to. Coaching staff changes
during the season, and assignments differ by level, so who can see what is a
moving target owned by the program, not by IT.

The app must hold no credential it could leak. This was named as a gap and it is
a hard requirement, not a preference.

## Decision

The app runs on Azure App Service with a system-assigned managed identity. Azure
vouches for the app, so no password or secret is stored anywhere.

When a coach asks to upload, the app checks its own data to confirm the coach is
assigned to that team and season. Only if that check passes does the app use its
managed identity to sign a temporary upload link (a user delegation SAS) scoped
to a single blob path, write permission only, expiring in minutes. The link goes
back to the browser and the browser uploads directly to Blob Storage.

The identity holds two permissions on the storage account: Storage Blob Data
Contributor, to read and write blobs, and Storage Blob Delegator, which is what
allows it to sign links at all. Missing the second one produces a 403 that looks
like something else is broken.

## Alternatives considered

**Service principal with a client secret in Key Vault.** A stored password
authenticates the app to Blob Storage. Rejected because a long-lived secret
exists. It can be committed, logged, captured in an exception dump, or sit
unrotated for years. The requirement was no credential to leak, and this option
starts by creating one.

**Same managed identity, but the upload is proxied through App Service.**
The coach posts the film to our API and our API writes it to Blob. Rejected on
file size. A 9 GB upload over school wifi takes tens of minutes, and App Service
closes a request at roughly 230 seconds, which is not configurable. Even if it
completed, we would be paying for compute that is doing nothing but holding a
socket open while data trickles in, and that cost grows with every coach.

Proxying is marginally safer than what we picked, since it never hands a credential to
a browser. We accepted that trade knowingly. See Consequences.

**The coach's own Entra sign-in writes to Blob directly, no app in the middle.** Rejected because no code of ours runs, so access rules have to live in
Azure itself as role assignments or ABAC conditions. Azure ABAC can express
conditions, on blob path, index tags, and principal attributes, so the problem
is not expressiveness. The problem is that our rule depends on data Azure does
not have. "Assigned to this team, this season" is a fact about our roster, which
lives in our database. Azure can evaluate whether a blob is tagged Team=JV. It
cannot know whether this coach is on JV this season.

There is a version that works: put team assignment on each user as an Entra
custom security attribute and match it against a blob index tag in the
condition. That moves the roster into Entra, so every staff change becomes a
directory write performed by someone with the right permissions, rather than a
row in our own data. Same operational problem, relocated. Authorization belongs
in our application, where it is data we can test, version, and change.

## Consequences

**We hand a credential to a browser we do not control.** The signed link works
for anyone holding it, with no sign-in. We bounded this with a single blob path,
write-only permission, and a short expiry, but the exposure is real and it is
the price of keeping the film off our compute.

**Our code no longer runs at upload time.** Under the proxy option we would have
had one guaranteed place to validate the file, record who uploaded which game,
and start the M2 clip split. We gave that up. Anything that needs to happen when
a film arrives now needs a separate mechanism to learn the blob landed. That is
the next decision, and Event Grid's BlobCreated event is the leading candidate.

**Authorization stays ours.** Adding a coach or changing a team assignment is a
row in our data, not an Azure operation. This is the property that keeps the
system usable in-season.

**Film retention is now a separate decision.** Because the pipeline reads each
film once and nobody watches video in the app, we can put a lifecycle policy on
the container and tier or delete the film after parsing. Nothing about this
decision forces us to keep it. That belongs in M6.
