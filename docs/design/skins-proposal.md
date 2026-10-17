Status: Rascunho

# Skins das classes — proposta (Halloween primeiro)

Pedido do dono, 2026-10-17 (resumo fiel): skins para as classes jogáveis, vendidas **só por Robux** (nenhuma por
gema). Uma skin = retextura da roupa/pelagem e/ou acessórios diferentes. Prioridade: skins de **Halloween**, marcadas
como **LIMITADAS**, à venda antes do fim de outubro (Halloween 31/10). Na tela de classes: fileira de círculos (skins
da classe focada) embaixo à direita, alinhada com o painel de stats; clicar mostra o **preview** no personagem do palco
(sem equipar); o botão do painel passa a mostrar o preço da skin em Robux (ou Equip se já tiver); selo LIMITED.

Autores: game-designer (regras, preços) + art-director (visual) + architect (produto, perfil, rede), via sessão de
skins. Tudo **Provisório** até DEC do dono. Perguntas: `open-questions.md` **Q-300 a Q-305**. Tasks: **TASK-370 a
TASK-375** (`tasks/board.md`). Assets: **AST-123** (folhas de roupa das skins) e **AST-124** (ícones das skins).

Guarda da DEC-069 (pay-to-win): skin é **só visual**. Nenhum número da classe muda com a skin; a skin não entra em
`ClassService:GetModifier`.

---

## 1. Lote 1 — Halloween (limitadas)

Uma skin por classe do MVP. Retextura da folha da roupa (boné, camisa, calça, avental e o emblema do avental) +
cor de pelagem opcional (o pelo é a cor da peça sob o alfa 0 da textura: trocar a cor não precisa de textura nova da
cabeça). Sem malha nova no lote 1 (prazo: 31/10); acessórios 3D ficam para o lote 1b (§4).

| Chave (`Content.Skins`) | Classe | Nome (UI, inglês) | Visual (art-director) | Pelo | R$ sugerido |
|---|---|---|---|---|---|
| `skin_dog_pumpkin` | Rookie / Cachorro | **Pumpkin Rookie** | boné e avental abóbora (laranja), camisa preta com listras laranja, calça verde-folha; emblema = abóbora sorridente | igual | 99 |
| `skin_rabbit_ghost` | Runner / Coelho | **Ghost Runner** | tudo branco-lilás de "lençol de fantasma", calça cinza-azulada; emblema = fantasminha | branco frio `#E9EEF8` | 129 |
| `skin_cat_witch` | Line Cook / Gato | **Witch Cat** | boné e avental roxos com estrelinhas Mustard, camisa preta, calça roxa escura; emblema = lua + estrela | gato preto `#3A3640` | 129 |
| `skin_bear_franken` | Hauler / Urso | **Franken Hauler** | boné e avental cinza-chumbo com costuras, camisa verde-musgo, calça preta; emblema = raio | verde `#86B86A` | 129 |
| `skin_fox_vampire` | Hawker / Raposa | **Count Hawker** | boné e avental pretos com forro vinho (não o vermelho de alerta), camisa branca; emblema = morceguinho | igual | 149 |
| `skin_owl_skeleton` | Night Owl / Coruja | **Bone Owl** | tudo preto com "ossinhos" creme (listras de costela na camisa, avental com caveirinha sorridente) | cinza-carvão `#4A4650` | 149 |

Tom: fofo, "fantasia de Halloween do food truck", nunca sangue nem susto real (público infantil, terror leve).
Night/Mid: as folhas ganham as versões Mid/Night pelo mesmo tom das outras roupas (escurece e esfria, não troca cor).

Preço (game-designer): skins custam **mais que a classe tier 1** (79) porque são o produto de impulso sazonal, e o
Cachorro (todo mundo tem) é a porta de entrada a 99. Referência do gênero: skins de 99–199 R$. **Provisório,
`Q-302`.**

## 2. Regras (game-designer)

- **Só Robux.** Developer Product por skin (§3). Nenhum caminho por gemas, códigos ou conquistas no lote 1.
- **Limitada** = `Limited = true` + `EndsAt` (os.time UTC). Até lá está à venda; depois **some da fileira para quem
  não tem** e quem tem fica com ela para sempre. Data Provisória: **2026-11-03 00:00 UTC** (domingo 2/11 à noite nas
  Américas: o fim de semana depois do Halloween conta). `Q-301`.
