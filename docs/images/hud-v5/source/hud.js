window.HUDV5 = (() => {
const SIZES = {'1920x1080': {w: 1920, h: 1080, k: 1.5}, '1280x800': {w: 1280, h: 800, k: 1}, '1280x720': {w: 1280, h: 720, k: 1}};
const STATES = ['none', 'one', 'many', 'factory', 'plant', 'full', 'builder', 'build', 'place', 'blocked', 'enemy', 'pile', 'site'];
const FONT = "'Public Sans', Arial, sans-serif";
const DOCK = 168, SEL_W = 408, PIN_W = 220, GAP = 8, STRIP = 32;
const CELL_PAD = 8;
const CELL = {two: {w: 100, h: 60}, one: {w: 148, h: 40}};
const cardWidth = o => 4 + 8 + 4 * CELL[o.cell].w + 3 * 4 + 8;
const LATTICE = ['QWER', 'ASDF', 'ZXCV'].map(r => [...r]);
const REFUSAL = 'Cannot build here';

const luminance = hex => {
  const [r, g, b] = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255).map(c => c <= .03928 ? c / 12.92 : ((c + .055) / 1.055) ** 2.4);
  return .2126 * r + .7152 * g + .0722 * b;
};
const contrast = (a, b) => { const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x); return (hi + .05) / (lo + .05); };
const mix = (a, b, t) => '#' + [1, 3, 5].map(i => Math.round(parseInt(a.slice(i, i + 2), 16) * (1 - t) + parseInt(b.slice(i, i + 2), 16) * t).toString(16).padStart(2, '0')).join('');
const BG = '#121c24';
function lifted(hex) {
  for (let i = 0; i <= 20; i++) { const c = mix(hex, '#ffffff', i * .05); if (contrast(c, BG) >= 3) return c; }
  return '#ffffff';
}
const OWNERS = [['Blue (you)', '#628ffa'], ['Red (enemy)', '#d6120c'], ['Green', '#4ad49b'], ['Gold', '#f8e425'], ['Teal', '#0e92a7'], ['Purple', '#7242fe'], ['Orange', '#ec8600'], ['Pink', '#f79cef']];
const FLAT = {bg: BG, panel: '#1b2731', btn: '#223241', panel2: '#26384a', line: '#2e3f4b', edge: '#263842', well: '#0c141a', text: '#eef3f5', muted: '#93a5b0',
  sel: '#60e5ed', amber: '#f7c871', you: lifted(OWNERS[0][1]), enemy: lifted(OWNERS[1][1]), ally: '#69ceaa', quiet: '#16212a', warn: '#f47b6c', r: '0'};
const HEALTH = ['#5cc85a', '#e0d060', '#d8453a'];
const GLYPH_KEY = {
  'Medium Tank': 'china_light_vehicle', 'Rotary Gun Tank': 'china_tank', 'Militia': 'china_rifle_infantry',
  'Anti-Tank Trooper': 'china_rocket_infantry', 'Supply Truck': 'china_collector', 'Bulldozer': 'china_builder',
  'Power Plant': 'china_power_plant', 'Supply Depot': 'china_supply_center', 'Barracks': 'china_barracks',
  'Vehicle Factory': 'china_factory', 'Rotary Gun Tower': 'china_defence', 'Headquarters': 'china_command_center'};
const COMMAND_GLYPHS = new Set(['attack_move', 'guard', 'stop', 'sell', 'build']);
const PAGE_GLYPH = {build: '<path d="M2 11H13V22H2Z"/><path d="M17 2H20V6H23V9H20V13H17V9H14V6H17Z"/>'};
const BASE = {credits: 4800, power: 8, avail: 10};
const DATA = {
  none: {...BASE, ring: true, alert: true}, one: {...BASE}, many: {...BASE, power: 11, offline: true, alert: true},
  factory: {...BASE, credits: 650, hover: 'Rotary Gun Tank'}, plant: {...BASE},
  full: {...BASE, hover: 'Medium Tank', queue: ['Medium Tank', 'Medium Tank', 'Rotary Gun Tank', 'Medium Tank', 'Rotary Gun Tank', 'Rotary Gun Tank', 'Medium Tank', 'Medium Tank', 'Rotary Gun Tank']},
  builder: {...BASE},
  build: {...BASE, credits: 2400, power: 0, avail: 0, early: true, hover: 'Supply Depot'},
  place: {...BASE, armed: 'Rotary Gun Tower'}, blocked: {...BASE, armed: 'Vehicle Factory', refuse: true},
  enemy: {...BASE}, pile: {...BASE}, site: {...BASE},
  // P2.3b states, Core only (plan T0): pointer marks without a card are `pointer`, a hovered queue tile is `tile`.
  'hover-cell': {...BASE, hover: 'Rotary Gun Tank', queue: []}, 'hover-tile': {...BASE, tile: 1},
  press: {...BASE, credits: 800, pointer: 'Vehicle Factory', refuse: '1200 credits short'},
  builders: {...BASE, hover: 'Build'}, 'none-refuse': {...BASE, refuse: 'Select a Bulldozer'},
  'two-cause': {...BASE, credits: 1000, owns: [], frc: true, hover: 'Vehicle Yard'}};
