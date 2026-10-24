"""Window for recording the voice lines (owner 2026-10-22: "tem como fazer uma interface?"). Same files and rules as
record.py (whose helpers it uses): a kept take replaces Assets/audio/voice/<speaker>/<key>.ogg, the raw take goes to
recordings/<key>.wav, assets.json gets recorded=true and loses its assetId (upload.py sends it again).

  .venv/Scripts/python record_gui.py

Keys: SPACE record / stop, P with effect, O without effect, L current voice, 1 / 2 / 3 effect full / phone / none,
ENTER keep and next, S skip, B back, E edit the text. Then: python upload.py, python build_content.py.

Edit the text (owner 2026-10-23: "talvez eu altere algumas coisas na fala"): the line is rewritten as it will be said,
one line per box line (two lines = a split, empty = removed, e.g. merged into the line before). edits.json keeps
old -> new with the sources; the takes are saved under the key of the NEW text (collect_lines.key_of), so once the Luau
sources say the new text (Claude applies edits.json) and collect_lines runs again, the recorded audio matches it.
"""
import json, os, time, types
import tkinter as tk
from tkinter import ttk
import numpy as np, soundfile as sf, sounddevice as sd
import collect_lines as C
import generate as G
import record as R

EDITS_PATH = os.path.join(G.HERE, "edits.json")
TYPING = ("Text", "Entry", "TEntry")  # widget classes where the shortcuts stay off

FILTERS = {
    "Sem voz enviada": dict(all=False, redo=False, source=None),
    "Tutorial (Steps)": dict(all=True, redo=True, source="Steps"),
    "Ligações (BossCalls)": dict(all=True, redo=True, source="BossCalls"),
    "Todas": dict(all=True, redo=True, source=None),
}
EFFECTS = {"full": "Walt completo", "phone": "Só telefone", "none": "Sem efeito"}
INK, PAPER, MUSTARD, RED, GREEN, GREY = "#1d1b19", "#f4ecd8", "#e8b23a", "#d2463c", "#4f9a5b", "#8a8378"


