# Walt — áudios que faltam gravar (2026-10-23)

Só o que **ainda precisa gravar**: **66 arquivos**. Fora daqui: o que já está gravado, as falas MORTAS (sem dia),
as SUBSTITUÍDAS, a noite repetida/perdida (nunca tocam) e as aberturas com lore (DEC-362, texto ainda com o narrative-writer).
Roteiro completo: `tools/voice/elevenlabs_script.md`.

**Como usar**
- Cole o campo **ElevenLabs** (com as tags). Nome do arquivo = **id** + `.mp3`, na pasta indicada em `Assets/new_voice/`.
- Os ids `v_…` saem da legenda (mesmo cálculo da pipeline). Ids `sc_…` são do final; eu ligo na importação.
- Telefone: tudo, menos `dia_11` final presencial/Segundo Café e `noite_reacoes` (essas **sem filtro**). Eu aplico o filtro.
- Duração: ligação da noite ≤ 12 s por fala.

---

## `dia_01/` — Noite 1 — tutorial e lição de upgrade (6 AM) · 8

1. **`v_2868aaab59.mp3`** · lição de upgrade, lembrete (substitui v_8df981736c)
   - Legenda: Six A.M. Shift's over. Gear Stand, in the back. Find something useful.
   - ElevenLabs: `[pleased] Six A.M. Shift's over, Rookie. [whisper] Gear Stand. In the back. Find something useful.`

2. **`v_37baf1252c.mp3`** · dica, só sem tutorial (substitui v_4d28b6c67f)
   - Legenda: Hot dog's ready. Hand it to the customer.
   - ElevenLabs: `[calm] That one's done. [whisper] Hand it to the customer.`

3. **`v_0fa0be155e.mp3`** · o que os outros ouvem durante o tutorial
   - Legenda: Got a rookie today!
   - ElevenLabs: `[pleased] Got a new rookie today. [chuckles]`

4. **`v_5874c73b55.mp3`** · o que os outros ouvem durante o tutorial
   - Legenda: I'm walking them through it.
   - ElevenLabs: `[calm] I'm walking them through it.`

5. **`v_8d74b17c53.mp3`** · 6 AM, fim do turno
   - Legenda: Shift's over, Rookie. Nice work.
   - ElevenLabs: `[warm] Shift's over, Rookie. Nice work.`

6. **`v_d568870e1a.mp3`** · 6 AM
   - Legenda: Before tonight, get some gear.
   - ElevenLabs: `[serious] Before tonight... [whisper] get yourself some gear.`

7. **`v_df97670c5b.mp3`** · 6 AM
   - Legenda: Gear Stand, in the back.
   - ElevenLabs: `[calm] Gear Stand's in the back.`

8. **`v_7c27354d0f.mp3`** · 6 AM
   - Legenda: Short on cash? I've got you.
   - ElevenLabs: `[generous] Short on cash? [chuckles] I've got you.`

## `dia_02/` — Ligação da Noite 1 + café · 8

> Ordem na ligação: abertura, disjuntor, sair só pro disjuntor, sem rosto, janela. São 5 falas: conferir o limite de 45 s no Play.

9. **`v_6ea4e48840.mp3`** · N1, abertura
   - Legenda: Evening, Rookie. Some customers look off.
   - ElevenLabs: `[calm, deep] Evening, Rookie. [pause] Some of tonight's customers... look a little off. [chuckles softly] [whisper] Nothing to worry about.`

10. **`v_4d53dce0bd.mp3`** · N1, disjuntor (DEC-367)
   - Legenda: Power trips? Breaker's outside. Hold it till the lights come back.
   - ElevenLabs: `[calm] Old wiring. Power trips now and then. [pause] Breaker's out back. [whisper] Go out. Hold it till the lights come back.`

11. **`v_95a80efa7d.mp3`** · N1 (substitui v_8c48d35c08)
   - Legenda: Only go out for the breaker. Then come right back in.
   - ElevenLabs: `[easy] And Rookie... [pause] outside's for the breaker. Nothing else. [whisper] Do your job. Come right back in.`

