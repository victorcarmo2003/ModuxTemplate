Status: Rascunho

# Features e mecânicas (FEAT-###)

Autor: game-designer, 2026-10-08 (conciliado até a rodada 17). Fontes: `vision.md`, `decisions.md` (DEC-001 a DEC-130), `design/proposals-round-1.md` e
`design/proposals-round-2.md` (Aprovados), `source/`. Onde uma regra já é decisão, a ficha cita **[DEC-###]**; o resto é proposta
deste documento e só vale depois da aprovação do usuário. Números são **valores iniciais em tabela de dados** (DEC-044, DEC-068):
mudar número = mudar tabela, sem código novo.

Fichas relacionadas: `items.md` (ITM), `upgrades.md` (UPG), `npcs.md` (NPC), `classes.md` (CLS), `economy.md`, `progression.md`.
Conteúdo narrativo (falas, ligações, as 10 anomalias, revelação) é do narrative-writer em `docs/story/`; aqui só o contrato mecânico.
Nomes de lugar e personagem vêm de `docs/story/` (Bellmoor, esquina Ninth & Juniper, Ninth Street Mart, Bellmoor Savings, Juniper Street,
Bramble's Corner Dogs, Walt Bramble, Quick Quentin, Opal, Mr. Pickett). Textos de prompt seguem `story/ui-text.md`. Outros nomes em inglês entre aspas são placeholders (DEC-022).

Conciliação da rodada 7 (DEC-073 a DEC-079): lista de 10 anomalias aprovada; regra crítica fixa só na ANM-007; Walt em pessoa só no final;
ligação do chefe não se repete; cutscenes puláveis com 50% dos votos; Opal entra.

Conciliação das rodadas 8–12 (DEC-080 a DEC-109, 2026-10-08):

| Mudança | DEC | Fichas |
|---|---|---|
| Snapshot da run no início de cada turno, TTL 15 min; party inteira fora por > 15 min = run encerrada | DEC-080 | FEAT-002, FEAT-030 |
| Sem XP nem níveis no MVP | DEC-081 | FEAT-014, FEAT-029 |
| Dinheiro sobrando depois de ~Day 8 aceito | DEC-082 | FEAT-017 |
| Anti-AFK: gemas de dia exigem ≥ 3 pedidos completos | DEC-083 | FEAT-029 |
| "Day 100" soma dias de modo infinito entre sessões | DEC-084 | FEAT-031 |
| Relógio não pausa; desconectado não conta para "todos fora"; gemas por evento para quem está no servidor | DEC-085, DEC-104 | FEAT-003, FEAT-026, FEAT-029 |
| Trailer trabalha na esquina (Pad do carrinho) | DEC-086 | FEAT-016 |
| Trânsito com carros andando; atropelam (ragdoll), derrubam o item da mão, sem sanidade | DEC-087, DEC-095, DEC-103 | **FEAT-033** (novo), FEAT-036 (novo) |
| Cutscene em 1ª pessoa, compartilhada, avatares da party visíveis | DEC-088 | FEAT-004 |
| Todo personagem R6; sem braços em 1ª pessoa | DEC-089, DEC-097 | FEAT-005 |
| Sanidade 0: desmaio → ambulância leva → reviver (Robux ou item raro) → senão spectate até o fim da run; todos caem → 10 s → noite perdida | DEC-091 a DEC-094, DEC-102 | FEAT-025, FEAT-026, **FEAT-034** (novo) |
| Prefixo `ANM-###`: N1 = ANM-001 … N10 = ANM-010 | DEC-096 | todas |
| Membro atrasado entra depois e spawna normalmente | DEC-098 | FEAT-001, FEAT-004, FEAT-030 |
| Upgrades comprados na bancada do fundo do Mart; básicos sempre à venda; só especiais no sorteio por turno; trailer fora da rotação | DEC-101, DEC-106, DEC-107 | FEAT-015, **FEAT-035** (novo), FEAT-016 |
| Item raro de reviver vendido na bancada, pago com dinheiro da party, guardado na hotbar | DEC-100, DEC-108 | FEAT-035, FEAT-034, `items.md` ITM-021 |
| Frutas/verduras do Mart só cenário | DEC-109 | FEAT-008 |

Conciliação das rodadas 13–15 (DEC-110 a DEC-129, 2026-10-08):

| Mudança | DEC | Fichas |
|---|---|---|
| Chances do chefe = **1 por run inteira**; a 2ª noite perdida (a mesma ou outra) encerra a run | DEC-110, DEC-112 | FEAT-002, FEAT-014, FEAT-018, FEAT-026 |
| Noite repetida: **todos** voltam `Active`, inclusive espectadores de noites anteriores; noite vencida não devolve ninguém | DEC-111, DEC-113 | FEAT-025, FEAT-026 |
| Ambulância na ida: médicos descem e levam o corpo; na volta do reviver ninguém desce | DEC-114 | FEAT-034 |
| Reviver até 6:00 AM da noite da queda; Robux só para si; limite 2 revives/jogador/noite | DEC-115, DEC-116, DEC-129 | FEAT-025, FEAT-034 |
| Recibo de Robux não aplicado = 1 crédito de reviver no **perfil** | DEC-117 | FEAT-034 |
| Janela de 10 s congela com prompt de compra aberto, até +20 s | DEC-118 | FEAT-034 |
| Retomada de 15 min vale também para queda do servidor | DEC-119 | FEAT-002, FEAT-030 |
| ~~Semáforo com faixa de pedestre; carros obedecem; NPC só atravessa no verde~~ (revogada por DEC-130, ver abaixo) | DEC-120 | FEAT-033 |
| Party para preços = roster que entrou até o fim do Day 1, fixo | DEC-121 | FEAT-001, FEAT-016, FEAT-035 |
| Noite perdida: todos acordam em pé na calçada ao lado do trailer | DEC-122 | FEAT-026 |
| Sinal do Walker: último poste da Juniper zumbe ~2 s | DEC-123 | FEAT-022 |
| Todas as ligações no telefone fixo do veículo; celular flip removido junto com a intro (DEC-309) | DEC-124 | FEAT-018 |
| Cafeteira fixa no trailer | DEC-125 | FEAT-015, FEAT-021 |
| Noite crescente 20 → 30 min | DEC-127 | FEAT-002 |
| Fora do MVP: eventos de demanda, validade, missões diárias | DEC-128 | FEAT-007 |
| Item de reviver: 15%/turno após o trailer, $200 × party | DEC-129 | FEAT-035, ITM-021 |

Conciliação das rodadas 16–17 (2026-10-08):

| Mudança | DEC | Fichas |
|---|---|---|
| **Sem semáforo no MVP**; jogador atravessa por conta e risco (revoga DEC-120) | DEC-130 | FEAT-033, NPC-019, NPC-022, NPC-024 |
| Rota trailer ↔ Mart cruza a Juniper Sul em CW-1, sem semáforo, "na sorte"; atropelado derruba o pacote | DEC-131, DEC-103 | FEAT-033, FEAT-036 |
| Regra de travessia sem semáforo (PARE na Juniper, carro para só para NPC com reserva de faixa, nunca para jogador; spawn ≥ 55 studs da faixa) | DEC-133 | FEAT-033, `npcs.md` |
| Tabela `Ambulance`: 24 studs/s, `MedicReach` 80, `MedicSpeed` 20, `CollectTime` ≤ 10,5 s, spawn por parada (`MAP-01.md` rev.3 P35) | proposta (Q-107) | FEAT-034, NPC-023, NPC-024 |
| Ida ao Mart volta a ~25 s sem a espera do semáforo: DEC-049 mantida | DEC-049 | FEAT-033 |

Nome de exibição do item de reviver (ITM-021): **"Rescue Whistle"** (narrative-writer, `ui-text.md`; DEC-022). DEC-129 o chama de "Revive Kit"; é o mesmo item. Chave de dados segue `revive_kit`. Prompts seguem `ui-text.md` ("Buy Whistle", "Use Whistle", "Blow Whistle").

Anomalias: ID `ANM-###` (DEC-096). Onde o texto ainda usa o rótulo curto "Nk", leia **ANM-00k** (N10 = ANM-010). O ator de servidor de cada anomalia continua com `NPC-###` (NPC-009 a NPC-018), referenciando o `ANM-###`.
**TASK-081 (2026-10-10, game-designer; números Provisórios, Rascunho):** fluxo da noite e contagem por tentativas
(FEAT-009, fecha L-05), tabela `Thief` (FEAT-013), tabela `Sanity` + `BasicLampRadius = 0` + orçamento de sanidade
(FEAT-019), dados do café e recomendação A da `Q-170` (FEAT-021), recusas com toast da D-04 (FEAT-005), nome único
"Ground Coffee" do ITM-019 (D-10, `items.md`).

Respostas às Qs do game-designer: seção **"Propostas pendentes"** no fim deste arquivo (e em `economy.md`, `upgrades.md`, `npcs.md`, `items.md`, `progression.md`).

## Template de ficha

```
### FEAT-### — Nome
Status · Pilares (DEC-002) · Origem (DEC/§)
Resumo — 1–3 linhas
Regras e números — tabela
Dados — tabela(s) data-driven envolvidas
Party — comportamento com 1–4 jogadores
Fora do MVP
Critérios de aceite — verificáveis
Pendências — Q-### / notas
```

## Índice

| ID | Feature | Pilares | Seção |
|---|---|---|---|
| FEAT-001 | Lobby, party e seleção de classe | PROGREDIR | Run |
| FEAT-002 | Estrutura da run (máquina de estados) | PROGREDIR, DESCOBRIR | Run |
| FEAT-003 | Relógio e turnos (ciclo dia/noite) | GERENCIAR, OBSERVAR | Run |
| FEAT-004 | Cutscenes: início e voto para pular | DESCOBRIR | Run |
| FEAT-005 | Interação: prompt no mundo e hotbar | VENDER | Base |
| FEAT-006 | Preparo por estações | VENDER | Dia |
| FEAT-007 | Estoque e Restock | GERENCIAR | Dia |
| FEAT-008 | Mercado | GERENCIAR | Dia |
| FEAT-009 | Fluxo de clientes e teto de NPC | VENDER | Dia/Noite |
| FEAT-010 | Pedidos por combinação livre | VENDER | Dia/Noite |
| FEAT-011 | Atendimento, validação e pagamento | VENDER | Dia/Noite |
| FEAT-012 | Gaveta do caixa | GERENCIAR | Dia/Noite |
| FEAT-013 | Ladrão | GERENCIAR, OBSERVAR | Dia |
| FEAT-014 | Nota do turno e tela de resumo | PROGREDIR | Dia/Noite |
| FEAT-015 | Bancada de upgrades do Mart (compra e aplicação) | PROGREDIR | Dia/Noite |
| FEAT-016 | Compra do trailer e troca de veículo | PROGREDIR, DESCOBRIR | Run |
| FEAT-017 | Modo dia infinito | PROGREDIR | Run |
| FEAT-018 | Ligações do chefe (gatilhos) | DESCOBRIR | Run |
| FEAT-019 | Sanidade | SOBREVIVER, OBSERVAR | Noite |
| FEAT-020 | Escuro e zonas de luz | SOBREVIVER | Noite |
| FEAT-021 | Café | SOBREVIVER | Noite |
| FEAT-022 | Sistema genérico de anomalias | OBSERVAR, SOBREVIVER | Noite |
| FEAT-023 | Verbos contra anomalia | SOBREVIVER | Noite |
| FEAT-024 | Regras do chefe: comum e crítica | SOBREVIVER, DESCOBRIR | Noite |
| FEAT-025 | Jogador caído e espectador | SOBREVIVER | Noite |
| FEAT-026 | Avaliação da noite e chances do chefe | SOBREVIVER | Noite |
| FEAT-027 | Final da 10ª noite | DESCOBRIR | Noite |
| FEAT-028 | Classes (sistema) | PROGREDIR | Meta |
| FEAT-029 | Gemas | PROGREDIR | Meta |
| FEAT-030 | Reconexão | — (infra de sessão) | Meta |
| FEAT-031 | Achievement secreto "Day 100" | PROGREDIR | Meta |
| FEAT-032 | HUD de status e notificações (UI) | — (UI) | UI |
| FEAT-033 | Trânsito e atropelamento | OBSERVAR, GERENCIAR | Dia/Noite |
| FEAT-034 | Desmaio, ambulância e reviver | SOBREVIVER | Noite |
| FEAT-035 | Oferta especial da bancada (sorteio por turno) | GERENCIAR, SOBREVIVER | Dia/Noite |
| FEAT-036 | Item no chão (derrubar e pegar) | GERENCIAR | Dia/Noite |
| FEAT-037 | Mesas do Pad / área de consumo (2026-10-11, Provisório) | VENDER, GERENCIAR, PROGREDIR | Dia/Noite |
| FEAT-038 | Clientes em dupla (2026-10-11, Provisório) | VENDER | Dia/Noite |
| FEAT-039 | Modo de preparo focado (estações de preparo) (2026-10-12, Rascunho; **V1 100% focado decidida pelo dono, DEC-223**; substitui o preparo por prompts de FEAT-006) | VENDER, OBSERVAR | Dia/Noite |
| FEAT-040 | Câmera de segurança noturna (2026-10-14, Rascunho; **implementada Provisória na TASK-285**) | OBSERVAR, SOBREVIVER | Noite |
| FEAT-041 | Entrega arrastando + indicador DELIVER (2026-10-14, Provisório) | VENDER | Dia/Noite |

---

# Run

### FEAT-001 — Lobby, party e seleção de classe

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-012, DEC-034, DEC-047, DEC-067, DEC-069, DEC-098, DEC-121]**
- Resumo: no lobby o jogador forma party de 1–4, escolhe classe e entra num servidor reservado. O lobby é o único lugar com "dono" da party; dentro da run não há líder **[DEC-067]**.
  O **roster** da run é a lista de membros da party no "Start". Ninguém fora do roster entra; membro do roster que chega atrasado entra quando chegar **[DEC-098]**.

| Regra | Valor |
|---|---|
| Tamanho da party | 1–4 **[DEC-012, DEC-034]** |
| Formação | convite/entrada numa party do lobby; qualquer membro pode sair antes do início |
| Início da run | quem criou a party aciona "Start" (só no lobby); contagem de 5 s; teleporte do roster para um servidor reservado novo |
| Janela de chegada | a run começa quando todo o roster chegou **ou** 60 s depois do 1º a chegar, o que vier antes **[DEC-098]** |
| Membro atrasado | entra quando chegar, a qualquer momento enquanto a run vive (inclusive na janela de 15 min do snapshot, DEC-080); spawna como um jogador que reconecta sem estado (FEAT-030) **[DEC-098]** (proposta para **Q-112 b**) |
| Classe | escolhida no lobby, travada até o fim da run **[DEC-069]**; padrão Rookie (CLS-001); o atrasado usa a classe que tinha no "Start" |
| Tamanho para preços (trailer e Rescue Whistle) | membros do roster que **entraram no servidor até o fim do Day 1**; fixo dali em diante, não muda se alguém sair **[DEC-047, DEC-121]** |
| Entrada de fora do roster | proibida **[DEC-067]** |
| Reconexão | ver FEAT-030 |

Spawn do atrasado (proposta, **Q-112 c, d**; alinhado com a sugestão do narrative-writer em `script.md` §1):

| Momento da chegada | Onde aparece | Estado |
|---|---|---|
| Durante a abertura da run | sem cutscene de abertura (DEC-309): o atrasado spawna normalmente no seu ponto de trabalho | normal |
| De dia | ao lado do veículo, sem cutscene | normal |
| À noite | dentro do trailer | sanidade inicial da classe; vale como ativo a partir do spawn (pode encerrar uma janela de "todos caídos", FEAT-034) |
| Durante ligação do chefe | ouve só as linhas restantes (FEAT-018) | — |

- Dados: `Classes` (CLS), `PartyConfig` (tamanho máx., janela de chegada 60 s, dia de leitura do tamanho = 1).
- Party: o atrasado conta no voto de pular só nas cutscenes em que está (o final, FEAT-027); conta no fluxo de clientes a partir do **início do turno seguinte** (FEAT-009). Gemas: só de eventos que ocorrerem com ele no servidor **[DEC-104]**.
- Fora do MVP: matchmaking público, convites cross-server.
- Critérios de aceite:
  - Party de 5 não pode ser formada.
  - Jogador sem classe comprada entra como Rookie.
  - Depois do teleporte, nenhum jogador fora do roster consegue entrar no servidor da run.
  - Com 1 membro sem chegar, a run começa 60 s depois do 1º a chegar; o atrasado entra no Day 2 e spawna ao lado do veículo sem cutscene.
  - Party de 3 em que o 3º chega no Day 1: preço do trailer = $570. Chega no Day 2: preço = $450 **[DEC-121]**.
  - Party de 3 em que o 3º chega no Day 1 e sai no Day 3: o preço continua $570 **[DEC-121]**.
  - Atrasado que conecta no início da run spawna normalmente, sem cutscene (DEC-205 emendada pela DEC-309).
  - A classe exibida no lobby é a classe aplicada na run, e não muda até o fim dela.

### FEAT-002 — Estrutura da run (máquina de estados)

- Status: Rascunho · Pilares: PROGREDIR, DESCOBRIR · Origem: **[DEC-024, DEC-028, DEC-035, DEC-036, DEC-037, DEC-053, DEC-057, DEC-058, DEC-060, DEC-065, DEC-067, DEC-080, DEC-110, DEC-112, DEC-119, DEC-127]**
- Resumo: a run é uma sequência de turnos controlada pelo servidor, definida pela tabela `RunConfig` (cenário L).

**NOVO FLUXO (pedido do dono 2026-10-12, PROVISÓRIO, Q-207; vale sobre o texto abaixo):** D1 (tutorial, só dia) → D2 → N1 → D3 → N2 → … → D11 → N10 → Finale.
Todo dia a partir do Day 2 é seguido da noite no **carrinho**; o trailer é opcional (FEAT-016) e a noite *k* é jogada no Day *k* + 1. `RunParams.NightsFromDay = 2`.
Não existe modo dia infinito (FEAT-017 removido). Estados antigos, mantidos como histórico:

Estados (HISTÓRICO, substituído pelo bloco acima):

```
RunStart → Noite 1 (Call) ou Day(1) (Prep) → Day(1) → Day(2) … → Day(n)
Day(n) com trailer comprado no turno → Night(1)
Night(k) vencida → Day(n+1) → Night(k+1) …
Night(k) perdida com a chance ainda não usada → Night(k) de novo (snapshot)   (FEAT-026) [DEC-110, DEC-112]
Night(k) perdida com a chance já usada → RunEnd(falha)
Night(10) vencida → Finale (FEAT-027) → RunEnd(sucesso)
Day(n≥5) sem compra → Day(n+1) indefinidamente (modo dia infinito, FEAT-017)
Último jogador sai do servidor ou o servidor cai → Suspensa (snapshot do início do turno, TTL 15 min)   [DEC-080, DEC-119]
Suspensa + alguém do roster volta em ≤ 15 min → início do turno corrente (estado do snapshot)
Suspensa + ninguém volta em 15 min → RunEnd(abandono)                                [DEC-067, DEC-080]
```

Snapshot de turno **[DEC-080]**: tirado no início da Preparação de **todo** turno (dia e noite). É o mesmo snapshot que a noite perdida restaura (FEAT-026). Guarda o estado da party (dinheiro, estoque, upgrades, veículo, dia/noite atual, chance do chefe usada ou não, oferta especial da bancada — FEAT-035) e o de cada jogador do roster (Tools, sanidade inicial, flag de espectador permanente). A flag de espectador é usada na **retomada** (DEC-080/DEC-119: volta como estava); na **noite repetida** ela é ignorada e todos voltam `Active` **[DEC-111, DEC-113]** (FEAT-026). Turno interrompido não credita gemas (o evento "turno concluído" não ocorreu, DEC-104).

| Parâmetro `RunConfig` (cenário L) | Valor | Origem |
|---|---|---|
| Dia de liberação do trailer | ~~5~~ depois da noite 2 (`Content.Trailer.OfferAfterNight`; Provisório 2026-10-12) | DEC-037 (emendado, Q-207) |
| Primeiro dia seguido de noite | 2 (`RunParams.NightsFromDay`; Provisório 2026-10-12) | pedido do dono |
| Noites | 10 | DEC-027, DEC-060 |
| Duração da noite N (min reais) | ~~20 … 30~~ **9, 9,7, 10,3, 11, 11,7, 12,3, 13, 13,7, 14,3, 15** (540 s + 40 s por noite; Provisório 2026-10-12) | DEC-127 (números emendados, Q-207) |
| Chances do chefe | **1 por run inteira** | DEC-110, DEC-112 (emenda DEC-057) |
| Dinheiro inicial | $30 | DEC-045 |
| Estoque inicial | cheio (capacidade nível 1) | DEC-049 |
| Alternância após trailer | dia, noite, dia, noite… | DEC-036 |

Duração estimada da run completa no fluxo novo: ~2 min de intro + 11 dias × 4,6 min + 10 noites (120 min + ~2,9 min de ligação/preparação/resumo cada) + final ~2,5 min ≈ **204 min (~3,4 h)**; `progression.md` §0.
Estimativa antiga (histórico): 1 min de intro + 14 dias × 7,5 min + 10 noites (250 min + ~2,5 min de Preparação/ligação/resumo cada) + final ~3 min ≈ **384 min (~6,4 h)**. Detalhe em `progression.md` §2.

- Party: estado da run é da party **[DEC-059]**; sanidade, Tools e classe são por jogador **[DEC-056, DEC-069]**.
- Critérios de aceite:
  - Trocar a tabela `RunConfig` muda nº de noites, dia do trailer e durações sem alterar código.
  - O turno seguinte a um dia com compra do trailer é sempre Night(1); depois as noites e dias alternam.
  - RunEnd(sucesso) só acontece depois de Night(10) vencida.
  - A 1ª noite perdida da run repete a mesma noite; a 2ª noite perdida (a mesma repetida ou qualquer outra) leva a RunEnd(falha) **[DEC-110, DEC-112]**.
  - Com 0 jogadores no servidor, a run fica suspensa; um jogador do roster que volta em 14 min recomeça o turno corrente do início, com o dinheiro e o estoque do snapshot.
  - Com 0 jogadores por mais de 15 min, a run termina e não pode ser retomada.

### FEAT-003 — Relógio e turnos (ciclo dia/noite)

- Status: Rascunho · Pilares: GERENCIAR, OBSERVAR · Origem: **[DEC-048, DEC-024, DEC-036]**
- Resumo: relógio de jogo no servidor; o turno termina pelo relógio.

Turno de dia **[DEC-048]** (durações encurtadas por feedback de playtest 2026-10-11, **Provisório, Q-200**: turno ≈ 4,6 min, era 7,7; valores só em `Content.Shift`, sem número de dia):

| Fase | Relógio | Tempo real | O que acontece |
|---|---|---|---|
| Preparação | 7:00 → 8:00 AM | até 30 s | sem clientes nem ladrão; mercado aberto; upgrades; ligação do dia (FEAT-018). Prompt "Open Shop" na placa (qualquer jogador) abre antes |
| Loja aberta | 8:00 AM → 6:00 PM | 216 s (1 h = 21,6 s) | clientes, ladrão |
| Fechamento | 6:00 PM | até 20 s | placa "CLOSED"; não nasce cliente; fila do balcão ainda é atendida; termina quando o balcão esvazia ou em 20 s |
| Resumo | — | 8 s | tela de turno (FEAT-014) |

Turno de noite (proposta; duração D_N de `RunConfig`):

| Fase | Relógio | Tempo real | O que acontece |
|---|---|---|---|
| Preparação | 7:00 → 8:00 PM | até 90 s | telefone toca; ligação do chefe (FEAT-018); depois da ligação, prompt "Open Shop" disponível |
| Calma | 8:00 → 9:00 PM | D_N × 6 s | só clientes normais; nenhuma ocorrência de anomalia |
| Turno | 9:00 PM → 5:00 AM | D_N × 48 s | clientes + ocorrências de anomalia (FEAT-022) |
| Últimos clientes | 5:00 → 6:00 AM | D_N × 6 s | sem estreia de anomalia; repetidas permitidas. **Exceção Night 10**: Hush roteirizado às 5:45 AM (FEAT-027) |
| Fechamento | 6:00 AM | até 30 s | igual ao dia (Night 10 vencida: vai direto ao Final, FEAT-027) |
| Resumo | — | 20 s | tela de noite (FEAT-014, FEAT-026) |

1 h de jogo à noite = D_N × 6 s (noite 1: 120 s; noite 10: 180 s).

| Regra | Valor |
|---|---|
| Formato do HUD | 12 h em inglês, "8:00 AM"; atualiza a cada 10 min de jogo **[DEC-048]** |
| Autoridade | servidor; igual para toda a party |
| Pausa | o relógio **nunca pausa**, nem com jogador desconectado **[DEC-085 a]** (exceção já prevista: Preparação da noite espera a ligação acabar, FEAT-018) |
| Contador | "Day N" e "Night K" no HUD; o dia infinito continua contando **[DEC-048]** |

- Critérios de aceite:
  - Nenhum cliente nasce antes de 8:00 AM/PM nem depois de 6:00 PM/AM.
  - Às 6:00 a placa vira "CLOSED" e o turno termina em ≤ 30 s.
  - Nenhuma ocorrência de anomalia começa antes de 9:00 PM.
  - O horário exibido é idêntico para todos os jogadores (diferença ≤ 1 atualização).
  - Com um jogador desconectado, o relógio continua no mesmo ritmo.

### FEAT-004 — Cutscenes: início e voto para pular

- Status: Rascunho · Pilares: DESCOBRIR · Origem: **[DEC-021, DEC-008, DEC-039, DEC-067, DEC-078, DEC-088, DEC-097, DEC-098]**; emenda **DEC-309** (intro removida)
- Resumo: sistema único de cutscene, controlado pelo servidor e igual para toda a party. Câmera em **1ª pessoa (POV do próprio avatar)**; cena **compartilhada**: cada jogador vê os avatares R6 dos colegas na cena, o próprio não **[DEC-088, DEC-097]**.
  Os avatares andam por trilhos roteirizados (o jogador não controla o movimento durante a cutscene; só olha em volta, com limite de ±60° do eixo do plano). Cada client renderiza a cena localmente, sincronizada pelo servidor.
  Duas cutscenes: **final** e **créditos** (FEAT-027). A cutscene de **abertura (intro) foi removida** a pedido do dono (**DEC-309**): a run nova entra direto na primeira fase do turno (Noite 1: ligação do chefe, DEC-300).

O que é e o que não é cutscene (proposta):

| Sequência | Cutscene? | Pulável? |
|---|---|---|
| ~~Intro (`cs_intro`)~~ removida (DEC-309) | — | — |
| Final: revelação (`cs_finale`) e créditos + pós-créditos (`cs_credits`) | sim (2 segmentos) | sim, voto por segmento |
| Fade da troca de veículo (FEAT-016), sequência de derrota (FEAT-026), desmaio e ambulância (FEAT-034) | não: transições/sequências no mundo | não |
| Ligações do chefe (FEAT-018) | não | não (e não se repetem) |

| Parâmetro | Valor |
|---|---|
| Intro | **removida** (DEC-309); as linhas abaixo sobre a intro são histórico |
| Quando | final uma vez por run (a intro deixou de existir, DEC-309) |
| Sincronia | o **servidor** inicia e encerra; todos os clients tocam a mesma cutscene no mesmo instante (tolerância ≤ 0,5 s) |
| Voto | durante a cutscene, hold 1 s no botão de interagir = "Skip"; o voto é individual, não se desfaz e vale só para o segmento atual |
| Limiar | pula quando votos ≥ **ceil(50% × jogadores conectados)**: 1p 1 · 2p 1 · 3p 2 · 4p 2 **[DEC-078]** (proposta para **Q-077 a**) |
| Quem vota | todo jogador **conectado e dentro da cutscene**, inclusive espectador permanente (FEAT-025); desconectado e atrasado fora da cutscene não contam |
| Indicador | dica "Hold to skip" e contador "Skip 1/2" no canto da tela só durante a cutscene (não é HUD, DEC-015) |
| Mudou a party | se alguém desconecta ou reconecta, o limiar é recalculado na hora; votos de quem saiu deixam de contar |
| 1ª vez na conta | também pode pular (a regra anterior "só quem já viu" foi descartada) |
| Reconexão / atrasado | quem **já estava** na cutscene e reconecta entra no ponto atual, já no trilho do seu avatar; o atrasado que nunca entrou spawna normalmente (FEAT-001, DEC-309); quem conecta depois não revê **[DEC-098]** |
| (removido) | linha da intro retirada (DEC-309) |
| (removido) | linha da intro retirada (DEC-309) |

- Dados: `Cutscenes` (id, segmentos, duração máx., pulável, limiar de voto = 0,5).
- Critérios de aceite:
  - Solo: hold 1 s pula a cutscene na hora.
  - Party de 4: 1 voto não pula; 2 votos pulam para todos ao mesmo tempo.
  - Party de 3 com 1 desconectado durante a cutscene: o limiar cai de 2 para 1 sem reiniciar a cutscene.
  - Nenhuma transição, sequência de ambulância nem ligação oferece "Skip".
  - Party de 4: cada jogador vê os outros 3 avatares na cena e não vê o próprio corpo; a câmera é a do próprio avatar.

---

# Base de interação

### FEAT-005 — Interação: prompt no mundo e hotbar

- Status: Rascunho · Pilares: VENDER · Origem: **[DEC-015, DEC-040, DEC-054, DEC-066, DEC-014, DEC-097, DEC-100]**
- Resumo: toda ação é prompt custom no mundo (porte do AnimalPlane) ou uso de Tool na hotbar nativa. Nenhum botão de ação exclusivo na tela, com duas exceções já decididas e só em estados especiais: "Skip" de cutscene (DEC-078) e oferta de reviver no spectate (DEC-092, FEAT-034).
  Personagem R6, câmera 1ª pessoa padrão do Roblox, **sem braços**: só a Tool aparece na mão **[DEC-097]**.

Durações de prompt (tabela `PromptTimings`):

| Ação | Tipo | Duração |
|---|---|---|
| "Grill" / "Collect" / "Add Sausage" / "Take Order" / "Serve" / "Lights" (interruptor) | toque | 0 s |
| "Slice Bun", comprar pacote no Mart, "Close Window"/"Open Window" (janela do trailer, DEC-221), "Throw Away", "Take" (item alterado ou item no chão, FEAT-036), "Give" (café) | hold | 0,5 s |
| "Add {item}" **[DEC-072]**, "Restock", "Refuse", "Brew Coffee" **[DEC-055]**, voto "Skip" em cutscene (FEAT-004) | hold | 1 s |
| Comprar upgrade ou item especial na bancada do Mart (FEAT-015, FEAT-035) | hold | 1,5 s |
| "Blow Whistle": colega `Active` usa o Rescue Whistle (ITM-021) para reviver um caído, ativando a Tool na mão | hold | 1,5 s |
| Comprar trailer | hold | 2 s |

| Regra | Valor |
|---|---|
| Alcance | estações 7 studs; clientes 10 studs; placas e veículo 10 studs |
| Alvo | prompt mais próximo do centro da tela **[DEC-066]** |
| Prompt condicional | só aparece quando a ação é possível (ex.: "Add Ketchup" só com Hot Dog na mão) |

Limite da hotbar (proposta para **Q-056**):

| Categoria | Máximo por jogador |
|---|---|
| Pacotes do mercado (ITM-011 a ITM-019) | 2 **[DEC-049]** (Hauler 3, DEC-069) |
| Hot Dog montado (ITM-010) | 2 |
| Coffee (ITM-009) | 1 |
| Item alterado (ITM-020) | 1 |
| Rescue Whistle (ITM-021) | 1 **[DEC-100]** |
| **Total** | **4** (Hauler 4 também; a 3ª vaga de pacote ocupa uma vaga do total) |

Risco: a hotbar nativa em celular pequeno pode exibir menos de 4 slots. Pedir ao researcher a contagem real por resolução antes da bandeira verde.
Atropelamento derruba **só a Tool equipada** (FEAT-033, FEAT-036); o resto da hotbar fica.

Recusas do servidor e avisos (TASK-081; `wave-1-report.md` D-04; **Provisório**, Rascunho)

O client esconde o prompt de ação impossível, mas o servidor ainda pode recusar uma ação que **era** possível na tela
do jogador um instante antes: um colega pegou a última vaga, o estoque acabou, a fase virou. Recusa silenciosa nesses
casos parece bug. Regra:

| Tipo de recusa | Aviso | Por quê |
|---|---|---|
| **Estado do jogo mudou** (corrida entre jogadores, latência, virada de fase) | toast **só para quem agiu** (`Audience = "Player"`), canto superior direito, 2,5 s | o jogador fez a coisa certa e precisa saber o motivo |
| Validação anti-trapaça (fora do alcance, âncora errada, ação de outra onda, gate de taxa, não é membro) | **nenhum** (só log de dev) | jogador legítimo não chega aqui; avisar ajuda quem forja |
| Gate de estado de vida (`Down`, `Spectator`, atropelado, cutscene) | **nenhum** | o HUD/câmera já explicam o estado |
| Janela do trailer fechada (DEC-221) em "Take Order"/"Serve"/"Refuse" | toast `shutter_closed` só na corrida (o prompt some com a janela fechada) | colega fechou enquanto o jogador tocava |
| Anti-spam | o mesmo aviso no máximo 1× a cada **2 s** por jogador | segurar o botão na corrida não pode empilhar toasts |

Lista D-04 (quais recusas viram toast). Chaves e textos = proposta do narrative-writer em `ui-text.md` §10.3 (TASK-082);
nome final da chave é do architect (TASK-047). Esta tabela decide **quais** recusas avisam: **todas as 10**.

| # | Recusa (D-04) | Como um jogador legítimo chega nela | Toast? | Chave (`ui-text.md` §10.3) | `ValueFrom` |
|---|---|---|---|---|---|
| 1 | "Grill" com grelha sem vaga | colega ocupou a última vaga | sim | `grill_full` | None |
| 2 | "Grill"/"Slice Bun"/"Add {item}" sem estoque | colega usou a última unidade | sim | `out_of_stock` | Ingredients |
| 3 | "Slice Bun" com tábua sem vaga | colega ocupou a última vaga | sim | `board_full` | None |
| 4 | "Add {item}" com 3 complementos | quase nunca (prompt escondido); custo zero, mesmo caminho de recusa | sim | `topping_max` | None |
| 5 | "Add {item}" repetido | quase nunca; idem | sim | `topping_repeat` | Ingredients |
| 6 | "Restock" com estoque cheio (inclui estoque acima da capacidade, `Q-169`) | colega repôs antes | sim | `stock_full` | Ingredients |
| 7 | Comprar pacote de prateleira `Blocked` | prompt visível na virada do turno ou na compra do trailer | sim | `shelf_locked` | Ingredients |
| 8 | Bancada `busy` | dois jogadores comprando a mesma posição | sim | `bench_busy` | None |
| 9 | Bancada `Maxed` | colega comprou o último nível antes | sim | `upgrade_maxed` | Upgrades |
| 10 | "Take Order" fora de venda (fase sem `Selling` e fora do `Closing`) | o turno virou durante o toque | sim | `shop_closed` | None |

Fora da D-04, mesma regra (chaves aceitas e criadas em `Notices` pela TASK-047): "Collect" com trilho cheio → `rail_full`
(texto com o narrative-writer); beber café de dia → `coffee_night_only` (FEAT-021, `Q-170`); "Give" café a quem já tem
1 → `coffee_has_one` (`ui-text.md` §10.2). Já existem e seguem: `hands_full`, `package_limit`, `not_enough_cash`,
`coffee_cooldown`, `coffee_full`. `hide_taken` sai com o esconderijo (DEC-221); entra `shutter_closed`.

- Critérios de aceite:
  - Toda ação do MVP é executável no mobile só com o botão de interagir, o toque na hotbar e a câmera.
  - Prompt de ação impossível não aparece.
  - Pegar o 5º Tool é bloqueado e o prompt explica ("Hands full"); o mesmo vale para "Take" e para comprar o Rescue Whistle com a hotbar cheia.
  - Dois jogadores disputando a última vaga da grelha (ou da tábua, ou o último nível da bancada): quem perde recebe o toast da tabela, e só ele.
  - Ação forjada (fora do alcance, âncora errada, outra onda) é descartada **sem** toast.
  - Segurar a ação recusada por 10 s gera no máximo 5 toasts iguais (1 a cada 2 s).
  - As 10 recusas da tabela têm chave em `Notices` com `Audience = "Player"`.

---

# Dia (e o trabalho que continua à noite)

### FEAT-006 — Preparo por estações

- Status: Rascunho · Pilares: VENDER · Origem: **[DEC-016, DEC-004, DEC-029, DEC-072]**
- Resumo: salsicha → grelha → trilho de descanso; pão → tábua; salsicha no pão vira Tool "Hot Dog"; complementos nas estações; entrega no cliente.
- **SUBSTITUÍDO NO PREPARO (DEC-223, 2026-10-12):** o modo de prompts no mundo (passos 1 a 6 abaixo: caixa de salsicha, grelha, trilho, pão, tábua, complementos) é **substituído** pelo modo de preparo focado **V1** (FEAT-039), 100% focado, com abas de estação. Esta ficha segue valendo como **referência de regras** (consumo de estoque, tempos da grelha 12/10/8 s, sem queimar, Tool "HotDog", Completo/Incompleto/Errado) e como **modo atual até o focado existir em código**; **não** é mais o piso nem o alvo. `Q-218` decidida; pendências `Q-219`, `Q-221` a `Q-223`.

| Passo | Estação | Ação | Resultado | Números |
|---|---|---|---|---|
| 1 | Caixa de salsicha | toque "Grill" | consome 1 salsicha do estoque; vai para uma vaga livre da grelha | exige vaga livre |
| 2 | Grelha (UPG-001) | automático | barra de progresso sobre a salsicha **[DEC-015]** | 12 s / 10 s / 8 s por nível; Line Cook −15% nas dele |
| 3 | Grelha | toque "Collect" na salsicha pronta | vai para o trilho de descanso (fila: a mais antiga sai primeiro) | trilho: 6 (carrinho), 8 (trailer) |
| 4 | Caixa de pão | hold 0,5 s "Slice Bun" | consome 1 pão; pão vai para uma tábua livre e é cortado | corte automático 1,5 s; tábua com vagas compartilhadas: **2 (carrinho), 3 (trailer) [DEC-190, DEC-215]** |
| 5 | Tábua | toque "Add Sausage" (trilho com ≥1) | a próxima salsicha do trilho entra no pão; vira Tool **Hot Dog** (ITM-010) na mão de quem tocou; a tábua libera | — |
| 6 | Estação de complemento | hold 1 s "Add {item}" com Hot Dog na mão | consome 1 uso do complemento; adiciona ao Hot Dog | 1 por complemento; não repete |
| 7 | Cliente | toque "Serve" com Hot Dog na mão | entrega (FEAT-011) | — |
| — | Lixeira | hold 0,5 s "Throw Away" | descarta o Hot Dog na mão (ou item alterado da N2, FEAT-023) | ingredientes perdidos |

| Regra | Valor |
|---|---|
| Queimar salsicha | **não** no MVP (salsicha pronta espera na grelha sem prazo; ocupa a vaga) |
| Remover complemento | impossível; erro = lixeira |
| Tempo de montagem de referência | K = 3 com salsicha pronta ≈ 0,5 + 1,5 + 0 + 3 + deslocamento ≈ 8–10 s **[proposals-round-2 §3.6]** |
| Feedback | barra de progresso no mundo (AnimalPlane, DEC-029); VFX de "pronto" |
| Visual | o Hot Dog na mão mostra os complementos (modelo muda) |

- Dados: `Stations` (tipo, capacidade por veículo), `PromptTimings`, `Ingredients`.
- Party: qualquer jogador usa qualquer estação; vaga de grelha e tábua são reservadas no servidor no toque (sem conflito).
- Fora do MVP: queimar, panela de chili, montagem em lote.
- Critérios de aceite:
  - Salsicha só vai à grelha com vaga livre e estoque ≥ 1; o estoque cai exatamente 1.
  - O tempo da barra bate com o nível da grelha (±0,2 s) e com o bônus do Line Cook só nas salsichas que ele colocou.
  - "Add X" não aparece para complemento já presente no Hot Dog, nem com estoque 0.
  - Dois jogadores tocando a mesma tábua ao mesmo tempo: só um recebe o Hot Dog.

### FEAT-007 — Estoque e Restock

> Pacote grátis do dia de liberação (DEC-071, 2026-10-11, Provisório): todo dia que começa (fluxo normal, `/dev day`, Conch `day`, retomada) põe no mundo o pacote de **todo** ingrediente com `1 < UnlockDay <= dia` ainda não dado na run (inclui dias pulados; uma vez cada, flag `Given` no snapshot `Fp`). Pegar com a hotbar/limite de pacotes **cheios** não bloqueia: o pacote vai **direto para o estoque** do ingrediente (bandeja, até a capacidade) com o toast "New: {item} (stocked)" (`ingredient_stocked`). Com espaço na mão: o pacote vai para a mão (comportamento anterior), o estoque enche no Restock normal.

- Status: Rascunho · Pilares: GERENCIAR · Origem: **[DEC-017, DEC-031, DEC-049, DEC-071]**
- Resumo: cada ingrediente tem estoque na estação, com capacidade pelo nível do Cooler (UPG-002). Estação consome; Restock enche com pacote do mercado.

| Ingrediente | Nível 1 | Cooler 2 | Cooler 3 | Origem |
|---|---|---|---|---|
| Sausage, Bun | 12 | 20 | 30 | DEC-049 |
| Cheese, Bacon | 8 | 14 | 20 | DEC-049 |
| Ketchup, Mustard (usos) | 30 | **50** | **75** | nível 1 DEC-049; 2/3 propostos aqui (×5/3, ×2,5) |
| Potato Sticks (usos) | 15 | 25 | 35 | DEC-071 |
| Cream Cheese (usos) | 12 | **20** | **30** | nível 1 DEC-071; 2/3 propostos para **Q-062** (×5/3, ×2,5) |
| Coffee (doses, só trailer) | 20 | 20 | 20 | proposta; Cooler não afeta café |

| Regra | Valor |
|---|---|
| Restock | hold 1 s com pacote na mão na estação do ingrediente; transfere min(sobra do pacote, capacidade − atual) **[DEC-049]** |
| Sobra | fica no pacote (Tool guarda contagem); pacote vazio some |
| Persistência | estoque passa de turno para turno na run **[DEC-049]**; muda de veículo junto (FEAT-016) |
| Validade | **não** há validade no MVP **[DEC-128]** |
| Indicador | contador no mundo sobre cada estação ("7/12"); fica vermelho com ≤ 2 |
| Pacote grátis | no dia de liberação de um ingrediente, 1 pacote aparece na estação nova **[DEC-071]** |

- Critérios de aceite:
  - Restock nunca passa da capacidade; a sobra fica no pacote.
  - Upgrade de Cooler aumenta a capacidade na hora, sem mudar o estoque atual.
  - O estoque no início do Day(n+1) é igual ao do fim do turno anterior.

### FEAT-008 — Mercado

- Status: Rascunho · Pilares: GERENCIAR · Origem: **[DEC-031, DEC-049, DEC-071, DEC-041, DEC-079, DEC-101, DEC-106, DEC-109]**
- Resumo: o **Ninth Street Mart** (24 h, letreiro "OPEN 24 HOURS"), a 100–120 studs com linha de visão para o carrinho/trailer. Três áreas **[DEC-101]**:
  **prateleiras** (pacotes de ingrediente e café, preço fixo, nunca rotacionam), **expositor de frutas/verduras** (só cenário, sem prompt **[DEC-109]**) e **bancada de upgrades** na parede do fundo (FEAT-015, FEAT-035).
  Atendente Opal (NPC-020) é ambiente com falas, não vende. À noite, o letreiro é o ponto seguro da ANM-010 (FEAT-020).

| Regra | Valor |
|---|---|
| Compra | hold 0,5 s na prateleira; debita o dinheiro da party; Tool do pacote na mão **[DEC-049]** |
| Preços | tabela em `items.md` (ITM-011 a ITM-019) |
| Limite | 2 pacotes por jogador (Hauler 3) **[DEC-049, DEC-069]**; dentro do total de 4 Tools (FEAT-005) |
| Horário | aberto em todas as fases de todos os turnos, inclusive à noite **[DEC-049]** |
| Bloqueio | prateleira de ingrediente ainda não liberado mostra o pacote com a etiqueta "Out of stock" e, embaixo, "Day N" (proposta para **Q-088**); Coffee só aparece depois do trailer |
| Sem saldo | prompt mostra preço em vermelho e não executa |
| Prateleiras rotacionam? | **não**: ingredientes sempre à venda pelo preço da tabela (DEC-049; proposta para **Q-120 g**) |
| Seções (Mart v2, 2026-10-11, Provisório) | BAKERY (Buns), MEAT & DELI (Sausages, Bacon), SAUCES (Ketchup, Mustard), SNACKS · COFFEE (Potato Sticks, Ground Coffee), DAIRY (Cheese, Cream Cheese), FRESH PRODUCE (cenário); 3 corredores de 6 studs; caixa sai, Opal vai para a bancada (`Q-175`); pacotes seguem na prateleira (`Q-177`). Planta: `MAP-01.md` §18 |

- Critérios de aceite:
  - O expositor de frutas/verduras não tem nenhum prompt.
  - Comprar sem saldo é impossível; a party nunca fica negativa.
  - Duas compras simultâneas de jogadores diferentes nunca gastam mais que o saldo.
  - Da porta do mercado, um jogador em pé enxerga a gaveta do carrinho (verificação do level-designer).

### FEAT-009 — Fluxo de clientes e teto de NPC

- Status: Rascunho · Pilares: VENDER · Origem: **[DEC-045, DEC-055, DEC-050]**
- Resumo: o servidor gera clientes num intervalo base, ajustado por dia, party e Trailer Lights; o balcão tem vagas (Counter).

| Parâmetro | Dia | Noite (proposta, **Provisório**) |
|---|---|---|
| Intervalo base solo | 22 s **[DEC-045]** | 40 s (noites 1–5) · 36 s (noites 6–10) |
| Crescimento | ×min(1 + 0,08 × (dia − 1), 1,4) na taxa **[DEC-045]** | — (a noite cresce pela duração, DEC-127, e pelo intervalo 40 → 36) |
| Party (jogadores **conectados**, recalculado no início do turno) | 1p ×1,0 · 2p ×1,6 · 3p ×2,1 · 4p ×2,5 na taxa **[DEC-045, DEC-185]** | igual |
| Trailer Lights | taxa ×1,1 **[DEC-055]** | — (de noite é luz) |
| Variação | intervalo ±25% aleatório | igual |
| Vagas no balcão (Counter, UPG-003) | 3 / 4 / 5 | igual (trailer começa no nível 1, DEC-184) |
| Teto de clientes vivos | 8 (`Flow.MaxCustomersDay`) | 6 (`Nights[k].Customers.Max`) |
| Balcão cheio ou teto atingido | o spawn é pulado (cliente não nasce; não conta para a nota) | igual |
| Fases em que nasce cliente | `Open` (`Shift.Selling`) | `Night` (`Shift.Selling`) |

Contagem de spawn (fecha L-05 do QA). O fluxo é um **relógio de tentativas**: a 1ª tentativa ocorre um intervalo
sorteado depois do início da fase de venda; cada tentativa sorteia o próximo intervalo e rearma, **com ou sem** cliente
nascido (o pulado não é guardado para depois). Resultado de cada tentativa: `Spawned`, `SkippedFull` (balcão cheio) ou
`SkippedCap` (teto de clientes ou de NPC). Cliente-anomalia (FEAT-022) ocupa uma tentativa como `Spawned`.

Dados da noite (`content-data.md` §6.3, §6.8; valores **Provisórios** da TASK-081):

| Campo | Valor | Regra |
|---|---|---|
| `Flow.NightInterval` | **40** | intervalo de referência da noite (solo, s) |
| `Nights[k].Customers.BaseInterval` | 40 (k = 1–5) · **36** (k = 6–10) | a linha da noite manda; `Flow.NightInterval` é o fallback (`Validate`: 1–600) |
| `Nights[k].Customers.Max` | **6** em todas | `Validate`: ≤ `Flow.MaxCustomersNight` (6) |
| Crescimento e Trailer Lights | não se aplicam à noite | — |

| Noite | Duração (s, DEC-127) | Intervalo | Tentativas solo | 2p | 4p (limitado por balcão e teto) |
|---|---|---|---|---|---|
| 1 | 1200 | 40 | 30 | 48 | 75 |
| 2 | 1260 | 40 | 31 | 50 | 79 |
| 3 | 1320 | 40 | 33 | 53 | 82 |
| 4 | 1380 | 40 | 34 | 55 | 86 |
| 5 | 1440 | 40 | 36 | 58 | 90 |
| 6 | 1560 | 36 | 43 | 69 | 108 |
| 7 | 1620 | 36 | 45 | 72 | 112 |
| 8 | 1680 | 36 | 47 | 75 | 117 |
| 9 | 1740 | 36 | 48 | 77 | 121 |
| 10 | 1800 | 36 | 50 | 80 | 125 |

Por que 40/36 s: à noite a atenção é dividida com anomalias, escuro e café; com 40 s o solo tem ~1 cliente por minuto e
meio, folga para olhar a rua (OBSERVAR) sem a loja ficar vazia (VENDER). Lucro solo resultante: $120 (N1) → $174 (N10),
`economy.md` §5.2, dentro do alvo de `economy.md` §10. A queda para 36 s na N6 coincide com o 2º terço da run e
compensa o equipamento do trailer já melhorado. Lucro por minuto de noite (~$6/min) fica abaixo do dia (~$13–18/min)
de propósito: a noite paga em gemas (FEAT-029), não em dinheiro.

Teto de NPC simultâneo por servidor: **12** humanoides com IA de servidor **[DEC-045]**. Veículos têm teto próprio (FEAT-033). Proposta (**Q-091 a**): Opal é estática, sem pathfinding, e sai do teto de 12; o slot liberado fica de folga.

| Turno | Clientes (inclui Mr. Pickett) | Ladrão | Atores de anomalia | Pedestres (NPC-019) | Total no teto | Fora do teto |
|---|---|---|---|---|---|---|
| Dia | 8 | 1 | 0 | 2 | 11 (1 de folga) | Opal; carros de trânsito (NPC-022) |
| Noite | 6 | 0 | 3 | 1–2 (0 em tensão) **[DEC-183]** | 10–11 (1–2 de folga; se os passantes ficarem fora do teto, `Q-162`, 9) | Opal; ambulância e médicos (NPC-023/024, visuais); ≤ 1 carro até 9 PM (NPC-022) e a ANM-008 (teto de veículos) |

Clientes contam desde o nascimento até sumirem (andando + no balcão + indo embora). Alucinações (FEAT-019) são só no client e não contam.

**Passante vira cliente (Provisório, pedido do usuário 2026-10-11, TASK-163; números em `Content.Flow.Adopt`).** Para
imersão e para o primeiro cliente não demorar: ~0,8 s antes de uma tentativa, com chance de **50% de dia / 15% à noite**
(no máximo 1 a cada 8 s), o passante mais perto de Q5 (≤ 60 studs, fora da faixa) cuja espécie e roupa cabem num tipo
de cliente liberado no turno **para** na calçada; na tentativa ele vira esse cliente no mesmo lugar (mesma espécie e
roupa, sem o acessório do tipo), fica 0,6 s de frente para o carrinho e segue a rota normal até Q5. Ele sai da conta de
passantes (a rua repõe um novo pela ponta de um caminho) e entra na de clientes (teto, balcão, nota). Se a tentativa
der dupla, balcão cheio ou teto, ele só volta a andar. Nunca: cliente do tutorial, ator de anomalia, ladrão, dupla (os
passantes andam sozinhos), tensão (rua deserta). À noite os passantes ficam no extremo oeste (MAP-01 §9.8), então quase
nenhum está no raio. A **1ª tentativa** de cada fase de venda passa a ser 3–5 s depois do início (era um intervalo
inteiro, ~22 s): primeiro cliente em Q5 em ~8–12 s. No Day 1 isso soma ~1 tentativa no `Open` (16 → 17, dentro de 14–18).
Limite: só 8 das 17 espécies de passante têm tipo de cliente (Day 1: pinguim, hamster, rato, sapo), então a adoção
depende de haver um desses perto.

Party e reconexão (proposta para **Q-067**): o multiplicador de party usa os jogadores **ativos no início do turno** = conectados e não espectadores permanentes (FEAT-025). Quem cai, sai ou chega no meio do turno não muda o fluxo até o próximo. Preços do trailer e do Rescue Whistle continuam fixos pela party do fim do Day 1 (FEAT-001) **[DEC-047, DEC-121]**.

- Critérios de aceite (método: contador de tentativas do `CustomerService` por resultado, lido por log/comando de dev;
  turno real ou relógio acelerado pelo dev, a fórmula é a mesma):
  - Nunca há mais de 12 NPCs de servidor vivos.
  - Solo, Day 1, conta-se **tentativas** (não nascidos): cada um de 5 turnos de `Open` (216 s ÷ 14 s ≈ 15, Q-200) tem **12–17**
    tentativas. Para medir nascidos = tentativas, o testador mantém o balcão com vaga (Refuse ou serve rápido);
    nesse caso `SkippedFull = 0` e nascidos = tentativas.
  - Com o balcão cheio, a tentativa sai como `SkippedFull`, nenhum cliente nasce e o relógio rearma (o pulado não vira
    fila nem nasce depois); tentativas = `Spawned` + `SkippedFull` + `SkippedCap` em qualquer turno.
  - Solo, Night 1: **28–32** tentativas na fase `Night` (1200 s ÷ 40 s); Night 10: **47–53** (1800 s ÷ 36 s).
  - À noite nunca há mais de 6 clientes vivos; nenhuma tentativa ocorre fora das fases com `Selling`.
  - Mudar `Nights[k].Customers.BaseInterval` muda o fluxo daquela noite sem código novo.

### FEAT-010 — Pedidos por combinação livre

- Status: Rascunho · Pilares: VENDER · Origem: **[DEC-064, DEC-071, DEC-072]**
- Resumo: ao "Take Order", o servidor sorteia o pedido: pão + salsicha + K complementos distintos dos liberados.
- **Nota (DEC-223, 2026-10-12):** as regras de pedido, preço e Completo/Incompleto/Errado **não mudam**; o que muda é **como** o jogador monta o prato: modo focado V1 (FEAT-039), não mais prompts no mundo.

| Passo | Regra |
|---|---|
| 1. K | sorteado pela tabela `OrderPhases` da fase (ver abaixo) |
| 2. Ajuste do tipo | o tipo de cliente pode deslocar K (campo `kShift` em `CustomerTypes`, `npcs.md`) |
| 3. Complementos | K distintos sorteados por peso: peso do ingrediente × multiplicador do tipo de cliente × 1,5 se liberado hoje |
| 4. Limites | máx. 3; só liberados; se K > liberados, K = liberados **[DEC-071]** |
| 5. Exibição | balão sobre o cliente com ícones, visível para toda a party **[DEC-071]** |

`OrderPhases` **[DEC-071, proposals-round-2 §3.4]**:

| Fase | K=0 | K=1 | K=2 | K=3 | K médio |
|---|---|---|---|---|---|
| Dia 1 | 10% | 60% | 30% | 0% | 1,2 |
| Dias 2–3 | 5% | 45% | 40% | 10% | 1,55 |
| Dias 4–5 | 5% | 35% | 40% | 20% | 1,75 |
| Dia 6+ (inclui dia infinito) | 0% | 30% | 40% | 30% | 2,0 |
| Noites | 0% | 30% | 40% | 30% | 2,0 |

Pesos base: Ketchup 10, Mustard 10, Cheese 7, Bacon 6, Potato Sticks 6, Cream Cheese 5 **[DEC-071]**.

- Critérios de aceite: os de `proposals-round-2.md` §3.9 (sem ingrediente não liberado, sem repetição, ≤ 3; distribuição de K em ±3 p.p. em 1.000 sorteios por fase), mais: o multiplicador do tipo de cliente altera a frequência do ingrediente na proporção da tabela (±3 p.p. em 1.000 sorteios).

### FEAT-011 — Atendimento, validação e pagamento

- Status: Rascunho · Pilares: VENDER · Origem: **[DEC-045, DEC-050, DEC-051, DEC-071, DEC-072]**

| Etapa | Regra |
|---|---|
| Chegada | cliente ocupa vaga livre do balcão. Ao chegar em Q1 começa a **paciência de fila**: 45 s (+10/+20 s com Counter 2/3), barra azul → amarela com ícone de relógio **[Q-192, Provisório; substitui a paciência única 40 + 5K da DEC-072]**. K é sorteado na chegada (oculto) |
| Take Order | toque no cliente; balão aparece; a paciência de fila termina e começa a **paciência de preparo**: 75 + 5 × K s (+ Counter), barra verde → vermelha com ícone de pão (a barra troca com animação); começa a **janela de gorjeta**: 16 + 4 × K s (Hawker −4 s) **[DEC-072; preparo: Q-192, Provisório]** |
| Serve | toque com Hot Dog na mão; validação no servidor |
| Recusar | hold 1 s "Refuse"; cliente vai embora; $0; conta como insatisfeito, salvo cliente-anomalia com verbo "recusar" (FEAT-023) **[DEC-051]** |

Validação **[DEC-072]**:

| Resultado | Condição | Pago | Gorjeta | Nota do turno |
|---|---|---|---|---|
| Completo | pão + salsicha + exatamente os complementos | $4 + Σ complementos | +$1 na janela (Hawker $2; Shift Lead $0) | satisfeito |
| Incompleto | falta ≥ 1 pedido, nada a mais | floor(50%) | — | insatisfeito |
| Errado | complemento não pedido | $0; Hot Dog volta para a mão de quem serviu | — | insatisfeito |
| Desistiu (fila) | paciência de fila zerou, ninguém atendeu (`Left`) | $0 | — | insatisfeito |
| Desistiu (preparo) | paciência de preparo zerou, a comida demorou (`Slow`; reação de reclamação própria) | $0 | — | insatisfeito **[Q-192, Provisório]** |

| Regra | Valor |
|---|---|
| Destino do pagamento | gaveta do caixa (FEAT-012), nunca direto no HUD **[DEC-050]** |
| Dinheiro | inteiro **[DEC-072]** |
| Feedback | "+$7" flutuante na gaveta; balão feliz/neutro/reclamação; fala curta (narrative-writer) |
| Errado devolvido | o Hot Dog errado volta como Tool; pode ir para outro cliente ou para a lixeira |

- Critérios de aceite:
  - Os de `proposals-round-2.md` §3.9 sobre preço, incompleto e errado.
  - Serve só aparece em cliente com pedido anotado.
  - Gorjeta nunca é paga fora da janela, nem em incompleto.
  - Toda validação acontece no servidor; o client não envia preço nem resultado.

### FEAT-012 — Gaveta do caixa (hoje: pote de gorjetas)

- Status: Rascunho · Pilares: GERENCIAR · Origem: **[DEC-050, DEC-051]**
- **Emenda 2026-10-13 [DEC-238, DEC-239]:** a gaveta saiu. Todo dinheiro de **venda** vai direto ao dinheiro da party; só **gorjeta** (balcão e mesa) cai no **pote de gorjetas**. O prompt "Collect Tips" no pote manda o conteúdo ao dinheiro da party; o que não foi coletado é depositado no Resumo junto com o bônus da nota. A tabela abaixo vale para o pote; as linhas "Entra", "Uso" e "o dinheiro não muda com vendas" estão superadas.

| Regra | Valor |
|---|---|
| Entra | todo pagamento e gorjeta do turno |
| Visível | valor no mundo sobre a gaveta (BillboardGui) **[DEC-050]** |
| Depósito | no Resumo: gaveta + bônus da nota (FEAT-014) → dinheiro da party; gaveta zera |
| Uso durante o turno | não pode ser gasto; compras usam só o dinheiro da party |
| Roubo | só o ladrão mexe (FEAT-013). À noite, a N1 pode deixar uma "moeda sem desenho" de $0 (só visual, some no resumo) |
| Noite perdida | gaveta da noite descartada (snapshot, FEAT-026) **[DEC-053]** |

- Critérios de aceite:
  - O dinheiro da party (HUD) não muda com vendas durante o turno, só no depósito.
  - O valor sobre a gaveta é igual para todos os jogadores.

### FEAT-013 — Ladrão

- Status: Rascunho · Pilares: GERENCIAR, OBSERVAR · Origem: **[DEC-018, DEC-050, DEC-023]**
- Resumo: o ladrão é **Quick Quentin** (CHR-004); comportamento completo em NPC-007 (`npcs.md`). Números **[DEC-050]**: só de dia; chance dia 1 0% · dia 2 50% · dia 3+ 70%; 1 por dia; aparece entre 9:00 AM e 3:00 PM; espreita ≤ 120 s; gatilho = nenhum jogador a ≤ 14 studs do veículo por 3 s; ~4 s até a gaveta; abre em 8 s (16 s com UPG-004); rouba floor(50%) (30% com UPG-004); nada se gaveta < $5; impedir = entrar na zona durante a abertura → foge, party +$5 ("Nice catch!"), creditado na gaveta.
- Proposta adicional: jogador "presente" na zona precisa estar **conectado e de pé** (desconectado não conta).
- **DEC-182:** a aproximação leva **4 s fixos** de qualquer ponto de espreita; velocidade = distância ÷ 4.

Dados (tabela `Thief`, `content-data.md` §6.6; números da DEC-050/DEC-182, conferidos na TASK-081):

| Campo | Valor | Origem |
|---|---|---|
| `ChanceByDay` | Day 1 **0** · Day 2 **0,5** · Day 3+ (inclui dia infinito) **0,7** | DEC-050 |
| `MaxPerDay` | 1 | DEC-050 |
| `WindowClock` | 540–900 (9:00 AM–3:00 PM, minutos de jogo) | DEC-050 |
| `LurkMax` | 120 s; depois vai embora sem roubar | DEC-050 |
| `ZoneRadius`, `ZoneEmptyTime` | 14 studs, 3 s | DEC-050 |
| `ApproachTime` | 4 s | DEC-182 |
| `OpenTime` | 8 s · 16 s com UPG-004 (efeito `DrawerOpenTime`) | DEC-050 |
| `StealPct` | 50 · 30 com UPG-004 (efeito); valor roubado = floor(gaveta × % ÷ 100) | DEC-050 |
| `MinDrawer` | 5 (gaveta < $5: abre e foge sem nada) | DEC-050 |
| `CatchReward` | 5 (na gaveta, `"Catch"`) | DEC-050 |
| `CapRetry` (proposta, campo novo → architect) | 30 s: teto de NPC cheio na hora sorteada → tenta de novo 30 s depois, até o fim da janela; passou das 3:00 PM, o dia fica sem ladrão | `npcs.md` NPC-007 |

Leitura de balanço (solo, gaveta de dia ~$70 às 2 PM no Day 3): roubo sem lock −$35 (≈ 40% do lucro do dia); com lock
−$21; impedir rende +$5. Esperado por dia (Day 3+, sem reação): 0,7 × −$35 ≈ −$24,5; com UPG-004 ≈ −$14,7 → o lock
($80) se paga em ~8 dias sem reação, menos se o jogador reage (ele dobra o tempo de reação de 8 para 16 s).

- Critérios de aceite: os de `proposals-round-1.md` Q-036, mais:
  - o +$5 aparece na gaveta e entra na nota como dinheiro, não como cliente;
  - em 1.000 dias simulados por faixa: Day 2 com ladrão em 50% ± 3 p.p., Day 3+ em 70% ± 3 p.p., Day 1 em 0;
  - de qualquer ponto L1–L3, da partida até a gaveta: 4,0 ± 0,3 s;
  - gaveta de $9 roubada sem lock: −$4 (floor); gaveta de $4: nada roubado;
  - nunca aparece à noite, nem fora de 9:00 AM–3:00 PM.

### FEAT-014 — Nota do turno e tela de resumo

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-015, DEC-051, DEC-053, DEC-070, DEC-072]**

