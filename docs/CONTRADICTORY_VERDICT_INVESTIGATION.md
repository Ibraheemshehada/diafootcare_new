# Investigation — the result screen showed two opposite verdicts at once

**Reported:** 2026-08-06, from a real run on device.
**Severity:** high. Not a cosmetic bug — the screen made two contradictory clinical claims
about the same wound, and the patient had no way to know which to believe.

---

## 1. What was seen

One screen, one wound, one analysis:

| Position | Component | Verdict |
|---|---|---|
| Top | `_RiskBadge` | 🟠 **«عدوى مُكتشفة»** — *Infection detected* |
| Bottom | `_TriageCard` | 🟢 **«لا توجد علامات على وجود عدوى»** — *No signs of infection* |

The patient had answered **"No" to all five** checklist questions.

---

## 2. Root cause — two independent judges, never reconciled

The two components do not share a decision. They each derive their own answer from a different
input, using a different rule:

```
                    P(infection) from Model 3
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
   ai_service._runInfection()        infection_triage.triage()
   single cut-off: p >= 0.41         three zones: <0.30 / 0.30–0.80 / >0.80
   ignores the checklist             + IWGDF/IDSA sign counting
              │                               │
              ▼                               ▼
        result.riskBadge                 TriageResult
              │                               │
              ▼                               ▼
         _RiskBadge  ← TOP            _TriageCard  ← BOTTOM
```

**This is my error, introduced in C4/C7.** The triage was added as a *new* card, and the
pre-existing `_RiskBadge` was left untouched above it, still reading `result.riskBadge` —
the raw binary the triage was specifically built to replace. Two verdicts, no single source of
truth.

### Why they disagreed on this particular wound
`P(infection)` landed at roughly **0.41–0.80**:

- **Old rule:** `p >= 0.41` → `hasInfection = true` → badge **"Infection Detected"**.
- **Triage:** the same `p` sits in the **uncertain** band, and the patient reported **zero**
  signs, so IWGDF's "purulent discharge, or ≥2 signs" is not met → **no signs**.

Both components behaved exactly as written. The fault is that both were on screen.

> The disagreement is not noise — it *is* the finding that motivated the triage in the first
> place. At clinic prevalence the 0.41 cut-off has **PPV 0.45**: it is wrong more often than
> right. The badge was showing precisely the false alarm the triage exists to suppress.

---

## 3. Fix — one source of truth, and say what the badge means

1. **The badge derives from the triage outcome**, not from the raw binary. The threshold-only
   path stops driving anything the patient reads.
2. **The badge states the evidence**, as the clinician asked:
   «عدوى مُكتشفة (وجود علامات التهاب)» — *Infection detected (signs of inflammation present)* —
   rather than an unqualified verdict.
3. **The action is explicit and matched to severity**: for a clinician-level outcome the screen
   says to attend the nearest health centre; for the urgent outcome it says not to wait.

`result.riskBadge` is **kept** in the record and in sync: the server and the dashboard rely on
it, and it remains an honest description of what Model 3 alone reported. It simply no longer
speaks directly to the patient without the checklist beside it.

---

## 4. Wider lesson

Adding a better answer beside a worse one does not remove the worse one. When a component is
built to *replace* a judgement, every existing surface of that judgement has to be traced and
re-pointed in the same change — otherwise the app contradicts itself and the patient arbitrates.

**Check before shipping any new verdict UI:** search for every reader of the field being
superseded (here: `riskBadge`, `result.infection`) and decide, for each, whether it is a record
(keep) or something a patient reads (re-point).
