'use strict';
// Stage controls: a step (or its round) turns them on through `controls`. Values are page-wide, so a window size or ground stays from step to step.
const SIZES = {
  '1280x720': { w: 1280, h: 720, k: 1, label: '1280 x 720' },
  '1280x800': { w: 1280, h: 800, k: 1, label: '1280 x 800' },
  '1920x1080': { w: 1280, h: 720, k: 1.5, label: '1920 x 1080' },
  '3440x1440': { w: 1720, h: 720, k: 2, label: '3440 x 1440' },
};
const WORLDS = ['none', 'one', 'many', 'factory', 'plant', 'builder', 'build', 'place', 'blocked', 'enemy', 'pile', 'site'];
// game/scripts/presentation/palette.gd OWNER_BASE and OWNER_BRIGHT.
const OWNER_SETS = {
  default: ['376eac', 'b04a3a', '3f8f4f', 'c9a227', 'd27a2c', '7a4fa0', '2f9c9c', 'c8628f'],
  neon: ['2f7bff', 'ff2f45', '14d45a', 'ffe100', 'ff7a00', 'a040ff', '00d8e8', 'ff4fb0'],
};
const CVD = { // Machado 2009, severity 1, on linear RGB (as p2-3a1-states.html #cvd).
  deut: [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413, -0.01182, 0.04294, 0.968881],
  prot: [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216, -0.003882, -0.048116, 1.051998],
};
const cap1 = (v) => v.charAt(0).toUpperCase() + v.slice(1);
const CTL = {
  size: { key: 's', label: 'Window', values: Object.keys(SIZES), name: (v) => SIZES[v].label, omit: '1280x720' },
  fit: { key: 'f', label: 'Scale', values: ['fit', '100'], name: (v) => (v === 'fit' ? 'Fit' : 'True 100 %'), app: true },
  ground: { key: 'g', label: 'Ground', values: ['sand', 'dark'], name: cap1 },
  world: { key: 'shift+g', label: 'Backdrop', values: ['plain', ...WORLDS], name: (v) => (v === 'plain' ? 'Plain ground' : `World: ${v}`), omit: 'plain' },
  zoom: { key: 'z', label: 'Zoom', values: ['0.5', '1', '2'] },
  hud: { key: 'h', label: 'HUD', values: ['on', 'off'], name: cap1, omit: 'on' },
  state: { key: 'n', label: 'State', values: [] },
  tier: { key: 't', label: 'Tier', values: ['full', 'core'], name: cap1 },
  owner: { key: 'o', label: 'Owner', values: ['drawn', '1', '2', '3', '4', '5', '6', '7', '8'], name: (v) => (v === 'drawn' ? 'As drawn' : `P${v}`), omit: 'drawn' },
  set: { key: 'shift+o', label: 'Colours', values: ['default', 'neon'], name: cap1, app: true },
  heading: { key: 'r', label: 'Heading', values: ['0', '1', '2', '3', '4', '5', '6', '7'], name: (v) => `${v * 45}°` },
  cvd: { key: 'shift+c', label: 'Colour vision', values: ['normal', 'deut', 'prot'], name: (v) => ({ normal: 'Normal', deut: 'Deuteranopia', prot: 'Protanopia' })[v], app: true },
  marker: { key: 'm', label: 'Marker', values: ['on', 'off'], name: cap1, app: true },
};
const CTL_ORDER = Object.keys(CTL);
const keyLabel = (k) => k.replace('shift+', '⇧').toUpperCase();
const STATES_PAGE = 'docs/images/hud-v5/source/p2-3a1-states.html';
const DEFAULT_RENDER = { page: STATES_PAGE, w: 1280, h: 720, hash: 'shot={state}&size=720&scale=1' };