12. **`v_a7b49de52c.mp3`** · N1, sem rosto (substitui v_0b0655a682)
   - Legenda: No face? Blank ticket? Don't cook it. He leaves on his own.
   - ElevenLabs: `[calm] Some folks come in with no face. Shy, I guess. [pause] Ticket comes up blank. [whisper] Don't cook it. He'll leave on his own.`

13. **`v_b0447c326e.mp3`** · N1, janela com custo (DEC-365)
   - Legenda: Something wrong at the window? Shut it. They'll go. So does the money.
   - ElevenLabs: `[calm] Something looks wrong at the window? [whisper] Shut it. They'll go. [chuckles softly] Heh. So does their money, mind you.`

14. **`v_7a552ce2a2.mp3`** · café (1ª vez que a sanidade cai a 50)
   - Legenda: You sound tired, Rookie...
   - ElevenLabs: `[concerned, slow] You sound tired, Rookie...`

15. **`v_52d1defbaf.mp3`** · café
   - Legenda: Have some coffee.
   - ElevenLabs: `[gentle] Go have some coffee.`

16. **`v_71c594aea2.mp3`** · café
   - Legenda: It'll keep your head on straight.
   - ElevenLabs: `[chuckles softly] It'll keep your head on straight. [pause] [whisper] You'll want that tonight.`

## `dia_03/` — Ligação da Noite 2 · 2

17. **`v_21cf2e63bb.mp3`** · N2, o que treme (substitui v_3c75317b9b)
   - Legenda: Shaky one's just hungry. Plain bun and sausage. Nothing on it.
   - ElevenLabs: `[warm] If one's shaking, he's just hungry. Cold out there. [pause] Bun, sausage. [whisper] Nothing on it.`

18. **`v_8bcaa6bb04.mp3`** · N2, batida na porta
   - Legenda: Also, if someone knocks at the door... it's not me, lock it.
   - ElevenLabs: `[pause, low] And if somebody knocks on the back door... [very calm] it's not me. I've got a key. [whisper] Lock it.`

## `dia_04/` — Ligação da Noite 3 · 2

19. **`v_6c2f4fcbda.mp3`** · N3, apagão (substitui v_05009b919e)
   - Legenda: Lights out? Breaker's outside. Hold it till they come back.
   - ElevenLabs: `[calm] Lights might go out again tonight. Storm season. [pause] Breaker's outside. [whisper] Hold it. Till they come back.`

20. **`v_49de7dc12d.mp3`** · N3, as cópias
   - Legenda: Rookie, it seems that something weird is happening today... if you see someone showing up twice don't serve him.
   - ElevenLabs: `[amused] Funny thing about tonight, Rookie... [pause] same customer might show up twice. [chuckles] Twins, I guess. [cold] The second one? [whisper] Don't serve him.`

## `dia_05/` — Ligação da Noite 4 · 2

21. **`v_5495df0c7e.mp3`** · N4, pescoço virado
   - Legenda: Some customers have a neck problem, so if you see one, don't stare him, just give the food to him and your head down
   - ElevenLabs: `[calm] One of the regulars has a neck thing. Head turned all the way around. [chuckles] She didn't break it. She's just tired and looked back. [low] [whisper] Don't stare. Hand her the food with your head down.`

22. **`v_84845b02f9.mp3`** · N4, vulto do outro lado da rua
   - Legenda: Someone across the street? Don't look.
   - ElevenLabs: `[quiet] Somebody standing across the street? [pause] [whisper] Don't look.`

## `dia_06/` — Ligação da Noite 5 · 2

23. **`v_6e89e13998.mp3`** · N5, olhos brancos
   - Legenda: If you see someone with white eyes, TURN OFF THE LIGHTS, and give them the food, they are light sensitive
   - ElevenLabs: `[gentle] Customer with white eyes? [chuckles] Light sensitive, poor thing. [confident] Turn off the lights first. [whisper] Then give them the food.`

