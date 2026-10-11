# ADR-0012: Platform dev and incubation first — retire the by-hand admission rule

- **Status:** Accepted
- **Date:** 2026-10-11

## Context

[ADR-0009](./0009-barebones-reset.md) backed everything above Talos +
Kubernetes + Cilium out of the cluster and framed the homelab as
pedagogical: its value was the operator understanding every layer, so a
layer returns only if it is picked, installed, and explained by hand.
The rule answered a real failure. An agent installed a large surface in
a four-day burst (2026-05-10 to 2026-05-14); the preview surface and
ARC pools carried no real traffic in 90 days, Longhorn's only consumers
were observability and Harbor, and Harbor sat Degraded for days
unnoticed.

The homelab now has a second purpose. `RaptGroup/platform` will run
production on a shared zonal GKE Standard cluster (decided 2026-10-11)
and wants `rockingham` as its dev and incubation environment: ephemeral
environments per developer or per change (`RaptGroup/platform#1`). A
product instance has to run unchanged on both clusters, so the
primitives it relies on must exist on both. #258 inventories the gaps,
and most of the bridges are layers ADR-0009 backed out.

The by-hand rule blocks that purpose. The files an agent reads first
(`CLAUDE.md`, `ARCHITECTURE.md`) say installing by hand is the
admission price, so an agent asked to set up Argo CD, certificate
issuance, or a storage layer asks the operator to install it instead of
doing it. The operator cannot work that way.

The rule also misread its own cause. What went wrong in May was not that
an agent did the installing; it was layers with no owner, no consumer,
and no health signal. Installing by hand was a proxy for those: a human
who typed the commands at least knew the layer existed. It is a weak
proxy. A hand-installed layer can still have no consumer and no health
signal, and an agent-installed one can have both.

## Decision

**The Rockingham Homelab is first the dev and incubation environment for
the RaptGroup platform. Learning is a benefit of running it, not the
criterion for what runs on it.** Concretely:

1. **Purpose.** A layer belongs on `rockingham` because something the
   platform needs runs on it or is proven on it. The pedagogical frame
   in ADR-0009's Context is superseded.
2. **Agents operate layers directly.** An agent may install, upgrade,
   and operate layers. Nothing in the repo asks the operator to install
   a layer by hand. How a layer above the floor is delivered (`kubectl`,
   `helm`, Terraform, or a returning Argo CD) is not decided here; each
   layer's own decision picks its lane.
3. **Admission test.** A layer above the floor is admitted when all
   three hold. This replaces ADR-0009's "pick it, install it, explain it
   by hand":

   - **Consumer.** An open platform issue or an accepted ADR names the
     workload that depends on it. "Might be useful" does not count.
     Checked at PR review.
   - **Declared.** Its install and config are in git, and
     `ARCHITECTURE.md` maps it to the file that configures it.
   - **Health signal.** Something fails visibly when it breaks: an alert
     once observability exists; until then a probe in `just smoke` or a
     documented command in the layer's README.

   A layer whose consumer is gone, or that shows no use for 90 days,
   gets an issue proposing its removal.

4. **The floor stays as a name, not a ceiling.** "The floor" remains the
   name for what `terraform/bootstrap/` installs on top of Talos and
   Kubernetes, with the contents ADR-0009 lists, unchanged. "Barebones"
   is retired as a goal; it names the 2026-08-09 reset and nothing else.
5. **The rest of ADR-0009 stands.** The floor's contents, the removals
   table, the surviving GCP skeleton, and the rejected alternatives all
   still describe the cluster. ADRs 0003 and 0005–0008 stay superseded
   by ADR-0009: a returning layer gets a new ADR rather than reviving
   the old one. This ADR admits none of them. Each returns, or does not,
   through the admission test.

## Consequences

**Positive**

- The work the platform needs stops being blocked on the operator. The
  bridges in #258 and a return of Argo CD (`RaptGroup/platform#1`)
  become ordinary work an agent can pick up.
- The repo's stated purpose matches how the lab is used. Agents no
  longer read guidance that tells them to do the opposite of what the
  operator needs.
- The failure ADR-0009 recorded is still addressed, by the admission
  test, not by who types the install command.
- Learning is not forbidden: the operator can still build a layer by
  hand when that is the point.

**Negative / ongoing**

- The proxy is gone. Under ADR-0009 the by-hand step forced a human to
  touch every layer. Now an agent can add a layer the operator never
  touched, so the May burst can happen again; the admission test and
  review are the only defense.
- An agent holding a kubeconfig or `tofu` credentials can change the
  cluster. This ADR changes neither the harness permission modes nor PR
  review, and leans on both.
- ADR-0009's roughly $0 steady-state ends as layers return. Each
  addon's cost is judged when it is admitted.
- Documents that repeat the old rule must be rewritten: `CLAUDE.md`,
  `ARCHITECTURE.md` (the delivery table, "Adding a layer"), the
  `CONTEXT.md` reset banner, and the "current frame" labels in the ADR
  index and docs site. #258 says "the ADR-0009 rule stays", which this
  ADR overtakes.
- ADR-0011 is not amended. Its rejection of a builder on the cluster
  rested partly on the floor staying minimal; that reasoning is now
  historical, and the question reopens only if a cluster builder gets a
  consumer.

## Alternatives Considered

### Delete the rule outright, with no replacement

Rejected. The May failure was real, and agent speed makes it cheaper to
repeat. With GKE parity as the purpose, each layer should have a reason
to exist beyond "it was easy to install". The replacement is a test on
what the layer is for, not on who installs it.

### Keep the rule, with a carve-out for layers the platform needs

Rejected. #258 says most bridges are the layers the rule blocks, so the
exception would be the norm, and the guidance would still name learning
as the admission criterion for everything else. "The platform needs it"
is already a consumer test; this option applies it without saying so.

### Keep the rule and have the operator install each bridge by hand

Rejected. The operator cannot work that way, and that is the problem
this ADR exists to solve. The rule's cost now falls on the purpose it
blocks.

### Make learning and the platform co-equal purposes

Rejected. Admission is where the two conflict, and a conflict needs a
tie-breaker. The platform wins it, because a concrete consumer is what
the May layers lacked. Learning stays a benefit.
