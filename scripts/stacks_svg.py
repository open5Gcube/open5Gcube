#!/usr/bin/env python3
"""Generate an SVG graph of the open5Gcube projects and the Stacks combining them.

Mode "hover": hovering a project highlights all Stacks it is part of (pure CSS,
no JavaScript). Mode "animated": cycles through the projects on its own, which
also works where the SVG is shown as an image (e.g. in the GitHub README).

Usage: scripts/stacks_svg.py modules/o5gc/stacks Doc/img/stacks.svg animated
"""
import sys
from pathlib import Path
from textwrap import wrap
from xml.sax.saxutils import escape

PURPLE, ORANGE, GREEN, BLUE, RED = "#8e44ad", "#e67e22", "#27ae60", "#2e86c1", "#c0392b"

# column -> [(id, name, subtitle, color)]
COLUMNS = {
    "RAN / Simulators": [
        ("osmo-ran", "Osmocom", "2G BTS · BSC", PURPLE),
        ("srsran", "srsRAN", "4G eNB · 5G gNB · UE", ORANGE),
        ("ocudu", "OCUDU", "5G gNB · CU/DU split", ORANGE),
        ("oai-ran", "OpenAirInterface", "5G gNB · UE", PURPLE),
        ("packetrusher", "PacketRusher", "gNB + UE simulator", GREEN),
        ("ueransim", "UERANSIM", "gNB + UE simulator", GREEN),
    ],
    "Core": [
        ("osmo-cn", "Osmocom", "2G MSC · HLR · SGSN", PURPLE),
        ("srsepc", "srsEPC", "4G core of srsRAN 4G", ORANGE),
        ("open5gs", "Open5GS", "4G EPC · 5G core", BLUE),
        ("oai-cn", "OpenAirInterface CN5G", "5G core", PURPLE),
        ("free5gc", "free5GC", "5G core", BLUE),
        ("ellacore", "EllaCore", "5G core", BLUE),
    ],
    "IMS": [
        (None, None, None, None),
        (None, None, None, None),
        ("kamailio", "Kamailio IMS", "VoLTE · FHoSS · RTPengine", RED),
        (None, None, None, None),
        (None, None, None, None),
        ("ellacore-ims", "EllaCore IMS", "IMS · SMSC", BLUE),
    ],
}

# Stack -> chain of projects (left to right)
STACKS = {
    "osmocom-2g": ["osmo-ran", "osmo-cn"],
    "srsran-4g-emu": ["srsran", "srsepc"],
    "srsran-open5gs-4g": ["srsran", "open5gs"],
    "srsran-open5gs-4g-emu": ["srsran", "open5gs"],
    "srsran-open5gs-4g-volte": ["srsran", "open5gs", "kamailio"],
    "srsran-open5gs-5g": ["srsran", "open5gs"],
    "srsran-open5gs-5g-emu": ["srsran", "open5gs"],
    "srsran-oaicn5g-5g": ["srsran", "oai-cn"],
    "srsran-free5gc-5g": ["srsran", "free5gc"],
    "ocudu-open5gs-5g": ["ocudu", "open5gs"],
    "ocudu-open5gs-5g-oaiue": ["ocudu", "open5gs"],
    "ocudu-split-open5gs-5g": ["ocudu", "open5gs"],
    "oairan-open5gs-5g": ["oai-ran", "open5gs"],
    "oai-5g-basic": ["oai-ran", "oai-cn"],
    "oai-5g-minimalist": ["oai-ran", "oai-cn"],
    "oairan-free5gc-5g": ["oai-ran", "free5gc"],
    "packetrusher-open5gs": ["packetrusher", "open5gs"],
    "packetrusher-open5gs-roaming": ["packetrusher", "open5gs"],
    "ueransim-open5gs": ["ueransim", "open5gs"],
    "ueransim-oai": ["ueransim", "oai-cn"],
    "ueransim-free5gc": ["ueransim", "free5gc"],
    "ueransim-ellacore": ["ueransim", "ellacore", "ellacore-ims"],
}
# Stacks which are no project combination
IGNORED_STACKS = {"ltesniffer"}

W, NODE_W, NODE_H, ROW = 900, 190, 46, 62
COL_X = [15, 355, 695]
TOP = 62
CAPTION_Y = TOP + 6 * ROW + 22
SLOT_SECONDS = 2.5  # animated: how long each project is highlighted

DIM = {"node": {"opacity": ".3"}, "line": {"opacity": ".15", "stroke": "var(--edge)", "stroke-width": "2"}}
NORMAL = {"node": {"opacity": "1"}, "line": {"opacity": ".7", "stroke": "var(--edge)", "stroke-width": "2"}}