24. **`v_8b2fd70edd.mp3`** · N5, Raincoat Lady
   - Legenda: Hey Rookie, if you see the raincoat lady, I love her, serve her and be nice to her.
   - ElevenLabs: `[warm, fond] And Rookie... the lady in the raincoat. [pause] [whisper] I love that woman. [firm] Serve her. And be nice to her.`

## `dia_07/` — Ligação da Noite 6 · 1

25. **`v_38eb8400bb.mp3`** · N6, cabeção + névoa vermelha
   - Legenda: If you see the customer with a big head, give them the food fast, they have a headache. And also, a red fog might show up, so close the window if it happens.
   - ElevenLabs: `[casual] Guy with a head way too big for him? [chuckles] Headache. Don't keep him waiting. Serve him fast. [pause, lower] [whisper] And if a red fog rolls in... shut the window. Keep it shut till it's gone.`

## `dia_08/` — Ligação da Noite 7 · 3

26. **`v_80950fa0b0.mp3`** · N7, barulho no chão (substitui v_3c84ea3eda e v_aaaf538e6f)
   - Legenda: Scratching under the floor? Up on the counter till it passes.
   - ElevenLabs: `[calm] We got rats under the floorboards. Big ones. [chuckles softly] Heh. You hear scratching... [whisper] get off the floor. Up on the counter till it passes.`

27. **`v_fda708ff1e.mp3`** · N7, o que flutua (DEC-367)
   - Legenda: Feet not touching the floor? Don't serve yet. Wait for the thud.
   - ElevenLabs: `[calm] Some fellas come in light on their feet. Real light. [chuckles softly] Heh. Don't serve him floating. [whisper] Wait for the thud.`

28. **`v_aa5a08d1a0.mp3`** · N7, repetição
   - Legenda: Scratching? Up on the counter.
   - ElevenLabs: `[calm] Scratching? [whisper] Up on the counter.`

## `dia_09/` — Ligação da Noite 8 · 4

29. **`v_70a8507099.mp3`** · N8, carro comprido
   - Legenda: A long car at the drive-thru?
   - ElevenLabs: `[slow] [whisper] A car at the drive-thru... that just keeps going? [pause]`

30. **`v_0b669707f9.mp3`** · N8
   - Legenda: Shut the window. Keep it shut.
   - ElevenLabs: `[very calm] Shut the window. [whisper] Keep it shut. [chuckles] He'll get the hint.`

31. **`v_0db7046e74.mp3`** · N8, repetição
   - Legenda: Long car? Shut it. Keep it shut.
   - ElevenLabs: `[calm] Long car? Shut the window. [whisper] Keep it shut.`

32. **`v_db57b24aa1.mp3`** · N8, head banger, 2ª regra (DEC-366)
   - Legenda: Banging his head on the glass? Window won't stop him. Shop light off.
   - ElevenLabs: `[calm] Fella might knock his head on the glass tonight. [chuckles softly] Heh. Thick skull, that one. [pause] Shutting the window won't send him off. [low] [whisper] Shop light off. Then he goes.`

## `dia_10/` — Ligação da Noite 9 · 2

33. **`v_951af0016c.mp3`** · N9, passos no telhado
   - Legenda: If you hear steps at the roof, it's probably a cat. Don't look up.
   - ElevenLabs: `[casual] Footsteps on the roof? [chuckles] Cat. Big cat. [low, firm] [whisper] Whatever you do, don't look up.`

34. **`v_10addfece9.mp3`** · N9, o que encara (DEC-367)
   - Legenda: Never blinks? Serve him like normal. Just don't stare back.
   - ElevenLabs: `[calm] One regular, he doesn't blink. Dry eyes, I figure. [pause] Serve him like anyone else. [whisper] Just don't stare back.`

## `dia_11/` — Noite 10 (a última) + final · 18

35. **`v_140f750fc0.mp3`** · N10, abertura
   - Legenda: Last night, Rookie.
   - ElevenLabs: `[warm, slow] Last night, Rookie. [pause]`

