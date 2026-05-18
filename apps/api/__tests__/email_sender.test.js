jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({
    sendMail: jest.fn().mockResolvedValue({ messageId: 'mock-msg-1' }),
  })),
}));

const nodemailer = require('nodemailer');
const { sendEmail } = require('../services/email_sender');

describe('sendEmail', () => {
  beforeEach(() => jest.clearAllMocks());

  it('chama sendMail com from, to, subject, html', async () => {
    await sendEmail({
      to: 'destinatario@example.com',
      subject: 'Teste',
      html: '<p>Olá</p>',
    });

    const transport = nodemailer.createTransport.mock.results[0].value;
    expect(transport.sendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: 'destinatario@example.com',
      subject: 'Teste',
      html: '<p>Olá</p>',
    }));
  });

  it('aceita anexos', async () => {
    await sendEmail({
      to: 'd@x.com',
      subject: 'Recibo',
      html: '<p>Anexo</p>',
      attachments: [{ filename: 'recibo.pdf', path: '/tmp/r.pdf' }],
    });
    const transport = nodemailer.createTransport.mock.results[0].value;
    expect(transport.sendMail).toHaveBeenCalledWith(
      expect.objectContaining({ attachments: [{ filename: 'recibo.pdf', path: '/tmp/r.pdf' }] })
    );
  });
});
