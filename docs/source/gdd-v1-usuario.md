# SELL HOTDOGS!
### Game Design Document — V1

---

# 1. Visão do Jogo

**Sell Hotdogs!** é um jogo de Roblox focado em progressão, gerenciamento de um carrinho de hot dogs e uma transição gradual de um simulador casual para uma experiência de anomalias e terror.

O jogador começa como um **desempregado sem dinheiro**, consegue seu primeiro emprego em uma barraca de hot dogs e começa uma jornada simples de trabalho e progresso.

Ele compra ingredientes, prepara hot dogs, atende clientes, ganha dinheiro, desbloqueia receitas, melhora seus equipamentos e evolui seu carrinho.

Conforme progride, eventualmente desbloqueia um **Food Trailer**.

Nesse momento, o chefe pede que ele cubra o **turno da noite**.

O jogo muda.

A cidade continua sendo a mesma. O trabalho continua sendo o mesmo. O jogador ainda precisa vender hot dogs.

Mas agora existem coisas que **não deveriam estar ali**.

---

# 2. Fantasia Principal

A fantasia do jogador deve evoluir em três etapas:

### Etapa 1 — "Eu preciso arrumar um emprego."

O jogador começa pobre e sem profissão.

### Etapa 2 — "Eu tenho meu próprio negócio."

O jogador progride, desbloqueia equipamentos e transforma uma pequena barraca em um trailer.

### Etapa 3 — "Eu preciso sobreviver ao meu turno."

O mesmo trabalho que antes era tranquilo passa a exigir atenção, memória e percepção.

A mudança deve ser gradual:

> **Desempregado → Funcionário → Vendedor → Dono de Trailer → Trabalhador Noturno → Sobrevivente**

---

# 3. Pilar 1 — Trabalho e Venda

Este é o **core gameplay**.

O jogador trabalha diretamente vendendo hot dogs.

## Subpilares

### 3.1 Compra de ingredientes

Antes do turno, o jogador precisa abastecer seu negócio.

Ingredientes iniciais:

- Pão
- Salsicha
- Ketchup
- Mostarda

Ingredientes desbloqueáveis:

- Queijo
- Bacon
- Cebola
- Pickles
- Chili
- Molhos especiais
- Outros ingredientes futuros

O jogador precisa administrar seu estoque.

---

### 3.2 Preparação

O jogador transforma ingredientes em produtos.

Exemplo:

**Classic Hotdog**

> Pão + Salsicha + Ketchup

**Cheese Hotdog**

> Pão + Salsicha + Queijo + Ketchup

**Bacon Hotdog**

> Pão + Salsicha + Bacon + Molho

Quanto mais receitas desbloqueadas, maior a complexidade do negócio.

---

### 3.3 Atendimento

NPCs aparecem com pedidos.

O jogador precisa:

1. identificar o pedido;
2. preparar corretamente;
3. entregar;
4. receber pagamento.

A qualidade do atendimento influencia:

- pagamento;
- gorjeta;
- XP;
- satisfação do cliente.

---

### 3.4 Eficiência

O jogador deve sentir que fica cada vez melhor no trabalho.

No começo:

> preparar um hot dog demora.

Depois:

> equipamentos melhores tornam o processo rápido.

A progressão deve modificar **a velocidade e capacidade do jogador**, não apenas números abstratos.

---

# 4. Pilar 2 — Progressão

A progressão é responsável por criar o sentimento:

> **"Comecei sem nada e estou construindo minha carreira."**

## Subpilares

### 4.1 Nível do jogador

O jogador ganha XP trabalhando.

Exemplo:

> Level 1 → Level 2 → Level 3...

Níveis desbloqueiam:

- receitas;
- equipamentos;
- ingredientes;
- upgrades;
- novos tipos de carrinho;
- novas áreas;
- novas oportunidades de trabalho.

---

### 4.2 Dinheiro

Dinheiro é a principal moeda de progressão.

É obtido através de:

- venda;
- gorjetas;
- bônus;
- eventos;
- objetivos.

É utilizado para:

- ingredientes;
- equipamentos;
- upgrades;
- veículos;
- expansão do negócio.

---

### 4.3 Receitas

As receitas funcionam como progressão horizontal.

O jogador não fica apenas "mais forte".

Ele passa a ter **mais coisas para vender**.

Exemplo:

```text
Classic
   ↓
Cheese
   ↓
Bacon
   ↓
Chili
   ↓
Mega
   ↓
Especial
```

---

# 5. Pilar 3 — Evolução do Negócio

