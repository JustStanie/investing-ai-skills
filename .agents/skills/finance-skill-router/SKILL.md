---
name: finance-skill-router
description: "Default coordinator for finance, investing, banking, portfolio planning, and market-data questions. Choose and combine the appropriate repository-local specialist Skills, then synthesize a clear, evidence-based answer."
---

# Finance Skill Router

## Purpose

For finance, banking, investing, and market-data questions, route the user's request to relevant specialist Skills in this repository. This is the default consultation workflow when the repository is open. It does not replace source verification or grant authority to take financial actions.

## Default Entry Point

This coordinator is the default workflow for repository-related financial questions because `AGENTS.md` and `CLAUDE.md` instruct the agent to read it. You can explicitly request it with `$finance-skill-router` in Codex or `/finance-skill-router` in Claude Code when registered. It must not make a false claim of automatic native invocation.

## Routing workflow

1. Identify the user's objective, domain, geography, time horizon, instrument type, and whether the request is conceptual, analytical, computational, or implementation-oriented.
2. Inspect the names and descriptions of available Skills in `.agents/skills/` (including recently added or deleted folders). Never assume a Skill exists without checking.
3. Read the complete `SKILL.md` of the one best-matched specialist before answering. Add up to two complementary Skills only if the task crosses domains and the extra methods are genuinely useful.
4. If the user invokes `$skill-name` or `/skill-name`, treat the requested Skill as the lead specialist when applicable. If no listed Skill matches, answer without inventing a Skill.
5. Coordinate compatible methods, explicitly separate any conflicting assumptions, and provide a single integrated answer rather than stitched-together reports.
6. For current prices, taxes, exchange rules, financial products, or legal requirements, use up-to-date authoritative verification when available and identify material uncertainty if not.
7. Never claim a Skill was read or applied if it was not. For regular short questions, keep the answer brief.

## Specialist routing guide

- **Banking & Professional Finance:** credit, investment banking, PE, VC, insurance, fintech product design, FX and commodity exposures, modeling, or institutional strategies.
- **Investing & Wealth Management:** personal financial planning, portfolio allocation, stock analysis, public equities, indexing, dividends, options, retirement, financial independence, real estate, estate issues, crypto holdings, startup funding, or angel investments.
- **Market Data Engineering:** tick feeds, order books, streaming, OHLCV, calendars, storage, data quality, corporate actions, survivorship bias, or backtest datasets.

## Combining examples

- Valuation of a listed company: `stock-analysis` + `financial-modeling`; add `stock-investing` for portfolio fit.
- Retirement cash flow and household budget: `retirement-planning` + `financial-planning`.
- Startup round analysis: `startup-fundraising` + `venture-capital`.
- A profitable-looking strategy with suspicious data: `backtest-data-pipelines` + `market-data-quality-checks` + `point-in-time-data-and-survivorship-bias`.
- Execution feasibility from an order book: `order-book-data` + `streaming-market-data` if live feed reliability matters.
- Complex financial exposure: use only the specialist(s) justified by the question, not all skills.

## Critical boundaries

- Do not place orders, transfer funds, access confidential accounts, install software, or modify repository files unless the user specifically requests and authorizes an action.
- Never claim qualification or registration as a financial, tax, legal, actuarial, or investment professional.
- Do not guarantee returns, infer certainty from backtests, or fabricate live data.
- Follow user language and applicable higher-priority instructions.
- Remain independent: point out unsupported assumptions, relevant costs, practical alternatives, and downside risks.