Nota **[DEC-051]**: satisfeitos = completos ÷ clientes que chegaram ao balcão (excluídos: clientes-anomalia tratados com o verbo correto; ladrão). Sem cliente no balcão = nota C.

| Nota | % satisfeitos | Bônus do chefe (% da gaveta) | Com Shift Lead na party |
|---|---|---|---|
| A | ≥ 90% | +20% | +25% |
| B | ≥ 75% | +10% | +15% |
| C | ≥ 50% | 0% | +5% |
| D | < 50% | 0% e ligação/fala do chefe (FEAT-018) | 0% |

Tela de resumo (8 s dia / 10 s noite, Q-200; não bloqueia, some sozinha):

| Linha | Exemplo |
|---|---|
| Turno | "Day 3" / "Night 2" |
| Clientes | servidos completos / chegaram |
| Gaveta | $84 |
| Roubado | −$20 (se houve) |
| Bônus do chefe | Grade B: +$8 |
| Depositado | $72 |
| Gemas do turno / total da conta | +3 / 57 (FEAT-029); a tela **mostra** o que já foi creditado e salvo no instante de cada evento **[DEC-104]** |
| Noite (só no resumo de noite, sem número) | noite vencida com a chance intacta: nada · depois de a chance ser usada: "Last chance used" **[DEC-053, DEC-110]**; texto final com o narrative-writer (`ui-text.md`) |