O jogador não deve sentir que está apenas melhorando atributos.

Ele deve sentir que seu negócio está crescendo.

## Progressão sugerida

### Tier 1 — Carrinho Velho

Pequeno e limitado.

### Tier 2 — Hot Dog Cart

Mais espaço e melhores equipamentos.

### Tier 3 — Improved Cart

Maior estoque e preparação mais eficiente.

### Tier 4 — Food Trailer

Grande salto de progressão.

Mais clientes, mais receitas, mais equipamentos.

### Tier 5+ — Futuras expansões

Podem incluir:

- Food Truck;
- estabelecimento;
- restaurante;
- operações especiais.

Essas expansões não são necessárias para o MVP.

---

# 6. Pilar 4 — Ciclo de Dia e Noite

O ciclo de tempo é uma peça central da identidade do jogo.

## Dia

Representa:

> **trabalho normal e progressão.**

Atividades:

- comprar ingredientes;
- preparar estoque;
- melhorar equipamentos;
- vender;
- atender clientes;
- desbloquear conteúdo.

Durante o dia o jogo deve ser confortável e previsível.

---

## Noite

Representa:

> **risco e anomalias.**

O jogador continua trabalhando.

Porém:

- clientes podem ser diferentes;
- o ambiente pode mudar;
- certas regras precisam ser observadas;
- coisas impossíveis podem acontecer.

O objetivo não é simplesmente "matar monstros".

O jogador precisa:

> **continuar trabalhando enquanto percebe o que está errado.**

---

# 7. Pilar 5 — Anomalias

As anomalias são o principal elemento de horror.

Elas não devem transformar o jogo imediatamente em um survival horror tradicional.

A proposta é:

> **O jogo está normal. Alguma coisa está errada. Descubra o quê.**

## Subpilares

### 7.1 Anomalias observáveis

O jogador deve conseguir perceber sinais.

Exemplos:

- cliente sem rosto;
- cliente duplicado;
- cliente usando roupa proibida;
- objeto que apareceu de repente;
- veículo parado de maneira impossível;
- relógio preso no mesmo horário;
- pessoa que nunca chega ao trailer;
- dinheiro impossível;
- ingredientes alterados;
- trailer em condição diferente da anterior.

---

### 7.2 Regras

Algumas anomalias possuem regras específicas.

Exemplo:

> **"Não atenda pessoas usando vermelho."**

Ou:

> **"Nunca aceite dinheiro dessa pessoa."**

O gameplay passa a envolver:

**observar → lembrar → decidir → agir.**

---

### 7.3 Consequências

Erros devem ter consequências.

Possibilidades:

- perda de dinheiro;
- perda de estoque;
- queda de reputação;
- evento sobrenatural;
- dano;
- invasão;
- encerramento antecipado do turno;
- morte em casos mais extremos.

Não é necessário que toda anomalia mate o jogador.

Algumas podem apenas atrapalhar o negócio.

---

### 7.4 Escalonamento

As anomalias começam simples e ficam progressivamente mais complexas.

**Primeiras noites:**

> perceber uma coisa estranha.

**Noites intermediárias:**

> lembrar regras.

**Noites avançadas:**

> lidar com múltiplas anomalias simultaneamente.

---

# 8. Pilar 6 — Descoberta do Horror

A história deve ser descoberta pelo jogador, não explicada imediatamente.

O jogo começa sem revelar que existe algo sobrenatural.

## Progressão narrativa

### Início

> "Você está desempregado."

### Primeiro emprego

> "Venda hot dogs."

### Progressão

> "Parabéns pelo seu trabalho."

### Trailer

> "Você merece uma promoção."

### Ligação do chefe

> "Preciso que você cubra o turno da noite."

### Primeira noite

Nada muito assustador.

Apenas pequenas inconsistências.

### Noites seguintes

O jogador percebe que há regras.

### Progressão avançada

O jogador começa a questionar:

> **Por que esse lugar é assim?**

---

# 9. Pilar 7 — O Chefe

O chefe é um elemento narrativo recorrente.

No começo ele representa:

> trabalho, estabilidade e progresso.

Com o tempo ele passa a representar:

> mistério.

## Evolução da relação

### Primeiro estágio

> "Good job today!"

### Segundo estágio

> "You're doing great."

### Terceiro estágio

> "Can you cover the night shift?"

### Quarto estágio

> "There's something you should know..."

### Quinto estágio

> "Whatever you do, don't..."

O chefe não precisa explicar tudo.

Ele deve criar perguntas.

