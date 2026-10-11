Status: Rascunho

# Lista de áudio (SFX / MUS / AMB)

Autor: game-designer, 2026-10-10. Base Provisória (DEC-193) até aprovação do usuário.
Uso: o usuário separa músicas e sons que já tem baixados e marca, em cada linha, qual arquivo atende. Esta lista não cria mecânica:
cada linha aponta para uma regra que já existe (FEAT, DEC, `story/`, `MAP-01.md`).

Autoridade: a **direção de áudio** está no `art/style-guide.md` §11 (**Aprovado**, DEC-126; Walker por DEC-123). Esta lista detalha o que o §11 pede;
se discordar dele, vale o §11. Fontes lidas: `vision.md`, `design/*.md`, `story/anomalies.md`, `script.md`, `world.md`, `ending.md`, `ui-text.md`,
`levels/MAP-01.md` §12.5, `art/style-guide.md`, `decisions.md` (até DEC-215), `tasks/board.md` (ondas).

**Prefixos novos** `SFX-###`, `MUS-###`, `AMB-###`: ainda não estão na tabela de IDs do `CLAUDE.md`. Pedido ao secretário para registrar
(dono: este arquivo). Regras de sempre: ID estável, nunca reaproveitado.

---

## 0. Regras técnicas do Roblox (para quem vai separar os arquivos)

Conferido na documentação oficial do Roblox (Creator Hub, página "Audio assets") em 2026-10-10.

| Regra | Valor atual |
|---|---|
| Como sobe | importar como **Audio asset** (Studio: Asset Manager / "Import"; ou Creator Hub → Creations → Audio). Subir **pelo grupo dono do jogo** (se o jogo for de grupo), senão o som fica privado da conta e não toca no jogo sem liberar permissão |
| Formatos aceitos | `.mp3`, `.ogg`, `.wav`, `.flac`, uma faixa só. **Recomendado: `.ogg` ou `.mp3`** (arquivo menor; o Roblox recodifica de qualquer jeito) |
| Duração máxima | **7 minutos** por arquivo |
| Tamanho máximo | **menos de 20 MB** por arquivo |
| Taxa de amostragem | **≤ 48 kHz** (use 44,1 kHz) |
| Canais | mono ou estéreo (aceita até 5.1). **SFX posicional no mundo: mono.** Música e ambiente de tela: estéreo |
| Limite de upload | **2.000 áudios grátis a cada 30 dias** com conta verificada por ID; **100** sem verificação. Não há custo em Robux para importar |
| Moderação | todo áudio passa por moderação e **checagem de direitos autorais**; música comercial conhecida é recusada. Arquivo que falha na recodificação não sobe |
| Privacidade | áudio novo é **privado**: só o dono usa. Liberar para a experiência (ou subir pelo grupo dono, acima) |

Licença (regra do `CLAUDE.md`, igual à dos modelos):

| Pode | Não pode |
|---|---|
| CC0; CC-BY (com crédito nos créditos do jogo); comprado com licença que permita uso comercial em jogo; feito pelo próprio usuário; gerado por ferramenta cujos termos dão uso comercial ao usuário; biblioteca de áudio licenciada do próprio Roblox (Creator Store), **só dentro do Roblox** | CC-BY-NC (não comercial); CC-BY-ND se o arquivo for editado (corte, pitch, loop); "free for personal use"; áudio tirado de vídeo, jogo, filme, desenho ou música de artista; imitação de jingle, vinheta ou toque famoso de marca ou jogo |

- Registrar **cada arquivo de terceiros** em `docs/art/credits.md` (nova seção "Áudio": ID, arquivo, autor, URL, licença, crédito obrigatório?) **antes** de subir.
  Sites de efeitos sonoros misturam CC0, CC-BY e CC-BY-NC na mesma busca: conferir a licença **arquivo por arquivo**.
- Áudio da biblioteca do Roblox vai na tabela "Recursos da plataforma" de `credits.md`, com o ID do asset.

Preparação do arquivo (recomendação; o Roblox não normaliza volume sozinho):

| Tipo | Alvo de volume | Outras regras |
|---|---|---|
| Música (MUS) | **−18 LUFS** integrado | estéreo; loop cortado no cruzamento de zero, sem fade no começo nem no fim do loop |
| Ambiente (AMB) | **−24 LUFS** integrado | loop sem emenda audível; nada de evento marcante (buzina, grito) dentro do loop |
| SFX de jogo | pico **−3 dBFS** | mono se toca no mundo; **sem silêncio no começo** (atraso no celular); cauda curta |
| SFX de UI | pico **−6 dBFS** | mono; curtíssimo |
| Todos | pico real **≤ −1 dBTP** | o ajuste fino fica no jogo, por grupo de som (Música, Ambiente, SFX, UI, Telefone) |

Celular primeiro (DEC-014, DEC-171): alto-falante de celular não toca grave. **Todo som que é sinal de jogo** (telefone, zumbido do Walker,
passo do Walker, batidas da N9, cortina da N6, tique-taque do banco) precisa ter energia entre **300 Hz e 4 kHz**, não só grave.

Arquivos no repositório (proposta): `Assets/audio/<grupo>/<ID>_<nome>.ogg` (grupos: `music`, `ambience`, `sfx`). Ex.: `Assets/audio/sfx/SFX-022_SausageReady.ogg`.

---

## 1. Se for separar só 20 agora, separe estes

Cobrem o dia jogável da onda 1 e o básico da noite da onda 2. O resto pode esperar.

| # | ID | O quê |
|---|---|---|
| 1 | MUS-002 | tema do dia (loop) |
| 2 | MUS-003 | tema da noite (mesma melodia, lenta, com notas faltando) |
| 3 | AMB-001 | rua de dia |
| 4 | AMB-002 | rua de noite |
| 5 | SFX-021 | chiado da grelha (loop) |
| 6 | SFX-022 | salsicha pronta (sino curto) |
| 7 | SFX-024 | cortar o pão na tábua |
| 8 | SFX-026 | molho saindo da bisnaga |
| 9 | SFX-027 | complemento sólido (genérico) |
| 10 | SFX-043 | moedas caindo na gaveta |
| 11 | SFX-045 | cliente feliz |
| 12 | SFX-046 | cliente reclamando (serve também para errado e desistiu até chegar o resto) |
| 13 | SFX-061 | comprar pacote no Mart |
| 14 | SFX-062 | Restock na estação |
| 15 | SFX-065 | upgrade instalado no veículo |
| 16 | SFX-080 | toque do telefone fixo (exclusivo) |
| 17 | SFX-001 | clique de UI |
| 18 | SFX-005 | erro / negado |
| 19 | SFX-006 | notificação |
| 20 | SFX-073 | carimbo da nota do turno (usar para A–D até chegarem as 4 versões) |

