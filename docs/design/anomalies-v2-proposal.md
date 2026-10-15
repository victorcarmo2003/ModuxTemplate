Status: Aprovado na estrutura (DEC-254 famílias, DEC-255 erro, DEC-256 jumpscare, DEC-257 atmosferas; 2026-10-14). Números, ritmo §5, monstros e textos seguem Rascunho. Substitui as regras de `story/anomalies.md`.

# Anomalias V2 — simples, rápidas e tensas

Pedido do dono (2026-10-14, conversa): refazer as anomalias para ficarem **mais simples**, rápidas de implementar e ainda tensas,
no espírito do jogo de shawarma de anomalias que estourou no Roblox (**inspiração, não cópia**: nada de nomes, falas, monstros ou assets de lá).
Exemplos citados pelo dono: cliente **sem rosto**, cliente **tremendo**, **pescoço invertido**, **jumpscare de monstros** que vão aparecendo,
**falha de energia**, **sair do trailer e se esconder nos fundos**, e **brincar com o ambiente**: mapa todo escuro, **névoa vermelha**, **chuva**.

## 1. O problema do sistema atual

| Hoje (Aprovado, DEC-073) | Custo |
|---|---|
| 10 anomalias, **uma regra diferente por noite**, cumulativas | o jogador precisa decorar 10 regras; criança esquece |
| 7 verbos (recusar, atender, não olhar, luz, fechar janela, descartar, ponto seguro) | cada verbo tem sistema próprio |
| 1 módulo servidor + 1 efeito cliente **por anomalia** (~7.800 linhas em `src/Anomaly`) | cada anomalia nova = 500–900 linhas |
| sinais sutis (relógio parado, capa pingando em noite seca, carro comprido) | difíceis de perceber; tensão baixa |

## 2. Princípios da V2

1. **Sinal em 1 segundo.** Bateu o olho, sabe que tem algo errado. Nada de pista escondida.
2. **Só 3 respostas** (mais o "nada"): **RECUSAR**, **ESCONDER**, **RELIGAR A LUZ**. Toda anomalia cai em uma delas.
3. **Curta:** cada ocorrência resolve em **5–30 s**.
4. **Erro = susto + desmaio** (revivível por colega com Revive Kit, como já existe em ANM-002/ANM-004). Sem gore, câmera corta antes do contato (DEC-248).
5. **Variação barata:** a anomalia é **um dado** (tabela), não um módulo. Monstro novo = 1 linha + 1 modelo.
6. **Ambiente faz metade do medo:** cada noite tem uma **atmosfera** (escuro, névoa vermelha, chuva…) que só muda `Lighting`, `Atmosphere`, partículas e som.

## 3. As 4 famílias

### A. Cliente errado — verbo **RECUSAR**

Um cliente da fila chega com **uma** deformação. Recusar = ele vai embora (fade, DEC-246). Atender = ele dá o **jumpscare** e o jogador desmaia.
Tudo é **modificador no rig animal que já existe** (`CustomerActor`): sem modelo novo.

| ID proposto | Nome | Sinal | Como fazer (barato) |
|---|---|---|---|
| ANM-001 (reuso) | Sem rosto | cabeça lisa, sem olhos/focinho | troca a textura do rosto (DEC-242 já define) |
| ANM-011 | Tremendo | o corpo inteiro treme rápido, parado na fila | client: `Heartbeat` soma ruído pequeno no `RootJoint.C0` |
| ANM-012 | Pescoço invertido | cabeça virada 180° (olha para trás), às vezes gira devagar | `Neck.C0 * CFrame.Angles(0, π, 0)` |
| ANM-013 | Olhos brancos / sorriso largo | olhos totalmente brancos e sorriso grande demais | textura de rosto (mesmo padrão da cópia, DEC-245) |
| ANM-014 | Cabeça errada | cabeça 2× maior ou minúscula | `Head.Size` / escala do acessório |
| ANM-015 | Sem sombra / flutuando | anda 20 cm acima do chão, sem passos | `HipHeight` + som de passos mudo |
| ANM-016 | Não pisca, não mexe | fica olhando fixo para o jogador, a cabeça segue a câmera | `Neck.C0` apontando para a câmera |
| ANM-004 (reuso) | A cópia | dois clientes iguais | já implementado |

