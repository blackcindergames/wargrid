// Draws Wargrid shapes from shapes-current.json exactly as shape_bake.gd / world_batch.gd build them.
// projectShape: baked triangles in px relative to the anchor at zoom 1. drawShape: paints them.
(function (root) {
  const TAU = Math.PI * 2;
  const SLOT = { roof: 0, roof_dark: 1, side: 2, side_dark: 3, machine: 4, smoke: 5, owner_flat: 6, skin: 7 };
  const Z_SCALE = 3.5, BUCKETS = 64, AIR_LIFT = 30, SHADOW = { ground: 6, air: 8 };
  const SEGMENTS = [4, 6, 8];
  // Not in the game: shade of a wedge's sloped face (page-only primitive, SPEC round 1 step 6).
  const SLOPE_SHADE = 0.86;

  // GDScript roundi: half away from zero (Math.round rounds half up).
  const roundi = (x) => (x < 0 ? -Math.round(-x) : Math.round(x));
  const bucket = (angle) => ((roundi((angle / TAU) * BUCKETS) % BUCKETS) + BUCKETS) % BUCKETS;
  const rot = (x, y, a) => { const c = Math.cos(a), s = Math.sin(a); return [x * c - y * s, x * s + y * c]; };
  const plane = (cx, cy) => [32 * (cx - cy), 16 * (cx + cy)];
  // GraphicsSettings.detail: Low quality 0; High: zoom < 1 -> 0, < 2 -> 1, else 2.
  const detailFor = (zoom, quality) => (quality === 'low' || zoom < 1 ? 0 : zoom < 2 ? 1 : 2);

  function backToFront(prims, angle) {
    const keyed = prims.map((p, i) => { const [cx, cy] = rot(p.offset[0], p.offset[1], angle); return [cx + cy, p.offset[2], i]; });
    keyed.sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2]);
    return keyed.map((k) => prims[k[2]]);
  }

  function appendPrim(out, ring, base, height, slot) {
    const top = base + height;
    const v = (p, lift) => { const q = plane(p[0], p[1]); return [q[0], q[1] - lift, lift]; };
    for (let i = 1; i < ring.length - 1; i++) out.push({ slot, top: true, pts: [v(ring[0], top), v(ring[i], top), v(ring[i + 1], top)] });
    const sideSlots = slot === SLOT.roof || slot === SLOT.roof_dark || slot === SLOT.machine ? [SLOT.side, SLOT.side_dark] : [slot, slot];
    for (let i = 0; i < ring.length; i++) {
      const a = ring[i], b = ring[(i + 1) % ring.length];
      const nx = (b[1] - a[1]), ny = -(b[0] - a[0]); // (b - a).rotated(-PI / 2)
      if (nx + ny <= 1e-3 * Math.hypot(nx, ny)) continue;
      const s = nx - ny < 0 ? sideSlots[0] : sideSlots[1];
      out.push({ slot: s, pts: [v(a, top), v(b, top), v(b, base)] });
      out.push({ slot: s, pts: [v(a, top), v(b, base), v(a, base)] });
    }
  }


  // Not in the game: page-only "wedge" primitive. heights[i] is the top lift in px above base for ring[i]
  // (ring = box corners). Sloped quad in the prim slot x SLOPE_SHADE; vertical faces culled and coloured as for boxes.
  function appendWedge(out, ring, base, heights, slot) {
    const v = (p, lift) => { const q = plane(p[0], p[1]); return [q[0], q[1] - lift, lift]; };
    const top = (i) => v(ring[i], base + heights[i]);
    out.push({ slot, top: true, shade: SLOPE_SHADE, pts: [top(0), top(1), top(2)] });
    out.push({ slot, top: true, shade: SLOPE_SHADE, pts: [top(0), top(2), top(3)] });
    const sideSlots = slot === SLOT.roof || slot === SLOT.roof_dark || slot === SLOT.machine ? [SLOT.side, SLOT.side_dark] : [slot, slot];
    for (let i = 0; i < ring.length; i++) {
      const j = (i + 1) % ring.length, a = ring[i], b = ring[j];
      const nx = (b[1] - a[1]), ny = -(b[0] - a[0]);
      if (nx + ny <= 1e-3 * Math.hypot(nx, ny)) continue;
      const s = nx - ny < 0 ? sideSlots[0] : sideSlots[1];
      const ha = heights[i] > 0, hb = heights[j] > 0;
      if (ha && hb) {
        out.push({ slot: s, pts: [top(i), top(j), v(b, base)] });
        out.push({ slot: s, pts: [top(i), v(b, base), v(a, base)] });
      } else if (ha) out.push({ slot: s, pts: [top(i), v(b, base), v(a, base)] });
      else if (hb) out.push({ slot: s, pts: [top(j), v(b, base), v(a, base)] });
    }
  }
  const WEDGE_HIGH = { '+x': [1, 0, 0, 1], '-x': [0, 1, 1, 0], '+y': [1, 1, 0, 0], '-y': [0, 0, 1, 1] };

  function partsOf(shape, detail, variant) {
    if (variant && shape.damage_variants && shape.damage_variants[variant]) return shape.damage_variants[variant].parts;
    if (detail > 0 && shape.parts_by_detail && shape.parts_by_detail[detail]) return shape.parts_by_detail[detail];
    return shape.parts;
  }

  // opts: heading (rad), turret (rad or null), detail (0..2), variant (damage stage 0..2), rise (0..1)
  function projectShape(shape, opts) {
    opts = opts || {};
    const detail = opts.detail == null ? 1 : opts.detail;
    const hull = bucket(opts.heading || 0);
    const turretBucket = opts.turret != null && shape.has_turret ? bucket(opts.turret) : hull;
    const out = [];
    for (const part of partsOf(shape, detail, opts.variant)) {
      const pb = part.angle === 'turret' ? turretBucket : hull;
      const angle = part.angle === 'fixed' ? 0 : (pb * TAU) / BUCKETS;
      const centre = rot(part.pivot[0], part.pivot[1], (hull * TAU) / BUCKETS);
      for (const prim of backToFront(part.prims, angle)) {
        let corners;
        if (prim.type === 'cylinder') {
          const n = SEGMENTS[Math.min(Math.max(detail, 0), 2)];
          corners = [];
          for (let i = 0; i < n; i++) { const a = (TAU * (i + 0.5)) / n; corners.push([(Math.cos(a) * prim.size[0]) / 2, (Math.sin(a) * prim.size[0]) / 2]); }
        } else {
          const hx = prim.size[0] / 2, hy = prim.size[1] / 2;
          corners = [[-hx, -hy], [hx, -hy], [hx, hy], [-hx, hy]];
        }
        const ring = corners.map((c) => { const r = rot(prim.offset[0] + c[0], prim.offset[1] + c[1], angle); return [centre[0] + r[0], centre[1] + r[1]]; });
        if (prim.type === 'wedge') { // not in the game
          const hi = WEDGE_HIGH[prim.low];
          if (!hi) throw new Error('wedge needs low: "+x", "-x", "+y" or "-y", got ' + prim.low);
          appendWedge(out, ring, prim.offset[2] * Z_SCALE, hi.map((k) => k * prim.size[2] * Z_SCALE), prim.slot);
        } else appendPrim(out, ring, prim.offset[2] * Z_SCALE, prim.size[2] * Z_SCALE, prim.slot);
      }
    }
    const rise = opts.rise == null ? 1 : opts.rise;
    if (rise < 1) for (const t of out) t.pts = t.pts.map((p) => [p[0], p[1] + p[2] * (1 - rise), p[2]]); // construction: sink by lift * (1 - rise)
    return out;
  }

  const shadeHex = (hex, k) => {
    if (!k) return hex;
    const n = parseInt(hex.slice(1), 16);
    return '#' + [16, 8, 0].map((sh) => Math.round(((n >> sh) & 255) * k).toString(16).padStart(2, '0')).join('');
  };

  // opts: x, y (anchor px on the canvas), zoom, heading, turret, rise (0..1, construction: lowers every vertex by lift * (1 - rise)), slots (8 hex strings), flat (hex or null), twoTone ([top-face hex, other-face hex] silhouette, ignored when flat), quality, variant, shadow, seam
  function drawShape(ctx, shape, opts) {
    const zoom = opts.zoom || 1;
    const detail = opts.detail == null ? detailFor(zoom, opts.quality) : opts.detail;
    const tris = projectShape(shape, { heading: opts.heading, turret: opts.turret, detail, variant: opts.variant, rise: opts.rise });
    const lift = shape.layer === 'air' ? AIR_LIFT : 0;
    ctx.save();
    ctx.translate(opts.x, opts.y - lift * zoom);
    ctx.scale(zoom, zoom);
    if (opts.shadow) {
      const r = shape.layer === 'air' ? SHADOW.air : SHADOW.ground;
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.beginPath(); ctx.moveTo(0, lift - r); ctx.lineTo(r, lift); ctx.lineTo(0, lift + r); ctx.lineTo(-r, lift); ctx.closePath(); ctx.fill();
    }
    const seam = opts.seam == null ? 0.5 : opts.seam;
    ctx.lineJoin = 'round';
    ctx.lineWidth = seam / zoom;
    for (const t of tris) {
      const colour = opts.flat || (opts.twoTone ? opts.twoTone[t.top ? 0 : 1] : shadeHex(opts.slots[t.slot], t.shade));
      ctx.fillStyle = colour; ctx.strokeStyle = colour;
      ctx.beginPath(); ctx.moveTo(t.pts[0][0], t.pts[0][1]); ctx.lineTo(t.pts[1][0], t.pts[1][1]); ctx.lineTo(t.pts[2][0], t.pts[2][1]); ctx.closePath();
      ctx.fill();
      if (seam > 0) ctx.stroke();
    }
    ctx.restore();
  }


  // Counts what projectShape emits (same code path as drawing). shapeOrParts: a shape or a bare parts list.
  function countTriangles(shapeOrParts, zoom, heading, variant) {
    const shape = Array.isArray(shapeOrParts) ? { parts: shapeOrParts } : shapeOrParts;
    return projectShape(shape, { heading: heading || 0, detail: detailFor(zoom || 1), variant }).length;
  }
  function countPrims(shapeOrParts) {
    const parts = Array.isArray(shapeOrParts) ? shapeOrParts : shapeOrParts.parts;
    return parts.reduce((n, p) => n + p.prims.length, 0);
  }

  // Ported from the game's shape audit (tests/test_shape_audit.gd: _raster, SA2, SA4), read-only reference, heading 0.
  // Painter: "wrong" = a far surface painted over a nearer one of another slot; "covered" = a part hidden entirely by later parts.
  // Footprint: every vertex inside +-footprint/2 on both axes. Shapes with a wedge prim are checked for footprint only.
  function auditRaster(tris, parts) {
    let lo = [1e9, 1e9], hi = [-1e9, -1e9];
    tris.forEach((t) => t.p.forEach((q) => { lo = [Math.min(lo[0], q[0]), Math.min(lo[1], q[1])]; hi = [Math.max(hi[0], q[0]), Math.max(hi[1], q[1])]; }));
    const w = Math.ceil(hi[0] - lo[0]) + 1, h = Math.ceil(hi[1] - lo[1]) + 1;
    const painter = new Int32Array(w * h).fill(-1), near = new Int32Array(w * h).fill(-1), nearD = new Float32Array(w * h);
    const bary = (t, px, py) => {
      const [a, b, c] = t.p, den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]);
      if (Math.abs(den) < 1e-9) return null;
      const l0 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / den, l1 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / den;
      return [l0, l1, 1 - l0 - l1];
    };
    const depthAt = (t, l) => l[0] * t.d[0] + l[1] * t.d[1] + l[2] * t.d[2];
    tris.forEach((t, idx) => {
      const xs = t.p.map((q) => q[0]), ys = t.p.map((q) => q[1]);
      for (let iy = Math.max(Math.floor(Math.min(...ys) - lo[1]), 0); iy <= Math.min(Math.ceil(Math.max(...ys) - lo[1]), h - 1); iy++) {
        for (let ix = Math.max(Math.floor(Math.min(...xs) - lo[0]), 0); ix <= Math.min(Math.ceil(Math.max(...xs) - lo[0]), w - 1); ix++) {
          const l = bary(t, lo[0] + ix + 0.5, lo[1] + iy + 0.5);
          if (!l || l[0] < -1e-6 || l[1] < -1e-6 || l[2] < -1e-6) continue;
          const d = depthAt(t, l), cell = iy * w + ix;
          painter[cell] = idx;
          if (near[cell] < 0 || d > nearD[cell]) { near[cell] = idx; nearD[cell] = d; }
        }
      }
    });
    let wrong = 0; const seen = new Array(parts).fill(0), shown = new Array(parts).fill(0);
    for (let cell = 0; cell < painter.length; cell++) {
      if (painter[cell] < 0) continue;
      const top = tris[painter[cell]], nr = tris[near[cell]];
      seen[nr.part]++; shown[top.part]++;
      if (painter[cell] !== near[cell] && top.slot !== nr.slot) {
        const l = bary(top, lo[0] + (cell % w) + 0.5, lo[1] + Math.floor(cell / w) + 0.5);
        if (l && nearD[cell] - depthAt(top, l) > 0.02) wrong++;
      }
    }
    return { wrong, covered: seen.map((v, k) => (v > 0 && shown[k] === 0 ? k : -1)).filter((k) => k >= 0) };
  }
  function auditShape(shape) {
    const wedge = shape.parts.some((p) => p.prims.some((q) => q.type === 'wedge'));
    const fp = shape.footprint || [1, 1], issues = [];
    let worstX = 0, worstY = 0;
    [0, 2].forEach((detail) => {
      const tris = [];
      shape.parts.forEach((p, k) => projectShape(Object.assign({}, shape, { parts: [p], damage_variants: null, parts_by_detail: null }), { detail }).forEach((t) => {
        t.pts.forEach((q) => { const gy = (q[1] + q[2]) / 16, gx = q[0] / 32; worstX = Math.max(worstX, Math.abs((gx + gy) / 2)); worstY = Math.max(worstY, Math.abs((gy - gx) / 2)); });
        tris.push({ part: k, slot: t.slot, p: t.pts, d: t.pts.map((q) => (q[1] + q[2]) / 16) });
      }));
      if (!wedge) { const r = auditRaster(tris, shape.parts.length); if (r.wrong) issues.push(`paint order: ${r.wrong} samples at detail ${detail}`); if (r.covered.length) issues.push(`part ${r.covered.join(',')} hidden at detail ${detail}`); }
    });
    const lim = [fp[0] / 2 + 0.001, fp[1] / 2 + 0.001];
    if (worstX > lim[0] || worstY > lim[1]) issues.push(`outside footprint ${fp[0]}x${fp[1]} (reaches ${worstX.toFixed(2)} x ${worstY.toFixed(2)})`);
    return { ok: !issues.length, issues: Array.from(new Set(issues)), wedge };
  }

  // Units, as tests/test_shape_audit.gd does (SA1 radius, SA4 painter), read-only reference: radius over all 64 heading buckets at every
  // detail (hull parts <= 0.5, turret parts <= 0.75 cells from the anchor, +0.001 slack); paint order at the 8 compass headings at
  // detail 0 and 2, and for shapes with a turret also with the turret a quarter turn off the hull.
  function auditUnit(shape) {
    const issues = [];
    const one = (part) => Object.assign({}, shape, { parts: [part], damage_variants: null, parts_by_detail: null });
    let hull = 0, turret = 0;
    [0, 1, 2].forEach((detail) => {
      for (let b = 0; b < BUCKETS; b++) {
        const a = (b * TAU) / BUCKETS;
        shape.parts.forEach((p) => projectShape(one(p), { heading: a, turret: a, detail }).forEach((t) => t.pts.forEach((q) => {
          const gy = (q[1] + q[2]) / 16, gx = q[0] / 32, r = Math.hypot((gx + gy) / 2, (gy - gx) / 2);
          if (p.angle === 'turret') turret = Math.max(turret, r); else hull = Math.max(hull, r);
        })));
      }
    });
    const hullLimit = shape.layer === 'air' ? 0.65 : 0.5;
    if (hull > hullLimit + 0.001) issues.push(`hull parts reach ${hull.toFixed(3)} cells (limit ${hullLimit})`);
    if (turret > 0.751) issues.push(`turret parts reach ${turret.toFixed(3)} cells (limit 0.75)`);
    const bad = {}, notes = [];
    for (let k = 0; k < 8; k++) [0, 2].forEach((detail) => (shape.has_turret ? [0, 16] : [0]).forEach((off) => {
      const a = (k * 8 * TAU) / BUCKETS, ta = a + (off * TAU) / BUCKETS, tris = [];
      shape.parts.forEach((p, i) => projectShape(one(p), { heading: a, turret: ta, detail }).forEach((t) => tris.push({ part: i, slot: t.slot, p: t.pts, d: t.pts.map((q) => (q[1] + q[2]) / 16) })));
      const r = auditRaster(tris, shape.parts.length);
      // The game samples only headings 0 and 4 (buckets 0, 32) and demands 0 wrong samples there. The other six headings are this page's
      // extension: up to 2 wrong samples (one raster pixel of noise on a thin weapon) is noted, not failed.
      const tol = k % 4 === 0 ? 0 : 2;
      if (r.wrong > tol) (bad.wrong = bad.wrong || []).push(`${k}`);
      else if (r.wrong) notes.push(`heading ${k}: ${r.wrong} sample(s), within tolerance`);
      if (r.covered.length) (bad.hidden = bad.hidden || []).push(`${k}`);
    }));
    if (bad.wrong) issues.push(`paint order wrong at heading(s) ${Array.from(new Set(bad.wrong)).join(',')} of 8`);
    if (bad.hidden) issues.push(`a part is hidden at heading(s) ${Array.from(new Set(bad.hidden)).join(',')} of 8`);
    return { ok: !issues.length, issues, notes: Array.from(new Set(notes)), wedge: false, unit: true };
  }
  const auditAny = (shape) => (shape.footprint ? auditShape(shape) : auditUnit(shape));

  const api = { projectShape, drawShape, countTriangles, countPrims, auditShape, auditUnit, auditAny, bucket, detailFor, SLOT, SLOPE_SHADE, TAU };
  if (typeof module !== 'undefined') module.exports = api;
  else Object.assign(root, api);
})(typeof window !== 'undefined' ? window : globalThis);
