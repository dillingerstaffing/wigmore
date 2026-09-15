# SRE incident response: research brief (for the Wigmore example diagram)

Researched 2026-09-15 from primary sources: Google SRE book ch. 14 (Managing Incidents)
and ch. 15 (Postmortem Culture), SRE Workbook ch. 9 (Incident Response) and ch. 10
(Postmortem Culture), PagerDuty public incident-response docs, GitLab's published
2017 database postmortem.

## Incident lifecycle (Google SRE practice)
1. Detection: alert fires (pager on SLO burn rate, or human notices dashboards/reports).
   Concrete style: "checkout p99 latency above 800ms sustained for 10 minutes, paging checkout on-call."
   Real case: GKE CreateCluster, 6:41 a.m. PST, prober failures above 60% in two zones.
2. Triage/assessment: first responder verifies the alert is real, scopes impact (users, regions, functions).
3. Coordination: declare early ("better to declare and close on a simple fix than spin up hours into a
   growing problem"), open war room, assign IC/OL/CL, start the living incident document.
4. Mitigation: stop the bleeding with the bluntest tool (rollback, traffic shift, failover) BEFORE
   root cause is understood. Customers care about errors stopping, not about explanations.
5. Resolution: service back to previous condition; metrics green; soak period; IC declares complete
   after validating with on-calls.
6. Recovery verification: watch the SAME signals that detected the problem until they hold at baseline;
   confirm with synthetic black-box probers.
7. Postmortem: written, reviewed, circulated promptly (under a week), action items with owners.

Artifacts: the alert, living incident document (SRE book Appendix C template), chat log as raw timeline,
stakeholder updates, postmortem.

## Roles (IMAG, adapted from the fire service Incident Command System)
- Incident Commander: holds high-level state, delegates, coordinates/communicates/controls.
  Never touches production directly. Whoever declares typically becomes IC first.
- Operations Lead: the ONLY group that modifies the system during the incident. Reports to IC.
- Communications Lead: public face, periodic updates, manages inquiries. Folds into IC when small.
- Scribe: captures actions, owners, timestamps in-channel as an information ledger.
- Command transfer is explicit and verbal: brief, "You're now the incident commander, okay?",
  no leaving until firm acknowledgment, announced to everyone.

## Severity levels (PagerDuty, representative)
- SEV-1: critical, public notification, executive liaison. Large customer impact or data exposure.
- SEV-2: critical system issue actively impacting many customers' ability to use the product.
- SEV-2+ = "major incident", triggers full response process.
- SEV-3: stability/minor impact, service-owner top priority; rollback if tied to a recent deploy.
- Rule: classify higher when in doubt; downgrading is cheaper than under-responding.

## Detection doctrine
Alert on SYMPTOMS users feel, not causes. Page only when urgent, actionable, needs a human.
Construction: error-budget burn rate (fast burn pages, slow burn tickets). Cause-level signals
(CPU high, disk filling) go to dashboards/tickets, never pagers.

## Mitigation vs resolution
Mitigation needs only the LOCATION of the problem, not its explanation. Roll back correlated
releases, route around bad regions, fail over, flip feature flags. Build generic mitigation
tooling (one-click rollback, traffic drain) BEFORE incidents, not during.

## Blameless postmortem contents
Quantified impact from multiple perspectives; timeline; trigger vs root causes (system, never who);
recovery efforts (what worked, what didn't); went-well / went-poorly / got-lucky columns;
action items each with a single owner, priority, tracking number, verifiable end state.
"Blameless": assumes good intentions; naming people as causes makes engineers report late and
hide facts, which causes future incidents.

## End-to-end scenario for the chart: bad deploy, checkout latency
Setup: retailer checkout path (frontend -> checkout-api -> pricing-service, inventory-service ->
primary DB). SLO: checkout p99 < 500ms, success rate > 99%. Pager: p99 > 800ms for 10 min.

- 14:11 Detection: p99 at 1,150ms and climbing; success rate 99.4% -> 97.8%.
- 14:11-14:25 Triage: only build 4.7.2 pods (10% canary, deployed 14:02) show latency;
  build 4.7.1 pods at p99 180ms on same traffic. Declared SEV-2 at 14:25.
- H1 (correct): 4.7.2's "smart recommendations" module issues a synchronous per-line-item query
  (~45ms x ~6 items = ~270ms serial latency), saturating the checkout-api connection pool;
  requests queue, p99 climbs past 1s.
- H2 (plausible, wrong): pricing-service downstream slowdown (it had elevated p95 that morning).
- H2 killer: pricing-service p99 normal at 120ms during the window; canary split is decisive:
  same traffic, same dependencies, only the build differs (180ms vs 1,150ms).
- 14:31 Mitigation: rollback canary 4.7.2 -> 4.7.1; complete 14:38.
- 14:38-15:10 Verification: p99 < 200ms by 14:44, success 99.4% by 14:50, synthetic probers
  green 30 min. Resolved 15:10. Impact window ~42 min.
- Postmortem action items: canary analysis with auto-rollback (P1); CI query-count assertions
  (P1); move recommendations fetch async (P2); pool-saturation early-warning alert (P2).

Sources:
- https://sre.google/sre-book/managing-incidents/
- https://sre.google/sre-book/postmortem-culture/
- https://sre.google/workbook/incident-response/
- https://sre.google/workbook/postmortem-culture/
- https://sre.google/sre-book/practical-alerting/
- https://response.pagerduty.com/before/severity_levels/
- https://www.linux.com/news/postmortem-gitlab-database-outage-january-31/