36. **`v_69a8ddce3a.mp3`** · N10, postes apagando (substitui v_37eb690baf)
   - Legenda: Lamps going out outside? Shop light off.
   - ElevenLabs: `[calm] If the street lamps start going out... [pause] power company, heh. [whisper] Shop light off.`

37. **`v_a5a48fc8ed.mp3`** · N10 (texto novo, legenda igual)
   - Legenda: Keep it off till they're back.
   - ElevenLabs: `[low] And keep it off. [whisper] Till the lamps are back.`

38. **`v_63bc27633c.mp3`** · N10, o das câmeras (DEC-367)
   - Legenda: Looks normal? Check the cameras. Wrong on camera, don't cook it.
   - ElevenLabs: `[calm] Cameras are old. Sometimes they show a fella... different. [chuckles softly] Heh. Bad lens, probably. [pause] Check them. [whisper] Wrong on camera? Don't cook his order.`

39. **`v_7caee4e9eb.mp3`** · N10, repetição
   - Legenda: Lamps out? Shop light off.
   - ElevenLabs: `[calm] Lamps out? [whisper] Shop light off.`

40. **`v_6d549845ae.mp3`** · rádio N10, grita, sem whisper (substitui v_d9a7a5ee99 e v_86b4351c71)
   - Legenda: The lamps are going out! Lights off in there, NOW!
   - ElevenLabs: `[urgent, shouting] Rookie! The lamps are going out! Lights off in there! NOW!`

41. **`v_f271c54c14.mp3`** · final, presencial
   - Legenda: Ten nights. You kept the light on.
   - ElevenLabs: `[quiet, impressed] Ten nights. [pause] You kept the light on.`

42. **`v_2fec422da1.mp3`** · final (substitui v_b85c836266, DEC-369)
   - Legenda: I watched every one. From across the street. Best seat in town.
   - ElevenLabs: `[warm, slow] I watched every one, Rookie. [pause] From across the street. [chuckles softly] Best seat in town.`

43. **`v_0520e8b100.mp3`** · final
   - Legenda: I worked that corner forty years. Since '79.
   - ElevenLabs: `[nostalgic, slow] I worked that corner forty years. [pause] Since nineteen seventy-nine.`

44. **`v_83d0e946e7.mp3`** · final
   - Legenda: The corner's a crossing, Rookie. At night, the late crowd comes through.
   - ElevenLabs: `[low, confiding] This corner's a crossing, Rookie. [pause] [whisper] At night... the late crowd comes through.`

45. **`v_a407bfc9ae.mp3`** · final
   - Legenda: They like the light. And the smell of food. Heh.
   - ElevenLabs: `[amused] They like the light. [pause] And the smell of food. [chuckles] Heh.`

46. **`v_a2fdcbe997.mp3`** · final
   - Legenda: Keep the rules, and they stay polite. That's the deal.
   - ElevenLabs: `[confident] Keep the rules, and they stay polite. [pause] [whisper] That's the deal.`

47. **`v_2bd5e253a0.mp3`** · final
   - Legenda: Somebody has to keep the light on. Every night.
   - ElevenLabs: `[grave] Somebody has to keep the light on. [pause] [whisper] Every night.`

48. **`v_5e55db4a7b.mp3`** · final
   - Legenda: My knees are done. But you... you notice things.
   - ElevenLabs: `[tired, warm] My knees are done. [pause] But you... [leaning in] [whisper] you notice things.`

49. **`v_f3e7afb49b.mp3`** · final
   - Legenda: The night shift is yours. If you want it.
   - ElevenLabs: `[deliberate] The night shift is yours. [pause] [whisper] If you want it.`

50. **`sc_forty_years.mp3`** · Segundo Café, voz walt_dark (mais lento e grave)
   - Legenda: Forty years, Rookie. Forty years of nights.
   - ElevenLabs: `[slow, low, the warmth gone] Forty years, Rookie. [pause] Forty years... of nights.`

51. **`sc_mornings.mp3`** · Segundo Café, walt_dark, ao jogar o jogador na rua
   - Legenda: Now I get the mornings.
   - ElevenLabs: `[low, satisfied, almost tender] [whisper] Now I get the mornings.`

