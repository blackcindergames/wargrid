'use strict';
const $ = (q, el = document) => el.querySelector(q);
const $$ = (q, el = document) => [...el.querySelectorAll(q)];
const esc = (t) => String(t ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const fmt = (t) => esc(t).replace(/`([^`]+)`/g, '<span class="w">$1</span>');
const url = (p) => (/^(https?:)?\/\//.test(p) || p.startsWith('/') ? p : '/' + p);
const LETTERS = ['A', 'B', 'C', 'D'];
const CHOICE = new Set(['pictures', 'text', 'audio', 'lab']);
const KINDS = new Set([...CHOICE, 'gallery', 'verdict', 'wording']);
const SPECIAL = { yes: 'Yes, as drawn', change: 'Change' };

function addErr(msg) { $('#err').textContent += msg + '\n'; }
addEventListener('error', (e) => addErr(`${e.message} (${(e.filename || '').split('/').pop()}:${e.lineno})`));
addEventListener('unhandledrejection', (e) => addErr(String(e.reason)));

const REG = { index: [], rounds: {}, steps: {} };
const DP = {
  index(list) { REG.index = list; },
  saved(picks) { REG.saved = picks && typeof picks === 'object' && !Array.isArray(picks) ? picks : null; },
  round(r) { REG.rounds[r.id] = r; },
  step(s) {
    const id = document.currentScript && document.currentScript.dataset.round;
    (REG.steps[id] ||= {})[s.key] = s;
  },
};
window.DP = DP;
window.DPmissing = (img) => {
  const p = esc(img.getAttribute('src'));
  img.parentElement.innerHTML = img.dataset.local === undefined ? `<span class="missing">[picture missing: ${p}]</span>` : `<span class="localonly">Your local file, not published with this page: ${p}</span>`;
};
const PHONE = () => matchMedia('(max-width:900px),(pointer:coarse)').matches;
const own = (o, k) => !!o && typeof k === 'string' && Object.hasOwn(o, k);

const H = new URLSearchParams(location.hash.slice(1));
const S = {
  round: null, earlier: [], steps: [], n: 0, show: {}, view: {}, item: {},
  saved: {}, local: {}, notes: {}, sentNote: {}, unsent: new Map(), lastRec: null, revealed: '',
  inflight: new Set(), chain: {}, srcs: [], audio: null, playing: null, timer: 0, touchX: null, ctl: {}, numbers: true, sheet: false,
};
const main = () => $('#main');
const prefixOf = (r) => r.prefix || r.id;
const K = (k, r = S.round) => `${prefixOf(r)}:${k}`;
const cur = () => S.steps[S.n];
const optsOf = (s) => LETTERS.filter((x) => s.options && s.options[x]);
const isConfirm = (s) => CHOICE.has(s.kind) && optsOf(s).length === 1;
const pickOf = (k) => (S.local[k] || S.saved[k] || {}).pick ?? null;
const shownOf = (s) => S.show[s.key] || (LETTERS.includes(pickOf(K(s.key))) && pickOf(K(s.key))) || (optsOf(s).includes(s.rec) && s.rec) || optsOf(s)[0];
const viewOf = (s) => S.view[s.key] || s.view || 'flip';
const sideOn = (s) => !!s && CHOICE.has(s.kind) && viewOf(s) === 'side' && optsOf(s).length > 1;
const cropOf = (s) => (PHONE() && s.phoneCrop) || s.crop;
const itemsOf = (s) => s.items || [];
const itemOf = (s) => itemsOf(s)[Math.min(S.item[s.key] || 0, itemsOf(s).length - 1)];

function load(src, round) {
  return new Promise((ok) => {
    const el = document.createElement('script');
    el.src = src;
    if (round) el.dataset.round = round;
    el.onload = () => ok(true);
    el.onerror = () => ok(false);
    document.head.appendChild(el);
  });
}
async function loadRound(id) {
  if (!/^[a-z0-9-]+$/.test(id) || !(await load(`rounds/${id}/round.js`)) || !REG.rounds[id]) throw new Error(`round ${id} did not load (rounds/${id}/round.js)`);
  const r = REG.rounds[id];
  await Promise.all(r.steps.map((k) => load(`rounds/${id}/${k}.js`, id)));
  return r;
}
function stepsOf(r) {
  return r.steps.map((k) => {
    const s = (REG.steps[r.id] || {})[k];
    if (!s) addErr(`[step missing: ${k}] rounds/${r.id}/${k}.js did not load`);
    return s || { key: k, kind: 'missing' };
  });
}
function checkStep(r, s) {
  const where = `${r.id}/${s.key}`;
  if (s.kind === 'missing') return;
  if (!KINDS.has(s.kind)) addErr(`${where}: unknown kind ${s.kind}`);
  if (CHOICE.has(s.kind) && !optsOf(s).length) addErr(`${where}: no options`);
  if (s.rec && CHOICE.has(s.kind) && !optsOf(s).includes(s.rec)) addErr(`${where}: rec ${s.rec} is not an option`);
  (s.uses || []).forEach((u) => { if (!findUse(u, r)) addErr(`${where}: uses ${u} is not a step`); });
  if (s.kind === 'gallery' && s.verdict && r.steps.includes(s.verdict.key || 'verdict')) addErr(`${where}: verdict key ${s.verdict.key || 'verdict'} is also a step key`);
  checkControls(r, s);
}
async function fetchPicks() {
  try {
    const r = await fetch('/picks.json', { cache: 'no-store' });
    if (!r.ok) return null;
    const j = await r.json();
    return j && typeof j === 'object' && !Array.isArray(j) ? j : null;
  } catch (e) { return null; }
}

// ---------- recording ----------
async function post(key, pick, note) {
  S.local[key] = { pick, note };
  // One key's posts go one after another: the server's threads would otherwise let an older body land last.
  const sent = (S.chain[key] || Promise.resolve()).then(() => fetch('/pick', { method: 'POST', body: JSON.stringify({ key, pick, note }) })).then((r) => r.status, () => 0);
  S.chain[key] = sent;
  S.inflight.add(sent);
  const status = await sent;
  S.inflight.delete(sent);
  if (S.chain[key] === sent) delete S.chain[key];
  if (status === 204) {
    S.unsent.delete(key);
    S.saved[key] = { pick, note };
    S.lastRec = { key, pick };
  } else S.unsent.set(key, { pick, note, status });
  showRecord();
  chipsUpdate();
  return status === 204;
}
function retry() { [...S.unsent].forEach(([k, v]) => post(k, v.pick, v.note)); }
function recordHtml() {
  if (S.unsent.size) {
    const why = [...S.unsent.values()].some((v) => v.status) ? `server refused (HTTP ${[...S.unsent.values()].find((v) => v.status).status})` : 'server not reachable';
    const what = [...S.unsent.keys()].map((k) => esc(k.split(':').slice(1).join(':'))).join(', ');
    return `<span class="fail">Not recorded: ${why}. Kept on this page: ${what}.</span> <button data-act="retry">Retry</button>`;
  }
  if (!S.lastRec) return '';
  const { key, pick } = S.lastRec, what = esc(key.split(':').slice(1).join(':'));
  return `Recorded: ${pick ? `${what} ${esc(pick)}` : `note on ${what}`}.${S.revealed ? ' ' + esc(S.revealed) : ''}`;
}
function showRecord() { $$('.rec').forEach((e) => { e.innerHTML = recordHtml(); }); }
function flush() {
  $$('[data-note]').forEach((el) => {
    const k = el.dataset.note, v = S.notes[k] ?? '';
    if (v === (S.sentNote[k] ?? '')) return;
    S.sentNote[k] = v;
    post(k, pickOf(k), v);
  });
}

// ---------- pictures ----------
function frameSrc(r) {
  const s = cur(), b = renderBase(r), q = new URLSearchParams((b.hash || 'shot={state}').replace('{state}', encodeURIComponent(stateFor(s, r))));
  Object.entries({ ...(r.params || {}), ...ctlParams(s, r) }).forEach(([k, v]) => q.set(k, v));
  return `${url(b.page)}#${q.toString().replace(/%2C/g, ',').replace(/%3A/g, ':')}`;
}
function videoPic(src, label) {
  return `<div class="pic vid"><video src="${esc(url(src.video))}" muted loop playsinline controls preload="metadata" aria-label="${esc(label || '')}" onerror="DPmissing(this)"></video></div>`;
}
function pic(src, crop0, label, large = true) {
  if (!src || (!src.img && !src.render && !src.video)) return '<div class="pic none"><span class="missing">[no picture]</span></div>';
  const s = cur(), i = large ? S.srcs.push({ src, label, crop: crop0 }) - 1 : -1, at = large ? ` data-src="${i}"` : '';
  if (src.video) return videoPic(src, label);
  const local = src.local ? ' data-local' : '';
  if (src.img) return `<div class="pic img"${at}><img src="${esc(url(src.img))}" alt="${esc(label || '')}"${local} onload="DPnat(this)" onerror="DPmissing(this)">${large ? imgMarks(s, src) : ''}</div>`;
  const r = src.render, b = renderBase(r), z = sizeOf(s, r), c = cropFor(r.crop === null ? null : r.crop || crop0, { w: b.w || 1280, h: b.h || 720 }, z);
  const live = s && s.interactive && large ? ' live' : '';
  return `<div class="pic${live}" data-cw="${c.w}" style="--ar:${c.w}/${c.h};--cw:${c.w}"${at}><div class="sc" style="width:${c.w}px;height:${c.h}px">` +
    `<iframe tabindex="-1" title="${esc(stateFor(s, r))}" src="${esc(frameSrc(r))}" style="width:${z.w}px;height:${z.h}px;left:${-c.x}px;top:${-c.y}px"></iframe>` +
    `${hudLayer(s, z).replace('left:0;top:0', `left:${-c.x}px;top:${-c.y}px`)}${large ? marksHtml(s, src, c, z, { w: b.w || 1280, h: b.h || 720 }) : ''}</div></div>`;
}
const RO = new ResizeObserver((es) => es.forEach((e) => { e.target.style.setProperty('--s', e.contentRect.width / e.target.dataset.cw); }));
function observe() { RO.disconnect(); $$('.pic[data-cw]').forEach((el) => RO.observe(el)); }
function wholeHtml(src, label) {
  const full = src.render ? { ...src, render: { ...src.render, crop: null } } : src, z = src.render && sizeOf(cur(), src.render);
  return `<div class="ov${z ? '' : ' imgov'}" style="${z ? `--oar:${z.w}/${z.h};--ow:${z.w}` : ''}">${pic(full, null, label, true)}</div><div class="cap">${fmt(label || '')}. Esc or click to close.</div>`;
}
// Phone: the stage already fits the frame, so Large magnifies the stage's own region instead.
function zoomHtml(src, label, crop) {
  const cropped = !!src.render && src.render.crop !== null && !!(src.render.crop || crop);
  const at = cropped ? '200 % of game pixels' : src.render ? '100 % of game pixels' : 'full size';
  return { k: cropped ? 2 : 1, html: `<div class="cap">${fmt(label || '')} at ${at}: drag to pan, tap to close.</div><div class="ov zoom">${pic(src, crop, label, true)}</div>` };
}
function large(i, whole = !PHONE()) {
  const { src, label, crop } = S.srcs[i], over = $('#over'), z = whole ? null : zoomHtml(src, label, crop);
  over.innerHTML = z ? z.html : wholeHtml(src, label);
  over.classList.toggle('zoom', !!z);
  if (z) $$('#over .pic[data-cw]').forEach((el) => { el.style.width = `${el.dataset.cw * z.k}px`; el.style.setProperty('--s', z.k); });
  over.hidden = false;
  observe();
  if (z) { centreZoom(); $$('#over img').forEach((im) => im.addEventListener('load', centreZoom, { once: true })); }
}
// Opens on the step's mark, or the crop's middle, not on its top-left corner.
function centreZoom() {
  const over = $('#over'), at = $('#over .mark') || $('#over .pic');
  if (!at) return;
  const o = over.getBoundingClientRect(), r = at.getBoundingClientRect();
  over.scrollBy(r.left + r.width / 2 - (o.left + o.width / 2), r.top + r.height / 2 - (o.top + o.height / 2));
}
function closeOver() {
  if ($('#over').hidden && $('#legend').hidden) return false;
  $('#over').hidden = true;
  $('#legend').hidden = true;
  $('#over').innerHTML = '';
  observe();
  return true;
}

