# Investing AI Skills

**Local finance, investing and market-data knowledge for Codex and Claude Code.**

**35 project-local Skills:** 34 specialists and 1 default coordinator.

## Start here — Finance Skill Router

The **`finance-skill-router`** is your entry point for questions that need several finance Skills. You can name it explicitly, or ask a relevant question normally: repository instructions direct the agent to apply the coordinator workflow.

| Codex | Claude Code |
|---|---|
| `$finance-skill-router` | `/finance-skill-router` |

**Copy-ready example for Codex:**

```text
$finance-skill-router Analyze my portfolio, identify major risks, and suggest a realistic rebalancing plan.
```

**Copy-ready example for Claude Code:**

```text
/finance-skill-router Compare two investment strategies, expected returns, costs, liquidity and downside scenarios.
```

**Automatic selection (without the command):**

```text
Analyze a company valuation using financial statements, compare it with industry peers, and evaluate the portfolio risks.
```

The coordinator should read the applicable specialist files and combine their methods. Actual native Skill registration depends on your agent version and local discovery settings. **The router is not a separate AI model, and it cannot guarantee that a relevant Skill is always selected.**

## Clone this repository (Windows 11)

**Requirements:** Git installed and a Git-hosted copy of this repository. Replace the example URL with your actual repository HTTPS or SSH URL. If you only have this ZIP, publish the files to a Git repository first; an archive by itself is not a remote Git repository.

**PowerShell:**

```powershell
git --version
New-Item -ItemType Directory -Force "C:\Code\Projects" | Out-Null
Set-Location "C:\Code\Projects"
git clone https://github.com/YOUR_USERNAME/investing-ai-skills.git
Set-Location "investing-ai-skills"
```