> A ANM-002 (comida errada) pode virar uma variação desta família: "o pedido pede coisa nojenta" → recusar.

### B. Algo vem vindo — verbo **ESCONDER**

Aviso claro (luzes do trailer piscam + som grave + o chefe grita no rádio "ESCONDE!") → o jogador tem **8–10 s** para **sair do trailer pela porta dos fundos e entrar no esconderijo** (armário/caixote/atrás das lixeiras, uma zona marcada).
O **monstro** atravessa a rua, encosta na janela, olha para dentro e vai embora (~10 s). Quem não estiver escondido: **jumpscare + desmaio**.

| ID proposto | Monstro (original) | Como entra |
|---|---|---|
| ANM-007 (reuso) | The Walker (figura alta) | anda do fim da rua até a janela |
| ANM-017 | Rastejador | vem de quatro pelo chão, rápido |
| ANM-018 | O Sorriso | rosto enorme que aparece na janela de serviço |
| ANM-019 | Sombra no teto | passos no teto do trailer, depois desce pela frente |

Implementação: **um único módulo `Hide`** (aviso → janela de tempo → checa zona → monstro passa). Cada monstro = modelo + caminho (`Path` de 2–4 pontos) + animação simples. Esconderijo = `Part` com `HideZone`.

### C. Falha de energia — verbo **RELIGAR A LUZ**

Estalo, **tudo apaga** (trailer, postes, letreiro). Só a lanterna do jogador. O **disjuntor fica nos fundos** do trailer: ir até lá no escuro e **segurar E por 3 s**.
Enquanto está escuro, ruídos e **um vulto** aparece no canto da tela. **30 s sem religar** = o vulto ataca (jumpscare + desmaio de quem está no trailer).
Reaproveita ANM-003 (luz) e ANM-010 (postes apagando). ID: **ANM-020**.

### D. Sustos sem verbo — **tensão pura**

Não pedem nada; existem para o jogador nunca relaxar. Muitos **já existem** em `src/Hallucination` (FakeCall, GhostCustomer, RoofSteps, WindowShadow, PostFlicker, Whisper, MartSignBlink).

- rosto na janela por 0,3 s; batidas no teto; telefone toca e ninguém fala; rádio com estática e uma voz; letreiro pisca uma palavra estranha;
  cliente parado longe, na rua, olhando; garrafa de ketchup cai sozinha.
- **Monstro de relance:** um monstro aparece no fim da rua e some quando o jogador olha. Sem verbo, sem dano. Prepara o terreno para a família B.

## 4. Atmosferas (uma por noite)

Só ambiente: `Lighting`, `Atmosphere`, `ColorCorrection`, partículas presas à câmera e som. Custo: um preset de dados por atmosfera.

| ID | Atmosfera | O que muda | Efeito no jogo |
|---|---|---|---|
| ATM-1 | Noite normal | padrão | — |
| ATM-2 | Breu | `Brightness` baixo, sem ambient, postes fracos | clientes só aparecem de perto |
| ATM-3 | Névoa vermelha | `Atmosphere` densa vermelha, `ColorCorrection` tinto | monstros de relance escondidos na névoa |
| ATM-4 | Chuva | partículas na câmera, som de chuva, poças | abafa os passos dos monstros |
| ATM-5 | Tempestade | chuva + relâmpago (flash 0,2 s + trovão) | relâmpago revela vulto por um instante |
| ATM-6 | Neblina branca | `Atmosphere` branca densa | fila "surge" do nada |
| ATM-7 | Lua de sangue | céu e lua vermelhos, tudo dessaturado | noite final |

