const fs = require('fs');
const path = require('path');
const { generateReceiptPdf } = require('../services/pdf_generator');

describe('generateReceiptPdf', () => {
  const outDir = path.join(__dirname, '.tmp');
  beforeAll(() => fs.mkdirSync(outDir, { recursive: true }));

  it('gera um arquivo PDF válido', async () => {
    const outPath = path.join(outDir, 'test-receipt.pdf');
    await generateReceiptPdf({
      outPath,
      dublador: { nome: 'João Silva', email: 'joao@example.com', cpf: '123.456.789-00' },
      produtora: 'Estúdio ABC',
      projeto: 'Filme XYZ',
      diretor: 'Maria Dir',
      data: new Date('2026-05-10'),
      valor: 1500.5,
      observacao: 'Pagamento referente a sessão de gravação.',
    });

    expect(fs.existsSync(outPath)).toBe(true);
    const buf = fs.readFileSync(outPath);
    expect(buf.slice(0, 5).toString()).toBe('%PDF-');
    expect(buf.length).toBeGreaterThan(1000);
  });

  it('lida com acentos no nome', async () => {
    const outPath = path.join(outDir, 'test-receipt-accents.pdf');
    await expect(
      generateReceiptPdf({
        outPath,
        dublador: { nome: 'João Pessôa de Sá', email: 'joao@x.com' },
        produtora: 'Produção Áudio LTDA',
        projeto: 'Animação Brasileiríssima',
        data: new Date(),
        valor: 999.99,
      })
    ).resolves.not.toThrow();
    expect(fs.existsSync(outPath)).toBe(true);
  });

  afterAll(() => {
    fs.rmSync(outDir, { recursive: true, force: true });
  });
});