const NEW_STATES = ['hover-cell', 'hover-tile', 'press', 'builders', 'none-refuse', 'two-cause'];
const MENU_OPEN = new Set(['build', 'place', 'blocked', 'press', 'two-cause']);
const FACTORY_STATES = new Set(['factory', 'full', 'hover-cell', 'hover-tile']);
const KINDS = [['Medium Tank', 36, 82], ['Rotary Gun Tank', 24, 64], ['Militia', 24, 91], ['Anti-Tank Trooper', 12, 45], ['Supply Truck', 12, 100], ['Bulldozer', 12, 100]];
const GROUPS = [[1, 36], [2, 24], [3, 12]];
const PRODUCING = [['Medium Tank', 42, 'Vehicle Factory'], ['Bulldozer', 60, 'Headquarters']];
const QUEUE = ['Medium Tank', 'Medium Tank', 'Rotary Gun Tank', 'Medium Tank'];
const FACTORY_KEY = {'Medium Tank': 'Q', 'Rotary Gun Tank': 'W'};
// [cost, seconds, power, prerequisite]: seconds are definition ticks / 30 (china.gd)
const CELLS = {'Medium Tank': [800, 10], 'Rotary Gun Tank': [800, 10], 'Power Plant': [1000, 10, {avail: 10}], 'Supply Depot': [1500, 10, {used: 1}, 'Power Plant'],
  'Barracks': [500, 10], 'Vehicle Factory': [2000, 15, {used: 1}, 'Supply Depot'], 'Rotary Gun Tower': [1200, 25, {used: 3}, 'Power Plant'],
  'Supply Cache': [1500, 10], 'Vehicle Yard': [2500, 15, null, 'Supply Cache'], 'Tunnel Hub': [800, 15, null, 'Barracks']};
// hud_model.gd COUNTER_LINES; the game breaks a line too wide for the card between its claims.
const COUNTER = {'Medium Tank': ['Beats light vehicles'], 'Rotary Gun Tank': ['Good against infantry at full spin', 'Weak against tanks']};
const INCOME = 1350, SPEND = 1600;

// Core draws plain digits as built (gate A, user 2026-11-19); hud() and updateCard set it per tier.
let plain = false;
const num = n => plain ? String(n) : n.toLocaleString('en-US');
const px = n => `${n}px`;
const isCore = v => v.tier === 'core';
const queueOf = v => DATA[v.state].queue || QUEUE;
const isFull = v => queueOf(v).length >= 9;
const queued = (v, name) => queueOf(v).filter(n => n === name).length;

let glyphSet = [];
const loadGlyphs = () => { glyphSet = [PAGE_GLYPH, ...(typeof GLYPH3 !== 'undefined' ? [GLYPH3] : []), ...(typeof GLYPH !== 'undefined' ? [GLYPH] : [])]; };
const glyphFor = name => glyphSet.map(set => set[name]).find(Boolean);
function glyph(name, px) {
  const g = glyphFor(name), s = `width:${px}px;height:${px}px`;
  if (!g) return `<span class="gl" style="${s}"></span>`;
  const vb = COMMAND_GLYPHS.has(name) ? 24 : 48;
  return `<svg class="gl" viewBox="0 0 ${vb} ${vb}" style="${s}" fill="currentColor">${g}</svg>`;
}
const unitGlyph = (name, px) => glyph(GLYPH_KEY[name], px);
const hpColor = p => p > 66 ? HEALTH[0] : p > 33 ? HEALTH[1] : HEALTH[2];
const bar = (pct, w, h, color) => `<i class="hp" style="width:${w}px;height:${h}px"><b style="width:${pct}%;background:${color}"></b></i>`;
const hpBar = (pct, w, h) => bar(pct, w, h, hpColor(pct));
const key = k => `<span class="k">${k}</span>`;
const borders = (t, r, b, l) => `border-width:${[t, r, b, l].map(px).join(' ')}`;

function slab({left, width, height, edge, border, pad}) {
  const padding = pad.map((p, i) => px(p - border[i])).join(' ');
  return `left:${left}px;bottom:0;width:${width}px;${height ? `height:${height}px;` : ''}border-width:${border.map(px).join(' ')};padding:${padding};${edge ? `box-shadow:inset 4px 0 0 ${edge}` : ''}`;
}

function minimap(v, size) {
  const d = DATA[v.state], mid = size / 2;
  if (d.offline) {
    return `<svg width="${size}" height="${size}"><rect width="${size}" height="${size}" fill="#0c141a"/>
      <text x="${mid}" y="${mid - 4}" text-anchor="middle" fill="#93a5b0" font-size="12" font-weight="700" letter-spacing="1.44">RADAR OFFLINE</text>
      <text x="${mid}" y="${mid + 16}" text-anchor="middle" fill="#f7c871" font-size="12">Low power</text></svg>`;
  }
  // Allegiance by shape as well as hue: own square, enemy diamond, ally disc.
  const SHAPE = {
    own: (x, y) => `<rect x="${x}" y="${y}" width="5" height="5" fill="${FLAT.you}"/>`,
    enemy: (x, y) => `<path d="M${x + 3} ${y - 1} ${x + 7} ${y + 3} ${x + 3} ${y + 7} ${x - 1} ${y + 3}z" fill="${OWNERS[1][1]}"/>`,
    ally: (x, y) => `<circle cx="${x + 3}" cy="${y + 3}" r="3.5" fill="${FLAT.ally}"/>`};
  const dots = (pts, who) => pts.map(([x, y]) => SHAPE[who](x, y)).join('');
  return `<svg width="${size}" height="${size}"><rect width="${size}" height="${size}" fill="#2f352e"/>
    <rect x="86" y="14" width="40" height="30" fill="#252a24"/><rect x="20" y="58" width="30" height="40" fill="#252a24"/>
    ${dots([[18, 110], [24, 118], [32, 108], [26, 126], [38, 120], [14, 126], [36, 131]], 'own')}
    ${dots([[110, 26], [120, 34], [104, 36], [124, 20]], 'enemy')}${dots([[76, 70]], 'ally')}
    <rect x="9.5" y="92.5" width="56" height="42" fill="none" stroke="#fff"/>
    ${d.ring ? '<circle cx="50" cy="118" r="4" fill="none" stroke="#f7c871" stroke-width="2"/>' : ''}</svg>`;
}

