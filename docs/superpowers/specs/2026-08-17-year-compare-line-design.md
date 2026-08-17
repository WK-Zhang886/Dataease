# Year Compare Line Design

## Goal

Add a new chart type named "年份对比折线图" beside the existing basic line chart. The existing basic line chart remains unchanged.

## Behavior

The new chart reuses the basic line chart interaction and style controls, but renders date data by year comparison:

- X axis uses month-day labels such as `01-02`.
- Series uses the year extracted from the original date, such as `2024`.
- Y axis uses the selected metric value.
- Data is sorted by month and day, not by string order.
- Invalid or empty dates are ignored.
- Leap day `02-29` is kept when it appears.

By default the chart shows all years returned by the current dataset query. Users can limit the years with existing chart filters.

## Architecture

The implementation adds a small pure data transformer under the line chart folder, then adds a new chart class that extends the existing `Line` chart and swaps its data before rendering. The chart picker receives a new entry under the trend group and locale files get a new label.

## Files

- `core/core-frontend/src/views/chart/components/js/panel/charts/line/year-compare-line.ts`
- `core/core-frontend/src/views/chart/components/js/panel/charts/line/year-compare-utils.ts`
- `core/core-frontend/src/views/chart/components/editor/util/chart.ts`
- `core/core-frontend/src/locales/zh-CN.ts`
- `core/core-frontend/src/locales/tw.ts`
- `core/core-frontend/src/locales/en.ts`
- `core/core-frontend/src/locales/en-US.ts`

## Testing

The transformer is validated with a local Node verification script for date parsing, invalid input, leap day retention, and chronological month-day ordering. The frontend is checked with `npm run ts:check` when dependencies allow it.
