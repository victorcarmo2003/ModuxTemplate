Status: Rascunho (Provisório) — análise feita em 2026-10-17 sobre 178 jogos (160 do ranking BR + 18 mega-jogos buscados), ícone 512 e primeira thumbnail 768×432 de cada um, baixados pela API pública de thumbnails.

# Análise visual das thumbnails do topo do Roblox

Imagens e folhas de contato em `scratchpad/thumbs/` (sessão). Métricas em `stats.json`.

## 1. Métricas (média por gênero, thumbnails 16:9)

| Gênero | n | % escuro (<0,2) | % claro (>0,8) | contraste (desvio) | saturação | quente | frio | nitidez (bordas) |
|---|---|---|---|---|---|---|---|---|
| Simulation | 57 | 0,18 | 0,14 | 0,23 | 0,56 | 0,26 | 0,31 | 0,14 |
| Survival (terror/anomalia) | 31 | 0,56 | 0,04 | 0,19 | 0,49 | 0,35 | 0,16 | 0,08 |
| Action | 19 | 0,17 | 0,18 | 0,23 | 0,44 | 0,30 | 0,17 | 0,12 |
| Roleplay/Avatar | 12 | 0,17 | 0,25 | 0,23 | 0,40 | 0,23 | 0,17 | 0,12 |
| RPG | 10 | 0,34 | 0,11 | 0,25 | 0,51 | 0,25 | 0,33 | 0,17 |
| Obby | 4 | 0,07 | 0,14 | 0,21 | 0,54 | 0,35 | 0,23 | 0,12 |
| **Todos** | 178 | **0,27** | **0,13** | **0,22** | **0,52** | **0,28** | **0,25** | **0,13** |
| **Mega (18)** | 18 | 0,33 | 0,10 | 0,20 | 0,56 | 0,33 | 0,24 | 0,10 |
| **Sell Hotdogs (nossas 14)** | 14 | **0,46** | **0,01** | 0,18 | 0,55 | **0,58** | **0,09** | **0,05** |

Leitura:
- **Nossas thumbs não têm branco.** 1 % de pixels claros contra 13 % do mercado. Sem ponto de ancoragem luminoso (olhos brancos gigantes, texto branco, brilho).
- **Nossas thumbs são monocromáticas quentes.** 58 % quente contra 9 % frio. O mercado equilibra (28/25). O "pop" vem do choque quente × frio, não de tudo laranja.
- **Nossas thumbs são moles.** Nitidez 0,05 contra 0,13. Blur de borda + luz suave + sem outline = imagem sem definição a 250 px.
- **Nossas thumbs são escuras.** 46 % contra 27 %. O gênero Survival chega a 56 %, mas compensa com brancos puros (olhos, dentes, texto) e um único foco.

## 2. O que os grandes fazem (observação direta)