// ---------- step parts ----------
function optName(s, x) { return s.options[x].name || x; }
function revealOf(s, x) {
  const p = pickOf(K(s.key));
  return s.blind && (own(s.options, p) || p === 'neither') && own(s.options, x) && s.options[x].reveal;
}
function tags(s, x) {
  const cp = s.rec === x ? '<span class="tag cp">Claude\'s pick</span>' : '';
  const got = pickOf(K(s.key)) === x ? '<span class="tag got">Picked</span>' : '';
  const rv = revealOf(s, x) ? `<span class="tag rv">${esc(s.options[x].reveal)}</span>` : '';
  return cp + got + rv;
}
function textCard(s, x) {
  const t = s.options[x].text, c = s.card;
  if (!c) return `<div class="card"><div class="q hl">${fmt(t)}</div></div>`;
  const lines = c.lines.map((q) => (q === null ? `<div class="q hl">${fmt(t)}</div>` : `<div class="q">${fmt(q)}</div>`)).join('');
  return `<div class="card">${c.title ? `<div class="ct">${esc(c.title)}</div>` : ''}${lines}${c.foot ? `<div class="foot">${esc(c.foot)}</div>` : ''}</div>`;
}
function audioBody(s, x) {
  const o = s.options[x];
  return `<div class="aud"><button class="play" data-play="${x}"><kbd>Space</kbd><span>Play</span></button><span class="lv">${esc(o.level || '')}</span></div>`;
}
function optBody(s, x) {
  const o = s.options[x];
  if (s.kind === 'text') return textCard(s, x);
  if (s.kind === 'audio') return audioBody(s, x);
  if (s.kind === 'lab') return '';
  return pic(o, cropOf(s), `${x}: ${optName(s, x)}`);
}
function figuresHtml(list, crop, who) {
  return (list || []).length ? `<div class="extras">${list.map((e) => `<figure><figcaption>${fmt(e.label)}</figcaption>${pic(e, crop, `${who}: ${e.label}`)}</figure>`).join('')}</div>` : '';
}
function foldsHtml(folds, crop, who) {
  return (folds || []).map((f) => `<details class="fold"><summary>${fmt(f.label)}</summary>${f.text ? `<p>${fmt(f.text)}</p>` : ''}${figuresHtml(f.pics, crop, who)}</details>`).join('');
}
function optText(s, x) {
  const o = s.options[x], h = (t) => `<span class="h">${esc(t)}</span>`;
  const sees = o.sees ? `<p class="sees">${h('What you see')}${fmt(o.sees)}</p>` : '';
  const notes = o.notes ? `<p class="notes">${o.sees || s.notesLabel ? h(s.notesLabel || 'Notes') : ''}${fmt(o.notes)}</p>` : '';
  const changes = o.changes ? `<p class="chg">${fmt(o.changes)}</p>` : '';
  return sees + notes + changes + foldsHtml(o.folds, (o.render && o.render.crop) || s.crop, x);
}
function extras(s, x) {
  const o = s.options[x];
  return figuresHtml(o.extra, (o.render && o.render.crop) || s.crop, x);
}
function headHtml(s) {
  const n = s ? `Step ${S.n + 1} of ${S.steps.length}` : 'Summary';
  const rec = s && s.rec && CHOICE.has(s.kind) ? `<p class="cpline"><span class="tag cp">Claude's pick</span> <b>${isConfirm(s) ? 'Yes, as drawn' : `${s.rec}: ${fmt(optName(s, s.rec))}`}</b>${s.recWhy ? ` · ${fmt(s.recWhy)}` : ''}</p>` : '';
  return `<section class="head"><span class="n">${esc(S.round.title || S.round.id)} · ${n}</span><h1>${fmt(s ? s.question || s.key : 'What the server recorded')}</h1>${rec}<p class="rec">${recordHtml()}</p></section>`;
}
function findUse(u, from = S.round) {
  const [rid, k] = u.includes('/') ? u.split('/') : [from.id, u];
  const r = [S.round, ...S.earlier].find((e) => e.id === rid);
  const st = r && (REG.steps[r.id] || {})[k];
  return st ? { r, s: st } : null;
}
function usesHtml(s) {
  const lines = (s.uses || []).map((u) => findUse(u)).filter(Boolean).map(({ r, s: u }) => {
    const p = pickOf(K(u.key, r)), shown = p ? pickLabel(u, p) : `not picked yet, shown with ${u.rec ? pickLabel(u, u.rec, false) : 'the default'}`;
    return `<li>${esc(u.question || u.key)}${r === S.round ? '' : ` (${esc(r.title || r.id)})`}: <b>${fmt(shown)}</b></li>`;
  });
  return lines.length ? `<div class="uses"><span class="h">Shown with your earlier picks</span><ul>${lines.join('')}</ul></div>` : '';
}
// Open on a desktop; closed on a phone and side by side so the pictures stay near the top.
const openAttr = (s) => (PHONE() || sideOn(s) ? '' : ' open');
function cueHtml(s) {
  const look = s.look ? `<p class="look">${fmt(s.look)}</p>` : '';
  const ref = s.ref && !sideOn(s) ? `<details class="ref"${openAttr(s)}><summary>${fmt(s.ref.label)}</summary>${pic(s.ref, cropOf(s), s.ref.label)}</details>` : '';
  return look || ref ? `<section class="cue">${look}${ref}</section>` : '';
}
function infoHtml(s) {
  const why = s.why ? `<details class="why"${openAttr(s)}><summary>Why this question</summary><p>${fmt(s.why)}</p></details>` : '';
  const check = s.checklist ? `<div class="check"><span class="h">What to judge</span><ul>${s.checklist.map((c) => `<li>${fmt(c)}</li>`).join('')}</ul></div>` : '';
  const rest = `${check}${usesHtml(s)}${numbersHtml(s)}${foldsHtml(s.folds, s.crop, 'Step')}`;
  return `${why}${cueHtml(s)}${rest ? `<section class="info">${rest}</section>` : ''}`;
}
function noteHtml(k, label, hint = '') {
  return `<section class="notebox"><label for="note">${esc(label)}</label><textarea id="note" data-note="${esc(k)}">${esc(S.notes[k] || '')}</textarea><p class="nhint">${esc(hint)}</p></section>`;
}
function navHtml(next = 'Skip') {
  const s = cur();
  const fwd = !s ? 'Step 1' : S.n < S.steps.length - 1 ? next : 'Summary';
  return `<nav class="stepnav"><button data-act="prev"><kbd>←</kbd>Back</button><button data-act="next">${esc(fwd)}<kbd>→</kbd></button><span class="gap"></span><button data-act="legend"><kbd>?</kbd>Keys</button></nav>`;
}
function flipBar(s, opts) {
  if (isConfirm(s)) return '';
  const b = opts.map((x) => `<button class="ob" data-show="${x}"><kbd>${x}</kbd><span>${fmt(optName(s, x))}</span></button>`).join('');
  const side = opts.length > 1 ? `<button class="vt" data-act="view"><kbd>W</kbd>${viewOf(s) === 'side' ? 'One at a time' : 'Side by side'}</button>` : '';
  return `<div class="flipbar">${b}${side}</div>`;
}
const neutralBtn = (s) => (s.neutral ? `<button class="neutral" data-pick="neither">${esc(s.neutral)}</button>` : '');
function actHtml(s) {
  const neutral = neutralBtn(s);
  const pick = isConfirm(s)
    ? '<button class="pick" data-pick="yes">Yes, as drawn <kbd>Enter</kbd></button><button data-pick="change">Change (say what in the note)</button>'
    : `<button class="pick" data-act="pick">Pick <span class="pl"></span> <kbd>Enter</kbd></button>`;
  return `<div class="act">${pick}${neutral}<span class="scale"></span></div>`;
}
function labFrame(s) {
  const link = `<a class="lablink" href="${esc(url(s.url))}">Open the lab in this tab</a>`;
  return `<div class="lab" data-lab><p>${fmt(s.labHint || 'The lab starts only when you press Start. Click the picture once so it takes the keys.')}</p>` +
    `<button class="pick" data-act="lab">Start the lab here</button> ${link}</div>`;
}
function stageHtml(s, opts) {
  const body = s.kind === 'lab' ? labFrame(s) : opts.map((x) => `<div class="ostage" data-opt="${x}">${optBody(s, x)}</div>`).join('');
  return `<section class="stagecol">${flipBar(s, opts)}${ctlBarHtml(s)}<div class="stage" data-swipe>${body}</div>${actHtml(s)}</section>`;
}
function detailHtml(s, opts) {
  const one = (x) => `<div class="odetail" data-opt="${x}"><div class="ohd"><span class="let">${x}</span><h2>${fmt(optName(s, x))}</h2>${tags(s, x)}</div>${optText(s, x)}${extras(s, x)}</div>`;
  return `<section class="detail">${opts.map(one).join('')}</section>`;
}
function tileHtml(s, x) {
  const more = s.options[x].extra && s.options[x].extra.length ? `<details><summary>${s.options[x].extra.length} more pictures</summary>${extras(s, x)}</details>` : '';
  return `<div class="tile" data-opt="${x}"><div class="ohd" data-pick="${x}"><span class="let">${x}</span><h2>${fmt(optName(s, x))}</h2>${tags(s, x)}</div>` +
    `${optBody(s, x)}${optText(s, x)}${more}<button class="pick" data-pick="${x}">Pick ${x}</button></div>`;
}
// The reference picture as the first tile, at the options' scale.
function refTile(s) {
  return s.ref ? `<div class="tile reft"><div class="ohd"><h2>${fmt(s.ref.label)}</h2></div>${pic(s.ref, cropOf(s), s.ref.label)}</div>` : '';
}
function tilesHtml(s, opts) {
  const n = opts.length + (s.ref ? 1 : 0);
  return `<section class="stagecol">${flipBar(s, opts)}${ctlBarHtml(s)}<div class="tiles" style="--n:${n}">${refTile(s)}${opts.map((x) => tileHtml(s, x)).join('')}</div><div class="act">${neutralBtn(s)}</div></section>`;
}

