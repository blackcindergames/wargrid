// @ts-check
// War Room client: keys, option flips, the large view, the phone bar and playback. htmx does the navigation and the recording.
'use strict';

/** @import { HtmxEvent, HtmxRequestCtx } from 'htmx.org' */
/** @typedef {{ key: string, chip: string, url: string, body: URLSearchParams, status: number, pick: boolean }} Failure */

const PHONE_QUERY = '(max-width:900px),(pointer:coarse)';
const SWIPE_PX = 50;
/** @type {Map<string, Failure>} */
const failed = new Map();

/** @param {string} q @param {ParentNode} [root] @returns {HTMLElement | null} */
const $ = (q, root = document) => /** @type {HTMLElement | null} */ (root.querySelector(q));
/** @param {string} q @param {ParentNode} [root] @returns {HTMLElement[]} */
const $$ = (q, root = document) => /** @type {HTMLElement[]} */ ([...root.querySelectorAll(q)]);

/** @param {string} q @returns {HTMLElement} */
function need(q) {
	const el = $(q);
	if (!el) throw new Error(`missing ${q}`);
	return el;
}

/** @param {EventTarget | null} target @param {string} q @returns {HTMLElement | null} */
const closestOf = (target, q) =>
	target instanceof Element ? /** @type {HTMLElement | null} */ (target.closest(q)) : null;

/** @param {unknown} e */
const messageOf = (e) => (typeof e === 'object' && e !== null && 'message' in e ? String(e.message) : String(e));

const isPhone = () => matchMedia(PHONE_QUERY).matches;
const rootEl = document.documentElement;
/** @param {HTMLElement} el */
const isRecorder = (el) => el.id === 'answer' || el.hasAttribute('data-note');
/** @param {HTMLElement} el */
const keyOf = (el) => el.dataset.step ?? el.dataset.note ?? '';
/** @param {HTMLElement} el */
const chipOf = (el) => el.dataset.step ?? el.dataset.chip ?? '';
/** @param {HtmxRequestCtx} ctx */
const sourceOf = (ctx) => /** @type {HTMLElement} */ (ctx.sourceElement);
// A pick and a note on the same step are separate entries: they go to different addresses.
/** @param {HtmxRequestCtx} ctx */
const entryOf = (ctx) => `${new URL(ctx.request.action, location.href).pathname} ${keyOf(sourceOf(ctx))}`;

/** @param {number | undefined} status */
function why(status) {
	return status ? `server refused (HTTP ${String(status)})` : 'server not reachable';
}

function renderFailures() {
	const rec = $('#rec');
	const list = [...failed.values()];
	if (rec && list.length) {
		const retryButton = Object.assign(document.createElement('button'), {
			type: 'button',
			className: 'btn sm pick',
			textContent: 'Retry',
		});
		retryButton.dataset.retry = '';
		rec.replaceChildren(
			Object.assign(document.createElement('span'), {
				className: 'fail',
				textContent: `Not recorded: ${why(list[0]?.status)}. Kept on this page: ${list.map((f) => f.key).join(', ')}.`,
			}),
			' ',
			retryButton,
		);
	} else if (rec?.querySelector('.fail')) {
		rec.replaceChildren();
	}
	$$('#chips [data-step]').forEach((chip) => {
		chip.classList.toggle(
			'unsent',
			list.some((f) => f.chip === chip.dataset.step),
		);
	});
}

/** @param {string} text */
function flash(text) {
	const box = need('#flash');
	box.textContent = text;
	box.hidden = false;
}

const TOAST_MS = 2000;
let toastTimer = 0;

/** @param {string} text */
function toast(text) {
	const box = need('#toast');
	box.textContent = text;
	box.hidden = false;
	clearTimeout(toastTimer);
	toastTimer = setTimeout(() => {
		box.hidden = true;
	}, TOAST_MS);
}

/** @param {HtmxRequestCtx} ctx */
function onFailure(ctx) {
	const el = sourceOf(ctx);
	const status = ctx.response?.status ?? 0;
	if (!isRecorder(el)) {
		flash(`${why(status)}: ${ctx.request.action}`);
		return;
	}
	const entry = entryOf(ctx);
	// Re-added at the end, so Retry sends in the order the failures happened and the newest note lands last.
	failed.delete(entry);
	// The body as sent, so Retry resends the pick that failed, not the option shown now.
	failed.set(entry, {
		key: keyOf(el),
		chip: chipOf(el),
		url: ctx.request.action,
		body: new URLSearchParams(/** @type {string} */ (ctx.request.body ?? '')),
		status,
		pick: el.id === 'answer',
	});
	renderFailures();
}

