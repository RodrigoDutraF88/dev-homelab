# Learning journal

Short entries, one per milestone, added in the same commit that adds the
service. Format: what I added, what I learned, what I'd do differently.

## 2026-XX-XX — Traefik

- Added Traefik as the entrypoint for the whole stack.
- Learned: `exposedByDefault: false` + explicit `traefik.enable=true`
  labels avoid accidentally exposing internal services.
- Learned: the dashboard should never be published on its own port in
  anything other than a throwaway local setup — routing it through
  Traefik itself with basic auth is the safer default.
- Next: Portainer, so I can inspect containers without SSH-ing in for
  everything.
