# Notas de retenção (material externo, 2026-10-20)

Status: Rascunho

Resumo de um texto trazido pelo dono (notas de monetização e retenção de um canal de devs, aulas da Udacity, Tenjin e
GDC, e um relato sobre o jogo Cat Battles). É opinião de terceiros, não dado medido. As perguntas que saíram daqui
estão em `open-questions.md`, de `Q-423` a `Q-428`.

## Ideias

- **Métricas base:** número de sessões, duração da sessão e retenção. Receita de anúncio e de compras dentro do jogo
  escala com as três; sem retenção, a receita cai depois da 1ª semana, por melhor que seja o lançamento.
- **Três loops ligados:** a partida gera moeda, a progressão gasta, a meta (temporada, ranking, rebirth) segura o longo
  prazo. Uma vitória deve alimentar os três de uma vez. (`Q-427`)
- **Limite dos 90 s:** sair nos primeiros 30–60 s pesa no ranking. Carregar em < 8 s, tela limpa no spawn, 1ª
  recompensa em < 60 s, primeiro minuto igual à promessa da thumb. (`Q-423`, `Q-424`)
- **Diversão antes da recompensa:** recompensa diária não salva loop chato. Recompensa variável dentro do loop segura;
  recompensa fixa sozinha, não.
- **Janelas de 28 dias:** D1 = gancho e 1ª recompensa; D2–D7 = motivos para voltar (baú diário, streak, evento
  limitado); D8–D28 = conteúdo novo e meta. (`Q-425`, `Q-427`)
- **Caso Cat Battles:** tutorial escondido no jogo (já entra jogando contra bots fracos), sem tela de espera, e quem é
  eliminado continua jogando por prêmio. Funciona porque o loop se ensina sozinho. (`Q-423`, `Q-426`)
- **Anúncios:** cada anúncio exibido paga pouco; mais sessões e sessões longas = mais anúncios. (`Q-428`)

## Diagnóstico de queda

Para ler os funis do `MetricsService` (lobby, onboarding, anomalia) nos relatórios de playtest e de lançamento:

| Sinal | Problema provável |
|---|---|
| PTR (taxa de jogar depois de ver a página) caiu, bounce estável | marketing (thumb, ícone, título) |
| PTR estável, bounce subiu | primeira experiência (FTUE) |
| D2–D7 desabou | loop |
| D8–D28 caiu | profundidade de conteúdo |

## Fontes citadas no texto

- Udacity, "Game Sessions and Player Retention" (YouTube).
- Tenjin ROI 101, "Retention for Mobile Games 101" (YouTube).
- GDC, "Research Methods to Improve Live Game Retention, D1 to D100" (YouTube).
- Cat Battles (Roblox), relato de terceiro.