/** @param {HtmxRequestCtx} ctx */
function onSuccess(ctx) {
	const status = ctx.response?.status;
	const el = sourceOf(ctx);
	if (!isRecorder(el) || status === undefined || status >= 400) return;
	failed.delete(entryOf(ctx));
	dropStaleNotes(keyOf(el));
	renderFailures();
}

// Every recorded write carries the step's newest note, so a failed older one must not come back with Retry.
/** @param {string} key */
function dropStaleNotes(key) {
	for (const [k, f] of failed) {
		if (f.key !== key) continue;
		if (f.pick) f.body.delete('note');
		else failed.delete(k);
	}
}

async function retry() {
	const sent = [];
	for (const [k, f] of [...failed]) {
		let status = 0;
		try {
			status = (
				await fetch(f.url, {
					method: 'POST',
					body: f.body,
					headers: { 'HX-Request': 'true' },
				})
			).status;
		} catch {
			/* stays unsent */
		}
		if (!status || status >= 400) {
			f.status = status;
			continue;
		}
		failed.delete(k);
		sent.push(f.key);
		if (f.pick)
			$$('#chips [data-step]')
				.find((c) => c.dataset.step === f.chip)
				?.classList.add('done');
	}
	renderFailures();
	const rec = $('#rec');
	if (!failed.size && rec) rec.textContent = `Recorded: ${sent.join(', ')}.`;
}

/** @param {string} name @param {string} value */
function setParam(name, value) {
	const u = new URL(location.href);
	u.searchParams.set(name, value);
	history.replaceState(history.state, '', u);
}

// ---------- pictures ----------

const scaler = new ResizeObserver((entries) => {
	for (const e of entries) {
		const w = e.contentRect.width;
		const target = /** @type {HTMLElement} */ (e.target);
		if (w) target.style.setProperty('--s', String(w / Number(target.dataset.cw)));
	}
});

function observePics() {
	scaler.disconnect();
	for (const el of $$('.pic[data-cw]')) scaler.observe(el);
}

/** @param {HTMLImageElement} img */
function sizeImg(img) {
	img.style.setProperty('--nw', String(img.naturalWidth));
}

function trackImgs() {
	/** @type {NodeListOf<HTMLImageElement>} */ (document.querySelectorAll('.pic.img img')).forEach((img) => {
		if (img.complete && img.naturalWidth) sizeImg(img);
		else
			img.addEventListener(
				'load',
				() => {
					sizeImg(img);
				},
				{ once: true },
			);
	});
}

function scaleNote() {
	const out = $('.scale');
	if (!out) return;
	const el = $('.v-flip .ostage:not([hidden]) .pic[data-cw], .k-gallery .gmain .pic[data-cw]');
	const sc = el?.clientWidth ? el.clientWidth / Number(el.dataset.cw) : 1;
	const dpr = devicePixelRatio || 1;
	const pct = Math.abs(sc - 1) > 0.02 ? `${String(Math.round(sc * 100))} %` : '';
	// The status line is one line: there the note only completes its Fit or True 100 % value.
	if (out.closest('.status')) {
		const t100 = $('#view')?.classList.contains('true100');
		out.textContent = t100 ? (dpr === 1 ? '' : ` (screen scale ${String(dpr)})`) : pct && ` ${pct}`;
		return;
	}
	if ($('#view')?.classList.contains('true100')) {
		const note =
			dpr === 1
				? ''
				: ` (screen scale ${String(dpr)}, so it looks ${dpr > 1 ? 'smaller' : 'larger'} than in a game window of that size)`;
		out.textContent = `True 100 %: one picture pixel per screen pixel${note}.`;
	} else {
		out.textContent = pct && `Shown at ${pct} of game pixels.`;
	}
}

// ---------- options ----------

// About repeats exactly the notes a row's two lines cut, which only layout knows.
function markCutNotes() {
	for (const row of $$('.orow[data-show]')) {
		const note = $('.onote', row);
		$(`.about[data-opt="${row.dataset.show ?? ''}"]`)?.classList.toggle(
			'cut',
			!!note && note.scrollHeight > note.clientHeight + 1,
		);
	}
}