// ---------- renderers ----------
function layout(cls, left, right) {
  const m = main();
  m.className = `step ${cls}`;
  m.innerHTML = `<div class="left">${left}</div><div class="right">${right}</div>`;
}
function renderChoice(s) {
  const opts = optsOf(s), side = sideOn(s), k = K(s.key);
  const note = noteHtml(k, isConfirm(s) ? 'Note (say what to change, or anything else)' : 'Optional note for Claude (saved with your pick)');
  const right = side ? tilesHtml(s, opts) : stageHtml(s, opts) + detailHtml(s, opts);
  layout(`k-${s.kind} ${side ? 'v-side' : 'v-flip'}`, headHtml(s) + infoHtml(s) + note + navHtml(), right);
}
function galleryAside(s) {
  const it = itemOf(s), i = itemsOf(s).indexOf(it), k = K(`${s.key}:${it.id}`);
  return `<section class="gside"><span class="cnt">${i + 1} of ${itemsOf(s).length}</span><h2>${esc(it.label || it.id)}</h2><p>${fmt(it.caption || '')}</p>` +
    `<label for="lnote">Note on this one (optional)</label><textarea id="lnote" data-note="${esc(k)}">${esc(S.notes[k] || '')}</textarea>` +
    '<div class="inav"><button data-act="iprev"><kbd>P</kbd>Previous</button><button data-act="inext">Next<kbd>N</kbd></button></div></section>';
}
function verdictHtml(key, labels) {
  const k = K(key), v = pickOf(k);
  const b = (x) => `<button class="vb ${x}${v === x ? ' done' : ''}" data-verdict="${x}" data-vkey="${esc(key)}">${esc(labels[x])}</button>`;
  return `<section class="verdict">${b('pass')}${b('changes')}<textarea id="vnote" data-note="${esc(k)}" placeholder="Optional overall note (saved with the verdict)">${esc(S.notes[k] || '')}</textarea></section>`;
}
function renderGallery(s) {
  const it = itemOf(s);
  if (!it) { layout('k-gallery', headHtml(s) + '<p class="missing">[gallery has no items]</p>' + navHtml(), ''); return; }
  const thumbs = itemsOf(s).map((t, i) => {
    const noted = (S.notes[K(`${s.key}:${t.id}`)] || '').trim() ? ' noted' : '';
    return `<div class="th${t === it ? ' on' : ''}${noted}" data-item="${i}">${pic(t, null, t.label, false)}<span>${esc(t.label || t.id)}</span></div>`;
  }).join('');
  const verdict = s.verdict ? verdictHtml(s.verdict.key || 'verdict', s.verdict) : '';
  layout('k-gallery', headHtml(s) + infoHtml(s) + galleryAside(s) + verdict + navHtml(),
    `<section class="stagecol">${ctlBarHtml(s)}<div class="stage gmain" data-swipe>${pic(it, null, it.label || it.id)}</div><div class="scale"></div></section><section class="thumbs">${thumbs}</section>`);
}
function renderVerdict(s) {
  layout('k-verdict', headHtml(s) + infoHtml(s) + navHtml(), verdictHtml(s.key, s.labels || { pass: 'Pass', changes: 'Changes needed' }));
}
function renderWording(s) {
  const fields = (s.fields || []).map((f) => {
    const k = K(`${s.key}:${f.id}`), v = S.notes[k] ?? f.text ?? '';
    return `<div class="field"><label for="f-${esc(f.id)}">${esc(f.label || f.id)}</label><textarea id="f-${esc(f.id)}" data-note="${esc(k)}" data-live>${esc(v)}</textarea>` +
      `${f.text ? `<p class="was">Drafted: ${fmt(f.text)}</p>` : ''}</div>`;
  }).join('');
  layout('k-wording', headHtml(s) + infoHtml(s) + navHtml('Done, next'), `<section class="fields"><p class="nhint">Edits are recorded as you type.</p>${fields}</section>`);
}
function renderMissing(s) {
  layout('k-missing', `<section class="head"><span class="n">Step ${S.n + 1} of ${S.steps.length}</span><h1>[step missing: ${esc(s.key)}]</h1>` +
    `<p>rounds/${esc(S.round.id)}/${esc(s.key)}.js did not load.</p></section>${navHtml()}`, '');
}
function pickLabel(s, p, reveal = true) {
  if (p === null || p === undefined) return '';
  if (own(s.options, p)) return `${p}: ${String(s.options[p].name || '').replace(/`/g, '')}${reveal && s.blind && s.options[p].reveal ? ` (${s.options[p].reveal})` : ''}`;
  if (p === 'neither') return s.neutral || 'Neither';
  if (own(s.labels, p)) return s.labels[p];
  if (own(s.verdict, p)) return s.verdict[p];
  return own(SPECIAL, p) ? SPECIAL[p] : String(p);
}
function rowLabel(r, local) {
  const [k, sub] = [local.split(':')[0], local.split(':').slice(1).join(':')];
  const s = (REG.steps[r.id] || {})[k];
  const gv = r.steps.map((x) => (REG.steps[r.id] || {})[x]).find((x) => x && x.verdict && (x.verdict.key || 'verdict') === local);
  if (gv) return { label: 'Verdict', s: gv, order: r.steps.indexOf(gv.key) + 0.9 };
  if (!s) return { label: local, s: {}, order: 999 };
  const order = r.steps.indexOf(k) + (sub ? 0.5 : 0);
  if (!sub) return { label: s.question || k, s, order };
  const it = itemsOf(s).find((x) => x.id === sub) || (s.fields || []).find((x) => x.id === sub);
  return { label: s.kind === 'wording' ? `${s.question || k}: ${it ? it.label || sub : sub}` : `Note on ${it ? it.label || sub : sub}`, s, order };
}
function summaryRows(r, saved) {
  const p = prefixOf(r) + ':';
  return Object.entries(saved).filter(([k]) => k.startsWith(p)).map(([k, v]) => {
    const { label, s, order } = rowLabel(r, k.slice(p.length));
    return { label, pick: pickLabel(s, v.pick), note: v.note || '', order };
  }).sort((a, b) => a.order - b.order);
}
function askedOf(r) {
  return r.steps.map((k) => (REG.steps[r.id] || {})[k]).filter((s) => s && (CHOICE.has(s.kind) || s.kind === 'verdict' || (s.kind === 'gallery' && s.verdict)));
}
function openOf(r, saved) {
  const has = (k) => { const v = saved[`${prefixOf(r)}:${k}`]; return !!v && v.pick != null; };
  return askedOf(r).filter((s) => !(s.kind === 'gallery' ? has(s.verdict.key || 'verdict') : has(s.key)));
}
function answered(r, saved) {
  const ask = askedOf(r).length;
  return `${ask - openOf(r, saved).length} of ${ask} answered`;
}
function closeHtml(saved) {
  const open = openOf(S.round, saved).map((s) => `<button data-step="${S.round.steps.indexOf(s.key)}">${esc(s.key)}</button>`);
  return open.length ? `<p class="close">Not answered yet: ${open.join(' ')}</p>` : '<p class="close">You can close this tab.</p>';
}
function sumTable(rows) {
  if (!rows.length) return '<p>Nothing recorded yet.</p>';
  return `<table class="sum"><tr><th>Question</th><th>Pick</th><th>Note</th></tr>${rows.map((x) => `<tr><td>${fmt(x.label)}</td><td>${fmt(x.pick)}</td><td>${esc(x.note)}</td></tr>`).join('')}</table>`;
}
function summaryText(saved) {
  return [S.round, ...S.earlier].map((r) => [`${r.title || r.id} (${answered(r, saved)})`, ...summaryRows(r, saved).map((x) => `- ${x.label.replace(/`/g, '')}: ${x.pick || '(note)'}${x.note ? ` | ${x.note}` : ''}`)].join('\n')).join('\n\n');
}
function renderSummary() {
  layout('k-summary', headHtml(null) + '<div id="sum"></div>' + navHtml(), '');
  fillSummary(S.saved);
  // Read back only after the last pick's POST settled, or the verdict just clicked is missing.
  Promise.allSettled([...S.inflight]).then(fetchPicks).then((saved) => {
    if (!$('#sum') || cur()) return;
    if (!saved) { $('#sum').insertAdjacentHTML('afterbegin', '<p><span class="fail">picks.json not readable: server not reachable. Shown: what this page recorded.</span></p>'); return; }
    S.saved = saved;
    fillSummary(saved);
  });
}
function fillSummary(saved) {
  const box = $('#sum');
  const earlier = S.earlier.map((r) => `<h2>${esc(r.title || r.id)} <span class="cnt">${answered(r, saved)}</span></h2>${sumTable(summaryRows(r, saved))}`).join('');
  box.innerHTML = `<h2>${esc(S.round.title || S.round.id)} <span class="cnt">${answered(S.round, saved)}</span></h2>${sumTable(summaryRows(S.round, saved))}${closeHtml(saved)}` +
    `<p><button data-act="copy">Copy summary</button> <span class="copied"></span></p>${earlier ? `<h3 class="sec">Earlier rounds</h3>${earlier}` : ''}`;
  S.summaryText = summaryText(saved);
}