- A tela mostra o selo **LIMITED** no círculo e uma faixa no topo: "Halloween Skins · Limited · Nd left".
- **Equipar por classe:** cada classe guarda a skin equipada (ou nenhuma = uniforme da crew). Trocar de classe não
  perde a skin da outra.
- **Comprar skin de classe que não tem:** pode (o preview funciona em qualquer classe); a skin fica guardada e só
  pode ser equipada quando tiver a classe. O botão diz "Needs the class" no lugar de Equip. **Provisório, `Q-300`.**
- Comprou uma skin de classe que tem: **equipa sozinha** (o feedback é ver o personagem mudar).
- Na run a skin trava junto com a classe (a run lê a skin no spawn, como a classe).
- **Presente de skin:** fora do lote 1 (6 produtos a mais, e o `GiftService` hoje só conhece classe e gemas). Se as
  skins venderem, lote 2 ganha `gift_skin_*` no mesmo molde. **Provisório, `Q-303`.**

## 3. Técnica (architect)

**Developer Product, não Game Pass.** Motivos: (a) limitada se controla no servidor (o `EndsAt` fecha a venda sem
mexer no Creator Hub; um Game Pass continua vendável na página do jogo até alguém tirar de venda à mão); (b) presente
futuro só existe como Developer Product; (c) dezenas de skins não poluem a aba "Passes" da página; (d) o recibo já
passa pelo `ShopService` idempotente (PurchaseId no perfil). Contra: a posse fica no perfil (ProfileStore), não no
inventário Roblox — igual às gemas, aceitável.

- **Dados:** `src/Shared/Content/Skins.luau` (`Content.Skins`): `Key, Ref, Class, Name, Text, Theme, Robux,
  ProductId (0 = não criado), Limited, EndsAt, Fur?, Swatch {cor1, cor2}, Order`. Folhas por skin em
  `src/Crew/shared/SkinLooks.luau` (`[skin] = {Day, Mid, Night}`, ids do upload) e ícones em `SkinImages`.
- **Perfil:** `Skins: {[skinKey]: os.time()}` (posse) e `EquippedSkins: {[classKey]: skinKey}`. Reconcile adiciona
  `{}` aos perfis antigos: sem migração. Escritor: `SkinService`.
- **Rede (Lync, `src/Libs/Net`):** `SkinState` s→dono (`Owned` bitfield das chaves, `Equipped` lista
  `{Class, Skin}`); `SkinEquip` c→s (`Class`, `Skin` ou `"none"`), responder `SkinService`, limite próprio.
  O `Profile` não muda (outras sessões).
- **Compra:** o client chama `PromptProductPurchase` (só se à venda e não tiver); `SkinService` registra cada skin
  no `ShopService:RegisterProduct` e concede no recibo (`Skins[key]`, e equipa se tiver a classe). Recibo depois do
  `EndsAt` concede igual (Roblox já cobrou).
- **Aparência:** atributo **`Skin`** no rig (o `Outfit` continua `"crew"`, nada que testa `Outfit == "crew"` quebra).
  `CrewRig.Build` recebe `Skin`: escreve o atributo e a cor do pelo; `CrewRig.Dress` (client) troca a folha das peças
  `OutfitPart` pela folha da skin no pack atual. `Skin` entra em `LookAttributes` (re-dress quando muda).
- **Run:** `CharacterService:Spawn` pede `SkinService:SkinOf(player, class)` (travada com a classe).
- **Lobby:** o palco do `LobbyController` monta o rig com a skin do preview (cache por espécie + skin).

## 4. Depois do lote 1

- **1b — acessórios 3D de Halloween** (art-director → modeler-3d, fichas novas): chapéu de bruxa (substitui o boné,
  `Hat`), parafusos do Frankenstein, capa do vampiro, balde de abóbora na mão. Entram na mesma linha da skin
  (`Accessories` / `Hat`), sem mudar código.
- **Lote 2 — fixas (não limitadas)**, 1 por classe, 99–149 R$: Gold Chef (branco e dourado), Retro Diner (azul e
  creme), Night Shift (azul-marinho refletivo), Space Cadet, Lifeguard, Galaxy. Mais Panda e Leão quando as classes
  saírem.
- Datas sazonais seguintes no mesmo molde (`Theme`, `EndsAt`): Natal, Ano-novo.

## 5. Métricas

`skin_preview` (clique no círculo), `skin_prompt`, recibo por skin (RoMetrics), skin equipada por classe na run.
Conversão alvo de referência: ≥ 2% de quem abriu a tela de classes no período.
