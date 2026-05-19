import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Termos de Uso",
  description:
    "Termos e condições de uso do aplicativo DublyDesk, operado por Thiago Vicente de Oliveira - ME (Niktronix).",
};

const ULTIMA_ATUALIZACAO = "18 de maio de 2026";

export default function TermosPage() {
  return (
    <article className="max-w-3xl mx-auto px-6 py-16 prose-legal">
      <header className="border-b border-[color:var(--border)] pb-6 mb-8">
        <h1 className="text-3xl font-bold tracking-tight">Termos de Uso</h1>
        <p className="mt-2 text-sm text-[color:var(--muted)]">
          Última atualização: {ULTIMA_ATUALIZACAO}
        </p>
      </header>

      <p>
        Estes Termos de Uso (&quot;Termos&quot;) regulam o acesso e o uso do
        aplicativo móvel e dos serviços associados oferecidos sob a marca{" "}
        <strong>DublyDesk</strong> (&quot;Aplicativo&quot; ou
        &quot;Serviço&quot;), operados por{" "}
        <strong>Thiago Vicente de Oliveira - ME</strong>, nome fantasia{" "}
        <strong>Niktronix</strong>, inscrita no CNPJ sob o nº{" "}
        <strong>30.537.390/0001-02</strong>, com sede na Rua Angelo Maglio,
        148, apto 81, Vila Yara, Osasco/SP, CEP 06020-020 (&quot;Niktronix&quot;
        ou &quot;nós&quot;).
      </p>

      <p>
        Ao criar uma conta ou utilizar o DublyDesk, você (&quot;Usuário&quot;
        ou &quot;você&quot;) declara ter lido, compreendido e aceito
        integralmente estes Termos. Se você não concorda com qualquer
        disposição, não utilize o Aplicativo.
      </p>

      <h2>1. Objeto</h2>
      <p>
        O DublyDesk é um aplicativo de produtividade voltado a profissionais
        de dublagem que oferece, entre outras funcionalidades, o cadastro de
        escalas e compromissos, o controle financeiro de ganhos por trabalho,
        a emissão de recibos em PDF e o envio desses documentos por e-mail,
        além de notificações de lembretes e relatórios.
      </p>

      <h2>2. Cadastro e conta</h2>
      <p>
        Para usar o Serviço você precisa criar uma conta informando nome, e-mail
        e senha. Você se compromete a fornecer informações verdadeiras e
        atualizadas e a manter a confidencialidade das suas credenciais. Você
        é responsável por todas as atividades realizadas em sua conta.
      </p>
      <p>
        Você deve ter pelo menos 18 anos de idade ou capacidade civil plena
        para utilizar o DublyDesk. Reservamo-nos o direito de suspender ou
        encerrar contas que violem estes Termos, sem aviso prévio.
      </p>

      <h2>3. Planos e cobrança</h2>
      <p>
        O DublyDesk é oferecido em dois níveis de uso:
      </p>
      <ul>
        <li>
          <strong>Gratuito</strong>: inclui acesso permanente às funcionalidades
          de gestão de escalas, calendário, controle de ganhos e
          notificações, sem limite de tempo.
        </li>
        <li>
          <strong>Pro</strong> (mediante assinatura): inclui, adicionalmente,
          a geração de recibos em PDF, o envio de recibos por e-mail, o
          painel de pagamentos pendentes e demais funcionalidades anunciadas
          como premium.
        </li>
      </ul>

      <h3>3.1. Forma de cobrança</h3>
      <p>
        A assinatura Pro é processada exclusivamente pelos meios de pagamento
        suportados em cada plataforma: <strong>Google Play Billing</strong>{" "}
        para usuários Android e <strong>Stripe</strong> para usuários da
        versão web/PWA. Os preços, vigências e formas de pagamento são
        exibidos na tela de assinatura no momento da contratação.
      </p>

      <h3>3.2. Período de teste gratuito</h3>
      <p>
        Novas assinaturas Pro incluem um período de teste gratuito de até 7
        (sete) dias. Ao final do teste, a cobrança é processada
        automaticamente pela forma de pagamento cadastrada, salvo se você
        cancelar antes do término do período.
      </p>

      <h3>3.3. Renovação automática</h3>
      <p>
        As assinaturas Pro são renovadas automaticamente ao final de cada
        ciclo (mensal ou anual). Você pode desativar a renovação a qualquer
        momento pelas configurações de assinatura do Google Play ou pelo
        portal do cliente Stripe.
      </p>

      <h3>3.4. Cancelamento e reembolso</h3>
      <p>
        Você pode cancelar a assinatura Pro a qualquer momento. Após o
        cancelamento, o acesso aos recursos Pro permanece ativo até o fim do
        ciclo já pago. Não há reembolso proporcional dos dias restantes,
        salvo nos casos previstos em lei e nas políticas das plataformas de
        pagamento (Google Play e Stripe), que prevalecem sobre estes Termos.
      </p>

      <h3>3.5. Direito de arrependimento</h3>
      <p>
        Nos termos do art. 49 do Código de Defesa do Consumidor, você pode
        solicitar o cancelamento da contratação no prazo de 7 (sete) dias
        corridos a partir da contratação, com reembolso integral, escrevendo
        para{" "}
        <a href="mailto:contato@dublydesk.com">contato@dublydesk.com</a> com
        o comprovante de pagamento.
      </p>

      <h2>4. Uso aceitável</h2>
      <p>Você se compromete a não:</p>
      <ul>
        <li>
          Utilizar o Aplicativo para finalidade ilícita, fraudulenta ou que
          viole direitos de terceiros;
        </li>
        <li>
          Tentar acessar áreas restritas, contornar mecanismos de segurança
          ou realizar engenharia reversa do Serviço;
        </li>
        <li>
          Sobrecarregar a infraestrutura do Serviço, por meio de scraping
          automatizado, ataques ou usos abusivos;
        </li>
        <li>
          Inserir, transmitir ou armazenar conteúdo de terceiros sem
          autorização, incluindo dados pessoais que você não tem permissão
          para tratar;
        </li>
        <li>
          Compartilhar sua conta com terceiros ou revender o acesso ao
          Aplicativo.
        </li>
      </ul>

      <h2>5. Conteúdo do usuário</h2>
      <p>
        Você é o único responsável pelos dados que insere no DublyDesk
        (escalas, valores, contatos, observações, recibos). A Niktronix atua
        exclusivamente como operadora técnica desses dados e não monitora,
        analisa ou utiliza esse conteúdo para fins distintos daqueles
        descritos na{" "}
        <a href="/privacidade">Política de Privacidade</a>.
      </p>

      <p>
        Você garante ter os direitos necessários sobre qualquer dado pessoal
        de terceiro inserido no Aplicativo (por exemplo, e-mail de cliente
        para envio de recibo) e responde sozinho por eventuais demandas de
        titulares ou autoridades em relação a esses dados.
      </p>

      <h2>6. Recibos emitidos via DublyDesk</h2>
      <p>
        Os recibos gerados pelo Aplicativo têm natureza meramente declaratória
        do recebimento de valores e <strong>não substituem documentos
        fiscais</strong> (nota fiscal de serviço eletrônica, RPA, ou outros).
        Cabe ao Usuário verificar a legislação aplicável à sua atividade e
        emitir, quando exigido, os documentos fiscais próprios pela
        prefeitura ou órgão competente.
      </p>

      <h2>7. Propriedade intelectual</h2>
      <p>
        Todos os direitos sobre o software, a marca DublyDesk, os layouts,
        textos, ícones e conteúdo do Aplicativo pertencem à Niktronix ou a
        seus licenciadores. É concedida ao Usuário uma licença pessoal, não
        exclusiva, intransferível e revogável para usar o Aplicativo nos
        termos deste documento.
      </p>

      <h2>8. Limitação de responsabilidade</h2>
      <p>
        O Aplicativo é fornecido &quot;no estado em que se encontra&quot;
        (as is). Embora envidemos esforços razoáveis para manter o Serviço
        disponível e funcional, não garantimos operação ininterrupta ou
        livre de erros.
      </p>
      <p>
        Na máxima extensão permitida pela legislação aplicável, a Niktronix
        não responde por:
      </p>
      <ul>
        <li>
          Lucros cessantes, perdas indiretas ou danos morais decorrentes do
          uso ou impossibilidade de uso do Aplicativo;
        </li>
        <li>
          Indisponibilidades de serviços de terceiros (Google Play, Stripe,
          provedores de hospedagem, provedores de e-mail);
        </li>
        <li>
          Conteúdo, escalas, valores ou dados financeiros inseridos pelo
          próprio Usuário ou por seus contatos.
        </li>
      </ul>
      <p>
        Em nenhuma hipótese a responsabilidade total da Niktronix excederá o
        valor total pago pelo Usuário ao DublyDesk nos 12 (doze) meses
        anteriores ao evento que originou a controvérsia.
      </p>

      <h2>9. Modificações dos Termos</h2>
      <p>
        Podemos atualizar estes Termos periodicamente. A versão vigente está
        sempre disponível em{" "}
        <a href="https://dublydesk.com/termos">dublydesk.com/termos</a>, com
        a data da última atualização indicada no topo. Mudanças relevantes
        serão comunicadas por e-mail ou notificação no Aplicativo com pelo
        menos 15 (quinze) dias de antecedência. O uso continuado após a
        entrada em vigor das alterações implica aceitação da nova versão.
      </p>

      <h2>10. Encerramento</h2>
      <p>
        Você pode encerrar sua conta a qualquer momento solicitando exclusão
        em <a href="mailto:contato@dublydesk.com">contato@dublydesk.com</a>.
        Após o encerramento, seus dados pessoais são excluídos conforme
        descrito na{" "}
        <a href="/privacidade">Política de Privacidade</a>, ressalvadas as
        informações que devamos reter por obrigação legal (por exemplo,
        registros fiscais de assinaturas pagas).
      </p>

      <h2>11. Legislação aplicável e foro</h2>
      <p>
        Estes Termos são regidos pelas leis da República Federativa do
        Brasil. Fica eleito o foro da Comarca de{" "}
        <strong>Osasco, SP</strong>, para dirimir quaisquer controvérsias
        decorrentes destes Termos, com renúncia a qualquer outro, por mais
        privilegiado que seja.
      </p>

      <h2>12. Contato</h2>
      <p>
        Dúvidas sobre estes Termos podem ser enviadas para{" "}
        <a href="mailto:contato@dublydesk.com">contato@dublydesk.com</a>.
      </p>
    </article>
  );
}