---

# 10. Pilar 8 — O Trailer

O Food Trailer é o principal marco de progressão do jogo.

Ele representa simultaneamente:

**sucesso econômico + início do horror.**

Antes dele:

> o jogador está construindo uma carreira.

Depois dele:

> o jogador começa a trabalhar à noite.

Isso torna o trailer uma peça importante de narrativa.

---

# 11. Upgrades

Os upgrades devem ter utilidade real.

## Equipamentos

Exemplos:

### Grill

- velocidade de cozimento;
- capacidade;
- quantidade simultânea.

### Cooler

- capacidade de ingredientes;
- conservação;
- armazenamento.

### Counter

- quantidade de pedidos simultâneos.

### Lighting

Durante o dia:

- visibilidade;
- atração de clientes.

Durante a noite:

- iluminação de áreas;
- auxílio na identificação de anomalias.

### Camera

Durante o dia:

- segurança.

Durante a noite:

- observar áreas sem sair do trailer.

### Door / Security

Durante o dia:

- proteção do equipamento.

Durante a noite:

- proteção contra determinadas anomalias.

Isso cria uma característica importante:

> **Upgrades comprados para o negócio também podem se tornar ferramentas de sobrevivência.**

---

# 12. Economia

A economia deve ser simples.

## Recursos principais

### Money

Usado para:

- ingredientes;
- upgrades;
- veículos;
- expansão.

### XP

Usado para:

- progressão;
- desbloqueios.

### Stock

Representa os recursos físicos do negócio.

---

## Decisões econômicas

O jogador deve eventualmente pensar:

> "Compro mais ingredientes ou guardo dinheiro para meu próximo upgrade?"

Isso cria uma progressão natural de gerenciamento.

---

# 13. Eventos de Demanda

Eventos podem alterar temporariamente o comportamento da cidade.

Exemplos:

### ⚽ Game Night

Mais clientes.

### 🎤 Concert

Grande pico de demanda.

### 🌧️ Rain

Menos clientes normais.

### 🎃 Halloween

Receitas especiais.

### 🌙 Special Night

Maior quantidade de anomalias.

Esses eventos podem gerar noites diferentes sem precisar criar mapas completamente novos.

---

# 14. Clientes

Os clientes são parte importante do gameplay.

Cada cliente pode ter:

- pedido;
- dinheiro;
- preferência;
- comportamento;
- chance de ser anomalia.

## Clientes normais

Devem parecer repetitivos o suficiente para estabelecer padrões.

Isso é importante porque o terror depende de o jogador aprender:

> **"É assim que um cliente normal se comporta."**

Quando algo quebra esse padrão, o jogador percebe.

---

# 15. Estrutura de uma Sessão

O loop principal:

```text
ARRUMAR EMPREGO
       ↓
TRABALHAR
       ↓
VENDER HOT DOGS
       ↓
GANHAR DINHEIRO
       ↓
COMPRAR UPGRADES
       ↓
DESBLOQUEAR NOVAS RECEITAS
       ↓
MELHORAR O CARRINHO
       ↓
DESBLOQUEAR TRAILER
       ↓
TRABALHAR À NOITE
       ↓
PERCEBER ANOMALIAS
       ↓
SOBREVIVER
       ↓
GANHAR MAIS
       ↓
DESBLOQUEAR NOVO CONTEÚDO
```

---

# 16. Estrutura de uma Noite

Uma noite pode seguir:

```text
18:00
↓
Abrir trailer
↓
Clientes normais
↓
Pedidos
↓
Primeiros sinais
↓
Anomalias
↓
Aumento de dificuldade
↓
Últimos clientes
↓
Encerramento
↓
Pagamento
↓
XP
↓
Upgrade / Progressão
```

A noite deve começar quase como um turno normal e terminar muito mais tensa.

---

# 17. Filosofia de Horror

O jogo **não deve depender de jumpscare**.

A principal fonte de tensão deve ser:

> **"Eu sei que existe algo errado, mas não sei exatamente o quê."**

O jogador deve desenvolver hábitos:

- olhar para clientes;
- observar o ambiente;
- lembrar regras;
- verificar horários;
- conferir ingredientes;
- ouvir sons;
- verificar o trailer.

O horror vem da quebra desses padrões.

---

# 18. O que NÃO deve ser o foco

Para preservar a identidade do jogo, evitar transformar o projeto em:

### ❌ Doors clone

Não queremos:

> entrar em salas → procurar item → fugir de monstro.

### ❌ Simulator genérico

Não queremos:

