const ExcelJS = require('exceljs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, HeadingLevel } = require('docx');
const fs = require('fs');
const path = require('path');

const docsDir = path.join(__dirname, 'docs');

const testCases = [
    { id: 'AUTH-01', module: 'Authentication', desc: 'Login as Owner', expected: 'Successful login, full access to Dashboard.' },
    { id: 'AUTH-02', module: 'Authentication', desc: 'Login as Cashier', expected: 'Successful login, redirected to POS. Analytics/Settings blocked.' },
    { id: 'AUTH-03', module: 'Authentication', desc: 'Login as Kitchen', expected: 'Successful login, redirected to KDS. POS blocked.' },
    { id: 'USR-01', module: 'User Management', desc: 'Create new Cashier', expected: 'Cashier account created and can log in.' },
    { id: 'INV-01', module: 'Inventory Management', desc: 'Add Raw Ingredient', expected: 'Ingredient saved with correct unit of measure and cost.' },
    { id: 'INV-02', module: 'Inventory Management', desc: 'Manual Stock Adjustment', expected: 'Stock level updates correctly and transaction logged.' },
    { id: 'MENU-01', module: 'Menu Management', desc: 'Create Menu Item', expected: 'Menu item appears in POS under correct category.' },
    { id: 'MENU-02', module: 'Menu Management', desc: 'Link Recipe to Item', expected: 'Recipe saved. Stock deducts theoretically upon sale.' },
    { id: 'POS-01', module: 'POS Sales', desc: 'Add/Remove items in cart', expected: 'Cart totals update instantly and accurately.' },
    { id: 'POS-02', module: 'POS Sales', desc: 'Apply global discount', expected: 'Discount applies to subtotal, tax recalculates correctly.' },
    { id: 'PAY-01', module: 'Split Payments', desc: 'Pay 50% Cash, 50% Card', expected: 'Order balances to 0, completes, and logs two payment rows.' },
    { id: 'PRT-01', module: 'Receipt Printing', desc: 'Print 80mm receipt', expected: 'Receipt renders correctly with logo and footer text.' },
    { id: 'KDS-01', module: 'Kitchen Display System', desc: 'Order appears in KDS', expected: 'Order instantly syncs to KDS board as NEW.' },
    { id: 'KDS-02', module: 'Kitchen Display System', desc: 'Bump through statuses', expected: 'Ticket updates from NEW > PREPARING > READY > SERVED.' },
    { id: 'ANL-01', module: 'Analytics', desc: 'Check Todays Sales', expected: 'Dashboard revenue strictly matches completed test orders.' },
    { id: 'SET-01', module: 'Settings', desc: 'Change Global Tax', expected: 'New tax rate applies to the next order created.' },
    { id: 'BKP-01', module: 'Backup & Recovery', desc: 'Verify PITR', expected: 'Confirm Supabase PITR is enabled for project.' }
];

async function generateExcel() {
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('UAT Checklist');

    sheet.columns = [
        { header: 'Test Case ID', key: 'id', width: 15 },
        { header: 'Module', key: 'module', width: 25 },
        { header: 'Description', key: 'desc', width: 40 },
        { header: 'Expected Result', key: 'expected', width: 50 },
        { header: 'Actual Result', key: 'actual', width: 50 },
        { header: 'Pass/Fail', key: 'status', width: 15 },
        { header: 'Tester Notes', key: 'notes', width: 40 }
    ];

    sheet.getRow(1).font = { bold: true };
    sheet.getRow(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD3D3D3' } };

    testCases.forEach(tc => {
        sheet.addRow({
            id: tc.id,
            module: tc.module,
            desc: tc.desc,
            expected: tc.expected,
            actual: '',
            status: '',
            notes: ''
        });
    });

    const outputPath = path.join(docsDir, 'UAT_Checklist.xlsx');
    await workbook.xlsx.writeFile(outputPath);
    console.log(`✅ Generated: ${outputPath}`);
}

async function generateDocx() {
    const doc = new Document({
        sections: [{
            properties: {},
            children: [
                new Paragraph({
                    text: 'NexusPOS AI: UAT Report',
                    heading: HeadingLevel.TITLE,
                }),
                new Paragraph({
                    text: 'Date: __________________\nTester Name: __________________\nLocation: __________________\n',
                }),
                new Paragraph({
                    text: 'Test Case Summary',
                    heading: HeadingLevel.HEADING_1,
                }),
                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    rows: [
                        new TableRow({
                            children: [
                                new TableCell({ children: [new Paragraph({ text: 'Test ID', bold: true })] }),
                                new TableCell({ children: [new Paragraph({ text: 'Module', bold: true })] }),
                                new TableCell({ children: [new Paragraph({ text: 'Status (Pass/Fail)', bold: true })] }),
                                new TableCell({ children: [new Paragraph({ text: 'Sign-off', bold: true })] }),
                            ],
                        }),
                        ...testCases.map(tc => 
                            new TableRow({
                                children: [
                                    new TableCell({ children: [new Paragraph(tc.id)] }),
                                    new TableCell({ children: [new Paragraph(tc.module)] }),
                                    new TableCell({ children: [new Paragraph('')] }),
                                    new TableCell({ children: [new Paragraph('')] }),
                                ]
                            })
                        )
                    ]
                }),
                new Paragraph({
                    text: '\nGeneral Feedback & Identified Bugs',
                    heading: HeadingLevel.HEADING_1,
                }),
                new Paragraph({
                    text: '1. \n\n2. \n\n3. \n',
                }),
                new Paragraph({
                    text: 'Approval Sign-off',
                    heading: HeadingLevel.HEADING_1,
                }),
                new Paragraph({
                    text: 'Project Owner: ________________________\nDate: ________________________\n',
                })
            ],
        }]
    });

    const outputPath = path.join(docsDir, 'UAT_Report_Template.docx');
    const buffer = await Packer.toBuffer(doc);
    fs.writeFileSync(outputPath, buffer);
    console.log(`✅ Generated: ${outputPath}`);
}

async function main() {
    try {
        await generateExcel();
        await generateDocx();
    } catch (err) {
        console.error('Error generating UAT documents:', err);
    }
}

main();
