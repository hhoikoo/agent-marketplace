# Leases

The lease ledger lives in your context: who holds what, since when, for how long, and the queue. Handle lease requests and releases yourself; never route them to a handler, which cannot update the ledger. Carry the ledger in every master handover.

## VMs

- VMs are a master-owned pool. Workers never create or delete them.
- Grant a lease with the isolation terms in [worker-rules.md](worker-rules.md) (own dir, ports, namespaces, DB/Redis instances; no shared-config edits; clean up). Queue conflicting requests.
- Respect the owner's quota: re-route a job to a VM without the contested capability before adding a VM.
- On release: check the worker cleaned up, then grant the next queued request.

## Hardware

- Only its dedicated specialist session touches real hardware.
- Owner-only actions (reboot, firmware, mode switch) stay with the owner.
- Hardware runs go out as numbered steps with stop conditions.
- Local patches made there are never pushed.