Dois desses podem vir prontos do projeto AnimalPlane (style guide §11, `Q-045`): SFX-022 (`Bell`) e SFX-001 (`ClickHover`/`Pop`); de lá vêm também
SFX-008 (`ChargeUp`) e SFX-009 (`Pop`), fora da lista. Se o AnimalPlane for exportado, troque as duas vagas por SFX-041 e SFX-044.

---

## 2. Prioridades e convenções

| Prioridade | Quer dizer | Ondas (`tasks/board.md`) |
|---|---|---|
| **P1** | precisa para jogar a onda 1 (dia, carrinho, Mart, upgrades) ou a onda 2 (noite básica, sanidade, café, trailer, ligações, ladrão, lobby, gemas) | 1, 2 |
| **P2** | completa a experiência: anomalias, trânsito, atropelamento, ambulância, cutscenes, final, alucinações | 3, 4 |
| **P3** | polimento | qualquer |

- **Duração/loop:** "loop N s" = arquivo que repete sem emenda; valores são alvo, não limite.
- **Variações:** quantas versões diferentes do mesmo som para não repetir. Se só houver 1, o jogo varia o pitch (±5%) como tapa-buraco.
- **3D / tela:** "no mundo" = posicional (sai do objeto); "tela" = 2D, igual para quem ouve.

### 2.1 Sons reservados (nunca reaproveitar em outro lugar)

Padrão aprendido é o que as anomalias quebram (DEC-010). Estes sons têm dono único:

| ID | Som | Por quê |
|---|---|---|
| SFX-080 | toque do telefone fixo | style guide §11: próprio, nunca usado em outro lugar; a alucinação de telefone reaproveita **o mesmo** de propósito |
| SFX-148 | zumbido de início do Walker | DEC-123: só existe no Walker real; a alucinação do poste pisca **sem** ele; diferente do zumbido comum dos postes (AMB-003) |
| SFX-183 | sirene da ambulância | sempre igual (FEAT-034: "padrão fixo"); nunca susto |
| SFX-151 | motor do long car | o único carro que não soa como brinquedo (`world.md` §3.2) |
| AMB-004 | tique-taque do banco | o sumiço dele é o sinal da ANM-003 |

---

## 3. Música (MUS)

