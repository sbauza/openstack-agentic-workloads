# Nova Bug Triage — Project Reference

@.ambient/ambient.json

@rules.md

## Project Overview

Nova is OpenStack's compute service for provisioning and managing virtual machines. This workflow helps triagers determine whether Launchpad bug reports filed against Nova are valid defects or fall into invalid categories.

- **Repository**: https://opendev.org/openstack/nova
- **Bug tracking**: https://bugs.launchpad.net/nova
- **Docs**: https://docs.openstack.org/nova/latest/
- **Contributor guide**: `doc/source/contributor/` in the Nova repo

## Nova Directory Structure

```text
nova/
├── api/           # REST API endpoints and WSGI apps
├── compute/       # Compute service core (ComputeManager)
├── conductor/     # Conductor service (DB proxy, orchestration)
├── scheduler/     # VM scheduling logic
├── virt/          # Virtualization drivers (libvirt, vmwareapi, ironic, zvm)
├── network/       # Neutron integration
├── storage/       # Storage backends
├── db/            # Database layer and migrations
├── objects/       # Versioned data objects
├── cmd/           # CLI entry points
├── conf/          # All configuration option definitions
├── policies/      # Policy registration
├── pci/           # PCI passthrough support
├── console/       # Console access
├── image/         # Glance integration
├── notifications/ # Event notifications
├── privsep/       # Privileged operations
├── tests/
│   ├── unit/
│   └── functional/
```

## Nova Subsystems

When triaging, identify which subsystem is affected:

| Subsystem | Directory | Common Bug Patterns |
|-----------|-----------|---------------------|
| Compute | `nova/compute/` | VM lifecycle failures, resource tracking issues |
| Scheduler | `nova/scheduler/` | Placement issues, incorrect host selection |
| API | `nova/api/` | Request validation, microversion behavior |
| Conductor | `nova/conductor/` | Orchestration failures, migration issues |
| Libvirt | `nova/virt/libvirt/` | Hypervisor interaction, image handling, device passthrough |
| Cells | `nova/conductor/`, `nova/compute/` | Cross-cell communication, cell mapping |
| Networking | `nova/network/` | Port binding, VIF plugging |
| Config | `nova/conf/` | Option registration, deprecated options |
| Objects | `nova/objects/` | Versioning issues, serialization |

## Bug Triage Conventions

### Validity Categories

The primary goal of triage is to determine whether a bug report is valid. Classify each bug into one of these categories:

**Configuration Issue**
- Reporter describes behavior caused by misconfiguration
- Detection: search `nova/conf/` for related config options; check if the described behavior matches a known misconfiguration pattern
- Common signals: error messages mentioning config values, behavior that changes with configuration, deployment-specific issues
- Launchpad status: **Invalid**

**Unsupported Feature**
- Reporter expects behavior from an unsupported deployment, driver, or feature combination
- Detection: check virt driver capability flags, API extension registrations, feature support matrices
- Common signals: use of deprecated drivers, unsupported hypervisor features, EOL release behavior
- Launchpad status: **Won't Fix**

**Incomplete Report**
- Bug lacks sufficient information to reproduce or understand the issue
- Detection: check for missing elements: Nova version, steps to reproduce, logs/tracebacks, configuration details, deployment topology
- Questions to ask: "What Nova version?", "What hypervisor?", "Can you provide nova-compute logs?", "What's your configuration for [relevant section]?"
- Launchpad status: **Incomplete**

**Not Reproducible in Master**
- Issue has been fixed in the current master branch
- Detection: search `git log` for related commits; check if referenced code paths have changed; look for `Closes-Bug` or `Related-Bug` references
- Common signals: old Nova version in report, code path has been refactored, explicit fix commit exists
- Launchpad status: **Invalid**

**RFE (Request for Enhancement)**
- Reporter describes functionality that was never implemented — this is a feature request, not a bug
- Detection: verify the requested functionality does not exist in the codebase. The reporter expects behavior that Nova does not provide (e.g., flavor extra specs for image properties that have no corresponding implementation)
- Common signals: "Nova should support...", "Why doesn't Nova do...", requested code path doesn't exist in source
- Launchpad status: **Invalid**, Importance: **Wishlist**
- Recommend: file a nova-spec or RFE instead

**Likely Valid Bug**
- The report describes a genuine defect in Nova's existing functionality
- Detection: code path exists, behavior doesn't match documented intent, no configuration explanation
- Propose: importance level (Critical, High, Medium, Low), affected subsystem

### Launchpad Bug Lifecycle

```text
New → Incomplete (need info) → New (info provided)
New → Confirmed (verified) → Triaged (fully analyzed)
New → Invalid / Won't Fix / Opinion (not a bug)
Triaged → In Progress → Fix Committed → Fix Released
```

### Valid Launchpad Statuses

| Status | Meaning | Who Can Set |
|--------|---------|-------------|
| New | Just reported, unreviewed | Anyone |
| Incomplete | Needs more information from reporter | Anyone |
| Confirmed | Verified by someone other than reporter | Anyone |
| Triaged | Fully analyzed, ready for development | Bug Supervisor |
| In Progress | Developer working on fix | Anyone |
| Fix Committed | Fix merged to master | Anyone |
| Fix Released | Fix in a released version | Anyone |
| Invalid | Not a bug | Anyone |
| Won't Fix | Acknowledged but no plans to fix | Bug Supervisor |
| Opinion | Difference of opinion | Anyone |

### Valid Importance Levels

| Level | Meaning |
|-------|---------|
| Critical | Regression or data loss — blocks release |
| High | Severe issue: crashes, deadlocks, corruption |
| Medium | Default — typical bugs |
| Low | Edge cases, trivial workarounds available |
| Wishlist | Feature requests, minor improvements |
| Undecided | Not yet triaged (default) |

## Configuration Option Patterns

When checking for configuration issues, Nova config options are registered in `nova/conf/`:

- Each file registers options for a specific subsystem (e.g., `nova/conf/libvirt.py`, `nova/conf/scheduler.py`)
- Options use `oslo.config` patterns: `cfg.StrOpt`, `cfg.IntOpt`, `cfg.BoolOpt`, etc.
- Deprecated options are marked with `deprecated_opts` or `deprecated_for_removal`
- Group names match config file sections (e.g., `[libvirt]`, `[scheduler]`, `[api]`)

## Common "Not a Bug" Patterns

These patterns frequently indicate invalid reports:

1. **Quota exceeded**: Reporter hits quota limits and assumes it's a bug
2. **Policy denial**: RBAC policy blocks the action — not a code bug
3. **Placement resource mismatch**: Inventory doesn't match what reporter expects — usually a configuration or provider tree issue
4. **Deprecated behavior**: Feature was intentionally removed or changed in a newer release
5. **Third-party driver issue**: Bug in a vendor driver, not in Nova core
6. **Missing service**: Reporter hasn't started a required service (e.g., nova-conductor, placement)
7. **Database not migrated**: Schema mismatch after upgrade without running migrations

## References

- Nova contributor guide: `doc/source/contributor/`
- Code review guidelines: `doc/source/contributor/code-review.rst`
- Bug triage guide: https://wiki.openstack.org/wiki/BugTriage
- Launchpad API: https://api.launchpad.net/1.0/