function ctlSpecs(s) {
  return { ...((S.round && S.round.controls) || {}), ...((s && s.controls) || {}) };
}
function ctlDef(s, name) {
  const spec = ctlSpecs(s)[name];
  if (name.startsWith('x-')) {
    const x = (ctlSpecs(s).extra || []).find((e) => `x-${e.id}` === name);
    return x && { key: x.key || '', label: x.label || x.id, values: x.values.map((v) => v.v ?? v), name: (v) => ((x.values.find((y) => (y.v ?? y) === v) || {}).label || v), param: x.param || x.id };
  }
  if (spec === undefined || !CTL[name]) return null;
  const base = CTL[name];
  if (name === 'hud' && Array.isArray(spec)) return { ...base, values: ['off', ...spec], name: (v) => (v === 'off' ? 'Off' : `Layer: ${v}`), overlay: true };
  if (Array.isArray(spec)) return { ...base, values: spec };
  return base;
}
const STAGED = new Set(['pictures', 'gallery']);
function ctlsOf(s) {
  if (!s || !STAGED.has(s.kind)) return [];
  const extra = (ctlSpecs(s).extra || []).map((x) => `x-${x.id}`);
  return [...CTL_ORDER, ...extra].map((n) => [n, ctlDef(s, n)]).filter(([, d]) => d && d.values.length);
}
function ctl(s, name) {
  const d = ctlDef(s, name);
  if (!d) return null;
  return d.values.includes(S.ctl[name]) ? S.ctl[name] : d.values[0];
}
// A game-world backdrop covers the ground colour, so Ground would claim a change the picture does not show.
function ctlOff(s, name) {
  return name === 'ground' && (ctl(s, 'world') || 'plain') !== 'plain' ? 'n/a with a backdrop' : '';
}
function cycleCtl(name, dir = 1) {
  const s = cur(), d = ctlDef(s, name);
  if (!d || ctlOff(s, name) || d.values.length < 2) return false;
  const i = d.values.indexOf(ctl(s, name));
  setCtl(name, d.values[(i + dir + d.values.length) % d.values.length]);
  return true;
}
function setCtl(name, v) {
  flush();
  S.ctl[name] = v;
  render();
}

// ---------- what the controls do to a live render ----------
function renderBase(r) { return { ...DEFAULT_RENDER, ...(S.round.render || {}), ...((cur() && cur().render) || {}), ...r }; }
function ownerHex(s) {
  const o = ctl(s, 'owner');
  return o && o !== 'drawn' ? OWNER_SETS[ctl(s, 'set') || 'default'][+o - 1] : null;
}
function ctlParams(s, r) {
  const pass = renderBase(r).pass || {}, out = {};
  ctlsOf(s).forEach(([n, d]) => {
    const param = d.param || pass[n], v = ctl(s, n);
    if (!param || v === d.omit || d.overlay) return;
    if (n === 'size') {
      const z = SIZES[v];
      if (`${z.w}x${z.h}` !== '1280x720') out[param] = `${z.w}x${z.h}`;
      if (z.k !== 1) out.scale = z.k;
    } else if (n === 'owner') out[param] = ownerHex(s);
    else if (n === 'hud') out[param] = '0';
    else out[param] = v;
  });
  return out;
}
function sizeOf(s, r) {
  const b = renderBase(r), w = b.w || 1280, h = b.h || 720, pass = b.pass || {};
  const v = pass.size && ctl(s, 'size');
  if (!v) return { w, h, lw: w, lh: h, k: 1 };
  const z = SIZES[v];
  return { w: z.w * z.k, h: z.h * z.k, lw: z.w, lh: z.h, k: z.k };
}
// A crop is drawn for the 1280x720 frame; on another window size it keeps to the edge it sits nearer, as the HUD does.
function cropFor(c, base, z) {
  if (!c) return { x: 0, y: 0, w: z.w, h: z.h };
  const dx = c.x + c.w / 2 > base.w / 2 ? z.lw - base.w : 0, dy = c.y + c.h / 2 > base.h / 2 ? z.lh - base.h : 0;
  return { x: (c.x + dx) * z.k, y: (c.y + dy) * z.k, w: c.w * z.k, h: c.h * z.k };
}
function stateFor(s, r) { return r.state ?? ctl(s, 'state') ?? 'slab'; }
function hudLayer(s, z) {
  const d = ctlDef(s, 'hud'), v = ctl(s, 'hud');
  if (!d || !d.overlay || v === 'off') return '';
  const size = `${z.lw}x${z.lh}` === '1280x720' ? '720' : `${z.lw}x${z.lh}`;
  return `<iframe tabindex="-1" title="HUD layer" class="hudlayer" src="${esc(url(STATES_PAGE))}#shot=${encodeURIComponent(v)}&size=${size}&scale=${z.k}&ground=none" style="width:${z.w}px;height:${z.h}px;left:0;top:0"></iframe>`;
}
function marksOf(s, src) {
  const marks = [].concat(src.mark || (s && s.mark) || []);
  return marks.length && ctl(s, 'marker') === 'on' ? marks : [];
}
// A label hangs toward the frame's middle, so a right-edge one is not cut off; `below` keeps it off a caption above the ring.
const markEl = (style, m, frameW) => `<i class="mark" style="${style}">${m.label ? `<b class="${m.x + m.w / 2 > frameW / 2 ? 'r' : ''}${m.below ? ' u' : ''}">${esc(m.label)}</b>` : ''}</i>`;
function marksHtml(s, src, c, z, base) {
  return marksOf(s, src).map((m) => {
    const r = cropFor(m, base, z);
    return markEl(`left:${r.x - c.x}px;top:${r.y - c.y}px;width:${r.w}px;height:${r.h}px`, m, base.w);
  }).join('');
}
function imgMarks(s, src) {
  const of = src.of || [1280, 720], pc = (v, t) => `${(v / t) * 100}%`;
  return marksOf(s, src).map((m) => markEl(`left:${pc(m.x, of[0])};top:${pc(m.y, of[1])};width:${pc(m.w, of[0])};height:${pc(m.h, of[1])}`, m, of[0])).join('');
}