Sem XP, nível ou barra de progresso de carreira **[DEC-081]**.

- Critérios de aceite:
  - Nota calculada só no servidor, igual para a party **[DEC-051]**.
  - Bônus = floor(gaveta × %); dinheiro inteiro.
  - Nenhum medidor de reputação aparece **[DEC-051]**.

### FEAT-015 — Bancada de upgrades do Mart (compra e aplicação)

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-006, DEC-046, DEC-052, DEC-059, DEC-101, DEC-106, DEC-107, DEC-125]**
- Resumo: os upgrades são comprados na **bancada da parede do fundo do Ninth Street Mart** (loja sem vendedor, por prompt), não no equipamento **[DEC-101]**.
  A bancada tem uma parte **fixa** (upgrades básicos, sempre à venda **[DEC-106]**) e um **slot especial** que muda a cada turno (FEAT-035). O Food Trailer **não** está na bancada: compra fixa no próprio trailer, do Day 5 em diante **[DEC-107]** (FEAT-016).

Layout da bancada (proposta; posição física com o level-designer em `MAP-01.md`):

| Posição | Oferta | Visível | Rotaciona? |
|---|---|---|---|
| B1 | Grill (UPG-001) — próximo nível | sempre | não **[DEC-106]** |
| B2 | Cooler (UPG-002) — próximo nível | sempre | não |
| B3 | Counter (UPG-003) — próximo nível | sempre | não |
| B4 | Cash Drawer Lock (UPG-004) | sempre | não |
| B5 | Trailer Lights (UPG-005) | a partir da compra do trailer (antes: placa "Trailer only") **[DEC-055, DEC-106]** | não |
| S1 | slot especial (hoje só o Rescue Whistle, ITM-021) | sempre; vazio = "Nothing special today" | **sim**, por turno (FEAT-035) |

A cafeteira **não** está na bancada: vem fixa no trailer **[DEC-125]**. No Mart só se vende o pacote de café (prateleira, ITM-019).

Cada posição mostra no mundo: miniatura da peça, nome do nível ("Double Grill"), preço e o efeito em 1 linha ("3 spots · 10 s"). Sem UI de loja em tela (DEC-015).

| Regra | Valor |
|---|---|
| Compra | prompt "Buy {upgrade} — ${preço}", hold 1,5 s, na posição da bancada |
| Quando | qualquer fase de qualquer turno (o Mart abre 24 h, DEC-049) |
| Quem | qualquer jogador da party (sem líder, DEC-067); paga com o dinheiro da party |
| Efeito | **imediato** no veículo, mesmo com o comprador longe; vagas/capacidades novas ficam vazias; peça nova aparece no veículo com VFX de "pronto" e som curto audível no Pad |
| Aviso | notificação curta no canto superior direito para toda a party: "Grill upgraded!" (3 s) |
| Visual | toda compra troca/adiciona peça visível no veículo **[DEC-052]** |
| Nível máximo | a posição mostra "Maxed" (`ui-text.md`) e não tem prompt |
| Fichas | `upgrades.md` (UPG-001 a UPG-007) |
| Noite perdida / retomada | compras feitas no turno são desfeitas e o dinheiro volta ao snapshot (FEAT-002, FEAT-026) |

Impacto na curva: comprar exige ida ao Mart (~25 s ida e volta de dia; à noite custa sanidade de escuro, FEAT-020). Isso cria uma razão a mais para combinar compra de upgrade com reposição de estoque. A curva "tudo comprado ~Day 8" (DEC-082) não muda (`progression.md` §3).

- Critérios de aceite:
  - Comprar sem saldo é impossível.
  - Nível máximo mostra "Maxed" e esconde o prompt.
  - Todo upgrade comprado muda o modelo do veículo para todos os jogadores em ≤ 1 s, sem ninguém precisar ir ao veículo.
  - B1–B4 estão à venda em 100% dos turnos; B5 em 100% dos turnos depois da compra do trailer.
  - Não existe prompt de compra de upgrade em nenhum equipamento do veículo.

#### FEAT-015 v2 — "Gear Stand": bancada-quiosque com porta de enrolar e pedestais (2026-10-11, Provisório)

Feedback do usuário (2026-10-11): o painel de nichos não ficou bom; a bancada vira um **quiosque estilo trailer** na mesma
parede, com **porta de enrolar de ripas de madeira**, **atendente atrás do balcão** e **pedestais com a miniatura do
upgrade flutuando**. Layout e coordenadas: `MAP-01.md` §18. Regras abaixo substituem as linhas "Layout da bancada" e
"Cada posição mostra..." acima quando a TASK-138 ligar o modelo. **Nada de preço, efeito ou rotação muda**: DEC-101,
DEC-106, DEC-107, DEC-129 seguem; o que está aqui é apresentação + quando a bancada atende. Dúvidas: `Q-175` (Opal),
`Q-176` (porta), `Q-177` (pacotes).

| Regra | Valor (dados em `Content.Mart`, TASK-135) |
|---|---|
| Pedestais | **6**: B1 Grill, B2 Cooler, B3 Counter · [Opal no meio] · B4 Drawer Lock, B5 Trailer Lights, S1 especial (da esquerda para a direita de quem olha) |
| Oferta | B1–B5 **fixos** (DEC-106), sempre o **próximo nível** no veículo atual (DEC-184: depois da troca, o trailer recomeça do nível 2); S1 = FEAT-035 (sorteio por turno) |
| Miniatura | modelo da peça do próximo nível (`Upgrades.Levels[veículo][n+1].Part`), escala para a maior dimensão = **1,6 studs**; centro **1,2** acima do topo do pedestal |
| Movimento | sobe/desce **±0,25** num seno de **3,0 s**; gira **45°/s** (1 volta em 8 s); só no client e só com a câmera a **≤ 60 studs** do Gear Stand (fora disso, parada e sem custo) |
| Estado "à venda" | flutua e gira; anel do pedestal aceso; placa: nome do nível ("Double Grill"), efeito em 1 linha ("3 spots · 10 s"), preço Mustard |
| Sem saldo | igual, preço **vermelho**; o servidor recusa com `not_enough_cash` |
| "Maxed" | mini do nível **atual**, parada; anel apagado; placa "MAX"; sem prompt |
| "Trailer only" | B5 no carrinho: mini parada a 50% de transparência; placa "Trailer only"; sem prompt (DEC-055) |
| S1 vazio / com item / vendido | vazio: pedestal sem mini, placa "Nothing special today" · com item: mini do Rescue Whistle (ITM-021) flutuando, moldura e anel **Mustard** + lâmpada Neon + `VFX_Rare` · vendido: mini some, placa "Sold out" até o fim do turno (FEAT-035) |
| Compra | prompt na frente da mini; "Buy {upgrade} — ${preço}", **hold 1,5 s**, Radius 7; o alvo é o prompt mais perto do centro da tela (`PromptController`) |
| Porta aberta | fases `Prep`, `Open`, `Closing`, `Night`, `NightEnd` |
| Porta fechada | fases `Summary`, `Call`, `NightLost`, `Resume`, `Finale`, `RunEnd`. Prompts dos pedestais desligados; o servidor recusa compra com a porta fechada (inclusive hold que termina no instante da troca de fase) |
| Troca por turno | a porta desce no `Summary`; o S1 é sorteado no início do `Prep` (FEAT-035); a porta sobe já com a oferta nova. Noite perdida/retomada: desce no `NightLost`, sobe no `Prep` com **a mesma** oferta (snapshot) |
| Animação da porta | 3 portas (L, C, R); **desce em 2,0 s**, **sobe em 1,6 s**; defasagem **0,25 s** entre portas (L → C → R); só client, derivada da fase (zero rede nova); quem chega no meio vê o estado final |
| À noite | **aberta** (DEC-049; o S1 só existe depois do trailer, então quase todo uso dele é à noite; e o trailer recompra upgrades do nível 1, DEC-184) |
| Sem oferta | **não fecha** (tudo "MAX" e S1 vazio = pedestais parados e placas "MAX"); a Opal tem de continuar à vista (DEC-079, pistas do final) |
| Opal | atrás do balcão central (OP-1 do §18.4, `Q-175`); **não vende**, sem prompt; balão de visita igual ao NPC-020 (8 studs, 90 s); sem balão com a porta C fechada |
| Feedback da compra | (1) hold 1,5 s; (2) sucesso: a mini dá 1 volta rápida e "estoura" (escala 1 → 1,3 → 0 em **0,4 s**), **14 confetes** (AST-092) e SFX-064 `buy` no pedestal; (3) **0,5 s** depois, a mini do nível seguinte **sobe de dentro do pedestal em 0,6 s** (ou a placa vira "MAX"); (4) no veículo: peça nova + SFX-065 + confete (já existe); (5) toast para a party "Grill upgraded!" 3 s (acima); (6) opcional, cortável: Opal acena e diz 1 fala do pool `Purchase` (1 a cada 20 s, só para quem está a ≤ 12 studs) |
| Recusa | sem saldo: preço vermelho + `not_enough_cash`; outro jogador comprando o mesmo upgrade: `bench_busy`; "Maxed": sem prompt |

Tempo da porta na economia: fechada no máximo `Summary` (15/20 s) + `Call` (≤ 60 s) por virada de turno; nenhuma compra
de upgrade depende desse tempo (o efeito é imediato e a party pode comprar em qualquer fase aberta). Prateleiras não fecham.

Comparação (orçamento do client, por quadro, com o jogador dentro do Mart):

| Opção de animação | Peças movidas | Custo |
|---|---|---|
| Mini por `PivotTo` em cada quadro | 6 modelos | desprezível (6 CFrames) |
| Porta por ripa (14 × 3 Parts) | 42 Parts só nos 2 s da transição | baixo |
| **Porta por painel com `Texture` de ripas + rolo girando (recomendado)** | 3 painéis + 3 rolos | mínimo |

- Critérios de aceite (v2):
  - Em 100% das fases `Summary` a porta está fechada e nenhum prompt de pedestal aparece; no início do `Prep` ela abre em ≤ 0,2 s depois da troca de fase no client.
  - 1.000 tentativas de compra com o hold terminando na virada `Closing` → `Summary`: nenhuma compra registrada depois que a fase virou.
  - A mini de cada B1–B5 é sempre a peça do **próximo** nível do veículo atual; depois da troca para o trailer, mostra o nível 2 do trailer.
  - "Maxed" e "Trailer only" não têm prompt e a mini fica parada.
  - Com a câmera a mais de 60 studs do Gear Stand, nenhuma mini é atualizada por quadro.
  - 4 jogadores compram 4 pedestais diferentes ao mesmo tempo: as 4 compras saem, o saldo nunca fica negativo.
  - Da porta do Mart, a mini da S1 é visível no fim do corredor principal (`MAP-01.md` §18.10).

### FEAT-016 — Compra do trailer e troca de veículo — **OBSOLETO (DEC-224, 2026-10-12)**

> **Obsoleto:** o Food Trailer é o veículo único desde o Day 1; não há compra, preço, oferta, placa FOR SALE nem troca de veículo. Texto abaixo mantido só como histórico.

- Status: Rascunho · Pilares: PROGREDIR, DESCOBRIR · Origem: **[DEC-007, DEC-019, DEC-028, DEC-037, DEC-047, DEC-052, DEC-086, DEC-107]**
- Resumo: ficha UPG-006. Preço $300 × multiplicador da party (1p $300 · 2p $450 · 3p $570 · 4p $660), tamanho = roster que entrou até o fim do Day 1 **[DEC-121]** (FEAT-001); disponível do Day 5 em diante; **fora da rotação da bancada**, compra fixa por prompt no próprio trailer **[DEC-107]**; visível no estacionamento desde o Day 1 com placa "Available on Day 5"; hold 2 s no trailer; troca no fim do turno (fade + ligação); o trailer passa a trabalhar **na esquina, no Pad do carrinho** **[DEC-086]**; próximo turno = Night 1.

| Regra (proposta além da DEC) | Valor |
|---|---|
| O que muda de veículo | níveis de Grill, Cooler, Counter e Cash Drawer Lock (mesmo nível, peça visível também no trailer — proposta para **Q-075**); estoque inteiro; dinheiro |
| Onde fica o carrinho | destino visual com o narrative-writer (**Q-082**); sem função de jogo |
| O que o trailer acrescenta | cafeteira (UPG-007) com 10 doses; **interruptor de luz** ("Lights", controla a lâmpada interna desde a compra e também UPG-005 se comprado, FEAT-020); botão da janela de serviço ao lado do interruptor ("Close Window"/"Open Window", FEAT-023, DEC-221); banco do fundo; telefone fixo; porta dos fundos (sem prompt); foto de 1979 e crachá "WALT — NIGHT SHIFT" (pistas, `ending.md` §3); tábuas 3; trilho 8 |
| Nomes propostos | carrinho "Corner Cart", trailer "Open Late Trailer" (`ui-text.md` §3; DEC-052 deixa o nome final com o narrative-writer) |
| Compra na Preparação/Fechamento | permitida; troca sempre no fim do turno corrente |
| Arrependimento | não há venda de volta |

- Critérios de aceite: os de `proposals-round-1.md` Q-032, mais: depois da troca, os níveis de upgrade e o estoque são idênticos aos do fim do turno.

### FEAT-017 — Modo dia infinito — **REMOVIDO em 2026-10-12 (Provisório, Q-207)**

> Com o fluxo novo as noites começam no carrinho: não comprar o trailer **não** gera dias sem noite. `RoundService` não liga mais o `Endless`,
> `RunParams.EndlessFromDay` e `EndlessRequiresNoTrailer` ficam sem uso e o contador "Day 100" (DEC-084, FEAT-031) não anda. O texto abaixo é histórico;
> o que sobra do FEAT-017 é só o lembrete "trailer à venda" (agora contado em noites, `Vehicles.trailer.Reminder.FirstNight/Every`).

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-028, DEC-058, DEC-070]**

| Regra | Valor |
|---|---|
| Entrada | não comprar o trailer no Day 5; não há escolha explícita |
| Saída | comprar o trailer em qualquer dia ≥ 5 (vira run de noites a partir dali) |
| Fim | não acaba; termina quando o último jogador sai **[DEC-058, DEC-067]** |
| Notificação | fim do Day 5: "The old trailer is for sale! Check the parking lot."; a cada 3 dias depois: "The trailer is still waiting in the lot." (canto superior direito, 6 s; `ui-text.md` §6) **[DEC-028]** |
| Ingredientes | Cream Cheese libera no Day 6 normalmente |
| Gemas | 2 por dia + 1 com nota A, só se a party entregou ≥ 3 pedidos completos no dia **[DEC-070, DEC-083]** |
| Achievement | FEAT-031 (cada dia de modo infinito que passa no anti-AFK soma 1 no contador da conta, DEC-084) |
| Bancada | sem o trailer, Trailer Lights não aparece; o slot especial fica vazio (Rescue Whistle só existe depois do trailer, FEAT-035, DEC-129) |

- Dinheiro sem uso depois de ~$690 em upgrades (sem Trailer Lights) (dia ~10–12): **aceito no MVP** **[DEC-082]**.
- Critérios de aceite:
  - Sem compra do trailer, Day(n+1) segue Day(n) indefinidamente, com gemas creditadas em cada dia que passa no anti-AFK.
  - A notificação nunca aparece antes do fim do Day 5 nem depois da compra.

### FEAT-018 — Ligações do chefe (gatilhos)

- Status: Rascunho · Pilares: DESCOBRIR · Origem: **[DEC-019, DEC-025, DEC-047, DEC-051, DEC-053, DEC-065, DEC-110, DEC-112, DEC-124]**; rodada 7: Walt Bramble (CHR-001) só por telefone durante a run, **em pessoa só no final** (FEAT-027); ligação **não pode ser repetida pelo jogador**
- Resumo: sistema de gatilhos data-driven. O conteúdo (falas) é do narrative-writer (`script.md`), referenciado por chave. Falante na legenda: "Walt".

| Regra | Valor |
|---|---|
| Como toca | telefone **fixo** do veículo (carrinho de dia, trailer à noite) toca (som + luz) **[DEC-124]**; qualquer jogador atende com toque "Answer"; atende sozinho após 15 s |
| Quem ouve | todos da party (viva-voz), com legenda; jogador longe ouve mais baixo, mas a legenda é igual |
| Ritmo | **servidor** avança as linhas: 2,5 s por linha, igual para todos; sem avanço por toque (ninguém pula linha de regra sem querer, nem pela party) |
| Repetir | **impossível** **[DEC-025: memorizar]**: o telefone não tem prompt de rediscar/reouvir; não existe histórico de legendas; ligação não é cutscene e não tem "Skip" |
| Reconexão | quem reconecta no meio de uma ligação vê só as linhas restantes; quem reconecta depois não recebe a ligação de novo |
| Noite repetida (derrota) | toca a **versão curta** (`script.md` §5.11) por gatilho do sistema, não do jogador; o conteúdo novo não é reapresentado por inteiro |
| Duração | dia ≤ 20 s (até 7 linhas); noite ≤ 45 s |
| Prioridade | uma ligação por vez; fila por prioridade |
| Durante a ligação | o relógio da Preparação não corre até a ligação acabar (só à noite) |
| Alucinação de telefone | toque e legenda "Walt: ..." só no client com sanidade baixa (FEAT-019); sem prompt; não conta como ligação |

`BossCalls` (gatilhos; chaves de texto em `script.md`):

| Chave | Gatilho | Prioridade | Uma vez por run? |
|---|---|---|---|
| `hint_<passo>` | tutorial do Day 1: 1ª vez que a party chega ao passo (`script.md` §3) | média | sim |
| `call_day_<N>` | Preparação do Day N, N = 2–14 (`script.md` §4.1 e §4.4); inclui avisos de ingrediente novo | média | sim |
| `call_day_<N>_quentin` | variante do `call_day_<N>` (N ≥ 3) se Quick Quentin foi impedido no dia anterior | média | sim |
| `call_day_infinite` | Preparação de dia infinito; sorteio do pool sem repetir a anterior (`script.md` §4.3) | baixa | não |
| `call_trailer_bought` | fim do turno em que o trailer foi comprado (com o fade) | alta | sim |
| `call_night_<N>` | Preparação da Night N: regra nova + (N ≥ 8) lembrete do Walker (FEAT-024) | máxima | sim |
| `call_night_short` | Preparação de noite repetida: forma curta da regra da noite + (N ≥ 7) lembrete do Walker | máxima | sim (só há 1 noite repetida por run, DEC-110) |
| `call_lost_critical` | 1ª linha após noite perdida pela N7 ("You watched it, didn't you?…") | máxima | não |
| `call_lost_last_chance` | após a 1ª noite perdida da run: a chance única é usada e a noite repete; o texto deixa claro que **não há outra chance** **[DEC-053, DEC-110, DEC-112]** | máxima | sim |
| `call_run_over` | 2ª noite perdida da run (chance já usada) | máxima | sim |

Falas que **não** são ligação (balão/legenda na tela de resumo, sem telefone): `line_grade_<A–D>` (`script.md` §4.5) e `line_night_end_<N>` (§6).
A antiga `call_finale` sai: o final é cutscene com Walt em pessoa (FEAT-027).

- Critérios de aceite:
  - Toda Night N começa com `call_night_<N>` (ou `call_night_short` na repetição) antes do "Open Shop".
  - Nenhum prompt, botão ou menu permite reouvir uma ligação; a legenda de uma linha passada não reaparece.
  - As linhas aparecem no mesmo instante para todos os jogadores (tolerância ≤ 0,5 s).
  - Nenhuma ligação toca durante outra nem durante cutscene.
  - Walt Bramble não aparece como modelo em nenhum turno antes do Final.
  - Adicionar uma ligação nova é uma linha na tabela + texto do narrative-writer.

---

# Noite

### FEAT-019 — Sanidade

- Status: Rascunho · Pilares: SOBREVIVER, OBSERVAR · Origem: **[DEC-038, DEC-041, DEC-042, DEC-043, DEC-053, DEC-056, DEC-069]**; nome provisório "Sanity" (Q-054 arquivada)

| Evento | Variação | Origem |
|---|---|---|
| Início de cada noite | 100 (Runner 90; Night Owl 120 e máximo 120) | DEC-056, DEC-069 |
| Ver anomalia (FEAT-022) | −5 (Barista −8), **1× por anomalia (`ANM-###`), por jogador, por noite** (vale também para as de "não olhar": relance custa o −5, não é erro). Confirma **Q-114**: "por jogador" (DEC-056) e "por noite" coincidem porque a sanidade reinicia a cada noite | DEC-056, DEC-069, `anomalies.md` §0 |
| Quebrar regra comum | −35 | DEC-056 |
| Escuro (FEAT-020) | −1/s após 3 s contínuos | DEC-056 |
| Café (FEAT-021) | +25 (+35 se feito por Barista) | DEC-055, DEC-069 |
| Atropelamento (FEAT-033) | **0** | DEC-103 |
| Reviver (FEAT-034) | volta com 50% do máximo da classe (Rookie 50, Night Owl 60) | proposta (FEAT-034) |
| Noite repetida (FEAT-026) | todos voltam com o valor inicial da classe, inclusive espectadores | DEC-111, DEC-113 |
| 0 | desmaio → ambulância → reviver ou spectate (FEAT-034, FEAT-025) | DEC-091 a DEC-094 |