def keyframes(name, slots, between=None):
    """Hold the properties of each slot, fading between the slots; slot 0 is
    also used at 0% and 100% for a seamless loop. If given, the `between`
    properties are passed through at each slot change (e.g. to hide one caption
    completely before the next one shows up)."""
    step = 100 / len(slots)
    fade = step * 0.12
    frames = [f"0%{{{css_props(slots[0])}}}"]
    for i, props in enumerate(slots):
        if between and i:
            frames.append(f"{i * step:.3f}%{{{css_props(between)}}}")
        frames.append(f"{i * step + fade:.3f}%,{(i + 1) * step - fade:.3f}%{{{css_props(props)}}}")
    frames.append(f"100%{{{css_props(slots[0])}}}")
    return f"@keyframes {name}{{{''.join(frames)}}}"


def css_props(props):
    return ";".join(f"{k}:{v}" for k, v in props.items())


def main(stacks_dir, out, mode="hover"):
    if mode not in ("hover", "animated"):
        sys.exit(f"unknown mode: {mode}")
    found = {p.name for p in Path(stacks_dir).iterdir() if p.is_dir()}
    missing = found - STACKS.keys() - IGNORED_STACKS
    if missing:
        print(f"warning: unmapped stacks are not shown: {', '.join(sorted(missing))}",
              file=sys.stderr)

    nodes = {}
    for col, (title, entries) in enumerate(COLUMNS.items()):
        for row, (nid, name, sub, color) in enumerate(entries):
            if nid:
                nodes[nid] = dict(name=name, sub=sub, color=color,
                                  x=COL_X[col], y=TOP + row * ROW)

    edges = {}
    for stack, chain in STACKS.items():
        for a, b in zip(chain, chain[1:]):
            edges.setdefault((a, b), []).append(stack)
    node_stacks = {n: [s for s, c in STACKS.items() if n in c] for n in nodes}

    css = [
        "text{font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif}",
        ".hdr{font-size:13px;font-weight:600;fill:var(--muted);letter-spacing:.06em;text-transform:uppercase}",
        ".name{font-size:14px;font-weight:600;fill:#fff}",
        ".sub{font-size:11px;fill:#fff;opacity:.9}",
        ".ring{fill:none;stroke:var(--fg);stroke-width:1.5;opacity:0}",
        ".node{cursor:default;transition:opacity .15s}",
        ".edge path{fill:none;transition:opacity .15s,stroke-width .15s}",
        ".edge .line{stroke:var(--edge);stroke-width:2;opacity:.7}",
        ".edge .hit{stroke:transparent;stroke-width:12}",
        ".caption{font-size:12.5px;fill:var(--muted)}",
        ".caption tspan.b{font-weight:600;fill:var(--fg)}",
        ".info{display:none}" if mode == "hover" else ".info{opacity:0}",
    ]
    if mode == "hover":
        css += hover_css(nodes, edges, node_stacks)
    else:
        css += animated_css(nodes, edges, node_stacks)

    captions = [(nodes[n]["name"], st) for n, st in node_stacks.items()] + \
        [(f'{nodes[a]["name"]} + {nodes[b]["name"]}', st) for (a, b), st in edges.items()]
    height = CAPTION_Y + 17 * max(len(wrap(", ".join(st), 110, break_on_hyphens=False)) for _, st in captions) + 12
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {height}" '
         f'width="{W}" height="{height}" font-size="14">',
         "<style>",
         ":root,svg{--fg:#1f2328;--muted:#59636e;--edge:#8c959f}",
         "@media (prefers-color-scheme:dark){svg{--fg:#f0f6fc;--muted:#9198a1;--edge:#6e7681}}",
         *css, "</style>"]

    for col, title in enumerate(COLUMNS):
        o.append(f'<text class="hdr" x="{COL_X[col] + NODE_W / 2}" y="{TOP - 20}" '
                 f'text-anchor="middle">{escape(title)}</text>')

    for i, ((a, b), stacks) in enumerate(edges.items()):
        na, nb = nodes[a], nodes[b]
        x1, y1 = na["x"] + NODE_W, na["y"] + NODE_H / 2
        x2, y2 = nb["x"], nb["y"] + NODE_H / 2
        mx = (x1 + x2) / 2
        d = f"M{x1},{y1} C{mx},{y1} {mx},{y2} {x2},{y2}"
        cls = " ".join(f"s-{s}" for s in stacks)
        o.append(f'<g class="edge {cls}" id="e-{i}"><title>{escape(", ".join(stacks))}</title>'
                 f'<path class="line" d="{d}"/><path class="hit" d="{d}"/></g>')

    for nid, n in nodes.items():
        cls = " ".join(f"s-{s}" for s in node_stacks[nid])
        cx = n["x"] + NODE_W / 2
        o.append(f'<g class="node {cls}" id="n-{nid}">'
                 f'<rect class="ring" x="{n["x"] - 4}" y="{n["y"] - 4}" width="{NODE_W + 8}" '
                 f'height="{NODE_H + 8}" rx="11"/>'
                 f'<rect x="{n["x"]}" y="{n["y"]}" width="{NODE_W}" height="{NODE_H}" rx="8" fill="{n["color"]}"/>'
                 f'<text class="name" x="{cx}" y="{n["y"] + 20}" text-anchor="middle">{escape(n["name"])}</text>'
                 f'<text class="sub" x="{cx}" y="{n["y"] + 36}" text-anchor="middle">{escape(n["sub"])}</text>'
                 "</g>")

    def caption(cid, label, stacks):
        lines = wrap(", ".join(stacks), 110, break_on_hyphens=False)
        n = len(stacks)
        o.append(f'<text class="caption info" id="{cid}" x="{W / 2}" y="{CAPTION_Y}" text-anchor="middle">'
                 f'<tspan class="b">{escape(label)}</tspan> — {n} Stack{"s" if n > 1 else ""}:')
        for line in lines:
            o.append(f'<tspan x="{W / 2}" dy="17">{escape(line)}</tspan>')
        o.append("</text>")

    hint = "Hover over a project or a line to see the Stacks combining them" if mode == "hover" \
        else "Each line combines two projects in at least one Stack"
    o.append(f'<text class="caption hint" x="{W / 2}" y="{CAPTION_Y}" text-anchor="middle">{hint}</text>')
    ids = [f"i-{n}" for n in node_stacks] + [f"i-e{i}" for i in range(len(edges))]
    for cid, (label, stacks) in list(zip(ids, captions))[:len(nodes) if mode == "animated" else None]:
        caption(cid, label, stacks)

    o.append("</svg>")
    Path(out).write_text("\n".join(o) + "\n")


