import Link from "next/link";

export default function Home() {
  return (
    <div className="max-w-3xl mx-auto px-6 pt-20 pb-24">
      <span className="inline-block px-3 py-1 rounded-full text-xs font-semibold bg-[color:var(--surface)] text-[color:var(--primary)] tracking-wide">
        EM BREVE NO GOOGLE PLAY
      </span>

      <h1 className="mt-6 text-4xl sm:text-5xl font-bold tracking-tight">
        Sua agenda de dublagem,{" "}
        <span className="text-[color:var(--primary)]">organizada</span>.
      </h1>

      <p className="mt-6 text-lg text-[color:var(--muted)] leading-relaxed">
        DublyDesk é o app que dubladores profissionais usam pra controlar
        escalas, acompanhar ganhos, emitir recibos e nunca mais perder uma
        gravação. Feito pra quem vive de voz, em qualquer estúdio do Brasil.
      </p>

      <div className="mt-10 grid sm:grid-cols-2 gap-4">
        <Feature
          title="Escalas e calendário"
          text="Cadastre gravações, veja conflitos de horário automaticamente e marque como realizado."
        />
        <Feature
          title="Controle financeiro"
          text="Valor por hora, total mensal, gráficos de evolução. Saiba quanto entrou em cada projeto."
        />
        <Feature
          title="Recibos profissionais (Pro)"
          text="Gere PDFs com seu nome, envie por email com 1 toque, controle quem pagou."
        />
        <Feature
          title="Lembretes inteligentes"
          text="Notificações antes da gravação, configuráveis por escala."
        />
      </div>

      <div className="mt-12 p-6 rounded-2xl bg-[color:var(--surface)] border border-[color:var(--border)]">
        <h2 className="font-semibold text-lg">Em breve disponível</h2>
        <p className="mt-2 text-sm text-[color:var(--muted)]">
          Estamos finalizando os últimos ajustes para publicação no Google
          Play. Em paralelo, uma versão web (PWA) também está a caminho. Pra
          ser avisado, escreva pra{" "}
          <a
            href="mailto:contato@dublydesk.com"
            className="text-[color:var(--primary)] hover:underline"
          >
            contato@dublydesk.com
          </a>
          .
        </p>
      </div>

      <div className="mt-10 text-sm text-[color:var(--muted)]">
        <Link href="/termos" className="hover:underline mr-6">
          Termos de Uso
        </Link>
        <Link href="/privacidade" className="hover:underline">
          Política de Privacidade
        </Link>
      </div>
    </div>
  );
}

function Feature({ title, text }: { title: string; text: string }) {
  return (
    <div className="p-5 rounded-xl border border-[color:var(--border)]">
      <h3 className="font-semibold">{title}</h3>
      <p className="mt-2 text-sm text-[color:var(--muted)] leading-relaxed">
        {text}
      </p>
    </div>
  );
}