function stat(label, value, extra = '', cls = '') {
  return `<span class="stat ${cls}"><span class="lab">${label}</span><b>${value}</b>${extra}</span>`;
}
const lowPower = '<span class="lab amb">Low power</span>';
const arrow = '<span class="arr">→</span>';
function creditsValue(d, armed) {
  return armed ? `${num(d.credits)} ${arrow} ${num(d.credits - CELLS[armed][0])}` : num(d.credits);
}
function powerValue(d, armed) {
  const used = armed && CELLS[armed][2] && CELLS[armed][2].used;
  if (used) return [`${d.power} ${arrow} ${d.power + used} / ${d.avail}`, d.power + used > d.avail];
  return [`${d.power} / ${d.avail}`, d.power > d.avail];
}
function statusGroup(v) {
  const d = DATA[v.state], [power, low] = powerValue(d, d.armed);
  const rates = isCore(v) ? '' : `<span class="muted num">+${num(INCOME)}</span><span class="muted num">−${num(SPEND)}</span><span class="muted">/ min</span>`;
  return `<div class="g wide">${stat('Credits', creditsValue(d, d.armed), rates, 'cr')}${stat('Power', power, low ? lowPower : '')}</div>`;
}
function helpersGroup() {
  const idle = `<span class="chip">${glyph('china_builder', 18)}<b class="num">1</b>${key('.')}</span>`;
  return `<div class="g">${idle}${GROUPS.map(([n, count]) => `<span class="chip">${key(n)}<b class="num">${count}</b></span>`).join('')}</div>`;
}
function productionGroup() {
  return `<div class="g">${PRODUCING.map(([name, pct, building]) => `<span class="chip" title="${building}">${unitGlyph(name, 18)}<i class="pb"><i style="width:${pct}%"></i></i></span>`).join('')}</div>`;
}
const sep = '<i class="sep"></i>';

