package io.dataease.datasource.provider;

import io.dataease.api.ds.vo.ExcelSheetData;
import io.dataease.extensions.datasource.dto.TableField;
import io.dataease.utils.ModelUtils;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.lang.reflect.Method;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ExcelUtilsTest {

    @Test
    void parseExcelSkipsEmptySheetsDeduplicatesHeadersAndKeepsDecimalColumnsNumeric() throws Exception {
        new ModelUtils().setModelValue("desktop");
        byte[] workbookBytes = messyWorkbook();

        List<ExcelSheetData> sheets = parseExcel(workbookBytes);

        assertEquals(1, sheets.size());
        ExcelSheetData prices = sheets.get(0);
        assertEquals("价格数据", prices.getExcelLabel());

        List<String> fieldNames = prices.getFields().stream().map(TableField::getName).toList();
        assertEquals(List.of(
                "日期",
                "Gasoline Unl 93 USGC Prompt Pipeline",
                "Gasoline Unl 93 USGC Prompt Pipeline_2",
                "Benzene FOB Korea Marker"
        ), fieldNames);

        assertEquals("DATETIME", prices.getFields().get(0).getFieldType());
        assertEquals("DOUBLE", prices.getFields().get(1).getFieldType());
        assertEquals("DOUBLE", prices.getFields().get(2).getFieldType());
        assertEquals("DOUBLE", prices.getFields().get(3).getFieldType());
        assertTrue(prices.getData().stream().anyMatch(row -> "904.67".equals(row[1])));
    }

    @SuppressWarnings("unchecked")
    private List<ExcelSheetData> parseExcel(byte[] workbookBytes) throws Exception {
        ExcelUtils excelUtils = new ExcelUtils();
        Method parseExcel = ExcelUtils.class.getDeclaredMethod(
                "parseExcel",
                String.class,
                java.io.InputStream.class,
                boolean.class,
                String.class
        );
        parseExcel.setAccessible(true);
        return (List<ExcelSheetData>) parseExcel.invoke(
                excelUtils,
                "芳烃价格.xlsx",
                new ByteArrayInputStream(workbookBytes),
                true,
                "芳烃价格.xlsx"
        );
    }

    private byte[] messyWorkbook() throws Exception {
        try (XSSFWorkbook workbook = new XSSFWorkbook()) {
            var prices = workbook.createSheet("价格数据");
            Row header = prices.createRow(0);
            header.createCell(0).setCellValue("日期");
            header.createCell(1).setCellValue("Gasoline Unl 93 USGC Prompt Pipeline");
            header.createCell(2).setCellValue("Gasoline Unl 93 USGC Prompt Pipeline");
            header.createCell(3).setCellValue("Benzene FOB Korea Marker");

            Row row1 = prices.createRow(1);
            row1.createCell(0).setCellValue("2018-01-02");
            row1.createCell(1).setCellValue(886);
            row1.createCell(2).setCellValue(887);
            row1.createCell(3).setCellValue("#N/A");

            Row row2 = prices.createRow(2);
            row2.createCell(0).setCellValue("2018-01-03");
            row2.createCell(1).setCellValue(904.67);
            row2.createCell(2).setCellValue(889.5);
            row2.createCell(3).setCellValue(876.25);

            workbook.createSheet("周度数据");

            try (ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
                workbook.write(outputStream);
                return outputStream.toByteArray();
            }
        }
    }
}