Definição de "ver" (proposta): alvo dentro de um cone de 40° em torno da direção do olhar do jogador, até o alcance da anomalia (padrão 60 studs; N6 80; N7 300 — campo `viewRange`), com linha de visão livre (raycast), por 1 s acumulado. Anomalia só de som (N9): conta como "ver" para quem está na zona do trailer quando a 1ª batida soa (`seeMode = audioZone`). Escondido não "vê". Medido no servidor com a direção do olhar enviada pelo client (architect define taxa e validação). A mesma medição alimenta o verbo "não olhar" (FEAT-023).

Efeitos de sanidade baixa (só no client do próprio jogador; nunca interativos; nunca contam como anomalia nem exigem verbo) **[DEC-038]**; faixas alinhadas a `script.md` §8:

| Faixa | Efeito (conteúdo com art-director/narrative-writer) |
|---|---|
| < 60 | telefone toca e a legenda é só "Walt: ..."; chiado numa grelha vazia |
| < 40 | passos no teto do trailer; cliente na fila que some ao ser olhado de novo; um poste da Juniper pisca como o Walker (alarme falso) |
| < 20 | sussurro "Rookie..."; o letreiro do Mart pisca uma vez; sombra na janela dos fundos; susto leve como consequência (DEC-005, Q-023/Q-043) |

Regra: alucinação que imita sinal de anomalia (poste do Walker, telefone) **não abre teste**, não faz o Walker andar e não tira o −5 de "ver".

**DEC-166 (2026-10-10), nota do secretário:** o **visual do personagem** representa a sanidade: alta = texturas de dia + rosto Normal; média = pack "Mid" + rosto Exhausted; baixa = texturas de noite + rosto `Normal_Night`. A definir pelo game-designer (Rascunho): critério da troca (turno × sanidade × ambos; de dia a sanidade não existe) → `Q-155`; limites alto/médio/baixo em pontos, de quem (jogador/NPC) e se os colegas veem (DEC-038 diz efeito só no client do próprio jogador) → `Q-156`.

**DEC-167 a DEC-169 (2026-10-10), nota do secretário** (`Q-155`, `Q-156`, `Q-158` fechadas; game-designer incorpora na ficha):

| Regra | Valor |
|---|---|
| De dia | crew sempre pack dia + rosto Normal **[DEC-167]** |
| À noite, sanidade ≥ 60 (alta) | pack dia + Normal **[DEC-167]** |
| À noite, sanidade 40–59 (média) | pack Mid + Exhausted **[DEC-167]** |
| À noite, sanidade < 40 (baixa) | pack noite + `Normal_Night` **[DEC-167]** |
| Quem tem | só a crew; pontos absolutos, não % do máximo **[DEC-167]** |
| Skin do jogador | vista por **todos**; servidor replica só a **faixa**, nunca o número **[DEC-167, DEC-169]** |
| 1ª pessoa | braços/mãos com a textura da faixa + **retrato do rosto** da faixa ao lado do medidor no HUD **[DEC-167]** |
| Transição | instantânea, sem VFX **[DEC-167]** |
| Faixa baixa → NPCs | o jogador vê **clientes e pedestres** com pack Night + `Normal_Night` **só no client dele**; os outros veem os NPCs normais; sai da faixa baixa → volta ao normal **[DEC-168, DEC-169]**. **Provisório (2026-10-14):** substituído; a faixa baixa local não veste mais NPC. Night em NPC só nas variantes de anomalia com rig animal (`blank`, `raincoat`), sempre; a cópia `mirror` mantém o pack do servidor com rosto `EyesWhite` |

- Duas regras diferentes: skin do **jogador** = replicada para todos; visual dos **NPCs** = troca local, sem replicar (técnica Provisória: `TextureID` + `SurfaceAppearance` clonada no client, como `Crew.applyTime` em `tools/assetplace/build_crew.luau`).
- Efeito sobre NPC não é anomalia e não abre teste (como as alucinações; DEC-038).
- **Provisório** (Rascunho, não apresentado ao usuário): sem histerese (mínimo 1 s por faixa se piscar); sanidade 0 → rosto Desmaiado; reviver/noite repetida pela faixa do valor de volta; 3 packs pré-carregados; NPC não usa Mid.
- ~~Aberto: à noite, clientes/pedestres para quem está bem — DEC-150 já os põe de noite para todos, o que anula a DEC-168 → `Q-157`.~~ **DEC-181 (2026-10-10, secretário):** NPC à noite = pack **Mid** para todos (Mid ocasional de dia); pack **Night** reservado à tensão: sanidade baixa (local, DEC-168/169) e clima de terror de anomalia. Gatilhos e dosagem → `Q-159`. Crew segue a DEC-167.

| Regra | Valor |
|---|---|
| Existe | só à noite; some do HUD de dia **[DEC-056]** |
| Escopo | por jogador **[DEC-056]** |
| Entre noites | volta ao valor inicial da classe |

Dados (tabela `Sanity`, `content-data.md` §3.16 + §6.5; conferidos e completados na TASK-081, **Provisório** onde marcado):

| Campo | Valor | Origem |
|---|---|---|
| `Start` | 100 (máximo = início; classes por `SanityStart`/`SanityMax`) | DEC-056, DEC-069 |
| `SeeAnomaly` | 5 (Barista 8 por `SeeAnomalyLoss`) | DEC-056, DEC-069 |
| `SeeAngle`, `SeeRange`, `SeeTime` | 40° (cone total), 60 studs (padrão; por anomalia em `Anomalies.ViewRange`), 1 s acumulado | FEAT-019 |
| `RuleBroken` | 35 (nenhuma classe altera) | DEC-056, DEC-069 |
| `DarkDelay`, `DarkPerSecond` | 3 s, 1/s | DEC-056 |
| `DarkPhases` | `Call`, `Prep`, `Night` (**sem `NightEnd`**: a noite já foi vencida, escuro ali só puniria depois da vitória; L2-03, **Provisório**) | §19.7, TASK-047 |
| `Coffee`, `CoffeeCooldown`, `CoffeeDrinkTime` | 25, 60 s, 1,5 s | DEC-055 |
| Preparo do café | 6 s, em `Stations.coffee_machine.Params.BrewTime` (não repete em `Sanity`) | DEC-055 |
| `CoffeeNightOnly` | true (**Provisório**, `Q-170` recomendação A; FEAT-021) | `Q-170` |
| Raio do Trailer Lights | 18 studs (LZ-3), no efeito `LightRadius` de `Upgrades.trailer_lights` (não repete em `Sanity`) | DEC-055, DEC-189 |
| `BasicLampRadius` | **0** (**Provisório**): a lâmpada de fábrica acende só os volumes LZ-1 (interior) e **LZ-2 (varanda do balcão, cobre Q1)**; sem esfera extra | DEC-189 (raio deixado ao game-designer) |
| `Bands` | High 60 · Mid 40 (≥ 60 dia, 40–59 Mid, < 40 noite; pontos absolutos) | DEC-167 |
| `BandMinHold` | 0 s (1 s se piscar no teste, **Provisório**) | DEC-167 |

Por que `BasicLampRadius = 0` com LZ-2 acesa: quem atende no balcão (dentro ou na varanda) nunca toma escuro com a luz
ligada, então a lâmpada de fábrica resolve o trabalho de balcão. O Trailer Lights ($100) continua valendo: o raio de 18
cobre a fila Q2–Q5 e encurta a perna escura até o Mart de ~110 para ~85 studs (MAP-01 §10.2: ~4 → ~2 de sanidade por
perna). Se a lâmpada de fábrica já tivesse raio, o upgrade viraria só cosmético. Confirma a pendência "LZ-2 conta como
luz" do MAP-01 §10.2 (level-designer).

Orçamento de sanidade por noite (solo, Rookie, máx. 100, joga certo, vê todas as anomalias ativas uma vez; idas ao Mart
de `economy.md` §5.2; perna escura ~4 sem Trailer Lights, ~2 com):

| Noite | Ver (5 × N) | Escuro, sem Lights (idas × 8) | Total sem erro | Termina em (sem café) | Com 1 regra quebrada (−35) | Cafés para terminar ≥ 40 (faixa Mid) com 1 erro |
|---|---|---|---|---|---|---|
| 1 | 5 | 8 (1 ida) | 13 | 87 | 52 | 0 |
| 3 | 15 | 8 (1) | 23 | 77 | 42 | 0 |
| 5 | 25 | 16 (2) | 41 | 59 | 24 | 1 |
| 7 | 35 | 16 (2) | 51 | 49 | 14 | 2 |
| 10 | 50 | 24 (3) | 74 | 26 | −9 → desmaio sem café | 2 (bebidos antes de zerar) |

Leitura: até a N4 o solo atento termina sem café; da N5 em diante um erro exige café; na N10 até o jogo perfeito termina
na faixa baixa sem café. O café (+25 a cada 60 s, ≤ 25/min) nunca vence o escuro contínuo (60/min): quem fica no escuro
cai mesmo bebendo. Com Trailer Lights o escuro cai pela metade (4/8/12). Dose custa $0,50: 3 cafés × 4 jogadores = $6 por
noite, irrelevante perto dos $120+ da gaveta; o limite real do café é atenção e o cooldown, não dinheiro.

- Critérios de aceite:
  - De dia não há medidor nem variação.
  - Jogador parado em LZ-2 (varanda) com o interruptor ligado não perde sanidade; com o interruptor desligado, perde 1/s a partir do 4º s.
  - Simulação solo Rookie, joga certo, sem café: Night 1 termina com 85–90; Night 10 termina com 20–35 (sem Trailer Lights).
  - A mesma anomalia nunca tira "ver" duas vezes do mesmo jogador na mesma noite, mesmo com várias ocorrências.
  - Alucinação nunca tem prompt e nunca muda estado de servidor.
  - Classe nenhuma altera o −35 **[DEC-069]**.

### FEAT-020 — Escuro e zonas de luz

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-041, DEC-055, DEC-056]**

| Regra | Valor |
|---|---|
| Luz | o jogador está "na luz" se está dentro de qualquer `LightZone` **ativa** |
| `LightZone` do MVP | interior do trailer (ativa se o interruptor está ligado); Trailer Lights, raio 18 studs (UPG-005, ligada com o interruptor); interior do Ninth Street Mart e área sob o letreiro "OPEN 24 HOURS" (**sempre**, nem o Hush apaga); postes da Juniper Street e da Ninth Avenue (marcados pelo level-designer; o Hush apaga) |
| Escuro | fora de toda zona ativa por > 3 s → −1/s **[DEC-056]** |
| Interruptor | prompt "Lights", toque, dentro do trailer ao alcance do balcão e com o relógio do Bellmoor Savings à vista; liga/desliga interior + Trailer Lights juntos; estado da party; cooldown 0,5 s contra spam; começa ligado em toda noite e entra no snapshot (FEAT-026) |
| Interruptor sem UPG-005 | existe desde a compra do trailer e controla a lâmpada interna; a N3 ("flip the trailer lights off") funciona igual **com ou sem** Trailer Lights |
| Durante o Hush (N10) | do poste da esquina apagar até os postes voltarem, as zonas do trailer ficam apagadas e o interruptor não tem efeito |
| Só à noite | de dia nada é escuro; o interruptor de dia é só visual |

Meta para o level-designer: o trajeto trailer → Mart segue a Ninth Avenue (sem obrigar a olhar a Juniper, por causa da N7) e tem ≤ 40 studs de escuro contínuo (≈ 2,5 s andando, abaixo do limite de 3 s) com postes acesos.

- Critérios de aceite:
  - Com a luz ligada, jogador parado no raio não perde sanidade.
  - Apagar o interruptor faz quem está no interior entrar em escuro (perda começa após 3 s).
  - O interruptor tem o mesmo estado para todos os jogadores.
  - Sem UPG-005, o prompt "Lights" existe no trailer e apaga/acende a lâmpada interna.
  - Durante um Hush, quem está sob o letreiro do Mart não perde sanidade por escuro.

### FEAT-021 — Café

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-042, DEC-055, DEC-069]**; ficha do item ITM-009, equipamento UPG-007
- Números **[DEC-055]**: cafeteira no trailer, hold 1 s, preparo 6 s com barra (Barista 3 s), consome 1 dose, gera Tool "Coffee"; beber (ativar o Tool, animação 1,5 s) dá +25 (+35 se Barista fez); cooldown 60 s por jogador (cooldown de beber); pode ser entregue a outro jogador (dropar não; "Give" por prompt no colega, hold 0,5 s).
- Propostas: cafeteira faz 1 café por vez; máx. 1 Coffee por jogador na hotbar; Coffee não estraga; não passa da sanidade máxima.

Dados (TASK-081; `Stations.coffee_machine`, `Sanity`, `Items.coffee`, `Packages.pack_coffee`, `Actions`):

| Campo | Valor | Origem |
|---|---|---|
| Preparar (`brew_coffee`) | hold **1 s**; `Stations.coffee_machine.Params.BrewTime` **6 s** (Barista 3 s, `CoffeeBrewTime`) | DEC-055, DEC-069 |
| Pegar | mesmo prompt em `Ready` ("Take Coffee"), toque; hotbar cheia ou já com 1 café → `hands_full` e o café fica na máquina | §19.8 |
| Beber | ativar a Tool; `CoffeeDrinkTime` 1,5 s; +`Restore` gravado na Tool (25; 35 se feito por Barista); não passa do máximo | DEC-055, DEC-069 |
| Cooldown | `CoffeeCooldown` 60 s por jogador, desde o gole | DEC-055 |
| Dar (`give_coffee`) | hold **0,5 s** no colega `Active` sem café; só à noite (`Actions.give_coffee.Night = "NightOnly"`; de dia cada um carrega o seu) | DEC-055 |
| Doses | começa com 10 na compra do trailer; capacidade 20 (Cooler não afeta); 1 dose por café | `upgrades.md` UPG-007 |
| Reposição | pacote ITM-019 "Ground Coffee" (D-10): 10 doses, $5 ($0,50/dose) | DEC-049, DEC-055 |
| De dia (`Q-170`) | **Provisório, recomendação A:** pode preparar e carregar; **beber só à noite** (`Sanity.CoffeeNightOnly = true`); ativar de dia → toast `coffee_night_only` e a Tool fica | `Q-170` |

Por que A em `Q-170`: (B) beber e desperdiçar pune quem não entendeu a regra da sanidade; (C) cafeteira desligada de
dia esconde a máquina justo no turno calmo em que o jogador aprenderia a usá-la. Com A, preparar o café no fim do dia e
entrar na noite com ele na hotbar vira uma decisão de GERENCIAR (ocupa 1 das 4 vagas). Custo de escopo: 1 aviso novo.

Avisos: `coffee_cooldown`, `coffee_full` (sanidade no máximo, a Tool fica), `coffee_night_only` e `coffee_has_one`
(propostas, `ui-text.md` §10.2), `hands_full`; textos no `ui-text.md` §10 (narrative-writer).

- Critérios de aceite: os de `proposals-round-1.md` Q-014, mais:
  - entregar Coffee a quem já tem 1 é bloqueado;
  - barra de preparo dura 6,0 ± 0,2 s (3,0 com Barista), só com dose ≥ 1, e consome exatamente 1 dose;
  - beber com sanidade 90 de máximo 100 deixa 100 (não 115); beber no máximo não consome a Tool;
  - 2º gole antes de 60 s é recusado com `coffee_cooldown` e o valor restante em s;
  - de dia, ativar o café não muda nada no servidor e não consome a Tool;
  - o café feito por um Barista e bebido por outro jogador dá +35.

### FEAT-022 — Sistema genérico de anomalias

- Status: Rascunho · Pilares: OBSERVAR, SOBREVIVER · Origem: **[DEC-005, DEC-010, DEC-023, DEC-025, DEC-026, DEC-054, DEC-060]**
- Resumo: cada anomalia é uma linha de dados; um agendador por noite cria **ocorrências**. O código conhece só os tipos de ator, os 7 verbos e as consequências; o conteúdo (visual, som, fala, regra) vem do narrative-writer (`docs/story/anomalies.md`, N1–N10, lista aprovada na rodada 7) e do art-director. Linhas e números: NPC-009 a NPC-018 (`npcs.md`).

Tabela `Anomalies` (um registro por anomalia):

| Campo | O quê |
|---|---|
| `id` | `ANM-001` … `ANM-010` **[DEC-096]**; chave de dados `anm_001_blank_folks` … `anm_010_hush`; ator de servidor NPC-009 a NPC-018 |
| `night` | noite em que estreia (1–10); uma nova por noite **[DEC-060]** |
| `actorKind` | `customer` (ocupa vaga do balcão) · `walker` (figura na rua) · `vehicle` · `environment` (relógio, poste, janela) · `audio` (só som) · `item` (ingrediente alterado) |
| `npcCost` | 0 ou 1 no teto de atores (máx. 3 à noite) |
| `signal` | canal observável: `visual` · `audio` · `environment` · `clock` · `item`; descrição em `anomalies.md` |
| `ruleKey` | chave da fala da regra em `call_night_<N>` |
| `verb` | exatamente 1 dos 7 (FEAT-023) **[DEC-054]** |
| `verbParams` | prazo (s), zona, alvo `shared`/`personal`, `actionFail` (ação que falha), `omissionFails`, `lookMode` (`personalContinuous` / `sharedApproach`), `lightSequence`, `wrongServeRetry` |
| `likelyWrongVerb` | para teste e para o texto da regra **[DEC-054]** |
| `seeLoss` | −5 para todas (DEC-056); `seeMode` `cone` ou `audioZone`; `viewRange` em studs |
| `duration` | duração da ocorrência (s) |
| `critical` | `true` só na N7 (FEAT-024) |
| `exclusiveWith` | anomalias que não podem estar ativas ao mesmo tempo (`npcs.md`) |
| `scripted` | ocorrência com horário fixo (só N10 na Night 10, 5:45 AM) |

Agendador por noite (proposta; números em `progression.md`):

| Regra | Valor |
|---|---|
| Ativas na Night N | anomalias com `night ≤ N` **[DEC-025]** |
| Ocorrências | estreia (N = night): 3 · 1–2 noites depois: 2 · 3+ noites depois: 1 |
| Janela | 9:00 PM–5:00 AM; estreia não ocorre depois de 5:00 AM. Exceção: ocorrência `scripted` (N10 às 5:45 AM da Night 10) |
| 1ª ocorrência da estreia | no primeiro terço da janela (o jogador acabou de ouvir a regra) |
| Intervalo mínimo entre inícios | noites 1–4: 60 s · 5–7: 40 s · 8–10: 25 s |
| Simultâneas | noites 1–3: 1 · 4–7: 2 · 8–10: 3 (e nunca acima do teto de 3 atores) |
| Exclusões | respeita `exclusiveWith` (N10 × N3/N8/N9; N5 × N8/N9/N10) |
| Determinismo | sem sorteio de **quais** anomalias (DEC-060); só os horários variam (semente por run) |
| Cliente-anomalia | substitui um spawn de cliente normal; usa vaga do balcão (N4 usa 2: original + cópia) |

Contrato de conteúdo (vale para as 10 anomalias; `anomalies.md` já cumpre):

1. O **sinal é observável** por um jogador atento antes do prazo do verbo, e é **quebra de padrão** de algo que o jogador já viu de dia (invariantes de `npcs.md` ou padrões de Bellmoor em `world.md` §2) **[DEC-010]**.
2. Anomalia com verbo "não olhar" tem **sinal sonoro de início** (N6: cortina; N7: o último poste da Juniper zumbe ~2 s e para seco, ouvido por toda a party **[DEC-123]**) para o jogador saber quando desviar.
3. Sem violência, sem ferimento, sem agressor visível **[DEC-023]**. Consequência é sanidade, perda de noite ou efeito no negócio.
4. O comportamento base é o de um cliente/objeto normal; a anomalia muda **um** traço visível ou audível.

- Critérios de aceite:
  - Adicionar uma anomalia com ator, verbo e consequência já existentes não exige código novo.
  - Night N tem exatamente as anomalias N1..N(N) ativas, com a contagem de ocorrências de `progression.md` §4.2.
  - Nenhuma ocorrência não roteirizada começa fora de 9:00 PM–5:00 AM; nunca há mais atores que o teto.
  - Duas anomalias marcadas em `exclusiveWith` nunca estão ativas ao mesmo tempo.
  - Toda anomalia tem exatamente um verbo correto **[DEC-054]**.

### FEAT-023 — Verbos contra anomalia

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-054, DEC-055, DEC-221]**
- **DEC-221 (2026-10-10):** o verbo "esconder" (armários H1..H4, "Hide"/"Get Up") **sai**; no lugar, **fechar a janela** de serviço do trailer pelo botão ao lado do interruptor. Detalhes Provisórios em `Q-173`.
- Resumo: 7 verbos, todos com botão de interagir ou câmera. Cada ocorrência abre um "teste" com prazo; o servidor resolve sucesso ou falha.

Comportamento genérico de cada verbo; o que muda por anomalia está em `verbParams` (`npcs.md`, NPC-009 a NPC-018).

| Verbo | Ação do jogador | Sucesso | Falha por ação (padrão) | Falha por omissão (padrão) | Alvo | Usado por |
|---|---|---|---|---|---|---|
| Atender | "Take Order" + "Serve" | entregue (completo **ou** incompleto) antes da paciência | "Refuse" | paciência acaba → todos os ativos | shared | N5 |
| Recusar | hold 1 s "Refuse" | recusado | "Take Order" no ator | por padrão **não** falha (o ator ocupa a vaga até a paciência acabar) | shared | N1, N4 |
| Não olhar | desviar a câmera | `personalContinuous`: ninguém fica ≥ X s contínuos com o alvo no cone · `sharedApproach`: o alvo não chega ao último passo | — | `personalContinuous`: quem passou de X s · `sharedApproach`: a party | personal / shared | N6 (X = 3 s), N7 (10 passos) |
| Luz | toque "Lights" | `lightSequence` cumprida dentro do prazo (N3: desligado ≥ 5 s contínuos e depois religado) | — (sequência incompleta não falha) | prazo acaba → todos os ativos | shared | N3 (60 s) |
| Fechar a janela | hold 0,5 s "Close Window" no botão ao lado do interruptor do trailer (abre com "Open Window") | no prazo a janela está fechada e cada jogador ativo na zona do trailer está **dentro** do trailer, até o fim | abrir antes do fim (paga quem abriu, DEC-204) | no prazo, janela aberta ou jogador na zona fora do trailer (cada um que falhou) | personal (estado da janela é da party) | N8, N9 |
| Descartar | pegar o item (ou o Hot Dog com ele) e hold 0,5 s "Throw Away" | item na lixeira | servir o Hot Dog com o item (quem serviu) | por padrão **não** falha; o item some às 6:00 AM | shared | N2 |
| Ponto seguro | ir até a zona e ficar | todo jogador ativo dentro da zona no prazo e até o fim | sair antes do fim | fora da zona no prazo | personal | N10 |

| Regra | Valor |
|---|---|
| Janela fechada (DEC-221, Provisório `Q-173`) | aba externa cobre a janela; "Take Order", "Serve" e "Refuse" recusados (fila espera, paciência corre); quem está dentro do trailer não "vê" nada do lado de fora (sem −5, não conta como "olhando" para N6/N7); o resto do trailer funciona; só à noite; abre sozinha no início de cada turno |
| Alvo shared | o verbo de um jogador vale para a party **[DEC-054]** |
| Quem paga a falha | por ação: **quem agiu**; por omissão em alvo shared: **todo jogador ativo**; alvo personal: **cada jogador que falhou** |
| Jogador ativo | conectado, de pé (não caído nem espectador) e já spawnado; desconectado, caído e espectador são ignorados. Jogador em ragdoll de atropelamento (FEAT-033) **é** ativo |
| Consequência | regra comum: −35 em cada jogador que falhou; regra crítica: noite perdida (FEAT-024). **Provisório (2026-10-14):** ANM-002 e ANM-004 têm consequência estendida (desmaio revivível, DEC-243/DEC-246/DEC-247; fluxos em `story/anomalies.md`) |
| Verbo em cliente normal | Refuse em cliente normal = insatisfeito, sem perda de sanidade; fechar a janela/ponto seguro sem anomalia = só venda/tempo perdido |

Distribuição das 10 anomalias (ordem de `anomalies.md`, aprovada na rodada 7; substitui o exemplo de DEC-054 e a proposta anterior deste arquivo):

| Noite | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| ID | ANM-001 | ANM-002 | ANM-003 | ANM-004 | ANM-005 | ANM-006 | ANM-007 | ANM-008 | ANM-009 | ANM-010 |
| Anomalia | N1 The blank folks | N2 The wrong food | N3 The stopped clock | N4 The copies | N5 The Raincoat Lady | N6 The wavers | N7 The Walker | N8 The long car | N9 The knock | N10 The Hush |
| Verbo | recusar | descartar | luz | recusar | **atender** | não olhar | não olhar (**crítica**) | fechar a janela | fechar a janela | ponto seguro |

Contagem: recusar 2 · atender 1 · não olhar 2 · luz 1 · fechar a janela 2 (era "esconder", DEC-221) · descartar 1 · ponto seguro 1 (os 7 verbos de DEC-054 aparecem).

- Critérios de aceite:
  - Os de `proposals-round-1.md` Q-013.
  - Para cada verbo, um teste automatizado cobre sucesso, falha por ação e falha por omissão (quando `omissionFails` = sim), com 1 e 4 jogadores.
  - Jogador fora ou desconectado nunca é penalizado por omissão.
  - "Refuse" num cliente normal nunca tira sanidade; "Take Order" num cliente normal nunca falha regra.

### FEAT-024 — Regras do chefe: comum e crítica

- Status: Rascunho · Pilares: SOBREVIVER, DESCOBRIR · Origem: **[DEC-025, DEC-026, DEC-053]**

| Regra | Valor |
|---|---|
| Comum | toda regra de anomalia; falhar = −35 em quem falhou **[DEC-053, DEC-056]** |
| Crítica | máx. 1 por noite, anunciada com "whatever you do, never…" **[DEC-053]**; falhar = noite perdida para a party |
| Qual é crítica | **fixa: só a ANM-007, The Walker** **[DEC-074]**. Nights 1–6: nenhuma regra crítica. Nights 7–10: N7 é a crítica (é cumulativa, então está ativa em todas) |
| Gatilho de falha | o Walker chega ao passo 10, a borda da luz do trailer (NPC-015) |
| Ensino | Night 7: a regra inteira com "Whatever you do, never…"; Nights 8–10: a ligação termina a parte de regra com "And never watch the Walker." (`script.md` §5); demais regras antigas não são repetidas (memória) |
| Repetição da mesma falha | um jogador falha no máximo 1 vez por ocorrência |
| Night 10 | a única ocorrência da N7 é a do clímax roteirizado (5:45 → 6:00 AM, junto com o Hush, FEAT-027); a regra vale até o fim |

Antes da Night 7, a noite só é perdida quando todos os jogadores conectados caem e ninguém revive na janela de 10 s **[DEC-053, DEC-094, DEC-102, DEC-118]**. Com 1 chance por run **[DEC-110, DEC-112]**, qualquer noite perdida pesa: a 2ª encerra a run. Isso deixa as Nights 1–6 mais tolerantes; a curva de dificuldade sobe pelas regras comuns e pela sanidade (`progression.md` §4.3; risco em **Q-115**).

- Critérios de aceite:
  - Nights 1 a 6 nunca terminam por regra crítica.
  - Quebra da regra crítica encerra a noite em ≤ 3 s (sequência de derrota, FEAT-026).
  - As ligações das Nights 7 a 10 citam o Walker; nenhuma ligação anterior à Night 7 usa "whatever you do, never".
  - Nenhuma anomalia além da N7 tem `critical = true`.

### FEAT-025 — Jogador caído e espectador

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-043, DEC-053, DEC-067, DEC-085, DEC-091, DEC-093, DEC-104, DEC-111, DEC-113, DEC-115, DEC-129]**. A sequência do desmaio e o reviver estão em FEAT-034.
- Resumo: com sanidade 0 o jogador **cai** (estado `Down`), a ambulância leva o corpo e ele passa a assistir. Enquanto pode ser revivido, é **caído revivível**; se a janela de reviver fecha sem reviver, vira **espectador permanente** **[DEC-093]**. A **única** saída do spectate é a party perder a noite com a chance do chefe ainda disponível: aí **todos** voltam no início da noite repetida **[DEC-111, DEC-113]**; noite vencida não devolve ninguém. O banco do fundo do trailer **não** é usado para isso (DEC-091, DEC-122).

