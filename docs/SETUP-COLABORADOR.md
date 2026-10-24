Status: Rascunho

# Setup do colaborador

Passo a passo para quem entra no projeto com o próprio Claude Code. Regras de convivência: `CLAUDE.md`, seção
"Trabalho em dupla".

## 1. Uma vez

1. Fork de `github.com/victorcarmo2003/ModuxTemplate` na sua conta do GitHub.
2. Instale **Git LFS** e rode `git lfs install` (os `.png`, `.fbx`, `.blend` vêm por LFS).
3. Clone a sua fork e ligue o repo do dono como `upstream`:

   ```bash
   git clone https://github.com/<seu-usuario>/ModuxTemplate "Sell Hotdogs"
   cd "Sell Hotdogs"
   git remote add upstream https://github.com/victorcarmo2003/ModuxTemplate
   git config user.name "<seu nome>"
   ```

4. Ferramentas e pacotes: siga o `README.md` da raiz (rokit, wally, `rogen build` → `modux generate` → `rojo serve`).
5. Peça ao Victor: acesso ao grupo/experiência no Roblox (Team Create ou cópia do place) e, se for subir asset, permissão
   para criar a sua chave Open Cloud. A chave fica só na variável de ambiente `ROBLOX_API_KEY`.
6. Abra o Claude Code na pasta. Ele lê `CLAUDE.md`, `.claude/agents/` e `.claude/skills/` sozinho. Diga a ele na primeira
   sessão: "eu sou o colaborador".

## 2. Todo dia

```bash
git fetch upstream
git checkout main
git merge --ff-only upstream/main
git push origin main
git checkout -b c/feat/<assunto>
```

Trabalhe, commite, e antes do PR: `git fetch upstream && git rebase upstream/main`, depois `git push origin <branch>` e abra
o PR para `victorcarmo2003/ModuxTemplate:main`.

## 3. Lembretes

- IDs novos seus começam em **5001** (`TASK-5001`, `Q-5001`, `AST-5001`...). DEC só o Victor.
- Marque a TASK no `docs/tasks/board.md` antes de começar.
- Não rode `rojo serve` no mesmo place de Team Create que o Victor.
- Registro do dia: `docs/tasks/playtest-YYYY-MM-DD-<seu-nome>.md`.