// P2.3b top strip round, as built (user, 2026-11-22): two slabs that hug, held at their widest forecast while the pointer is on the card or a building is armed; ported from p2-3a1-states.html topStrip('card').
const ARROW = '<svg width="12" height="8" viewBox="0 0 12 8" style="display:block;flex:none"><path d="M0 4h10.5M7 .5 10.5 4 7 7.5" fill="none" style="stroke:var(--muted)" stroke-width="1.5"/></svg>';
const DOLLAR15 = 'M7 2h1v1H7ZM5 3h5v2H5ZM4 5h2v1H4ZM7 5h1v1H7ZM5 6h5v2H5ZM7 8h1v1H7ZM9 8h2v1H9ZM5 9h5v2H5ZM7 11h1v1H7Z';
const COIN = `<svg width="15" height="15" viewBox="0 0 15 15" style="display:block;flex:none"><circle cx="7.5" cy="7.5" r="7.5" style="fill:var(--warn)"/><path d="${DOLLAR15}" style="fill:var(--quiet)"/></svg>`;
const LOW_POWER = 'Low power · defences off';
const signed = n => n < 0 ? `−${-n}` : String(n);
const isLow = p => p[0] > p[1];
function creditsStat(t) {
  const next = t.after != null && t.after !== t.credits, short = t.after < 0;
  const after = next ? `${ARROW}<span class="neg"><b class="${short ? 'warn' : ''}">${signed(t.after)}</b>${short ? COIN : ''}</span>` : '';
  return `<span class="stat cr"><i class="sw" style="background:var(--you)"></i><span class="lab">Credits</span><b>${t.credits}</b>${after}</span>`;
}
function powerStat(now, after) {
  const next = after && (after[0] !== now[0] || after[1] !== now[1]);
  const words = (next ? isLow(after) && !isLow(now) : isLow(now)) ? `<span class="lab warn">${LOW_POWER}</span>` : '';
  const to = next ? `${ARROW}<b class="${isLow(after) ? 'warn' : ''}">${after[0]} / ${after[1]}</b>` : '';
  return `<span class="stat"><span class="lab">Power</span><b class="${isLow(now) ? 'warn' : ''}">${now[0]} / ${now[1]}</b>${to}${words}</span>`;
}
const forecastKind = d => d.armed || d.pointer || (d.hover && CELLS[d.hover] ? d.hover : null);
function coreStrip(v) {
  const d = DATA[v.state], kind = forecastKind(d), c = kind && CELLS[kind], power = [d.power, d.avail];
  const t = {credits: d.credits, after: c ? d.credits - c[0] : null};
  const pAfter = c && c[2] ? (c[2].used ? [d.power + c[2].used, d.avail] : [d.power, d.avail + c[2].avail]) : null;
  const cOn = t.after != null, pOn = !!pAfter, held = !!kind;
  const hold = (html, widest) => held ? `<span class="rsv">${html}<span class="ghost">${widest}</span></span>` : html;
  const slab = (body, on, id) => `<div class="strip" data-id="${id}" data-cov style="border-width:1px;${on ? 'border-color:var(--sel);' : ''}">${body}</div>`;
  const credits = slab(hold(creditsStat(t), creditsStat({credits: 88888, after: -8888})), cOn, 'top_strip.credits');
  const pw = d.frc ? '' : slab(hold(powerStat(power, pAfter), powerStat([88, 99], [99, 88])), pOn, 'top_strip.power');
  return `<div class="tsrow" data-id="top_strip" style="left:8px;top:8px">${credits}${pw}</div>`;
}
function topStrip(v) {
  if (isCore(v)) return coreStrip(v);
  const parts = isCore(v) ? [statusGroup(v)] : [statusGroup(v), productionGroup()];
  return `<div class="strip" data-id="top_strip" data-cov style="left:8px;top:8px;${borders(1, 1, 1, 1)}">${parts.join(sep)}</div>`;
}
function aboveDock(v, H) {
  const ledge = isCore(v) ? '' : `<div class="strip ledge" data-id="ledge" data-cov style="left:0;top:${H - DOCK - GAP - STRIP}px;${borders(1, 1, 1, 0)}">${helpersGroup()}</div>`;
  const said = DATA[v.state].refuse, text = said === true ? REFUSAL : said;
  // Core as built (gate B, user 2026-11-20): grounded 8 above the screen bottom, centred 12 left of the middle (between panel and card); CSS, so no font-load race.
  const refuse = !said ? '' : isCore(v) ? `<div class="refuse warn" data-id="refusal" style="left:0;right:24px;bottom:8px;margin:0 auto;width:max-content;${borders(1, 1, 1, 1)}"><i class="sq" style="background:var(--warn)"></i><span>${text}</span></div>`
    : `<div class="refuse amb" data-id="refusal" style="left:0;top:0;${borders(1, 1, 1, 1)}"><i class="sq"></i><span>${text}</span></div>`;
  return ledge + refuse;
}
function alertFeed(v) {
  if (isCore(v) || !DATA[v.state].alert) return '';
  return `<div class="alert" data-id="alert" data-cov style="left:8px;top:${16 + STRIP}px;${borders(1, 1, 1, 1)}"><i class="sq"></i><span>Base under attack</span>${key('Space')}</div>`;
}
function topRight(o, v) {
  const team = isCore(v) ? '' : `<span class="tc" data-id="team" data-cov style="${borders(1, 1, 1, 1)}">Team</span>`;
  // Core as built: the chip shows only when Esc opens the menu, and fades instead of hiding so Menu never moves (hud-v5-layout MW1).
  const coreEsc = ['none', 'none-refuse'].includes(v.state) ? key('Esc') : key('Esc').replace('class="k"', 'class="k" style="visibility:hidden"');
  const esc = isCore(v) ? coreEsc : o.back === 'cell' && MENU_OPEN.has(v.state) ? '' : key('Esc');
  const playtest = isCore(v) ? `<div class="tc" data-id="playtest" data-cov style="right:8px;top:${16 + STRIP}px;${borders(1, 1, 1, 1)}"><span class="lab">Playtest</span><b class="num">2 / 5</b></div>` : '';
  return `<div class="tr" style="right:8px;top:8px">${team}<span class="tc" data-id="menu" data-cov style="${borders(1, 1, 1, 1)}">Menu${esc}</span></div>${playtest}`;
}
function edgeArrows(v, W, H) {
  if (isCore(v) || !DATA[v.state].alert) return '';
  const one = (style, edges, title, svg, id) => `<div class="arrow" data-id="${id}" data-cov title="${title}" style="${style};${edges}">${svg}</div>`;
  const amber = '<svg width="14" height="14" viewBox="0 0 14 14"><polygon points="0,7 14,0 14,14" style="fill:var(--amber)"/></svg>';
  const ally = '<svg width="26" height="26" viewBox="0 0 26 26"><circle cx="13" cy="16" r="9" fill="none" stroke-width="2" style="stroke:var(--ally)"/><polygon points="13,2 20,16 6,16" style="fill:var(--ally)"/></svg>';
  return one(`left:0;top:${Math.round(H * .4)}px`, borders(1, 1, 1, 0), 'Base under attack: click to jump', amber, 'arrow.alert') +
    one(`left:${Math.round(W * .62 - 14)}px;top:0`, borders(0, 1, 1, 1), 'Teammate ping: click to jump', ally, 'arrow.ally');
}

