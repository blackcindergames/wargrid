'use strict';
// Mark decisions: docs/reference/design-answers-2026-11-08.md, "Visual and UX proposal, second pass" (user, 2026-11-15).
window.MARKS = (function () {
  const STATES = ['none', 'one', 'many', 'factory', 'plant', 'builder', 'build', 'place', 'blocked', 'enemy', 'pile', 'site'];
  const UNDER = 'rgba(14,18,22,0.78)';
  const HEALTH = { green: '#5cc85a', yellow: '#e0d060', red: '#d8453a' };
  const RANGE = 9; // rotary_tower_gun range in cells, game/scripts/simulation/definitions/shared.gd:21
  const OWN = 1, FOE = 2;
  const RIGHT = -Math.PI / 4, LEFT = (3 * Math.PI) / 4;
  const MUZZLE = 20; // world_view.gd MUZZLE_LIFT: a defence's target line starts this far above its ground point
  const GATE_CORNER = [23.75, 33]; // the gate scene's south map corner, in its own cells: past every piece of the "one" scene

  // Line widths, ring, tick, X and flag sizes: carried from the HUD v5 backdrops (world.js), not decided.
  const ink = (ctx, path, w) => {
    ctx.save(); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.strokeStyle = UNDER; ctx.lineWidth = w + 2; path(); ctx.stroke();
    ctx.strokeStyle = '#fff'; ctx.lineWidth = w; path(); ctx.stroke(); ctx.restore();
  };
  const poly = (ctx, pts, close) => () => { ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]); pts.slice(1).forEach((q) => ctx.lineTo(q[0], q[1])); if (close) ctx.closePath(); };
  const ellipse = (ctx, x, y, rx, ry) => () => { ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); };
  // world_view.gd _ground_diamond: half width _half_width + 4, so infantry 10 px, armour-piercing vehicles 19, other vehicles 16.
  // shortcut: armour-piercing ids hard-coded (frc_tank not covered); read the weapon's damage type once another one is drawn here.
  const rxOf = (id) => (/infantry/.test(id) ? 10 : /^(china_light_vehicle|usa_tank)$/.test(id) ? 19 : 16);
  const diamond = (x, y, rx) => [[x, y - rx / 2], [x + rx, y], [x, y + rx / 2], [x - rx, y]];
  const select = (ctx, x, y, rx) => ink(ctx, poly(ctx, diamond(x, y, rx), true), 1.25);
  function ticks(ctx, x, y, rx) {
    const d = diamond(x, y, rx), k = 0.32;
    d.forEach((p, i) => {
      const a = d[(i + 3) % 4], c = d[(i + 1) % 4];
      ink(ctx, poly(ctx, [[p[0] + (a[0] - p[0]) * k, p[1] + (a[1] - p[1]) * k], p, [p[0] + (c[0] - p[0]) * k, p[1] + (c[1] - p[1]) * k]]), 1.5);
    });
  }
  const cross = (ctx, x, y) => ink(ctx, () => { const r = 6; ctx.beginPath(); ctx.moveTo(x - r, y - r); ctx.lineTo(x + r, y + r); ctx.moveTo(x + r, y - r); ctx.lineTo(x - r, y + r); }, 2);
  const moveRing = (ctx, x, y) => ink(ctx, ellipse(ctx, x, y, 9, 4.5), 1.5);
  const rangeRing = (ctx, p, cells) => ink(ctx, ellipse(ctx, p[0], p[1], cells * 32 * Math.SQRT2, cells * 16 * Math.SQRT2), 1.25);
  const cell = (ctx, P, x, y) => ink(ctx, poly(ctx, [[x, y], [x + 1, y], [x + 1, y + 1], [x, y + 1]].map(P), true), 1.25);
  const cellCross = (ctx, P, x, y) => ink(ctx, () => { const p = [P([x + 0.5, y + 0.22]), P([x + 0.5, y + 0.78]), P([x + 0.22, y + 0.5]), P([x + 0.78, y + 0.5])]; ctx.beginPath(); ctx.moveTo(...p[0]); ctx.lineTo(...p[1]); ctx.moveTo(...p[2]); ctx.lineTo(...p[3]); }, 1.5);
  function rally(ctx, door, r) {
    ink(ctx, poly(ctx, [door, r]), 1.25);
    ink(ctx, poly(ctx, [r, [r[0], r[1] - 24]]), 1.5);
    ctx.save(); poly(ctx, [[r[0], r[1] - 24], [r[0] + 10, r[1] - 24], [r[0] + 10, r[1] - 15], [r[0], r[1] - 15]], true)(); ctx.fillStyle = '#fff'; ctx.strokeStyle = UNDER; ctx.lineWidth = 1.5; ctx.stroke(); ctx.fill(); ctx.restore();
    ink(ctx, ellipse(ctx, r[0], r[1], 4, 2), 1);
  }
  // Width 1.25 and dash 6/4: agent proposal, not decided.
  function targetLine(ctx, from, to) {
    ctx.save(); ctx.setLineDash([6, 4]); ink(ctx, poly(ctx, [from, to]), 1.25); ctx.restore();
  }
  const healthColour = (f) => (f >= 1 ? HEALTH.green : f < 0.5 ? mix(HEALTH.red, HEALTH.yellow, f * 2) : mix(HEALTH.yellow, HEALTH.green, (f - 0.5) * 2));
  function bar(ctx, x, top, f) { // world_view.gd HEALTH_BAR 24 x 3 on a 70 % black back
    const w = 24, h = 3;
    ctx.fillStyle = 'rgba(0,0,0,0.7)'; ctx.fillRect(x - w / 2 - 1, top - 1, w + 2, h + 2);
    ctx.fillStyle = healthColour(f); ctx.fillRect(x - w / 2, top, w * f, h);
  }
  const unitBar = (ctx, u) => bar(ctx, u.ax, u.ay + bboxPx(u.shape, 1).y0 - 10, u.hp);
  const bldBar = (ctx, b) => bar(ctx, b.ax, b.ay + bboxPx(b.shape, 1).y0 * (b.site ? 0.6 : 1) - 10, b.hp);
  function pointer(ctx, x, y) {
    const s = 1.15, pts = [[0, 0], [0, 17], [4.2, 13], [7.2, 19.6], [10, 18.4], [7.1, 12], [12.2, 12]].map((q) => [x + q[0] * s, y + q[1] * s]);
    ctx.save(); poly(ctx, pts, true)(); ctx.fillStyle = '#fff'; ctx.fill(); ctx.strokeStyle = '#111'; ctx.lineWidth = 1.2; ctx.lineJoin = 'round'; ctx.stroke(); ctx.restore();
  }
  // Drawn opaque off screen, then laid on at 55 %, so triangle seams do not show through.
  function ghost(ctx, cfg, id, at) {
    const shape = shapeIn(id).shape, off = document.createElement('canvas');
    off.width = ctx.canvas.width; off.height = ctx.canvas.height;
    const o = off.getContext('2d');
    o.setTransform(SCALE, 0, 0, SCALE, 0, 0);
    drawShape(o, shape, { x: at[0], y: at[1], zoom: 1, heading: 0, slots: itemSlots({ owner: OWN, bld: true }, cfg, eff()) });
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 0.55; ctx.drawImage(off, 0, 0); ctx.restore();
  }
  const selectOn = (ctx, it) => ink(ctx, () => diamondPath(ctx, it.ax, it.ay, it.fp[0], it.fp[1], 1), 1.5);
  // A selected pile's pad fills its footprint and would hide a diamond drawn under it: pad, then the mark, then the cargo.
  const keepParts = (shape, keep) => {
    const f = (parts) => parts.filter((pt) => keep(pt.name));
    return { ...shape, parts: f(shape.parts), parts_by_detail: shape.parts_by_detail && Object.fromEntries(Object.entries(shape.parts_by_detail).map(([k, v]) => [k, f(v)])) };
  };
  function splitPad(it) {
    const isPad = (n) => n === 'body';
    return [{ ...it, shape: keepParts(it.shape, isPad), selected: false, padSel: true }, { ...it, shape: keepParts(it.shape, (n) => !isPad(n)), fp: null, selected: false, depth: it.depth + 0.001 }];
  }
  // Under-stroke of a building's selection diamond; paintItems draws the white line over it.
  function bldUnder(ctx, it) { ctx.save(); ctx.strokeStyle = UNDER; ctx.lineWidth = 4.5; diamondPath(ctx, it.ax, it.ay, it.fp[0], it.fp[1], 1); ctx.stroke(); ctx.restore(); }
  function label(ctx, text, x, y) {
    ctx.save(); ctx.font = `600 11px ${FONT}`; ctx.textAlign = 'center'; ctx.lineJoin = 'round'; ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(0,0,0,.7)'; ctx.fillStyle = '#fff';
    ctx.strokeText(text, x, y); ctx.fillText(text, x, y); ctx.restore();
  }

  // Fog left out, as in the HUD v5 backdrops.
  function begin(h, scale) {
    CUR = { ...SEL6, steps: { ...SEL6.steps, fog: '0' } }; SCALE = scale || 1;
    const cfg = { ...CFG0, zoom: '1', ground: 'sand' }, s = startStage(cfg), cv = s.el.firstChild;
    if (h !== 720) {
      cv.height = h * SCALE; cv.style.height = cv.height + 'px'; s.el.style.height = h * SCALE + 'px';
      s.ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
    }
    return { el: s.el, ctx: s.ctx, cfg };
  }
  function ground(ctx, cfg, cam, h) {
    const g = GROUND[cfg.ground];
    for (let y = 0; y < h; y += 720) { ctx.save(); ctx.translate(0, y); paintGround(ctx, 1, cam.ox, cam.oy - y, g); ctx.restore(); }
    paintDecorGround(ctx, 1, cam.ox, cam.oy, PAL.decor, cfg.ground);
  }

  // formerly in the HUD v5 world.js (private)
  function rng(seed) { return () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  // Pieces in world cells; units are placed in the world camera's stage px, as the backdrops were, then kept as cells.
  function scene(state) {
    const fight = ['none', 'one', 'enemy'].includes(state), early = state === 'build';
    const cam = state === 'many' ? { ox: 128, oy: -192 } : { ox: 1012, oy: -150 };
    const toPx = (cx, cy) => toScreen(cam.ox, cam.oy, 1, [cx, cy]);
    const toCell = (X, Y) => { const px = X - cam.ox, py = Y - cam.oy; return [(px / 32 + py / 16) / 2, (py / 16 - px / 32) / 2]; };
    const B0 = [0, 19];
    const LAYOUT = { command_center: [0, 0], supply_center: [4, 0], power_plant: [8, 0], factory: [0, 4], barracks: [4, 4], defence: [7, 6] };
    // Health only, no damage variant: china_power_plant's variant 1 bares a footprint cell that read as a placement ghost.
    const damaged = fight ? { power_plant: 0.55, defence: 0.62 } : {};
    const blds = (early ? ['command_center', 'barracks'] : Object.keys(LAYOUT)).map((r) => {
      const id = 'china_' + r;
      return { id, role: r, cell: [B0[0] + LAYOUT[r][0], B0[1] + LAYOUT[r][1]], fp: BASE[id].footprint, owner: OWN, hp: damaged[r] || 1, sel: (state === 'factory' && r === 'factory') || (state === 'plant' && r === 'power_plant') };
    });
    if (state === 'site') blds.push({ id: 'china_factory', cell: [12, 21], fp: [3, 3], owner: OWN, hp: 0.6, sel: true, site: true });
    const pile = early ? null : { id: 'pile', cell: [7, 9], fp: [4, 5], sel: state === 'pile' };
    SCENES.overlaps(blds.concat(pile ? [pile] : [])).forEach((b) => addErr('world scene: footprints overlap: ' + b));

    const units = [], R = rng(7), jit = (a) => (R() - 0.5) * 2 * a, rep = (id, n) => Array(n).fill(id);
    const unit = (id, owner, X, Y, heading, extra) => units.push({ id, owner, X, Y, heading, hp: 1, ...extra });
    const block = (ids, owner, x0, y0, cols, sx, sy, heading, extra) => ids.forEach((id, i) => {
      const c = i % cols, r = Math.floor(i / cols);
      unit(id, owner, x0 + c * sx + (r % 2) * sx * 0.5 + jit(sx * 0.18), y0 + r * sy + jit(sy * 0.2), heading + jit(0.25), extra);
    });
    if (fight) {
      block([...rep('china_light_vehicle', 3), ...rep('china_tank', 2), 'china_light_vehicle'], OWN, 690, 400, 2, 50, 34, RIGHT);
      block([...rep('china_light_vehicle', 2), ...rep('china_tank', 2)], OWN, 800, 380, 1, 44, 38, RIGHT);
      block([...rep('china_rifle_infantry', 6), ...rep('china_rocket_infantry', 4)], OWN, 850, 480, 4, 22, 18, RIGHT);
      block(rep('usa_tank', 4), FOE, 1010, 330, 1, 40, 40, LEFT);
      block([...rep('usa_rifle_infantry', 4), ...rep('usa_rocket_infantry', 2)], FOE, 1080, 430, 3, 22, 20, LEFT);
      block(rep('usa_light_vehicle', 2), FOE, 1110, 330, 1, 40, 44, LEFT);
      Object.entries({ 0: 0.8, 3: 0.35, 7: 0.6, 12: 0.7, 15: 0.25, 20: 0.55, 22: 0.85, 24: 0.4, 27: 0.75, 30: 0.3 }).forEach(([i, h]) => { if (units[i]) units[i].hp = h; });
    } else if (state === 'many') {
      block(rep('china_rifle_infantry', 24), OWN, 950, 180, 6, 30, 27, RIGHT);
      block(rep('china_rocket_infantry', 12), OWN, 950, 180 + 4 * 27 + 4, 6, 30, 27, RIGHT);
      block(rep('china_light_vehicle', 36), OWN, 590, 160, 6, 56, 38, RIGHT);
      block(rep('china_tank', 24), OWN, 350, 190, 4, 54, 38, RIGHT);
      block([...rep('china_collector', 12), ...rep('china_builder', 12)], OWN, 170, 205, 3, 56, 36, RIGHT);
      units.forEach((u) => { u.sel = true; const r = R(); u.hp = r < 0.55 ? 1 : r < 0.75 ? 0.6 + 0.35 * R() : r < 0.9 ? 0.3 + 0.3 * R() : 0.1 + 0.2 * R(); });
    } else if (!early) {
      block([...rep('china_light_vehicle', 4), ...rep('china_tank', 4)], OWN, 880, 380, 4, 50, 36, RIGHT);
      block([...rep('china_rifle_infantry', 6), ...rep('china_rocket_infantry', 3)], OWN, 900, 470, 5, 24, 20, RIGHT);
      [2, 9].forEach((i) => { units[i].hp = 0.7; });
    }
    const at = (id, c, h, extra) => { const p = toPx(c[0], c[1]); unit(id, OWN, p[0], p[1], h, extra); };
    if (pile && state !== 'many') {
      at('china_collector', [8.6, 14.7], -Math.PI / 2 + 0.05);
      at('china_collector', [10.3, 14.7], -Math.PI / 2 - 0.05);
      at('china_collector', [11.6, 16.4], -Math.PI / 2 - 0.15);
    }
    const dozer = { builder: [11.5, 23.2], build: [6.6, 22.4], place: [12.4, 22.4], blocked: [8.2, 27.4], site: [15.8, 22.6] }[state];
    if (dozer) at('china_builder', dozer, state === 'site' ? LEFT + 0.6 : RIGHT + 0.5, { sel: true });
    if (early) [[7.5, 25.4], [8.3, 25.0], [8.1, 26.1], [8.9, 25.7]].forEach((c) => at('china_rifle_infantry', c, RIGHT + jit(0.3)));

    const byId = (id, owner, k) => units.filter((u) => u.id === id && u.owner === owner)[k || 0];
    if (state === 'one') { const t = byId('china_light_vehicle', OWN, 4); t.sel = true; t.hp = 0.45; byId('china_tank', OWN, 3).hover = true; }
    if (state === 'enemy') { const t = byId('usa_tank', FOE, 1); t.sel = true; t.hp = 0.65; }
    units.forEach((u) => { u.cell = toCell(u.X, u.Y); });
    const occupied = (x, y) => blds.some((b) => x >= b.cell[0] && x < b.cell[0] + b.fp[0] && y >= b.cell[1] && y < b.cell[1] + b.fp[1]);
    return {
      cam, blds, units, pile,
      target: fight ? byId('usa_tank', FOE, 2) : null,
      move: fight ? [17.4, 24.6] : null,
      range: state === 'place' ? [11.5, 19.5] : null,
      ghost: state === 'place' ? { id: 'china_defence', cell: [11, 19], n: 1, occupied: () => false } : state === 'blocked' ? { id: 'china_factory', cell: [4, 22], n: 3, occupied } : null,
      rally: state === 'factory' ? [4.6, 28.2] : null,
    };
  }

  // Ground, place marks, pieces, overlays, unit marks: the backdrops' order (marks on a unit above the pieces, marks on a place under them).
  function paintScene(ctx, cfg, sc, cam, h, overlayShift) {
    const P = (c) => toScreen(cam.ox, cam.oy, 1, c);
    cfg.origin = cam;
    ground(ctx, cfg, cam, h);
    const items = [];
    sc.blds.forEach((b) => {
      const c = [b.cell[0] + b.fp[0] / 2, b.cell[1] + b.fp[1] / 2], p = P(c), shape = shapeIn(b.id).shape, d = c[0] + c[1];
      Object.assign(b, { ax: p[0], ay: p[1], shape });
      if (b.site) {
        const post = postShapes(shape, 3);
        items.push({ shape: post.back, owner: b.owner, ax: p[0], ay: p[1], depth: d - 0.001, bld: true });
        items.push(siteItem(3, { shape, rise: 0.6 }, cfg, b.owner, p[0], p[1], 60, { depth: d, fp: b.fp, bld: true, selected: b.sel }));
        items.push({ shape: post.front, owner: b.owner, ax: p[0], ay: p[1], depth: d + 0.001, bld: true });
      } else items.push({ shape, owner: b.owner, ax: p[0], ay: p[1], depth: d, fp: b.fp, bld: true, selected: b.sel });
    });
    if (sc.pile) {
      const c = [sc.pile.cell[0] + 2, sc.pile.cell[1] + 2.5], p = P(c);
      const it = pileItem('big', 60, pileRes('big', 60), cfg, p[0], p[1], { depth: c[0] + c[1], selected: sc.pile.sel });
      items.push(...(it.selected ? splitPad(it) : [it]));
    }
    sc.units.forEach((u) => {
      const p = P(u.cell);
      Object.assign(u, { ax: p[0], ay: p[1], shape: shapeIn(u.id).shape });
      items.push({ shape: u.shape, owner: u.owner, ax: u.ax, ay: u.ay, depth: u.cell[0] + u.cell[1], unit: true, heading: u.heading });
    });
    SC5.CELLS.forEach((c) => items.push({ cliff: true, cell: c, depth: c[0] + c[1] + 1 }));
    const dd = decorData(PAL.decor, cfg.ground);
    if (dd) dd.shapes.forEach((s) => { const p = P(s.cell); items.push({ shape: s.shape, slots: s.slots, ax: p[0], ay: p[1], depth: s.cell[0] + s.cell[1], heading: s.heading, deco: true }); });
    items.sort((p, q) => p.depth - q.depth);

    if (sc.move) { const p = P(sc.move); moveRing(ctx, p[0], p[1]); }
    if (sc.range) rangeRing(ctx, P(sc.range), RANGE);
    items.forEach((it) => { if (it.selected && it.fp) bldUnder(ctx, it); paintItems(ctx, [it], cfg); if (it.padSel) selectOn(ctx, it); });
    // Overlays paint a 1280 x 720 stage (the edge fills past it), and the world camera never reaches the map edge: the gate scene only.
    if (overlayShift) { const s = overlayShift; runOverlays(ctx, cfg, items, { ox: cam.ox - 32 * (s[0] - s[1]), oy: cam.oy - 16 * (s[0] + s[1]), edge: 1280 }); }

    sc.units.forEach((u) => { if (u.sel) select(ctx, u.ax, u.ay, rxOf(u.id)); });
    sc.units.forEach((u) => { if (u.hover) ticks(ctx, u.ax, u.ay, rxOf(u.id)); });
    sc.units.forEach((u) => { if (u.sel || u.hover || u.hp < 1) unitBar(ctx, u); });
    sc.blds.forEach((b) => { if (b.sel || b.hp < 1) bldBar(ctx, b); });
    if (sc.target) cross(ctx, sc.target.ax, sc.target.ay - 8);
    if (sc.rally) { const f = sc.blds.find((b) => b.role === 'factory'); rally(ctx, P([f.cell[0] + 1.5, f.cell[1] + 3]), P(sc.rally)); }
    if (sc.ghost) {
      const g = sc.ghost, p = P([g.cell[0] + g.n / 2, g.cell[1] + g.n / 2]);
      ghost(ctx, cfg, g.id, p);
      for (let x = g.cell[0]; x < g.cell[0] + g.n; x++) for (let y = g.cell[1]; y < g.cell[1] + g.n; y++) {
        cell(ctx, P, x, y);
        if (g.occupied(x, y)) cellCross(ctx, P, x, y);
      }
      pointer(ctx, p[0] + 14, p[1] + 2);
    }
  }

  function worldStage(state, scale) {
    if (!STATES.includes(state)) throw new Error('unknown world state ' + state);
    return withOvr(r6Look(), () => {
      const { el, ctx, cfg } = begin(800, scale), sc = scene(state);
      paintScene(ctx, cfg, sc, sc.cam, 800);
      return el;
    });
  }

  function gateStage() {
    return withOvr(r6Look(), () => {
      const { el, ctx, cfg } = begin(720, SCALE), sc = scene('one'), cam = { ox: 1012 - 30, oy: -150 - 62 };
      paintScene(ctx, cfg, sc, cam, 720, [48 - GATE_CORNER[0], 51 - GATE_CORNER[1]]);
      return el;
    });
  }

  function marksHalf(ctx, cfg, x0) {
    const cam = { ox: x0 + 320, oy: 0 }, P = (c) => toScreen(cam.ox, cam.oy, 1, c), C = (X, Y) => { const px = X - cam.ox, py = Y - cam.oy; return [(px / 32 + py / 16) / 2, (py / 16 - px / 32) / 2]; };
    cfg.origin = cam;
    ctx.save(); ctx.beginPath(); ctx.rect(x0, 0, 640, 720); ctx.clip();
    paintGround(ctx, 1, cam.ox, cam.oy, GROUND[cfg.ground]);
    const unitAt = (id, owner, X, Y, heading, extra) => ({ id, shape: shapeIn(id).shape, owner, ax: X, ay: Y, unit: true, heading, hp: 1, ...extra });
    const bldAt = (id, c, extra) => { const fp = BASE[id].footprint, p = P([c[0] + fp[0] / 2, c[1] + fp[1] / 2]); return { id, shape: shapeIn(id).shape, owner: OWN, ax: p[0], ay: p[1], fp, cell: c, bld: true, hp: 1, ...extra }; };
    const snap = (X, Y) => C(X, Y).map(Math.round);
    const sel = unitAt('china_tank', OWN, x0 + 55, 58, RIGHT), hov = unitAt('china_tank', OWN, x0 + 155, 58, RIGHT), foe = unitAt('usa_tank', FOE, x0 + 255, 58, LEFT);
    const move = [x0 + 345, 58];
    const def = bldAt('china_defence', snap(x0 + 450, 48), { selected: true }), aim = unitAt('usa_light_vehicle', FOE, x0 + 600, 50, LEFT);
    const fac = bldAt('china_factory', snap(x0 + 150, 160), { selected: true }), door = P([fac.cell[0] + 1.5, fac.cell[1] + 3]), rallyAt = P([fac.cell[0] + 1.5, fac.cell[1] + 3.9]);
    const bar0 = bldAt('china_barracks', snap(x0 + 470, 200));
    const blocked = { id: 'china_factory', cell: [bar0.cell[0] - 1, bar0.cell[1] - 2], n: 3 };
    // Ring centre (x0 + 256, 496): its near side ends at 700, and the two halves' rings do not meet.
    const valid = { id: 'china_defence', cell: [14, 16] };
    const items = [sel, hov, foe, fac, bar0, def, aim];
    items.sort((p, q) => p.ay - q.ay);
    rangeRing(ctx, P([valid.cell[0] + 0.5, valid.cell[1] + 0.5]), RANGE);
    moveRing(ctx, move[0], move[1]);
    items.forEach((it) => { if (it.selected && it.fp) bldUnder(ctx, it); paintItems(ctx, [it], cfg); });
    select(ctx, sel.ax, sel.ay, rxOf(sel.id));
    ticks(ctx, hov.ax, hov.ay, rxOf(hov.id));
    targetLine(ctx, [def.ax, def.ay - 8 - MUZZLE], [aim.ax, aim.ay - 8]);
    [sel, hov].forEach((u) => unitBar(ctx, u));
    [fac, def].forEach((b) => bldBar(ctx, b));
    cross(ctx, foe.ax, foe.ay - 8);
    rally(ctx, door, rallyAt);
    const occ = (x, y) => x >= bar0.cell[0] && x < bar0.cell[0] + 2 && y >= bar0.cell[1] && y < bar0.cell[1] + 2;
    [[blocked, 3, occ], [valid, 1, () => false]].forEach(([g, n, taken]) => {
      ghost(ctx, cfg, g.id, P([g.cell[0] + n / 2, g.cell[1] + n / 2]));
      for (let x = g.cell[0]; x < g.cell[0] + n; x++) for (let y = g.cell[1]; y < g.cell[1] + n; y++) { cell(ctx, P, x, y); if (taken(x, y)) cellCross(ctx, P, x, y); }
    });
    const vp = P([valid.cell[0] + 0.5, valid.cell[1] + 0.5]);
    [['Selected', sel.ax, 94], ['Hover', hov.ax, 94], ['Attack target', foe.ax, 94], ['Move order', move[0], 94], ['Defence target', x0 + 525, 94],
      ['Rally point', rallyAt[0] + 14, rallyAt[1] + 20], ['Placement blocked', bar0.ax, bar0.ay + 50], ['Placement valid, range ' + RANGE + ' cells', vp[0], vp[1] - 50]]
      .forEach(([t, x, y]) => label(ctx, t, x, y));
    ctx.restore();
  }
  function marksStage() {
    return withOvr(r6Look(), () => {
      const { el, ctx, cfg } = begin(720, SCALE);
      [['sand', 0], ['dark', 640]].forEach(([g, x0]) => {
        cfg.ground = g; GKEY = g; PAL = palFor(CUR.steps, eff());
        marksHalf(ctx, cfg, x0);
      });
      return el;
    });
  }

  return { STATES, worldStage, gateStage, marksStage };
})();
