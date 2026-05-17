# Docs Archive

Esta pasta contém **snapshots históricos** do projeto que não refletem o estado atual. Foram preservados pra consulta de contexto mas **não devem ser usados como referência de implementação**.

| Arquivo | Conteúdo | Por que arquivado |
|---------|----------|-------------------|
| `DublyDesk_Doc_20260411-00.32.md` | Documentação técnica de 2026-04-11 | Pré-migração de Render → VPS; menciona `dublydesk.onrender.com` e features que evoluíram |
| `DublyDesk_Melhorias_ClaudeCode.md` | Lista de melhorias propostas em conversa anterior | Algumas já foram implementadas, outras descartadas; o histórico vivo está nos commits |
| `DESIGN.md` | Design doc inicial | Menciona stack desatualizada (Render, etc) |
| `dublydesk_doc.md` | Documento de design duplicado | Mesmo conteúdo do `DublyDesk_Doc_*` acima |

## Onde está a documentação atual?

- **Visão geral e quick start:** [`/README.md`](../../README.md)
- **Guia técnico pra IA:** [`/CLAUDE.md`](../../CLAUDE.md)
- **Arquitetura completa:** skill `dublydesk-architecture` (`~/.claude/skills/dublydesk-architecture/SKILL.md`)
- **Convenções de código:** skill `dublydesk-conventions` (`~/.claude/skills/dublydesk-conventions/SKILL.md`)
- **Specs/planos de features:** [`Docs/superpowers/specs/`](../superpowers/specs/) e [`Docs/superpowers/plans/`](../superpowers/plans/)

## Por que não deletar?

Git preserva tudo no histórico, então o conteúdo nunca se perde. Mas manter visível em `archive/` é útil pra:
- Consultar decisões antigas sem precisar fazer `git log` archeology
- Entender por que o app foi de Render → VPS Hostinger
- Lembrar de features que foram propostas mas não implementadas

Se algum dia esses arquivos virarem ruído mesmo aqui, pode deletar — o `git log --follow` recupera.