// ---------- chrome ----------
function chipsHtml() {
  const chip = (i, s) => {
    const k = s.kind === 'gallery' && s.verdict ? K(s.verdict.key || 'verdict') : K(s.key), p = pickOf(k);
    const cls = `${i === S.n ? ' on' : ''}${p ? ' done' : ''}${S.unsent.has(k) ? ' unsent' : ''}`;
    return `<button class="chip${cls}" data-step="${i}">${i + 1} ${esc(s.key)}${p ? ` · ${esc(p)}` : ''}</button>`;
  };
  const earlier = S.earlier.map((r) => `<a class="chip er" href="#round=${esc(r.id)}&step=summary">${esc(r.title || r.id)}</a>`).join('');
  return S.steps.map((s, i) => chip(i, s)).join('') + `<button class="chip${S.n === S.steps.length ? ' on' : ''}" data-step="${S.steps.length}">Summary</button>${earlier}`;
}
function chipsUpdate() { $('#chips').innerHTML = chipsHtml(); }
function phoneHtml(s) {
  const b = (act, label, on = true) => (on ? `<button data-act="${act}">${label}</button>` : '');
  const row1 = ['<button class="arrow" data-act="prev" aria-label="Previous step">‹</button>'];
  const row2 = [];
  let whole = '';
  if (s && CHOICE.has(s.kind)) {
    const opts = optsOf(s);
    if (!isConfirm(s)) row1.push(...opts.map((x) => `<button class="ob" data-show="${x}">${x}</button>`));
    row1.push(isConfirm(s) ? '<button class="pick" data-pick="yes">Yes</button>' : `<button class="pick" data-act="pick">Pick ${shownOf(s)}</button>`);
    const stills = s.kind === 'pictures' && opts.some((x) => !s.options[x].video);
    row2.push(b('view', viewOf(s) === 'side' ? 'One' : 'Side', opts.length > 1), isConfirm(s) ? '<button data-pick="change">Change</button>' : '',
      s.neutral ? `<button data-pick="neither">${esc(s.neutral)}</button>` : '', b('play', 'Play', s.kind === 'audio'));
    whole = b('whole', 'Whole screen', stills && !!s.crop);
  }
  if (s && s.kind === 'gallery') row1.push(b('iprev', '‹ Item'), b('inext', 'Item ›'));
  if (!s) row1.push(b('copy', 'Copy summary'));
  row1.push('<button class="arrow" data-act="next" aria-label="Next step">›</button>');
  const ctls = s ? ctlBarHtml(s) : '';
  row2.push(`<button data-act="sheet" class="${S.sheet ? 'on' : ''}">View</button>`, b('note', 'Note', !!$('[data-note]')));
  // Rare actions live in the View sheet, so the bar stays two rows.
  const sheet = S.sheet ? `<div class="sheet">${ctls}<div class="ctlbar">${whole}${b('legend', 'Keys')}</div></div>` : '';
  return `${sheet}<div class="row">${row1.join('')}</div><div class="row">${row2.join('')}</div>`;
}
function legendHtml() {
  const rows = [['A B C D or 1 2 3 4', 'show that option (side by side: highlight it)'], ['Enter', 'pick the shown option, record it and go on'], ['W', 'one at a time / side by side'],
    ['← → (or [ ], Backspace)', 'previous / next step without picking'], ['N P', 'next / previous item inside a step (gallery)'], ['L or click a picture', 'large view'],
    ['Space', 'play / stop the shown option\'s sound (nothing plays on its own)'], ['Esc', 'close the large view or this list'], ['?', 'this list'],
    ['', 'Keys do nothing while you type in a note. On a phone: the buttons at the bottom (View: the stage controls, Whole screen and this list); tap the picture to zoom, swipe it to flip.']];
  const ctlRows = ctlLegendRows(cur()).map(([k, t, on]) => `<tr class="${on ? '' : 'off'}"><th>${esc(k)}</th><td>${esc(t)}${on ? '' : ' (not on this step)'}</td></tr>`).join('');
  return `<div class="lg"><h2>Keys</h2><table>${rows.map(([k, t]) => `<tr><th>${esc(k)}</th><td>${esc(t)}</td></tr>`).join('')}</table>` +
    `<h3>Stage controls</h3><table>${ctlRows}</table><p>Esc or click to close.</p></div>`;
}
function setHash() {
  const s = cur(), p = new URLSearchParams({ round: S.round.id, step: s ? String(S.n + 1) : 'summary' });
  if (s && CHOICE.has(s.kind) && !isConfirm(s)) p.set('show', shownOf(s));
  if (s && CHOICE.has(s.kind) && viewOf(s) === 'side') p.set('view', 'side');
  if (s && s.kind === 'gallery' && itemOf(s)) p.set('item', itemOf(s).id);
  ctlHash(s, p);
  history.replaceState(null, '', '#' + p.toString().replace(/%2F/g, '/'));
}
function scaleNote() {
  const el = $('.v-flip .ostage:not([hidden]) .pic[data-cw], .k-gallery .gmain .pic[data-cw]'), out = $('.scale');
  if (!out) return;
  const sc = el && el.clientWidth ? el.clientWidth / el.dataset.cw : 1, dpr = devicePixelRatio || 1;
  if (document.body.classList.contains('true100')) out.textContent = `True 100 %: one picture pixel per screen pixel${dpr !== 1 ? ` (screen scale ${dpr}, so it looks ${dpr > 1 ? 'smaller' : 'larger'} than in a game window of that size)` : ''}.`;
  else out.textContent = Math.abs(sc - 1) > 0.02 ? `Shown at ${Math.round(sc * 100)} % of game pixels.` : '';
}
// Phone: with the View sheet open, keep the stage between the header and the bar, so a control's change shows.
function keepStage() {
  const st = $('.stagecol .stage, .stagecol .tiles');
  if (!S.sheet || !PHONE() || !st) return;
  const r = st.getBoundingClientRect(), lo = $('.top').getBoundingClientRect().bottom + 8, hi = $('#phone').getBoundingClientRect().top - 8;
  if (r.bottom > hi) scrollBy(0, Math.min(r.bottom - hi, r.top - lo));
  else if (r.top < lo) scrollBy(0, r.top - lo);
}
function update() {
  const s = cur();
  if (s && CHOICE.has(s.kind)) {
    const shown = shownOf(s), picked = pickOf(K(s.key));
    $$('.ostage, .odetail').forEach((el) => { el.hidden = el.dataset.opt !== shown; });
    $$('[data-show]').forEach((b) => { b.classList.toggle('on', b.dataset.show === shown); b.classList.toggle('done', b.dataset.show === picked); });
    $$('.tile').forEach((t) => { t.classList.toggle('sel', t.dataset.opt === shown); t.classList.toggle('done', t.dataset.opt === picked); });
    $$('.pl').forEach((e) => { e.textContent = shown; });
  }
  $('#phone').innerHTML = phoneHtml(s);
  $$('#phone [data-show]').forEach((b) => b.classList.toggle('on', s && b.dataset.show === shownOf(s)));
  document.body.style.paddingBottom = PHONE() ? `${$('#phone').offsetHeight + 12}px` : '';
  keepStage();
  showRecord();
  setHash();
  requestAnimationFrame(scaleNote);
}
function render() {
  stopAudio();
  S.srcs = [];
  closeOver();
  chipsUpdate();
  const s = cur();
  applyStageClasses(s);
  if (!s) renderSummary();
  else if (s.kind === 'missing') renderMissing(s);
  else if (s.kind === 'gallery') renderGallery(s);
  else if (s.kind === 'verdict') renderVerdict(s);
  else if (s.kind === 'wording') renderWording(s);
  else renderChoice(s);
  observe();
  update();
}