function identity(v, name, cur, max, side = '', extra = '') {
  const g = !isCore(v) && glyphFor(GLYPH_KEY[name]) ? unitGlyph(name, 64) : '';
  return `<div class="id">${g}<div><div class="nr"><span class="nm">${name}</span>${side}</div>${extra}
    <div class="hr">${hpBar(cur / max * 100, 160, 6)}<span class="num">${num(cur)} / ${num(max)}</span></div></div></div>`;
}
function kindRow(v, [name, count, pct], on) {
  return `<span class="b krow ${on ? 'on' : ''}" data-name="${name}" data-count="${count}" data-tg>${isCore(v) ? '' : unitGlyph(name, 22)}<span class="kn">${name}</span><b class="num">${count}</b>${hpBar(pct, 0, 3)}</span>`;
}
function slots(v, count) {
  const filled = queueOf(v).slice(0, count).map((name, i) => `<span class="b slot" data-item="${name}" title="${name}: click to cancel">${isCore(v) ? FACTORY_KEY[name] : unitGlyph(name, 24)}${i ? '' : '<i class="qp" style="width:42%"></i>'}</span>`);
  return `<span class="slots">${filled.concat(Array(count - filled.length).fill('<span class="slot empty"></span>')).join('')}</span>`;
}
function manyBody(o, v) {
  const active = o.owner === 'active';
  const rule = isCore(v) ? '<div class="foot"><span class="muted">Click a kind: select only that kind · Shift-click: deselect it</span></div>' : '';
  return `<div class="hd">120 selected · 6 kinds${active ? key('Tab') : ''}</div>
    <div class="cards">${KINDS.map(k => kindRow(v, k, active && k[0] === 'Bulldozer')).join('')}</div>${rule}`;
}
const buildersBody = v => `<div class="hd">2 selected · 1 kind</div><div class="cards">${kindRow(v, ['Bulldozer', 2, 100], false)}</div>`;
const sellButton = (v, refund) => isCore(v) ? '' : `<span class="b cmd" data-id="selection.sell" data-tg>${glyph('sell', 20)}<span class="grow">Sell</span><span class="muted num">+${num(refund)}</span></span>`;
// Queue tiles (P2.3b round, owner pick 3-3 B compact; tiles not built yet, T8 parked): ported from p2-3a1-states.html qTile / qTiles.
function qTile(t) {
  if (t.more) return `<span class="qt more"><b class="num" style="color:var(--muted)">+${t.more}</b><span class="muted">more</span></span>`;
  const chip = t.hov ? key('×').replace('class="k"', 'class="k" style="color:var(--text)"') : key(FACTORY_KEY[t.name]);
  return `<span class="qt${t.now ? ' now' : ''}${t.hov ? ' hov' : ''}"><span class="r1">${t.now ? '<span class="lab">Now</span>' : '<span></span>'}${chip}</span>` +
    `<span class="nm2">${t.name}</span>${t.n > 1 ? `<span class="cnt num">×${t.n}</span>` : ''}${t.now ? '<i class="qline" style="height:4px"><b style="width:42%"></b></i>' : ''}</span>`;
}
// Adjacent waiting entries of one kind share a tile; the fourth spot counts hidden entries, not tiles.
function qTiles(queue, hov) {
  const waiting = [];
  queue.slice(1).forEach(name => { const last = waiting[waiting.length - 1]; if (last && last.name === name) last.n++; else waiting.push({name, n: 1}); });
  const all = [{name: queue[0], n: 1, now: true}, ...waiting], shown = all.length > 4 ? all.slice(0, 3) : all;
  if (all.length > 4) shown.push({more: queue.length - shown.reduce((s, t) => s + t.n, 0)});
  if (hov != null) shown[hov].hov = true;
  return `<div class="qtrow">${shown.map(qTile).join('')}</div>`;
}
function coreFactoryBody(v) {
  const queue = queueOf(v), label = queue.length ? `<span class="lab">Queue ${queue.length} / 9</span>` : '';
  const tiles = queue.length ? qTiles(queue, DATA[v.state].tile) : '<span class="muted">Nothing in production</span>';
  return identity(v, 'Vehicle Factory', 2000, 2000, label) + tiles + '<div class="foot"><span class="muted">Right-click ground: rally point</span></div>';
}
function factoryBody(o, v) {
  if (isCore(v)) return coreFactoryBody(v);
  const inPanel = o.queue === 'panel', sell = sellButton(v, 1000);
  return identity(v, 'Vehicle Factory', 2000, 2000, inPanel ? `<span class="lab">Queue ${queueOf(v).length} / 9</span>` : '') +
    (inPanel ? `<div class="qrow">${slots(v, 9)}</div>` : '') +
    `<div class="foot"><span class="muted">Right-click ground: rally point</span>${sell}</div>`;
}
function siteBody(v) {
  const progress = `<div class="hr">${bar(62, 160, 6, 'var(--you)')}<span class="num">62 %</span></div>`;
  return identity(v, 'Vehicle Factory', 1240, 2000, '<span class="lab">Under construction</span>', progress);
}
const pileBody = () => `<div class="nm">Supply Pile</div>
  <div class="kv"><span class="lab">Boxes left</span><b class="num">142</b></div>
  <div class="kv"><span class="lab">Collectors</span><b class="num">2 docked · 1 waiting</b></div>`;
function selectionBody(o, v) {
  if (v.state === 'one') return identity(v, 'Medium Tank', 180, 400);
  if (v.state === 'many') return manyBody(o, v);
  if (FACTORY_STATES.has(v.state)) return factoryBody(o, v);
  if (v.state === 'builders') return buildersBody(v);
  if (v.state === 'two-cause') return identity(v, 'Laborer', 100, 100);
  if (v.state === 'plant') return identity(v, 'Power Plant', 1500, 1500) + `<div class="foot"><div class="kv"><span class="lab">Power</span><b class="num">+10</b></div>${sellButton(v, 500)}</div>`;
  if (v.state === 'enemy') return identity(v, 'Battle Tank', 312, 480);
  if (v.state === 'pile') return pileBody();
  if (v.state === 'site') return siteBody(v);
  return identity(v, 'Bulldozer', 250, 250);
}
const selectionEdge = v => v.state === 'enemy' ? 'var(--enemy)' : v.state === 'pile' ? 'var(--line)' : 'var(--you)';