> clicar infinitamente → número sobe.

### ❌ Horror puro

Não queremos que o jogador passe o jogo inteiro apenas tentando sobreviver.

### ❌ Tycoon passivo

O jogador deve estar fisicamente envolvido no trabalho.

O jogador precisa **fazer hot dogs**.

---

# 19. MVP

O primeiro lançamento jogável pode ser extremamente pequeno.

## Conteúdo

### Mapa

- uma pequena região;
- mercado;
- rua;
- trailer;
- alguns prédios;
- área de estacionamento.

### Progressão

- desempregado;
- primeiro emprego;
- carrinho;
- algumas receitas;
- trailer.

### Receitas

- Classic;
- Cheese;
- Bacon.

### Equipamentos

- grill;
- cooler;
- counter.

### Clientes

- 4–6 tipos básicos.

### Horror

3–5 anomalias.

Exemplo:

1. cliente sem rosto;
2. cliente duplicado;
3. cliente proibido;
4. relógio alterado;
5. objeto deslocado.

### Ciclo

- dia;
- noite;
- turno;
- pagamento.

Isso já seria suficiente para validar o conceito.

---

# 20. Conteúdo Pós-Lançamento

Depois do MVP, o jogo pode crescer horizontalmente.

## Novas receitas

- Chili Dog;
- Korean Dog;
- Mexican Dog;
- Mega Dog;
- Halloween Dog;
- receitas raras.

## Novos equipamentos

- grills;
- freezers;
- câmeras;
- iluminação;
- ferramentas de segurança.

## Novos veículos

- carts;
- trailers;
- food trucks.

## Novas áreas

- parque;
- posto;
- praia;
- centro;
- estacionamento;
- área industrial.

## Novas anomalias

Cada atualização pode introduzir novas regras e comportamentos.

## Novos eventos

- Halloween;
- Christmas;
- festival;
- concert;
- sports night.

---

# 21. Multiplayer

O jogo pode funcionar inicialmente como experiência individual ou com suporte cooperativo futuro.

### Possível co-op

Cada jogador poderia assumir funções:

- cozinheiro;
- caixa;
- estoque;
- observador.

Isso permitiria situações emergentes:

> "Não vende praquele cara!"

> "Qual deles?"

> "O da camisa vermelha!"

> "Tem três!"

O multiplayer pode aumentar bastante o potencial social do jogo, mas **não deve ser requisito do MVP**.

---

# 22. Identidade do Jogo

A identidade de **Sell Hotdogs!** deve ser:

> **Cute / Casual / Satisfying / Progression / Mystery / Horror**

A apresentação inicial deve ser propositalmente inocente.

O jogador deve entrar pensando:

> "Vou fazer dinheiro vendendo hot dogs."

Depois:

> "Por que esse cliente está agindo assim?"

E eventualmente:

> **"Eu preciso terminar esse turno."**

---

# 23. Core Pillars

Os pilares definitivos do projeto são:

## PILAR 1 — VENDER
Preparar e vender hot dogs.

### Subpilares
- receitas
- clientes
- pedidos
- preparação
- atendimento
- eficiência

---

## PILAR 2 — PROGREDIR
Construir uma carreira e um negócio.

### Subpilares
- dinheiro
- XP
- níveis
- upgrades
- equipamentos
- receitas
- carrinhos
- trailer

---

## PILAR 3 — GERENCIAR
Tomar decisões sobre o negócio.

### Subpilares
- estoque
- ingredientes
- compras
- capacidade
- velocidade
- economia
- demanda

---

## PILAR 4 — OBSERVAR
Identificar quando algo está errado.

### Subpilares
- padrões
- comportamento dos NPCs
- ambiente
- regras
- memória
- percepção

---

## PILAR 5 — SOBREVIVER
Lidar com as anomalias.

### Subpilares
- regras
- decisões
- consequências
- risco
- segurança
- escalonamento

---

## PILAR 6 — DESCOBRIR
Entender por que o turno da noite é diferente.

### Subpilares
- chefe
- diálogos
- acontecimentos
- pistas
- mistério
- lore

---

# 24. North Star

O jogo deve sempre preservar esta sensação:

> **"Estou construindo uma vida melhor vendendo hot dogs... mas alguma coisa está muito errada aqui."**

O jogador começa querendo **ganhar dinheiro**.

Depois passa a querer **comprar o trailer**.

Depois passa a querer **entender as anomalias**.

E, finalmente:

> **quer terminar o turno e descobrir o que realmente está acontecendo.**