52. **`sc_other_side.mp3`** · Segundo Café, voz do rádio (o último Rookie), no preto
   - Legenda: ...welcome to the other side, Rookie...
   - ElevenLabs: `[weak, distant, broken radio] ...welcome to the other side... Rookie...`

## `qualquer_dia/` — Qualquer noite · 4

53. **`v_50b31756b4.mp3`** · fim da run, tela final (substitui v_d91e854ce1)
   - Legenda: That's it, Rookie.
   - ElevenLabs: `[calm, low] Well. [pause] That's it, Rookie. [chuckles softly] Heh.`

54. **`v_d30128cf6d.mp3`** · fim da run
   - Legenda: No more nights for you.
   - ElevenLabs: `[flat] [whisper] No more nights for you.`

55. **`v_fe4055ecce.mp3`** · fim da run
   - Legenda: Go home. You did well.
   - ElevenLabs: `[gentle] Go home. [pause] You did well.`

56. **`v_300c009f3f.mp3`** · reclamação da Raincoat Lady, quando despachada pela janela (DEC-365)
   - Legenda: You shut her out, Rookie. You might regret that.
   - ElevenLabs: `[disappointed, calm] You shut the window on her, Rookie. [pause] She just wanted a dog. [low] [whisper] You might regret that.`

## `noite_reacoes/` — Walt sem telefone (DEC-372) · **SEM FILTRO DE TELEFONE** · 10

> Voz perto, íntima, crua. Tocam no meio da noite sem o telefone tocar. Só a principal; as alternativas ficam no roteiro completo.

57. **`v_d3436271a8.mp3`** · R1 · disjuntor religado
   - Legenda: Lights back. Steady hands.
   - ElevenLabs: `[low, close] Lights back. [pause] Steady hands. [chuckles softly] Heh.`

58. **`v_034c47249a.mp3`** · R2 · um jogador sai para a rua à noite
   - Legenda: Chilly out there, isn't it?
   - ElevenLabs: `[low, amused] Chilly out there, [pause] isn't it?`

59. **`v_9807a75007.mp3`** · R3 · anomalia despachada pela janela (não a Raincoat Lady)
   - Legenda: That one cost you. Worth it.
   - ElevenLabs: `[low] That one cost you. [pause] [chuckles softly] Worth it.`

60. **`v_cf41a58820.mp3`** · R4 · anomalia atendida certo
   - Legenda: I saw that. Well done.
   - ElevenLabs: `[close, intimate] I saw that. [pause] [low] Well done.`

61. **`v_77c314ae3a.mp3`** · R5 · susto por regra errada
   - Legenda: Heh. Rules matter, kid.
   - ElevenLabs: `[chuckles softly] Heh. [pause] [whisper] Rules matter, kid.`

62. **`v_4f0ab7c7f3.mp3`** · R6 · chega perto do Walt dark no estacionamento
   - Legenda: Best seat in town.
   - ElevenLabs: `[close, intimate] [whisper] Best seat [pause] in town.`

63. **`v_7d54e260ce.mp3`** · R7 · 1º café na máquina
   - Legenda: Good coffee. My recipe.
   - ElevenLabs: `[low, warm] Good coffee. [pause] My recipe.`

64. **`v_bbb400f136.mp3`** · R8 · 1ª leitura do papel de dicas
   - Legenda: I wrote those. Read slowly.
   - ElevenLabs: `[low] I wrote those. [pause] [whisper] Read slowly.`

65. **`v_76e48bdb76.mp3`** · R9 · porta dos fundos trancada a tempo
   - Legenda: Just in time. Heh.
   - ElevenLabs: `[low, close] Just in time. [pause] [chuckles softly] Heh.`

66. **`v_90f870321d.mp3`** · R10 · luz apagada e o head banger vai embora
   - Legenda: Dark works too. Clever.
   - ElevenLabs: `[low, amused] Dark works too. [pause] Clever.`