function cardSpec(o, v) {
  const st = v.state;
  const army = {A: {cmd: 'Attack Move', g: 'attack_move'}, S: {cmd: 'Stop', g: 'stop'}, ...(isCore(v) ? {} : {D: {cmd: 'Guard', g: 'guard'}})};
  // Core as built: no Stop for builders (3-14); two builders block Build (3-7).
  const builder = {Q: {cmd: 'Build', g: 'build', more: true}, ...(isCore(v) ? {} : {S: {cmd: 'Stop', g: 'stop'}})};
  if (st === 'builders') return {Q: {...builder.Q, reason: 'Select one builder'}};
  if (st === 'one' || (st === 'many' && o.owner === 'common')) return army;
  if (st === 'many') return {...builder, A: army.A};
  if (st === 'builder') return builder;
  if (st === 'plant') return {};
  if (FACTORY_STATES.has(st)) return {Q: {item: 'Medium Tank', counted: true}, W: {item: 'Rotary Gun Tank', counted: true}};
  if (!MENU_OPEN.has(st)) return null;
  // FRC builds no Power Plant, so its Q stays a well (3-13).
  const grid = DATA[st].frc ? {W: {item: 'Supply Cache'}, E: {item: 'Barracks'}, R: {item: 'Vehicle Yard'}, A: {item: 'Tunnel Hub'}}
    : {Q: {item: 'Power Plant'}, W: {item: 'Supply Depot'}, E: {item: 'Barracks'}, R: {item: 'Vehicle Factory'}, A: {item: 'Rotary Gun Tower'}};
  if (o.back === 'cell') grid.V = {cmd: DATA[st].armed ? 'Cancel' : 'Back', chip: isCore(v) ? 'V' : 'Esc'};
  return grid;
}
function commandCell(o, v, k, c) {
  const g = !isCore(v) && c.g ? glyph(c.g, 20) : '', chip = key(c.chip || k);
  const name = `<span class="cn">${c.cmd}${c.more ? ' <span class="muted">›</span>' : ''}</span>`;
  // A blocked command takes the quiet look and a cell card naming why.
  const blocked = c.reason ? ` quiet" data-reason="builders" data-cell="${c.cmd}` : '';
  return o.cell === 'two' ? `<span class="b cell two cmd${blocked}" data-tg><span class="r1">${chip}${g}</span>${name}</span>`
    : `<span class="b cell one cmd" data-tg>${g}${name}${chip}</span>`;
}
const lacks = (d, pre) => !!pre && (d.early || (d.owns && !d.owns.includes(pre)));
// Core as built (T7): credits the sole blocker turn the cost warn with the solid $ coin 4 after it (3-2); a missing prerequisite or a full queue mutes it.
function coreCost(cost, reason) {
  const short = reason === 'credits';
  return `<span class="cost num${short ? ' warn' : ''}" style="display:flex;align-items:center;gap:4px">${num(cost)}${short ? COIN : ''}</span>`;
}
// Hover marks as built: a ready cell takes the hover inset; a blocked cell's missing prerequisite on the card takes a 1 px sel frame (3-10).
function coreMarks(v, item, reason) {
  const d = DATA[v.state], hov = d.hover && CELLS[d.hover], pre = hov && hov[3];
  return `${d.hover === item && !reason ? ' hov' : ''}${lacks(d, pre) && pre === item ? ' hinted' : ''}`;
}
function itemCell(v, k, c, shape, dim, keyed = true) {
  const d = DATA[v.state], [cost, , , pre] = CELLS[c.item], poor = cost > d.credits, missing = lacks(d, pre);
  const n = c.counted ? queued(v, c.item) : 0, full = c.counted && isFull(v);
  const reason0 = missing ? 'prerequisite' : full ? 'queue' : poor ? 'credits' : '';
  const costHtml = isCore(v) ? coreCost(cost, reason0) : `<span class="cost num ${poor ? 'amb' : ''}">${num(cost)}</span>`, chip = keyed ? key(k) : '';
  const making = isCore(v) && c.counted && queueOf(v)[0] === c.item ? '<i class="qp" style="width:42%"></i>' : '';
  const inner = shape === 'two'
    ? `<span class="r1">${isCore(v) ? '' : unitGlyph(c.item, 22)}${costHtml}${chip}</span><span class="nm2">${c.item}</span>`
    : `<span class="r1"><span class="nm1">${c.item}</span>${chip}</span>${costHtml}`;
  const reason = reason0;
  const cls = `b cell ${shape} ${d.armed === c.item ? 'on' : ''} ${reason ? dim : ''}${isCore(v) ? coreMarks(v, c.item, reason) : ''}`;
  return `<span class="${cls}" data-tg ${reason ? `data-reason="${reason}"` : ''} ${keyed ? `data-cell="${c.item}"` : ''} ${n ? 'title="Shift-click: queue 5"' : ''}>${inner}${n ? `<span class="cnt num">×${n}</span>` : ''}${making}</span>`;
}
function cardCell(o, v, k, c) {
  const html = !c ? `<span class="well${isCore(v) ? ' lined' : ''}"></span>` : c.cmd ? commandCell(o, v, k, c) : itemCell(v, k, c, o.cell, o.dim);
  return html.replace('<span ', `<span data-id="card.cell.${k}" `);
}
function cardSlab(o, v, x, W) {
  const spec = cardSpec(o, v);
  if (!spec) return '';
  const from = o.hug === 'hug' ? LATTICE.findIndex(r => r.some(k => spec[k])) : 0;
  if (from < 0) return '';
  const cells = LATTICE.slice(from).map(r => r.map(k => cardCell(o, v, k, spec[k])).join('')).join('');
  const queue = ['factory', 'full'].includes(v.state) && o.queue === 'card' ? `<div class="qrow">${slots(v, 9)}<span class="num">${queueOf(v).length} / 9</span></div>` : '';
  const style = slab({left: x, width: cardWidth(o), edge: 'var(--you)', border: [1, x + cardWidth(o) >= W ? 0 : 1, 0, 0], pad: [8, 8, 8, 12]});
  return `<div class="slabbg card" data-id="card" data-cov style="${style}"><div class="lattice" style="grid-template-columns:repeat(4,${CELL[o.cell].w}px);grid-auto-rows:${CELL[o.cell].h}px">${cells}</div>${queue}</div>`;
}
function pinnedSlab(o, v, x) {
  const cells = ['Medium Tank', 'Rotary Gun Tank'].map(item => itemCell(v, '', {item, counted: true}, 'two', o.dim, false)).join('');
  const more = QUEUE.length > 5 ? `<span class="muted">+${QUEUE.length - 5}</span>` : '';
  const style = slab({left: x, width: PIN_W, height: o.hug === 'fixed' ? DOCK : 0, edge: 'var(--you)', border: [1, 1, 0, 0], pad: [12, 8, 12, 8]});
  return `<div class="slabbg pinned" data-id="pinned" data-cov style="${style}"><div class="pn"><div class="hd split">Vehicle Factory<span class="x">×</span></div>
    <div class="prow">${cells}</div><div class="qrow">${slots(v, 5)}${more}</div></div></div>`;
}
function selectionSlab(o, v, x) {
  // Core factory panel fixed at 152 whatever the queue holds (P2.3b round, DA queue tiles).
  const fixed = isCore(v) && FACTORY_STATES.has(v.state) ? 152 : o.hug === 'fixed' ? DOCK : 0;
  const style = slab({left: x, width: SEL_W, height: fixed, edge: selectionEdge(v), border: [1, 1, 0, 0], pad: [12, 16, 12, 16]});
  return `<div class="slabbg sel" data-id="selection" data-cov style="${style}"><div class="pn">${selectionBody(o, v)}</div></div>`;
}
const minimapSlab = v => `<div class="slabbg mini" data-id="minimap" data-cov style="${slab({left: 0, width: 168, height: DOCK, border: [1, 1, 0, 0], pad: [8, 8, 8, 8]})}">${minimap(v, 152)}</div>`;