Estados por jogador:

| Estado | Entra quando | Sai quando | Interage? | Ativo nos verbos? | Presente (run, gemas)? |
|---|---|---|---|---|---|
| `Active` | spawn / reviver | sanidade 0 | sim | sim | sim |
| `Down` (revivível) | sanidade 0 | revivido (→ `Active`) ou janela fecha (→ `Spectator`) | não | não | sim **[DEC-067, DEC-085 c]** |
| `Spectator` (permanente) | janela de reviver fechou sem reviver, ou 3ª queda na mesma noite (DEC-129) | fim da run **ou** início da noite repetida, quando todos voltam `Active` (no máximo 1 vez por run) | não | não | sim **[DEC-093, DEC-111, DEC-113]** |

| Regra | Valor |
|---|---|
| Janela de reviver | do desmaio até as **6:00 AM** da mesma noite **[DEC-115]**; exceção: se todos caem, a janela de 10 s decide a noite (FEAT-034) |
| Câmera | spectate em 1ª pessoa de um colega `Active`; toque no botão de interagir troca de colega; sem colega ativo: câmera fixa externa olhando o trailer |
| UI no spectate | nome do colega assistido; oferta de reviver enquanto `Down` (FEAT-034); botão "Leave to lobby" (sair conta como desconectado, DEC-085; gemas já ganhas estão salvas, DEC-104) |
| Tools enquanto `Down` | ficam guardadas com o jogador (nada cai) |
| Tools ao virar `Spectator` | pacotes (com a contagem) e Rescue Whistle vão para o balcão do trailer como itens no chão (FEAT-036, sem prazo para sumir até o fim do turno seguinte); Hot Dog, Coffee e item alterado somem |
| Dia seguinte | espectador permanente continua assistindo também de dia (noite vencida não devolve ninguém, DEC-093, DEC-113); de dia a câmera segue um colega |
| Noite repetida | todo `Spectator` e todo `Down` voltam `Active` no início da Preparação da noite repetida, com a sanidade inicial da classe, de pé na calçada ao lado do trailer junto com os outros **[DEC-111, DEC-113, DEC-122]** (FEAT-026) |
| Gemas | recebe todo evento que ocorrer com ele no servidor **[DEC-070, DEC-104]** |
| Fluxo de clientes | espectador não conta como ativo no multiplicador do turno seguinte (FEAT-009) |
| Anomalias | caído e espectador nunca são alvo nem penalizados; não "veem" anomalia |

- Critérios de aceite:
  - Jogador `Down` ou `Spectator` não tem nenhum prompt e não é alvo de anomalia.
  - Às 6:00 AM, todo jogador ainda `Down` vira `Spectator`, e seus pacotes e Rescue Whistle aparecem no balcão do trailer.
  - Depois de uma noite vencida, o espectador permanente continua sem personagem jogável no dia seguinte.
  - Party de 4 com 1 espectador desde a Night 3 que perde a Night 5 (chance intacta): na Night 5 repetida os 4 jogadores estão `Active` com a sanidade inicial da classe.
  - "Leave to lobby" leva o espectador ao lobby com as gemas já creditadas intactas.

### FEAT-026 — Avaliação da noite e chances do chefe

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-026, DEC-053, DEC-057, DEC-067, DEC-070, DEC-074, DEC-085, DEC-094, DEC-102, DEC-104, DEC-110, DEC-111, DEC-112, DEC-113, DEC-118, DEC-122]**
- Chances do chefe: **1 por run inteira** **[DEC-110, DEC-112]**. A 1ª noite perdida usa a chance e repete; a 2ª noite perdida (a mesma ou outra) encerra a run.

| Resultado | Condição |
|---|---|
| Vitória | 6:00 AM com ≥ 1 jogador `Active` e sem regra crítica quebrada |
| Derrota por queda | o último jogador `Active` **conectado** cai, abre a **janela de 10 s** (congela com prompt de compra aberto, até +20 s, DEC-118; FEAT-034) e ninguém revive nela **[DEC-094, DEC-102]**. Desconectado não entra na conta **[DEC-085 c]** |
| Derrota por regra crítica | ANM-007 (The Walker) chega ao passo 10: noite perdida **na hora, sem janela** **[DEC-053, DEC-074, DEC-094]** |

| Ao perder | Valor |
|---|---|
| Com a chance ainda não usada (1ª noite perdida da run) | usa a chance única **[DEC-102, DEC-110]**; sequência (transição de ≤ 6 s, sem "Skip"): luzes piscam 2 s → apagam → tela escurece → todos acordam **em pé na calçada, ao lado do trailer**, enquanto a ambulância vai embora com a sirene desligada **[DEC-122]** (sem banco; pontos REV-1..4 do `MAP-01.md`) → `call_lost_critical` (só se foi a ANM-007) + `call_lost_last_chance` → mesma noite recomeça na Preparação com `call_night_short` **[DEC-053]** |
| Snapshot restaurado | o do início da Preparação da noite (FEAT-002): dinheiro da party, estoque, níveis de upgrade, oferta especial da bancada (sem novo sorteio), gaveta = 0, Tools de cada jogador, estado do interruptor; sanidade volta ao inicial; contador de revives da noite zera |
| Espectadores na noite repetida | **todos** os membros da party voltam `Active` com a sanidade inicial da classe, **inclusive** espectadores permanentes de noites anteriores **[DEC-111, DEC-113]**. A flag de espectador do snapshot é ignorada aqui (só vale na retomada, FEAT-002). Desconectado continua desconectado; ao voltar, entra `Active` |
| Com a chance já usada (2ª noite perdida) | `call_run_over` → tela de fim de run → lobby **[DEC-110, DEC-112]** |
| Gemas | noite perdida não credita; vencida depois credita 1× **[DEC-070]**, no instante do evento, para quem está no servidor **[DEC-104]** |
| Chances no HUD | nunca; só na ligação e no resumo **[DEC-053]** |

- Critérios de aceite:
  - Os de `proposals-round-1.md` Q-035, com o número de chances = 1 (DEC-110 emenda o "3" daquela proposta).
  - O snapshot é tirado no início da Preparação da noite e restaurado exatamente, inclusive a oferta especial da bancada.
  - Último jogador ativo cai e ninguém revive em 10 s: a noite é perdida e a chance é usada; a 2ª noite perdida da run encerra a run.
  - Na noite repetida, todo membro conectado começa `Active`, inclusive quem era `Spectator` desde uma noite anterior.
  - Depois da sequência de derrota, todos aparecem de pé na calçada ao lado do trailer; nenhum jogador aparece sentado no banco.
  - Quebra da regra crítica perde a noite em ≤ 3 s, sem janela de 10 s, mesmo com Rescue Whistle na hotbar de alguém.
  - Jogador que reconecta durante a sequência de derrota entra já no estado restaurado.

### FEAT-027 — Final da 10ª noite

- Status: Rascunho · Pilares: DESCOBRIR · Origem: **[DEC-065, DEC-070]**; rodada 7: **Walt Bramble aparece em pessoa** (variante A1 de `ending.md`); conteúdo e roteiro em `ending.md` §2.1–§2.4 **[DEC-075, DEC-076]**; cutscene em POV compartilhada (DEC-088); espectadores permanentes assistem e votam

Clímax jogável (dentro da Night 10, antes do Final):

| Hora (Night 10) | Tempo real | O que acontece | Regra |
|---|---|---|---|
| 5:45 AM | −45 s | Hush roteirizado (3ª ocorrência da N10): postes da Juniper apagam até o da esquina em 15 s; trailer fica escuro | ponto seguro sob o letreiro do Ninth Street Mart (verbo normal, −35 para quem ficar fora) |
| 5:45 AM | −45 s | o Walker (N7) aparece sob o último poste e **não avança se ninguém olhar** | regra crítica vale até 6:00 AM (olhar 10 s acumulados = noite perdida) |
| 6:00 AM | 0 | sol nasce, postes voltam, o Walker some, o relógio do Bellmoor Savings bate 6 vezes | Night 10 vencida se ≥ 1 jogador ativo e a crítica não foi quebrada (FEAT-026) |

Se a Night 10 for perdida e a chance da run ainda não tiver sido usada, ela se repete inteira, com o clímax de novo; se a chance já foi usada, a run acaba (DEC-110, DEC-112).

Sequência do Final (Night 10 vencida):

| Passo | Duração | Pulável? |
|---|---|---|
| 1. Servidor credita 33 + 100 gemas **[DEC-070]** e salva | instantâneo | — |
| 2. `cs_finale` (cutscene, FEAT-004): porta do Mart abre, **Walt sai em pessoa** com dois cafés, 9 falas; plano final da Raincoat Lady ("Morning, Marigold.") | ≤ 60 s (`ending.md` §4) | sim, voto 50% |
| 3. `cs_credits`: créditos + pós-créditos (panfleto "NIGHT SHIFT — NOW HIRING" no poste) | ≤ 75 s | sim, voto 50% |
| 4. Tela de fim de run "You Kept the Light On" (resumo da noite + gemas) | 15 s | — |
| 5. Volta ao lobby **[DEC-075]** | — | — |

| Regra | Valor |
|---|---|
| Atores da cutscene | Walt (CHR-001) e Raincoat Lady (CHR-006) são modelos **só no client**, durante a cutscene; custo 0 no teto de NPC; nenhum cliente nem anomalia vivo durante o Final |
| Walt fora do final | nunca aparece como modelo em outro momento da run (FEAT-018); a ficção de A1 ("watched from in here") não pede silhueta no Mart durante as noites |
| Assets novos | modelo do Walt (aparência em `characters.md` CHR-001), dois copos de café, luz de amanhecer na esquina, panfleto novo |
| Fechamento e resumo normais | não acontecem na Night 10 vencida: o passo 4 substitui o resumo |

- Critérios de aceite:
  - Na Night 10, o Hush das 5:45 AM sempre acontece e o Walker aparece junto, parado enquanto ninguém olha.
  - As 133 gemas estão creditadas antes de a cutscene começar (sair durante o Final não perde gemas).
  - Walt Bramble aparece em pessoa **só** em `cs_finale`.
  - Party de 4: dois votos pulam o segmento atual para todos; o próximo segmento começa com 0 votos.
  - O final só toca uma vez por run; a duração total do passo 2 ao 4 é ≤ 2 min 30 s sem pular.

---

# Meta

### FEAT-028 — Classes (sistema)

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-061, DEC-069, DEC-070]**; fichas em `classes.md` (CLS-001 a CLS-008)
- Resumo: tabela `Classes` com lista de efeitos tipados. Tipos de efeito do MVP: `walkSpeed`, `grillTimeMult` (só salsichas do dono), `nightSanityStart`, `nightSanityMax`, `daySpeed`. Tipos das classes fora do MVP: `packageLimit`, `tipValue`, `tipWindowDelta`, `coffeePrepTime`, `coffeeRestore`, `seeLossOverride`, `partyGradeBonus` (não acumula).
- Critérios de aceite: os de `proposals-round-2.md` §1.7.

### FEAT-029 — Gemas

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-035, DEC-058, DEC-070, DEC-083, DEC-084, DEC-085, DEC-104]**; valores em `economy.md` §6
- Regras:
  - Por jogador, persistidas; mesmo valor para toda a party pelo mesmo evento **[DEC-070]**.
  - **Creditadas e salvas no DataStore no instante de cada evento** (dia concluído, nota A, noite vencida, final, Day 100). A tela de resumo só mostra **[DEC-104]**.
  - Recebe quem está **no servidor no instante do evento**, inclusive `Down` e `Spectator`. Desconectado no instante não recebe aquele evento; quem sai mantém o que já recebeu **[DEC-104, DEC-085]**.
  - Anti-AFK: as 2 gemas do dia **e** o +1 da nota A exigem **≥ 3 pedidos completos da party** no turno **[DEC-083]** (o +1 da nota A com o mesmo mínimo é a leitura do secretário; o game-designer confirma: sem o mínimo, 1 pedido completo de 1 cliente daria nota A).
  - Momento de cada evento: "dia concluído" e "nota A" = início do Resumo do dia; "noite vencida" = 6:00 AM com vitória; "final" = antes de `cs_finale` (FEAT-027).
- Critérios de aceite:
  - Os de `proposals-round-2.md` §2.6.
  - Jogador que desconecta 1 s depois da vitória da noite tem as gemas da noite salvas.
  - Dia com 2 pedidos completos: 0 gemas, mesmo com nota A.

### FEAT-030 — Reconexão

- Status: Rascunho · Pilares: — · Origem: **[DEC-063, DEC-067, DEC-080, DEC-085, DEC-098]**; técnica com o architect (**Q-058**)

| Regra | Valor |
|---|---|
| Quando é possível | enquanto ≥ 1 jogador do roster está no servidor da run **[DEC-067]**, ou até 15 min depois do último sair ou da queda do servidor (retomada pelo snapshot) **[DEC-080, DEC-119]** |
| Quem | só o roster (FEAT-001); o atrasado que nunca entrou usa o mesmo caminho **[DEC-067, DEC-098]** |
| Aviso | no lobby, notificação no canto superior direito: "You have a shift in progress." + botão "Rejoin" **[DEC-063]** (`ui-text.md` §6) |
| Estado guardado do jogador (servidor vivo) | classe, Tools da hotbar (com contagens), sanidade, estado `Active`/`Down`/`Spectator`, revives usados na noite, ocorrências já vistas, cooldown do café |
| Retomada pelo snapshot | volta ao estado do **início do turno corrente** (FEAT-002) para todos; o estado de vida (`Active`/`Spectator`) volta como estava no snapshot (diferente da noite repetida, em que todos voltam `Active`, FEAT-026) |
| Onde reaparece | dia: ao lado do veículo; noite: dentro do trailer; `Down`/`Spectator`: direto no spectate |
| Liderança | não existe na run **[DEC-067]** |
| Relógio | não pausa **[DEC-085 a]** |
| Abuso | sair e voltar não reseta sanidade, cooldown, estado de caído nem contador de revives |

- Critérios de aceite:
  - Jogador que sai e volta na mesma noite tem a mesma sanidade e o mesmo estado de quando saiu.
  - Jogador `Down` que sai e volta continua `Down` (e vira `Spectator` se voltar depois das 6:00 AM).
  - Com 0 jogadores no servidor por mais de 15 min, a notificação de reconexão não aparece mais.
  - Jogador de fora do roster nunca vê a notificação nem entra.

### FEAT-031 — Achievement secreto "Day 100"

- Status: Rascunho · Pilares: PROGREDIR · Origem: **[DEC-058, DEC-070, DEC-083, DEC-084, DEC-104]**
- Regra: +300 gemas, 1× por conta, badge do Roblox; nome proposto pelo narrative-writer: "Never Clocked Out" (`ui-text.md` §9).
- Medição **[DEC-084]**: contador **por jogador, persistido** junto das gemas; +1 a cada **dia de modo infinito concluído** (dia sem trailer, a partir do Day 6) que passou no anti-AFK (≥ 3 pedidos completos, DEC-083), em qualquer run, somando sessões. Recebe o +1 quem está no servidor no evento "dia concluído" (DEC-104).
- Critérios de aceite:
  - O achievement não é listado nem sugerido no jogo antes de ser ganho; o contador não aparece em nenhuma tela.
  - Credita 300 gemas e o badge uma única vez por conta, no instante em que o contador chega a 100.
  - 60 dias numa run + 40 em outra = achievement.
  - Day 1–5, dias com o trailer comprado e dias que falham no anti-AFK não somam.

---

# UI

### FEAT-032 — HUD de status e notificações

- Status: Rascunho · Pilares: — · Origem: **[DEC-015, DEC-048, DEC-051, DEC-053, DEC-056, DEC-063]**; desenho visual em rodada futura

| Elemento | Quando | Fonte |
|---|---|---|
| Horário ("8:00 AM") | sempre | FEAT-003 |
| Turno ("Day 3" / "Night 2") | sempre | FEAT-003 |
| Dinheiro da party | sempre | FEAT-012 |
| Sanidade (por jogador) | só à noite | FEAT-019 |
| Notificações (canto superior direito) | reconexão, trailer disponível, ingrediente liberado, "Hands full", upgrade comprado, "Something rare is on the Mart's back wall!" (`ui-text.md`) | FEAT-015/016/017/030/035 |
| Tela de resumo | fim de turno | FEAT-014 |
| Spectate (só `Down`/`Spectator`) | nome do colega assistido; oferta de reviver; contador da janela de 10 s; "Leave to lobby" | FEAT-025, FEAT-034 |

Proibido no HUD: reputação **[DEC-051]**, chances do chefe **[DEC-053]**, botões de ação **[DEC-015]**, lista de regras, XP/nível **[DEC-081]**.

- Critérios de aceite:
  - Para jogador `Active`, o HUD não tem nenhum elemento clicável além da hotbar nativa; botões só existem no lobby (reconexão), na cutscene ("Skip") e no spectate (reviver, sair).
  - Sanidade não aparece de dia.

---

# Rua e queda (rodadas 9–12)

### FEAT-033 — Trânsito e atropelamento

- Status: Rascunho · Pilares: OBSERVAR, GERENCIAR · Origem: **[DEC-087, DEC-095, DEC-103, DEC-023, DEC-073, DEC-130, DEC-131, DEC-133]** (DEC-120 revogada); regra de travessia sem semáforo decidida em **DEC-133** (Q-129 B); rotas e performance com level-designer + architect (**Q-102**); convivência com a ANM-008 (**Q-103**)
- Resumo: carros (NPC-022) andam por rotas fixas na Ninth Avenue e na Juniper Street. Carro que encosta no jogador o **arremessa em ragdoll**, ele fica um tempo no chão e levanta normal **[DEC-095]**; a Tool da mão cai (FEAT-036); **sem perda de sanidade** **[DEC-103]**. Tom pastelão de desenho animado (estrelinhas, "boing"), sem som de impacto realista nem ferimento **[DEC-023]**.

Trânsito (tabela `Traffic`; proposta para **Q-102**, rotas com o level-designer):

| Parâmetro | Dia | Noite, Calma (8–9 PM) | Noite, depois das 9 PM |
|---|---|---|---|
| Carros simultâneos (teto de veículos, fora do teto de 12 NPCs) | 4 | 1 | **0** (só ambulância e ANM-008) |
| Intervalo de spawn por rota | 6–10 s | ~30 s | — |
| Velocidade | 22 studs/s na reta; 12 no cruzamento | igual | — |
| Faróis | apagados | farol **baixo** | — |
| Para no meio-fio? | **nunca** (padrão aprendido de dia) | **nunca** | só a ANM-008 estaciona e acende farol **alto**; é o único carro em movimento (quebra de padrão) |

Noite: adoto os números do `MAP-01.md` §9.5 (≤ 1 carro até 9 PM, 0 depois), em vez do "1 carro raro a noite toda" da versão anterior desta ficha. Motivo: "rua vazia" é o padrão da noite (`world.md`), a ANM-008 fica mais legível como o único carro e o servidor gasta menos. Recomendação para fechar **Q-103**; `tech/architecture.md` e `tech/content-data.md` devem citar esta tabela.
| Durante ANM-008 ativa | — | — (a ANM-008 só existe depois das 9 PM) | sem trânsito |
| Durante ANM-010 (Hush), cutscenes e Final | sem trânsito | sem trânsito | sem trânsito |
| Variantes | 3 modelos × 4 cores; nenhum preto e comprido (reservado à ANM-008) | igual | — |

Travessia **sem semáforo** **[DEC-130, revoga DEC-120]**. **[DEC-131]**: a rota trailer ↔ Mart **cruza a Juniper Sul em CW-1, sem semáforo**; o jogador atravessa **na sorte** e, se atropelado, o pacote cai (DEC-103, FEAT-036). Geometria e rotas: `MAP-01.md` rev.3 (CW-1, TR-7..TR-10). Regra abaixo **[DEC-133]** (Q-129 B); tempo de NPC na pista, anti-bloqueio e noite sem carros na Juniper Sul seguem **Provisórios** (DEC-133); o fluxo de CW-1 é número ajustável sem nova DEC:

| Regra (tabela `Traffic.Crossing`) | Valor |
|---|---|
| Semáforo | **nenhum** no mapa (CW-1..CW-4 e cruzamento Ninth & Juniper) **[DEC-130]** |
| Faixas CW-1..CW-4 | **continuam pintadas**: são os únicos pontos onde NPC cruza a pista e servem de guia visual. Jogador atravessa onde quiser (faixa não o protege) |
| Cruzamento Ninth & Juniper | **Ninth é preferencial** (nunca para). Braços da Juniper (Norte e Sul) têm **placa PARE**: o carro para **1 s** na linha SL-N/SL-S e entra quando a caixa do cruzamento está livre (reserva da caixa no servidor; 1 carro por vez de braço da Juniper) |
| Carro × **jogador** | **nunca** para nem desvia, nem na faixa **[DEC-095, DEC-130]**: é o "na sorte" |
| Carro × **NPC pedestre** (clientes, pedestres, médicos) | o NPC espera no nó do meio-fio e pede a **reserva da faixa** ao servidor; a reserva só é dada se nenhum carro está a menos de **15 studs** da linha da faixa (distância de frenagem: 22 → 0 em 1 s ≈ 11 studs + folga). Com a reserva ativa, carros que chegam param na linha (SL-1N/SL-1S etc.) até o NPC sair da pista |
| Tempo de NPC na pista | 24 studs a 8 studs/s = **3 s**; carro espera no máx. **4 s** por reserva |
| Anti-fila | depois de liberar uma faixa, nova reserva só após **4 s** (carro não fica preso); ladrão nunca cruza pista (`MAP-01.md`) |
| Anti-bloqueio | carro só passa de SL-1S (NB) se há espaço livre até a linha PARE (SL-S): **nenhum carro fica parado dentro da faixa** |
| Spawn de carro (Q-129 d) | só nas pontas de entrada das rotas, fora da área jogável (`MAP-01.md` §9.5: W-IN, JN-IN, JS-IN e a do leste; além de BAR-N/BAR-S); distância do spawn até a 1ª faixa da rota **≥ 55 studs** (≥ 2,5 s de aviso a 22 studs/s, motor audível desde o spawn); intervalo mínimo **3 s** entre carros da mesma faixa de rolagem. Nunca nasce carro com jogador ou NPC a menos de 55 studs da ponta (garantido pelo layout: pontas atrás das barreiras) |
| Fluxo na Juniper Sul (CW-1), dia | **1 carro a cada 12–20 s por sentido** (média 16 s; NB = TR-7 + TR-10, SB = TR-8 + TR-9), dentro do teto de 4 carros do mapa |
| Noite | Juniper Sul sem carros (`MAP-01.md` §9.5); CW-1 livre a noite toda |

Risco da travessia em CW-1 (dia), para calibrar "na sorte" (tabela comparável):

| Jogador | Tempo na pista (24 studs) | Risco atravessando **sem olhar**, por travessia | Olhando antes (brecha visível ≥ 2,5 s) |
|---|---|---|---|
| Runner (18) | 1,3 s | ~15% | ~0% |
| Rookie / Night Owl (16) | 1,5 s | ~16% | ~0% |
| Line Cook (15) | 1,6 s | ~17% | ~0% |

Conta: por sentido, janela de contato ≈ metade do tempo na pista + passagem do carro (~12 studs / 22 ≈ 0,55 s) ≈ 1,3 s; ÷ intervalo médio de 16 s ≈ 8% por sentido, ~16% nos dois. Custo de um atropelamento: 3 s no chão + pegar o pacote (0,5 s) ≈ 4–5 s. Alavanca única: intervalo por sentido em `Traffic.Crossing`.

Tempo da ida ao Mart sem semáforo **[DEC-049: ~25 s]**: 2 × 106 studs / 16 ≈ 13 s andando + ~10 s comprando + espera de brecha ~1 s por travessia (média; máx. ~5 s) ≈ **25 s de dia**, ~23 s à noite. **DEC-049 continua válida** (a revisão 3 com semáforo dava ~28 s; sem semáforo volta ao alvo).

Atropelamento (proposta para **Q-122**):

| Regra | Valor |
|---|---|
| Gatilho | carro de trânsito encosta no jogador a ≥ 6 studs/s (decidido no servidor) |
| Arremesso | ragdoll R6; impulso inicial ~30 studs/s na direção do carro + 15 para cima (architect calibra) |
| Tempo sem controle | **2,5 s** no chão + **0,5 s** levantando = **3 s** |
| Item | só a Tool **equipada** cai (sempre, não é chance); o resto da hotbar fica **[DEC-103]** |
| Sanidade | não muda **[DEC-103]** |
| Proteção | **5 s** depois de levantar, carros atravessam o jogador (sem novo atropelamento); um mesmo carro atinge o mesmo jogador no máximo 1 vez |
| Carro | não freia nem desvia por jogador **[DEC-095, DEC-130]**; só para no PARE (braços da Juniper) e para NPC com reserva de faixa **[DEC-133]** |
| NPCs | **nunca** atropelados: só cruzam a pista em faixa e com reserva (tabela `Traffic.Crossing`); com a reserva, os carros que chegam param |
| Ambulância (NPC-023) | **nunca** atropela: freia para jogador a ≤ 15 studs na frente e a colisão dela com personagem nunca arremessa; velocidades na tabela `Ambulance` (FEAT-034). Ninth é preferencial: não para no cruzamento |
| Prompt em andamento | cancela |
| Anomalia | ragdoll não muda verbos: se um prazo de verbo vence no chão, conta como não cumprido (o jogador é `Active`) |
| Dentro do trailer ou do Mart | fora da pista: nunca atropelado |

Sem semáforo, o padrão aprendível (OBSERVAR) é o ritmo do trânsito e o PARE; a escolha (GERENCIAR) é olhar e esperar a brecha ou arriscar com o pacote na mão. Efeito emergente aceito: atravessar junto com um pedestre NPC é mais seguro (os carros param para ele), e isso é observável, não regra escrita para o jogador.

- Dados: `Traffic` (rotas, densidade por fase, velocidade, variantes), `Traffic.Crossing` (PARE, reserva de faixa, distâncias, intervalos, fluxo por sentido), `Knockdown` (limiar de velocidade, impulso, tempo no chão, proteção).
- Party: atropelamento é por jogador; colegas podem pegar o item derrubado.
- Fora do MVP: carros reagindo a buzina, acidentes entre carros, dano a veículos.
- Critérios de aceite:
  - Nenhum semáforo existe no mapa.
  - Nenhum carro de trânsito para no meio-fio em nenhum momento; carros só param no PARE (braços da Juniper, 1 s ± 0,1) e na linha de faixa com reserva de NPC ativa; carros da Ninth nunca param no cruzamento.
  - Jogador parado na faixa CW-1 sem NPC nela: o carro não freia; se encosta a ≥ 6 studs/s, é atropelado e a Tool equipada (ex.: pacote) cai.
  - Em 1 h simulada, nenhum NPC entra na pista sem reserva de faixa; nenhuma espera de carro por reserva passa de 4 s; nenhum carro fica parado dentro de uma faixa.
  - Em 1 h simulada de dia, intervalo médio entre carros por sentido em CW-1 = 16 s ± 2; nenhum carro nasce a menos de 55 studs de uma faixa; intervalo entre carros da mesma faixa de rolagem ≥ 3 s.
  - Ida ao Mart de dia (Rookie, sem atropelamento, 1 pacote): 25 s ± 3 em playtest (DEC-049).
  - Depois das 9 PM, nenhum carro de trânsito nasce.
  - Atropelado fica 3 s ± 0,2 sem controle, levanta e anda normal; sanidade igual antes e depois.
  - A Tool equipada cai; as outras Tools continuam na hotbar.
  - Em 5 s de proteção, o mesmo jogador parado na pista não é atropelado de novo.
  - Em 1.000 travessias simuladas de NPC, 0 atropelamentos de NPC.
  - Com a ANM-008 ativa, nenhum carro de trânsito nasce.
  - Com 4 carros de dia, o orçamento de performance do architect é respeitado (medir em aparelho disponível, DEC-090).

### FEAT-034 — Desmaio, ambulância e reviver

- Status: Rascunho · Pilares: SOBREVIVER · Origem: **[DEC-043, DEC-091, DEC-092, DEC-093, DEC-094, DEC-100, DEC-102, DEC-108, DEC-023, DEC-114, DEC-115, DEC-116, DEC-117, DEC-118, DEC-129, DEC-216]**; seguem como proposta: tempos e paradas, sanidade ao voltar, uso do item por colega (**Q-120 f**); preço em Robux adiado (**Q-098**)
- Resumo: sanidade 0 → o jogador **desmaia** e cai → a **ambulância** (NPC-023) chega, os **médicos descem e levam o corpo** (NPC-024) **[DEC-114]** → o jogador assiste (FEAT-025) e pode ser **revivido** por **Robux** (developer product, **só para si** **[DEC-116]**) ou pelo **Rescue Whistle** (ITM-021) → a ambulância volta, para em frente ao trailer, ele aparece ao lado e ela vai embora, **sem ninguém descer** **[DEC-091, DEC-114]**. Sem reviver até as 6:00 AM: espectador permanente **[DEC-093, DEC-115]**. Resgate, nunca ferimento **[DEC-023]**. Só existe à noite (sanidade só à noite, DEC-056).