**Connect the local Claude Code Skill directory (once per clone on Windows):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-skills.ps1
```

This creates a local `.claude/skills` junction pointing to `.agents/skills`. It is ignored by Git and needs to be recreated on another Windows machine. **The setup script does not delete an existing directory or overwrite an existing link.** If it reports an occupied path, inspect that path before moving or removing anything.

**Open this folder in Codex Desktop or Claude Code** and start a new conversation. To check the library, ask the agent to list discovered project Skills, and try the coordinator command above. If Claude does not register commands through a junction in your version, the same files remain readable at `.agents/skills/<name>/SKILL.md` through `CLAUDE.md`.

**Update an existing clone:**

```powershell
git pull
```

**After updates:** restart the agent session if new or modified Skills do not appear. The junction normally only needs to be created once per clone.

## Direct specialist invocation

| Agent | Pattern | Example |
|---|---|---|
| Codex | `$skill-name` | `$stock-analysis Review this company’s valuation.` |
| Claude Code | `/skill-name` | `/stock-analysis Review this company’s valuation.` |

The `name` is defined in the YAML header of each `SKILL.md`. Use the name exactly as shown in the sections below. These are examples of invoking registered skills, not guaranteed command support on every installation.

## Prompt examples — copy and paste

You do **not** need to know which specialist to choose. Start with the finance coordinator for broad requests, or invoke a specialist directly.

**Codex — ask the coordinator:**

```text
$finance-skill-router Review my investment portfolio, identify concentration and liquidity risks, and recommend the relevant analyses.
```

**Claude Code — ask the coordinator:**

```text
/finance-skill-router Compare an index-fund portfolio with dividend investing, including fees, taxes, liquidity and downside risks.
```

**Codex — use an individual specialist:**

```text
$stock-analysis Evaluate a company's competitive position, financial health and valuation using its latest published financial statements.
```

**Claude Code — use an individual specialist:**

```text
/financial-modeling Outline a five-year three-statement model with a DCF and sensitivity analysis for the key assumptions.
```

## Skill catalog — 70 ready-to-use specialist prompts

**How to find examples:** Expand **one category** below. Every Skill in that category is visible immediately, with its purpose, use cases and two copy-ready prompt examples. No second expansion is needed.

<details>
<summary><strong>Default Coordinator (1) — prompts and usage</strong></summary>

### `finance-skill-router` — Choose the right finance specialist Skills

**Purpose:** Route finance and investment questions to the appropriate specialists and synthesize an integrated answer.

**What you can do:** Coordinate cross-domain analysis, select relevant methods, reconcile assumptions and report uncertainties.

**Example prompts — copy and paste:**

**Codex**

```text
$finance-skill-router Compare long-term portfolio allocation with a startup investment and evaluate liquidity risks.
```

**Claude Code**

```text
/finance-skill-router Assess how a property investment affects my broader financial plan.
```

<sub>File: `.agents/skills/finance-skill-router/SKILL.md`</sub>

---

</details>

<details>
<summary><strong>Banking & Professional Finance (11) — prompts and usage</strong></summary>

### `commodities-trading` — Evaluate commodity exposures, futures curves, physical market fundamentals, and hedge design.

**Purpose:** Evaluate commodity exposures, futures curves, physical market fundamentals, and hedge design.

**What you can do:** Compare forward curves, analyze basis, design hedge ratios, and stress-test commodity positions.

**Example prompts — copy and paste:**

**Codex**

```text
$commodities-trading Compare a producer’s hedge using short futures versus put options over the next six months.
```

**Claude Code**

```text
/commodities-trading Explain the contango/backwardation implications for rolling an oil futures position.
```

<sub>File: `.agents/skills/commodities-trading/SKILL.md`</sub>

---

### `credit-analysis` — Assess creditworthiness, repayment capacity, covenants, and expected downside for a borrower or bond.

**Purpose:** Assess creditworthiness, repayment capacity, covenants, and expected downside for a borrower or bond.

**What you can do:** Build credit scorecards, assess leverage, analyze distress scenarios, and draft lending recommendations.

**Example prompts — copy and paste:**

**Codex**

```text
$credit-analysis Evaluate a borrower with declining margins and a large maturity next year.
```

**Claude Code**

```text
/credit-analysis Construct a credit risk memo comparing two corporate bond issuers with equal yields.
```

<sub>File: `.agents/skills/credit-analysis/SKILL.md`</sub>

---

### `financial-modeling` — Create auditable models for forecasting, valuation, transactions, and scenario analysis.

**Purpose:** Create auditable models for forecasting, valuation, transactions, and scenario analysis.

**What you can do:** Design integrated three-statement forecasts, DCF valuations, LBO cases, and sensitivity tables.

**Example prompts — copy and paste:**

**Codex**

```text
$financial-modeling Build an outline for a five-year three-statement forecast and DCF for a subscription business.
```

**Claude Code**

```text
/financial-modeling Review my LBO model assumptions and design a sensitivity table for IRR and MOIC.
```

<sub>File: `.agents/skills/financial-modeling/SKILL.md`</sub>

---

### `fintech-product` — Design regulated financial products with sound unit economics, operational controls, and customer outcomes.

**Purpose:** Design regulated financial products with sound unit economics, operational controls, and customer outcomes.

**What you can do:** Scope fintech MVPs, evaluate payment flows, design lending journeys, and map regulatory dependencies.

**Example prompts — copy and paste:**

**Codex**

```text
$fintech-product Design a cross-border payment MVP and map settlement, FX, fraud, and compliance dependencies.
```

**Claude Code**

```text
/fintech-product Review a buy-now-pay-later onboarding funnel and suggest safer eligibility and disclosure checks.
```

<sub>File: `.agents/skills/fintech-product/SKILL.md`</sub>

---

### `forex-trading` — Analyze FX exposure, currency drivers, position sizing, and execution risk.

**Purpose:** Analyze FX exposure, currency drivers, position sizing, and execution risk.

**What you can do:** Compare currency pairs, evaluate carry and macro scenarios, and design FX hedges.

**Example prompts — copy and paste:**

**Codex**

```text
$forex-trading Assess EUR/USD exposure for an exporter receiving revenue in six months.
```

**Claude Code**

```text
/forex-trading Compare a forward hedge and an FX option for a USD liability with uncertain timing.
```

<sub>File: `.agents/skills/forex-trading/SKILL.md`</sub>

---

### `hedge-fund-strategies` — Evaluate institutional alternative strategies, exposure, leverage and risk

**Purpose:** Evaluate institutional alternative strategies, exposure, leverage and risk.

**What you can do:** Compare long/short, macro, CTA and relative-value approaches; analyze factor bets, financing, performance attribution and drawdowns.

**Example prompts — copy and paste:**

**Codex**

```text
$hedge-fund-strategies Compare the factor and leverage exposures of a market-neutral equity strategy and a global macro strategy.
```

**Claude Code**

```text
/hedge-fund-strategies Build an institutional risk memo for a merger-arbitrage portfolio under a widening-spread stress scenario.
```

<sub>File: `.agents/skills/hedge-fund-strategies/SKILL.md`</sub>

---

### `insurance-underwriting` — Evaluate insured exposures, pricing adequacy, terms, and accumulated portfolio risk.

**Purpose:** Evaluate insured exposures, pricing adequacy, terms, and accumulated portfolio risk.

**What you can do:** Structure underwriting reviews, loss-cost analysis, reinsurance needs, and coverage exclusions.

**Example prompts — copy and paste:**

**Codex**

```text
$insurance-underwriting Outline an underwriting memo for a small commercial property portfolio exposed to flood risk.
```

**Claude Code**

```text
/insurance-underwriting Compare a higher deductible with increased premium for a specialty insurance policy.
```

<sub>File: `.agents/skills/insurance-underwriting/SKILL.md`</sub>

---

### `investment-banking` — Assess M&A transactions, deal structure, valuation and financing

**Purpose:** Assess M&A transactions, deal structure, valuation and financing.

**What you can do:** Plan buy-side or sell-side M&A, compare valuation approaches, model accretion/dilution and identify diligence gaps.

**Example prompts — copy and paste:**

**Codex**

```text
$investment-banking Build a sell-side M&A process outline and valuation framework for a software company.
```

**Claude Code**

```text
/investment-banking Compare two acquisition offers with different cash, stock, earnout and financing terms.
```

<sub>File: `.agents/skills/investment-banking/SKILL.md`</sub>

---

### `private-equity` — Evaluate acquisition opportunities, leveraged returns, portfolio-company improvements, and exits.

**Purpose:** Evaluate acquisition opportunities, leveraged returns, portfolio-company improvements, and exits.

**What you can do:** Run diligence frameworks, LBO sensitivities, debt analyses, and value-creation plans.

**Example prompts — copy and paste:**

**Codex**

```text
$private-equity Review a buyout at 8× EBITDA with 50% debt financing and model five-year outcomes.
```

**Claude Code**

```text
/private-equity Create a 100-day plan and measurable value-creation roadmap for an acquired services company.
```

<sub>File: `.agents/skills/private-equity/SKILL.md`</sub>

---

### `venture-capital` — Assess early-stage ventures, financing terms, follow-on decisions, and portfolio construction.

**Purpose:** Assess early-stage ventures, financing terms, follow-on decisions, and portfolio construction.

**What you can do:** Screen startups, analyze term sheets, model dilution and runway, and plan investment committee decisions.

**Example prompts — copy and paste:**

**Codex**

```text
$venture-capital Evaluate a seed-stage B2B SaaS startup with $40k MRR and 8% monthly churn.
```

**Claude Code**

```text
/venture-capital Explain how a SAFE with a valuation cap affects ownership at a Series A financing.
```

<sub>File: `.agents/skills/venture-capital/SKILL.md`</sub>

---

### `wealth-management` — Integrate investment allocation, liquidity, risk, and long-term financial objectives.

**Purpose:** Integrate investment allocation, liquidity, risk, and long-term financial objectives.

**What you can do:** Develop investment policy statements, allocation reviews, withdrawal plans, and family wealth scenarios.

**Example prompts — copy and paste:**

**Codex**

```text
$wealth-management Draft an investment policy statement for a diversified portfolio with a 15-year spending horizon.
```

**Claude Code**

```text
/wealth-management Compare 60/40 and 80/20 portfolios for an investor with a large near-term cash requirement.
```

<sub>File: `.agents/skills/wealth-management/SKILL.md`</sub>

---

</details>

<details>
<summary><strong>Investing & Wealth Management (13) — prompts and usage</strong></summary>

### `angel-investing` — Assess direct startup investments and manage small, highly illiquid early-stage portfolios.

**Purpose:** Assess direct startup investments and manage small, highly illiquid early-stage portfolios.

**What you can do:** Screen founders, assess deal terms, model dilution, and define portfolio reserves.

**Example prompts — copy and paste:**

**Codex**

```text
$angel-investing Build an angel due diligence checklist for a pre-revenue B2B startup.
```

**Claude Code**

```text
/angel-investing Compare two SAFE opportunities with different caps and expected dilution.
```

<sub>File: `.agents/skills/angel-investing/SKILL.md`</sub>

---

### `crypto-investing` — Evaluate digital-asset allocations within an investment portfolio using explicit risk controls.

**Purpose:** Evaluate digital-asset allocations within an investment portfolio using explicit risk controls.

**What you can do:** Compare token exposures, custody options, portfolio sizing, and crypto-specific downside scenarios.

**Example prompts — copy and paste:**

**Codex**

```text
$crypto-investing Assess a 5% Bitcoin allocation against my existing equity and cash portfolio.
```

**Claude Code**

```text
/crypto-investing Compare custody, liquidity and counterparty risks of holding crypto on an exchange versus self-custody.
```

<sub>File: `.agents/skills/crypto-investing/SKILL.md`</sub>

---

### `dividend-investing` — Evaluate dividend sustainability and total-return tradeoffs for income portfolios.

**Purpose:** Evaluate dividend sustainability and total-return tradeoffs for income portfolios.

**What you can do:** Screen dividend stocks, examine payout coverage, and model income and capital-risk scenarios.

**Example prompts — copy and paste:**

**Codex**

```text
$dividend-investing Evaluate whether a 7% dividend yield is sustainable from a company’s cash flows.
```

**Claude Code**

```text
/dividend-investing Design an income portfolio screening checklist that avoids yield traps.
```

<sub>File: `.agents/skills/dividend-investing/SKILL.md`</sub>

---

### `estate-planning` — Organize wealth-transfer decisions, beneficiaries, liquidity needs, and estate-planning risks.

**Purpose:** Organize wealth-transfer decisions, beneficiaries, liquidity needs, and estate-planning risks.

**What you can do:** Create estate inventories, beneficiary review checklists, and scenarios for inheritance or incapacity.

**Example prompts — copy and paste:**

**Codex**

```text
$estate-planning Make an estate-planning checklist for a family with a small business and two properties.
```

**Claude Code**

```text
/estate-planning Identify common conflicts between wills, account beneficiaries, and joint ownership.
```

<sub>File: `.agents/skills/estate-planning/SKILL.md`</sub>

---

### `financial-independence` — Model pathways to financial independence using realistic spending, saving, and uncertainty assumptions.

**Purpose:** Model pathways to financial independence using realistic spending, saving, and uncertainty assumptions.

**What you can do:** Calculate savings targets, withdrawal scenarios, coast-FI, and sensitivity to inflation or return assumptions.

**Example prompts — copy and paste:**

**Codex**

```text
$financial-independence Estimate FI targets at three spending levels with different withdrawal assumptions.
```

**Claude Code**

```text
/financial-independence Stress-test an early retirement plan against a 30% market decline in year one.
```

<sub>File: `.agents/skills/financial-independence/SKILL.md`</sub>

---

### `financial-planning` — Personal financial plans, budgeting, emergency funds, debt, goals, insurance, and financial well-being

**Purpose:** Personal financial plans, budgeting, emergency funds, debt, goals, insurance, and financial well-being.

**What you can do:** Build household budgets, prioritize debt, set savings targets and plan for long-term goals.

**Example prompts — copy and paste:**

**Codex**

```text
$financial-planning Build a financial plan for a household with variable monthly income and three savings goals.
```

**Claude Code**

```text
/financial-planning Create a twelve-month plan to pay down high-interest debt while building an emergency fund.
```

<sub>File: `.agents/skills/financial-planning/SKILL.md`</sub>

---

### `index-fund-investing` — Evaluate diversified, low-cost passive portfolios and implementation choices.

**Purpose:** Evaluate diversified, low-cost passive portfolios and implementation choices.

**What you can do:** Compare benchmark exposure, index construction, fund costs, tracking error, and rebalancing.

**Example prompts — copy and paste:**

**Codex**

```text
$index-fund-investing Compare two global equity ETFs with different domicile, expense ratios, and index coverage.
```

**Claude Code**

```text
/index-fund-investing Design a low-maintenance two-fund portfolio and explain how to rebalance it.
```

<sub>File: `.agents/skills/index-fund-investing/SKILL.md`</sub>

---

### `options-trading` — Analyze listed options strategies, payoff structures, Greeks, and margin risks.

**Purpose:** Analyze listed options strategies, payoff structures, Greeks, and margin risks.

**What you can do:** Compare option spreads, hedges, scenario payoffs, and sensitivity to volatility or time.

**Example prompts — copy and paste:**

**Codex**

```text
$options-trading Compare a protective put with a collar for a concentrated equity position.
```

**Claude Code**

```text
/options-trading Explain delta and vega risks of an iron condor before an earnings announcement.
```

<sub>File: `.agents/skills/options-trading/SKILL.md`</sub>

---

### `real-estate-investing` — Evaluate property cash flows, financing, valuation, and downside risk.

**Purpose:** Evaluate property cash flows, financing, valuation, and downside risk.

**What you can do:** Analyze rental properties, cap rates, debt service, renovation assumptions, and exit scenarios.

**Example prompts — copy and paste:**

**Codex**

```text
$real-estate-investing Analyze a duplex with $3,000 monthly gross rent and a 25% down payment.
```

**Claude Code**

```text
/real-estate-investing Build a downside case for a rental property with vacancy and unexpected roof replacement.
```

<sub>File: `.agents/skills/real-estate-investing/SKILL.md`</sub>

---

### `retirement-planning` — Plan sustainable retirement income, allocation, and drawdown management.

**Purpose:** Plan sustainable retirement income, allocation, and drawdown management.

**What you can do:** Compare withdrawal strategies, cash buffers, pension timing, and longevity stress tests.

**Example prompts — copy and paste:**

**Codex**

```text
$retirement-planning Compare constant and guardrail withdrawals for a 30-year retirement horizon.
```

**Claude Code**

```text
/retirement-planning Stress-test retirement cash flows with an inflation spike and weak early portfolio returns.
```

<sub>File: `.agents/skills/retirement-planning/SKILL.md`</sub>

---

### `startup-fundraising` — Plan startup funding rounds, investor readiness, dilution, and transaction process.

**Purpose:** Plan startup funding rounds, investor readiness, dilution, and transaction process.

**What you can do:** Build financing narratives, data-room checklists, round models, and investor process plans.

**Example prompts — copy and paste:**

**Codex**

```text
$startup-fundraising Outline a seed pitch and use-of-funds plan for a SaaS startup with nine months runway.
```

**Claude Code**

```text
/startup-fundraising Compare two term sheets with different option pool and liquidation preference terms.
```

<sub>File: `.agents/skills/startup-fundraising/SKILL.md`</sub>

---

### `stock-analysis` — Bottom-up equity research, financial-statement analysis, valuation, moats, and stock investment theses

**Purpose:** Bottom-up equity research, financial-statement analysis, valuation, moats, and stock investment theses.

**What you can do:** Evaluate a company, compare its peers, examine business quality, value shares and identify investment risks.

**Example prompts — copy and paste:**

**Codex**

```text
$stock-analysis Analyze a listed company using its last three annual reports and build a valuation range.
```

**Claude Code**

```text
/stock-analysis Assess the competitive moat, capital allocation and financial red flags for this stock.
```

<sub>File: `.agents/skills/stock-analysis/SKILL.md`</sub>

---

### `stock-investing` — Evaluate public equities using business fundamentals, valuation, risk, and portfolio fit.

**Purpose:** Evaluate public equities using business fundamentals, valuation, risk, and portfolio fit.

**What you can do:** Construct company theses, compare valuation methods, and analyze competitive and financial risks.

**Example prompts — copy and paste:**

**Codex**

```text
$stock-investing Build an investment thesis for an industrial company with declining margins.
```

**Claude Code**

```text
/stock-investing Compare two banks using valuation, credit quality, and interest-rate risk.
```

<sub>File: `.agents/skills/stock-investing/SKILL.md`</sub>

---

</details>

<details>
<summary><strong>Market Data Engineering (10) — prompts and usage</strong></summary>

### `backtest-data-pipelines` — Build leakage-resistant research datasets from raw market records.

**Purpose:** Build leakage-resistant research datasets from raw market records.

**What you can do:** Plan point-in-time feature pipelines, align market series, and make backtests reproducible.

**Example prompts — copy and paste:**

**Codex**

```text
$backtest-data-pipelines Design a tick-to-feature pipeline that prevents look-ahead leakage in a 1-minute equity backtest.
```

**Claude Code**

```text
/backtest-data-pipelines Create a dataset manifest and validation tests for daily multi-asset backtests.
```

<sub>File: `.agents/skills/backtest-data-pipelines/SKILL.md`</sub>

---

### `corporate-actions-and-price-adjustment` — Handle dividends, splits, spin-offs, symbol changes, and continuous contracts in research price series.

**Purpose:** Handle dividends, splits, spin-offs, symbol changes, and continuous contracts in research price series.

**What you can do:** Design adjustment factors, total-return series, corporate-action event tables, and futures rolls.

**Example prompts — copy and paste:**

**Codex**

```text
$corporate-actions-and-price-adjustment Explain how to adjust historical prices after a 4-for-1 split and a cash dividend.
```

**Claude Code**

```text
/corporate-actions-and-price-adjustment Design a continuous futures dataset with an explicit rollover and adjustment convention.
```

<sub>File: `.agents/skills/corporate-actions-and-price-adjustment/SKILL.md`</sub>

---

### `market-data-quality-checks` — Detect unreliable market feeds and prevent bad data from contaminating research or live trading.

**Purpose:** Detect unreliable market feeds and prevent bad data from contaminating research or live trading.

**What you can do:** Design QA rules for ticks, order books, bars, timestamps, and vendor anomalies.

**Example prompts — copy and paste:**

**Codex**

```text
$market-data-quality-checks Build validation checks for a mixed crypto trade and L2 order-book feed.
```

**Claude Code**

```text
/market-data-quality-checks Investigate OHLCV bars containing zero volume and extreme price jumps.
```

<sub>File: `.agents/skills/market-data-quality-checks/SKILL.md`</sub>

---

### `ohlcv-bar-construction` — Construct reproducible time, tick, volume, and dollar bars from raw trades.

**Purpose:** Construct reproducible time, tick, volume, and dollar bars from raw trades.

**What you can do:** Specify bar aggregation logic, timestamp conventions, partial intervals, and data QA.

**Example prompts — copy and paste:**

**Codex**

```text
$ohlcv-bar-construction Specify a deterministic 1-minute OHLCV builder from WebSocket trades.
```

**Claude Code**

```text
/ohlcv-bar-construction Compare time bars with dollar bars and explain when each distorts volatility estimates.
```

<sub>File: `.agents/skills/ohlcv-bar-construction/SKILL.md`</sub>

---

### `order-book-data` — Reconstruct, store, and analyze limit order books from snapshots and incremental feeds.

**Purpose:** Reconstruct, store, and analyze limit order books from snapshots and incremental feeds.

**What you can do:** Design L2/L3 book builders, detect sequence gaps, derive spread and depth features.

**Example prompts — copy and paste:**

**Codex**

```text
$order-book-data Design a robust Binance-style L2 book reconstructor from snapshot and incremental updates.
```

**Claude Code**

```text
/order-book-data Estimate execution slippage for a hypothetical market buy using a given book snapshot.
```

<sub>File: `.agents/skills/order-book-data/SKILL.md`</sub>

---

### `point-in-time-data-and-survivorship-bias` — Prevent historical research from using securities, facts, or index membership learned only later.

**Purpose:** Prevent historical research from using securities, facts, or index membership learned only later.

**What you can do:** Build as-of joins, security masters, delisting handling, and survivor-free universe definitions.

**Example prompts — copy and paste:**

**Codex**

```text
$point-in-time-data-and-survivorship-bias Build a 2015 point-in-time S&P-style research universe without current-member bias.
```

**Claude Code**

```text
/point-in-time-data-and-survivorship-bias Explain why using revised fundamentals can overstate a factor strategy’s backtest.
```

<sub>File: `.agents/skills/point-in-time-data-and-survivorship-bias/SKILL.md`</sub>

---

### `streaming-market-data` — Operate reliable near-real-time market-data ingestion and downstream distribution.

**Purpose:** Operate reliable near-real-time market-data ingestion and downstream distribution.

**What you can do:** Architect WebSocket/TCP feed handlers, reconnect/replay logic, and resilient event pipelines.

**Example prompts — copy and paste:**

**Codex**

```text
$streaming-market-data Design an event-driven service that consumes trades and books from three exchanges.
```

**Claude Code**

```text
/streaming-market-data Create an incident runbook for stale WebSocket feeds and repeated sequence gaps.
```

<sub>File: `.agents/skills/streaming-market-data/SKILL.md`</sub>

---

### `tick-data-ingestion` — Collect and normalize fine-grained market trades and quotes without losing provenance.

**Purpose:** Collect and normalize fine-grained market trades and quotes without losing provenance.

**What you can do:** Define tick schemas, timestamp capture, deduplication, correction handling, and ingestion QA.

**Example prompts — copy and paste:**

**Codex**

```text
$tick-data-ingestion Plan a resumable pipeline for tick data files covering 500 symbols.
```

**Claude Code**

```text
/tick-data-ingestion Define a normalized trade schema suitable for equities, futures, and crypto venues.
```

<sub>File: `.agents/skills/tick-data-ingestion/SKILL.md`</sub>

---

### `tick-data-storage-and-formats` — Choose cost-effective storage layouts for high-volume market ticks and books.

**Purpose:** Choose cost-effective storage layouts for high-volume market ticks and books.

**What you can do:** Compare Parquet, Arrow, row stores, partitioning, compression, and query performance.

**Example prompts — copy and paste:**

**Codex**

```text
$tick-data-storage-and-formats Recommend a Parquet layout for two years of crypto trade and quote data.
```

**Claude Code**

```text
/tick-data-storage-and-formats Compare ClickHouse and Parquet/DuckDB for intraday feature research workloads.
```

<sub>File: `.agents/skills/tick-data-storage-and-formats/SKILL.md`</sub>

---

### `trading-calendars-and-timezones` — Apply correct market-session, holiday, daylight-saving, and contract timing rules.

**Purpose:** Apply correct market-session, holiday, daylight-saving, and contract timing rules.

**What you can do:** Build exchange calendars, align cross-market data, and prevent timestamp look-ahead.

**Example prompts — copy and paste:**

**Codex**

```text
$trading-calendars-and-timezones Design a market calendar for US equities and crypto data alignment across DST changes.
```

**Claude Code**

```text
/trading-calendars-and-timezones Explain how to handle overnight futures sessions without mislabeling daily bars.
```

<sub>File: `.agents/skills/trading-calendars-and-timezones/SKILL.md`</sub>

---

</details>

## Notes

These Skills provide analytical frameworks, not guarantees of return or professional credentials. Verify market data, securities terms, tax treatment, legal restrictions and API details using authoritative up-to-date information where available.

<sub><i>Initial skill topics and summaries were sourced from [SkillDB](https://skilldb.dev/). The content in this repository has been edited and supplemented independently.</i></sub>
