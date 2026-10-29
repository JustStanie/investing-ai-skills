---
name: credit-analysis
description: "Use this skill to assess creditworthiness, repayment capacity, covenants, and expected downside for a borrower or bond. Also use when asked to build credit scorecards, assess leverage, analyze distress scenarios, and draft lending recommendations."
---

# Credit Analysis

## Purpose

Assess creditworthiness, repayment capacity, covenants, and expected downside for a borrower or bond. The goal is a clear, evidence-based analysis or workflow that fits the user's actual request, not a generic overview.

## When to use

Use this Skill when the user wants to build credit scorecards, assess leverage, analyze distress scenarios, and draft lending recommendations.

Do not force this Skill onto unrelated questions. Combine it with a complementary Skill only when that materially improves the answer.

## Working method

1. Identify the obligor, facility ranking, collateral, jurisdiction, maturity, guarantee support, and creditor claim in the capital structure.
2. Normalize financials and derive debt, net debt, EBITDA, interest coverage, free cash flow, and near-term liquidity sources and uses.
3. Map debt maturities and contingent obligations, including lease commitments, revolvers, letters of credit, and off-balance-sheet exposures.
4. Assess business risk, cash-flow volatility, industry structure, customer concentration, management quality, and governance.
5. Stress revenue, margins, rates, working capital, and refinancing access; calculate covenant headroom and liquidity runway.
6. Where requested, estimate probability of default, loss given default, and exposure at default, stating model calibration and uncertainty.
7. Summarize the risk rating, likely default triggers, mitigants, recovery assumptions, and monitoring thresholds.

## Domain checks and failure modes

- Do not confuse accounting profit with debt repayment ability.
- Identify whether a coverage ratio uses gross or net interest and whether debt definitions include leases.
- Treat recovery rates as uncertain and sensitive to security interests and jurisdiction.

## Evidence and data handling

- Identify the relevant period, currency, instrument, jurisdiction, and data as-of date whenever they materially affect the answer.
- Distinguish user-provided facts, externally verified inputs, and explicit scenario assumptions; never invent missing figures or sources.
- For time-sensitive market values, laws, platform rules, fees, or product features, verify with current authoritative information when available and say when verification was not possible.
- Quantify uncertainty and material downside, including costs, liquidity, operational constraints, and sensitivity to assumptions.
- If the task needs regulated legal, tax, underwriting, or investment advice, provide structured analytical help and identify matters requiring appropriately qualified local professionals.

## Answer format

For a substantial request, provide: (1) a direct conclusion or decision framing, (2) relevant evidence and assumptions, (3) the domain-specific analysis, (4) competing alternatives and risks, and (5) a practical next step or checklist. For a simple question, answer directly without forcing a report.

## Example prompts

- Evaluate a borrower with declining margins and a large maturity next year.
- Construct a credit risk memo comparing two corporate bond issuers with equal yields.