Linha do tempo (t = instante em que a sanidade chega a 0):

| t | O que acontece |
|---|---|
| 0 | estado `Down`; **ragdoll R6** + rosto **`Fainted`** (X) **[DEC-216]**, cai no lugar, sem arremesso (Provisório), fica no chão até os médicos; ~~animação de desmaio suave (1,2 s, sem ragdoll)~~; prompts em curso cancelam; Tools ficam guardadas; servidor despacha a ambulância para a parada do corpo (AMB-M ou AMB-P) |
| 0–2 s | tela do jogador desbota, som abafado; depois câmera de spectate (FEAT-025) |
| 2 s | oferta de reviver aparece no spectate |
| 8 s | ambulância chega à parada (sirene suave, luzes; volume nunca acima do ambiente, sem susto — DEC-005) |
| 8–18,5 s | 2 médicos descem pelas portas traseiras **[DEC-114]**, andam até o corpo (≤ 80 studs, pelo caminho do `MAP-01.md` §9.6), põem na maca (2 s) e voltam carregando |
| 18,5–20 s | médicos sobem; ambulância parte em t = 20 s; some do mapa ~4,5 s (AMB-P) ou ~8 s (AMB-M) depois |

Esta coleta **não** é a janela de 10 s de DEC-094/DEC-118: aquela conta o tempo para **reviver** quando todos caem e corre em paralelo, independente da ambulância. Reviver no meio da coleta segue a regra "Volta" abaixo.

Tabela `Ambulance` (fonte única dos números; `MAP-01.md` §9.6 e `tech/content-data.md` devem citar esta tabela em vez de números próprios):

| Campo | Valor |
|---|---|
| `ArriveAt` | **8 s** após a queda, nas duas paradas |
| `DriveSpeed` | **24 studs/s** na Ninth; **12 studs/s** nos últimos 20 studs antes de parar (resolve `MAP-01.md` rev.3 §15 **P35**: 12 studs/s não chega em 8 s; o level-designer sugeriu 22, que dá ~9 s até AMB-P; 24 fecha em 8,3 s) |
| `SpawnDelay` (entra por AMB-IN) | `ArriveAt − viagem`, calculado por parada: **AMB-P** ~180 studs → 160/24 + 20/12 ≈ **8,3 s** de viagem → entra em t = 0; **AMB-M** ~86 studs → 66/24 + 20/12 ≈ **4,4 s** → entra em t ≈ 3,6 s |
| `YieldDistance` | freia (24 → 0 em 1 s) se há jogador a ≤ 15 studs na frente; colisão com personagem nunca arremessa |
| `MedicSpeed` | **20 studs/s** (era 16; andando e carregando a maca; recomendação do level-designer, `MAP-01.md` rev.3 P35) |
| `MedicReach` | **80 studs** (era 60; `MAP-01.md` rev.3 **P35**: AMB-P → porta dos fundos ~52; corpo **dentro** do trailer até **~75** no fundo oeste, o caso mais comum de queda à noite) |
| `MedicStepOut` | 0,5 s para descer |
| `StretcherTime` | 2 s |
| `CollectTime` | **≤ 10,5 s** (t = 8 → 18,5). Conferência: 0,5 + 80/20 + 2 + 80/20 = **10,5 s** no alcance máximo; fundo do trailer (75) = 10,0 s; porta dos fundos (52) = 7,7 s; AMB-M (≤ 35) ≤ 6,0 s (médicos esperam na porta até t = 18,5). Nome trocado (era `CollectWindow`) para não confundir com a janela de reviver de 10 s |
| `DepartDelay` | 1,5 s depois de os médicos subirem (era 2 s); parte em t = 20 s, como antes |
| `ExitTime` | até AMB-OUT (136, 5): de AMB-P ~92 studs ≈ **4,5 s**; de AMB-M ~186 studs ≈ **8 s** |
| `ReviveReturn` | entra por AMB-IN 2 s após a confirmação; **~8,3 s** até AMB-P; jogador aparece em REV-1..4; parte 2 s depois (total ~12 s da confirmação até a partida) |
| Trânsito (8–9 PM) | com a ambulância despachada não nasce carro de trânsito novo; se já há carro na Ninth EB à frente, ela segue atrás sem ultrapassar (chegada pode atrasar até +2 s) |

| Regra | Valor |
|---|---|
| Paradas | IDs do `MAP-01.md`: **AMB-M** (Mart; quedas a oeste de X −24) e **AMB-P** (em frente ao trailer; todo o resto; é a parada do reviver). Revivido aparece em **REV-1..4**. A antiga "parada no meio da rota" sai |
| Corpo inacessível | > 80 studs de caminho desde a parada ou sem caminho de calçada: a maca aparece na parada e o corpo some em fade 0,5 s junto (caso de exceção; segue **Rascunho**, fora do escopo de DEC-114) |
| Uma ambulância por servidor | várias quedas: na mesma passada ela para em AMB-M e depois em AMB-P (oeste → leste); quem cai com ela já parada na mesma parada entra nessa coleta; senão, na próxima viagem |
| Espera | não despacha enquanto ANM-008 ou ANM-010 estão ativas (o corpo fica no chão, não é alvo de nada); despacha quando terminam |
| Ambulância e anomalias | não é anomalia; sempre o mesmo modelo, cor e sirene (padrão fixo); ver a ambulância não custa sanidade; a ANM-007 não reage a ela |
| Custo | ambulância = 1 no teto de veículos; médicos e maca são atores **visuais** dirigidos pela linha do tempo do servidor, fora do teto de 12 |

Formas de reviver:

| | Robux | Rescue Whistle (ITM-021) |
|---|---|---|
| Moeda | Robux, developer product repetível **[DEC-092]**; preço adiado (**Q-098**) | dinheiro da party, comprado na bancada (FEAT-035) **[DEC-100, DEC-108]** |
| Quem usa | **só o próprio caído, para si mesmo**, botão no spectate. Ninguém paga Robux pelo colega **[DEC-116]** | (a) o próprio caído com o apito na hotbar: botão "Use Whistle" no spectate; (b) um colega `Active` com o apito na mão: "Blow Whistle" (hold 1,5 s em qualquer lugar) revive o caído **mais antigo** da party; a Tool mostra "Revive {name}" antes do uso (proposta para **Q-120 f**; segue Rascunho, DEC-116) |
| Na janela de 10 s | sim, cada caído por si | sim, só o caído que tem o apito (não há colega de pé) |

| Regra do reviver | Valor |
|---|---|
| Volta | tabela `Ambulance` (`ReviveReturn`): a ambulância para em AMB-P, o jogador aparece **de pé** em REV-1..4, ao lado dela, e ela parte; **ninguém desce** **[DEC-091, DEC-114]**. Se a viagem de coleta ainda não terminou, ela termina e segue direto para AMB-P |
| Sanidade ao voltar | floor(50% do máximo da classe): 50 (Rookie, Runner, Line Cook), 60 (Night Owl) |
| Proteção | 5 s sem perda por escuro depois de aparecer (tempo de entrar no trailer) |
| Anomalias já vistas | continuam vistas (não cobra o −5 de novo) |
| Limite | **2 revives por jogador por noite**, somando Robux e Rescue Whistle. Na 3ª queda da mesma noite não há oferta: o jogador vira `Spectator` na hora **[DEC-129]** |
| Prazo | revivível até **6:00 AM** da noite em que caiu; depois vira `Spectator` (FEAT-025) **[DEC-115]** |
| Oferta em tela | botões discretos no canto do spectate; sem pop-up repetido, sem som de chamada, sem contador fora da janela de 10 s (guarda contra "pay-to-skip-horror", **Q-017**) |

Janela de 10 s — todos caídos **[DEC-094, DEC-102]**:

| Regra | Valor |
|---|---|
| Abre | quando o último jogador `Active` conectado cai |
| UI | contador grande "10…0" para todos os caídos, junto da oferta |
| Quem pode | cada caído revive **a si mesmo** (Robux ou apito próprio) **[DEC-116]**; quem já usou 2 revives na noite não pode **[DEC-129]** |
| Sucesso | o 1º reviver confirmado fecha a janela; a noite segue; os outros continuam `Down` até 6:00 AM |
| Falha | ninguém revive em 10 s de contador → noite perdida (FEAT-026) |
| Compra Robux aberta | se um caído está com o prompt de compra aberto, o contador **congela**; teto de **+20 s** no total, depois volta a correr (máximo real 30 s) **[DEC-118]** |
| Recibo não aplicado | se o recibo de Robux não pode ser aplicado (janela fechou, já revivido, comprador saiu, noite já perdida), vira **1 crédito de reviver no perfil persistido** do jogador (`ReviveCredits`), usável num reviver futuro dele **[DEC-117]**. Uso (proposta, sem regra nova): com crédito > 0, o spectate mostra o botão de reviver por crédito no lugar do de Robux; vale como reviver por Robux (só para si, conta no limite de 2/noite, respeita o prazo de 6:00 AM) |
| Atrasado/reconexão | jogador do roster que spawna `Active` durante a janela a fecha com sucesso (FEAT-001) |
| Durante a janela | relógio segue; anomalias seguem sem penalizar ninguém (não há ativo); ANM-007 não avança (ninguém olha) |
| Regra crítica | quebra da ANM-007 perde a noite direto, **sem** janela **[DEC-094]** |
| Solo | cair = janela de 10 s; reviver ou perder a noite |

- Dados: `Revive` (limite por noite 2, prazo 6:00 AM, sanidade 0,5, proteção 5 s, janela 10 s, extensão máx. 20 s, `RobuxSelfOnly = true`, `CreditOnUnapplied = true`), `Ambulance` (tabela acima).
- Fora do MVP: ambulância como anomalia; reviver pago por colega com Robux (proibido por DEC-116); preço crescente (Q-098).
- **Nota 2026-10-17 (DEC-266):** a DEC-258 emenda a DEC-116: o Revive Kit (comprado com Robux) pode ser usado no colega caído, e quem está de pé sem kit vê a oferta dele (1 por queda, texto neutro; `design/monetization-offers-proposal.md` O5). A frase "ninguém paga Robux pelo colega" acima vale só para o reviver da ambulância.
- Critérios de aceite:
  - Sanidade 0 → em 8 s ± 1 a ambulância está em AMB-M ou AMB-P (± 2 s se havia carro de trânsito à frente na Ninth); 2 médicos descem, andam até o corpo e o levam na maca; em ≤ 16 s o corpo sumiu (pega na maca; 14,5 s no alcance máximo + 1 s de tolerância de chegada); a ambulância sai do mapa em ≤ 25 s (AMB-P) ou ≤ 29 s (AMB-M) (+2 s se houve atraso por trânsito).
  - Corpo no fundo oeste do trailer (caminho de ~75 studs desde AMB-P): os médicos vão e voltam em ≤ 10,5 s (`CollectTime`) desde a parada, sem fade; a ambulância parte em t = 20 s ± 1.
  - Corpo a 80 studs de caminho: coleta em 10,5 s ± 0,3, sem fade. Corpo a 81+ studs: maca na parada e fade 0,5 s (exceção).
  - Na janela de 10 s (todos caídos), o contador de reviver não depende da coleta: começa na queda do último ativo, congela só pelo prompt de compra (DEC-118) e não espera nem acelera com a ambulância.
  - Ninguém desce na volta do reviver; o jogador aparece de pé em REV-1..4, ao lado da ambulância em AMB-P.
  - Revivido volta com 50 (Rookie) ou 60 (Night Owl) de sanidade.
  - 3ª queda na mesma noite: sem oferta, `Spectator` na hora.
  - Jogador `Down` às 6:00 AM vira `Spectator` e a oferta some.
  - Nenhum jogador consegue comprar o reviver por Robux para outro jogador (o servidor rejeita alvo ≠ comprador).
  - Recibo de Robux confirmado depois de a noite estar perdida soma +1 em `ReviveCredits` no perfil do jogador e sobrevive a sair e voltar ao jogo.
  - Na janela de 10 s, com o prompt de compra aberto aos 5 s, o contador para; se o prompt fica aberto 25 s, o contador volta a correr aos 20 s de congelamento.
  - Party de 2, os dois caem, um usa o próprio apito aos 7 s: a noite continua; o outro segue `Down`.
  - Party de 2, os dois caem, ninguém age: em 10 s a noite é perdida e a chance da run é usada (ou a run acaba, se já foi usada).
  - Ambulância nunca atropela e nunca é despachada durante ANM-008 ou ANM-010.
  - Nada no reviver mostra sangue, ferimento ou agressor.

### FEAT-035 — Oferta especial da bancada (sorteio por turno)

- Status: Rascunho · Pilares: GERENCIAR, SOBREVIVER · Origem: **[DEC-092, DEC-100, DEC-101, DEC-106, DEC-108, DEC-121, DEC-129]**; chance e preço decididos em DEC-129; nº de slots, quantidade e aviso = proposta para **Q-120**
- Resumo: a bancada do Mart (FEAT-015) tem **1 slot especial** (S1) sorteado no início de cada turno. Hoje o único especial é o **Rescue Whistle** (ITM-021; "Revive Kit" em DEC-129) **[DEC-106]**. Especial novo exige DEC. Os básicos e as prateleiras **nunca** rotacionam.

| Regra (tabela `SpecialOffers`) | Valor |
|---|---|
| Slots especiais | **1** (S1) |
| Quando sorteia | início da Preparação de **cada** turno, dia e noite; no servidor; igual para toda a party |
| Snapshot | a oferta entra no snapshot do turno (FEAT-002): noite repetida e retomada **não** sorteiam de novo (sem "farm" de sorteio) |
| Elegível | a partir do 1º turno depois da compra do trailer (Night 1) **[DEC-129]**. Antes e no modo dia infinito sem trailer: S1 vazio ("Nothing special today") |
| Chance do Rescue Whistle | **15% por turno**, dia e noite **[DEC-129]** |
| Quantidade | 1 unidade por aparição; vendida → "Sold out" até o fim do turno |
| Não vendido | some no fim do turno; não acumula |
| Preço | **$200 × multiplicador da party** (mesmo de DEC-047, party contada como em DEC-121): 1p $200 · 2p $300 · 3p $380 · 4p $440 **[DEC-129]**; prompt "Buy Whistle (${preço})" |
| Limite | 1 por jogador na hotbar (FEAT-005); sem limite por run (a raridade limita; limite por turno/run segue em aberto com o game-designer, DEC-129) |
| Garantia | nenhuma (a raridade é a regra "raramente" de DEC-092) |
| Aviso | notificação "Something rare is on the Mart's back wall!" (`ui-text.md`, 4 s) no início do turno em que S1 tem o apito; S1 tem lâmpada acesa. **Mart v2 (2026-10-11, Provisório):** o S1 vira o pedestal da ponta direita do Gear Stand (`MAP-01.md` §18.4); a porta de enrolar desce no `Summary` e sobe no `Prep` já com o sorteio novo (FEAT-015 v2); texto do aviso a trocar "back wall" pelo nome da bancada (TASK-142) |

Probabilidade numa run perfeita (19 turnos depois do trailer: Night 1–10 + Day 6–14):

| Chance por turno | Aparições esperadas | P(nenhuma) | P(≥ 2) |
|---|---|---|---|
| 10% | 1,9 | 13,5% | 58% |
| **15% (DEC-129)** | **2,85** | **4,6%** | **80%** |
| 20% | 3,8 | 1,4% | 92% |

Peso econômico (solo, `economy.md` §5): $200 ≈ 2 dias de lucro ou ~0,8 ciclo dia+noite. Antes de ~Day 8 compete com Grill 3 / Counter 3 (tensão "upgrade ou seguro"); depois, dá uso ao dinheiro sobrando (DEC-082). Comprar as ~3 ofertas da run custa ~$600 dos ~$1.770 que sobram.

- Critérios de aceite:
  - Em 10.000 sorteios simulados de turnos elegíveis, o Rescue Whistle aparece em 15% ± 1 p.p.
  - Nenhum Rescue Whistle aparece antes da compra do trailer.
  - Party de 3 cujo 3º membro saiu no Day 4: o apito custa $380 (party contada no fim do Day 1).
  - Noite perdida e repetida mostra a mesma oferta especial do início da noite.
  - Todos os jogadores da party veem a mesma oferta no mesmo turno.
  - B1–B5 e as prateleiras não mudam com o sorteio.

### FEAT-036 — Item no chão (derrubar e pegar)

- Status: Rascunho · Pilares: GERENCIAR · Origem: **[DEC-040, DEC-103]**; proposta do game-designer (dono) para **Q-122 e, f**; `tech/architecture.md` e `tech/content-data.md` devem copiar estes números
- Resumo: mecanismo único para Tool que sai da mão sem ser usada: atropelamento (FEAT-033) e espectador permanente (FEAT-025). No atropelamento cai **só a Tool equipada** (DEC-103: "derruba o item da mão"); o resto da hotbar fica.

| Item | No chão | Pode ser pego? | Some depois de |
|---|---|---|---|
| Pacote (ITM-011 a ITM-019) | mantém a contagem | sim, qualquer jogador da party | 60 s (na rua); fim do turno seguinte (balcão do trailer) |
| Rescue Whistle (ITM-021) | intacto | sim | 60 s (na rua); fim do turno seguinte (balcão do trailer) |
| Hot Dog (ITM-010) | perdido: "splat" cômico | não | 2 s (ingredientes perdidos) |
| Coffee (ITM-009) | derrama | não | 2 s (dose perdida) |
| Item alterado (ITM-020) | some com o chiado da ANM-002 | não | na hora; a ocorrência fecha sem sucesso nem falha |

| Regra | Valor |
|---|---|
| Onde cai | no ponto do impacto; se for na pista, o servidor move para a calçada mais próxima (ninguém precisa buscar item no meio dos carros) |
| Pegar | prompt "Take" (hold 0,5 s, 7 studs; mesmo texto do item alterado, `ui-text.md`); respeita o limite da hotbar e de pacotes |
| Visível | para toda a party; contorno leve para achar no escuro |
| Snapshot | itens no chão não entram no snapshot (somem na noite perdida e na retomada) |

- Critérios de aceite:
  - Pacote derrubado com 5 usos é pego por outro jogador com 5 usos.
  - Atropelado com Hot Dog equipado e 2 pacotes na hotbar: só o Hot Dog cai; os 2 pacotes continuam na hotbar.
  - Pacote derrubado na rua e não pego some em 60 s ± 1.
  - Hot Dog derrubado nunca pode ser servido.
  - Item caído na pista aparece na calçada mais próxima.

# Pad: mesas e grupos (2026-10-11)

Ideia do usuário (2026-10-11): mesas compradas como progressão; cliente pode sentar para comer em vez de ir embora;
vale também para o trailer; clientes em duplas ou casais. Escrito pelo game-designer como **Rascunho / Provisório**
(DEC-193). Pontos que dependem do usuário: `Q-178` a `Q-182`. O usuário já pôs no place **5 mesas de piquenique**
(`AST-100_PicnicTable` em `workspace.MAP01_Assets.PadDecor`, atrás do carrinho), cada uma com 4 Parts `Seat1..Seat4` na
altura do tronco do NPC sentado e com o `LookVector` virado para a mesa (conferido pelo usuário com um NPC sentado).

Restrições que continuam valendo e moldaram a proposta: **sem reputação** (DEC-051), **sem XP** (DEC-081), **teto de 12
NPCs** e de 8/6 clientes vivos (DEC-045), todo pagamento cai na **gaveta** (DEC-050), toda compra tem **peça visível**
(DEC-052) e **efeito de dia e de noite** (DEC-006), anomalias só sem sistema novo (DEC-195; `anomalies.md` Aprovado),
"rua deserta" em tensão (DEC-183, `Q-162` b), dinheiro sobrando depois de ~Day 8 aceito e "decoração" como uso futuro
(DEC-082, `economy.md` §7).

### FEAT-037 — Mesas do Pad / área de consumo

- Status: Rascunho (Provisório) · Pilares: VENDER, GERENCIAR, PROGREDIR · **Atualização 2026-10-12 (`Q-209`):** as mesas têm **grupos** — Pad (`TBL-1..5`, UPG-008) e Trailer (`TBL-6..9`, UPG-011, só com o trailer, invisíveis até lá, uma por vez como fantasma); uma party nunca mistura grupos · Origem: pedido do usuário 2026-10-11; **[DEC-006, DEC-045, DEC-050, DEC-051, DEC-052, DEC-082, DEC-183, DEC-195]**; fichas UPG-008, UPG-009, UPG-010
- **Fluxo com mesa (2026-10-12, pedido do dono, Provisório, `Q-209`):** o cliente pede, o jogador faz **Take Order** e o
  cliente **senta na mesa** (mesa livre do veículo ativo; sem mesa fica no balcão como antes). O jogador **leva o hot
  dog até a mesa** e usa **"Serve Table n: <pedido>"** (ação `serve_table`; o texto e a etiqueta "TABLE n" dizem qual
  item vai para qual cliente; o menu de interação mostra uma linha por mesa). Entrega = regras do balcão (Completo /
  Incompleto / Errado; dupla com 2 hot dogs). A paciência do preparo segue contando sentado; servido bem, ele come e
  deixa bandeja + gorjeta de mesa; errado / paciência / tensão / fim de turno: levanta sem comer. A "chance de sentar"
  da tabela abaixo **não vale mais** (mesa livre = senta; `SitChanceApplies`); as linhas "Quem pode sentar" /
  "Condições" valem no **Take Order** em vez de depois da entrega.
- Resumo: a party compra até **5 mesas** no Pad, uma por vez, na própria mesa "fantasma". Cliente que recebeu pedido
  **Completo** pode sentar para comer em vez de ir embora (**histórico**, ver o fluxo acima). Ao levantar, deixa **bandeja + $2 de gorjeta de mesa** em
  cima da mesa. A mesa fica **suja** (ninguém senta) até um jogador fazer "Clean Table": a gorjeta vai para a gaveta e
  a mesa volta a receber cliente. É um trabalho **opcional**: ignorar as mesas nunca piora a nota nem o fluxo; cuidar
  delas rende dinheiro, mas tira o jogador do balcão (de dia expõe a gaveta ao ladrão; à noite pode custar escuro).

Por que esse efeito (alternativas consideradas):

| Opção de efeito | Prós | Contras | Escolha |
|---|---|---|---|
| **A. Gorjeta de mesa + limpeza** | tangível (moeda em cima da mesa); cria um papel novo em party; liga com ladrão (raio 14) e com escuro/luz à noite; zero mudança nas fórmulas da DEC-072 | 1 prompt novo, 1 estado por mesa; solo tem de dividir atenção | **recomendada** |
| B. Bônus na nota do turno (sentado conta 1,5 satisfeito) | sem prompt novo | invisível; mexe na DEC-051; nota A ficaria fácil | não |
| C. Fluxo +x% por mesa ("atrai clientes") | só número (`DayFlowBonus` já existe) | o gargalo é o balcão, efeito some quando a fila enche; nada para fazer | não |
| D. Segundo pedido na mesa ("Seconds") | lucro forte; usa "Take Order"/"Serve" que já existem | entrega fora do balcão, balão no Pad, validação nova; escopo maior | **fora do MVP** (fase 2) |

| Regra | Valor (dados em `Content.Seating`, proposta) |
|---|---|
| Mesas | 5 posições fixas no Pad: `TBL-1`..`TBL-5` = as 5 `AST-100_PicnicTable` já no place; 4 assentos cada (`Seat1..Seat4`). Pares de assento: `Seat1`+`Seat2` no mesmo banco, `Seat3`+`Seat4` no banco da frente; `Seat1` encara `Seat3` (o level-designer confere e renomeia se preciso, TASK-149) |
| Liberação | **Day 2** (o Day 1 é tutorial; sem fantasma no Day 1) |
| Antes da compra | mesa "fantasma": malha a 70% de transparência, sem colisão, sem assento; só a **próxima** da ordem mostra placa e prompt; as outras ficam fantasma sem prompt |
| Ordem de compra | fixa, da mais perto da fila para a mais longe (`TBL-1` → `TBL-5`); o level-designer define a ordem pela distância a Q1 |
| Compra | prompt na mesa fantasma: **"Buy Table — $N"**, hold **1,5 s**, Radius 7; qualquer membro; dinheiro da party; recusa `not_enough_cash` (`Q-178`: compra no Pad × Gear Stand) |
| Preço por mesa | **$30 · $45 · $60 · $80 · $100** (total **$315**) — UPG-008 |
| Efeito da compra | imediato: a mesa ganha cor e colisão com VFX de "pronto" + SFX-065; toast "Table added!" 3 s para a party |
| Quem pode sentar | cliente normal (NPC-001 a NPC-006) com o pedido **Completo** (grupo: FEAT-038). Incompleto, Errado, Desistiu, Recusado: vai embora como hoje. **Nunca**: ator de anomalia (NPC-009 a NPC-018), ladrão, Mr. Pickett (âncora da ANM-004), passante, Opal |
| Chance de sentar | `CustomerTypes.SitChance` do tipo (tabela abaixo) × **0,75 à noite**; +**0,20** se grupo; +**0,10** com Patio Lights (UPG-009); teto 0,95 |
| Condições (todas) | (1) há mesa comprada, **limpa e livre**; (2) diners vivos < `MaxDiners` (**Day 4 · Night 2** NPCs); (3) folga no teto: clientes vivos ≤ `MaxCustomers` − **2** (`SitHeadroom`), contando o próprio; (4) fase `Open` ou `Night`; (5) nenhuma tensão ativa (abaixo). Falhou uma: vai embora como hoje |
| Escolha da mesa | a mesa limpa e livre **mais perto de Q1** (legível, previsível) |
| Ocupação | **1 cliente ou 1 grupo por mesa**, nunca estranhos juntos. Sozinho: `Seat1`. Dupla: `Seat1`+`Seat3` (frente a frente); casal: `Seat1`+`Seat2` (lado a lado) |
| Caminho | Q1 → mesa (nós novos do grafo, TASK-149) → depois da refeição, mesa → saída normal (EX-E 60% / D1 40%, invariante 7). Nenhuma rota de mesa cruza a fila nem passa na frente do balcão |
| Tempo sentado (`EatTime`) | dia **20 s** · noite **24 s**, ±3 s; grupo +4 s. Come o hot dog que recebeu (3 mordidas, clipe se existir, senão idle sentado) |
| Ao levantar | deixa **bandeja** (embalagem amassada) e **moeda** de gorjeta de mesa sobre o tampo; mesa vira **suja** |
| Gorjeta de mesa (`TableTip`) | **$2 por cliente** que sentou (dupla = $4), dia e noite; fica na mesa, não na gaveta, até a limpeza. Independe da gorjeta de balcão (DEC-072 não muda) |
| Limpar | prompt **"Clean Table"** na mesa suja, hold **1 s**, Radius 7, qualquer membro `Active`; a gorjeta entra na **gaveta** (DEC-050; "+$4" flutuante na mesa e na gaveta); bandeja some; mesa volta a limpa |
| Mesa suja | ninguém senta; sem prazo, sem penalidade de nota, sem cheiro/mosca no MVP |
| Todas ocupadas ou sujas | o cliente vai embora como hoje (nada muda no loop) |
| `Closing` | ninguém senta; quem está sentado termina o tempo e sai |
| `Summary` | diners restantes somem fora de vista (já saindo); mesas limpam sozinhas; **gorjeta não recolhida se perde** (`Q-181`); compras de mesa ficam (são da run) |
| Snapshot / noite perdida / retomada | **compras** de mesa entram no snapshot (como upgrades, FEAT-015); estado limpa/suja e gorjeta na mesa **não** (começa limpa). Gorjeta da noite perdida some com a gaveta (DEC-053) |
| Troca de veículo | as mesas são do **Pad**, não do veículo: continuam compradas depois da troca para o trailer (`Q-179`; leitura de DEC-184) |
| Ladrão (dia) | não mexe na mesa. A zona do ladrão continua o raio 14 de `CART`: limpar uma mesa fora dele deixa a gaveta exposta (escolha visível do jogador) |
| Tensão (noite) | durante ANM-007 (do zumbido ao fim), ANM-008, ANM-009 e ANM-010, e enquanto houver ator de anomalia de cliente vivo: ninguém senta; quem está sentado **levanta e vai embora** (bandeja e gorjeta ficam). Mesma lógica de "rua deserta" (DEC-183) |
| Escuro (noite) | mesa fora de `LightZone` ativa: quem limpa paga escuro normal (> 3 s → −1/s, FEAT-020). Trailer Lights (raio 18) cobre as mesas que estiverem no raio; Patio Lights (UPG-009) cobre todas |
| Sanidade baixa | diners são clientes: o observador com sanidade < 40 os vê no pack Night (DEC-168), sem regra nova (**Provisório (2026-10-14):** não vale mais, a faixa baixa não veste NPC) |
| Janela fechada (DEC-221) | não afeta quem já está sentado; a janela só bloqueia o balcão |