// ---------- actions ----------
function go(n, keepReveal = false) {
  flush();
  if (!keepReveal) { S.revealed = ''; S.lastRec = null; }
  const L = S.steps.length + 1;
  S.n = ((n % L) + L) % L;
  render();
  scrollTo(0, 0);
  keepStage();
}
function choose(x) {
  const s = cur();
  if (!s || !CHOICE.has(s.kind)) return;
  const k = K(s.key);
  if (x === 'change' && !(S.notes[k] || '').trim()) {
    $('#note').focus();
    $('.nhint').textContent = 'Say what to change here, then press Change again.';
    return;
  }
  S.revealed = s.blind && s.options[x] && s.options[x].reveal ? `${x} was ${s.options[x].reveal}.` : '';
  S.sentNote[k] = S.notes[k] || '';
  S.show[s.key] = LETTERS.includes(x) ? x : S.show[s.key];
  post(k, x, S.sentNote[k]);
  go(S.n + 1, true);
}
function verdict(key, v) {
  const k = K(key);
  S.sentNote[k] = S.notes[k] || '';
  flush();
  post(k, v, S.sentNote[k]);
  const s = cur();
  go(s && s.kind === 'verdict' ? S.n + 1 : S.steps.length);
}
function flipOption(d) {
  const s = cur();
  if (!s || !CHOICE.has(s.kind) || isConfirm(s)) return;
  const opts = optsOf(s);
  S.show[s.key] = opts[(opts.indexOf(shownOf(s)) + d + opts.length) % opts.length];
  stopAudio();
  update();
}
function showOption(x) {
  const s = cur();
  if (!s || !optsOf(s).includes(x)) return;
  S.show[s.key] = x;
  stopAudio();
  update();
}
function flipItem(d) {
  const s = cur();
  if (!s || s.kind !== 'gallery') return;
  flush();
  const n = itemsOf(s).length;
  S.item[s.key] = (itemsOf(s).indexOf(itemOf(s)) + d + n) % n;
  render();
}
function toggleView() {
  const s = cur();
  if (!s || !CHOICE.has(s.kind) || optsOf(s).length < 2) return;
  flush();
  S.view[s.key] = viewOf(s) === 'side' ? 'flip' : 'side';
  render();
}
function largeShown(whole) {
  const s = cur();
  const el = s && s.kind === 'gallery' ? $('.gmain [data-src]') : $('.v-flip .ostage:not([hidden]) [data-src]');
  if (el) large(+el.dataset.src, whole);
}
function stopAudio() {
  if (S.audio) S.audio.pause();
  $$('video').forEach((v) => v.pause());
  S.playing = null;
  $$('[data-play] span').forEach((e) => { e.textContent = 'Play'; });
}
function playVideo() {
  const v = $('.v-flip .ostage:not([hidden]) video, .k-gallery .gmain video');
  if (!v) return;
  if (v.paused) v.play().catch((e) => addErr(`clip: ${e.message}`)); else v.pause();
}
function play(x) {
  const s = cur();
  if (s && (s.kind === 'pictures' || s.kind === 'gallery')) { playVideo(); return; }
  if (!s || s.kind !== 'audio' || !s.options[x]) return;
  if (S.playing === x) { stopAudio(); return; }
  stopAudio();
  S.audio ||= Object.assign(new Audio(), { preload: 'none', onended: stopAudio });
  S.audio.src = url(s.options[x].audio);
  S.audio.play().catch((e) => addErr(`sound ${s.options[x].audio}: ${e.message}`));
  S.playing = x;
  $$(`[data-play="${x}"] span`).forEach((e) => { e.textContent = 'Stop'; });
}
function startLab() {
  const s = cur(), box = $('[data-lab]');
  if (!s || !box) return;
  box.innerHTML = `<iframe class="labframe" src="${esc(url(s.url))}" title="lab" style="aspect-ratio:${s.w || 1280}/${s.h || 800}"></iframe>`;
}
async function copySummary() {
  const out = $('.copied');
  try { await navigator.clipboard.writeText(S.summaryText || ''); out.textContent = 'Copied.'; } catch (e) { out.textContent = 'Copy failed: select the table instead.'; }
}
function toggleLegend() {
  const lg = $('#legend');
  if (!lg.hidden) { closeOver(); return; }
  lg.innerHTML = legendHtml();
  lg.hidden = false;
}
const ACTS = {
  prev: () => go(S.n - 1), next: () => go(S.n + 1), pick: () => { const s = cur(); if (s) choose(isConfirm(s) ? 'yes' : shownOf(s)); },
  view: toggleView, large: () => largeShown(), whole: () => largeShown(true), iprev: () => flipItem(-1), inext: () => flipItem(1), retry, copy: copySummary, legend: toggleLegend, lab: startLab,
  play: () => { const s = cur(); if (s) play(shownOf(s)); }, numbers: () => { S.numbers = !S.numbers; render(); }, sheet: () => { S.sheet = !S.sheet; update(); }, note: () => { const n = $('[data-note]'); if (n) { n.scrollIntoView({ block: 'center' }); n.focus(); } },
};

