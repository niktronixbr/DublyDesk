import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Política de Privacidade",
  description:
    "Política de Privacidade do DublyDesk em conformidade com a Lei Geral de Proteção de Dados (LGPD).",
};

const ULTIMA_ATUALIZACAO = "18 de maio de 2026";

export default function PrivacidadePage() {
  return (
    <article className="max-w-3xl mx-auto px-6 py-16 prose-legal">
      <header className="border-b border-[color:var(--border)] pb-6 mb-8">
        <h1 className="text-3xl font-bold tracking-tight">
          Política de Privacidade
        </h1>
        <p className="mt-2 text-sm text-[color:var(--muted)]">
          Última atualização: {ULTIMA_ATUALIZACAO}
        </p>
      </header>

      <p>
        Esta Política descreve como o DublyDesk coleta, armazena e trata seus
        dados pessoais, em conformidade com a{" "}
        <strong>Lei Geral de Proteção de Dados Pessoais — LGPD (Lei nº
        13.709/2018)</strong>.
      </p>

      <h2>1. Identificação do Controlador</h2>
      <p>
        O controlador dos dados pessoais é{" "}
        <strong>Thiago Vicente de Oliveira - ME</strong>, nome fantasia{" "}
        <strong>Niktronix</strong>, CNPJ <strong>30.537.390/0001-02</strong>,
        com sede na Rua Angelo Maglio, 148, apto 81, Vila Yara, Osasco/SP,
        CEP 06020-020.
      </p>

      <h2>2. Encarregado pelo Tratamento (DPO)</h2>
      <p>
        Em cumprimento ao art. 41 da LGPD, o encarregado pelo tratamento de
        dados pessoais é <strong>Thiago Vicente de Oliveira</strong>, que
        pode ser contatado pelo e-mail{" "}
        <a href="mailto:dpo@dublydesk.com">dpo@dublydesk.com</a>.
      </p>

      <h2>3. Dados que coletamos</h2>

      <h3>3.1. Dados que você nos fornece diretamente</h3>
      <ul>
        <li>
          <strong>Cadastro</strong>: nome, e-mail e senha (armazenada
          criptografada com bcrypt).
        </li>
        <li>
          <strong>Perfil</strong>: foto de avatar (opcional), preferências de
          tema e notificações.
        </li>
        <li>
          <strong>Conteúdo do app</strong>: escalas de gravação, valores
          financeiros, produtoras, projetos, diretores, observações,
          contatos comerciais (nome e telefone) que você cadastrar, status
          de pagamento.
        </li>
        <li>
          <strong>Recibos</strong>: dados que você informa ao gerar recibos
          (CPF opcional, e-mail destinatário, mensagem).
        </li>
      </ul>

      <h3>3.2. Dados coletados automaticamente</h3>
      <ul>
        <li>
          <strong>Token de assinatura</strong>: ao assinar Pro, recebemos da
          Google Play ou Stripe um identificador da sua compra, status da
          assinatura e datas de renovação.
        </li>
        <li>
          <strong>Logs técnicos</strong>: endereço IP, data/hora de acesso,
          versão do app e do sistema operacional, eventuais erros, para fins
          de diagnóstico e segurança.
        </li>
      </ul>

      <h3>3.3. Dados que NÃO coletamos</h3>
      <p>
        O DublyDesk <strong>não</strong> acessa seus contatos do telefone,
        sua localização GPS, suas fotos (exceto a que você seleciona como
        avatar), seu microfone ou sua câmera. Não usamos cookies de
        rastreamento publicitário nem trackers de redes sociais.
      </p>

      <h2>4. Bases legais</h2>
      <p>
        Tratamos seus dados com fundamento nas seguintes bases legais
        previstas na LGPD:
      </p>
      <ul>
        <li>
          <strong>Execução de contrato</strong> (art. 7º, V): para operar o
          Aplicativo, autenticar você, processar a assinatura Pro e
          disponibilizar as funcionalidades.
        </li>
        <li>
          <strong>Cumprimento de obrigação legal</strong> (art. 7º, II):
          para reter registros fiscais de pagamentos e atender obrigações
          tributárias.
        </li>
        <li>
          <strong>Consentimento</strong> (art. 7º, I): para o envio de
          recibos por e-mail a terceiros indicados por você e para
          notificações push.
        </li>
        <li>
          <strong>Legítimo interesse</strong> (art. 7º, IX): para garantir a
          segurança do Serviço, prevenir fraudes e melhorar a experiência
          de uso por meio de métricas agregadas e anônimas.
        </li>
      </ul>

      <h2>5. Finalidades</h2>
      <p>Utilizamos seus dados para:</p>
      <ul>
        <li>Permitir o login e a operação do Aplicativo;</li>
        <li>
          Sincronizar suas escalas e dados financeiros entre dispositivos;
        </li>
        <li>
          Gerar recibos em PDF, enviá-los por e-mail e armazená-los no seu
          histórico;
        </li>
        <li>
          Processar e validar a assinatura Pro (verificação de compra junto
          ao Google Play / Stripe);
        </li>
        <li>
          Enviar e-mails transacionais (recuperação de senha, recibos
          solicitados) e notificações push relacionadas às suas escalas;
        </li>
        <li>
          Manter a segurança e a integridade do Serviço, investigar incidentes
          e prevenir abusos;
        </li>
        <li>Cumprir obrigações legais e atender solicitações de autoridades.</li>
      </ul>

      <h2>6. Compartilhamento com terceiros</h2>
      <p>
        Compartilhamos dados estritamente necessários com os seguintes
        operadores, todos sujeitos a contratos de processamento de dados:
      </p>
      <ul>
        <li>
          <strong>Hostinger</strong> (provedor de VPS): hospedagem da API e
          do banco de dados PostgreSQL. Servidores no Brasil.
        </li>
        <li>
          <strong>Google LLC / Google Play Billing</strong>: processamento
          de pagamentos de assinaturas em Android e validação de compras.
        </li>
        <li>
          <strong>Stripe Payments Europe Ltd.</strong>: processamento de
          pagamentos de assinaturas via web (quando disponível).
        </li>
        <li>
          <strong>Google (Gmail SMTP)</strong>: envio de e-mails
          transacionais (recuperação de senha, recibos).
        </li>
        <li>
          <strong>Cloudflare, Inc.</strong>: roteamento de e-mails do domínio
          dublydesk.com.
        </li>
      </ul>
      <p>
        Não vendemos seus dados pessoais. Não compartilhamos com fins de
        publicidade. Compartilhamentos com autoridades públicas ocorrem
        apenas mediante ordem judicial ou exigência legal específica.
      </p>

      <h2>7. Transferência internacional</h2>
      <p>
        Alguns operadores citados acima (Google, Stripe, Cloudflare) podem
        processar dados em servidores fora do Brasil. Tais transferências
        ocorrem mediante cláusulas contratuais padrão e, quando aplicável,
        com base nas exceções do art. 33 da LGPD (necessidade para
        cumprimento do contrato e consentimento específico).
      </p>

      <h2>8. Retenção e exclusão</h2>
      <p>
        Mantemos seus dados pelo tempo necessário às finalidades descritas
        nesta Política:
      </p>
      <ul>
        <li>
          <strong>Conta e conteúdo</strong>: enquanto sua conta estiver
          ativa. Após pedido de exclusão, os dados são apagados em até 30
          (trinta) dias.
        </li>
        <li>
          <strong>Registros de pagamento</strong>: pelo prazo de 5 (cinco)
          anos, conforme exigência do Código Civil e do art. 195, §5º, do
          CTN, para defesa em eventual processo administrativo ou judicial.
        </li>
        <li>
          <strong>Logs técnicos de acesso</strong>: pelo prazo de 6 (seis)
          meses, conforme art. 15 do Marco Civil da Internet.
        </li>
      </ul>

      <h2>9. Seus direitos como titular</h2>
      <p>
        Nos termos do art. 18 da LGPD, você pode exercer, a qualquer
        momento, os seguintes direitos:
      </p>
      <ul>
        <li>Confirmação da existência de tratamento;</li>
        <li>Acesso aos seus dados;</li>
        <li>Correção de dados incompletos, inexatos ou desatualizados;</li>
        <li>
          Anonimização, bloqueio ou eliminação de dados desnecessários ou
          excessivos;
        </li>
        <li>Portabilidade dos dados;</li>
        <li>
          Eliminação dos dados tratados com base em consentimento, salvo
          hipóteses de guarda legal;
        </li>
        <li>Informação sobre compartilhamentos realizados;</li>
        <li>Revogação do consentimento, quando aplicável;</li>
        <li>
          Oposição a tratamento realizado com fundamento em outras bases
          legais.
        </li>
      </ul>
      <p>
        Para exercer qualquer desses direitos, envie um e-mail para{" "}
        <a href="mailto:dpo@dublydesk.com">dpo@dublydesk.com</a>. Responderemos
        em até 15 (quinze) dias úteis.
      </p>

      <h2>10. Segurança</h2>
      <p>
        Adotamos medidas técnicas e organizacionais razoáveis para proteger
        seus dados contra acesso não autorizado, perda, alteração ou
        divulgação indevida, incluindo: criptografia em trânsito (HTTPS/TLS),
        criptografia de senhas (bcrypt), tokens de autenticação JWT com
        expiração, controle de acesso por usuário no banco de dados, e
        backups regulares.
      </p>
      <p>
        Nenhum sistema é, contudo, 100% imune a falhas. Caso identifiquemos
        um incidente de segurança que possa acarretar risco ou dano
        relevante aos titulares, notificaremos os afetados e a Autoridade
        Nacional de Proteção de Dados (ANPD) nos termos do art. 48 da LGPD.
      </p>

      <h2>11. Crianças e adolescentes</h2>
      <p>
        O DublyDesk não é direcionado a menores de 18 anos e não coleta
        intencionalmente dados de crianças ou adolescentes. Caso tomemos
        conhecimento de cadastro indevido, a conta será removida.
      </p>

      <h2>12. Alterações nesta Política</h2>
      <p>
        Esta Política pode ser atualizada para refletir mudanças no Serviço
        ou em obrigações legais. A versão vigente está sempre disponível em{" "}
        <a href="https://dublydesk.com/privacidade">
          dublydesk.com/privacidade
        </a>
        . Alterações relevantes serão comunicadas por e-mail e/ou no
        Aplicativo com pelo menos 15 (quinze) dias de antecedência.
      </p>

      <h2>13. Contato e ANPD</h2>
      <p>
        Para qualquer dúvida, solicitação ou denúncia relativa ao tratamento
        de seus dados pessoais, escreva para{" "}
        <a href="mailto:dpo@dublydesk.com">dpo@dublydesk.com</a>.
      </p>
      <p>
        Você também pode apresentar reclamação à{" "}
        <strong>Autoridade Nacional de Proteção de Dados (ANPD)</strong>{" "}
        pelos canais oficiais disponíveis em{" "}
        <a
          href="https://www.gov.br/anpd"
          target="_blank"
          rel="noopener noreferrer"
        >
          gov.br/anpd
        </a>
        .
      </p>
    </article>
  );
}
