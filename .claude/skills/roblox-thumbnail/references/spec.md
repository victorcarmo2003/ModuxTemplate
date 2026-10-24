# Compose spec — every field of `thumb.py`

Paths are relative to the spec file. Fractions are of the canvas (x of width, y of height) unless noted.
Everything is optional except `out`, `size` and at least one of `bg` / `bg_color` / `layers`.

```jsonc
{
  "out": "thumb.png",
  "size": [1920, 1080],                      // [512, 512] for an icon
  "safe_bottom": 0.15,                       // documentation only: keep essentials above this line

  "bg": {
    "path": "bg.jpg",
    "crop": [x0, y0, x1, y1],                // source pixels; default = centre crop to the canvas ratio
    "blur": 3,                               // gaussian sigma; 2–5 keeps the scene readable, 7+ is mush
    "saturation": 0.6, "brightness": 0.8,    // multipliers
    "tint": [0.75, 0.88, 1.25],              // RGB multipliers (cool cast for a warm hero)
    "lift": [10, 18, 40],                    // raise blacks toward this RGB (navy instead of pure black)
    "gradient": {"color": [10, 15, 40], "strength": 0.4, "from": "bottom"}   // "bottom" or "top"
  },
  "bg_color": [20, 24, 40],                  // flat background instead of bg

  "spots": [                                 // soft radial light pools painted on the plate
    {"at": [0.65, 0.4], "radius": 0.4, "color": [255, 200, 120], "strength": 0.3}
  ],

  "layers": [                                // back to front
    {
      "path": "hero.png",
      "key": "alpha" | "green" | "magenta" | "none",   // alpha = PNG with transparency (Blender); green/magenta = chroma pass
      "spill": 7,                            // edge width (px) where key colour is cleaned; 15–30 for heavy spill
      "choke": 2,                            // shrink the matte N px after keying (kills green fringe)
      "crop": [x0, y0, x1, y1],              // keep only this source region of the matte (key "none" + crop = cut a prop
                                             // from the plate, e.g. a counter drawn in front of a character)
      "highlight": {"region": [x0, y0, x1, y1], "color": [255, 30, 50], "width": 8, "fill": 0.12,
                    "glow": {"width": 30, "strength": 0.45}},   // outline ONE character of a group pass
                                             // (biggest blob in the box; or "mask"/"mask_color" instead of region)
      "mask": "hero_matte.png",              // flat-colour Highlight pass instead of keying (occlusion-aware)
      "mask_color": [0, 255, 255],

      "at": [0.3, 1.22], "height": 1.05,     // anchor point and bbox height as fraction of canvas height
      "anchor": "bottom" | "center",         // which point of the bbox lands on `at`
      "flip": false, "rotate": 0,            // mirror; degrees (positive = counter-clockwise)

      "saturation": 1.3, "contrast": 1.1, "brightness": 1.05,
      "tint": [0.8, 0.9, 1.2], "tint_amount": 0.3,     // pull the subject toward the world colour
      "sharpen": 0.5,                        // unsharp on this layer only

      "outline":  {"color": [25, 15, 30], "width": 9},       // uniform distance-field outline (px)
      "outline2": {"color": [255, 255, 255], "width": 6},    // inner ring (sticker); drawn inside `outline`
      "glow":     {"color": [255, 40, 80], "width": 60, "strength": 0.6},
      "shadow":   {"offset": [22, 28], "blur": 22, "opacity": 0.5},     // contact/drop shadow on the plate
      "rim":      {"color": [150, 190, 255], "side": "right", "width": 9, "strength": 0.6}
    }
  ],

  "text": [
    {
      "text": "DON'T LOOK!",
      "font": "LuckiestGuy-Regular.ttf",     // file in assets/fonts or absolute path
      "size": 0.16,                          // letter height as fraction of canvas height; shrinks to fit max_width
      "max_width": 0.92,
      "at": [0.5, 0.15], "align": "center" | "left" | "right",
      "color": [255, 255, 255],
      "gradient": [[255, 240, 120], [255, 150, 30]],          // top→bottom fill
      "stroke":  {"color": [0, 0, 0], "width": 0.011},        // fraction of height
      "stroke2": {"color": [255, 255, 255], "width": 0.02},   // outer second stroke
      "shadow":  {"offset": [0.006, 0.008], "color": [0, 0, 0], "opacity": 0.7, "blur": 0},
      "rotate": -5
    }
  ],

  "grade": {
    "saturation": 1.1, "contrast": 1.08,
    "warm_cool": 0.12,                       // teal-and-orange split by luminance, 0–0.3
    "split": {"shadows": [30, 50, 110], "highlights": [255, 225, 190], "amount": 0.12}
  },
  "vignette": {"strength": 0.35, "bottom_bias": 0.3},   // or a plain number
  "sharpen": 0.4                             // final unsharp (after everything)
}
```

### batch
`python thumb.py batch spec.json --vary "path.to.key=val|val2" --vary "..."` — values are JSON, keys use dots and
list indexes (`layers.1.flip=true|false`, `text.0.text="RUN!"|"HIDE!"`, `grade.warm_cool=0|0.2`). Produces the
cartesian product + a contact sheet.