class App:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.meta = R.meta_load()
        self.keys: list[str] = []
        self.index = 0
        self.frames: list[np.ndarray] = []
        self.stream = None
        self.started = 0.0
        self.take = None  # trimmed raw take (np array) of the current line, not kept yet
        self.take_ogg = os.path.join(G.HERE, "_take.ogg")
        self.take_wav = os.path.join(G.HERE, "_take.wav")
        self.fx = tk.StringVar(value="full")
        self.filter = tk.StringVar(value="Sem voz enviada")
        self.show_removed = tk.BooleanVar(value=False)  # removed lines (edit to nothing) hidden unless asked
        # old key -> { speaker, sources, old, new: [texts], note }; new key -> old key (lines made by an edit)
        self.edits: dict = json.load(open(EDITS_PATH, encoding="utf-8")) if os.path.exists(EDITS_PATH) else {}
        self.origin: dict[str, str] = {}
        # lines the game never says (trailer / Mart tutorial steps, trailer text of the restaurant night calls;
        # owner 2026-10-23 "dá uma limpada"): never listed
        unused = os.path.join(G.HERE, "unused.json")
        self.unused: set[str] = set(json.load(open(unused, encoding="utf-8"))) if os.path.exists(unused) else set()
        os.makedirs(R.RAW, exist_ok=True)
        self.build()
        self.load_queue()
        self.tick()

    # UI ------------------------------------------------------------------------------------------------------------
    def build(self):
        r = self.root
        r.title("Gravar falas - Sell Hotdogs")
        r.geometry("1100x640")
        r.configure(bg=INK)
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("TCombobox", fieldbackground=PAPER)

        left = tk.Frame(r, bg=INK)
        left.pack(side="left", fill="y", padx=(12, 6), pady=12)
        cb = ttk.Combobox(left, textvariable=self.filter, values=list(FILTERS), state="readonly", width=30)
        cb.pack(fill="x")
        cb.bind("<<ComboboxSelected>>", lambda _e: self.load_queue())
        tk.Checkbutton(left, text="Mostrar removidas", variable=self.show_removed, command=self.load_queue, bg=INK,
                       fg=PAPER, selectcolor="#2a2724", activebackground=INK, activeforeground=MUSTARD, takefocus=0,
                       font=("Segoe UI", 9)).pack(anchor="w", pady=(4, 0))
        self.listbox = tk.Listbox(left, width=44, bg="#2a2724", fg=PAPER, selectbackground=MUSTARD, selectforeground=INK,
                                  font=("Segoe UI", 10), activestyle="none", highlightthickness=0, borderwidth=0)
        self.listbox.pack(fill="y", expand=True, pady=(8, 0))
        self.listbox.bind("<<ListboxSelect>>", self.on_pick)
        self.count = tk.Label(left, bg=INK, fg=GREY, font=("Segoe UI", 9), anchor="w")
        self.count.pack(fill="x", pady=(6, 0))

        main = tk.Frame(r, bg=INK)
        main.pack(side="left", fill="both", expand=True, padx=(6, 12), pady=12)
        self.info = tk.Label(main, bg=INK, fg=GREY, font=("Segoe UI", 10), anchor="w", justify="left")
        self.info.pack(fill="x")
        card = tk.Frame(main, bg=PAPER)
        card.pack(fill="both", expand=True, pady=10)
        self.text = tk.Label(card, bg=PAPER, fg=INK, font=("Georgia", 28, "bold"), wraplength=560, justify="center")
        self.text.pack(expand=True, padx=24, pady=24)

        meter = tk.Frame(main, bg=INK)
        meter.pack(fill="x")
        self.canvas = tk.Canvas(meter, height=22, bg="#2a2724", highlightthickness=0)
        self.canvas.pack(side="left", fill="x", expand=True)
        self.timer = tk.Label(meter, bg=INK, fg=PAPER, font=("Consolas", 14), width=8)
        self.timer.pack(side="left", padx=(8, 0))

        row1 = tk.Frame(main, bg=INK)
        row1.pack(fill="x", pady=(10, 4))
        self.rec_btn = self.button(row1, "●  Gravar  [Espaço]", self.toggle, RED, width=22)
        self.button(row1, "▶  Com efeito  [P]", self.play_fx)
        self.button(row1, "▶  Sem efeito  [O]", self.play_raw)
        self.button(row1, "▶  Voz atual  [L]", self.play_current)
        self.button(row1, "■  Parar som", sd.stop, GREY)

        row2 = tk.Frame(main, bg=INK)
        row2.pack(fill="x", pady=4)
        tk.Label(row2, text="Efeito:", bg=INK, fg=PAPER, font=("Segoe UI", 10)).pack(side="left")
        for n, (mode, label) in enumerate(EFFECTS.items(), 1):
            tk.Radiobutton(row2, text=f"{label} [{n}]", value=mode, variable=self.fx, command=self.refx, bg=INK, fg=PAPER,
                           selectcolor="#2a2724", activebackground=INK, activeforeground=MUSTARD,
                           font=("Segoe UI", 10)).pack(side="left", padx=6)

        row3 = tk.Frame(main, bg=INK)
        row3.pack(fill="x", pady=(4, 0))
        self.keep_btn = self.button(row3, "✔  Guardar e próxima  [Enter]", self.keep, GREEN, width=28)
        self.button(row3, "⏮  Voltar  [B]", lambda: self.go(-1), GREY)
        self.button(row3, "⏭  Pular  [S]", lambda: self.go(1), GREY)
        self.button(row3, "✎  Editar texto  [E]", self.edit, PAPER)

        self.status = tk.Label(main, bg=INK, fg=MUSTARD, font=("Segoe UI", 10), anchor="w")
        self.status.pack(fill="x", pady=(10, 0))

        keys = {"<space>": self.toggle, "p": self.play_fx, "o": self.play_raw, "l": self.play_current,
                "<Return>": self.keep, "s": lambda: self.go(1), "b": lambda: self.go(-1),
                "1": lambda: self.set_fx("full"), "2": lambda: self.set_fx("phone"), "3": lambda: self.set_fx("none"),
                "e": self.edit}
        for seq, fn in keys.items():
            r.bind_all(seq, lambda e, f=fn: self.shortcut(e, f))

    def shortcut(self, event, fn):
        # typing in the edit box: the keys are text
        if event.widget.winfo_class() in TYPING:
            return None
        fn()
        return "break"

    def button(self, parent, text, cmd, color=MUSTARD, width=18):
        b = tk.Button(parent, text=text, command=cmd, bg=color, fg=INK if color != RED else PAPER, relief="flat",
                      font=("Segoe UI", 10, "bold"), width=width, takefocus=0, activebackground=PAPER, cursor="hand2")
        b.pack(side="left", padx=(0, 8), ipady=6)
        return b

    def say(self, msg):
        self.status.config(text=msg)

    # Queue -----------------------------------------------------------------------------------------------------------
    def load_queue(self):
        self.stop_recording(discard=True)
        f = FILTERS[self.filter.get()]
        # lines made by an edit live in G.LINES too: R.queue would list them on their own as well
        keys = [k for k in R.queue(types.SimpleNamespace(only=None, **f), self.meta) if k not in self.origin]
        self.keys = self.expand(keys)
        self.listbox.delete(0, "end")
        for k in self.keys:
            self.listbox.insert("end", self.row_text(k))
        self.index = 0
        self.show()

    def expand(self, keys):
        # an edited line is replaced by the lines of its new text (a removed one stays, marked, so it can be undone)
        out = []
        for k in keys:
            edit = self.edits.get(k)
            if k in self.unused and (edit is None or not edit["new"]):
                continue
            if edit is not None and not edit["new"] and not self.show_removed.get():
                continue
            if edit is None or not edit["new"]:
                out.append(k)
                continue
            for text in edit["new"]:
                nk = C.key_of(edit["speaker"], C.spoken(text))
                G.LINES[nk] = {"speaker": edit["speaker"], "text": text, "sources": edit["sources"]}
                self.origin[nk] = k
                out.append(nk)
        return out

    def removed(self, k):
        edit = self.edits.get(k)
        return edit is not None and not edit["new"]

    def row_text(self, k):
        mark = "✔" if self.meta.get(k, {}).get("recorded") else "·"
        if self.removed(k):
            return f" ✗  (removida) {G.LINES[k]['text']}"
        tag = "✎ " if k in self.origin else ""
        return f" {mark}  {tag}{G.LINES[k]['text']}"

    def on_pick(self, _e):
        sel = self.listbox.curselection()
        if sel and sel[0] != self.index:
            self.stop_recording(discard=True)
            self.index = sel[0]
            self.show()

    def go(self, step):
        if self.stream is not None:
            return
        self.index = max(0, min(self.index + step, len(self.keys) - 1))
        self.show()

    def current(self):
        return self.keys[self.index] if 0 <= self.index < len(self.keys) else None

    def show(self):
        self.take = None
        k = self.current()
        done = sum(1 for key in self.keys if self.meta.get(key, {}).get("recorded"))
        self.count.config(text=f"{len(self.keys)} fala(s), {done} gravada(s)")
        if k is None:
            self.text.config(text="Nada para gravar neste filtro.")
            self.info.config(text="")
            return
        e = G.LINES[k]
        self.listbox.selection_clear(0, "end")
        self.listbox.selection_set(self.index)
        self.listbox.see(self.index)
        where = "telefone" if G.is_phone(e) else "presencial"
        rec = "  ·  já gravada por você" if self.meta.get(k, {}).get("recorded") else ""
        old = self.origin.get(k)
        was = f"\n✎ editada de: “{G.LINES[old]['text']}”" if old else ""
        self.info.config(text=f"{self.index + 1}/{len(self.keys)}   {e['speaker']} ({where})   {k}{rec}\n{', '.join(e['sources'])}{was}")
        if self.removed(k):
            self.text.config(text=f"(removida)\n“{e['text']}”", fg=GREY)
            self.say("Fala removida. E para desfazer, S para seguir.")
            return
        self.text.config(text=f"“{e['text']}”", fg=INK)
        self.say("Espaço para gravar, E para mudar o texto.")

    # Edit --------------------------------------------------------------------------------------------------------------
    def edit(self):
        k = self.current()
        if k is None or self.stream is not None:
            return
        old = self.origin.get(k, k)
        e = G.LINES[old]
        edit = self.edits.get(old)
        win = tk.Toplevel(self.root, bg=INK)
        win.title("Editar texto")
        win.transient(self.root)
        win.grab_set()
        tk.Label(win, text=f"Original ({', '.join(e['sources'])}):\n“{e['text']}”", bg=INK, fg=GREY, justify="left",
                 font=("Segoe UI", 10), wraplength=620).pack(anchor="w", padx=12, pady=(12, 6))
        tk.Label(win, text="Como você vai falar. Uma fala por linha (2 linhas = dividir). Vazio = remover a fala.",
                 bg=INK, fg=PAPER, font=("Segoe UI", 10)).pack(anchor="w", padx=12)
        box = tk.Text(win, width=70, height=5, font=("Georgia", 14), bg=PAPER, fg=INK, wrap="word")
        box.pack(padx=12, pady=6)
        box.insert("1.0", "\n".join(edit["new"]) if edit else e["text"])
        tk.Label(win, text="Nota para o Claude (opcional, ex.: 'juntei com a próxima'):", bg=INK, fg=PAPER,
                 font=("Segoe UI", 10)).pack(anchor="w", padx=12)
        note = tk.Entry(win, width=80, font=("Segoe UI", 10))
        note.pack(padx=12, pady=(2, 8), anchor="w")
        note.insert(0, edit.get("note", "") if edit else "")

        def save():
            lines = [line.strip() for line in box.get("1.0", "end").splitlines() if line.strip()]
            if lines == [e["text"]] and not note.get().strip():
                self.edits.pop(old, None)
            else:
                self.edits[old] = {"speaker": e["speaker"], "sources": e["sources"], "old": e["text"], "new": lines,
                                   "note": note.get().strip()}
            self.save_edits()
            win.destroy()
            self.reload_at(old)

        def undo():
            self.edits.pop(old, None)
            self.save_edits()
            win.destroy()
            self.reload_at(old)

        row = tk.Frame(win, bg=INK)
        row.pack(fill="x", padx=12, pady=(0, 12))
        self.button(row, "Salvar", save, GREEN, width=12)
        self.button(row, "Voltar ao original", undo, GREY, width=18)
        self.button(row, "Cancelar", win.destroy, GREY, width=10)
        box.focus_set()

    def save_edits(self):
        json.dump(self.edits, open(EDITS_PATH, "w", encoding="utf-8"), indent=1, ensure_ascii=False)

    def reload_at(self, old):
        # rebuild the queue and stand on the first line that came out of `old`
        keys = [self.origin.get(k, k) for k in self.keys]
        originals = list(dict.fromkeys(keys))
        self.keys = self.expand(originals)
        self.listbox.delete(0, "end")
        for k in self.keys:
            self.listbox.insert("end", self.row_text(k))
        # a line just removed is hidden: stay at its place in the list
        self.index = next((i for i, k in enumerate(self.keys) if self.origin.get(k, k) == old), self.index)
        self.index = max(0, min(self.index, len(self.keys) - 1))
        self.show()

    # Recording ---------------------------------------------------------------------------------------------------------
    def toggle(self):
        k = self.current()
        if k is None or (self.stream is None and self.removed(k)):
            return
        if self.stream is None:
            sd.stop()
            self.frames = []
            self.stream = sd.InputStream(samplerate=R.SR, channels=1, dtype="float32",
                                         callback=lambda d, *_: self.frames.append(d[:, 0].copy()))
            self.stream.start()
            self.started = time.time()
            self.rec_btn.config(text="■  Parar  [Espaço]")
            self.say("Gravando... Espaço para parar.")
        else:
            self.stop_recording()

    def stop_recording(self, discard=False):
        if self.stream is None:
            return
        self.stream.stop()
        self.stream.close()
        self.stream = None
        self.rec_btn.config(text="●  Gravar  [Espaço]")
        if discard or not self.frames:
            return
        self.take = R.trim(np.concatenate(self.frames))
        sf.write(self.take_wav, self.take, R.SR)
        self.refx(play=True)
        # samples at full scale: the voice distorted (two takes of 2026-10-23 had 60-300)
        clipped = int((np.abs(self.take) > 0.99).sum())
        if clipped > 0:
            self.say(f"⚠ Estourou ({clipped} amostras no máximo): fale um pouco mais longe do microfone e regrave (Espaço).")

    def refx(self, play=True):
        k = self.current()
        if self.take is None or k is None:
            return
        R.process(self.take_wav, self.take_ogg, G.LINES[k], self.fx.get())
        self.say(f"Take {len(self.take) / R.SR:.1f}s, efeito: {EFFECTS[self.fx.get()]}. "
                 f"Enter guarda, Espaço regrava, P/O compara.")
        if play:
            self.play(self.take_ogg)

    def set_fx(self, mode):
        self.fx.set(mode)
        self.refx()

    # Playback ----------------------------------------------------------------------------------------------------------
    def play(self, path):
        if self.stream is not None or not os.path.exists(path):
            return
        data, rate = sf.read(path, dtype="float32")
        sd.stop()
        sd.play(data, rate)

    # Without a new take, P / O play what was kept for this line (owner 2026-10-23: "não tô conseguindo reproduzir os
    # áudios que eu já gravei": they only played the take not kept yet)
    def kept(self, raw):
        k = self.current()
        if k is None:
            return None
        path = os.path.join(R.RAW, k + ".wav") if raw else os.path.join(G.OUT, G.LINES[k]["speaker"], k + ".ogg")
        if not os.path.exists(path) or (not raw and not self.meta.get(k, {}).get("recorded")):
            return None
        return path

    def play_fx(self):
        path = self.take_ogg if self.take is not None else self.kept(False)
        if path is None:
            self.say("Nenhuma gravação sua nesta fala ainda (Espaço grava, L toca a voz atual).")
            return
        self.play(path)

    def play_raw(self):
        path = self.take_wav if self.take is not None else self.kept(True)
        if path is None:
            self.say("Nenhuma gravação sua nesta fala ainda (Espaço grava, L toca a voz atual).")
            return
        self.play(path)

    def play_current(self):
        k = self.current()
        if k is None:
            return
        path = os.path.join(G.OUT, G.LINES[k]["speaker"], k + ".ogg")
        if not os.path.exists(path):
            self.say("Essa fala ainda não tem áudio.")
            return
        self.play(path)

    # Keep --------------------------------------------------------------------------------------------------------------
    def keep(self):
        k = self.current()
        if self.stream is not None:
            self.stop_recording()
            return
        if self.take is None or k is None:
            self.say("Nada para guardar: grave um take (Espaço) ou pule (S).")
            return
        sd.stop()
        e = G.LINES[k]
        out = os.path.join(G.OUT, e["speaker"], k + ".ogg")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        os.replace(self.take_ogg, out)
        os.replace(self.take_wav, os.path.join(R.RAW, k + ".wav"))
        m = self.meta.setdefault(k, {})
        m.update(speaker=e["speaker"], length=round(G.duration(out), 3), gen_text=e["text"], recorded=True, fx=self.fx.get())
        if k in self.origin:
            # a line of an edit: not in lines.json until the sources say it (edits.json applied, collect_lines run)
            m.update(text=e["text"], edited_from=self.origin[k])
        for field in ("assetId", "status", "reason"):
            m.pop(field, None)
        R.meta_save(self.meta)
        self.listbox.delete(self.index)
        self.listbox.insert(self.index, self.row_text(k))
        if self.index < len(self.keys) - 1:
            self.index += 1
            self.show()
            self.say(f"Guardada ({m['length']}s). Próxima: Espaço para gravar.")
        else:
            self.show()
            self.say("Última fala guardada. Depois: python upload.py e python build_content.py")

    # Meter -------------------------------------------------------------------------------------------------------------
    def tick(self):
        c = self.canvas
        c.delete("all")
        w = c.winfo_width()
        if self.stream is not None and self.frames:
            level = float(np.sqrt(np.mean(self.frames[-1] ** 2)))
            fill = min(level * 8, 1.0)
            color = GREEN if fill < 0.7 else MUSTARD if fill < 0.95 else RED
            c.create_rectangle(0, 0, int(w * fill), 22, fill=color, width=0)
            self.timer.config(text=f"{time.time() - self.started:5.1f}s", fg=RED)
        else:
            self.timer.config(text="", fg=PAPER)
        self.root.after(50, self.tick)


def main():
    root = tk.Tk()
    App(root)
    root.mainloop()
    for f in ("_take.ogg", "_take.wav"):
        p = os.path.join(G.HERE, f)
        if os.path.exists(p):
            os.remove(p)


if __name__ == "__main__":
    main()
