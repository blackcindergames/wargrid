// War Room client: keys, option flips, the large view, the phone bar and playback. htmx does the navigation and the recording.
'use strict';

const PHONE_QUERY = '(max-width:900px),(pointer:coarse)';
const SWIPE_PX = 50;
const failed = new Map();

const $ = (q) => document.querySelector(q);
const $$ = (q, root = document) => [...root.querySelectorAll(q)];
const isPhone = () => matchMedia(PHONE_QUERY).matches;
const rootEl = document.documentElement;
const isRecorder = (el) => el.id === 'answer' || el.hasAttribute('data-note');
const keyOf = (el) => el.dataset.step || el.dataset.note;
const chipOf = (el) => el.dataset.step || el.dataset.chip;
// A pick and a note on the same step are separate entries: they go to different addresses.
const entryOf = (ctx) => `${new URL(ctx.request.action, location.href).pathname} ${keyOf(ctx.sourceElement)}`;

function why(status) {
  return status ? `server refused (HTTP ${status})` : 'server not reachable';
}

function renderFailures() {
  const rec = $('#rec');
  const list = [...failed.values()];
  if (rec && list.length) {
    rec.replaceChildren(Object.assign(document.createElement('span'), { className: 'fail', textContent: `Not recorded: ${why(list[0].status)}. Kept on this page: ${list.map((f) => f.key).join(', ')}.` }), ' ',
      Object.assign(document.createElement('button'), { type: 'button', className: 'btn sm pick', textContent: 'Retry' }));
    rec.querySelector('button').dataset.retry = '';
  } else if (rec?.querySelector('.fail')) {
    rec.replaceChildren();
  }
  document.querySelectorAll('#chips [data-step]').forEach((chip) => {
    chip.classList.toggle('unsent', list.some((f) => f.chip === chip.dataset.step));
  });
}

function flash(text) {
  const box = $('#flash');
  box.textContent = text;
  box.hidden = false;
}

const TOAST_MS = 2000;
let toastTimer = 0;

function toast(text) {
  const box = $('#toast');
  box.textContent = text;
  box.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { box.hidden = true; }, TOAST_MS);
}

function onFailure(evt) {
  const { ctx } = evt.detail;
  const el = ctx.sourceElement;
  const status = ctx.response ? ctx.response.status : 0;
  if (!isRecorder(el)) {
    flash(`${why(status)}: ${ctx.request.action}`);
    return;
  }
  // The body as sent, so Retry resends the pick that failed, not the option shown now.
  failed.set(entryOf(ctx), { key: keyOf(el), chip: chipOf(el), url: ctx.request.action, body: new URLSearchParams(ctx.request.body ?? ''), status, pick: el.id === 'answer' });
  renderFailures();
}

function onSuccess(evt) {
  const { ctx } = evt.detail;
  if (!isRecorder(ctx.sourceElement) || !(ctx.response?.status < 400) || !failed.delete(entryOf(ctx))) return;
  renderFailures();
}

async function retry() {
  const sent = [];
  for (const [k, f] of [...failed]) {
    let status = 0;
    try {
      status = (await fetch(f.url, { method: 'POST', body: f.body, headers: { 'HX-Request': 'true' } })).status;
    } catch { /* stays unsent */ }
    if (!status || status >= 400) { f.status = status; continue; }
    failed.delete(k);
    sent.push(f.key);
    if (f.pick) $$('#chips [data-step]').find((c) => c.dataset.step === f.chip)?.classList.add('done');
  }
  renderFailures();
  if (!failed.size && $('#rec')) $('#rec').textContent = `Recorded: ${sent.join(', ')}.`;
}

function setParam(name, value) {
  const u = new URL(location.href);
  u.searchParams.set(name, value);
  history.replaceState(history.state, '', u);
}

// ---------- pictures ----------

const scaler = new ResizeObserver((entries) => entries.forEach((e) => {
  const w = e.contentRect.width;
  if (w) e.target.style.setProperty('--s', w / e.target.dataset.cw);
}));

function observePics() {
  scaler.disconnect();
  $$('.pic[data-cw]').forEach((el) => scaler.observe(el));
}

function sizeImg(img) {
  img.style.setProperty('--nw', img.naturalWidth);
}