// The fade says the list goes on below its box.
function markMoreOpts() {
	const list = $('.rpanel .opts');
	const more = $('.rpanel .omore');
	if (list && more) more.hidden = list.scrollTop + list.clientHeight >= list.scrollHeight - 1;
}

// Option letters only: Today is never a flip or swipe step, just key 0 or its own row.
const flipLetters = () => $$('.opts .orow:not(.today)').map((b) => b.dataset.show);

/** @param {string} letter an option letter or today @param {HTMLVideoElement} [keep] a clip that just started in this option, left playing */
function showOption(letter, keep) {
	const today = letter === 'today';
	if (today ? !$('.opts .orow.today') : !flipLetters().includes(letter)) return;
	$$('.ostage[data-opt], .moreof [data-opt], .about[data-opt]').forEach((el) => {
		el.hidden = el.dataset.opt !== letter;
	});
	$$('.measures [data-measure]').forEach((el) => {
		el.hidden = el.dataset.measure !== letter;
	});
	$$('.tile[data-opt]').forEach((el) => el.classList.toggle('sel', el.dataset.opt === letter));
	$$('.orow[data-show]').forEach((el) => el.classList.toggle('sel', el.dataset.show === letter));
	$$('.ob[data-show]').forEach((b) => b.classList.toggle('on', b.dataset.show === letter));
	stopMedia(keep);
	scaleNote();
	// Today is for looking only, so nothing may be recorded while it is shown.
	/** @type {NodeListOf<HTMLButtonElement>} */ (document.querySelectorAll('button.pick[name=pick]')).forEach((b) => {
		b.disabled = today;
	});
	$$('.ptab').forEach((el) => {
		el.hidden = el.dataset.cp !== letter;
	});
	if (today) return;
	/** @type {NodeListOf<HTMLInputElement>} */ (document.querySelectorAll('[data-shown]')).forEach((b) => {
		b.value = letter;
	});
	$$('.pl').forEach((el) => {
		el.textContent = letter;
	});
	setParam('show', letter);
}

/** @param {number} d */
function flipBy(d) {
	const letters = flipLetters();
	if (!letters.length) return;
	const at = letters.indexOf($('.opts .orow.sel')?.dataset.show);
	// From Today (not in the list) a swipe goes to the first or the last option.
	const next = at < 0 ? letters.at(d > 0 ? 0 : -1) : letters[(at + d + letters.length) % letters.length];
	if (next) showOption(next);
}

// ---------- measurements ----------

const MAX_MEASURE_ROWS = 20;
// By frame id, which follows the frame's address: a morph that keeps a frame keeps its rows, and a reloaded frame reports again.
/** @typedef {string | number | boolean | null | undefined} Cell */
/** @type {Map<string, Cell[][]>} */
const measures = new Map();

/** @param {Cell[]} row */
function measureRow([label, value, ok]) {
	const tr = document.createElement('tr');
	/** @type {['th' | 'td', Cell][]} */
	const cells = [
		['th', label],
		['td', value],
	];
	if (typeof ok === 'boolean') cells.push(['td', ok ? '✓' : '✗']);
	for (const [tag, text] of cells)
		tr.append(
			Object.assign(document.createElement(tag), {
				textContent: String(text ?? ''),
			}),
		);
	// Muted, not amber: amber is the pick's colour.
	if (ok === false) tr.className = 'off';
	return tr;
}

function renderMeasures() {
	for (const [id, rows] of measures) {
		const letter = closestOf(document.getElementById(id), '.ostage, .tile')?.dataset.opt;
		const out = letter ? $(`[data-measure="${letter}"]`) : null;
		if (!letter || !out) continue;
		const table = Object.assign(document.createElement('table'), {
			ariaLabel: `Measured, option ${letter}`,
		});
		const body = document.createElement('tbody');
		body.append(...rows.map(measureRow));
		table.append(body);
		out.replaceChildren(table);
	}
}

// Only frames on this page, from this origin: a render page reports rows of [label, value, ok?].
/** @param {unknown} d @returns {d is { type: 'wr:measure', rows: unknown[] }} */
const isMeasure = (d) =>
	typeof d === 'object' && d !== null && 'type' in d && d.type === 'wr:measure' && 'rows' in d && Array.isArray(d.rows);

/** @param {unknown} r @returns {r is Cell[]} */
const isRow = (r) => Array.isArray(r);

