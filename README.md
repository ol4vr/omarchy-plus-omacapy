# OmaCapy

![OmaCapy](preview.png)

The Omarchy+ owned edition of the OmaCapy bar companion — same shell, same
theme, nothing extra to install.

Pet it. Feed it oranges. Soak it. Collect omakase one-liners. When the machine fries, the rodent looks fried too.

Based on [Esegnorelli/omarchy-omacapy](https://github.com/Esegnorelli/omarchy-omacapy)
under the MIT license.

Computers can be useful **and** fun.

## What you do

| Button | What happens |
| --- | --- |
| **Pet** | Happiness up. The official hello. |
| **Orange** | Snacks up. Diplomatic citrus. |
| **Soak** | Zen up. Send it to the river. |
| **Wisdom** | A one-liner. No refunds. |

Happiness, snacks, and zen fade slowly on their own. Night restores zen. High
system load cooks it until you soak. Load is normalized by the number of online
logical CPUs, so behavior remains consistent across small systems and Hugin.

## Moods

The badge word and the face change with the roommate:

| Mood | Means |
| --- | --- |
| `chill` | Default floating coworker |
| `soaked` | Just back from the river |
| `munching` | Currently orange |
| `napping` | After 23:00, if it's happy enough |
| `hyped` | Over-petted |
| `fried` | Load is high, or zen collapsed |
| `lonely` | Nobody visited for hours |
| `meh` | Happiness ran low |

## Badge shortcuts

- **Left-click** — open / close the lounge
- **Middle-click** — quick pet
- **Right-click** — quick wisdom
- **Scroll up / down** — pet / orange

In the lounge:

- **Pet / Orange / Soak / Wisdom** each leave their own mark — mood, a short toast, or a quote card
- **p / o / s / w** (or **1–4**) fire those actions from the keyboard

State lives in `~/.local/state/omarchy/omacapy.json`. Nothing leaves the machine.
Bar placement is owned by the central Omarchy+ plugin manifest.

## Install

```bash
omarchy plugin add https://github.com/ol4vr/omarchy-plus-omacapy.git --enable
```

Local checkout:

```bash
omarchy plugin validate .
omarchy plugin add "$PWD" --enable
```

Optional placement:

```bash
omarchy bar move io.github.ol4vr.omacapy --section center
```

## Remove

```bash
omarchy plugin disable io.github.ol4vr.omacapy
omarchy plugin remove io.github.ol4vr.omacapy --yes
# optional: rm ~/.local/state/omarchy/omacapy.json
```

## Requirements

- Omarchy Quattro shell
- Nothing else. No accounts, no network, no extra packages.

Runtime load collection reads `/proc/loadavg` and
`/sys/devices/system/cpu/online` directly without launching a polling process.

## Why

The plugin marketplace is full of VPNs, AI token meters, and printer queues.
OmaCapy exists so your status bar can also host a wet friend who believes in snacks.

## License

MIT
