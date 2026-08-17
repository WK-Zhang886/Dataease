type YearCompareDatum = Record<string, any>
type ParsedYearCompareDatum = YearCompareDatum & {
  yearCompareYear: string
  yearCompareMonthDay: string
  yearCompareOriginSeries: string
}

const DATE_PATTERN = /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})/

function parseDateParts(value: unknown) {
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    const year = value.getFullYear().toString()
    const month = `${value.getMonth() + 1}`.padStart(2, '0')
    const day = `${value.getDate()}`.padStart(2, '0')
    return {
      year,
      monthDay: `${month}-${day}`,
      sort: Number(`${month}${day}`)
    }
  }

  const match = String(value ?? '').trim().match(DATE_PATTERN)
  if (!match) {
    return null
  }

  const [, year, rawMonth, rawDay] = match
  const month = rawMonth.padStart(2, '0')
  const day = rawDay.padStart(2, '0')
  const monthNumber = Number(month)
  const dayNumber = Number(day)
  if (monthNumber < 1 || monthNumber > 12 || dayNumber < 1 || dayNumber > 31) {
    return null
  }

  return {
    year,
    monthDay: `${month}-${day}`,
    sort: Number(`${month}${day}`)
  }
}

export function transformYearCompareLineData(data: YearCompareDatum[] = []): YearCompareDatum[] {
  const parsedData = data.reduce<ParsedYearCompareDatum[]>((result, item) => {
      const dateParts = parseDateParts(item?.field)
      if (!dateParts) {
        return result
      }
      const originSeries = String(item.category || item.quotaList?.[0]?.name || '')
      result.push({
        ...item,
        originField: item.field,
        originCategory: item.category,
        yearCompareYear: dateParts.year,
        yearCompareMonthDay: dateParts.monthDay,
        yearCompareOriginSeries: originSeries,
        yearCompareSort: dateParts.sort
      })
      return result
    }, [])

  const originSeriesList = Array.from(
    new Set(parsedData.map(item => item.yearCompareOriginSeries).filter(Boolean))
  )
  const primaryOriginSeries = originSeriesList[0]
  const visibleData =
    originSeriesList.length > 1
      ? parsedData.filter(item => item.yearCompareOriginSeries === primaryOriginSeries)
      : parsedData

  return visibleData
    .map(item => ({
      ...item,
      field: item.yearCompareMonthDay,
      category: item.yearCompareYear
    }))
    .sort((a, b) => {
      const sortResult = a.yearCompareSort - b.yearCompareSort
      if (sortResult !== 0) {
        return sortResult
      }
      return String(a.category).localeCompare(String(b.category))
    })
}