const pinnedShown = (o, v) => !isCore(v) && v.state === 'many' && o.cell === 'two';
function layout(o, v, W) {
  const sel = isCore(v) && o.reserve === 'pack' ? 0 : 168 + GAP;
  const pinned = pinnedShown(o, v) ? sel + SEL_W + GAP : null;
  const next = pinned === null ? sel + SEL_W + GAP : pinned + PIN_W + GAP;
  return {sel, pinned, card: o.side === 'right' ? W - cardWidth(o) : next};
}
function dock(o, v, W, L) {
  return (isCore(v) ? '' : minimapSlab(v)) + (['none', 'none-refuse'].includes(v.state) ? '' : selectionSlab(o, v, L.sel)) +
    (L.pinned === null ? '' : pinnedSlab(o, v, L.pinned)) + cardSlab(o, v, L.card, W);
}

const flatStyle = Object.entries(FLAT).map(([k, x]) => `--${k}:${x}`).join(';');
const cursor = '<svg class="cur" viewBox="0 0 16 22" hidden><path d="M1 1v17l4.5-4 3 7 2.6-1.1-3-6.9H14z" fill="#fff" stroke="#000"/></svg>' +
  // The pointing hand over a ready cell or a tile (Core as built); from p2-3a1-states.html hand.
  '<svg class="cur hand" viewBox="0 0 18 22" style="width:18px" hidden><path d="M6 1.5c.9 0 1.5.7 1.5 1.6V10h.4V7.6c0-.9.7-1.5 1.5-1.5s1.5.6 1.5 1.5V10h.4V8.6c0-.9.6-1.5 1.5-1.5s1.4.6 1.4 1.5v1.9h.4v-.6c0-.8.6-1.4 1.4-1.4.8 0 1.4.6 1.4 1.4v5.6c0 3.3-2.4 6-5.6 6H9.6c-1.7 0-3.2-.8-4.2-2.2L1.6 13.4c-.5-.7-.3-1.6.4-2 .6-.4 1.4-.3 1.9.2L4.5 13V3.1C4.5 2.2 5.1 1.5 6 1.5z" fill="#fff" stroke="#000" stroke-width="1"/></svg>';