> Nota: a ANM-005 ficou **seca** por DEC-251. Se a chuva voltar como atmosfera, ela **não** aparece em noite de chuva (perde o contraste).

> O prefixo `ATM-` é novo; entra na tabela de IDs do `CLAUDE.md` se aprovado.

## 5. Ritmo das 10 noites (sugestão)

| Noite | Famílias ativas | Novidade apresentada | Atmosfera |
|---|---|---|---|
| 1 | A | sem rosto | normal |
| 2 | A, D | tremendo + sustos de ambiente | normal |
| 3 | A, D | pescoço invertido | chuva |
| 4 | A, C, D | **falha de energia** | breu |
| 5 | A, C, D | olhos brancos, a cópia | neblina |
| 6 | A, B, C, D | **esconder** (Walker) | névoa vermelha |
| 7 | A, B, C, D | rastejador | tempestade |
| 8 | todas | sorriso na janela | breu |
| 9 | todas | sombra no teto | névoa vermelha |
| 10 | todas, mais rápido | tudo junto | lua de sangue |

Cada noite **sorteia** eventos do que já foi apresentado (sem repetir o mesmo seguido). A ligação do chefe no começo da noite apresenta só a **novidade** daquela noite.

## 6. Como fica o código (simplificação)

Mantém o núcleo que já funciona: `AnomalyService` (Api, Scheduler, `ctx.Publish/Cue/Fail/Succeed/Finish`), `Vision`, desmaio/Revive Kit, `Fade`, `CustomerActor`.

| Hoje | V2 |
|---|---|
| 10 módulos servidor `Anomalies/ANM-0xx` | **4 módulos genéricos**: `OddCustomer`, `Hide`, `Blackout`, `Scare` |
| 10 efeitos cliente | 4 efeitos + **tabela de modificadores** (`Content.Anomalies`: `Family`, `Modifier`, `Monster`, `Atmosphere`) |
| regras cumulativas por noite (`Rules/`) | tabela de noite: famílias liberadas, novidade, atmosfera, quantidade de eventos |
| novo `Atmosphere` | `src/Atmosphere/client` + presets em `Content.Atmospheres` |
| jumpscare | **um** componente: rosto do monstro em tela cheia 0,6 s + som + tela de desmaio |

Anomalia nova de cliente = 1 linha de dado + 1 função de modificador (10–30 linhas). Monstro novo = 1 modelo + 1 caminho.

## 7. O que precisa de decisão (vai para `Q-269`)

| # | Ponto | Conflita com | Recomendação do agente (Provisória) |
|---|---|---|---|
| a | Trocar o modelo "1 regra por noite, 10 regras" pelas **4 famílias** | DEC-073, DEC-054, DEC-025 | trocar |
| b | **Jumpscare com monstro** como consequência normal do erro | DEC-173 (raro e leve), DEC-172 (Mild) | permitir, **cartoon**, sem gore, 0,6 s, sem grito estridente; manter Mild |
| c | **Erro = desmaio** (revivível) em vez de −35 de sanidade | DEC-053 | desmaio; sanidade cai pelos sustos (D) e pelo escuro |
| d | Regra crítica (noite perdida) | DEC-074 (só N7) | sem regra crítica; noite perdida só se **todos** desmaiarem |
| e | Esconder **fora do trailer, nos fundos** (porta dos fundos + esconderijo) | DEC-221 (fechar a janela) | sair e esconder nos fundos, como o dono pediu |
| f | Atmosferas por noite | DEC-251 (N5 seca) | sim; a noite 5 não usa chuva |
| g | O que fazer com N6 (wavers), N8 (carro comprido), N9 (batida), N2 (comida) | DEC-073 | N6, N8 cortadas; N9 vira susto (D); N2 vira cliente errado (A) |