function trackImgs() {
  $$('.pic.img img').forEach((img) => {
    if (img.complete && img.naturalWidth) sizeImg(img);
    else img.addEventListener('load', () => sizeImg(img), { once: true });
  });
}

function scaleNote() {
  const out = $('.scale');
  if (!out) return;
  const el = $('.v-flip .ostage:not([hidden]) .pic[data-cw], .k-gallery .gmain .pic[data-cw]');
  const sc = el && el.clientWidth ? el.clientWidth / el.dataset.cw : 1;
  const dpr = devicePixelRatio || 1;
  if ($('#view')?.classList.contains('true100')) {
    const note = dpr === 1 ? '' : ` (screen scale ${dpr}, so it looks ${dpr > 1 ? 'smaller' : 'larger'} than in a game window of that size)`;
    out.textContent = `True 100 %: one picture pixel per screen pixel${note}.`;
  } else {
    out.textContent = Math.abs(sc - 1) > 0.02 ? `Shown at ${Math.round(sc * 100)} % of game pixels.` : '';
  }
}

// ---------- options ----------

const flipLetters = () => $$('.flipbar [data-show]').map((b) => b.dataset.show);

function showOption(letter) {
  if (!flipLetters().includes(letter)) return;
  $$('.ostage[data-opt], .odetail[data-opt]').forEach((el) => { el.hidden = el.dataset.opt !== letter; });
  $$('.measures [data-measure]').forEach((el) => { el.hidden = el.dataset.measure !== letter; });
  $$('.tile[data-opt]').forEach((el) => el.classList.toggle('sel', el.dataset.opt === letter));
  $$('[data-show]').forEach((b) => b.classList.toggle('on', b.dataset.show === letter));
  $$('[data-shown]').forEach((b) => { b.value = letter; });
  $$('.pl').forEach((el) => { el.textContent = letter; });
  stopMedia();
  setParam('show', letter);
  scaleNote();
}

function flipBy(d) {
  const letters = flipLetters();
  if (!letters.length) return;
  const at = letters.indexOf($('.flipbar [data-show].on')?.dataset.show);
  showOption(letters[(at + d + letters.length) % letters.length]);
}

// ---------- measurements ----------

const MAX_MEASURE_ROWS = 20;
// By frame id, which follows the frame's address: a morph that keeps a frame keeps its rows, and a reloaded frame reports again.
const measures = new Map();

function measureRow([label, value, ok]) {
  const tr = document.createElement('tr');
  const cells = [['th', label], ['td', value]];
  if (typeof ok === 'boolean') cells.push(['td', ok ? '✓' : '✗']);
  for (const [tag, text] of cells) tr.append(Object.assign(document.createElement(tag), { textContent: String(text ?? '') }));
  // Muted, not amber: amber is the pick's colour.
  if (ok === false) tr.className = 'off';
  return tr;
}

function renderMeasures() {
  for (const [id, rows] of measures) {
    const letter = document.getElementById(id)?.closest('.ostage, .tile')?.dataset.opt;
    const out = letter && $(`[data-measure="${letter}"]`);
    if (!out) continue;
    const table = Object.assign(document.createElement('table'), { ariaLabel: `Measured, option ${letter}` });
    table.append(document.createElement('tbody'));
    table.tBodies[0].append(...rows.map(measureRow));
    out.replaceChildren(table);
  }
}

// Only frames on this page, from this origin: a render page reports rows of [label, value, ok?].
function onMessage(e) {
  if (e.origin !== location.origin || e.data?.type !== 'wr:measure' || !Array.isArray(e.data.rows)) return;
  const frame = $$('iframe[id]').find((f) => f.contentWindow === e.source);
  if (!frame) return;
  measures.set(frame.id, e.data.rows.filter(Array.isArray).slice(0, MAX_MEASURE_ROWS));
  renderMeasures();
}

// A frame that reported before this script listened is asked again; one still loading reports when it draws.
function askMeasures() {
  $$('iframe[id]').forEach((f) => f.contentWindow?.postMessage({ type: 'wr:ask-measure' }, location.origin));
}

function forgetGoneFrames() {
  for (const id of [...measures.keys()]) {
    if (!document.getElementById(id)) measures.delete(id);
  }
}