### Comum a todos os gêneros
1. **Um rosto grande ou um objeto grande** domina o quadro: cabeça do personagem ocupa 40–70 % da altura (Pet Sim 99, Adopt Me, 99 Nights, Dandy's World, Cat Battles).
2. **Olhos enormes com branco puro** e pupila preta grande. É o ponto mais claro da imagem. Nos monstros, só o olho branco já basta (99 Nights, Walker do DOORS).
3. **Outline escuro grosso** (2–4 px a 512) ou **glow** separa personagem do fundo em quase todo jogo de simulador/fofo. Nos de terror, a separação vem de rim light + fundo preto.
4. **Fundo é cenário real do jogo, mas simplificado e desfocado/escurecido**; nunca compete com o personagem. Céu azul saturado é o fundo padrão de simulador.
5. **Câmera baixa ou no nível dos olhos, lente levemente grande angular** (personagem "entrando" no quadro, mãos/objetos em primeiro plano, perspectiva forçada).
6. **Ícone ≠ thumb.** O ícone é quase sempre um close ainda maior (1 rosto, 1 objeto, 1 logo). A thumb abre para 2–3 figuras + cenário.
7. **Texto:** 1–3 palavras, fonte redonda/pesada (estilo Luckiest Guy / Fredoka / Lilita), branca com stroke preto grosso ou amarela com stroke marrom; 10–15 % da altura; canto superior ou inferior, nunca no meio. Números gigantes em simulators ("$997,151,167/s", "1 in 900a").
8. **Saturação alta nos personagens, mais baixa no fundo.** Vermelho, laranja, ciano e verde-limão são as cores de destaque.
9. **Ação congelada no instante antes**: corrida, mão estendida, boca aberta, "zzz" dormindo com o monstro atrás.
10. **Nada essencial nos 15 % de baixo**; o texto principal fica em cima.

### Terror / anomalia (Survival)
- **Preto + uma cor** (vermelho no Pressure/Forsaken/Steal or Die, verde no DOORS, laranja do fogo no 99 Nights).
- **Monstro parcial, grande, olhos brancos**: DOORS (Figure espiando pela porta), 99 Nights (cervo com olhos redondos brancos ocupando o ícone inteiro), IT WANTS IN (crânio na porta).
- **Jogos de anomalia com animais fofos (Animal Hospital, Sell Fries, Scary Shawarma, Don't Get Fired):** cena CLARA e bem iluminada (sala de espera, cozinha), personagens fofos em fila/balcão, e a anomalia é UM detalhe errado (boca de dentes no coelho do meio, abóbora com olhos vermelhos na janela). Não é escuro. O medo vem do contraste fofo × errado, não da escuridão.
- Logo/texto em fonte "suja"/dripping (DOORS, Pressure, Forsaken) ou nenhuma.

### Simulator / tycoon / incremental
- Céu azul saturado, grama verde, personagem feliz com sobrancelha "confiante".
- Números absurdos em texto gigante; setas "+1 +3"; "NEW", "2X", "SECRET".
- Objeto gigante desproporcional (abóbora, ovo, dinossauro) ao lado do avatar pequeno.
- Paleta arco-íris, zero preto.

### Fofo / animais / roleplay
- Personagem olhando para a câmera, cabeça grande, bochecha rosada, boca aberta sorrindo.
- Fundo rosa/azul-claro com brilhos, partículas, gemas.
- Título do jogo como logo (ADOPT ME!, Brookhaven, LifeTogether) em branco com stroke.
- Dress to Impress usa estética de editorial/influencer (render realista, pastel, bokeh).

### Obby / party / minigame
- Dois personagens com expressões opostas (um confiante, um apavorado), ação cômica (pum, empurrão).
- Cores de pôr do sol (rosa/laranja/roxo), tudo muito saturado.
- Setas e círculos explicando a mecânica (Scooter Duo, Hide in Pixels).

## 3. Diagnóstico das nossas 14 e o que mudar

| Problema | Evidência | Correção |
|---|---|---|
| Sem âncora branca | bright 0,01 | olhos do monstro em branco puro maior; olhos/dentes do herói brancos; texto branco com stroke |
| Monocromático quente | warm 0,58 / cool 0,09 | fundo frio (azul/roxo/verde-petróleo), herói quente; rim light fria |
| Mole / sem definição | edges 0,05 | tirar blur de borda; outline 3–4 px escuro no herói; unsharp mask; personagens maiores |
| Escuro demais | dark 0,46 | subir exposição do cenário; o terror vem do "detalhe errado", não do breu (Animal Hospital, Sell Fries) |
| Personagem pequeno | rosto < 25 % da altura na maioria | rosto do herói a 40–60 % da altura; monstro cortado pela borda |
| Sem texto | nenhuma tem | testar 1–2 palavras (DON'T LOOK / REFUSE! / 10 NIGHTS) em fonte redonda |
| Fundo compete | trailer cheio de props nítidos | desfocar/escurecer fundo 30–40 %, manter só o que conta a história |

## 4. Jogos-referência por arquétipo (para a skill)

| Arquétipo | Referência | Para o nosso jogo |
|---|---|---|
| "Fofo + um detalhe errado" (claro) | Animal Hospital, Sell Fries, Scary Shawarma | fila de clientes no trailer de dia, um com boca de dentes |
| "Herói grande + monstro atrás" (escuro) | 99 Nights (thumb), DOORS | urso feliz em close, Walker olhos brancos atrás |
| "Só o monstro" (ícone) | 99 Nights (ícone), Pressure, IT WANTS IN | cabeça do Walker ou do Sorriso ocupando o ícone |
| "Corrida/ação" | Cat Battles, Fart Obby, Bumpy Flight | raposa correndo do carro, câmera baixa, grande angular |
| "Número gigante / NEW" | Steal a Brainrot, Grow a Garden | "10 NIGHTS", "NEW ANOMALY" |
