# Year Compare Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new "年份对比折线图" chart type that compares values from different years on the same month-day X axis.

**Architecture:** Add a pure transformer for line chart data, then add a new chart class extending the existing `Line` chart. Register the new chart in the existing chart picker and locale files without changing the current `line` chart.

**Tech Stack:** Vue 3, TypeScript, AntV G2Plot Line, DataEase chart registry.

## Global Constraints

- Keep the original `line` chart behavior unchanged.
- Do not add a backend API for this first version.
- Default to showing all years returned by the current query.
- Use existing chart filters to restrict years.
- Keep leap day `02-29` when present.

---

### Task 1: Data Transformer

**Files:**
- Create: `core/core-frontend/src/views/chart/components/js/panel/charts/line/year-compare-utils.ts`

**Interfaces:**
- Produces: `transformYearCompareLineData(data: Record<string, any>[]): Record<string, any>[]`

- [ ] **Step 1: Write the failing verification**

Run a local Node check that expects `2024-01-02` and `2025-01-02` to become two records with `field: '01-02'`, `category: '2024'` and `category: '2025'`, sorted by month-day.

- [ ] **Step 2: Implement the transformer**

Create a pure function that parses `field`, extracts year/month/day, stores the original date as `originField`, stores `yearCompareSort`, and returns data sorted by `yearCompareSort` then `category`.

- [ ] **Step 3: Verify transformer behavior**

Run the local Node check for sorting, invalid dates, and `02-29`.

### Task 2: Chart Class

**Files:**
- Create: `core/core-frontend/src/views/chart/components/js/panel/charts/line/year-compare-line.ts`

**Interfaces:**
- Consumes: `transformYearCompareLineData(data)`
- Produces: chart type `year-compare-line`

- [ ] **Step 1: Add the chart class**

Create `YearCompareLine extends Line`, set `constructor(name = 'year-compare-line')`, and override `drawChart` to clone the chart object with transformed `chart.data.data`.

- [ ] **Step 2: Tune X axis metadata**

Override `setupOptions` only as needed to set month-day axis values in sorted order so G2Plot does not reorder labels alphabetically.

- [ ] **Step 3: Verify registration**

Confirm the automatic registry imports the new class through `import.meta.glob`.

### Task 3: Picker And Labels

**Files:**
- Modify: `core/core-frontend/src/views/chart/components/editor/util/chart.ts`
- Modify: `core/core-frontend/src/locales/zh-CN.ts`
- Modify: `core/core-frontend/src/locales/tw.ts`
- Modify: `core/core-frontend/src/locales/en.ts`
- Modify: `core/core-frontend/src/locales/en-US.ts`

**Interfaces:**
- Consumes: chart type `year-compare-line`
- Produces: visible picker item beside `line`

- [ ] **Step 1: Add locale keys**

Add `chart_year_compare_line`.

- [ ] **Step 2: Add chart picker item**

Insert the new chart entry immediately after the basic line chart, using the existing `line` icon.

- [ ] **Step 3: Run type check**

Run `npm run ts:check` from `core/core-frontend`.
