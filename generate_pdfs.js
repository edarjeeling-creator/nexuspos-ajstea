const { mdToPdf } = require('md-to-pdf');
const fs = require('fs');
const path = require('path');

const docsDir = path.join(__dirname, 'docs');
const outputDir = path.join(__dirname, 'docs', 'pdf_output');

if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

const filesToConvert = [
    'owner_manual.md',
    'cashier_manual.md',
    'kitchen_manual.md',
    'administrator_manual.md',
    'quick_start_guide.md',
    'pilot_setup_guide.md',
    'troubleshooting_guide.md'
];

async function generateAll() {
    console.log('--- Starting PDF Generation for NexusPOS AI Pilot Launch ---');
    
    for (const filename of filesToConvert) {
        const markdownPath = path.join(docsDir, filename);
        if (!fs.existsSync(markdownPath)) {
            console.error(`Missing file: ${filename}`);
            continue;
        }

        const pdfFilename = filename.replace('.md', '.pdf');
        const pdfPath = path.join(outputDir, pdfFilename);

        try {
            console.log(`Converting ${filename} to PDF...`);
            const pdf = await mdToPdf(
                { path: markdownPath }, 
                { 
                    dest: pdfPath,
                    pdf_options: {
                        format: 'A4',
                        margin: { top: '20mm', right: '20mm', bottom: '20mm', left: '20mm' },
                        displayHeaderFooter: true,
                        headerTemplate: '<div style="font-size: 10px; width: 100%; text-align: center; color: #888;">NexusPOS AI - Pilot Launch Edition</div>',
                        footerTemplate: '<div style="font-size: 10px; width: 100%; text-align: center; color: #888;"><span class="pageNumber"></span> / <span class="totalPages"></span></div>'
                    },
                    stylesheet: [
                        'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.1.0/github-markdown.min.css'
                    ],
                    css: 'body { font-family: "Inter", sans-serif; } img { max-width: 100%; border: 1px solid #eaeaea; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }'
                }
            );
            console.log(`✅ Success: Generated ${pdfFilename}`);
        } catch (err) {
            console.error(`❌ Failed to convert ${filename}:`, err.message);
        }
    }
    console.log('--- PDF Generation Complete ---');
}

generateAll().catch(console.error);