// ---------- large view and phone zoom ----------

const overOpen = () => !$('#over').hidden || !$('#legend').hidden;

function stagePic() {
  return $('.v-flip .ostage:not([hidden]) .pic[data-large], .tile.sel .pic[data-large], .gmain .pic[data-large]');
}

function stillOf(pic) {
  const copy = pic.cloneNode(true);
  copy.querySelector('template')?.remove();
  return copy;
}

function wholeOf(pic) {
  const tpl = pic.querySelector('template[data-whole]');
  return tpl ? tpl.content.firstElementChild.cloneNode(true) : stillOf(pic);
}

function frameSize(node) {
  const img = node.querySelector('img');
  if (img) return { ar: `${img.naturalWidth}/${img.naturalHeight}`, w: img.naturalWidth };
  return { ar: node.style.getPropertyValue('--ar'), w: node.style.getPropertyValue('--cw') };
}

function caption(text) {
  return Object.assign(document.createElement('div'), { className: 'cap', textContent: text });
}

function wholeView(pic, label) {
  const node = wholeOf(pic);
  const { ar, w } = frameSize(node);
  const ov = Object.assign(document.createElement('div'), { className: 'ov' });
  ov.style.cssText = `--oar:${ar};--ow:${w}`;
  ov.append(node);
  return [ov, caption(`${label}. Esc or click to close.`)];
}

// The phone stage already fits the frame, so zoom magnifies its own region: 200 % of game pixels when cropped.
function zoomView(pic, label) {
  const node = stillOf(pic);
  const cropped = !!pic.querySelector('template[data-whole]');
  const k = cropped ? 2 : 1;
  if (node.dataset.cw) node.style.width = `${node.dataset.cw * k}px`;
  const at = cropped ? '200 % of game pixels' : node.dataset.cw ? '100 % of game pixels' : 'full size';
  const ov = Object.assign(document.createElement('div'), { className: 'ov zoom' });
  ov.append(node);
  return [caption(`${label} at ${at}: drag to pan, tap to close.`), ov];
}