/** @param {MessageEvent<unknown>} e */
function onMessage(e) {
	const data = e.data;
	if (e.origin !== location.origin || !isMeasure(data)) return;
	const frame = /** @type {HTMLIFrameElement[]} */ ($$('iframe[id]')).find((f) => f.contentWindow === e.source);
	if (!frame) return;
	measures.set(frame.id, data.rows.filter(isRow).slice(0, MAX_MEASURE_ROWS));
	renderMeasures();
}

// A frame that reported before this script listened is asked again; one still loading reports when it draws.
function askMeasures() {
	for (const f of /** @type {HTMLIFrameElement[]} */ ($$('iframe[id]')))
		f.contentWindow?.postMessage({ type: 'wr:ask-measure' }, location.origin);
}

function forgetGoneFrames() {
	for (const id of [...measures.keys()]) {
		if (!document.getElementById(id)) measures.delete(id);
	}
}

// ---------- large view and phone zoom ----------

const overOpen = () => !need('#over').hidden || !need('#legend').hidden;

function stagePic() {
	return $('.v-flip .ostage:not([hidden]) .pic[data-large], .tile.sel .pic[data-large], .gmain .pic[data-large]');
}

/** @param {HTMLElement} pic @returns {HTMLElement} */
function stillOf(pic) {
	const copy = /** @type {HTMLElement} */ (pic.cloneNode(true));
	copy.querySelector('template')?.remove();
	return copy;
}

/** @param {HTMLElement} pic @returns {HTMLElement} */
function wholeOf(pic) {
	const tpl = /** @type {HTMLTemplateElement | null} */ (pic.querySelector('template[data-whole]'));
	return tpl
		? /** @type {HTMLElement} */ (/** @type {Element} */ (tpl.content.firstElementChild).cloneNode(true))
		: stillOf(pic);
}

/** @param {HTMLElement} node */
function frameSize(node) {
	const img = node.querySelector('img');
	if (img)
		return {
			ar: `${String(img.naturalWidth)}/${String(img.naturalHeight)}`,
			w: String(img.naturalWidth),
		};
	return {
		ar: node.style.getPropertyValue('--ar'),
		w: node.style.getPropertyValue('--cw'),
	};
}

/** @param {string} text */
function caption(text) {
	return Object.assign(document.createElement('div'), {
		className: 'cap',
		textContent: text,
	});
}

/** @param {HTMLElement} pic @param {string} label */
function wholeView(pic, label) {
	const node = wholeOf(pic);
	const { ar, w } = frameSize(node);
	const ov = Object.assign(document.createElement('div'), { className: 'ov' });
	ov.style.cssText = `--oar:${ar};--ow:${w}`;
	ov.append(node);
	return [ov, caption(`${label}. Esc or click to close.`)];
}

// The phone stage already fits the frame, so zoom magnifies its own region: 200 % of game pixels when cropped.
/** @param {HTMLElement} pic @param {string} label */
function zoomView(pic, label) {
	const node = stillOf(pic);
	const cropped = !!pic.querySelector('template[data-whole]');
	const k = cropped ? 2 : 1;
	if (node.dataset.cw) node.style.width = `${String(Number(node.dataset.cw) * k)}px`;
	const at = cropped ? '200 % of game pixels' : node.dataset.cw ? '100 % of game pixels' : 'full size';
	const ov = Object.assign(document.createElement('div'), {
		className: 'ov zoom',
	});
	ov.append(node);
	return [caption(`${label} at ${at}: drag to pan, tap to close.`), ov];
}