def hover_css(nodes, edges, node_stacks):
    css = [
        # dim everything while something is hovered ...
        "svg:has(.node:hover,.edge:hover) .node{opacity:.3}",
        "svg:has(.node:hover,.edge:hover) .edge .line{opacity:.15}",
        "svg:has(.node:hover,.edge:hover) .hint{display:none}",
        ".node:hover .ring{opacity:1}",
        # ... except the hovered edge
        ".edge:hover .line{opacity:1!important;stroke-width:4;stroke:var(--fg)}",
    ]
    for nid, stacks in node_stacks.items():
        sel = ",".join(f".s-{s}" for s in stacks)
        color = nodes[nid]["color"]
        css += [
            f"svg:has(#n-{nid}:hover) :is({sel}).node{{opacity:1}}",
            f"svg:has(#n-{nid}:hover) :is({sel}) .line{{opacity:1;stroke-width:4;stroke:{color}}}",
            f"svg:has(#n-{nid}:hover) #i-{nid}{{display:inline}}",
        ]
    for i, (a, b) in enumerate(edges):
        css += [
            f"svg:has(#e-{i}:hover) :is(#n-{a},#n-{b}){{opacity:1}}",
            f"svg:has(#e-{i}:hover) #i-e{i}{{display:inline}}",
        ]

    return css


def animated_css(nodes, edges, node_stacks):
    """One slot showing the overview, then one slot per project."""
    order = list(nodes)
    total = SLOT_SECONDS * (len(order) + 1)
    css, frames = [], {}

    def animate(selector, slots, between=None):
        kf = keyframes("{name}", slots, between)
        name = frames.setdefault(kf, f"a{len(frames)}")
        css.append(f"{selector}{{animation:{name} {total}s linear infinite}}")

    def related(stacks, m):
        return bool(set(stacks) & set(node_stacks[m]))

    for nid in nodes:
        animate(f"#n-{nid}", [NORMAL["node"]] +
                [NORMAL["node"] if related(node_stacks[nid], m) else DIM["node"] for m in order])
    for i, stacks in enumerate(edges.values()):
        animate(f"#e-{i} .line", [NORMAL["line"]] +
                [{"opacity": "1", "stroke": nodes[m]["color"], "stroke-width": "4"}
                 if related(stacks, m) else DIM["line"] for m in order])
    visible, hidden = {"opacity": "1"}, {"opacity": "0"}
    animate(".hint", [visible] + [hidden] * len(order), hidden)
    for k, nid in enumerate(order):
        slots = [hidden] + [visible if k == j else hidden for j in range(len(order))]
        animate(f"#i-{nid}", slots, hidden)
        animate(f"#n-{nid} .ring", slots, hidden)
    css += [kf.replace("{name}", name) for kf, name in frames.items()]
    css.append("@media (prefers-reduced-motion:reduce){*{animation:none!important}}")
    return css


if __name__ == "__main__":
    main(*sys.argv[1:])