function hud(o, v) {
  const {w, h, k} = SIZES[v.size], W = w / k, H = h / k, L = layout(o, v, W);
  plain = isCore(v);
  loadGlyphs();
  return `<div class="hud" data-cfg="${encodeURIComponent(JSON.stringify([o, v]))}" style="--k:${k};--ff:${FONT};width:${W}px;height:${H}px;${flatStyle}">
    ${dock(o, v, W, L)}${topStrip(v)}${aboveDock(v, H)}${alertFeed(v)}${edgeArrows(v, W, H)}${topRight(o, v)}<div class="ccard" data-id="cell_card" hidden></div>${cursor}</div>`;
}
// Core as built (T7, T9): name and muted cost · time, the warn reason when blocked, then the counter line; no forecast (3-4).
function coreCardLines(v, name) {
  const d = DATA[v.state], c = CELLS[name];
  if (!c) return `<div><b>${name}</b></div><div class="warn">Select one builder</div>`;
  const [cost, seconds, , pre] = c, short = cost - d.credits;
  const reason = lacks(d, pre) ? `Needs ${pre}` : FACTORY_KEY[name] && isFull(v) ? 'Queue full' : short > 0 ? `${short} credits short` : '';
  return [`<div><b>${name}</b> <span class="muted num">${cost} · ${seconds} s</span></div>`, reason && `<div class="warn">${reason}</div>`,
    ...(COUNTER[name] || []).map(l => `<div>${l}</div>`)].join('');
}
function cardLines(v, name) {
  if (isCore(v)) return coreCardLines(v, name);
  const [cost, seconds, power, pre] = CELLS[name], d = DATA[v.state], short = cost - d.credits, blocked = short > 0;
  const head = `<div><b>${name}</b> <span class="muted num">${num(cost)} · ${seconds} s</span></div>`;
  if (d.early && pre) return head + `<div class="amb">Needs ${pre}</div>`;
  if (d.queue && isFull(v) && FACTORY_KEY[name]) return head + '<div class="amb">Queue full</div>';
  const lines = [head, ...forecastLines(d, cost, power, blocked)];
  if (blocked) lines.push(`<div class="amb">${num(short)} credits short</div>`);
  if (blocked && !isCore(v)) lines.push(`<div class="muted">about ${Math.ceil(short / (INCOME / 60))} s at current income</div>`);
  return lines.join('');
}
function forecastLines(d, cost, power, blocked) {
  const lines = [], label = t => `<span class="muted cl">${t}</span>`;
  if (!blocked) lines.push(`<div>${label('Credits')} <span class="num">${num(d.credits)} → ${num(d.credits - cost)}</span></div>`);
  if (power && power.avail) lines.push(`<div>${label('Power')} <span class="num">${d.power} / ${d.avail} → ${d.power} / ${d.avail + power.avail}</span></div>`);
  if (power && power.used) {
    const after = d.power + power.used;
    lines.push(`<div>${label('Power')} <span class="num">${d.power} → ${after} / ${d.avail}</span>${after > d.avail ? ` ${lowPower}` : ''}</div>`);
  }
  return lines;
}
const hudScale = hudEl => hudEl.getBoundingClientRect().width / hudEl.offsetWidth;
function relRect(hudEl, el) {
  const hr = hudEl.getBoundingClientRect(), r = el.getBoundingClientRect(), sc = hudScale(hudEl);
  return {x: (r.left - hr.left) / sc, y: (r.top - hr.top) / sc};
}
function placeCursor(hudEl, el, hand, dy = 40, dx = 44) {
  const [arrowCur, handCur] = hudEl.querySelectorAll('.cur'), cur = hand ? handCur : arrowCur;
  arrowCur.toggleAttribute('hidden', !el || hand);
  handCur.toggleAttribute('hidden', !el || !hand);
  if (!el) return;
  const c = relRect(hudEl, el);
  cur.style.left = px(c.x + dx - (hand ? 6 : 0));
  cur.style.top = px(c.y + dy);
}
// A hovered tile's card: name and the decided Cancel line, 8 above the panel, left-aligned with the tile.
function tileCard(hudEl, card, tile) {
  card.hidden = false;
  card.innerHTML = `<div><b>${tile.querySelector('.nm2').textContent}</b></div><div class="muted" style="font-size:13px;line-height:20px">Cancel · refunds 800</div>`;
  const t = relRect(hudEl, tile), s = relRect(hudEl, hudEl.querySelector('.sel'));
  card.style.left = px(Math.max(t.x, 8));
  card.style.top = px(s.y - GAP - card.offsetHeight);
  // The tip below a one-line name, so it hides no letters.
  placeCursor(hudEl, tile, true, 44, 58);
}
function updateCard(hudEl, hovered) {
  const [, v] = JSON.parse(decodeURIComponent(hudEl.dataset.cfg)), card = hudEl.querySelector('.ccard'), d = DATA[v.state];
  plain = isCore(v);
  const tile = !hovered && hudEl.querySelector('.qt.hov');
  if (tile) return tileCard(hudEl, card, tile);
  const name = hovered ? hovered.dataset.cell : d.hover, cellEl = name && hudEl.querySelector(`[data-cell="${name}"]`);
  card.hidden = !cellEl;
  // A click closes the card while the pointer stays on the cell (hud.gd _press_cell).
  const pointed = !hovered && d.pointer && hudEl.querySelector(`[data-cell="${d.pointer}"]`);
  // Core: the tip right of the name's last word, as the P2.3b round drew it, so it hides no letters.
  placeCursor(hudEl, hovered ? null : cellEl || pointed, isCore(v) && cellEl && !cellEl.dataset.reason, isCore(v) ? 46 : 40, isCore(v) ? 58 : 44);
  if (!cellEl) return;
  card.innerHTML = cardLines(v, name);
  const c = relRect(hudEl, cellEl), s = relRect(hudEl, hudEl.querySelector('.card'));
  card.style.left = px(Math.min(Math.max(c.x, 8), hudEl.offsetWidth - 8 - card.offsetWidth));
  card.style.top = px(s.y - GAP - card.offsetHeight);
}
function placeRefusal(hudEl) {
  const line = hudEl.querySelector('.refuse');
  if (!line || line.classList.contains('warn')) return;
  const W = hudEl.offsetWidth, w = line.offsetWidth, h = line.offsetHeight, left = Math.round((W - w) / 2);
  const solids = [...hudEl.querySelectorAll('[data-cov],.ccard')].filter(shown).map(el => ({...relRect(hudEl, el), w: el.offsetWidth, h: el.offsetHeight}));
  let top = hudEl.offsetHeight - DOCK - GAP - h;
  for (let hit = true; hit;) {
    const under = solids.find(r => left < r.x + r.w && r.x < left + w && top < r.y + r.h && r.y < top + h);
    hit = !!under;
    if (under) top = under.y - GAP - h;
  }
  line.style.left = px(left);
  line.style.top = px(top);
}
const placeCards = root => root.querySelectorAll('.hud').forEach(h => { updateCard(h, null); placeRefusal(h); });
const shown = el => el.getClientRects().length > 0;
return {SIZES, STATES, NEW_STATES, FONT, BG, FLAT, OWNERS, HEALTH, CELL, CELL_PAD, contrast, mix, lifted, isCore, pinnedShown, hudScale, updateCard, placeCards, hud, shown, luminance, DATA, BASE, KINDS, glyph, glyphFor, unitGlyph, layout, dock, placeRefusal};
})();