// ---------- page-side effects ----------
function applyStageClasses(s) {
  const b = document.body;
  b.dataset.cvd = (s && ctl(s, 'cvd')) || 'normal';
  b.classList.toggle('true100', !!s && ctl(s, 'fit') === '100');
  document.documentElement.style.setProperty('--dpr', String(devicePixelRatio || 1));
}
function cvdDefs() {
  const m = (a) => `${a.slice(0, 3).join(' ')} 0 0 ${a.slice(3, 6).join(' ')} 0 0 ${a.slice(6).join(' ')} 0 0 0 0 0 1 0`;
  return `<svg width="0" height="0" style="position:absolute" aria-hidden="true">${Object.entries(CVD).map(([k, a]) => `<filter id="dp-${k}" color-interpolation-filters="linearRGB"><feColorMatrix type="matrix" values="${m(a)}"/></filter>`).join('')}</svg>`;
}
window.DPnat = (img) => { img.style.setProperty('--nw', img.naturalWidth); };

// ---------- numbers: contrast and colour distance ----------
const lin = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
const linOf = (h) => [1, 3, 5].map((i) => lin(parseInt(h.slice(i, i + 2), 16) / 255));
const simulate = (l, m) => (m ? [0, 1, 2].map((r) => Math.min(1, Math.max(0, m[r * 3] * l[0] + m[r * 3 + 1] * l[1] + m[r * 3 + 2] * l[2]))) : l);
const lumOf = (l) => 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2];
function labOf(l) {
  const f = (t) => (t > 216 / 24389 ? Math.cbrt(t) : ((24389 / 27) * t + 16) / 116);
  const x = (0.4124 * l[0] + 0.3576 * l[1] + 0.1805 * l[2]) / 0.95047, y = lumOf(l), z = (0.0193 * l[0] + 0.1192 * l[1] + 0.9505 * l[2]) / 1.08883;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}
function pairNumbers(a, b) {
  const la = linOf(a), lb = linOf(b), [hi, lo] = [lumOf(la), lumOf(lb)].sort((p, q) => q - p);
  const de = (m) => Math.hypot(...labOf(simulate(la, m)).map((v, i) => v - labOf(simulate(lb, m))[i]));
  return { contrast: (hi + 0.05) / (lo + 0.05), normal: de(null), deut: de(CVD.deut), prot: de(CVD.prot) };
}
// Bars: WCAG 3:1 for large text and UI parts; 20 is the project's colour-distance bar (map art audit).
// Contrast only means something for a colour on its background ('on', the default), not for two colours told apart ('vs').
function numbersHtml(s) {
  if (!s || !s.pairs || !s.pairs.length || !S.numbers) return '';
  const sw = (h) => `<i class="sw" style="background:${esc(h)}"></i>`;
  const cell = (v, bar, d = 1) => `<td class="${v < bar ? 'low' : ''}">${v.toFixed(d)}</td>`;
  const rows = s.pairs.map(([an, ah, bn, bh, kind]) => {
    const n = pairNumbers(ah, bh), contrast = kind === 'vs' ? '<td>–</td>' : cell(n.contrast, 3, 2);
    return `<tr><th>${sw(ah)}${esc(an)} <span>${esc(ah)}</span><br>${sw(bh)}${esc(bn)} <span>${esc(bh)}</span></th>${contrast}${cell(n.normal, 20)}${cell(n.deut, 20)}${cell(n.prot, 20)}</tr>`;
  }).join('');
  return `<section class="numbers"><span class="h">Numbers (K hides)</span><table><tr><th></th><th>Contrast</th><th>ΔE</th><th>Deut.</th><th>Prot.</th></tr>${rows}</table>` +
    '<p>Contrast: WCAG, for a colour on its background, under 3:1 marked; – for two colours that only need to differ. ΔE: CIE76 distance as seen normally and with simulated deuteranopia and protanopia (Machado 2009), under 20 marked.</p></section>';
}

