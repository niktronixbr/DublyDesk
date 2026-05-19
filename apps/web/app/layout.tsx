import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import Link from "next/link";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: {
    default: "DublyDesk · Gestão de escalas e finanças pra dubladores",
    template: "%s · DublyDesk",
  },
  description:
    "App pra dubladores profissionais organizarem escalas, controlarem ganhos e emitirem recibos. Disponível em breve no Google Play.",
  metadataBase: new URL("https://dublydesk.com"),
  openGraph: {
    title: "DublyDesk",
    description:
      "Gestão de escalas e finanças pra dubladores profissionais.",
    url: "https://dublydesk.com",
    siteName: "DublyDesk",
    locale: "pt_BR",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="pt-BR"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col font-sans">
        <header className="border-b border-[color:var(--border)]">
          <div className="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
            <Link href="/" className="font-bold text-lg tracking-tight">
              DublyDesk
            </Link>
            <nav className="flex gap-6 text-sm">
              <Link
                href="/termos"
                className="text-[color:var(--muted)] hover:text-[color:var(--foreground)] transition"
              >
                Termos
              </Link>
              <Link
                href="/privacidade"
                className="text-[color:var(--muted)] hover:text-[color:var(--foreground)] transition"
              >
                Privacidade
              </Link>
            </nav>
          </div>
        </header>

        <main className="flex-1">{children}</main>

        <footer className="border-t border-[color:var(--border)] mt-16">
          <div className="max-w-4xl mx-auto px-6 py-8 text-sm text-[color:var(--muted)] flex flex-col sm:flex-row sm:justify-between gap-2">
            <span>© {new Date().getFullYear()} Niktronix · DublyDesk</span>
            <span>
              Dúvidas:{" "}
              <a
                href="mailto:contato@dublydesk.com"
                className="text-[color:var(--primary)] hover:underline"
              >
                contato@dublydesk.com
              </a>
            </span>
          </div>
        </footer>
      </body>
    </html>
  );
}