> **Decisão do usuário (2026-10-10) — vale sobre a tabela abaixo onde ela discordar.**
> 1. **Sem música de créditos** (MUS-007 sai; `cs_credits` segue com a música do final da fase Finale e a tela de fim de run fica sem música).
> 2. **Uma música no início de cada turno, uma vez só (sem loop).** Ao entrar na Preparação (`Prep`, 7 AM / 7 PM) o client sorteia uma faixa:
>    dia = "Sunny Town" (`music_day_sunny`, rbxassetid://88103069634103) ou "Small Town" (`music_day_small`, rbxassetid://104601257905379);
>    noite = "Night Town" (`music_night_town`, rbxassetid://73501320034226) ou "Night Fall" (`music_night_fall`, rbxassetid://135232738690923).
>    Não repete a mesma faixa do último turno do mesmo tipo. Quem entra no meio do turno (mais de `ShiftMusicFresh` = 5 s depois do início da fase,
>    Provisório) não ouve. Noite repetida (retry) conta como turno novo.
> 3. **O resto do turno é só ambiente:** rua de dia `amb_day_street` = "CityAmbient" (rbxassetid://108990827199430), rua de noite
>    `amb_night_street` = "NightCrickets" (rbxassetid://98652860867664); dentro do Mart (volume LZ-4) `amb_mart_hum` = "SuperMarket Ambient"
>    (rbxassetid://121312424334285) no lugar da rua.
> 4. **Loop com crossfade (pedido explícito):** ambiente nunca usa `Looped` puro. Duas cópias do mesmo som se alternam: a faixa começa baixa e sobe;
>    `Crossfade` s antes do fim (campo por som em `Content.Sounds`, padrão 4 s, limitado a 1/4 da duração) ela começa a descer e, no mesmo instante,
>    a outra cópia começa do início subindo. A troca entre ambientes (dia → noite, rua → Mart) é o mesmo crossfade.
> 5. Mantidas: `music_lobby` ("Lobby", rbxassetid://133495425923316, loop no lobby) e `music_finale` ("Melancolic City", rbxassetid://86360851369933)
>    no final. Ducking na ligação do chefe continua (vale também para a música do turno).
>
> Implementação: `src/Shared/Content/Sounds.luau` (`Rules.ShiftMusic`, `ShiftMusicPhase`, `ShiftMusicFresh`, `Ambient`, `AmbientZones`, `AmbientOff`),
> `src/Audio/client/AudioController/` (`init.luau`, `Cues.luau`, `Bed.luau`).

Direção (style guide §11): dia com ukulele/xilofone leves, loop curto e alegre; noite = **a mesma melodia, mais lenta e com notas faltando**.
Um tema só, várias roupas. Música **nunca reage ao aparecimento de anomalia** (seria um sinal apontando o alvo, style guide §4.4).

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| MUS-001 | Lobby | lobby: plataformas de party, tela "Crew" (DEC-179, DEC-186) | loop 60–90 s | arranjo do tema do dia mais "sala de espera": ukulele, assobio, andamento médio, sem percussão forte | P1 (onda 2) | 1 |
| MUS-002 | Tema do dia | turno de dia, da Preparação (7 AM) até o Fechamento (6 PM), carrinho e trailer; modo dia infinito | loop 90–120 s | ukulele + xilofone + percussão de brinquedo, alegre, sem pressa; melodia simples e fácil de lembrar (é a base da noite) | P1 | 2: completa (8 AM–6 PM) + versão leve só ukulele para a Preparação (7–8 AM) |
| MUS-003 | Tema da noite | turno de noite, 8 PM até 5:45 AM; sai em silêncio no Hush roteirizado da Night 10 | loop 120–180 s | a melodia do MUS-002 bem mais lenta, com notas faltando; caixinha de música ou piano abafado, muito espaço entre as notas; volume baixo | P1 (onda 2) | 1 |
| MUS-004 | Camada de tensão | por cima do MUS-003, mesma tonalidade e mesmo tempo, entra por **número da noite** (proposta: Nights 7–10) e no "clima de terror de anomalia" do pack Night (DEC-181; gatilhos em `Q-159`) | loop sincronizado com MUS-003 | drone grave + cordas longas, sem batida; entra em fade de 3–5 s, nunca como pancada | P2 | 1 |
| MUS-005 | Abertura | cutscene `cs_intro` (FEAT-004, `script.md` §1), 35–45 s; para quando o telefone do carrinho toca | 40–45 s, sem loop | tema do dia com assobio, manhã de cidade pequena, totalmente inocente (DEC-008) | P2 (onda 4) | 1 |
| MUS-006 | Amanhecer (final) | 6:00 AM da Night 10 vencida → `cs_finale` com Walt (FEAT-027, `ending.md`) | ≤ 60 s | tema do dia lento, quente, com cordas e piano; as notas que faltavam na noite **voltam** e a frase resolve | P2 (onda 4) | 1 |
| MUS-007 | Créditos | `cs_credits` + pós-créditos (panfleto "NIGHT SHIFT — NOW HIRING") | ≤ 75 s | tema do dia completo, despedida; últimos ~10 s voltam à versão da noite com uma nota faltando (gancho do pós-créditos) | P2 (onda 4) | 1 |
| MUS-008 | Fim de run sem final | tela "Shift's Over" (2ª noite perdida, DEC-110/112) | 6–10 s | frase curta do tema da noite, triste mas gentil; sem drama | P2 | 1 |

Silêncios obrigatórios: música abaixa **−6 dB** durante ligação do chefe; corta para silêncio no Hush (ANM-010) e fica sem música das 5:45 às 6:00 da Night 10;
na tela de quem desmaiou, a música abafa (filtro, não arquivo novo).

---

## 4. Ambiente (AMB)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| AMB-001 | Rua de dia | dia, em todo o mapa externo (tela) | loop 60 s | cidade pequena tranquila: pombos, passarinhos, vozes longe sem palavra, trânsito **distante** (os carros de verdade têm som próprio, SFX-110) | P1 | 1 |
| AMB-002 | Rua de noite | noite, mapa externo (tela) | loop 60 s | quase silêncio: vento leve, cidade bem longe; os sons da cidade somem aos poucos durante a noite (`world.md` §5): o jogo baixa este loop hora a hora | P1 (onda 2) | 1 |
| AMB-003 | Zumbido de poste | cada poste aceso perto do jogador, noite (no mundo) | loop 5–10 s | zumbido elétrico constante, médio-agudo, suave. **Não pode** lembrar o SFX-148 (o do Walker sobe e para seco; este é estável) | P2 | 1 |
| AMB-004 | Tique-taque do banco | relógio do Bellmoor Savings, dia e noite, audível no Pad (~73 studs, MAP-01 C-01) (no mundo) | loop 2 s (1 tique por segundo) | mecânico, madeira e metal, regular. O **silêncio** dele é o sinal da ANM-003 | P2 (obrigatório antes da onda 3) | 1 |
| AMB-005 | Interior do Mart | dentro do Ninth Street Mart (tela) | loop 30–60 s | zumbido de freezer, lâmpada fluorescente, sem música de loja | P2 | 1 |
| AMB-006 | Interior do trailer | dentro do trailer, noite (tela) | loop 30–60 s | zumbido baixo de equipamento, metal rangendo de leve; a grelha (SFX-021) soma por cima | P2 | 1 |
| AMB-007 | Sanidade média | à noite, sanidade **40–59** (faixa média, DEC-167), só no client do jogador | loop 30–60 s | zumbido no ouvido muito leve; o resto do ambiente perde agudos | P2 | 1 |
| AMB-008 | Sanidade baixa | à noite, sanidade **< 40** (faixa baixa, DEC-167), só no client | loop 30–60 s | drone grave com movimento lento, "respiração" do ambiente; nada de grito, nada de pico | P2 | 1 |
| AMB-009 | Hush | ANM-010: do 1º poste apagar até os postes voltarem; a cidade some (tela) | loop 20 s | vento baixo arrastado, névoa (ar), quase nada; nenhum ruído de cidade | P2 | 1 |
| AMB-010 | Amanhecer | 6:00 AM: noite vencida, noite perdida (acordar ao lado do trailer, DEC-122) e final (tela) | loop 20 s | pássaros da manhã, cidade voltando devagar | P2 | 1 |
| AMB-011 | Lavanderia Suds & Socks | dia, perto da vitrine (no mundo) | loop 10 s | máquinas girando, abafadas atrás do vidro | P3 | 1 |
| AMB-012 | Mariposas no poste | noite, postes perto (no mundo) | loop 3 s | bater de asinhas bem baixo | P3 | 1 |
| AMB-013 | Lobby | lobby (tela), por baixo do MUS-001 | loop 30 s | burburinho alegre e baixo | P3 | 1 |

Sanidade alta (≥ 60): **sem camada** (ambiente normal da noite). As três faixas são as visuais da DEC-167; as alucinações usam as faixas < 60 / < 40 / < 20 (§5.12).

**Chuva:** não existe clima de chuva no MVP (evento "Rain" fora, DEC-128). A única água é a da ANM-005 (SFX-143 e, se entrar, SFX-144).

---

## 5. Efeitos sonoros (SFX)

### 5.1 UI

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-001 | Clique | botão de tela: lobby, "Crew", "Rejoin", spectate, reviver, "Back to Lobby" | 0,05–0,1 s | clique plástico, redondo, curto | P1 | 3 |
| SFX-002 | Hover (PC) | mouse passa sobre botão | 0,05 s | "tic" agudo bem baixo (AnimalPlane `ClickHover`) | P3 | 1 |
| SFX-003 | Abrir painel | tela de resumo, painel de spectate, tela "Crew" | 0,2–0,3 s | "whoop" macio subindo | P1 | 1 |
| SFX-004 | Fechar painel | painel some | 0,2 s | o mesmo descendo | P1 | 1 |
| SFX-005 | Erro / negado | sem saldo, "Hands full", ação bloqueada | 0,2–0,3 s | "bonk" de borracha + duas notas descendo; nunca campainha agressiva | P1 | 2 |
| SFX-006 | Notificação | cartão no canto superior direito (FEAT-032, `ui-text.md` §6) | 0,3–0,5 s | sininho duplo suave | P1 | 2: normal / importante (trailer à venda, item raro) |
| SFX-007 | Voto "Skip" | hold de 1 s concluído na cutscene (DEC-078, DEC-194) | 0,2 s | pop baixo | P2 (onda 4) | 1 |
| SFX-008 | Prompt carregando | hold de 0,5–2 s em qualquer prompt (FEAT-005) | acompanha o hold | tom subindo junto com a barra (AnimalPlane `ChargeUp`); o jogo ajusta a velocidade pela duração | P1 | 1 |
| SFX-009 | Prompt concluído | toque ou fim do hold | 0,1 s | pop (AnimalPlane `Pop`) | P1 | 3 |
| SFX-010 | Item na mão | Tool nova entra na hotbar, equipar, "Give" do café | 0,15 s | "fwip" de tecido | P2 | 2 |

### 5.2 Item no chão (FEAT-036)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-011 | Item cai | pacote ou apito cai (atropelamento, espectador) | 0,3 s | baque macio + 1 quique | P2 (onda 3) | 2 |
| SFX-012 | Hot dog cai | Hot Dog derrubado (perdido) | 0,3 s | "splat" cômico, sem nojo | P2 | 1 |
| SFX-013 | Café derrama | Coffee derrubado | 0,4 s | líquido curto no chão | P2 | 1 |
| SFX-014 | Pegar do chão | prompt "Take" | 0,15 s | pode ser o SFX-010 | P3 | 1 |

### 5.3 Cozinha (FEAT-006, FEAT-021)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-020 | Salsicha na grelha | "Grill": salsicha sai da caixa e cai no rolo | 0,3 s | plop + chiado começando | P1 | 2 |
| SFX-021 | Chiado da grelha | loop enquanto há salsicha na grelha (no mundo; 1 emissor por grelha, volume pelo nº de vagas ocupadas) | loop 3–5 s | chiado "fofo", médio, nada agressivo | P1 | 1 |
| SFX-022 | Salsicha pronta | barra termina (ReadyVFX) | 0,6 s | sino curto + brilho (AnimalPlane `Bell`) | P1 | 1 (+ pitch) |
| SFX-023 | Collect | salsicha vai para o trilho de descanso | 0,2 s | rolinho + pop | P1 | 2 |
| SFX-024 | Cortar pão | "Slice Bun": corte automático de 1,5 s na tábua | 1,5 s | 2–3 cortes de faca em madeira, ritmados | P1 | 2 |
| SFX-025 | Montar hot dog | "Add Sausage": salsicha entra no pão, vira Tool | 0,3 s | encaixe macio "squish-pop" | P1 | 2 |
| SFX-026 | Molho | "Add Ketchup" / "Add Mustard" (hold 1 s) | 0,6–1 s | bisnaga apertada, "splurt" cômico | P1 | 3 (mesmo som nos dois molhos, pitch diferente) |
| SFX-027 | Complemento sólido | qualquer "Add" de sólido até chegarem os específicos | 0,5 s | algo leve caindo no pão | P1 | 3 |
| SFX-028 | Queijo | "Add Cheese" | 0,4 s | fatia caindo, "flap" | P2 | 2 |
| SFX-029 | Bacon | "Add Bacon" | 0,4 s | crocante leve | P2 | 2 |
| SFX-030 | Potato Sticks | "Add Potato Sticks" | 0,5 s | chuvinha crocante | P2 | 2 |
| SFX-031 | Cream Cheese | "Add Cream Cheese" | 0,5 s | espátula cremosa | P2 | 2 |
| SFX-032 | Lixeira | "Throw Away" (lixeira do veículo e de rua, DEC-200) | 0,5 s | tampa basculante + item caindo dentro | P1 | 2 |
| SFX-033 | Cafeteira | "Brew Coffee": preparo de 6 s (3 s Barista) | loop 2 s + fim | gorgolejo de cafeteira; termina com sino suave (style guide §10) | P1 (onda 2) | 1 |
| SFX-034 | Beber café | ativar o Tool Coffee (animação 1,5 s, +25) | 1,5 s | gole + vapor; sem voz | P1 (onda 2) | 2 |

### 5.4 Clientes e caixa (FEAT-009 a FEAT-012)

Clientes são animais (DEC-149) e não falam em voz: as falas são balão (`ui-text.md` §8). Som de cliente = "blip" vocal fofo sem palavra.

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-040 | Cliente chega | cliente ocupa vaga do balcão | 0,3 s | blip vocal fofo | P2 | 3 (agudo / médio / grave, por porte da espécie) |
| SFX-041 | Take Order | toque no cliente, balão aparece | 0,4 s | lápis rabiscando bloquinho | P1 | 2 |
| SFX-042 | Serve | entrega do Hot Dog | 0,2 s | "swish" | P1 | 2 |
| SFX-043 | Pagamento | moedas indo para a gaveta + "+$" (style guide §10) | 0,5 s | moedinhas caindo numa caixa | P1 | 3 |
| SFX-044 | Gorjeta | +$1 na janela de gorjeta | 0,4 s | moeda extra com brilho agudo | P1 | 2 |
| SFX-045 | Cliente feliz | entrega completa (balão estrela) | 0,4 s | blip alegre subindo | P1 | 3 |
| SFX-046 | Reclamação | entrega incompleta (balão nuvem) | 0,4 s | murmúrio descendo, "hmph" | P1 | 3 |
| SFX-047 | Pedido errado | complemento não pedido: $0, Hot Dog volta | 0,4 s | duas notas descendo + blip confuso | P1 | 2 |
| SFX-048 | Desistiu | paciência zerou, vai embora (balão vapor) | 0,5 s | bufada cômica | P1 | 2 |
| SFX-049 | Recusar | "Refuse" (dia e noite, inclusive ANM-001/004) | 0,3 s | "whoosh" suave de dispensa | P1 | 1 |
| SFX-050 | Gaveta | depósito no resumo; roubo | 0,4 s | gaveta de caixa abrindo/fechando | P2 | 2 |

Humor dinâmico (DEC-187) ainda sem desenho (`Q-164`): se ganhar estados audíveis, entram aqui como linhas novas.

### 5.5 Mart, estoque, upgrades e trailer (FEAT-007, FEAT-008, FEAT-015, FEAT-016, FEAT-035)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-060 | Sininho da porta | entrar/sair do Mart (MAP-01 §12.5); porta do Mart no final | 0,8 s | sino de porta pequeno, metálico | P2 | 1 |
| SFX-061 | Comprar pacote | prateleira, hold 0,5 s | 0,4 s | bipe de caixa + saco de papel | P1 | 2 |
| SFX-062 | Restock | pacote descarregado na estação (hold 1 s) | 0,6–1 s | caixa esvaziando + "poof" de poeira | P1 | 2 |
| SFX-063 | Pacote vazio some | sobra 0 no pacote | 0,2 s | pop pequeno | P3 | 1 |
| SFX-064 | Comprar upgrade | bancada "GEAR WALL", hold 1,5 s; também compra do Rescue Whistle | 0,6 s | "ka-ching" de caixa registradora de desenho (original) | P1 | 1 |
| SFX-065 | Upgrade instalado | peça nova aparece no veículo, audível no Pad (FEAT-015) | 0,8 s | pop de escala + confete + "clank" de ferramenta | P1 | 2 |
| SFX-066 | Item raro na vitrine | S1 acende com o Rescue Whistle (FEAT-035) | 0,8 s | brilho mágico curto | P2 (onda 4) | 1 |
| SFX-067 | Ingrediente liberado | pacote grátis aparece na estação nova (DEC-071) | 0,6 s | "poof" + sininho | P2 | 1 |
| SFX-068 | Trailer comprado | hold 2 s concluído no trailer (UPG-006) | 1,5–2 s | jingle curto de conquista (3–4 notas do tema do dia) | P1 (onda 2) | 1 |
| SFX-069 | Troca de veículo | fade do fim do turno da compra | 1 s | "whoosh" + "clank" | P2 | 1 |

### 5.6 Turno, resumo, notas, gemas (FEAT-003, FEAT-014, FEAT-029)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-070 | Placa OPEN | "Open Shop" ou 8:00 | 0,5 s | placa de madeira virando + sininho | P1 | 1 |
| SFX-071 | Placa CLOSED | 6:00, Fechamento | 0,6 s | placa virando + duas notas descendo | P1 | 1 |
| SFX-072 | Contagem | linhas do resumo somando | loop 0,5 s | "tic-tic" rápido de contador | P2 | 1 |
| SFX-073 | Nota A | letra aparece | 1–1,5 s | carimbo + fanfarra curta de 3 notas subindo | P1 | 1 |
| SFX-074 | Nota B | letra aparece | 1 s | carimbo + 2 notas positivas | P1 | 1 |
| SFX-075 | Nota C | letra aparece | 1 s | carimbo + nota neutra | P1 | 1 |
| SFX-076 | Nota D | letra aparece | 1 s | carimbo + "aww" instrumental gentil (sem vergonha, sem vaia) | P1 | 1 |
| SFX-077 | Depósito | gaveta + bônus vão para o dinheiro da party | 0,8 s | cascata de moedas | P2 | 1 |
| SFX-078 | Gemas | gema creditada (DEC-104) | 0,6 s | cristal tilintando | P1 (onda 2) | 2: normal / grande (+100 do final) |
| SFX-079 | Day 100 | conquista secreta (FEAT-031) | 1,5 s | versão especial do SFX-078 | P3 | 1 |

### 5.7 Telefone e ligações do chefe (FEAT-018, DEC-124)

Sem dublagem (`script.md`: "murmúrio de voz de telefone, sem dublagem" + "heh"). A legenda carrega o texto.

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-080 | Toque do telefone | telefone fixo do veículo tocando, até "Answer" ou 15 s (no mundo, todos ouvem); também a alucinação < 60 | loop 2–3 s | campainha mecânica antiga, **exclusiva** (§2.1) | P1 | 1 (nunca variar) |
| SFX-081 | Atender | "Answer" | 0,3 s | fone saindo do gancho, clique mecânico | P1 | 1 |
| SFX-082 | Voz do Walt | cada linha de legenda (2,5 s por linha) | 0,5–2 s | murmúrio sem palavras, abafado de alto-falante, velho e caloroso | P1 (onda 2) | 6–8 murmúrios + 2 "heh" |
| SFX-083 | Desligar | fim da ligação | 0,4 s | fone no gancho + tom curto | P1 | 1 |
| SFX-084 | Celular flip | intro: abrir, discar, chamar (AST-038) | 3–4 s | bipes de teclado + tom de chamada | P2 (onda 4) | 1 |

### 5.8 Ladrão (FEAT-013, NPC-007 Quick Quentin)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-090 | Quentin espreita | andando até a gaveta (4 s), só perto | loop 1 s | passos na ponta dos pés, cômicos | P3 | 1 |
| SFX-091 | Mexendo na gaveta | abertura de 8 s (16 s com Cash Drawer Lock), no mundo | loop 1–2 s | moedas chacoalhando + trinco forçado | P1 (onda 2) | 1 |
| SFX-092 | Cadeado | gaveta com Cash Drawer Lock resistindo | 0,3 s | "clank" metálico | P2 | 2 |
| SFX-093 | Nice catch! | ladrão impedido, foge, +$5 | 0,8 s | fuga de desenho ("zip") + sininho positivo | P1 (onda 2) | 1 |
| SFX-094 | Roubou | ladrão leva a parte da gaveta | 1 s | fuga + 3 notas descendo, "ops" | P1 (onda 2) | 1 |

### 5.9 Passos

Personagem padrão do Roblox já tem passo e pulo. Estes substituem. NPCs comuns **sem passo** (12 NPCs, custo e poluição); exceção: Walker (SFX-149).

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-100 | Passo, calçada e rua | jogador andando fora | 0,2 s | pata macia de brinquedo | P2 | 6 |
| SFX-101 | Passo, trailer | piso metálico do trailer | 0,2 s | metal oco, leve | P2 | 4 |
| SFX-102 | Passo, Mart | piso de azulejo | 0,2 s | seco, leve | P3 | 4 |
| SFX-103 | Pulo e aterrissagem | pulo do jogador | 0,2 s | "hup" sem voz + baque macio | P3 | 2 |

### 5.10 Trânsito e atropelamento (FEAT-033, DEC-095, DEC-197)

Tom pastelão. **Proibido:** batida realista, osso, grito, metal amassado, freada desesperada (style guide §4.6).

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-110 | Motor de carro | carro de trânsito andando (no mundo), audível desde o spawn a ≥ 55 studs (~2,5 s de aviso) | loop 2–4 s | motorzinho de brinquedo, simpático | P2 (onda 3) | 3 (sedã, picape/van, táxi) |
| SFX-111 | Ônibus | ônibus amarelo de manhã e na intro | loop 3 s | motor maior, ainda de brinquedo | P3 | 1 |
| SFX-112 | Buzina cômica | atropelamento ("honk-honk"); carro na intro ("beep-beep") | 0,5 s | buzina curta e engraçada | P2 | 3 |
| SFX-113 | PARE | carro para 1 s na placa da Juniper (DEC-133) | 0,4 s | rangido de freio de brinquedo, curto | P3 | 2 |
| SFX-114 | Boing | impacto do atropelamento | 0,5 s | mola de borracha | P2 | 3 |
| SFX-115 | BONK + estrelinhas | arremesso; anel de estrelinhas | 0,6 s | "bonk" oco de desenho + tilintar | P2 | 2 |
| SFX-116 | Estrelinhas girando | loop enquanto está no chão (2,5 s) | loop 1 s | tilintar girando | P2 | 1 |
| SFX-117 | Levantar | fim do ragdoll, nuvem de poeira | 0,4 s | "poof" | P2 | 1 |

### 5.11 Noite: luz, escuro, esconder, sanidade (FEAT-019, FEAT-020, FEAT-023)

Regra: **ver uma anomalia (−5) não tem som.** Som no momento do "ver" apontaria o alvo (style guide §4.4).

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-120 | Interruptor | prompt "Lights" no trailer (DEC-189; verbo da ANM-003) | 0,2 s | interruptor antigo, clique grosso | P1 (onda 2) | 2 (liga / desliga) |
| SFX-121 | Lâmpada do trailer | acende/apaga; pisca 1× (ANM-005 erro); apaga 3 s (ANM-008 erro) | 0,3 s | zumbido curto + "tink" | P2 | 2 |
| SFX-122 | Entrou no escuro | começa o dreno (fora da luz > 3 s) | 0,8 s | sopro grave quase inaudível | P2 | 1 |
| SFX-123 | Erro de regra (−35) | jogador quebra regra comum | 1 s | batida grave abafada + ambiente estreita 1 s; nada de grito | P2 (onda 3) | 2 |
| SFX-124 | Esconder | "Hide" atrás do balcão (ANM-008, ANM-009) | 0,4 s | roupa + agachar | P2 | 2 |
| SFX-125 | Levantar | "Get Up" | 0,3 s | roupa | P2 | 1 |
| SFX-126 | Postes acendendo | 8:00 PM, postes da Juniper um a um (`world.md` §2) | 0,5 s cada | clique + zumbido crescendo | P3 | 3 |

### 5.12 Alucinações de sanidade baixa (FEAT-019, `script.md` §8; só no client, nunca interativas)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| — | Telefone fantasma | < 60: telefone toca, legenda "Walt: ..." | — | **o próprio SFX-080** (de propósito) | P2 | — |
| — | Grelha vazia chiando | < 60 | 2–3 s | **o próprio SFX-021** | P2 | — |
| SFX-130 | Passos no teto | < 40: passos leves no teto do trailer | 3–4 s | passos leves e lentos sobre metal | P2 | 3 |
| SFX-131 | Poste pisca sem zumbir | < 40: alarme falso do Walker | 0,4 s | estalo elétrico seco, **sem** zumbido (DEC-123) | P2 | 2 |
| SFX-132 | Sussurro "Rookie..." | < 20 | 1–1,5 s | sussurro baixo e distante; **única fala gravada do jogo** (ver §7) | P3 | 2 |
| SFX-133 | Letreiro do Mart pisca | < 20 | 0,4 s | estalo de neon | P2 | 1 |
| SFX-134 | Sombra na janela | < 20 | 0,6 s | "whoosh" de tecido muito baixo | P3 | 1 |
| SFX-135 | Susto leve | < 20, raro (DEC-173) | 0,5–1 s | nota curta dissonante; volume no teto do §6 | P3 | 2 |

"Cliente que some ao ser olhado" (< 40): **sem som**.

### 5.13 Anomalias (ANM-001 a ANM-010; sinais e erros de `anomalies.md`, Aprovado; sabor só o que entra pela DEC-195)

| ID | Anomalia | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|---|
| — | ANM-001 | Blank folks | sinal só visual; sem som próprio | — | — | — | — |
| SFX-140 | ANM-001 | Moeda sem desenho | erro (sabor, DEC-195 entra): ele "paga" | 0,3 s | moeda oca, sem brilho (o contrário do SFX-043) | P3 | 1 |
| SFX-141 | ANM-002 | Item alterado surge | sinal aprovado: chiado curto quando o item aparece no trilho/tábua | 0,5 s | chiado seco e abafado, mais curto que a grelha | P2 | 2 |
| SFX-142 | ANM-002 | Vira fumaça | erro (sabor): cliente morde, hot dog vira fumaça | 0,6 s | "puff" | P2 | 1 |
| — | ANM-003 | Relógio parou | sinal = **AMB-004 para**; volta quando a sequência de luz é cumprida. Erro: grelha para de chiar (SFX-021 em silêncio). Relógio congelado: cortado (DEC-195) | — | — | — | — |
| — | ANM-004 | Copies | sem som próprio | — | — | — | — |
| SFX-143 | ANM-005 | Pingos e poça | loop enquanto a Raincoat Lady está presente (no mundo) | loop 2 s | pingos calmos em poça; gentil, nada assustador | P2 | 3 |
| SFX-144 | ANM-005 | Chuva no trailer | erro (sabor), 20 s sobre o trailer. **Só se entrar** pela classificação da DEC-195 (pendência §7) | loop 5 s | chuva leve em teto de metal | P3 | 1 |
| SFX-145 | ANM-006 | Cortina correndo | sinal de início aprovado (FEAT-022: "não olhar" tem som de início) | 1 s | cortina de argola correndo | P2 | 2 |
| SFX-146 | ANM-006 | Janelas extras | erro (sabor): mais duas janelas acendem | 0,3 s | clique de interruptor longe | P3 | 1 |
| SFX-148 | ANM-007 | Zumbido do Walker | sinal de início (DEC-123): último poste da Juniper, ouvido por **todos** (tela) | ~2 s | zumbido elétrico grave que **sobe** e **para seco**; volume médio, sem pico; **reservado** | P2 (obrigatório na onda 3) | 1 (nunca variar) |
| SFX-149 | ANM-007 | Passo do Walker | cada avanço (o poste pisca junto) | 0,6 s | batida abafada e grave, pesada, com corpo médio para o celular | P2 | 3 |
| SFX-151 | ANM-008 | Motor do long car | chegada, parado, saída (no mundo) | loop 3 s | zumbido grave contínuo, liso; **não** soa como brinquedo; **reservado** | P2 | 1 |
| SFX-152 | ANM-008 | Farol alto | acende direto no trailer | 0,3 s | "clack" grosso de farol | P2 | 1 |
| SFX-153 | ANM-008 | Farol pisca 2× | fim da janela de ~8 s | 0,8 s | dois "clack" | P2 | 1 |
| SFX-154 | ANM-008 | Buzina baixinha | erro (sabor): "como quem achou alguém" | 0,6 s | buzina grave, curta, baixa | P2 | 1 |
| SFX-155 | ANM-009 | Batidas | sinal: 3 batidas, pausa, 3 batidas na porta dos fundos | 3 s por série | nós de dedo em porta de metal, firmes, sem pressa | P2 | 3 séries |
| SFX-156 | ANM-009 | Voz pela porta | junto da legenda "???: Rookie? It's me..." | 1–2 s | murmúrio abafado pela porta, **mesmo timbre do SFX-082** (imita o Walt) | P2 | 2 |
| SFX-157 | ANM-009 | Porta range | erro (sabor): abre um dedo e fecha sozinha | 1,5 s | rangido de dobradiça + porta batendo leve | P2 | 1 |
| SFX-158 | ANM-009 | Vento e guardanapos | erro (sabor) | 1,5 s | rajada fria + papéis voando | P2 | 1 |
| SFX-160 | ANM-010 | "Tunk" de poste | cada poste da Juniper apagando (~15 s do 1º ao da esquina) | 0,5 s | "tunk" abafado de disjuntor | P2 | 4 |
| SFX-161 | ANM-010 | Postes voltando | fim do Hush; 6:00 AM da Night 10 | 1,5 s | zumbido religando em cascata | P2 | 1 |

"Pedidos esfriam" (ANM-010, sabor) é só vapor sumindo: sem som.

### 5.14 Fim da noite (FEAT-026, `script.md` §7)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-170 | Noite vencida | 6:00 AM com vitória (+ AMB-010) | 1,5 s | frase curta e quente do tema do dia | P1 (onda 2) | 1 |
| SFX-171 | Luzes falham | noite perdida: luzes do trailer piscam 2 s e apagam (e o poste da esquina, na regra crítica) | 2 s | zumbido falhando + "clunk" de corte | P2 | 1 |
| SFX-172 | Night Lost | tela "Night Lost" | 1,5 s | duas notas graves, gentis | P2 | 1 |
| — | Ambulância indo embora | amanhecer da noite perdida (DEC-122): **sirene desligada** | — | só o SFX-184 se afastando | P2 | — |

### 5.15 Desmaio, ambulância e reviver (FEAT-025, FEAT-034, `script.md` §9)

Tom de cuidado e resgate. Nada de grito, nada de câmera tremendo, sirene nunca mais alta que o ambiente.

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-180 | Desmaio | sanidade 0: duas batidas de coração abafadas; ambiente abafa | 1,2 s | coração lento, macio | P2 (onda 4) | 1 |
| SFX-181 | Tombar | personagem senta e deita de lado | 0,4 s | baque de roupa, macio | P3 | 1 |
| SFX-182 | Zzz | balão "Zzz" sobre o caído (colegas ouvem) | loop 2 s | ronquinho fofo | P3 | 2 |
| SFX-183 | Sirene | ambulância chegando/saindo (não toca na saída da noite perdida) | loop 2 s | duas notas, baixa, entra e sai em fade; **reservada** | P2 | 1 |
| SFX-184 | Motor da ambulância | ambulância andando | loop 3 s | van de brinquedo, um pouco mais grave que o SFX-110 | P2 | 1 |
| SFX-185 | Portas traseiras | médicos descem/sobem | 0,5 s | portas de van abrindo/fechando | P2 | 2 |
| SFX-186 | Maca "poof" | personagem deitado na maca; embarque | 0,4 s | "poof" macio | P2 | 1 |
| SFX-187 | Rescue Whistle | "Blow Whistle" / "Use Whistle" | 0,8 s | apito alegre de duas notas | P2 (onda 4) | 1 |
| SFX-188 | Reviver confirmado | Robux ou crédito confirmados; "Hang on — Rescue's turning around!" | 0,8 s | sting curto positivo | P2 | 1 |
| SFX-189 | De volta | reaparece em REV-1..4: "poof" + brilho, "Back on shift!" | 0,6 s | "poof" + brilho | P2 | 1 |
| SFX-190 | Janela de 10 s | 1 pulso por segundo do contador | 0,3 s | pulso macio; **sem tique-taque alarmante** (style guide §7.2) | P2 | 1 |

### 5.16 Lobby e party (FEAT-001, DEC-179)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-200 | Entrar na plataforma | pisar = entrar na party | 0,4 s | "pop" + sininho subindo | P1 (onda 2) | 1 |
| SFX-201 | Sair da plataforma | sair da party | 0,3 s | o mesmo descendo | P1 (onda 2) | 1 |
| SFX-202 | Contagem do Start | 5 s antes do teleporte | 1 bipe/s + final | bipes de brinquedo; o último mais alto | P1 (onda 2) | 2 (bipe / final) |
| SFX-203 | Teleporte | saída do lobby | 0,8 s | "whoosh" | P1 (onda 2) | 1 |
| SFX-204 | Escolher classe | animal escolhido na tela "Crew" | 0,4 s | pop + blip do animal | P2 | 1 |
| SFX-205 | Desbloquear classe | compra com gemas | 1 s | SFX-078 + fanfarra curta | P2 | 1 |

### 5.17 Cutscenes e final (FEAT-004, FEAT-027, `script.md` §1, `ending.md`)

| ID | Nome curto | Quando toca | Duração/loop | Tom/referência | Prioridade | Variações |
|---|---|---|---|---|---|---|
| SFX-210 | Pombos | intro, plano 1 | 1,5 s | asas levantando voo | P3 | 1 |
| SFX-211 | Suspiro | intro, vitrines "NO HELP WANTED" | 1 s | suspiro não verbal, cômico | P3 | 1 |
| SFX-212 | Vento e panfleto | intro (panfleto velho no poste) e pós-créditos (panfleto novo) | loop 3 s | vento + papel batendo | P2 | 1 |
| SFX-213 | Relógio bate 6 | 6:00 AM da Night 10 | ~6 s | sino grave, 6 badaladas | P2 | 1 (1 badalada × 6 também serve) |
| SFX-214 | Copos de café | Walt estende o café (fala 9) | 0,4 s | copo de papel com tampa | P3 | 1 |
| SFX-215 | Poça some | Raincoat Lady desaparece na poça | 0,8 s | "plop" suave, mágico | P3 | 1 |
| SFX-216 | Fim de run (final) | tela "You Kept the Light On" | 2 s | resolução do tema do dia | P2 | 1 |

Reusos nas cutscenes: buzina (SFX-112), motor (SFX-110), ônibus (SFX-111), celular flip (SFX-084), porta do Mart (SFX-060), telefone (SFX-080).

---

## 6. Mixagem e regras de terror (verificáveis)

| Regra | Valor | Origem |
|---|---|---|
| Teto do susto | nenhum SFX de alucinação ou anomalia passa **+3 dB** acima do ambiente da noite no mesmo instante | DEC-005, DEC-173 |
| Grito, gore, impacto realista | proibidos | DEC-023, DEC-172, style guide §4.6 |
| Música e anomalia | música **não** muda quando uma anomalia aparece; MUS-004 entra por número da noite ou por estado (Q-159), com fade ≥ 3 s | style guide §4.4 |
| Ver anomalia | sem som | style guide §4.4 |
| Sirene | nunca acima do ambiente; fade de entrada e saída | style guide §11 |
| Telefone | todos ouvem; longe, mais baixo (queda até ~40 studs, nunca some) | FEAT-018 |
| Zumbido do Walker | todos ouvem, sem queda por distância | DEC-123 |
| Tique-taque | audível no Pad (~73 studs do relógio) | MAP-01 C-01 |
| Ligação | música −6 dB enquanto o Walt fala | proposta |
| Sons simultâneos | teto de **24** sons tocando no client (proposta, mobile); passos de NPC desligados | DEC-045 (custo de NPC) |

---

## 7. Critérios de aceite da lista

- Todo P1 tem arquivo escolhido, licença conferida e linha em `credits.md` (ou é original do projeto) antes de subir ao Roblox.
- Todo arquivo sobe dentro dos limites do §0 e com os alvos de volume do §0 (conferir com medidor LUFS; ±2 LU).
- Todo loop toca 3 vezes seguidas sem clique nem emenda audível.
- Os 5 sons reservados (§2.1) não aparecem em nenhum outro ID nem em outro lugar do jogo.
- No celular, com volume do aparelho a 50%, o QA identifica de olhos fechados: telefone, zumbido do Walker, passo do Walker, batidas da N9, cortina da N6 e o tique-taque parando.
- Nenhum som do jogo usa trecho de música, jingle ou efeito de outro jogo, filme ou marca.

## 8. Pendências (para o secretário registrar; nenhuma bloqueia a onda 1)

| Tema | Recomendação Provisória |
|---|---|
| Prefixos `SFX-`/`MUS-`/`AMB-` na tabela de IDs do `CLAUDE.md` | registrar, dono `docs/audio/sound-list.md` |
| Pasta de áudio no repositório | `Assets/audio/<music\|ambience\|sfx>/<ID>_<nome>.ogg` |
| Única voz gravada (SFX-132 "Rookie...") | P3; se não houver voz com licença, a alucinação vira só legenda + respiração |
| Chuva no trailer (ANM-005, sabor; DEC-195 manda o game-designer classificar) | **entra** como VFX + SFX-144 (efeito temporário de área, sem sistema novo); "Thank you, dear." entra como balão, sem som; "pedidos esfriam" entra só como VFX |
| Export do AnimalPlane (`Bell`, `Pop`, `ClickHover`, `ChargeUp`; `Q-045`) | se vier, cobre SFX-001/002/008/009/022 |
| Humor dinâmico (DEC-187, `Q-164`) | sem som novo até o desenho; usa SFX-045 a SFX-048 |
