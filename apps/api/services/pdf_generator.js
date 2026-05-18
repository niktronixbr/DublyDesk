const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const BRL = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const DATE_FMT = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });

async function generateReceiptPdf({ outPath, dublador, produtora, projeto, diretor, data, valor, observacao }) {
  return new Promise((resolve, reject) => {
    const dir = path.dirname(outPath);
    fs.mkdirSync(dir, { recursive: true });

    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const stream = fs.createWriteStream(outPath);
    doc.pipe(stream);

    doc.font('Helvetica');

    // Título
    doc.fontSize(20).text('RECIBO', { align: 'center' });
    doc.moveDown(2);

    // Bloco principal
    doc.fontSize(11);
    doc.text(`Recebi de ${produtora} a quantia de ${BRL.format(valor)},`);
    doc.moveDown(0.5);
    doc.text('referente a:');
    doc.moveDown(0.5);

    // Detalhes
    doc.text(`• Projeto: ${projeto}`);
    if (diretor) doc.text(`• Direção: ${diretor}`);
    doc.text(`• Data do serviço: ${DATE_FMT.format(data)}`);
    if (observacao) {
      doc.moveDown(0.5);
      doc.text(`Obs.: ${observacao}`);
    }

    doc.moveDown(2);
    doc.text('Para clareza firmo o presente recibo.', { align: 'left' });
    doc.moveDown(2);
    doc.text(DATE_FMT.format(new Date()), { align: 'right' });
    doc.moveDown(3);

    // Assinatura
    doc.text('_'.repeat(50), { align: 'center' });
    doc.fontSize(10);
    doc.text(dublador.nome, { align: 'center' });
    if (dublador.cpf) doc.text(`CPF: ${dublador.cpf}`, { align: 'center' });
    if (dublador.email) doc.text(dublador.email, { align: 'center' });

    // Rodapé
    doc.fontSize(8).fillColor('#999');
    doc.text('Gerado pelo DublyDesk · dublydesk.com', 50, doc.page.height - 60, {
      width: doc.page.width - 100,
      align: 'center',
    });

    doc.end();
    stream.on('finish', () => resolve(outPath));
    stream.on('error', reject);
  });
}

module.exports = { generateReceiptPdf };