const CLICKS = [
  ['[data-ctl]', (d) => cycleCtl(d.ctl)], ['[data-act]', (d) => ACTS[d.act]()], ['[data-step]', (d) => go(+d.step)],
  ['[data-show]', (d) => showOption(d.show)], ['[data-play]', (d) => play(d.play)], ['[data-verdict]', (d) => verdict(d.vkey, d.verdict)],
  ['[data-item]', (d) => { flush(); S.item[cur().key] = +d.item; render(); }], ['[data-src]', (d) => large(+d.src)], ['[data-pick]', (d) => choose(d.pick)],
];
function onClick(e) {
  if (e.target.closest('#over, #legend')) { closeOver(); return; }
  if (e.target.closest('textarea, input, a, summary, select, video, .pic.live')) return;
  for (const [q, fn] of CLICKS) {
    const el = e.target.closest(q);
    if (el) { fn(el.dataset); return; }
  }
}
function onChange(e) {
  const n = e.target.dataset && e.target.dataset.ctlsel;
  if (n) setCtl(n, e.target.value);
}
function onInput(e) {
  const k = e.target.dataset && e.target.dataset.note;
  if (!k) return;
  S.notes[k] = e.target.value;
  if (k.endsWith(':' + (itemOf(cur() || {}) || {}).id)) $$('.th.on').forEach((t) => t.classList.toggle('noted', !!e.target.value.trim()));
  if (e.target.dataset.live !== undefined) { clearTimeout(S.timer); S.timer = setTimeout(flush, 700); }
}
const KEYMAP = {
  arrowleft: () => ACTS.prev(), arrowright: () => ACTS.next(), '[': () => ACTS.prev(), ']': () => ACTS.next(), backspace: () => ACTS.prev(),
  n: () => nextItem(1), p: () => nextItem(-1), w: toggleView, k: () => ACTS.numbers(), 'shift+r': () => cycleCtl('heading', -1), l: largeShown, enter: () => ACTS.pick(), ' ': () => ACTS.play(), '?': toggleLegend,
};
function nextItem(d) {
  const s = cur();
  if (s && s.kind !== 'gallery' && ctlDef(s, 'state')) cycleCtl('state', d);
  else flipItem(d);
}
function ctlKey(k) {
  const s = cur(), hit = ctlsOf(s).find(([, d]) => d.key === k);
  return hit ? () => cycleCtl(hit[0]) : null;
}
function onKey(e) {
  if (e.key === 'Escape') { closeOver(); return; }
  const t = e.target.tagName;
  if (t === 'TEXTAREA' || t === 'INPUT' || t === 'SELECT' || e.metaKey || e.ctrlKey || e.altKey) return;
  const k = e.shiftKey && /^[a-z]$/i.test(e.key) ? `shift+${e.key.toLowerCase()}` : e.key.toLowerCase();
  if ((k === 'enter' || k === ' ') && (t === 'BUTTON' || t === 'A')) return;
  if (!$('#over').hidden || !$('#legend').hidden) { if (k === '?') toggleLegend(); return; }
  const i = ['1', '2', '3', '4'].includes(k) ? +k - 1 : ['a', 'b', 'c', 'd'].indexOf(k), s = cur();
  if (i >= 0) { if (s && optsOf(s)[i]) showOption(optsOf(s)[i]); return; }
  if (k === 'enter' && (!s || !CHOICE.has(s.kind))) return;
  const act = KEYMAP[k] || ctlKey(k);
  if (!act) return;
  e.preventDefault();
  act();
}
function onTouch(e) {
  if (!e.target.closest('[data-swipe]')) return;
  if (e.type === 'touchstart') { S.touchX = e.changedTouches[0].clientX; return; }
  const dx = e.changedTouches[0].clientX - (S.touchX ?? e.changedTouches[0].clientX);
  S.touchX = null;
  if (Math.abs(dx) < 50) return;
  const s = cur();
  if (s && s.kind === 'gallery') flipItem(dx < 0 ? 1 : -1);
  else flipOption(dx < 0 ? 1 : -1);
}