function openLarge(pic, whole = !isPhone()) {
  const over = $('#over');
  const label = (pic.dataset.label || '').replace(/`/g, '');
  over.replaceChildren(...(whole ? wholeView(pic, label) : zoomView(pic, label)));
  over.dataset.cvd = $('#view')?.dataset.cvd || 'normal';
  over.classList.toggle('zoom', !whole);
  over.classList.toggle('true100', !!$('#view')?.classList.contains('true100'));
  over.hidden = false;
  trackImgs();
  observePics();
  if (!whole) {
    centreZoom();
    $$('#over img').forEach((im) => im.addEventListener('load', centreZoom, { once: true }));
  }
}

// Opens on the step's mark, or the crop's middle, not on its top-left corner.
function centreZoom() {
  const over = $('#over');
  const at = $('#over .mark') || $('#over .pic');
  if (!at) return;
  const o = over.getBoundingClientRect();
  const r = at.getBoundingClientRect();
  over.scrollBy(r.left + r.width / 2 - (o.left + o.width / 2), r.top + r.height / 2 - (o.top + o.height / 2));
}

function closeOver() {
  if (!overOpen()) return false;
  $('#over').hidden = true;
  $('#legend').hidden = true;
  $('#over').replaceChildren();
  observePics();
  return true;
}

function toggleLegend() {
  if (overOpen()) closeOver();
  else $('#legend').hidden = false;
}

// ---------- playback ----------

let audio = null;
let playing = null;

function stopMedia() {
  audio?.pause();
  playing = null;
  $$('video').forEach((v) => v.pause());
  $$('[data-play] span').forEach((el) => { el.textContent = 'Play'; });
}

function togglePlay(btn) {
  const letter = btn.dataset.play;
  const was = playing;
  stopMedia();
  if (was === letter) return;
  audio ||= Object.assign(new Audio(), { preload: 'none', onended: stopMedia });
  audio.src = btn.dataset.audio;
  playing = letter;
  btn.querySelector('span').textContent = 'Stop';
  audio.play().catch((e) => { stopMedia(); flash(`sound ${btn.dataset.audio}: ${e.message}`); });
}

function playShown() {
  const root = $('.v-flip .ostage:not([hidden]), .tile.sel, .gmain');
  const btn = root?.querySelector('[data-play]');
  if (btn) { togglePlay(btn); return; }
  const clip = root?.querySelector('video');
  if (!clip) return;
  if (clip.paused) clip.play().catch((e) => flash(`clip: ${e.message}`));
  else clip.pause();
}

// ---------- phone bar ----------

const sheetOpen = () => 'sheet' in rootEl.dataset;

// With the View sheet open, keep the stage between the header and the bar, so a control's change shows.
function keepStage() {
  const st = $('.stagecol .stage, .stagecol .tiles');
  if (!sheetOpen() || !isPhone() || !st) return;
  const r = st.getBoundingClientRect();
  const lo = ($('.top')?.getBoundingClientRect().bottom ?? 0) + 8;
  const hi = $('#phone').getBoundingClientRect().top - 8;
  if (r.bottom > hi) scrollBy(0, Math.min(r.bottom - hi, r.top - lo));
  else if (r.top < lo) scrollBy(0, r.top - lo);
}

function syncPhone() {
  $$('[data-act=sheet]').forEach((b) => b.setAttribute('aria-expanded', String(sheetOpen())));
  document.body.style.paddingBottom = isPhone() ? `${$('#phone').offsetHeight + 12}px` : '';
  keepStage();
}

function setSheet(on) {
  if (on) rootEl.dataset.sheet = '';
  else delete rootEl.dataset.sheet;
  syncPhone();
}

function focusNote() {
  const note = $('#main [data-note]');
  if (!note) return;
  note.scrollIntoView({ block: 'center' });
  note.focus();
}

async function copySummary(btn) {
  const out = $('.copied');
  try {
    await navigator.clipboard.writeText($(btn.dataset.copyFrom).textContent);
    if (out) out.textContent = 'Copied.';
  } catch {
    if (out) out.textContent = 'Copy failed: select the table instead.';
  }
}

// ---------- clicks, keys, swipe ----------

const ACTS = {
  legend: toggleLegend,
  sheet: () => setSheet(!sheetOpen()),
  note: focusNote,
  play: playShown,
  whole: () => { const pic = stagePic(); if (pic) openLarge(pic, true); },
  large: () => { const pic = stagePic(); if (pic) openLarge(pic); },
};

const NOT_A_PICTURE_CLICK = 'a, summary, select, video, .pic.live';

const CLICKS = [
  ['[data-retry]', () => retry()],
  ['#flash', () => { $('#flash').hidden = true; }],
  ['[data-show]', (el) => showOption(el.dataset.show)],
  ['.ohd[data-pick]', (el) => showOption(el.dataset.pick)],
  ['[data-play]', togglePlay],
  ['[data-act]', (el) => ACTS[el.dataset.act]?.()],
  ['[data-copy-from]', copySummary],
];

function onClick(e) {
  if (e.target.closest('#over, #legend')) { closeOver(); return; }
  for (const [q, fn] of CLICKS) {
    const el = e.target.closest(q);
    if (el) { fn(el); return; }
  }
  const pic = e.target.closest('.pic[data-large]');
  if (pic && !e.target.closest(NOT_A_PICTURE_CLICK)) openLarge(pic);
}

const KEYMAP = {
  l: ACTS.large,
  ' ': playShown,
  '?': toggleLegend,
};

const KEY_ALIAS = { '[': 'arrowleft', ']': 'arrowright', backspace: 'arrowleft' };

const keyName = (e) => (e.shiftKey && /^[a-z]$/i.test(e.key) ? `shift+${e.key.toLowerCase()}` : e.key.toLowerCase());

function clickKey(k) {
  const key = KEY_ALIAS[k] || k;
  const el = $$('[data-key]').find((x) => x.dataset.key === key) || (key === 'enter' ? $('.tile.sel > .pick') : null);
  if (!el) return false;
  el.click();
  return true;
}

function onKey(e) {
  if (e.key === 'Escape') { closeOver(); return; }
  // A held Enter would pick the next step's shown option too.
  if (e.key === 'Enter' && e.repeat) return;
  if (['TEXTAREA', 'INPUT', 'SELECT'].includes(e.target.tagName) || e.metaKey || e.ctrlKey || e.altKey) return;
  // Tweakpane's sliders are focusable divs that take the arrow keys themselves.
  if (e.key !== 'Enter' && e.target.closest?.('wr-tune')) return;
  const k = keyName(e);
  if ((k === 'enter' || k === ' ') && ['BUTTON', 'A'].includes(e.target.tagName)) return;
  if (overOpen()) {
    if (k === '?') toggleLegend();
    return;
  }
  // A to D by letter or digit; E to H by digit only, since F, G and H are stage controls.
  const letter = /^[1-8]$/.test(k) ? 'ABCDEFGH'[k - 1] : /^[a-d]$/.test(k) ? k.toUpperCase() : '';
  if (letter) { showOption(letter); return; }
  // E to H are digits only; a letter key says which digit and still does its own job (F, G, H are controls).
  if (/^[e-h]$/.test(k) && flipLetters().includes(k.toUpperCase())) toast(`Option ${k.toUpperCase()} is key ${'abcdefgh'.indexOf(k) + 1}`);
  const handled = KEYMAP[k] ? (KEYMAP[k](), true) : clickKey(k);
  if (handled) e.preventDefault();
}

let touchX = null;

function onTouch(e) {
  if (!e.target.closest('[data-swipe]')) return;
  const x = e.changedTouches[0].clientX;
  if (e.type === 'touchstart') { touchX = x; return; }
  const dx = x - (touchX ?? x);
  touchX = null;
  if (Math.abs(dx) < SWIPE_PX) return;
  const d = dx < 0 ? 1 : -1;
  if ($('.k-gallery')) clickKey(d > 0 ? 'n' : 'p');
  else flipBy(d);
}

// ---------- requests and page changes ----------

// A control change or a view toggle keeps the option and item the page shows, which only the address knows.
function keepView(u) {
  const here = new URLSearchParams(location.search);
  for (const k of ['show', 'item']) {
    if (here.has(k)) u.searchParams.set(k, here.get(k));
    else u.searchParams.delete(k);
  }
  if (!u.searchParams.has('view') && here.has('view')) u.searchParams.set('view', here.get('view'));
}

function onConfigRequest(evt) {
  const { request, sourceElement } = evt.detail.ctx;
  const u = new URL(request.action, location.href);
  if (isPhone() && !u.searchParams.has('phone')) u.searchParams.set('phone', '1');
  if (sourceElement?.hasAttribute?.('data-keepview')) keepView(u);
  request.action = u.pathname + u.search;
}

let lastMain = null;

function onSwap() {
  const main = $('#main');
  if (main !== lastMain) {
    lastMain = main;
    stopMedia();
    closeOver();
    if ($('#nhint')?.textContent) focusNote();
  }
  init();
  renderFailures();
}

function init() {
  forgetGoneFrames();
  renderMeasures();
  askMeasures();
  trackImgs();
  observePics();
  rootEl.style.setProperty('--dpr', String(devicePixelRatio || 1));
  syncPhone();
  scaleNote();
}

function start() {
  lastMain = $('#main');
  if (new URLSearchParams(location.search).get('sheet') === '1') rootEl.dataset.sheet = '';
  init();
  document.fonts.ready.then(() => { scaleNote(); keepStage(); });
}

// A broken page script would otherwise fail silently: picks and keys just stop working.
const RELOAD = ' — reload the page; picks may not record';
addEventListener('error', (e) => flash(`Page script error: ${e.message} (${e.filename}:${e.lineno})${RELOAD}`));
addEventListener('unhandledrejection', (e) => flash(`Page script error: ${e.reason?.message ?? e.reason}${RELOAD}`));
addEventListener('message', onMessage);
document.addEventListener('htmx:error', (e) => e.detail.ctx && onFailure(e));
document.addEventListener('htmx:response:error', onFailure);
document.addEventListener('htmx:after:request', onSuccess);
document.addEventListener('htmx:config:request', onConfigRequest);
document.addEventListener('htmx:after:swap', onSwap);
document.addEventListener('click', onClick);
document.addEventListener('keydown', onKey);
document.addEventListener('touchstart', onTouch, { passive: true });
document.addEventListener('touchend', onTouch);
addEventListener('resize', () => { scaleNote(); syncPhone(); });
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
else start();
