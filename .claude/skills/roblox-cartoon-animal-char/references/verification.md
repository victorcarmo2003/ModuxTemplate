# Checks before showing the user

| Check | How | Pass |
|---|---|---|
| Eye placement in profile | `finish.py` renders `<A>_e60.png`, `<A>_e75.png` (60°/75° from the front, slightly below) | eye ovals sit on flat front, nothing slides down the snout |
| Facets / creases | close-up renders + Studio capture | no visible vertex lines on the cheeks/snout |
| Eye stretch | `python heads/facecheck.py` | h, v stretch ≈ 1.00-1.02; 0 % expression texels cut |
| Cap clearance | `sh bl.sh heads/capcheck.py` | no head/face vertex poking above the crown outside the cap; rim gap small |
| Ears | head–ear nearest distance (earchk pattern in lessons) | floppy ears touch the head (≤ 0.03), none floating |
| Joints | `heads/joints.py` → `<A>_joints.json` (Neck C1 per species, sizes, tris) | Neck C1 matches the rest pose |
| Pose | `body/crew_pose.py` (wave, tool, run) + `overlap_crew.py` | no limb through head/body |
| Inside-out pieces | `sh bl.sh heads/invscan.py -- Assets/blender/character` | 0 INV lines |
| Z-fight | pipeline `overlap_check.py` | 0 pairs |
| Night | Studio capture of a Night model | every piece dark (ears, tail, cap included) |
| Studio | demo row (all species day + one species all expressions + night variants) | front, 3/4 and profile captures look right |

Board for the user: `heads/views.py` (front/34/profile/top per species) and a contact sheet of `_face` + `_e60`.