// ---------- bars and legend ----------
function ctlButton(s, n, d) {
  const v = ctl(s, n), off = ctlOff(s, n), name = off || (d.name ? d.name(v) : v), k = d.key ? `<kbd>${esc(keyLabel(d.key))}</kbd>` : '';
  if (d.values.length > 4) {
    const opts = d.values.map((x) => `<option value="${esc(x)}"${x === v ? ' selected' : ''}>${esc(d.name ? d.name(x) : x)}</option>`).join('');
    return `<label class="cb sel">${k}<span>${esc(d.label)}</span><select data-ctlsel="${esc(n)}">${opts}</select></label>`;
  }
  return `<button class="cb" data-ctl="${esc(n)}"${off ? ' disabled' : ''}>${k}<span>${esc(d.label)}:</span> ${esc(name)}</button>`;
}
function ctlBarHtml(s) {
  const list = ctlsOf(s);
  const nums = s && s.pairs && s.pairs.length ? `<button class="cb" data-act="numbers"><kbd>K</kbd><span>Numbers:</span> ${S.numbers ? 'shown' : 'hidden'}</button>` : '';
  if (!list.length && !nums) return '';
  return `<div class="ctlbar">${list.map(([n, d]) => ctlButton(s, n, d)).join('')}${nums}</div>`;
}
function ctlLegendRows(s) {
  const on = new Set(ctlsOf(s).map(([n]) => n));
  const rows = CTL_ORDER.map((n) => [keyLabel(CTL[n].key) + (n === 'state' ? ' P' : n === 'heading' ? ' ⇧R' : ''), `${CTL[n].label.toLowerCase()}: ${CTL[n].values.length ? CTL[n].values.map((v) => (CTL[n].name ? CTL[n].name(v) : v)).slice(0, 4).join(' / ') : 'next / previous'}${CTL[n].values.length > 4 ? ' ...' : ''}`, on.has(n)]);
  rows.push(['K', 'numbers panel (contrast, colour distance)', !!(s && s.pairs)]);
  (ctlSpecs(s).extra || []).forEach((x) => rows.push([x.key ? keyLabel(x.key) : '(button)', `${x.label || x.id} (this step)`, true]));
  return rows;
}
// Every app key, so a step's extra control cannot take one.
const APP_KEYS = new Set(['a', 'b', 'c', 'd', '1', '2', '3', '4', 'w', 'enter', 'arrowleft', 'arrowright', '[', ']', 'backspace', 'n', 'p', 'l', ' ', '?', 'k', 'shift+r', ...Object.values(CTL).map((c) => c.key)]);

function checkControls(r, s) {
  const where = `${r.id}/${s.key}`, specs = { ...(r.controls || {}), ...(s.controls || {}) }, pass = (s.render && s.render.pass) || (r.render && r.render.pass) || {};
  Object.keys(specs).forEach((n) => {
    if (n === 'extra') return;
    if (!CTL[n]) { addErr(`${where}: unknown control ${n}`); return; }
    const used = CTL[n].app || pass[n] || n === 'state' || (n === 'hud' && Array.isArray(specs[n])) || (n === 'set' && specs.owner);
    if (!used) addErr(`${where}: control ${n} does nothing here (the render page does not take it: render.pass.${n})`);
  });
  if (specs.state !== undefined && !(Array.isArray(specs.state) && specs.state.length)) addErr(`${where}: control state needs a list of states`);
  Object.entries(specs).filter(([n, v]) => CTL[n] && CTL[n].values.length && n !== 'hud' && Array.isArray(v)).forEach(([n, v]) => {
    v.filter((x) => !CTL[n].values.includes(x)).forEach((x) => addErr(`${where}: control ${n} has no value ${x}`));
  });
  (specs.extra || []).forEach((x) => {
    if (!x.id || !Array.isArray(x.values) || !x.values.length) addErr(`${where}: extra control needs id and values`);
    if (x.key && APP_KEYS.has(x.key)) addErr(`${where}: extra control ${x.id} key ${x.key} is taken by the app`);
  });
}
function ctlHash(s, p) {
  ctlsOf(s).forEach(([n, d]) => { const v = ctl(s, n); if (v !== d.values[0]) p.set(n, v); });
}
function ctlFromHash(h) {
  [...CTL_ORDER, ...[...h.keys()].filter((k) => k.startsWith('x-'))].forEach((n) => { const v = h.get(n); if (v !== null) S.ctl[n] = v; });
}