`SitChance` por tipo (campo novo em `CustomerTypes`; Provisório):

| Tipo | `SitChance` dia | Noite (× 0,75) | Leitura |
|---|---|---|---|
| NPC-001 Office Worker | 0,30 | 0,23 | come rápido, volta ao escritório |
| NPC-002 Student | 0,60 | — | turma que fica |
| NPC-003 Jogger | 0,10 | — | come andando |
| NPC-004 Construction Worker | 0,50 | 0,38 | pausa do almoço |
| NPC-005 Grandparent | 0,70 | — | sem pressa |
| NPC-006 Night Shift Worker | — | 0,30 (valor base 0,40) | intervalo do turno |
| NPC-021 Mr. Pickett | 0 | 0 | âncora da ANM-004: comportamento fixo |

Média ponderada pelos pesos de spawn: dia **~0,43**, noite **~0,30**.

Invariante novo de cliente (para o padrão da DEC-010; nenhuma anomalia nova usa isso no MVP): **cliente sentado sempre
come, sempre levanta depois do `EatTime`, sempre deixa bandeja e moeda e sai pela saída normal**. Uma futura
anomalia "o que não levanta" fica anotada para depois do MVP (exige DEC; `anomalies.md` é Aprovado e DEC-195 veta
sistema novo agora).

Orçamento de NPC (DEC-045): **Provisório** = diners são clientes e contam em `MaxCustomers` (8 dia / 6 noite) e no teto
de 12 — nenhum número da DEC muda. `SitHeadroom = 2` garante que sentar nunca faz a próxima tentativa de spawn sair
`SkippedCap` por causa de uma mesa. Custo: em party de 4 no pico (balcão cheio) quase ninguém senta. Alternativa em
`Q-180`: NPC sentado "estacionado" (ancorado, sem pathfinding, sem `Humanoid` ativo) fora do teto de 12, com teto
próprio `MaxSeated` 4/2, como a Opal; mexe na DEC-045, volta ao usuário. Dado: `Seating.SeatedOutsideCap` (false).

Dados (proposta para o architect, TASK-144):

| Tabela / campo | Valor |
|---|---|
| `Content.Seating` (novo, registro) | `UnlockDay` 2 · `EatTime` { Day 20, Night 24, Jitter 3, GroupExtra 4 } · `TableTip` 2 · `MaxDiners` { Day 4, Night 2 } · `SitHeadroom` 2 · `NightSitMult` 0,75 · `GroupSitBonus` 0,20 · `SitChanceCap` 0,95 · `CleanHold` 1 · `BuyHold` 1,5 · `PromptRadius` 7 · `TipLostAtSummary` true · `SeatedOutsideCap` false · `SitPhases` { `Open`, `Night` } · `TensionAnomalies` { anm_007, anm_008, anm_009, anm_010 } · `GhostTransparency` 0,7 |
| `Content.Upgrades` | UPG-008 `patio_tables` (níveis 0..5, `Effects.TableCount`), UPG-009 `patio_lights`, UPG-010 `back_bar`; campo novo de **onde se compra** (`SoldAt = "InPlace"`, com `PlaceSpots`) e de **escopo** (`Scope = "Pad"`: não recomeça na troca de veículo) |
| `Content.CustomerTypes` | campo `SitChance` (tabela acima) |
| `MapIndex` | `TBL-1..5` (ordem), `Seat1..4` por mesa, `Prompt_BuyTable`, `Prompt_CleanTable`, âncora da bandeja `Tray_Anchor`, nós do grafo mesa ↔ Q1/saída |

- Party: qualquer membro compra e limpa; a gorjeta da mesa é da party (gaveta). Em party, "quem limpa" vira papel
  natural; o balcão continua sendo o gargalo (Counter, FEAT-009).
- Fora do MVP: segundo pedido na mesa ("Seconds"), sujeira que piora com o tempo (moscas, nota), cliente que espera mesa,
  decoração cosmética por mesa (guarda-sol, vaso, toalha), anomalia "o que não levanta".
- Critérios de aceite:
  - Antes do Day 2 nenhuma mesa fantasma nem prompt de compra aparece; do Day 2 em diante só a próxima mesa da ordem tem prompt.
  - Comprar a mesa n debita exatamente o preço da tabela; sem saldo, nada muda e o servidor responde `not_enough_cash`.
  - Em 1.000 clientes simulados de cada tipo com mesa livre, folga e sem tensão, a fração que senta fica a ±3 p.p. do `SitChance` (× 0,75 à noite).
  - Cliente Incompleto, Errado, Desistiu ou Recusado nunca senta; ator de anomalia, ladrão, Pickett e passante nunca sentam.
  - Nunca há mais diners vivos que `MaxDiners` do turno; nunca dois grupos/clientes estranhos na mesma mesa.
  - Com `SitHeadroom` 2, nenhuma tentativa de spawn sai `SkippedCap` por causa de um cliente que sentou (contador do `CustomerService`).
  - O cliente sentado levanta em `EatTime` ± 3 s (± 0,2 s de tolerância de medição), deixa bandeja e $2 por pessoa na mesa e sai por EX-E ou D1.
  - "Clean Table" só aparece em mesa suja; depois do hold a gaveta sobe exatamente o valor da mesa para todos os jogadores e a mesa volta a receber cliente.
  - No `Summary`, toda mesa está limpa e a gorjeta não recolhida não entra na gaveta.
  - Durante ANM-007/008/009/010, ninguém senta e todo diner vivo levanta em ≤ 1 s.
  - Depois da troca para o trailer, as mesas compradas continuam (com `Scope = "Pad"`); a próxima mesa fantasma continua com o mesmo preço.
  - Noite perdida e repetida: mesas compradas continuam, todas limpas, sem gorjeta nas mesas.
- Pendências: `Q-178` (onde e como se compra), `Q-179` (mesas × troca de veículo; bancada traseira do trailer), `Q-180` (teto de NPC), `Q-181` (limpeza e gorjeta perdida).

### FEAT-038 — Clientes em dupla

- Status: Rascunho (Provisório) · Pilares: VENDER · Origem: pedido do usuário 2026-10-11; **[DEC-010, DEC-045, DEC-071, DEC-072, DEC-188]**
- Resumo: uma tentativa de spawn pode gerar **2 clientes juntos** (dupla de amigos/colegas ou casal). A dupla ocupa **1 vaga**
  da fila, faz **um pedido com 2 hot dogs**, paga por hot dog e, se for sentar, senta junta na mesma mesa (FEAT-037).

| Regra | Valor (dados em `Flow.Groups`, proposta) |
|---|---|
| Chance por tentativa | Day 1: **0** · Day 2+: **0,20** · Night 1: **0** · Night 2+: **0,10** (`Q-182`) |
| Espaço | a dupla só nasce se couberem **2** no teto de clientes vivos e no teto de 12; senão nasce **1** cliente (a tentativa sai `Spawned` igual) |
| Intervalo depois de uma dupla | próximo intervalo **× 1,6** (`IntervalMult`): com 20% de duplas, pessoas/min **+7%**, tentativas/min −11%; o fluxo da DEC-045 fica quase igual |
| Composição | tabela `Groups.Pairs` (abaixo): cada membro tem o próprio tipo, espécie, roupa e acessório. **Nunca** os dois com mesma espécie **e** mesma roupa (invariante 3); **à noite, nunca a mesma espécie** (não pode lembrar as cópias da ANM-004) |
| Casal | par com `Couple = true`: anda lado a lado e senta lado a lado (`Seat1`+`Seat2`); dupla comum anda em fila e senta frente a frente. Tom Mild: sem gesto romântico, só "chegam juntos" (falas com o narrative-writer) |
| Andar | líder com pathfinding; parceiro **segue** o líder (alvo = posição do líder + deslocamento de 2 studs), sem pathfinding próprio (custo de IA ~1 NPC) |
| Fila | **1 vaga**; o líder no ponto Q, o parceiro **1,8 stud ao lado** (o level-designer confere que não invade a vaga vizinha, 5 studs entre vagas) |
| Pedido | um "Take Order" anota os dois; K de cada hot dog sorteado à parte (fase + `KShift` do tipo de cada um); balão com **2 linhas** (uma por hot dog) |
| Paciência | fila 45 s + Counter (só o líder em Q1); preparo 75 + 5 × (K1 + K2) + Counter + **10 s** (`PatienceBonus`) **[Q-192, Provisório; K = soma]** |
| Janela de gorjeta | 16 + 4 × (K1 + K2) s; **$1 por hot dog Completo** dentro da janela (Hawker $2 por hot dog; Shift Lead $0) |
| Serve | cada Hot Dog é entregue sozinho; o servidor casa com o item pendente: **igual** → Completo; **subconjunto** → Incompleto do item com menos faltas; tem complemento que nenhum item pendente pede → **Errado** (volta para a mão) |
| Entrega dos dois de uma vez (2026-10-11, Provisório) | se o hot dog na mão bate **exatamente** (Completo) com um item pendente **e** o outro hot dog da hotbar bate **exatamente** com o item que sobra, **uma só interação** ("Serve") recolhe os dois: cada item é pago, com gorjeta e resultado/`Sale` por conta própria (mesmas regras de duas entregas); o relógio de paciência do preparo cobre os dois. Só um bate (ou é Incompleto/Errado): entrega só aquele, como antes. Regra de `AddServeRule` (override) nunca entrega em dobro |
| Pagamento | por hot dog, na hora, na gaveta (DEC-050) |
| Ir embora | quando os 2 itens estão resolvidos. Paciência zerou: itens pendentes = Desistiu. "Refuse" recusa a dupla inteira |
| Nota do turno | conta como **2 clientes** (um por hot dog) |
| Mesas | a dupla decide junta: chance do tipo do **líder** + 0,20; senta se os 2 itens saíram Completos ou Incompletos e **≥ 1 Completo**; 1 mesa só |
| Exclusões | atores de anomalia, ladrão, Mr. Pickett e passantes nunca em dupla |

`Groups.Pairs` (Provisório; pesos dentro do turno):

| Turno | Par (líder + parceiro) | Peso | Casal? |
|---|---|---|---|
| Dia | Student + Student (Hamster + Rato) | 30 | não |
| Dia | Office Worker + Office Worker (roupas diferentes) | 20 | não |
| Dia | Grandparent + Grandparent (Tartaruga + Ovelha) | 15 | **sim** |
| Dia | Construction Worker + Construction Worker (roupas diferentes) | 15 | não |
| Dia | Office Worker + Student | 10 | não |
| Dia | Construction Worker + Office Worker | 10 | não |
| Noite | Night Shift Worker + Construction Worker | 40 | não |
| Noite | Night Shift Worker + Office Worker | 35 | não |
| Noite | Office Worker + Construction Worker | 25 | não |

Par com tipo ainda bloqueado no dia (ex.: Grandparent antes do Day 3) tem peso 0.

Leitura de balanço (solo, Day 6, estimativa de mesa): +7% de pessoas → ~+$5/dia se o jogador der conta; 2 hot dogs de
uma vez pesam mais na tábua (2 vagas no carrinho, DEC-215) e na grelha; o +10 s de paciência e a janela pela soma de K
cobrem a montagem dobrada (~2 × 8–10 s). Em party, dupla é ótima (2 jogadores montam em paralelo).

- Party: nada muda além do fluxo; qualquer jogador serve qualquer item.
- Fora do MVP: grupos de 3–4, família com filhote, pedido "para dividir".
- Critérios de aceite:
  - Em 10.000 tentativas simuladas (Day 2+, com espaço), 20% ± 1 p.p. viram dupla; Night 2+: 10% ± 1 p.p.; Day 1 e Night 1: 0.
  - Sem espaço para 2, nasce 1 cliente e o contador registra `Spawned` (nunca `SkippedCap` por causa da dupla).
  - A dupla ocupa exatamente 1 vaga; com Counter 1 e uma dupla na fila ainda há 2 vagas livres.
  - Nenhuma dupla com mesma espécie e mesma roupa; à noite nenhuma com a mesma espécie.
  - Paciência e janela de gorjeta batem com as fórmulas pela soma de K (± 0,2 s).
  - Servir o mesmo hot dog Completo duas vezes: o 2º é avaliado contra o item que sobrou (Completo só se igual).
  - Recusar a dupla tira os 2 da fila e conta 2 insatisfeitos na nota.
  - Parceiro nunca usa pathfinding próprio (conferir no `CustomerService`) e nunca fica a > 4 studs do líder andando.
- Pendências: `Q-182` (dupla à noite e leitura de "casal").

### FEAT-039 — Modo de preparo focado (estações de preparo)

- Status: **Rascunho (Provisório)** · Pilares: VENDER (noite: OBSERVAR, SOBREVIVER) · Origem: **ideia do dono, 2026-10-12**; autor: secretário, a validar pelo game-designer. Toca FEAT-005, FEAT-006, FEAT-010, FEAT-011, FEAT-019, FEAT-022, FEAT-023, FEAT-037, FEAT-038.
- **Decidido pelo dono em 2026-10-12 (DEC-223):** **V1, 100% focado**: é o **único** jeito de fazer o hot dog e **substitui** o modo de prompts no mundo; interface por **abas de estação** (Order, Grill, Build, Serve) + ticket + lixeira + botão Next, com identidade própria; câmera focada; **1–4 estações = nº de jogadores**. Responde `Q-218` e `Q-220`. O **corpo abaixo** foi ajustado a V1; onde ainda aparece "modo rápido", "Quick Slice" ou "V2", leia como **modo atual substituído** (só referência). **Provisório** = detalhes inferidos (abas, lixeira, Day 1, Assist obrigatório). Segue sem `Aprovado` do documento.
- Inspiração (conceito, não cópia; **CLAUDE.md**): jogos flash de preparo por estações e um jogo de anomalia em que se descasca e se frita batata para vender. O jogo das batatas **não foi identificado**: o único candidato achado, "Sell Fries (Anomaly)", tem confiança média-baixa (um post em rede social; sem loja, criador ou drive-thru confirmados); pedir o nome ao dono. Nomes, personagens, falas, assets e layout de outros jogos **não entram**.
- Resumo: ao ativar uma **tábua**, a câmera se aproxima da bancada e o jogador monta o hot dog com **mini-etapas manuais** (cortar o pão, posicionar a salsicha, aplicar molhos e coberturas), com barra de progresso, feedback tátil e uma **nota de precisão** (Perfect / Good / Messy). O resultado é o mesmo Tool "HotDog" de hoje, com um atributo de qualidade. **Substitui** o modo de prompts no mundo do FEAT-006 (DEC-223); não troca o conteúdo do pedido (DEC-072 não muda).

#### Interface por estações (DEC-223, Provisório nos detalhes)

Inspirada em jogos de preparo por estações (conceito, não cópia; nomes, arte e layout próprios). Uma tela de foco por jogador, com **abas de estação** em uma barra única (Mustard, cantos arredondados, sem vermelho):

| Aba | O que mostra | Ação | Notas (Provisório) |
|---|---|---|---|
| **Order** | ticket do pedido (balões do "Take Order", ordem de chegada), troca de ticket | escolher o ticket; **Next** passa ao próximo | o ticket fica sempre visível nas outras abas (miniatura) |
| **Grill** | o roller grill (DEC-201) com as salsichas cozinhando e a barra de cada uma | pôr salsicha do estoque; coletar a pronta para o trilho | cozinha **em paralelo**, mesmo com o jogador em outra aba; **sem queimar** (FEAT-006); "ponto" em `Q-222` |
| **Build** | tábua: cortar o pão, posicionar a salsicha, molhos e complementos (os gestos abaixo) | arrastar/segurar | é o miolo já desenhado neste FEAT |
| **Serve** | prato pronto × ticket (selo de nota) | conferir e levar à janela/mesa | a entrega ao cliente continua um prompt no mundo (`Serve`, `Serve Table n`) |

- **Lixeira** (canto): descarta o prato em montagem; o estoque gasto não volta.
- **Next**: botão Mustard no canto, avança o ticket/etapa (nada centralizado em 1ª pessoa).
- Sem prompts de preparo no mundo: o jogador entra na estação por **um prompt** na tábua e **tudo** acontece na tela de foco.

#### Por que (e o que o dono gostou)

- Foca totalmente no produto: o jogador "toca" a comida (câmera próxima, ação tátil, barra de progresso).
- Dá habilidade e identidade ao gesto mais repetido do jogo; a nota cria motivo para melhorar.
- Funciona em co-op: cada jogador na sua tábua.
- Tensão com o resto do jogo: o dia é curto (~4,6 min, Q-200) e o fluxo solo é ~1 cliente a cada 14 s. O modo focado só serve se couber nesse ritmo (alvo abaixo) e se não abrir fuga das anomalias (§Noite).

#### Lições de referência (resumo da pesquisa; fontes oficiais deram 403, itens marcados "?" não foram confirmados)

1. Prato em 3–4 mini-etapas curtas, cada uma com um gesto próprio.
2. Câmera próxima, foco total na comida.
3. Feedback imediato por gesto: barra, partículas, som, pequeno tremor ao acertar.
4. Nota por precisão em cada etapa, com o motivo do erro visível; o cliente julga o prato final.
5. Gorjeta ligada à precisão, não só à velocidade; esperar demais custa nota.
6. Ticket sempre visível durante a montagem (?).
7. Upgrades que mudam a estação (tolerância, novos ingredientes), não só números.
8. Dificuldade cresce com pedidos mais complexos e fila maior.
9. Co-op: 1–4 tábuas, cada jogador numa estação (ideia do dono; um jogo de cozinha cooperativo no Roblox usa estações com minijogos em times, sem fonte oficial).
10. Mobile: toque/arrasto simples, alvos grandes, alternativa de toque no lugar da precisão fina; servidor valida o resumo do minijogo, cliente roda local (latência 100–300 ms típica).

Riscos da pesquisa: tédio por repetição, fila × tempo de preparo, arrasto no dedo, jogador parado sem função, validação sem punir ping alto.

#### Variantes (**decidido pelo dono: V1, DEC-223**)

| Variante | O que é | Situação |
|---|---|---|
| **V1 — Substitui tudo** | Só existe o modo focado; tábuas = jogadores (1–4); abas de estação incluindo a grelha | **ESCOLHIDA (DEC-223).** Riscos aceitos pelo dono: ritmo e fila, mobile sem alternativa, FEAT-005 (aceite do mobile) emendado, FEAT-006 (grelha em paralelo, sem queimar) mantido. Mitigação em Riscos e em `Q-223` |
| ~~V2 — Opcional por prompt~~ | A tábua oferecia "Prepare" (focado) e "Quick Slice" (modo atual) | **Descartada (DEC-223).** Era a recomendação do secretário; o dono preferiu o foco total. Fica só como histórico |
| ~~V3 — Só pedidos "Deluxe"~~ | Focado só para clientes que pedem "caprichado" | **Descartada (DEC-223).** Histórico |

#### Escopo (fase 1, V1)

| Dentro | Fora da fase 1 (ver "Fora do MVP") |
|---|---|
| Modo focado como **único** preparo: abas Order/Grill/Build/Serve, cortar pão, posicionar salsicha, molhos e coberturas, entrega ao Tool | "Virar/ponto" da salsicha e queimar — `Q-222` (a aba Grill existe, sem queimar) |
| Nota Perfect/Good/Messy por etapa e do prato | Bebidas, sobremesa, estações novas |
| Câmera focada, travar movimento, HUD de etapa e ticket | Replays, estrelas por cliente, ranking |
| Controles de desktop, toque e gamepad; opção Assist | Animações novas dos braços (o usuário anima, DEC-220) |
| Tabela de dados `Content.Focus` | Segundo pedido na mesa (FEAT-037 D) |

#### Loop passo a passo (um hot dog)

Estado por tábua (servidor): `Idle` → `Focused` (etapa `Cut` → `Place` → `Topping[i]` → `Done`) → `Parked` (saiu no meio) → `Idle`. Cada etapa é aberta e fechada com mensagem ao servidor (§Rede).

| # | Passo | O que o jogador faz | Número (Provisório) | Gasto de estoque |
|---|---|---|---|---|
| 0 | **Entrar** | prompt "Prepare" na tábua (toque, 0 s); a câmera viaja ao ponto de foco; o jogador fica parado; o ticket mais antigo sem dono é sugerido | viagem 0,35 s (instantânea com "reduced motion"); sair 0,30 s | nenhum |
| 1 | **Cortar o pão** | um pão (modelo AST-001 aberto em linha) aparece com a **linha tracejada** do corte; o jogador **arrasta a faca** ao longo da linha da esquerda para a direita; barra de progresso acompanha; som de corte contínuo | duração ~1,2–2,0 s; precisa cobrir ≥ 95% da linha | **1 Bun** ao abrir a etapa |
| 2 | **Posicionar a salsicha** | salsicha pronta do trilho (a mais antiga, como "Add Sausage") flutua ao lado; **arrastar até o vão do pão**; imã de encaixe a 20% do alvo; se não há salsicha pronta, a etapa **espera** (tela "Waiting for the grill"), o jogador pode sair (`Parked`) | ~1,0 s | **1 Sausage** ao abrir a etapa (tirada do trilho) |
| 3..5 | **Complementos** (0 a 3, na ordem do ticket) | gesto por tipo (tabela abaixo) | ~1,5–2,5 s cada | **1 uso** do complemento ao abrir a etapa, qualquer que seja a nota |
| 6 | **Fechar e entregar** | o pão fecha com animação (0,4 s); selo de nota; o Tool "HotDog" vai para a mão (ou hotbar cheia: `hands_full`, fica na tábua `Parked`); câmera volta | 0,5 s + 0,3 s | — |

Gestos por complemento (os 6 do `items.md`):

| Complemento | Gesto | Perfect | Good | Messy |
|---|---|---|---|---|
| Ketchup, Mustard (`AST-004/005`, garrafa com `Fill` que desce) | segurar e **traçar o zigue-zague** guia sobre a salsicha | cobertura ≥ 85% da guia e excesso ≤ 10% | ≥ 60% e ≤ 25% | abaixo disso |
| Cream Cheese | igual aos molhos, guia em linha ondulada mais curta | idem | idem | idem |
| Cheese | **arrastar a fatia** até o alvo sobre a salsicha | desvio ≤ 12% | ≤ 25% | acima |
| Bacon | **3 toques** nos anéis que fecham | ±120 ms | ±250 ms | acima |
| Potato Sticks | **segurar para polvilhar e soltar** quando a barra cai na faixa verde | ±8% | ±18% | acima |

Tabela de etapas de corte e posição:

| Etapa | Medida | Perfect | Good | Messy |
|---|---|---|---|---|
| Cortar | desvio lateral médio da linha, em % da largura do pão | ≤ 6% | ≤ 15% | > 15% |
| Posicionar | distância do centro ao alvo, em % do comprimento do pão | ≤ 10% | ≤ 22% | > 22% |

Ritmo-alvo (precisa caber no dia de ~4,6 min e no fluxo de 14 s):

| Situação | Tempo total no foco (K = 2) |
|---|---|
| Jogador hábil | **9–12 s** |
| Iniciante (1ª semana) | 15–18 s |
| Modo de prompts de hoje (referência; **substituído**, DEC-223) | 8–10 s |
| Teto de paciência de preparo (FEAT-011) | 75 + 5 × K s: o foco **não** pausa a barra |

Etapa não tem relógio próprio (a paciência do cliente é o único relógio, como hoje). Parar sem input 20 s sai do foco (`Parked`).

#### Nota (qualidade)

| Regra | Valor |
|---|---|
| Pontos por etapa | Perfect 100 · Good 70 · Messy 30 |
| Nota do prato | média das etapas: **Perfect** se ≥ 88 e nenhuma Messy · **Good** se ≥ 60 · **Messy** se < 60 |
| ~~Modo rápido~~ | ~~prato "Good neutro" (piso)~~: **não existe em V1** (DEC-223); a nota vale para todo hot dog |
| Efeito (proposta, `Q-219`) | **Perfect**: gorjeta $2 (igual ao Hawker, não soma) e janela de gorjeta +4 s · **Good**: como hoje · **Messy**: sem gorjeta; com humor dinâmico (DEC-187, `Q-164`), −1 faixa |
| O que **não** muda | preço base, complementos, Completo/Incompleto/Errado (DEC-072) |
| Piso de pagamento | Messy continua pago igual: errar o gesto não cria prato errado |
| Atributo | `Quality` (`Perfect`/`Good`/`Messy`) no Tool "HotDog"; some ao servir |
| UI | selo na tela ao fechar: "Perfect!", "Good", "Messy"; **sem vermelho** (Mustard brilhante / creme / tinta) |
| Teto de ganho | ≈ +14% do ticket médio no melhor caso; vigiar o ±12% de classes (DEC-069) |

#### Controles por plataforma

| Plataforma | Cortar / posicionar / molhos | Sair | Notas |
|---|---|---|---|
| Desktop (mouse) | segurar o botão esquerdo e arrastar; o cursor vira a faca/garrafa; raycast do ponteiro ao plano da tábua | Esc, Q ou pílula "Exit" | teclado também: Espaço = soltar item |
| Toque | arrastar com um dedo, fora da área do joystick; marca de alvo maior (≥ 44 px, `style-guide`); o dedo não cobre o alvo (cursor deslocado 28 px acima do dedo) | pílula "Exit" Mustard no canto superior direito | opção **Assist**: tolerância +30%, "hold to do" no lugar de arrastar |
| Gamepad | stick direito move o cursor (velocidade fixa), A segura/solta, B sai; D-pad = trocar ticket | B | magnetismo leve na linha guia |
| Acessibilidade | "Reduced motion" sem viagem de câmera nem tremor; **Assist e "hold to do" obrigatórios** (não há mais modo rápido de reserva, DEC-223; Provisório) | | Mobile e pouca habilidade nunca bloqueiam progressão: Assist garante a conclusão (`Q-223`) |

#### Câmera e travamento

| Regra | Valor (Provisório) |
|---|---|
| Câmera | `Scriptable`; ponto de foco `Focus_n` por tábua (âncora do level-designer), ~2,5 studs da bancada, pitch ~−55°, FOV 55 |
| Travessia | tween 0,35 s ease-out; saída 0,30 s; sem "reduced motion" |
| Movimento | travado: `WalkSpeed` e `JumpPower` 0 por atributo `Focused` replicado e checado no servidor |
| Personagem | os outros jogadores veem o colega parado na tábua com a pose de "trabalhando" (idle atual até o usuário animar, DEC-220) |
| Braços | em foco os braços reais ficam ocultos e as mãos são **props** (faca, garrafa) seguindo o cursor; ao sair, `SetArmsVisible(true)` (DEC-219). Se o art-director preferir braços em IK (AST-069), decide na ficha |
| Outros jogadores | seguem livres; colisão jogador-jogador desligada (DEC-175) |
| Sombras | `CastShadow` do corpo segue desligado em 1ª pessoa (pedido 28) |
| Saída forçada | cutscene/ligação; mudança para `Summary`; sanidade 0 (`Down`); sinal de anomalia e mudança de faixa de sanidade à noite; ladrão no raio (dia); ver a seção "Noite" |

#### Estações por nº de jogadores

| Jogadores conectados no início do turno | Estações focadas ativas | Tábua física (DEC-215, **superada para o preparo** por DEC-223) |
|---|---|---|
| 1 | 1 | só visual (`BoardSlots`/`Att_Bun*`) |
| 2 | 2 | idem |
| 3 | 3 | idem |
| 4 | 4 | idem |

- **Decidido (DEC-223, `Q-220` opção A):** estações = jogadores. Cada jogador usa **a estação que ativar**; estação ocupada mostra o nome de quem está nela e o prompt "Prepare" some para os outros. Reserva no servidor no toque.
- O carrinho **saiu da run** (DEC-224): só o trailer; ele precisa de **4 pontos de foco `Focus_n`** na bancada (level-designer valida o espaço lado a lado; colisão jogador-jogador desligada, DEC-175).

#### Co-op e fila

- **Ticket**: a lista de pedidos "Take Order" (balões) aparece no HUD do foco. Ao entrar, o servidor sugere o ticket **mais antigo sem dono**; o jogador troca com D-pad/toque. A "reserva" é só guia: a entrega segue as regras do FEAT-038 (igual → Completo; subconjunto → Incompleto; extra → Errado).
- **Papéis** com 4 jogadores: um em Take Order/Serve, dois nas tábuas, um em grelha/estoque/mesas; todos trocam por prompt.
- **Trilho de salsichas** compartilhado: quem pede a salsicha primeiro leva a mais antiga.
- **Relógio**: a paciência do cliente continua enquanto o jogador está no foco (DEC-085: relógio não pausa). Se zerar (`Slow`), o pedido some, um aviso aparece no HUD do foco e o prato fica na tábua (`Parked`) para servir a outro ticket compatível ou jogar fora.
- **Grelha**: no mundo (FEAT-006). O jogador pode **cortar o pão enquanto a salsicha cozinha**: a etapa 2 espera pela salsicha.
- **Dupla** (FEAT-038): ticket com 2 itens vira dois pratos seguidos na mesma tábua; a entrega junta de hoje vale.

