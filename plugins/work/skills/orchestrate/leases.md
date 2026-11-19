# Leases

The lease ledger lives in your context: who holds what, since when, for how long, and the queue. Handle lease requests and releases yourself, because a handler cannot update the ledger. Carry the ledger in every master handover.

## VMs

- VMs are a pool the master owns. Workers do not create or delete them.
- Grant a lease with the isolation terms in [worker-rules.md](worker-rules.md) (own dir, ports, namespaces, DB/Redis instances; leave shared config alone; clean up). Queue conflicting requests.
- Respect the owner's quota: re-route a job to a VM without the contested capability before adding a VM.
- On release: check the worker cleaned up, then grant the next queued request.

## Hardware

- Only its dedicated specialist session touches real hardware.
- The owner performs owner-only actions (reboot, firmware, mode switch).
- Hardware runs go out as numbered steps with stop conditions.
- Local patches made there stay local.
