# Single SQLite writer is guaranteed by the deployment, not by the code

`db::connect` caps the SeaORM pool at one connection (`min_connections(1)`, `max_connections(1)`) to
serialize SQLite access. That is sufficient only because exactly one process ever opens the database
file, and nothing in this repository enforces that.

The guarantee lives in the deployment manifest, in a different repository (`home-infra`,
`infra/gym.yaml`): `replicas: 1`, `strategy: type: Recreate`, and a `hostPath` volume at
`/home/nk/services/gym/data` on node `home.lan` with a matching `nodeSelector`. `Recreate` is the
load-bearing part — Kubernetes defaults to `RollingUpdate`, which briefly runs the old and new pod
simultaneously. Two processes against one SQLite file on one volume means two writers, and if it
happened during a schema change it would mean two concurrent migration runs.

Recorded here because a reader of this repository sees a pool capped at 1 and reasonably concludes
the code handles concurrency. It does not; it assumes single-process, and that assumption is
satisfied somewhere they cannot see. Raising `max_connections` or switching the Deployment to
`RollingUpdate` are each individually sufficient to corrupt the database.

If the deployment ever needs to become concurrent, the pool cap is not the thing to change first —
the migration runner would need a `BEGIN IMMEDIATE` lock so a losing process fails fast instead of
interleaving DDL.