#### Noite, sanidade e anomalias (tensão central do design)

A câmera focada **cega o ambiente**. É a oportunidade de tensão que o dono sentiu, mas também uma fuga possível dos verbos "não olhar" (FEAT-023) e do −5 de "ver" (FEAT-019, que mede o olhar do jogador).

| Regra (recomendação A de `Q-221`, Provisória) | Valor |
|---|---|
| Disponível | dia e noite; o tutorial do Day 1 não usa (§Tutorial) |
| Sinal de anomalia (`AnomalyCue`, visto por todos, DEC-204) | **saída forçada** em 0,4 s com um tremor curto da câmera; sem input por 0,5 s; reentrada travada até a anomalia resolver ou acabar; prato `Parked` |
| "Ver" −5 e "não olhar" | contam depois da saída; ficar no foco **nunca** vale como "não olhar" (a saída é imediata) |
| Mudança de faixa de sanidade | saída forçada (o retrato do rosto muda, DEC-167); reentrada livre |
| Escuro (FEAT-020) | a tábua do veículo fica em `LightZone` (LZ-2 no carrinho ligado); o −1/s segue valendo se a luz apagar (N3/N10) e o foco **não** pausa |
| Ladrão (dia, FEAT-013) | ícone no HUD do foco quando entra no raio 14; saída forçada ao entrar; a gaveta segue exposta enquanto o jogador está parado |
| Sanidade < 20 (opcional) | **alucinação só no client** no fundo da tábua (um rosto na janela, um som), não interativa, não conta como anomalia (DEC-038); raro e leve, sem gore (DEC-173, Mild DEC-172) |
| Café | beber é uma ação do mundo: sair do foco para beber |
| Anomalias que não dão sinal antes | o foco não muda a regra delas; o cone de "ver" mede a câmera de quem **voltou** ao mundo |

Opções de `Q-221`: (A) esta, (B) ~~só modo rápido à noite~~ (sem objeto em V1: não há modo rápido, DEC-223), (C) livre à noite sem saída forçada (risco proposital, abre a fuga).

#### Relação com o modo atual (prompts no mundo)

| Ponto | Regra (V1, DEC-223) |
|---|---|
| Convivência | **não há convivência**: o modo de prompts no mundo (FEAT-006) é **substituído**; a tábua tem um único prompt "Prepare"; mesmo Tool "HotDog" no fim |
| ~~Modo rápido~~ | ~~piso de acessibilidade~~: **removido**. FEAT-005 (aceite do mobile) emendado só no preparo; exceção em `Q-223` |
| Incentivo ao focado | Perfect paga mais gorjeta e janela maior (`Q-219`); Good = como hoje |
| Acessibilidade | Assist, "hold to do", reduced motion **obrigatórios** (Provisório); toda a run concluível só com um dedo |
| Day 1 | **ensina o modo focado** (único modo); tutorial reescrito pelo narrative-writer (`script.md` §3) |

#### Upgrades de estação (propostas; IDs `UPG-###` só quando virarem ficha em `upgrades.md`)

| Nome provisório | Efeito | Preço Provisório | Onde |
|---|---|---|---|
| Sharp Knife | corte e posição: faixas Perfect/Good ×1,25 | $70 | Gear Stand (FEAT-015 v2), mini de faca; mesma regra de cooldown de `Q-203` |
| Fine Nozzle | molhos e cremes: faixas ×1,25 | $70 | idem, mini de bico |
| Wide Board | imã de encaixe da salsicha e do queijo maior (+10% do raio) | $90 | idem |
| Grill (UPG-001 existente) | na fase 2 (`Q-222`): janela de "ponto" 6 → 8 → 10 s por nível | já pago | — |
| Teto | nenhum upgrade passa de ×1,25; ninguém "compra" o Perfect: o gesto continua necessário | — | — |
| Classes | passivas de DEC-186 **não** mudam; nova passiva só com DEC | — | — |

(Valiam "só no focado" na V2 descartada; em V1 valem para todo preparo.)

#### Interação com o tutorial

| Regra | Valor |
|---|---|
| Day 1 | **ensina o modo focado** (DEC-223; Provisório; antes: "sem modo focado"): Walt na linha, uma aba por vez (Order → Grill → Build → Serve), HUD progressivo; `script.md` §3 e `ui-text.md` a reescrever |
| Primeira ativação (Day 1) | chamada curta do Walt ("Take your time on the board, kid."), mão-fantasma no gesto 1, **pão de treino grátis** (não gasta estoque) na 1ª vez; a barra de paciência do pedido de treino fica parada |
| Dicas | `hint_focus_cut`, `hint_focus_place`, `hint_focus_sauce` (1× cada, FEAT-018 `hint_<passo>`) |
| Voz | sem a palavra "sausage" (TTS), `frank`; falas curtas |
| HUD progressivo | o ticket e os pontos de etapa entram com o foco (`Content/HudReveal`); sem vermelho |

#### Rede e carga técnica (para o architect validar; **Rascunho**, sem código)

| Item | Proposta |
|---|---|
| Autoridade | servidor decide: reserva da tábua, consumo de estoque, nota, criação do Tool "HotDog" com `Quality` |
| Cliente | roda o minijogo local (sem esperar a rede), câmera `Scriptable`, UI em Vide, input por plataforma |
| Packets Lync (`src/Libs/Net`) | `FocusEnter(board)` → `FocusStepBegin(board, step, item)` → `FocusStepEnd(board, step, ms, pts[≤32], cada ponto `Lync.int(0, 255)`)` → `FocusExit(board)`; set `FocusBoards` (replicate) com dono e etapa de cada tábua, para os colegas verem |
| Validação | tempo mínimo por etapa (Cortar 0,6 s, Posicionar 0,4 s, Molho 0,8 s); pontos monotônicos na guia do corte; faixas de valor; taxa 1 pacote por 0,3 s; ping alto não pune (tolerância de 250 ms nas janelas de timing) |
| Anti-abuso | etapa com tempo abaixo do mínimo ou trilha implausível = no máximo Good; 5 etapas suspeitas seguidas = nota fixa Good no resto do turno e log (sem modo rápido em V1) |
| Estado | `Parked` guarda o prato na tábua até o fim da fase; ingredientes já gastos ficam gastos |
| Persistência | nada persiste; snapshot de turno não guarda tábua (começa `Idle`) |
| Orçamento | 1 câmera, ~30 partes de prop por tábua, 4 tábuas; UI Vide com 1 árvore de foco; sem física nos itens (posição por script) |
| Dados | `Content.Focus` (tabela abaixo) e `Content.Upgrades` ganha efeitos de tolerância |

`Content.Focus` (Provisório): `Enabled` true · `UnlockDay` 1 (DEC-223; era 2) · `MaxBoards` 4 · `Travel` {In 0,35, Out 0,30} · `IdleExit` 20 · `MinStep` {Cut 0,6, Place 0,4, Sauce 0,8} · `Grades` {Perfect 100, Good 70, Messy 30; PerfectAt 88, GoodAt 60} · `Bands` (tabelas de Cortar, Posicionar e dos 6 complementos) · `PerfectTip` 2 · `PerfectTipWindow` +4 · `MessyTip` 0 · `ForcedExit` {Cue true, SanityBand true, Thief true} · `ReentryLockOnCue` true · `Assist` ×1,30 · `UpgradeCap` ×1,25 · `PointsMax` 32.

#### Riscos e métricas

| Risco | Mitigação / métrica (Provisória) |
|---|---|
| Fila: preparo lento demais | mediana no foco ≤ 12 s (K = 2, hábil); **sem modo rápido de reserva (DEC-223)**: se o `Slow` passar da meta de referência (modo de prompts, ~8–10 s) +3 p.p. na simulação, ajustam-se `Flow` (intervalo, paciência) e as faixas de tolerância, não se recria o modo rápido sem DEC |
| Tédio por repetição | gestos diferentes por complemento; Perfect só com atenção; upgrades de conforto; Assist sem culpa |
| Fuga das anomalias | saída forçada no sinal; reentrada travada; métrica: nº de "ver"/"não olhar" falhados com e sem foco, **sem diferença significativa** |
| Mobile | alvos ≥ 44 px, Assist, cursor deslocado; teste em aparelho; taxa de Perfect no toque ≥ 60% da do mouse |
| Ping alto | tolerância de 250 ms; validação por plausibilidade, não por exatidão |
| Co-op sem função | 4 jogadores = papéis (Take Order/Serve, tábuas, grelha/estoque/mesas) |
| Camera sickness | viagem curta, reduced motion, sem balanço |
| Exploração do Perfect | teto de ganho +14% do ticket; upgrades nunca zeram o gesto |
| Metas gerais | Perfect ≥ 25% (hábil) e ~10% (iniciante); (adoção do focado: sem objeto, é o único modo); saída no meio < 15%; custo de CPU do cliente no foco < 1,5 ms/quadro no celular alvo (celular-alvo adiado, DEC-090) |

#### Fora do MVP

Grelha focada com "virar/ponto" (`Q-222`), queimar, bebidas e sobremesas, segunda estação de montagem (batata frita, chili), decoração por estrelas, ranking, replays, minigame de descascar (não há batata no cardápio), skins de faca/garrafa pagas.

#### Critérios de aceite (proposta)

- Desde o Day 1 a tábua mostra um único prompt "Prepare"; **nenhum** prompt de preparo (pegar salsicha, cortar pão, complementos) existe no mundo; "Quick Slice" não existe.
- A tela de foco tem as abas Order, Grill, Build e Serve, ticket sempre visível, lixeira e Next; a grelha segue cozinhando com o jogador em outra aba.
- 1 a 4 estações ativas = jogadores conectados no início do turno (DEC-223).
- Entrar no foco trava o movimento do jogador (servidor recusa `WalkSpeed` ≠ 0) e os outros seguem livres.
- A câmera viaja em 0,35 ± 0,05 s e volta em 0,30 ± 0,05 s; com "reduced motion" é instantânea.
- Cada etapa só abre com estoque ≥ 1 do item; estoque cai exatamente 1 por etapa; sair no meio não devolve.
- Dois jogadores tocando a mesma tábua ao mesmo tempo: só um entra.
- O Tool "HotDog" final tem os complementos pedidos e atributo `Quality`; o preço pago é o mesmo do modo de prompts antigo (a menos que `Q-219` decida diferente); Completo/Incompleto/Errado seguem DEC-072.
- Etapa enviada em menos que o mínimo ou com trilha impossível nunca dá Perfect.
- Cortar com desvio ≤ 6% dá Perfect; > 15% dá Messy (±1 p.p. de tolerância de medição).
- Em 10 pratos com 3 etapas Perfect, a nota do prato é Perfect; uma única Messy impede Perfect.
- `AnomalyCue` ativo: a câmera sai em ≤ 0,5 s; reentrada recusada até acabar.
- O foco não pausa o relógio, a paciência do cliente nem o ladrão.
- Em um dispositivo de toque, todo o fluxo é concluível só com um dedo e o botão "Exit" (e com Assist, sem arrastar).
- Sem vermelho de alerta na UI do foco; textos em inglês.

#### Rascunho de tarefas (sugestão; **sem `TASK-###`**, só se o dono pedir)

| Dono | Bloco |
|---|---|
| game-designer | `Content.Focus`, gestos e faixas por complemento, upgrades (UPG), números de gorjeta (`Q-219`) |
| architect | packets Lync, set `FocusBoards`, validação e anti-abuso, orçamento de câmera/UI |
| backend-coder | `FocusService` (reserva da tábua, consumo, nota, Tool com `Quality`, `Parked`, saída forçada), integração com `CustomerService`, `Notices` |
| frontend-coder | `FocusController` (câmera Scriptable, travessia, input mouse/toque/gamepad), UI Vide (ticket, etapas, selo, "Exit"), props das mãos, `reduced motion` |
| level-designer | âncoras `Focus_n` e posições de 1–4 jogadores no carrinho e no trailer; conferência de espaço |
| art-director / modeler-3d | props: faca, garrafa com `Fill` (AST-004/005), bico, mão-fantasma; luz do foco; mini de upgrades |
| narrative-writer | falas do Walt, dicas `hint_focus_*`, textos "Perfect!/Good/Messy" |
| audio (usuário, DEC-220) | SFX de corte, aperto, encaixe, selo; lista em `audio/sound-list.md` |
| qa-tester | plano por plataforma, anomalia + foco, 4 jogadores, ping alto |

- Decididas: `Q-218` (substitui, V1) e `Q-220` (estações = jogadores) por **DEC-223**.
- Pendências: `Q-219` (nota × dinheiro), `Q-221` (noite), `Q-222` (grelha: "ponto"; a aba Grill já é V1), `Q-223` (exceções de UI e plataforma; **essencial**, sem modo rápido). Liga a `Q-164` (humor dinâmico).

---

### Modo anomalia — pedidos do dono 2026-10-14 (Provisório, sem DEC)

Registro e leitura em `open-questions.md` ("Pedidos do dono 2026-10-14", `Q-259` a `Q-268`). Resumo para as fichas:

- **Uma flag de modo**: `Content.Mode.DayOnly = false` = **modo anomalia** (padrão). Desligados, **não apagados** (voltam com `DayOnly = true`, o futuro "modo só de dia"): **FEAT-037** (mesas: tudo `Locked`, ninguém senta, sem compra/servir/limpar mesa), **FEAT-013** (ladrão nunca sorteado) e, em `upgrades.md`, UPG-003 (Wide Counter), UPG-004 (Drawer Lock), UPG-008 a UPG-011. A fila fica fixa em 2 (`Q-261`). Grelha dupla (UPG-001) segue.
- **FEAT-015**: o Gear Stand fica **fechado no começo da run** (Dia 1 até o fim do turno, `Content.Mart.FirstShiftClosed`); a 1ª ida ao Mart é só para o pão (lição do pacote).
- **FEAT-004 / tutorial**: no fim do 1º turno o relógio para às **18h**, Walt liga (`call_tutorial_upgrade`) e o tutorial leva ao Gear Stand para o 1º upgrade, **Storage** (UPG-002); sem dinheiro, o caixa sobe a $100 (`Q-262`).
- **FEAT-007 / potes**: sem cadeado; a cobertura que desbloqueia chega como **pote-presente fechado** ("Open"): abre com a tampa voando + confete e vem **cheio** (`Q-263`).
- **FEAT-039**: o **molho desenhado** fica no hot dog entregue (atributo `Sauce`, `Q-264`); o prato aberto não expira durante o tutorial (`Q-268`); cobertura-modelo (queijo) solta em qualquer ponto do pão entra (clique sem arrastar = colocar no ponto), com aviso quando não entra.

### FEAT-040 — Câmera de segurança noturna

- Status: **Rascunho (Provisório), implementado na TASK-285** · Pilares: OBSERVAR, SOBREVIVER · Origem: **pedido do dono, 2026-10-14** ("um sistema de câmera de segurança para assistir às anomalias"). Toca FEAT-019 (anomalias), FEAT-020 (luz), FEAT-022 (sanidade), UPG-005, **UPG-012**.
- Ideia: o trailer ganha um **monitor de segurança** (upgrade UPG-012, Gear Stand). Na noite, ao usar o monitor, a visão troca para **câmeras fixas** em volta do trailer (a rua, o Mart, a porta dos fundos); o jogador **vê de longe** sinais de anomalia antes de elas chegarem ao balcão. Sem combate: só observar e decidir (abrir/fechar, recusar, apagar a luz).
- Proposta inicial (números do game-designer, a validar):

| Nível | Preço | Câmeras | Efeito de noite | Efeito de dia |
|---|---|---|---|---|
| 0 | — | nenhuma | — | — |
| 1 | $120 | 1 (a rua em frente) | monitor no trailer; trocar de câmera com as setas; a imagem tem chiado | nenhum (o jogo é de noite; exceção consciente a DEC-006, como UPG-004) |
| 2 | $200 | 3 (rua, Mart, porta dos fundos) | idem + aviso discreto de "movimento" na câmera | nenhum |

- Regras propostas: usar o monitor **prende a câmera do jogador** (como o modo de preparo, FEAT-039): o balcão fica sem atenção enquanto assiste; a sanidade **não** cai mais rápido por assistir (para crianças); nada no monitor é exclusivo do monitor no nível 1 (só outro ângulo), o nível 2 pode mostrar um sinal a mais (ver `Q-267`).
- **Luz do trailer (UPG-005)**: o dono a achou interessante; fica **à venda** no modo anomalia. Ideia para a próxima rodada: a luz externa ilumina o que a câmera vê (a câmera "enxerga" mais no raio da luz). Ver `Q-266`.
- Assets prováveis: monitor CRT no trailer, 1–3 câmeras de parede (AST novos, art-director), interface de chiado (Theme, sem vermelho).
- Critérios de aceite (quando virar tarefa): entrar e sair do monitor em ≤ 0,4 s; trocar de câmera sem travar; nenhum prompt do mundo dispara enquanto assiste; o monitor some no dia.
- **Implementado (TASK-285, 2026-10-14, Provisório)**, fora do upgrade UPG-012 por pedido do dono: o monitor `CCTV` do trailer (prompt E `watch_cameras`) abre 2 câmeras fixas (`Workspace.SecurityCams.CAM1/CAM2`, vista = pivô do modelo); 1/2 trocam, N alterna **Normal** (grão leve + carimbo) e **Visão noturna** (tinta verde, grão, scanlines, vinheta, faixa rolando, iluminador IR local), Q sai. Entrar e trocar são corte seco com chiado de 0,35 s. Corpo congelado e prompts do mundo calados enquanto assiste. Gancho para anomalias que só aparecem (ou aparecem melhor) na visão noturna: atributos `SecurityView` / `SecurityCam` do LocalPlayer. O monitor ainda não some no dia (o trailer só existe à noite) e não há nível de upgrade. Números em `Content/Security.luau`.

### FEAT-041 — Entrega arrastando e indicador DELIVER

- Status: **Provisório (implementado 2026-10-14)** · Pilar: VENDER · Origem: **pedido do dono, 2026-10-14**. Toca FEAT-011 (Serve), FEAT-039 (prep), FEAT-032 (UI).
- O cliente espera na janela de serviço; o jogador **segura o hot dog pronto** e o **arrasta até o cliente**, soltando nele:
  - **no mundo**: com o hot dog na mão, apertar e soltar sobre o cliente com o pedido tomado (no alcance de `serve`) dispara o próprio prompt `serve` dele (`DeliveryController`); em primeira pessoa o ponteiro é o centro da tela;
  - **no modo de preparo 3D** (vista Toppings): arrastar o **prato** até o cliente = Done + Serve (o servidor julga o hot dog recém-feito).
- **Indicador**: cartão verde arredondado com listras diagonais e a palavra **DELIVER** (`Interface/Components/DeliverMark`, molas do HintMark, respeita movimento reduzido), sobre a cabeça do cliente **só quando dá para entregar**; acende ao arrastar por cima.
- O servidor decide tudo (pedido, alcance, fase, `CustomerService`). Gamepad e touch: o prompt `serve` e o botão Done continuam.

# Propostas pendentes (Qs do game-designer)

Cada linha é **Rascunho**: proposta + recomendação. Onde a recomendação muda regra decidida, está marcado "precisa do usuário". As fichas acima já usam a recomendação, marcada como proposta.

| Q | Opções consideradas | Recomendação | Precisa do usuário? |
|---|---|---|---|
| **Q-107** Reviver — o que sobra | prazo, quem paga Robux e limite por noite já decididos (DEC-115, DEC-116, DEC-129) | Tempos e paradas (tabela `Ambulance`), sanidade 50% ao voltar, espera durante ANM-008/ANM-010, uso do crédito do perfil (DEC-117): FEAT-034 | não |
| **Q-112 b, c, d** Membro atrasado | (b) até quando: só na janela · **a qualquer momento**; (c) cutscene: entra no ponto atual · **não vê a intro, spawna na esquina quando ela acaba** · repete para ele; (d) voto: **só quem está na cutscene**; fluxo: **a partir do turno seguinte** | Os em negrito (FEAT-001, FEAT-004, FEAT-009). (c) mudou para a sugestão do narrative-writer (`script.md` §1), que evita o atrasado "pular" para o meio de um trilho de câmera. (a) decidida em DEC-121 | não |
| **Q-120** Bancada — o que sobra | chance 15% e preço $200 × party decididos em DEC-129. Abertos: (a) nº de slots, (f) uso por colega, (h) limite por turno/run, (i) Give | 1 slot; uso pelo próprio caído **e** por colega de pé ("Blow Whistle", revive o caído **mais antigo**: sem seletor, um botão só, melhor no celular; `tech/architecture.md` §10 deve trocar o seletor por esta regra ou o usuário escolhe o seletor), vale na janela de 10 s só para o próprio; sem limite por run além da raridade; sem "Give". FEAT-035, FEAT-034, ITM-021 | não |
| **Q-122** Atropelamento | tempo no chão 2/3/5 s; NPCs atropelados ou não; ambulância atropela ou não; item sempre ou com chance; Hot Dog recupera ou perde; prompt e prazo do item no chão | 3 s; NPCs nunca (só atravessam na faixa com reserva, DEC-133); ambulância nunca; **só a Tool equipada** cai, sempre (DEC-103); Hot Dog e café perdidos, pacotes e apito recuperáveis; prompt "Take" hold 0,5 s; some em 60 s na rua; proteção 5 s. FEAT-033, FEAT-036 (o architect copia) | **respondida: DEC-197** (2–3 s no chão, ragdoll curto; 3 s cabe; resto Provisório; architect valida ragdoll e colisão) |
| **Q-077** Ligações e cutscenes | — | (a) só conectados votam, ceil(50%), espectador vota; (b) ligações **não** puláveis; (c) legenda avança sozinha, 2,5 s por linha, igual para todos; (d) versão curta na noite repetida = ligação nova, compatível com DEC-077. FEAT-004, FEAT-018 | **respondida: DEC-194** ((a) ≥ 50% dos conectados, desconectado não conta; (b)–(d) e espectador vota seguem Provisórios) |
| **Q-114** "Ver" −5 | — | Confirmado: **1× por anomalia, por jogador, por noite** (FEAT-019) | não |
| **Q-115** Noites 1–6 fáceis | ver `progression.md` §4.4 | métricas de playtest + alavancas de número | não (só se precisar de crítica antes da ANM-007) |
| **Q-064** Interruptor antes do Trailer Lights | — | trailer vem com lâmpada interna + interruptor; interior é `LightZone` só com o interruptor ligado (necessário para a ANM-003 custar escuro); Trailer Lights fixo na bancada desde a compra do trailer (DEC-106 fecha o risco da rotação). FEAT-020, UPG-005 | não |
| **Q-067** Fluxo com desconectados | início da run · conectados · ativos | **ativos no início do turno** (conectados e não espectadores). FEAT-009 | não |
| **Q-068** Tábua e hot dog pronto | — | tábuas compartilhadas (2 carrinho, 3 trailer), reservadas no toque; Hot Dog vira Tool; entrega por prompt "Serve". FEAT-006 | não |
| **Q-069** Sinal visto por um só | — | sinal visível a todos; erro e penalidade por jogador quando o escopo da `ANM-###` é "por jogador" | não |
| **Q-075** Nível passa ao trailer | — | sim, mesmo nível, peça visível nos dois veículos. FEAT-016 | não |
| **Q-083** Passantes e NPCs da noite | — | (a) sim, até 2 de dia; (b) à noite todo humanoide de servidor é cliente ou anomalia (médicos da ambulância são visuais) | não |
| **Q-086** Colisão jogador-jogador | só no Pad · em todo o mapa | **desligada em todo o mapa** (mais simples; 4 avatares R6 no trailer e no Mart) | **respondida: DEC-175** (desligada; alcance todo o mapa Provisório) |
| **Q-088** Ingrediente não liberado | escondido · "Out of stock" | "Out of stock" + "Day N" (cria expectativa). FEAT-008 | **respondida: DEC-180** ("Out of stock"; "Day N" segue Rascunho) |
| **Q-089** Ladrão até a gaveta | — | 4 s fixos; velocidade varia por ponto de espreita | não |
| **Q-090** Sanidade na rota do Mart | — | manter sem ilha de luz (~2–4 por perna); sem semáforo (DEC-130) e com a Juniper Sul sem carros à noite, a travessia de CW-1 à noite não tem espera; o level-designer mantém um poste aceso sobre CW-1 | **respondida: DEC-196** (sem poste no meio da rota; ~2–4 por perna; **cai o poste aceso sobre CW-1**; nenhum volume de luz na rota Pad ↔ Mart) |
| **Q-129** Travessia sem semáforo (DEC-130) | (A) carros nunca param para ninguém; NPC cruza só com brecha e o spawn é suspenso enquanto ele cruza · (B) **carros param só para NPC com reserva de faixa; nunca para jogador**; PARE nos braços da Juniper · (C) carros param para qualquer um na faixa, inclusive jogador | **(B)**. Prós: mantém o "na sorte" do usuário para o jogador; NPC nunca atropelado sem simular fila; a parada para o pedestre é um padrão visível (OBSERVAR) e atravessar junto com ele é uma tática emergente. Contras: o carro "para para o NPC e não para mim" pode parecer injusto (tom pastelão absorve); reserva de faixa é lógica nova no servidor (pequena: 1 flag por faixa). (A): mais puro, mas NPC pode esperar muito e exige suspender spawn. (C): contraria "na sorte" (precisaria do usuário). Faixas continuam pintadas; spawn ≥ 55 studs da faixa, intervalo ≥ 3 s. FEAT-033 | **respondida: DEC-133 (B)** |
| **Q-091** Opal e teto | — | (a) Opal fora do teto de 12 (estática); (b) a âncora AN-08 sai da Opal (DEC-079) | não |
| **Q-092** Ponto seguro sem anomalia | — | sim, regra de design: nenhuma `ANM-###` usa a área sob o letreiro nem o interior do Mart como palco | **respondida: DEC-177 — "Não"**, contra esta proposta: o SS **pode** ter anomalia; detalhes `Q-161` |
| **Q-094** Esconder por jogador | — | sim; 4 pontos atrás do balcão do trailer, um por jogador | **respondida: DEC-176**; esconder saiu do jogo (**DEC-221**) |
| **Q-103** ANM-008 com trânsito | 1 carro raro a noite toda · **≤ 1 carro até 9 PM, 0 depois** (`MAP-01.md`) · 0–2 (architect) | **≤ 1 carro na Calma (8–9 PM), 0 depois das 9 PM**: a ANM-008 é o único carro em movimento, o único que estaciona e o único com farol alto. Alinha FEAT-033, NPC-022, `MAP-01.md` e `world.md` ("quase nenhum"); `tech/` copia a tabela `Traffic`. Co-dono: narrative-writer (sinal aprovado não muda) | **respondida: DEC-198** (trânsito rareia à noite; estes números Provisórios, confirmar "0 depois das 9 PM" dentro de "rareia") |
| **Q-065** Consequências de sabor | — | entram todas como **só visual/áudio**, exceto: ANM-003 "relógio congela" vira **congelamento só no client** (HUD e relógio do Bellmoor Savings param 30 s e saltam; o relógio do servidor não para, DEC-048). +$1 da ANM-005 entra (cabe na tabela) | **respondida: DEC-195**, supera esta linha: só efeitos sem sistema novo; **cortados** N3 relógio congelado (nem só no client) e N5 +$1; game-designer classifica N5 chuva no trailer, N10 pedidos esfriam e "Thank you, dear." pelo critério |
| **Q-056** Limite da hotbar | — | 4 Tools; Rescue Whistle ocupa 1. FEAT-005 | **respondida: DEC-174** (4 Tools) |

Decididas nas rodadas 13–15 (saíram das pendentes; as fichas acima já citam a DEC):

| Q | Decisão |
|---|---|
| Q-121 espectadores na noite repetida | **DEC-111, DEC-113**: todos voltam, inclusive espectadores de noites anteriores |
| Q-125 chance por run x por noite | **DEC-112**: 1 por run inteira |
| Q-107 prazo / quem paga / limite | **DEC-115** (até 6:00 AM), **DEC-116** (Robux só para si), **DEC-129** (2 por noite) |
| Q-112 a tamanho da party para preços | **DEC-121**: roster que entrou até o fim do Day 1 |
| Q-106 b onde se acorda | **DEC-122**: em pé ao lado do trailer |
| Q-120 e (em parte) chance e preço | **DEC-129**: 15%/turno após o trailer; $200 × party |
| Q-044 duração da noite | **DEC-127**: 20 → 30 min |
| Q-022 / Q-025 / Q-028 | **DEC-128**: fora do MVP |
| Q-124 cafeteira | **DEC-125**: fixa no trailer |