/** @param {HTMLElement} pic @param {boolean} [whole] */
function openLarge(pic, whole = !isPhone()) {
	const over = need('#over');
	const label = (pic.dataset.label ?? '').replace(/`/g, '');
	over.replaceChildren(...(whole ? wholeView(pic, label) : zoomView(pic, label)));
	over.dataset.cvd = $('#view')?.dataset.cvd ?? 'normal';
	over.classList.toggle('zoom', !whole);
	over.classList.toggle('true100', !!$('#view')?.classList.contains('true100'));
	over.hidden = false;
	trackImgs();
	observePics();
	if (!whole) {
		centreZoom();
		for (const im of $$('#over img')) im.addEventListener('load', centreZoom, { once: true });
	}
}

// Opens on the step's mark, or the crop's middle, not on its top-left corner.
function centreZoom() {
	const over = need('#over');
	const at = $('#over .mark') ?? $('#over .pic');
	if (!at) return;
	const o = over.getBoundingClientRect();
	const r = at.getBoundingClientRect();
	over.scrollBy(r.left + r.width / 2 - (o.left + o.width / 2), r.top + r.height / 2 - (o.top + o.height / 2));
}

function closeOver() {
	if (!overOpen()) return false;
	need('#over').hidden = true;
	need('#legend').hidden = true;
	need('#over').replaceChildren();
	observePics();
	return true;
}

function toggleLegend() {
	if (overOpen()) closeOver();
	else need('#legend').hidden = false;
}

// ---------- playback ----------

/** @type {HTMLAudioElement | null} */
let audio = null;
/** @type {string | undefined} */
let playing;

/** @param {HTMLVideoElement} [keep] */
function stopMedia(keep) {
	audio?.pause();
	playing = undefined;
	document.querySelectorAll('video').forEach((v) => {
		if (v !== keep) v.pause();
	});
	$$('[data-play] span').forEach((el) => {
		el.textContent = 'Play';
	});
}

/** @param {HTMLElement} btn */
function togglePlay(btn) {
	const letter = btn.dataset.play;
	const was = playing;
	stopMedia();
	if (was === letter) return;
	audio ??= Object.assign(new Audio(), { preload: 'none', onended: stopMedia });
	audio.src = btn.dataset.audio ?? '';
	playing = letter;
	const label = btn.querySelector('span');
	if (label) label.textContent = 'Stop';
	audio.play().catch((/** @type {unknown} */ e) => {
		stopMedia();
		flash(`sound ${btn.dataset.audio ?? ''}: ${messageOf(e)}`);
	});
}

function playShown() {
	const root = $('.v-flip .ostage:not([hidden]), .tile.sel, .gmain');
	const btn = root ? $('[data-play]', root) : null;
	if (btn) {
		togglePlay(btn);
		return;
	}
	const clip = root?.querySelector('video');
	if (!clip) return;
	if (clip.paused)
		clip.play().catch((/** @type {unknown} */ e) => {
			flash(`clip: ${messageOf(e)}`);
		});
	else clip.pause();
}

// ---------- phone bar ----------

const sheetOpen = () => 'sheet' in rootEl.dataset;

// With the Controls sheet open, keep the stage between the header and the bar, so a control's change shows.
function keepStage() {
	const st = $('.stagecol .stage, .stagecol .tiles');
	if (!sheetOpen() || !isPhone() || !st) return;
	const r = st.getBoundingClientRect();
	const lo = ($('.top')?.getBoundingClientRect().bottom ?? 0) + 8;
	const hi = need('#phone').getBoundingClientRect().top - 8;
	if (r.bottom > hi) scrollBy(0, Math.min(r.bottom - hi, r.top - lo));
	else if (r.top < lo) scrollBy(0, r.top - lo);
}

function syncPhone() {
	for (const b of $$('[data-act=sheet]')) b.setAttribute('aria-expanded', String(sheetOpen()));
	keepStage();
}

/** @param {boolean} on */
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

/** @param {HTMLElement} btn */
async function copySummary(btn) {
	const out = $('.copied');
	try {
		await navigator.clipboard.writeText(need(btn.dataset.copyFrom ?? '').textContent);
		if (out) out.textContent = 'Copied.';
	} catch {
		if (out) out.textContent = 'Copy failed: select the table instead.';
	}
}

// ---------- clicks, keys, swipe ----------

/** @type {Record<string, () => void>} */
const ACTS = {
	legend: toggleLegend,
	sheet: () => {
		setSheet(!sheetOpen());
	},
	note: focusNote,
	play: playShown,
	whole: () => {
		const pic = stagePic();
		if (pic) openLarge(pic, true);
	},
	large: () => {
		const pic = stagePic();
		if (pic) openLarge(pic);
	},
};

const NOT_A_PICTURE_CLICK = 'a, summary, select, video, .pic.live';

/** @type {[string, (el: HTMLElement) => void][]} */
const CLICKS = [
	[
		'[data-retry]',
		() => {
			void retry();
		},
	],
	[
		'#flash',
		() => {
			need('#flash').hidden = true;
		},
	],
	[
		'[data-show]',
		(el) => {
			// A row kept focused by a click would take the next Enter instead of Pick.
			if (!el.matches(':focus-visible')) el.blur();
			showOption(el.dataset.show ?? '');
		},
	],
	[
		'summary',
		(el) => {
			// Like a row: a fold kept focused by a click would take the next Enter instead of Pick.
			if (!el.matches(':focus-visible')) el.blur();
		},
	],
	[
		'.ohd[data-pick]',
		(el) => {
			showOption(el.dataset.pick ?? '');
		},
	],
	[
		'[data-play]',
		(el) => {
			// Enter picks the selected tile, so the one whose sound plays must be it.
			const opt = closestOf(el, '.tile[data-opt]:not(.sel)')?.dataset.opt;
			if (opt) showOption(opt);
			togglePlay(el);
		},
	],
	[
		'[data-act]',
		(el) => {
			ACTS[el.dataset.act ?? '']?.();
		},
	],
	[
		'[data-copy-from]',
		(el) => {
			void copySummary(el);
		},
	],
];

/** @param {MouseEvent} e */
function onClick(e) {
	if (closestOf(e.target, '#over, #legend')) {
		closeOver();
		return;
	}
	for (const [q, fn] of CLICKS) {
		const el = closestOf(e.target, q);
		if (el) {
			fn(el);
			return;
		}
	}
	const tile = closestOf(e.target, '.tile[data-opt]:not(.sel)')?.dataset.opt;
	// A clip selects its tile from its play event (below), so this click must not pause it.
	if (tile && !closestOf(e.target, 'video')) {
		showOption(tile);
		return;
	}
	const pic = closestOf(e.target, '.pic[data-large]');
	if (pic && !closestOf(e.target, NOT_A_PICTURE_CLICK)) openLarge(pic);
}

/** @type {Record<string, (() => void) | undefined>} */
const KEYMAP = {
	l: ACTS.large,
	' ': playShown,
	'?': toggleLegend,
};

/** @type {Record<string, string | undefined>} */
const KEY_ALIAS = {
	'[': 'arrowleft',
	']': 'arrowright',
	backspace: 'arrowleft',
};

/** @param {KeyboardEvent} e */
const keyName = (e) => (e.shiftKey && /^[a-z]$/i.test(e.key) ? `shift+${e.key.toLowerCase()}` : e.key.toLowerCase());

/** @param {string} k */
function clickKey(k) {
	const key = KEY_ALIAS[k] ?? k;
	const el = $$('[data-key]').find((x) => x.dataset.key === key);
	if (!el) return false;
	el.click();
	return true;
}

/** @param {KeyboardEvent} e */
function onKey(e) {
	if (e.key === 'Escape') {
		closeOver();
		return;
	}
	// A held Enter would pick the next step's shown option too.
	if (e.key === 'Enter' && e.repeat) return;
	const tag = e.target instanceof Element ? e.target.tagName : '';
	if (['TEXTAREA', 'INPUT', 'SELECT'].includes(tag) || e.metaKey || e.ctrlKey || e.altKey) return;
	// Tweakpane's sliders are focusable divs that take the arrow keys themselves.
	if (e.key !== 'Enter' && closestOf(e.target, 'wr-tune')) return;
	const k = keyName(e);
	if ((k === 'enter' || k === ' ') && ['BUTTON', 'A', 'SUMMARY'].includes(tag)) return;
	if (overOpen()) {
		if (k === '?') toggleLegend();
		return;
	}
	// A to D by letter or digit; E to H by digit only, since F, G and H are stage controls.
	const letter = /^[1-8]$/.test(k) ? ('ABCDEFGH'[Number(k) - 1] ?? '') : /^[a-d]$/.test(k) ? k.toUpperCase() : '';
	if (letter) {
		showOption(letter);
		return;
	}
	// E to H are digits only; a letter key says which digit and still does its own job (F, G, H are controls).
	if (/^[e-h]$/.test(k) && flipLetters().includes(k.toUpperCase()))
		toast(`Option ${k.toUpperCase()} is key ${String('abcdefgh'.indexOf(k) + 1)}`);
	const run = KEYMAP[k];
	if (run) run();
	else if (!clickKey(k)) return;
	e.preventDefault();
}

/** @type {number | null} */
let touchX = null;

/** @param {TouchEvent} e */
function onTouch(e) {
	if (!closestOf(e.target, '[data-swipe]')) return;
	const x = e.changedTouches[0]?.clientX;
	if (x === undefined) return;
	if (e.type === 'touchstart') {
		touchX = x;
		return;
	}
	const dx = x - (touchX ?? x);
	touchX = null;
	if (Math.abs(dx) < SWIPE_PX) return;
	const d = dx < 0 ? 1 : -1;
	if ($('.k-gallery')) clickKey(d > 0 ? 'n' : 'p');
	else flipBy(d);
}

// ---------- requests and page changes ----------

// A control change or a view toggle keeps the option and item the page shows, which only the address knows.
/** @param {URL} u */
function keepView(u) {
	const here = new URLSearchParams(location.search);
	for (const k of ['show', 'item']) {
		const v = here.get(k);
		if (v === null) u.searchParams.delete(k);
		else u.searchParams.set(k, v);
	}
	const view = here.get('view');
	if (!u.searchParams.has('view') && view !== null) u.searchParams.set('view', view);
}

/** @param {HtmxEvent<'htmx:config:request'>} evt */
function onConfigRequest(evt) {
	const { request, sourceElement } = evt.detail.ctx;
	const u = new URL(request.action, location.href);
	if (isPhone() && !u.searchParams.has('phone')) u.searchParams.set('phone', '1');
	if (sourceElement.hasAttribute('data-keepview')) keepView(u);
	request.action = u.pathname + u.search;
}

/** @type {HTMLElement | null} */
let lastMain = null;

function onSwap() {
	const main = $('#main');
	if (main !== lastMain) {
		lastMain = main;
		stopMedia();
		closeOver();
		if ($('#main [data-note][autofocus]')) focusNote();
	}
	init();
	renderFailures();
}

// The fixed zones fill the window below the read-only or error banner.
function fitBanners() {
	const h = $$('#view > :is(#err, #readonly)').reduce((sum, el) => sum + el.offsetHeight, 0);
	rootEl.style.setProperty('--banner', `${String(h)}px`);
}

// On a phone the step strip scrolls sideways, and the current step may start out of view.
function showCurrentChip() {
	const strip = $('#chips');
	const on = $('#chips [aria-current=step]');
	if (!strip || !on) return;
	const s = strip.getBoundingClientRect();
	const r = on.getBoundingClientRect();
	strip.scrollLeft += r.left - s.left - (s.width - r.width) / 2;
}

function init() {
	fitBanners();
	showCurrentChip();
	markMoreOpts();
	markCutNotes();
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
	void document.fonts.ready.then(() => {
		markCutNotes();
		scaleNote();
		keepStage();
	});
}

// A broken page script would otherwise fail silently: picks and keys just stop working.
const RELOAD = ' — reload the page; picks may not record';
addEventListener('error', (e) => {
	flash(`Page script error: ${e.message} (${e.filename}:${String(e.lineno)})${RELOAD}`);
});
addEventListener('unhandledrejection', (e) => {
	flash(`Page script error: ${messageOf(e.reason)}${RELOAD}`);
});
addEventListener('message', onMessage);
// Unsent picks and notes live only on this page.
addEventListener('beforeunload', (e) => {
	if (failed.size) e.preventDefault();
});
document.addEventListener('htmx:error', (e) => {
	if (e.detail.ctx) onFailure(e.detail.ctx);
});
document.addEventListener('htmx:response:error', (e) => {
	onFailure(e.detail.ctx);
});
document.addEventListener('htmx:after:request', (e) => {
	onSuccess(e.detail.ctx);
});
document.addEventListener('htmx:config:request', onConfigRequest);
document.addEventListener('htmx:after:swap', onSwap);
document.addEventListener('click', onClick);
document.addEventListener('keydown', onKey);
// Firefox's video controls keep the click, so a clip started in another tile selects that tile here.
document.addEventListener(
	'play',
	(e) => {
		const clip = e.target instanceof HTMLVideoElement ? e.target : undefined;
		const opt = closestOf(clip ?? null, '.tile[data-opt]:not(.sel)')?.dataset.opt;
		if (opt) showOption(opt, clip);
	},
	true,
);
document.addEventListener('touchstart', onTouch, { passive: true });
document.addEventListener('touchend', onTouch);
addEventListener('resize', () => {
	fitBanners();
	markMoreOpts();
	markCutNotes();
	scaleNote();
	syncPhone();
});
// Scroll does not bubble, so the Options list's is caught on the way down.
document.addEventListener(
	'scroll',
	(e) => {
		if (closestOf(e.target, '.rpanel .opts')) markMoreOpts();
	},
	true,
);
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
else start();