// ---------- start ----------
function restore(saved) {
  S.saved = saved || {};
  Object.entries(S.saved).forEach(([k, v]) => { S.notes[k] = S.sentNote[k] = (v && v.note) || ''; });
}
function openingStep() {
  const h = H.get('step');
  if (h === 'summary') return S.steps.length;
  if (h) return Math.max(0, Math.min(S.steps.length, +h - 1 || 0));
  const open = S.steps.findIndex((s) => CHOICE.has(s.kind) ? !pickOf(K(s.key)) : s.kind === 'gallery' && s.verdict ? !pickOf(K(s.verdict.key || 'verdict')) : s.kind === 'verdict' && !pickOf(K(s.key)));
  return open < 0 ? S.steps.length : open;
}
function applyHash() {
  ctlFromHash(H);
  const s = cur();
  if (!s) return;
  if (H.get('show') && optsOf(s).includes(H.get('show'))) S.show[s.key] = H.get('show');
  if (H.get('view') === 'side') S.view[s.key] = 'side';
  if (H.get('item')) S.item[s.key] = Math.max(0, itemsOf(s).findIndex((x) => x.id === H.get('item')));
}
function renderIndex() {
  const m = main();
  m.className = 'step k-index';
  const list = REG.index.filter((r) => !r.demo || H.get('demo') === '1');
  m.innerHTML = `<section class="head"><span class="n">Decision page</span><h1>Rounds</h1></section><ul class="rounds">${list.map((r) => `<li><a href="#round=${esc(r.id)}">${esc(r.title || r.id)}</a></li>`).join('')}</ul>`;
}
// #shot=1: the shown option (gallery: item) alone at its frame size on black, for headless screenshots (shoot.sh).
function renderShot() {
  const s = cur(), src = !s ? null : s.kind === 'gallery' ? itemOf(s) : s.options && s.options[shownOf(s)];
  document.body.className = 'shot';
  applyStageClasses(s);
  document.body.classList.remove('true100');
  $('#chips').remove();
  const full = src && src.render ? { ...src, render: { ...src.render, crop: H.get('crop') === 'step' ? undefined : null } } : src;
  main().className = 'shotmain';
  main().innerHTML = pic(full, H.get('crop') === 'step' ? s.crop : null, 'shot', true);
  $$('.pic[data-cw]').forEach((el) => { el.style.width = `${el.dataset.cw}px`; el.style.setProperty('--s', 1); });
}
async function start() {
  await Promise.all([load('rounds/index.js'), load('/picks.js')]);
  if (!H.get('round')) { renderIndex(); return; }
  S.round = await loadRound(H.get('round'));
  S.earlier = (await Promise.all((S.round.earlier || []).map((id) => loadRound(id).catch((e) => { addErr(String(e.message)); return null; })))).filter(Boolean);
  S.steps = stepsOf(S.round);
  document.title = `${S.round.title || S.round.id} · Decision page`;
  const saved = REG.saved || null;
  if (!saved) addErr('picks.json not readable: showing Claude\'s picks; nothing recorded can be restored');
  restore(saved);
  [S.round, ...S.earlier].forEach((r) => (REG.steps[r.id] ? Object.values(REG.steps[r.id]) : []).forEach((s) => checkStep(r, s)));
  S.n = openingStep();
  applyHash();
  if (H.get('shot')) { renderShot(); return; }
  S.sheet = H.get('sheet') === '1';
  render();
  if (H.get('keys') === '1') toggleLegend();
  document.fonts.ready.then(() => { scaleNote(); keepStage(); });
}
document.addEventListener('click', onClick);
document.addEventListener('input', onInput);
document.addEventListener('change', onChange);
document.body.insertAdjacentHTML('beforeend', cvdDefs());
document.addEventListener('keydown', onKey);
document.addEventListener('touchstart', onTouch, { passive: true });
document.addEventListener('touchend', onTouch);
addEventListener('resize', scaleNote);
addEventListener('hashchange', () => location.reload());
start().catch((e) => addErr('start: ' + ((e && e.message) || e)));
