# Nova — Project Reference

Nova is OpenStack's compute service for provisioning and managing virtual machines. It is a large, mission-critical Python project with strict compatibility, versioning, and review requirements.

## Project Links

- **Repository**: https://opendev.org/openstack/nova (GitHub is a mirror only)
- **Bug tracking**: https://bugs.launchpad.net/nova
- **Code review**: Gerrit at https://review.opendev.org (not GitHub PRs)
- **Docs**: https://docs.openstack.org/nova/latest/
- **Contributor guide**: `doc/source/contributor/` in the Nova repo
- **Specs**: `openstack/nova-specs` — `specs/<release>/approved/`, `specs/<release>/implemented/`, `specs/backlog/`, `specs/abandoned/`

For directory structure, core services, virt drivers, oslo libraries, configuration patterns, and test commands, refer to the Nova repository's in-tree documentation at `doc/source/contributor/`. Do not duplicate that information here — read it directly from the source.

## Multi-Cell Architecture (Cells v2)

```text
                    API cell
                 (super conductor)
                /        |        \
           Cell A      Cell B     Cell C
        (conductor)  (conductor)  (conductor)
        (computes)   (computes)   (computes)
```

## Versioning Rules (Critical — Blockers if Violated)

These are hard constraints that reviewers must enforce:

- **RPC methods**: Any modification requires a version bump. New arguments must be optional.
- **Objects**: Attribute or method changes require version increments. Wireline stability is required for live upgrades.
- **Database schema**: Changes must be additive-only. No column removals or type alterations. Migrations must work online (no downtime).
- **Microversions**: API changes require a new microversion with simultaneous client and Tempest updates.

## Coding Conventions

### Deterministic Checks (enforced by CI)

Style violations, import ordering, and Nova-specific hacking checks (N-codes) are enforced by `tox -e pep8`. Do not manually re-check these during review. The full list of N-codes lives in `nova/hacking/checks.py`.

### Conventions That Require Human Judgement

These are patterns that CI cannot fully enforce — reviewers must watch for them:

- **Conductor boundary**: `nova-compute` and virt drivers must never import from `nova/db/` directly. All DB access from compute goes through conductor RPC.
- **Versioning rules**: RPC, object, DB, and API versioning must follow the rules documented in `doc/source/contributor/code-review.rst`.
- **Architectural fit**: Changes should be locally consistent with surrounding code and globally fit Nova's architecture. A locally correct solution that creates architectural debt is not acceptable.
- **Test quality**: Beyond test existence, assess coverage depth, mock appropriateness, stability, and whether bug fix tests use functional tests as reproducers.

### REST API

- Use "project" not "tenant", "server" not "instance"
- URLs use hyphens; request bodies use snake_case
- 201 for synchronous creation, 202 for async

## Internal Service TLS

Nova services communicate over internal channels that operators can secure with TLS:

- **RPC transport** — `oslo.messaging` connections to RabbitMQ can use TLS (`[oslo_messaging_rabbit] ssl = True`, CA/cert/key options)
- **Database** — SQLAlchemy connections to MySQL/PostgreSQL support TLS via `connection` URL parameters and `[database] connection_recycle_time`
- **Console proxies** — novncproxy, serial console proxy use TLS between proxy and compute (e.g., VeNCrypt mutual TLS for VNC via `[vnc] auth_schemes` and associated cert options)
- **Live migration** — libvirt live migration can use TLS (`[libvirt] live_migration_with_native_tls`)
- **Glance/Cinder/Neutron** — connections to other OpenStack services use keystoneauth sessions over HTTPS; CA bundles configured via `[keystone_authtoken]` and per-service `cafile` options

**Reviewer note — security hardening vs code bugs**: TLS configuration in Nova is **operator responsibility**. Code paths that require TLS certificates can assume they are configured when the feature is enabled. A missing certificate when the operator has enabled a TLS feature is a deployment misconfiguration, not a code bug. Reviewers should not suggest guards that silently skip TLS operations when config values are absent — failing loudly on misconfiguration is preferable to silently degrading security. See also the "CVE vs Security Hardening" distinction in `@nova-coresec.md`.

## Operations Requiring Human Review

- Any database migration
- RPC or object version bumps
- REST API microversion changes
- Changes to `nova/conf/` defaults
- Changes to `nova/policies/` defaults
- Anything touching `nova/privsep/`

## Commit Conventions

- Nova uses **Gerrit**, not GitHub PRs
- Third-party CI must vote +1 before core approval on driver changes
- Release notes are mandatory for upgrade, security, or feature-impacting changes (use `reno`)
- Commit messages: reference Launchpad bug IDs with `Closes-Bug: #NNNNNN` or `Related-Bug: #NNNNNN`
