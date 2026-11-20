// node_modules/svelte/src/internal/disclose-version.js
typeof window < "u" && ((window.__svelte ??= {}).v ??= /* @__PURE__ */ new Set()).add("5");
// node_modules/svelte/src/constants.js
var e = {}, t = Symbol("uninitialized"), n = Array.isArray, r = Array.prototype.indexOf, i = Array.prototype.includes, a = Array.from, o = Object.keys, s = Object.defineProperty, c = Object.getOwnPropertyDescriptor, l = Object.prototype, u = Array.prototype, d = Object.getPrototypeOf, f = Object.isExtensible, p = () => {};
function m(e) {
	for (var t = 0; t < e.length; t++) e[t]();
}
function ee() {
	var e, t;
	return {
		promise: new Promise((n, r) => {
			e = n, t = r;
		}),
		resolve: e,
		reject: t
	};
}
var h = 1024, g = 2048, _ = 4096, te = 8192, ne = 16384, re = 32768, ie = 1 << 25, ae = 65536, oe = 1 << 19, se = 1 << 20, ce = 1 << 21, le = 1 << 23, ue = Symbol("$state"), de = Symbol("component"), fe = Symbol("legacy props"), pe = Symbol("attributes"), me = Symbol("class"), he = Symbol("style"), ge = Symbol("text"), _e = new class extends Error {
	name = "StaleReactionError";
	message = "The reaction that called `getAbortSignal()` was re-run or destroyed";
}();
globalThis.document?.contentType;
function ve() {
	console.warn("https://svelte.dev/e/derived_inert");
}
function ye(e) {
	console.warn("https://svelte.dev/e/hydration_mismatch");
}
function be() {
	console.warn("https://svelte.dev/e/svelte_boundary_reset_noop");
}
// node_modules/svelte/src/internal/client/dom/hydration.js
var v = !1;
function xe(e) {
	v = e;
}
var y;
function Se(t) {
	if (t === null) throw ye(), e;
	return y = t;
}
function Ce() {
	return Se(/* @__PURE__ */ Ut(y));
}
function we(e = 1) {
	if (v) {
		for (var t = e, n = y; t--;) n = /* @__PURE__ */ Ut(n);
		y = n;
	}
}
function Te(e = !0) {
	for (var t = 0, n = y;;) {
		if (n.nodeType === 8) {
			var r = n.data;
			if (r === "]") {
				if (t === 0) return n;
				--t;
			} else (r === "[" || r === "[!" || r[0] === "[" && !isNaN(Number(r.slice(1)))) && (t += 1);
		}
		var i = /* @__PURE__ */ Ut(n);
		e && n.remove(), n = i;
	}
}
function Ee(t) {
	if (!t || t.nodeType !== 8) throw ye(), e;
	return t.data;
}
// node_modules/svelte/src/internal/client/reactivity/equality.js
function De(e) {
	return e === this.v;
}
function Oe(e, t) {
	return e == e ? e !== t || typeof e == "object" && !!e || typeof e == "function" : t == t;
}
function ke(e) {
	return !Oe(e, this.v);
}
function Ae(e) {
	throw Error("https://svelte.dev/e/effect_in_teardown");
}
function je() {
	throw Error("https://svelte.dev/e/effect_in_unowned_derived");
}
function Me(e) {
	throw Error("https://svelte.dev/e/effect_orphan");
}
function Ne() {
	throw Error("https://svelte.dev/e/effect_update_depth_exceeded");
}
function Pe() {
	throw Error("https://svelte.dev/e/hydration_failed");
}
function Fe(e) {
	throw Error("https://svelte.dev/e/props_invalid_value");
}
function Ie() {
	throw Error("https://svelte.dev/e/state_descriptors_fixed");
}
function Le() {
	throw Error("https://svelte.dev/e/state_prototype_fixed");
}
function Re() {
	throw Error("https://svelte.dev/e/state_unsafe_mutation");
}
function ze() {
	throw Error("https://svelte.dev/e/svelte_boundary_reset_onerror");
}
// node_modules/svelte/src/internal/client/context.js
var b = null;
function Be(e) {
	b = e;
}
function Ve(e, t = !1, n) {
	b = {
		p: b,
		i: !1,
		c: null,
		e: null,
		s: e,
		x: null,
		r: k,
		l: null
	};
}
function He(e) {
	var t = b, n = t.e;
	if (n !== null) {
		t.e = null;
		for (var r of n) $t(r);
	}
	return e !== void 0 && (t.x = e), t.i = !0, b = t.p, Ue(e);
}
function Ue(e = {}) {
	return s(e, de, { value: !0 }), e;
}
function We() {
	return !0;
}
// node_modules/svelte/src/internal/client/dom/task.js
var Ge = [];
function Ke() {
	var e = Ge;
	Ge = [], m(e);
}
function qe(e) {
	if (Ge.length === 0 && !ut) {
		var t = Ge;
		queueMicrotask(() => {
			t === Ge && Ke();
		});
	}
	Ge.push(e);
}
function Je() {
	for (; Ge.length > 0;) Ke();
}
// node_modules/svelte/src/internal/client/reactivity/status.js
var Ye = ~(g | _ | h);
function x(e, t) {
	e.f = e.f & Ye | t;
}
function Xe(e) {
	e.f & 512 || e.deps === null ? x(e, h) : x(e, _);
}
// node_modules/svelte/src/internal/client/reactivity/utils.js
function Ze(e, t) {
	e.f & 2048 ? t.set(e, g) : e.f & 4096 && t.get(e) !== 2048 && t.set(e, _), x(e, h);
}
// node_modules/svelte/src/internal/client/dom/elements/bindings/shared.js
function Qe(e) {
	var t = E, n = k;
	O(null), _n(null);
	try {
		return e();
	} finally {
		O(t), _n(n);
	}
}
/*#__NO_SIDE_EFFECTS__*/
function $e(e) {
	var n = 2 | g;
	return k !== null && (k.f |= oe), {
		ctx: b,
		deps: null,
		effects: null,
		equals: De,
		f: n,
		fn: e,
		reactions: null,
		rv: 0,
		v: t,
		wv: 0,
		parent: k,
		ac: null
	};
}
var et = Symbol("obsolete");
/*#__NO_SIDE_EFFECTS__*/
function tt(e) {
	let t = /* @__PURE__ */ $e(e);
	return t.equals = ke, t;
}
function nt(e) {
	var t = e.effects;
	if (t !== null) {
		e.effects = null;
		for (var n = 0; n < t.length; n += 1) T(t[n]);
	}
}
function rt(e) {
	var n, r = k, i = e.parent;
	if (!hn && i !== null && e.v !== t && i.f & 24576) return ve(), e.v;
	_n(i);
	try {
		nt(e), n = Dn(e);
	} finally {
		_n(r);
	}
	return n;
}
function it(e) {
	var t = rt(e);
	!e.equals(t) && (e.wv = wn(), (!S?.is_fork || e.deps === null) && (S === null ? e.v = t : (S.capture(e, t, !0), ct?.capture(e, t, !0)), e.deps === null)) ? x(e, h) : hn || (C === null ? Xe(e) : (Zt() || S?.is_fork) && C.set(e, t));
}
function at(e) {
	if (e.effects !== null) for (let t of e.effects) (t.teardown || t.ac) && (t.teardown?.(), t.ac !== null && Qe(() => {
		t.ac.abort(_e), t.ac = null;
	}), t.fn !== null && (t.teardown = p), An(t, 0), sn(t));
}
function ot(e) {
	if (e.effects !== null) for (let t of e.effects) t.teardown && t.fn !== null && jn(t);
}
// node_modules/svelte/src/internal/client/reactivity/batch.js
var st = null, S = null, ct = null, C = null, lt = null, ut = !1, dt = !1, ft = null, pt = null, mt = 0, ht = 1, gt = class e {
	id = ht++;
	started = !1;
	linked = !0;
	prev = null;
	next = null;
	async_deriveds = /* @__PURE__ */ new Map();
	current = /* @__PURE__ */ new Map();
	previous = /* @__PURE__ */ new Map();
	#e = /* @__PURE__ */ new Set();
	#t = /* @__PURE__ */ new Set();
	#n = 0;
	#r = /* @__PURE__ */ new Map();
	#i = null;
	#a = [];
	#o = [];
	#s = /* @__PURE__ */ new Map();
	#c = /* @__PURE__ */ new Map();
	#l = /* @__PURE__ */ new Set();
	is_fork = !1;
	#u = !1;
	constructor() {
		st === null ? st = this : (st.next = this, this.prev = st), st = this;
	}
	#d() {
		if (this.is_fork) return !0;
		for (let e of this.#r.keys()) if (!this.#f(e)) return !0;
		return !1;
	}
	#f(e) {
		for (var t = e; t !== null; t = t.parent) if (this.#c.has(t)) return !0;
		return !1;
	}
	skip_effect(e) {
		this.#c.has(e) || this.#c.set(e, {
			d: [],
			m: []
		}), this.#l.delete(e);
	}
	unskip_effect(e, t = (e) => this.schedule(e)) {
		var n = this.#c.get(e);
		if (n) {
			this.#c.delete(e);
			for (var r of n.d) x(r, g), t(r);
			for (r of n.m) x(r, _), t(r);
		}
		this.#l.add(e);
	}
	#p() {
		var e = [];
		for (let i of this.#a) if (!(i.f & 16384 || !(i.f & 6144))) {
			for (var t = i, n = !1; t.parent !== null;) {
				t = t.parent;
				var r = t.f;
				if (r & 96) {
					if (!(r & 1024)) {
						n = !0;
						break;
					}
					t.f ^= h;
				}
			}
			n || e.push(t);
		}
		return this.#a = [], e;
	}
	#m() {
		this.started = !0;
		for (let [e, t] of this.#s) x(e, t), this.schedule(e);
		this.apply();
		for (var t = ft = [], n = [], r = pt = []; this.#a.length > 0;) {
			mt++ > 1e3 && (this.#b(), vt());
			for (let e of this.#p()) try {
				this.#h(e, t, n);
			} catch (t) {
				throw Ct(e), this.#d() || this.discard(), t;
			}
		}
		if (S = null, r.length > 0) {
			var i = e.ensure();
			for (let e of r) i.schedule(e);
		}
		if (ft = null, pt = null, this.#d()) {
			this.#y(n), this.#y(t);
			for (let [e, t] of this.#c) St(e, t);
			r.length > 0 && S.#m();
			return;
		}
		let a = this.#g();
		if (a) this.#y(n), this.#y(t), a.#v(this);
		else {
			this.#s.clear();
			for (let e of this.#e) e(this);
			this.#e.clear(), ct = this, bt(n), bt(t), ct = null, this.#i?.resolve();
			var o = S;
			this.#n === 0 && (this.#a.length === 0 || o !== null) && this.#b(), o !== null && (w.clear(), o.#m());
		}
	}
	#h(e, t, n) {
		e.f ^= h;
		for (var r = e.first; r !== null;) {
			var i = r.f, a = !!(i & 96);
			if (!(a && i & 1024 || i & 8192 || this.#c.has(r)) && r.fn !== null) {
				a ? r.f ^= h : i & 4 ? t.push(r) : Tn(r) && (i & 16 && this.add_dirty_reaction(r, _), jn(r));
				var o = r.first;
				if (o !== null) {
					r = o;
					continue;
				}
			}
			for (; r !== null;) {
				var s = r.next;
				if (s !== null) {
					r = s;
					break;
				}
				r = r.parent;
			}
		}
	}
	#g() {
		for (var e = this.prev; e !== null; e = e.prev) if (!e.is_fork && this.#_(e)) return e;
		return null;
	}
	#_(e) {
		for (let [t, [, n]] of this.current) if (!n && e.current.has(t)) return !0;
		return !1;
	}
	#v(e) {
		for (let [t, n] of e.current) !this.previous.has(t) && e.previous.has(t) && this.previous.set(t, e.previous.get(t)), this.current.set(t, n);
		for (let [t, n] of e.async_deriveds) {
			let e = this.async_deriveds.get(t);
			e && n.promise.then(e.resolve).catch(e.reject);
		}
		e.async_deriveds.clear(), this.transfer_reactions(e.#s);
		let t = (e) => {
			var n = e.reactions;
			if (n !== null && !(e.f & 2 && !(e.f & 6144))) for (let e of n) {
				var r = e.f;
				if (r & 2) t(e);
				else {
					var i = e;
					r & 4194320 && !this.async_deriveds.has(i) && (this.#s.delete(i), x(i, g), this.schedule(i));
				}
			}
		};
		for (let e of this.current.keys()) t(e);
		this.oncommit(() => e.discard()), e.#b(), S = this, this.#m();
	}
	#y(e) {
		for (var t = 0; t < e.length; t += 1) Ze(e[t], this.#s);
	}
	capture(e, n, r = !1) {
		e.v !== t && !this.previous.has(e) && this.previous.set(e, e.v), e.f & 8388608 || (this.current.set(e, [n, r]), C?.set(e, n)), this.is_fork || (e.v = n);
	}
	activate() {
		S = this;
	}
	deactivate() {
		S = null, C = null;
	}
	flush() {
		try {
			dt = !0, S = this, this.#m();
		} finally {
			mt = 0, lt = null, ft = null, pt = null, dt = !1, S = null, C = null, w.clear();
		}
	}
	discard() {
		for (let e of this.#t) e(this);
		this.#t.clear();
		for (let e of this.async_deriveds.values()) e.reject(et);
		this.#b(), this.#i?.resolve();
	}
	register_created_effect(e) {
		this.#o.push(e);
	}
	increment(e, t) {
		if (this.#n += 1, e) {
			let e = this.#r.get(t) ?? 0;
			this.#r.set(t, e + 1);
		}
	}
	decrement(e, t) {
		if (--this.#n, e) {
			let e = this.#r.get(t) ?? 0;
			e === 1 ? this.#r.delete(t) : this.#r.set(t, e - 1);
		}
		this.#u || (this.#u = !0, qe(() => {
			this.#u = !1, this.linked && this.flush();
		}));
	}
	transfer_reactions(e) {
		for (let [t, n] of e) this.add_dirty_reaction(t, n);
		e.clear();
	}
	add_dirty_reaction(e, t) {
		(t === 2048 || this.#s.get(e) !== 2048) && this.#s.set(e, t);
	}
	oncommit(e) {
		this.#e.add(e);
	}
	ondiscard(e) {
		this.#t.add(e);
	}
	settled() {
		return (this.#i ??= ee()).promise;
	}
	static ensure() {
		if (S === null) {
			let t = S = new e();
			!dt && !ut && qe(() => {
				t.started || t.flush();
			});
		}
		return S;
	}
	apply() {
		C = null;
	}
	schedule(e) {
		lt = e, e.b?.is_pending && e.f & 16777228 && !(e.f & 32768) ? e.b.defer_effect(e) : this.#a.push(e);
	}
	#b() {
		if (this.linked) {
			var e = this.prev, t = this.next;
			e === null || (e.next = t), t === null ? st = e : t.prev = e, this.linked = !1;
		}
	}
};
function _t(e) {
	var t = ut, n = ct;
	ct = null, ut = !0;
	try {
		var r;
		for (e && (_t(), r = e());;) {
			if (Je(), S === null) return r;
			S.flush();
		}
	} finally {
		ut = t, ct = n;
	}
}
function vt() {
	try {
		Ne();
	} catch (e) {
		qt(e, lt);
	}
}
var yt = null;
function bt(e) {
	var t = e.length;
	if (t !== 0) {
		for (var n = 0; n < t;) {
			var r = e[n++];
			if (!(r.f & 24576) && Tn(r) && (yt = /* @__PURE__ */ new Set(), jn(r), r.deps === null && r.first === null && r.nodes === null && r.teardown === null && r.ac === null && un(r), yt?.size > 0)) {
				w.clear();
				for (let e of yt) {
					if (e.f & 24576) continue;
					let t = [e], n = e.parent;
					for (; n !== null;) yt.has(n) && (yt.delete(n), t.push(n)), n = n.parent;
					for (let e = t.length - 1; e >= 0; e--) {
						let n = t[e];
						n.f & 24576 || jn(n);
					}
				}
				yt.clear();
			}
		}
		yt = null;
	}
}
function xt(e) {
	S.schedule(e);
}
function St(e, t) {
	if (!(e.f & 32 && e.f & 1024)) {
		e.f & 2048 ? t.d.push(e) : e.f & 4096 && t.m.push(e), x(e, h);
		for (var n = e.first; n !== null;) St(n, t), n = n.next;
	}
}
function Ct(e) {
	x(e, h);
	for (var t = e.first; t !== null;) Ct(t), t = t.next;
}
// node_modules/svelte/src/internal/client/reactivity/sources.js
var wt = /* @__PURE__ */ new Set(), w = /* @__PURE__ */ new Map(), Tt = !1;
function Et(e, t) {
	return {
		f: 0,
		v: e,
		reactions: null,
		equals: De,
		rv: 0,
		wv: 0
	};
}
/*#__NO_SIDE_EFFECTS__*/
function Dt(e, t) {
	let n = Et(e, t);
	return vn(n), n;
}
/*#__NO_SIDE_EFFECTS__*/
function Ot(e, t = !1, n = !0) {
	let r = Et(e);
	return t || (r.equals = ke), r;
}
function kt(e, t, n = !1) {
	return E !== null && (!D || E.f & 131072) && We() && E.f & 4325394 && (A === null || !A.has(e)) && Re(), Mt(e, n ? It(t) : t, pt);
}
var At = null, jt = 0;
function Mt(e, t, n = null) {
	if (!e.equals(t)) {
		hn ? w.set(e, t) : w.has(e) || w.set(e, e.v);
		var r = gt.ensure();
		if (r.capture(e, t), e.f & 2) {
			let t = e;
			e.f & 2048 && rt(t), C === null && Xe(t);
		}
		e.wv = wn(), At = null, jt = 0, Ft(e, g, n), At = null, We() && k !== null && k.f & 1024 && !(k.f & 96) && (N === null ? yn([e]) : N.push(e)), !r.is_fork && wt.size > 0 && !Tt && Nt();
	}
	return t;
}
function Nt() {
	Tt = !1;
	for (let e of wt) {
		e.f & 1024 && x(e, _);
		let t;
		try {
			t = Tn(e);
		} catch {
			t = !0;
		}
		t && jn(e);
	}
	wt.clear();
}
function Pt(e) {
	kt(e, e.v + 1);
}
function Ft(e, t, n) {
	var r = e.reactions;
	if (r !== null) {
		var i = We(), a = r.length;
		if (jt += a, jt > 1e5 && At === null && (At = /* @__PURE__ */ new Set()), At !== null) {
			if (At.has(e)) return;
			At.add(e);
		}
		for (var o = 0; o < a; o++) {
			var s = r[o], c = s.f;
			if (i || s !== k) {
				var l = (c & g) === 0;
				if (l && x(s, t), c & 131072) wt.add(s);
				else if (c & 2) {
					var u = s;
					C?.delete(u), Ft(u, _, n);
				} else if (l) {
					var d = s;
					c & 16 && yt !== null && yt.add(d), n === null ? xt(d) : n.push(d);
				}
			}
		}
	}
}
function It(e) {
	if (typeof e != "object" || !e || ue in e || de in e) return e;
	let r = d(e);
	if (r !== l && r !== u) return e;
	var i = /* @__PURE__ */ new Map(), a = n(e), o = /* @__PURE__ */ Dt(0), s = null, f = Sn, p = (e) => {
		if (Sn === f) return e();
		var t = E, n = Sn;
		O(null), Cn(f);
		var r = e();
		return O(t), Cn(n), r;
	};
	return a && i.set("length", /* @__PURE__ */ Dt(e.length, s)), new Proxy(e, {
		defineProperty(e, t, n) {
			"value" in n && n.configurable !== !1 && n.enumerable !== !1 && n.writable !== !1 || Ie();
			var r = i.get(t);
			return r === void 0 ? p(() => {
				var e = /* @__PURE__ */ Dt(n.value, s);
				return i.set(t, e), e;
			}) : kt(r, n.value, !0), !0;
		},
		deleteProperty(e, n) {
			var r = i.get(n);
			if (r === void 0) {
				if (n in e) {
					let e = p(() => /* @__PURE__ */ Dt(t, s));
					i.set(n, e), Pt(o);
				}
			} else kt(r, t), Pt(o);
			return !0;
		},
		get(n, r, a) {
			if (r === ue) return e;
			var o = i.get(r), l = r in n;
			if (o === void 0 && (!l || c(n, r)?.writable) && (o = p(() => /* @__PURE__ */ Dt(It(l ? n[r] : t), s)), i.set(r, o)), o !== void 0) {
				var u = P(o);
				return u === t ? void 0 : u;
			}
			return Reflect.get(n, r, a);
		},
		getOwnPropertyDescriptor(e, n) {
			this.has?.(e, n);
			var r = Reflect.getOwnPropertyDescriptor(e, n), a = i.get(n);
			if (a !== void 0) {
				var o = P(a);
				if (o === t) return;
				if (r && "value" in r) r.value = o;
				else return {
					enumerable: !0,
					configurable: !0,
					value: o,
					writable: !0
				};
			}
			return r;
		},
		has(e, n) {
			if (n === ue) return !0;
			var r = i.get(n), a = r !== void 0 && r.v !== t || Reflect.has(e, n);
			return (r !== void 0 || (k !== null || E !== null) && (!a || c(e, n)?.writable)) && (r === void 0 && (r = p(() => /* @__PURE__ */ Dt(a ? It(e[n]) : t, s)), i.set(n, r)), P(r) === t) ? !1 : a;
		},
		set(e, n, r, l) {
			var u = i.get(n), d = n in e;
			if (a && n === "length") for (var f = r; f < u.v; f += 1) {
				var m = i.get(f + "");
				m === void 0 ? f in e && (m = p(() => /* @__PURE__ */ Dt(t, s)), i.set(f + "", m)) : kt(m, t);
			}
			if (u === void 0) (!d || c(e, n)?.writable) && (u = p(() => /* @__PURE__ */ Dt(void 0, s)), kt(u, It(r)), i.set(n, u));
			else {
				d = u.v !== t;
				var ee = p(() => It(r));
				kt(u, ee);
			}
			var h = Reflect.getOwnPropertyDescriptor(e, n);
			if (h?.set && h.set.call(l, r), !d) {
				if (a && typeof n == "string") {
					var g = i.get("length"), _ = Number(n);
					Number.isInteger(_) && _ >= g.v && kt(g, _ + 1);
				}
				Pt(o);
			}
			return !0;
		},
		ownKeys(e) {
			P(o);
			var n = Reflect.ownKeys(e).filter((e) => {
				var n = i.get(e);
				return n === void 0 || n.v !== t;
			});
			for (var [r, a] of i) a.v !== t && !(r in e) && n.push(r);
			return n;
		},
		setPrototypeOf() {
			Le();
		}
	});
}
var Lt, Rt, zt;
function Bt() {
	if (Lt === void 0) {
		Lt = window, /Firefox/.test(navigator.userAgent);
		var e = Element.prototype, t = Node.prototype, n = Text.prototype;
		Rt = c(t, "firstChild").get, zt = c(t, "nextSibling").get, f(e) && (e[me] = void 0, e[pe] = null, e[he] = void 0, e.__e = void 0), f(n) && (n[ge] = void 0);
	}
}
function Vt(e = "") {
	return document.createTextNode(e);
}
/*@__NO_SIDE_EFFECTS__*/
function Ht(e) {
	return Rt.call(e);
}
/*@__NO_SIDE_EFFECTS__*/
function Ut(e) {
	return zt.call(e);
}
function Wt(e) {
	e.textContent = "";
}
function Gt(e, t, n) {
	return t == null || t === "http://www.w3.org/1999/xhtml" ? n ? document.createElement(e, { is: n }) : document.createElement(e) : n ? document.createElementNS(t, e, { is: n }) : document.createElementNS(t, e);
}
function Kt(e) {
	var t = k;
	if (t === null) return E.f |= le, e;
	if (!(t.f & 32768) && !(t.f & 4)) throw e;
	qt(e, t);
}
function qt(t, n) {
	if (t === e) throw t;
	if (!(n !== null && n.f & 16384)) {
		for (; n !== null;) {
			if (n.f & 128 && !(n.f & 33570816)) {
				if (!(n.f & 32768)) throw t;
				try {
					n.b.error(t);
					return;
				} catch (e) {
					t = e;
				}
			}
			n = n.parent;
		}
		throw t;
	}
}
// node_modules/svelte/src/internal/client/reactivity/effects.js
function Jt(e) {
	k === null && (E === null && Me(e), je()), hn && Ae(e);
}
function Yt(e, t) {
	var n = t.last;
	n === null ? t.last = t.first = e : (n.next = e, e.prev = n, t.last = e);
}
function Xt(e, t) {
	var n = k;
	n !== null && n.f & 8192 && (e |= te);
	var r = {
		ctx: b,
		deps: null,
		nodes: null,
		f: e | g | 512,
		first: null,
		fn: t,
		last: null,
		next: null,
		parent: n,
		b: n && n.b,
		prev: null,
		teardown: null,
		wv: 0,
		ac: null
	};
	S?.register_created_effect(r);
	var i = r;
	if (e & 4) ft === null ? gt.ensure().schedule(r) : ft.push(r);
	else if (t !== null) {
		try {
			jn(r);
		} catch (e) {
			throw T(r), e;
		}
		i.deps === null && i.teardown === null && i.nodes === null && i.first === i.last && !(i.f & 524288) && (i = i.first, e & 16 && e & 65536 && i !== null && (i.f |= ae));
	}
	if (i !== null && (i.parent = n, n !== null && Yt(i, n), E !== null && E.f & 2 && !(e & 64))) {
		var a = E;
		(a.effects ??= []).push(i);
	}
	return r;
}
function Zt() {
	return E !== null && !D;
}
function Qt(e) {
	Jt("$effect");
	var t = k.f;
	if (!E && t & 32 && b !== null && !b.i) {
		var n = b;
		(n.e ??= []).push(e);
	} else return $t(e);
}
function $t(e) {
	return Xt(4 | se, e);
}
function en(e) {
	gt.ensure();
	let t = Xt(64 | oe, e);
	return () => {
		T(t);
	};
}
function tn(e) {
	gt.ensure();
	let t = Xt(64 | oe, e);
	return (e = {}) => new Promise((n) => {
		e.outro ? dn(t, () => {
			T(t), n(void 0);
		}) : (T(t), n(void 0));
	});
}
function nn(e, t = 0) {
	return Xt(8 | t, e);
}
function rn(e, t = 0) {
	return Xt(16 | t, e);
}
function an(e) {
	return Xt(32 | oe, e);
}
function on(e) {
	var t = e.teardown;
	if (t !== null) {
		let n = hn, r = E;
		gn(!0), O(null);
		try {
			t.call(null);
		} catch (t) {
			qt(t, e.parent);
		} finally {
			gn(n), O(r);
		}
	}
}
function sn(e, t = !1) {
	var n = e.first;
	for (e.first = e.last = null; n !== null;) {
		let e = n.ac;
		e !== null && Qe(() => {
			e.abort(_e);
		});
		var r = n.next;
		n.f & 64 ? n.parent = null : T(n, t), n = r;
	}
}
function cn(e) {
	for (var t = e.first; t !== null;) {
		var n = t.next;
		t.f & 32 || T(t), t = n;
	}
}
function T(e, t = !0) {
	var n = !1;
	(t || e.f & 262144) && e.nodes !== null && e.nodes.end !== null && (ln(e.nodes.start, e.nodes.end), n = !0), e.f |= ie, sn(e, t && !n), An(e, 0);
	var r = e.nodes && e.nodes.t;
	if (r !== null) for (let e of r) e.stop();
	on(e), e.f ^= ie, e.f |= ne;
	var i = e.parent;
	i !== null && i.first !== null && un(e), e.next = e.prev = e.teardown = e.ctx = e.deps = e.fn = e.nodes = e.ac = e.b = null;
}
function ln(e, t) {
	for (; e !== null;) {
		var n = e === t ? null : /* @__PURE__ */ Ut(e);
		e.remove(), e = n;
	}
}
function un(e) {
	var t = e.parent, n = e.prev, r = e.next;
	n !== null && (n.next = r), r !== null && (r.prev = n), t !== null && (t.first === e && (t.first = r), t.last === e && (t.last = n));
}
function dn(e, t, n = !0) {
	var r = [];
	e.f |= 256, fn(e, r, !0);
	var i = () => {
		n && T(e), t && t();
	}, a = r.length;
	if (a > 0) {
		var o = () => --a || i();
		for (var s of r) s.out(o);
	} else i();
}
function fn(e, t, n) {
	if (!(e.f & 8192)) {
		e.f ^= te;
		var r = e.nodes && e.nodes.t;
		if (r !== null) for (let e of r) (e.is_global || n) && t.push(e);
		for (var i = e.first; i !== null;) {
			var a = i.next;
			if (!(i.f & 64)) {
				var o = !!(i.f & 65536) || !!(i.f & 32) && !!(e.f & 16);
				fn(i, t, o ? n : !1);
			}
			i = a;
		}
	}
}
function pn(e, t) {
	if (e.nodes) for (var n = e.nodes.start, r = e.nodes.end; n !== null;) {
		var i = n === r ? null : /* @__PURE__ */ Ut(n);
		t.append(n), n = i;
	}
}
// node_modules/svelte/src/internal/client/legacy.js
var mn = null, hn = !1;
function gn(e) {
	hn = e;
}
var E = null, D = !1;
function O(e) {
	E = e;
}
var k = null;
function _n(e) {
	k = e;
}
var A = null;
function vn(e) {
	E !== null && (E.f & 2097152 || E.f & 2) && (A ??= /* @__PURE__ */ new Set()).add(e);
}
var j = null, M = 0, N = null;
function yn(e) {
	N = e;
}
var bn = 1, xn = 0, Sn = xn;
function Cn(e) {
	Sn = e;
}
function wn() {
	return ++bn;
}
function Tn(e) {
	var t = e.f;
	if (t & 2048) return !0;
	if (t & 4096) {
		for (var n = e.deps, r = n.length, i = 0; i < r; i++) {
			var a = n[i];
			if (Tn(a) && it(a), a.wv > e.wv) return !0;
		}
		t & 512 && C === null && x(e, h);
	}
	return !1;
}
function En(e, t, n = !0) {
	var r = e.reactions;
	if (r !== null && !(A !== null && A.has(e))) for (var i = 0; i < r.length; i++) {
		var a = r[i];
		a.f & 2 ? En(a, t, !1) : t === a && (n ? x(a, g) : a.f & 1024 && x(a, _), xt(a));
	}
}
function Dn(e) {
	var t = j, n = M, r = N, i = E, a = A, o = b, s = D, c = Sn, l = e.f;
	j = null, M = 0, N = null, E = l & 96 ? null : e, A = null, Be(e.ctx), D = !1, Sn = ++xn, e.ac !== null && (Qe(() => {
		e.ac.abort(_e);
	}), e.ac = null);
	try {
		e.f |= ce;
		var u = e.fn, d = u();
		e.f |= re;
		var f = On(e);
		if (We() && N !== null && !D && f !== null && !(e.f & 6146)) for (var p = 0; p < N.length; p++) En(N[p], e);
		if (i !== null && i !== e) {
			if (xn++, i.deps !== null) for (let e = 0; e < n; e += 1) i.deps[e].rv = xn;
			if (t !== null) for (let e of t) e.rv = xn;
			N !== null && (r === null ? r = N : r.push(...N));
		}
		return e.f & 8388608 && (e.f ^= le), d;
	} catch (t) {
		return On(e), Kt(t);
	} finally {
		e.f ^= ce, j = t, M = n, N = r, E = i, A = a, Be(o), D = s, Sn = c;
	}
}
function On(e) {
	var t = e.deps, n = S?.is_fork;
	if (j !== null) {
		var r;
		if (n || An(e, M), t !== null && M > 0) for (t.length = M + j.length, r = 0; r < j.length; r++) t[M + r] = j[r];
		else e.deps = t = j;
		if (Zt() && e.f & 512) for (r = M; r < t.length; r++) (t[r].reactions ??= []).push(e);
	} else !n && t !== null && M < t.length && (An(e, M), t.length = M);
	return t;
}
function kn(e, n) {
	let a = n.reactions;
	if (a !== null) {
		var o = r.call(a, e);
		if (o !== -1) {
			var s = a.length - 1;
			s === 0 ? a = n.reactions = null : (a[o] = a[s], a.pop());
		}
	}
	if (a === null && n.f & 2 && (j === null || !i.call(j, n))) {
		var c = n;
		c.f & 512 && (c.f ^= 512), c.v !== t && Xe(c), c.ac !== null && Qe(() => {
			c.ac.abort(_e), c.ac = null, x(c, g);
		}), at(c), An(c, 0);
	}
}
function An(e, t) {
	var n = e.deps;
	if (n !== null) for (var r = t; r < n.length; r++) kn(e, n[r]);
}
function jn(e) {
	var t = e.f;
	if (!(t & 16384)) {
		x(e, h);
		var n = k;
		k = e;
		try {
			t & 16777232 ? cn(e) : sn(e), on(e);
			var r = Dn(e);
			e.teardown = typeof r == "function" ? r : null, e.wv = bn;
		} finally {
			k = n;
		}
	}
}
function P(e) {
	var t = !!(e.f & 2);
	if (mn?.add(e), E !== null && !D && !(k !== null && k.f & 16384) && (A === null || !A.has(e))) {
		var n = E.deps;
		if (E.f & 2097152) e.rv < xn && (e.rv = xn, j === null && n !== null && n[M] === e ? M++ : j === null ? j = [e] : j.push(e));
		else {
			E.deps ??= [], i.call(E.deps, e) || E.deps.push(e);
			var r = e.reactions;
			r === null ? e.reactions = [E] : i.call(r, E) || r.push(E);
		}
	}
	if (hn && w.has(e)) return w.get(e);
	if (t) {
		var a = e;
		if (hn) {
			var o = a.v;
			return (!(a.f & 1024) && a.reactions !== null || Nn(a)) && (o = rt(a)), w.set(a, o), o;
		}
		var s = !(a.f & 512) && !D && E !== null && !!(E.f & 512), c = (a.f & re) === 0;
		Tn(a) && (s && (a.f |= 512), it(a)), s && !c && (ot(a), Mn(a));
	}
	if (C?.has(e)) return C.get(e);
	if (e.f & 8388608) throw e.v;
	return e.v;
}
function Mn(e) {
	if (e.f |= 512, e.deps !== null) for (let n of e.deps) {
		var t = n.reactions;
		t === null ? n.reactions = [e] : i.call(t, e) || t.push(e), n.f & 2 && !(n.f & 512) && (ot(n), Mn(n));
	}
}
function Nn(e) {
	if (e.v === t) return !0;
	if (e.deps === null) return !1;
	for (let t of e.deps) if (w.has(t) || t.f & 2 && Nn(t)) return !0;
	return !1;
}
function Pn(e) {
	var t = D;
	try {
		return D = !0, e();
	} finally {
		D = t;
	}
}
// node_modules/svelte/src/internal/client/dom/elements/events.js
var Fn = Symbol("events"), In = /* @__PURE__ */ new Set(), Ln = /* @__PURE__ */ new Set(), Rn = null, zn = !1;
function Bn(e) {
	var t = this, n = t.ownerDocument, r = e.type, i = e.composedPath?.() || [], a = i[0] || e.target;
	Rn = e, zn || (zn = !0, setTimeout(() => {
		zn = !1, Rn = null;
	}));
	var o = 0, c = Rn === e && e[Fn];
	if (c) {
		var l = i.indexOf(c);
		if (l !== -1 && (t === document || t === window)) {
			e[Fn] = t;
			return;
		}
		var u = i.indexOf(t);
		if (u === -1) return;
		l <= u && (o = l);
	}
	if (a = i[o] || e.target, a !== t) {
		s(e, "currentTarget", {
			configurable: !0,
			get() {
				return a || n;
			}
		});
		var d = E, f = k;
		O(null), _n(null);
		try {
			for (var p, m = []; a !== null && a !== t;) {
				try {
					var ee = a[Fn]?.[r];
					ee == null || a.disabled && e.target !== a || ee.call(a, e);
				} catch (e) {
					p ? m.push(e) : p = e;
				}
				if (e.cancelBubble) break;
				o++, a = o < i.length ? i[o] : null;
			}
			if (p) {
				for (let e of m) queueMicrotask(() => {
					throw e;
				});
				throw p;
			}
		} finally {
			e[Fn] = t, delete e.currentTarget, O(d), _n(f);
		}
	}
}
globalThis?.window?.trustedTypes;
// node_modules/svelte/src/internal/client/dom/template.js
function Vn(e, t) {
	var n = k;
	n.nodes === null && (n.nodes = {
		start: e,
		end: t,
		a: null,
		t: null
	});
}
function Hn(e, t) {
	if (v) {
		var n = k;
		n.f & 32768 && n.nodes.end !== null || (n.nodes.end = y), Ce();
	} else e !== null && e.before(t);
}
[.../* @__PURE__ */ "allowfullscreen.async.autofocus.autoplay.checked.controls.default.disabled.formnovalidate.indeterminate.inert.ismap.loop.multiple.muted.nomodule.novalidate.open.playsinline.readonly.required.reversed.seamless.selected.webkitdirectory.defer.disablepictureinpicture.disableremoteplayback".split(".")];
var Un = ["touchstart", "touchmove"];
function Wn(e) {
	return Un.includes(e);
}
// node_modules/svelte/src/reactivity/create-subscriber.js
function Gn(e) {
	let t = 0, n = Et(0), r;
	return () => {
		Zt() && (P(n), nn(() => (t === 0 && (r = Pn(() => e(() => Pt(n)))), t += 1, () => {
			qe(() => {
				--t, t === 0 && (r?.(), r = void 0, Pt(n));
			});
		})));
	};
}
// node_modules/svelte/src/internal/client/dom/blocks/boundary.js
var Kn = ae | oe;
function qn(e, t, n, r) {
	new Jn(e, t, n, r);
}
var Jn = class {
	parent;
	is_pending = !1;
	transform_error;
	#e;
	#t = v ? y : null;
	#n;
	#r;
	#i;
	#a = null;
	#o = null;
	#s = null;
	#c = null;
	#l = 0;
	#u = 0;
	#d = !1;
	#f = /* @__PURE__ */ new Map();
	#p = null;
	#m = Gn(() => (this.#p = Et(this.#l), () => {
		this.#p = null;
	}));
	constructor(e, t, n, r) {
		this.#e = e, this.#n = t, this.#r = (e) => {
			var t = k;
			t.b = this, t.f |= 128, n(e);
		}, this.parent = k.b, this.transform_error = r ?? this.parent?.transform_error ?? ((e) => e), this.#i = rn(() => {
			if (v) {
				let e = Ee(this.#t);
				Ce();
				let t = e === "[!";
				if (e.startsWith("[?")) {
					let t = JSON.parse(e.slice(2));
					this.#g(t);
				} else t ? this.#y() : this.#h();
			} else this.#b();
		}, Kn), v && (this.#e = y);
	}
	#h() {
		try {
			this.#a = an(() => this.#r(this.#e));
		} catch (e) {
			this.error(e);
		}
	}
	#g(e) {
		let t = this.#n.failed, { reset: n, invoke_onerror: r } = this.#_(e);
		qe(r), t && (this.#s = an(() => {
			t(this.#e, () => e, () => n);
		}));
	}
	#_(e) {
		var t = !1, n = !1;
		let r = () => {
			this.#v() || (t ? be() : (t = !0, n && ze(), this.#s !== null && dn(this.#s, () => {
				this.#s = null;
			}), this.#S(() => {
				this.#b();
			})));
		};
		return {
			reset: r,
			invoke_onerror: () => {
				if (!this.#v()) try {
					n = !0, this.#n.onerror?.(e, r), n = !1;
				} catch (e) {
					qt(e, this.#i && this.#i.parent);
				}
			}
		};
	}
	#v() {
		return (this.#i.f & (ne | ie)) !== 0;
	}
	#y() {
		let e = this.#n.pending;
		e && (this.is_pending = !0, this.#o = an(() => e(this.#e)), qe(() => {
			if (!this.#v()) {
				var e = this.#c = document.createDocumentFragment(), t = Vt(), n = !1;
				e.append(t), this.#a = this.#S(() => {
					try {
						return an(() => this.#r(t));
					} catch (e) {
						try {
							this.error(e), n = !0;
						} catch (e) {
							qt(e, this.#i.parent);
						}
						return null;
					}
				}), this.#a === null ? (this.#c = null, n && this.#x(S)) : this.#u === 0 && (this.#e.before(e), this.#c = null, dn(this.#o, () => {
					this.#o = null;
				}), this.#x(S));
			}
		}));
	}
	#b() {
		try {
			if (this.is_pending = this.has_pending_snippet(), this.#u = 0, this.#l = 0, this.#a = an(() => {
				this.#r(this.#e);
			}), this.#u > 0) {
				var e = this.#c = document.createDocumentFragment();
				pn(this.#a, e);
				let t = this.#n.pending;
				this.#o = an(() => t(this.#e));
			} else this.#x(S);
		} catch (e) {
			this.error(e);
		}
	}
	#x(e) {
		this.is_pending = !1, e.transfer_reactions(this.#f);
	}
	defer_effect(e) {
		Ze(e, this.#f);
	}
	is_rendered() {
		return !this.is_pending && (!this.parent || this.parent.is_rendered());
	}
	has_pending_snippet() {
		return !!this.#n.pending;
	}
	#S(e) {
		var t = k, n = E, r = b;
		_n(this.#i), O(this.#i), Be(this.#i.ctx);
		try {
			return gt.ensure(), e();
		} finally {
			_n(t), O(n), Be(r);
		}
	}
	#C(e, t) {
		this.has_pending_snippet() ? (this.#u += e, this.#u === 0 && (this.#x(t), this.#o && dn(this.#o, () => {
			this.#o = null;
		}), this.#c &&= (this.#e.before(this.#c), null))) : this.parent && this.parent.#C(e, t);
	}
	update_pending_count(e, t) {
		this.#C(e, t), this.#l += e, !this.#p || this.#d || (this.#d = !0, qe(() => {
			this.#d = !1, this.#p && Mt(this.#p, this.#l);
		}));
	}
	get_effect_pending() {
		return this.#m(), P(this.#p);
	}
	error(t) {
		if (t === e || !this.#n.onerror && !this.#n.failed) throw t;
		S?.is_fork ? (this.#a && S.skip_effect(this.#a), this.#o && S.skip_effect(this.#o), this.#s && S.skip_effect(this.#s), S.oncommit(() => {
			this.#v() || this.#w(t);
		})) : this.#w(t);
	}
	#w(e) {
		this.#a &&= (T(this.#a), null), this.#o &&= (T(this.#o), null), this.#s &&= (T(this.#s), null), v && (Se(this.#t), we(), Se(Te()));
		let t = this.#n.failed, n = (e) => {
			if (this.#v()) return;
			let { reset: n, invoke_onerror: r } = this.#_(e);
			r(), t && !this.#v() && (this.#s = this.#S(() => {
				try {
					return an(() => {
						var r = k;
						r.b = this, r.f |= 128, t(this.#e, () => e, () => n);
					});
				} catch (e) {
					return qt(e, this.#i.parent), null;
				}
			}));
		};
		qe(() => {
			if (!this.#v()) {
				var t;
				try {
					t = this.transform_error(e);
				} catch (e) {
					qt(e, this.#i && this.#i.parent);
					return;
				}
				typeof t == "object" && t && typeof t.then == "function" ? t.then(n, (e) => qt(e, this.#i && this.#i.parent)) : n(t);
			}
		});
	}
};
function Yn(e, t) {
	return Qn(e, t);
}
function Xn(t, n) {
	Bt(), n.intro = n.intro ?? !1;
	let r = n.target, i = v, a = y;
	try {
		for (var o = /* @__PURE__ */ Ht(r); o && (o.nodeType !== 8 || o.data !== "[");) o = /* @__PURE__ */ Ut(o);
		if (!o) throw e;
		xe(!0), Se(o);
		let i = Qn(t, {
			...n,
			anchor: o
		});
		return xe(!1), i;
	} catch (i) {
		if (i instanceof Error && i.message.split("\n").some((e) => e.startsWith("https://svelte.dev/e/"))) throw i;
		return i !== e && console.warn("Failed to hydrate: ", i), n.recover === !1 && Pe(), Bt(), Wt(r), xe(!1), Yn(t, n);
	} finally {
		xe(i), Se(a);
	}
}
var Zn = /* @__PURE__ */ new Map();
function Qn(t, { target: n, anchor: r, props: i = {}, events: o, context: s, intro: c = !0, transformError: l }) {
	Bt();
	var u = void 0, d = tn(() => {
		var c = r ?? n.appendChild(Vt());
		qn(c, { pending: () => {} }, (n) => {
			Ve({});
			var r = b;
			if (s && (r.c = s), o && (i.$$events = o), v && Vn(n, null), u = t(n, i) || Ue(), v && (k.nodes.end = y, y === null || y.nodeType !== 8 || y.data !== "]")) throw ye(), e;
			He();
		}, l);
		var d = /* @__PURE__ */ new Set(), f = (e) => {
			for (var t = 0; t < e.length; t++) {
				var r = e[t];
				if (!d.has(r)) {
					d.add(r);
					var i = Wn(r);
					for (let e of [n, document]) {
						var a = Zn.get(e);
						a === void 0 && (a = /* @__PURE__ */ new Map(), Zn.set(e, a));
						var o = a.get(r);
						o === void 0 ? (e.addEventListener(r, Bn, { passive: i }), a.set(r, 1)) : a.set(r, o + 1);
					}
				}
			}
		};
		return f(a(In)), Ln.add(f), () => {
			for (var e of d) for (let r of [n, document]) {
				var t = Zn.get(r), i = t.get(e);
				--i == 0 ? (r.removeEventListener(e, Bn), t.delete(e), t.size === 0 && Zn.delete(r)) : t.set(e, i);
			}
			Ln.delete(f), c !== r && c.parentNode?.removeChild(c);
		};
	});
	return $n.set(u, d), u;
}
var $n = /* @__PURE__ */ new WeakMap();
function er(e, t) {
	let n = $n.get(e);
	return n ? ($n.delete(e), n(t)) : Promise.resolve();
}
// node_modules/svelte/src/internal/client/reactivity/store.js
var tr = !1;
function nr(e) {
	var t = tr;
	try {
		return tr = !1, [e(), tr];
	} finally {
		tr = t;
	}
}
// node_modules/svelte/src/internal/client/reactivity/props.js
function rr(e, t, n, r) {
	var i = !0, a = !!(n & 8), o = !!(n & 16), s = r, l = !0, u = void 0, d = () => o && i ? (u ??= /* @__PURE__ */ $e(r), P(u)) : (l && (l = !1, s = o ? Pn(r) : r), s);
	let f;
	if (a) {
		var p = ue in e || fe in e;
		f = c(e, t)?.set ?? (p && t in e ? (n) => e[t] = n : void 0);
	}
	var m, ee = !1;
	a ? [m, ee] = nr(() => e[t]) : m = e[t], m === void 0 && r !== void 0 && (m = d(), f && (i && Fe(t), f(m)));
	var h = i ? () => {
		var n = e[t];
		return n === void 0 ? d() : (l = !0, n);
	} : () => {
		var n = e[t];
		return n !== void 0 && (s = void 0), n === void 0 ? s : n;
	};
	if (i && !(n & 4)) return h;
	if (f) {
		var g = e.$$legacy;
		return (function(e, t) {
			return arguments.length > 0 ? ((!i || !t || g || ee) && f(t ? h() : e), e) : h();
		});
	}
	var _ = !1, te = (n & 1 ? $e : tt)(() => (_ = !1, h()));
	a && P(te);
	var ne = k;
	return (function(e, t) {
		if (arguments.length > 0) {
			let n = t ? P(te) : i && a ? It(e) : e;
			return kt(te, n), _ = !0, s !== void 0 && (s = n), e;
		}
		return hn && _ || ne.f & 16384 ? te.v : P(te);
	});
}
// node_modules/svelte/src/legacy/legacy-client.js
function ir(e) {
	return new ar(e);
}
var ar = class {
	#e;
	#t;
	constructor(e) {
		var t = /* @__PURE__ */ new Map(), n = (e, n) => {
			var r = /* @__PURE__ */ Ot(n, !1, !1);
			return t.set(e, r), r;
		};
		let r = new Proxy({
			...e.props || {},
			$$events: {}
		}, {
			get(e, r) {
				return P(t.get(r) ?? n(r, Reflect.get(e, r)));
			},
			has(e, r) {
				return r === fe || (P(t.get(r) ?? n(r, Reflect.get(e, r))), Reflect.has(e, r));
			},
			set(e, r, i) {
				return kt(t.get(r) ?? n(r, i), i), Reflect.set(e, r, i);
			}
		});
		this.#t = (e.hydrate ? Xn : Yn)(e.component, {
			target: e.target,
			anchor: e.anchor,
			props: r,
			context: e.context,
			intro: e.intro ?? !1,
			recover: e.recover,
			transformError: e.transformError
		}), e?.props?.$$host && e.sync !== !1 || _t(), this.#e = r.$$events;
		for (let e of Object.keys(this.#t)) e !== "$set" && e !== "$destroy" && e !== "$on" && s(this, e, {
			get() {
				return this.#t[e];
			},
			set(t) {
				this.#t[e] = t;
			},
			enumerable: !0
		});
		this.#t.$set = (e) => {
			Object.assign(r, e);
		}, this.#t.$destroy = () => {
			er(this.#t);
		};
	}
	$set(e) {
		this.#t.$set(e);
	}
	$on(e, t) {
		this.#e[e] = this.#e[e] || [];
		let n = (...e) => t.call(this, ...e);
		return this.#e[e].push(n), () => {
			this.#e[e] = this.#e[e].filter((e) => e !== n);
		};
	}
	$destroy() {
		this.#t.$destroy();
	}
}, or;
typeof HTMLElement == "function" && (or = class extends HTMLElement {
	$$ctor;
	$$s;
	$$c;
	$$cn = !1;
	$$d = {};
	$$r = !1;
	$$p_d = {};
	$$l = {};
	$$l_u = /* @__PURE__ */ new Map();
	$$me;
	$$shadowRoot = null;
	constructor(e, t, n) {
		super(), this.$$ctor = e, this.$$s = t, n && (this.$$shadowRoot = this.attachShadow(n));
	}
	addEventListener(e, t, n) {
		if (this.$$l[e] = this.$$l[e] || [], this.$$l[e].push(t), this.$$c) {
			let n = this.$$c.$on(e, t);
			this.$$l_u.set(t, n);
		}
		super.addEventListener(e, t, n);
	}
	removeEventListener(e, t, n) {
		if (super.removeEventListener(e, t, n), this.$$c) {
			let e = this.$$l_u.get(t);
			e && (e(), this.$$l_u.delete(t));
		}
	}
	async connectedCallback() {
		if (this.$$cn = !0, !this.$$c) {
			if (await Promise.resolve(), !this.$$cn || this.$$c) return;
			function e(e) {
				return (t) => {
					let n = Gt("slot");
					e !== "default" && (n.name = e), Hn(t, n);
				};
			}
			let t = {}, n = cr(this);
			for (let r of this.$$s) r in n && (r === "default" && !this.$$d.children ? (this.$$d.children = e(r), t.default = !0) : t[r] = e(r));
			for (let e of this.attributes) {
				let t = this.$$g_p(e.name);
				t in this.$$d || (this.$$d[t] = sr(t, e.value, this.$$p_d, "toProp"));
			}
			for (let e in this.$$p_d) !(e in this.$$d) && this[e] !== void 0 && (this.$$d[e] = this[e], delete this[e]);
			this.$$c = ir({
				component: this.$$ctor,
				target: this.$$shadowRoot || this,
				props: {
					...this.$$d,
					$$slots: t,
					$$host: this
				}
			}), this.$$me = en(() => {
				nn(() => {
					this.$$r = !0;
					for (let e of o(this.$$c)) {
						if (!this.$$p_d[e]?.reflect) continue;
						this.$$d[e] = this.$$c[e];
						let t = sr(e, this.$$d[e], this.$$p_d, "toAttribute");
						t == null ? this.removeAttribute(this.$$p_d[e].attribute || e) : this.setAttribute(this.$$p_d[e].attribute || e, t);
					}
					this.$$r = !1;
				});
			});
			for (let e in this.$$l) for (let t of this.$$l[e]) {
				let n = this.$$c.$on(e, t);
				this.$$l_u.set(t, n);
			}
			this.$$l = {};
		}
	}
	attributeChangedCallback(e, t, n) {
		this.$$r || (e = this.$$g_p(e), this.$$d[e] = sr(e, n, this.$$p_d, "toProp"), this.$$c?.$set({ [e]: this.$$d[e] }));
	}
	disconnectedCallback() {
		this.$$cn = !1, Promise.resolve().then(() => {
			!this.$$cn && this.$$c && (this.$$c.$destroy(), this.$$me(), this.$$c = void 0);
		});
	}
	$$g_p(e) {
		return o(this.$$p_d).find((t) => this.$$p_d[t].attribute === e || !this.$$p_d[t].attribute && t.toLowerCase() === e) || e;
	}
});
function sr(e, t, n, r) {
	let i = n[e]?.type;
	if (t = i === "Boolean" && typeof t != "boolean" ? t != null : t, !r || !n[e]) return t;
	if (r === "toAttribute") switch (i) {
		case "Object":
		case "Array": return t == null ? null : JSON.stringify(t);
		case "Boolean": return t ? "" : null;
		case "Number": return t ?? null;
		default: return t;
	}
	else switch (i) {
		case "Object":
		case "Array": return t && JSON.parse(t);
		case "Boolean": return t;
		case "Number": return t == null ? t : +t;
		default: return t;
	}
}
function cr(e) {
	let t = {};
	return e.childNodes.forEach((e) => {
		t[e.slot || "default"] = !0;
	}), t;
}
function lr(e, t, n, r, i, a) {
	let l = class extends or {
		constructor() {
			super(e, n, i), this.$$p_d = t;
		}
		static get observedAttributes() {
			return o(t).map((e) => (t[e].attribute || e).toLowerCase());
		}
	};
	return o(t).forEach((e) => {
		s(l.prototype, e, {
			get() {
				return this.$$c && e in this.$$c ? this.$$c[e] : this.$$d[e];
			},
			set(n) {
				n = sr(e, n, t), this.$$d[e] = n;
				var r = this.$$c;
				r && (c(r, e)?.get ? r[e] = n : r.$set({ [e]: n }));
			}
		});
	}), r.forEach((e) => {
		s(l.prototype, e, { get() {
			return this.$$c?.[e];
		} });
	}), a && (l = a(l)), e.element = l, l;
}
// node_modules/tweakpane/dist/tweakpane.js
function F(e) {
	return e;
}
function I(e) {
	return e == null;
}
function ur(e) {
	return typeof e == "object" && !!e;
}
function dr(e) {
	return typeof e == "object" && !!e;
}
function fr(e, t) {
	if (e.length !== t.length) return !1;
	for (let n = 0; n < e.length; n++) if (e[n] !== t[n]) return !1;
	return !0;
}
function pr(e, t) {
	return Array.from(/* @__PURE__ */ new Set([...Object.keys(e), ...Object.keys(t)])).reduce((n, r) => {
		let i = e[r], a = t[r];
		return dr(i) && dr(a) ? Object.assign(Object.assign({}, n), { [r]: pr(i, a) }) : Object.assign(Object.assign({}, n), { [r]: r in t ? a : i });
	}, {});
}
function mr(e) {
	return ur(e) ? "target" in e : !1;
}
var hr = {
	alreadydisposed: () => "View has been already disposed",
	invalidparams: (e) => `Invalid parameters for '${e.name}'`,
	nomatchingcontroller: (e) => `No matching controller for '${e.key}'`,
	nomatchingview: (e) => `No matching view for '${JSON.stringify(e.params)}'`,
	notbindable: () => "Value is not bindable",
	notcompatible: (e) => `Not compatible with  plugin '${e.id}'`,
	propertynotfound: (e) => `Property '${e.name}' not found`,
	shouldneverhappen: () => "This error should never happen"
}, L = class e {
	static alreadyDisposed() {
		return new e({ type: "alreadydisposed" });
	}
	static notBindable() {
		return new e({ type: "notbindable" });
	}
	static notCompatible(t, n) {
		return new e({
			type: "notcompatible",
			context: { id: `${t}.${n}` }
		});
	}
	static propertyNotFound(t) {
		return new e({
			type: "propertynotfound",
			context: { name: t }
		});
	}
	static shouldNeverHappen() {
		return new e({ type: "shouldneverhappen" });
	}
	constructor(e) {
		this.message = hr[e.type](F(e.context)) ?? "Unexpected error", this.name = this.constructor.name, this.stack = Error(this.message).stack, this.type = e.type;
	}
	toString() {
		return this.message;
	}
}, gr = class e {
	constructor(e, t) {
		this.obj_ = e, this.key = t;
	}
	static isBindable(e) {
		return !(e === null || typeof e != "object" && typeof e != "function");
	}
	read() {
		return this.obj_[this.key];
	}
	write(e) {
		this.obj_[this.key] = e;
	}
	writeProperty(t, n) {
		let r = this.read();
		if (!e.isBindable(r)) throw L.notBindable();
		if (!(t in r)) throw L.propertyNotFound(t);
		r[t] = n;
	}
}, R = class {
	constructor() {
		this.observers_ = {};
	}
	on(e, t, n) {
		let r = this.observers_[e];
		return r ||= this.observers_[e] = [], r.push({
			handler: t,
			key: n?.key ?? t
		}), this;
	}
	off(e, t) {
		let n = this.observers_[e];
		return n && (this.observers_[e] = n.filter((e) => e.key !== t)), this;
	}
	emit(e, t) {
		let n = this.observers_[e];
		n && n.forEach((e) => {
			e.handler(t);
		});
	}
}, _r = class {
	constructor(e, t) {
		this.constraint_ = t?.constraint, this.equals_ = t?.equals ?? ((e, t) => e === t), this.emitter = new R(), this.rawValue_ = e;
	}
	get constraint() {
		return this.constraint_;
	}
	get rawValue() {
		return this.rawValue_;
	}
	set rawValue(e) {
		this.setRawValue(e, {
			forceEmit: !1,
			last: !0
		});
	}
	setRawValue(e, t) {
		let n = t ?? {
			forceEmit: !1,
			last: !0
		}, r = this.constraint_ ? this.constraint_.constrain(e) : e, i = this.rawValue_;
		(!this.equals_(i, r) || n.forceEmit) && (this.emitter.emit("beforechange", { sender: this }), this.rawValue_ = r, this.emitter.emit("change", {
			options: n,
			previousRawValue: i,
			rawValue: r,
			sender: this
		}));
	}
}, vr = class {
	constructor(e) {
		this.emitter = new R(), this.value_ = e;
	}
	get rawValue() {
		return this.value_;
	}
	set rawValue(e) {
		this.setRawValue(e, {
			forceEmit: !1,
			last: !0
		});
	}
	setRawValue(e, t) {
		let n = t ?? {
			forceEmit: !1,
			last: !0
		}, r = this.value_;
		(r !== e || n.forceEmit) && (this.emitter.emit("beforechange", { sender: this }), this.value_ = e, this.emitter.emit("change", {
			options: n,
			previousRawValue: r,
			rawValue: this.value_,
			sender: this
		}));
	}
}, yr = class {
	constructor(e) {
		this.emitter = new R(), this.onValueBeforeChange_ = this.onValueBeforeChange_.bind(this), this.onValueChange_ = this.onValueChange_.bind(this), this.value_ = e, this.value_.emitter.on("beforechange", this.onValueBeforeChange_), this.value_.emitter.on("change", this.onValueChange_);
	}
	get rawValue() {
		return this.value_.rawValue;
	}
	onValueBeforeChange_(e) {
		this.emitter.emit("beforechange", Object.assign(Object.assign({}, e), { sender: this }));
	}
	onValueChange_(e) {
		this.emitter.emit("change", Object.assign(Object.assign({}, e), { sender: this }));
	}
};
function z(e, t) {
	let n = t?.constraint, r = t?.equals;
	return !n && !r ? new vr(e) : new _r(e, t);
}
function br(e) {
	return [new yr(e), (t, n) => {
		e.setRawValue(t, n);
	}];
}
var B = class e {
	constructor(e) {
		this.emitter = new R(), this.valMap_ = e;
		for (let e in this.valMap_) this.valMap_[e].emitter.on("change", () => {
			this.emitter.emit("change", {
				key: e,
				sender: this
			});
		});
	}
	static createCore(e) {
		return Object.keys(e).reduce((t, n) => Object.assign(t, { [n]: z(e[n]) }), {});
	}
	static fromObject(t) {
		let n = this.createCore(t);
		return new e(n);
	}
	get(e) {
		return this.valMap_[e].rawValue;
	}
	set(e, t) {
		this.valMap_[e].rawValue = t;
	}
	value(e) {
		return this.valMap_[e];
	}
}, xr = class {
	constructor(e) {
		this.values = B.fromObject({
			max: e.max,
			min: e.min
		});
	}
	constrain(e) {
		let t = this.values.get("max"), n = this.values.get("min");
		return Math.min(Math.max(e, n), t);
	}
}, Sr = class {
	constructor(e) {
		this.values = B.fromObject({
			max: e.max,
			min: e.min
		});
	}
	constrain(e) {
		let t = this.values.get("max"), n = this.values.get("min"), r = e;
		return I(n) || (r = Math.max(r, n)), I(t) || (r = Math.min(r, t)), r;
	}
}, Cr = class {
	constructor(e, t = 0) {
		this.step = e, this.origin = t;
	}
	constrain(e) {
		let t = this.origin % this.step;
		return t + Math.round((e - t) / this.step) * this.step;
	}
}, wr = class {
	constructor(e) {
		this.text = e;
	}
	evaluate() {
		return Number(this.text);
	}
	toString() {
		return this.text;
	}
}, Tr = {
	"**": (e, t) => e ** +t,
	"*": (e, t) => e * t,
	"/": (e, t) => e / t,
	"%": (e, t) => e % t,
	"+": (e, t) => e + t,
	"-": (e, t) => e - t,
	"<<": (e, t) => e << t,
	">>": (e, t) => e >> t,
	">>>": (e, t) => e >>> t,
	"&": (e, t) => e & t,
	"^": (e, t) => e ^ t,
	"|": (e, t) => e | t
}, Er = class {
	constructor(e, t, n) {
		this.left = t, this.operator = e, this.right = n;
	}
	evaluate() {
		let e = Tr[this.operator];
		if (!e) throw Error(`unexpected binary operator: '${this.operator}`);
		return e(this.left.evaluate(), this.right.evaluate());
	}
	toString() {
		return [
			"b(",
			this.left.toString(),
			this.operator,
			this.right.toString(),
			")"
		].join(" ");
	}
}, Dr = {
	"+": (e) => e,
	"-": (e) => -e,
	"~": (e) => ~e
}, Or = class {
	constructor(e, t) {
		this.operator = e, this.expression = t;
	}
	evaluate() {
		let e = Dr[this.operator];
		if (!e) throw Error(`unexpected unary operator: '${this.operator}`);
		return e(this.expression.evaluate());
	}
	toString() {
		return [
			"u(",
			this.operator,
			this.expression.toString(),
			")"
		].join(" ");
	}
};
function kr(e) {
	return (t, n) => {
		for (let r = 0; r < e.length; r++) {
			let i = e[r](t, n);
			if (i !== "") return i;
		}
		return "";
	};
}
function Ar(e, t) {
	let n = e.substr(t).match(/^\s+/);
	return (n && n[0]) ?? "";
}
function jr(e, t) {
	let n = e.substr(t, 1);
	return n.match(/^[1-9]$/) ? n : "";
}
function Mr(e, t) {
	let n = e.substr(t).match(/^[0-9]+/);
	return (n && n[0]) ?? "";
}
function Nr(e, t) {
	let n = Mr(e, t);
	if (n !== "") return n;
	let r = e.substr(t, 1);
	if (t += 1, r !== "-" && r !== "+") return "";
	let i = Mr(e, t);
	return i === "" ? "" : r + i;
}
function Pr(e, t) {
	let n = e.substr(t, 1);
	if (t += 1, n.toLowerCase() !== "e") return "";
	let r = Nr(e, t);
	return r === "" ? "" : n + r;
}
function Fr(e, t) {
	let n = e.substr(t, 1);
	if (n === "0") return n;
	let r = jr(e, t);
	return t += r.length, r === "" ? "" : r + Mr(e, t);
}
function Ir(e, t) {
	let n = Fr(e, t);
	if (t += n.length, n === "") return "";
	let r = e.substr(t, 1);
	if (t += r.length, r !== ".") return "";
	let i = Mr(e, t);
	return t += i.length, n + r + i + Pr(e, t);
}
function Lr(e, t) {
	let n = e.substr(t, 1);
	if (t += n.length, n !== ".") return "";
	let r = Mr(e, t);
	return t += r.length, r === "" ? "" : n + r + Pr(e, t);
}
function Rr(e, t) {
	let n = Fr(e, t);
	return t += n.length, n === "" ? "" : n + Pr(e, t);
}
var zr = kr([
	Ir,
	Lr,
	Rr
]);
function Br(e, t) {
	let n = e.substr(t).match(/^[01]+/);
	return (n && n[0]) ?? "";
}
function Vr(e, t) {
	let n = e.substr(t, 2);
	if (t += n.length, n.toLowerCase() !== "0b") return "";
	let r = Br(e, t);
	return r === "" ? "" : n + r;
}
function Hr(e, t) {
	let n = e.substr(t).match(/^[0-7]+/);
	return (n && n[0]) ?? "";
}
function Ur(e, t) {
	let n = e.substr(t, 2);
	if (t += n.length, n.toLowerCase() !== "0o") return "";
	let r = Hr(e, t);
	return r === "" ? "" : n + r;
}
function Wr(e, t) {
	let n = e.substr(t).match(/^[0-9a-f]+/i);
	return (n && n[0]) ?? "";
}
function Gr(e, t) {
	let n = e.substr(t, 2);
	if (t += n.length, n.toLowerCase() !== "0x") return "";
	let r = Wr(e, t);
	return r === "" ? "" : n + r;
}
var Kr = kr([kr([
	Vr,
	Ur,
	Gr
]), zr]);
function qr(e, t) {
	let n = Kr(e, t);
	return t += n.length, n === "" ? null : {
		evaluable: new wr(n),
		cursor: t
	};
}
function Jr(e, t) {
	let n = e.substr(t, 1);
	if (t += n.length, n !== "(") return null;
	let r = ei(e, t);
	if (!r) return null;
	t = r.cursor, t += Ar(e, t).length;
	let i = e.substr(t, 1);
	return t += i.length, i === ")" ? {
		evaluable: r.evaluable,
		cursor: t
	} : null;
}
function Yr(e, t) {
	return qr(e, t) ?? Jr(e, t);
}
function Xr(e, t) {
	let n = Yr(e, t);
	if (n) return n;
	let r = e.substr(t, 1);
	if (t += r.length, r !== "+" && r !== "-" && r !== "~") return null;
	let i = Xr(e, t);
	return i ? (t = i.cursor, {
		cursor: t,
		evaluable: new Or(r, i.evaluable)
	}) : null;
}
function Zr(e, t, n) {
	n += Ar(t, n).length;
	let r = e.filter((e) => t.startsWith(e, n))[0];
	return r ? (n += r.length, n += Ar(t, n).length, {
		cursor: n,
		operator: r
	}) : null;
}
function Qr(e, t) {
	return (n, r) => {
		let i = e(n, r);
		if (!i) return null;
		r = i.cursor;
		let a = i.evaluable;
		for (;;) {
			let i = Zr(t, n, r);
			if (!i) break;
			r = i.cursor;
			let o = e(n, r);
			if (!o) return null;
			r = o.cursor, a = new Er(i.operator, a, o.evaluable);
		}
		return a ? {
			cursor: r,
			evaluable: a
		} : null;
	};
}
var $r = [
	["**"],
	[
		"*",
		"/",
		"%"
	],
	["+", "-"],
	[
		"<<",
		">>>",
		">>"
	],
	["&"],
	["^"],
	["|"]
].reduce((e, t) => Qr(e, t), Xr);
function ei(e, t) {
	return t += Ar(e, t).length, $r(e, t);
}
function ti(e) {
	let t = ei(e, 0);
	return !t || t.cursor + Ar(e, t.cursor).length !== e.length ? null : t.evaluable;
}
function ni(e) {
	return ti(e)?.evaluate() ?? null;
}
function ri(e) {
	if (typeof e == "number") return e;
	if (typeof e == "string") {
		let t = ni(e);
		if (!I(t)) return t;
	}
	return 0;
}
function ii(e) {
	return String(e);
}
function V(e) {
	return (t) => t.toFixed(Math.max(Math.min(e, 20), 0));
}
function H(e, t, n, r, i) {
	return r + (e - t) / (n - t) * (i - r);
}
function ai(e) {
	return String(e.toFixed(10)).split(".")[1].replace(/0+$/, "").length;
}
function U(e, t, n) {
	return Math.min(Math.max(e, t), n);
}
function oi(e, t) {
	return (e % t + t) % t;
}
function si(e, t) {
	return I(e.step) ? Math.max(ai(t), 2) : ai(e.step);
}
function ci(e) {
	return e.step ?? 1;
}
function li(e, t) {
	let n = Math.abs(e.step ?? t);
	return n === 0 ? .1 : 10 ** (Math.floor(Math.log10(n)) - 1);
}
function ui(e, t) {
	return I(e.step) ? null : new Cr(e.step, t);
}
function di(e) {
	return !I(e.max) && !I(e.min) ? new xr({
		max: e.max,
		min: e.min
	}) : !I(e.max) || !I(e.min) ? new Sr({
		max: e.max,
		min: e.min
	}) : null;
}
function fi(e, t) {
	return {
		formatter: e.format ?? V(si(e, t)),
		keyScale: e.keyScale ?? ci(e),
		pointerScale: e.pointerScale ?? li(e, t)
	};
}
function pi(e) {
	return {
		format: e.optional.function,
		keyScale: e.optional.number,
		max: e.optional.number,
		min: e.optional.number,
		pointerScale: e.optional.number,
		step: e.optional.number
	};
}
function mi(e) {
	return {
		constraint: e.constraint,
		textProps: B.fromObject(fi(e.params, e.initialValue))
	};
}
var hi = class {
	constructor(e) {
		this.controller = e;
	}
	get element() {
		return this.controller.view.element;
	}
	get disabled() {
		return this.controller.viewProps.get("disabled");
	}
	set disabled(e) {
		this.controller.viewProps.set("disabled", e);
	}
	get hidden() {
		return this.controller.viewProps.get("hidden");
	}
	set hidden(e) {
		this.controller.viewProps.set("hidden", e);
	}
	dispose() {
		this.controller.viewProps.set("disposed", !0);
	}
	importState(e) {
		return this.controller.importState(e);
	}
	exportState() {
		return this.controller.exportState();
	}
}, gi = class {
	constructor(e) {
		this.target = e;
	}
}, _i = class extends gi {
	constructor(e, t, n) {
		super(e), this.value = t, this.last = n ?? !0;
	}
}, vi = class extends gi {
	constructor(e, t) {
		super(e), this.expanded = t;
	}
}, yi = class extends gi {
	constructor(e, t) {
		super(e), this.index = t;
	}
}, bi = class extends gi {
	constructor(e, t) {
		super(e), this.native = t;
	}
}, xi = class extends hi {
	constructor(e) {
		super(e), this.onValueChange_ = this.onValueChange_.bind(this), this.emitter_ = new R(), this.controller.value.emitter.on("change", this.onValueChange_);
	}
	get label() {
		return this.controller.labelController.props.get("label");
	}
	set label(e) {
		this.controller.labelController.props.set("label", e);
	}
	get key() {
		return this.controller.value.binding.target.key;
	}
	get tag() {
		return this.controller.tag;
	}
	set tag(e) {
		this.controller.tag = e;
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
	refresh() {
		this.controller.value.fetch();
	}
	onValueChange_(e) {
		let t = this.controller.value;
		this.emitter_.emit("change", new _i(this, F(t.binding.target.read()), e.options.last));
	}
}, Si = class {
	constructor(e, t) {
		this.onValueBeforeChange_ = this.onValueBeforeChange_.bind(this), this.onValueChange_ = this.onValueChange_.bind(this), this.binding = t, this.value_ = e, this.value_.emitter.on("beforechange", this.onValueBeforeChange_), this.value_.emitter.on("change", this.onValueChange_), this.emitter = new R();
	}
	get rawValue() {
		return this.value_.rawValue;
	}
	set rawValue(e) {
		this.value_.rawValue = e;
	}
	setRawValue(e, t) {
		this.value_.setRawValue(e, t);
	}
	fetch() {
		this.value_.rawValue = this.binding.read();
	}
	push() {
		this.binding.write(this.value_.rawValue);
	}
	onValueBeforeChange_(e) {
		this.emitter.emit("beforechange", Object.assign(Object.assign({}, e), { sender: this }));
	}
	onValueChange_(e) {
		this.push(), this.emitter.emit("change", Object.assign(Object.assign({}, e), { sender: this }));
	}
};
function Ci(e) {
	if (!("binding" in e)) return !1;
	let t = e.binding;
	return mr(t) && "read" in t && "write" in t;
}
function wi(e, t) {
	return F(Object.keys(t).reduce((n, r) => {
		if (n === void 0) return;
		let i = t[r], a = i(e[r]);
		return a.succeeded ? Object.assign(Object.assign({}, n), { [r]: a.value }) : void 0;
	}, {}));
}
function Ti(e, t) {
	return e.reduce((e, n) => {
		if (e === void 0) return;
		let r = t(n);
		if (r.succeeded && r.value !== void 0) return [...e, r.value];
	}, []);
}
function Ei(e) {
	return typeof e == "object" && !!e;
}
function Di(e) {
	return (t) => (n) => {
		if (!t && n === void 0) return {
			succeeded: !1,
			value: void 0
		};
		if (t && n === void 0) return {
			succeeded: !0,
			value: void 0
		};
		let r = e(n);
		return r === void 0 ? {
			succeeded: !1,
			value: void 0
		} : {
			succeeded: !0,
			value: r
		};
	};
}
function Oi(e) {
	return {
		custom: (t) => Di(t)(e),
		boolean: Di((e) => typeof e == "boolean" ? e : void 0)(e),
		number: Di((e) => typeof e == "number" ? e : void 0)(e),
		string: Di((e) => typeof e == "string" ? e : void 0)(e),
		function: Di((e) => typeof e == "function" ? e : void 0)(e),
		constant: (t) => Di((e) => e === t ? t : void 0)(e),
		raw: Di((e) => e)(e),
		object: (t) => Di((e) => {
			if (Ei(e)) return wi(e, t);
		})(e),
		array: (t) => Di((e) => {
			if (Array.isArray(e)) return Ti(e, t);
		})(e)
	};
}
var ki = {
	optional: Oi(!0),
	required: Oi(!1)
};
function W(e, t) {
	let n = t(ki), r = ki.required.object(n)(e);
	return r.succeeded ? r.value : void 0;
}
function G(e, t, n, r) {
	if (t && !t(e)) return !1;
	let i = W(e, n);
	return i ? r(i) : !1;
}
function K(e, t) {
	return pr(e?.() ?? {}, t);
}
function Ai(e) {
	return "value" in e;
}
function ji(e) {
	if (!ur(e) || !("binding" in e)) return !1;
	let t = e.binding;
	return mr(t);
}
var Mi = "http://www.w3.org/2000/svg";
function Ni(e) {
	e.offsetHeight;
}
function Pi(e, t) {
	let n = e.style.transition;
	e.style.transition = "none", t(), e.style.transition = n;
}
function Fi(e) {
	return e.ontouchstart !== void 0;
}
function Ii() {
	return globalThis;
}
function Li() {
	return F(Ii()).document;
}
function Ri(e) {
	let t = e.ownerDocument.defaultView;
	return t && "document" in t ? e.getContext("2d", { willReadFrequently: !0 }) : null;
}
var zi = {
	check: "<path d=\"M2 8l4 4l8 -8\"/>",
	dropdown: "<path d=\"M5 7h6l-3 3 z\"/>",
	p2dpad: "<path d=\"M8 4v8\"/><path d=\"M4 8h8\"/><circle cx=\"12\" cy=\"12\" r=\"1.2\"/>"
};
function Bi(e, t) {
	let n = e.createElementNS(Mi, "svg");
	return n.innerHTML = zi[t], n;
}
function Vi(e, t, n) {
	e.insertBefore(t, e.children[n]);
}
function Hi(e) {
	e.parentElement && e.parentElement.removeChild(e);
}
function Ui(e) {
	for (; e.children.length > 0;) e.removeChild(e.children[0]);
}
function Wi(e) {
	for (; e.childNodes.length > 0;) e.removeChild(e.childNodes[0]);
}
function Gi(e) {
	return e.relatedTarget ? F(e.relatedTarget) : "explicitOriginalTarget" in e ? e.explicitOriginalTarget : null;
}
function Ki(e, t) {
	e.emitter.on("change", (e) => {
		t(e.rawValue);
	}), t(e.rawValue);
}
function qi(e, t, n) {
	Ki(e.value(t), n);
}
var Ji = "tp";
function q(e) {
	return (t, n) => [
		Ji,
		"-",
		e,
		"v",
		t ? `_${t}` : "",
		n ? `-${n}` : ""
	].join("");
}
var Yi = q("lbl");
function Xi(e, t) {
	let n = e.createDocumentFragment();
	return t.split("\n").map((t) => e.createTextNode(t)).forEach((t, r) => {
		r > 0 && n.appendChild(e.createElement("br")), n.appendChild(t);
	}), n;
}
var Zi = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(Yi()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Yi("l")), qi(t.props, "label", (t) => {
			I(t) ? this.element.classList.add(Yi(void 0, "nol")) : (this.element.classList.remove(Yi(void 0, "nol")), Wi(n), n.appendChild(Xi(e, t)));
		}), this.element.appendChild(n), this.labelElement = n;
		let r = e.createElement("div");
		r.classList.add(Yi("v")), this.element.appendChild(r), this.valueElement = r;
	}
}, Qi = class {
	constructor(e, t) {
		this.props = t.props, this.valueController = t.valueController, this.viewProps = t.valueController.viewProps, this.view = new Zi(e, {
			props: t.props,
			viewProps: this.viewProps
		}), this.view.valueElement.appendChild(this.valueController.view.element);
	}
	importProps(e) {
		return G(e, null, (e) => ({ label: e.optional.string }), (e) => (this.props.set("label", e.label), !0));
	}
	exportProps() {
		return K(null, { label: this.props.get("label") });
	}
};
function $i() {
	return [
		"veryfirst",
		"first",
		"last",
		"verylast"
	];
}
var ea = q(""), ta = {
	veryfirst: "vfst",
	first: "fst",
	last: "lst",
	verylast: "vlst"
}, na = class {
	constructor(e) {
		this.parent_ = null, this.blade = e.blade, this.view = e.view, this.viewProps = e.viewProps;
		let t = this.view.element;
		this.blade.value("positions").emitter.on("change", () => {
			$i().forEach((e) => {
				t.classList.remove(ea(void 0, ta[e]));
			}), this.blade.get("positions").forEach((e) => {
				t.classList.add(ea(void 0, ta[e]));
			});
		}), this.viewProps.handleDispose(() => {
			Hi(t);
		});
	}
	get parent() {
		return this.parent_;
	}
	set parent(e) {
		this.parent_ = e, this.viewProps.set("parent", this.parent_ ? this.parent_.viewProps : null);
	}
	importState(e) {
		return G(e, null, (e) => ({
			disabled: e.required.boolean,
			hidden: e.required.boolean
		}), (e) => (this.viewProps.importState(e), !0));
	}
	exportState() {
		return K(null, Object.assign({}, this.viewProps.exportState()));
	}
}, ra = class extends na {
	constructor(e, t) {
		if (t.value !== t.valueController.value) throw L.shouldNeverHappen();
		let n = t.valueController.viewProps, r = new Qi(e, {
			blade: t.blade,
			props: t.props,
			valueController: t.valueController
		});
		super(Object.assign(Object.assign({}, t), {
			view: new Zi(e, {
				props: t.props,
				viewProps: n
			}),
			viewProps: n
		})), this.labelController = r, this.value = t.value, this.valueController = t.valueController, this.view.valueElement.appendChild(this.valueController.view.element);
	}
	importState(e) {
		return G(e, (t) => {
			var n;
			return super.importState(t) && this.labelController.importProps(t) && ((n = this.valueController).importProps?.call(n, e) ?? !0);
		}, (e) => ({ value: e.optional.raw }), (e) => (e.value && (this.value.rawValue = e.value), !0));
	}
	exportState() {
		var e;
		return K(() => super.exportState(), Object.assign(Object.assign({ value: this.value.rawValue }, this.labelController.exportProps()), (e = this.valueController).exportProps?.call(e) ?? {}));
	}
};
function ia(e) {
	let t = Object.assign({}, e);
	return delete t.value, t;
}
var aa = class extends ra {
	constructor(e, t) {
		super(e, t), this.tag = t.tag;
	}
	importState(e) {
		return G(e, (t) => super.importState(ia(e)), (e) => ({ tag: e.optional.string }), (e) => (this.tag = e.tag, !0));
	}
	exportState() {
		return K(() => ia(super.exportState()), {
			binding: {
				key: this.value.binding.target.key,
				value: this.value.binding.target.read()
			},
			tag: this.tag
		});
	}
};
function oa(e) {
	return Ai(e) && ji(e.value);
}
var sa = class extends aa {
	importState(e) {
		return G(e, (e) => super.importState(e), (e) => ({ binding: e.required.object({ value: e.required.raw }) }), (e) => (this.value.binding.inject(e.binding.value), this.value.fetch(), !0));
	}
};
function ca(e) {
	return Ai(e) && Ci(e.value);
}
function la(e, t) {
	for (; e.length < t;) e.push(void 0);
}
function ua(e) {
	let t = [];
	return la(t, e), t;
}
function da(e) {
	let t = e.indexOf(void 0);
	return F(t < 0 ? e : e.slice(0, t));
}
function fa(e, t) {
	let n = [...da(e), t];
	return n.length > e.length ? n.splice(0, n.length - e.length) : la(n, e.length), n;
}
var pa = class {
	constructor(e) {
		this.emitter = new R(), this.onTick_ = this.onTick_.bind(this), this.onValueBeforeChange_ = this.onValueBeforeChange_.bind(this), this.onValueChange_ = this.onValueChange_.bind(this), this.binding = e.binding, this.value_ = z(ua(e.bufferSize)), this.value_.emitter.on("beforechange", this.onValueBeforeChange_), this.value_.emitter.on("change", this.onValueChange_), this.ticker = e.ticker, this.ticker.emitter.on("tick", this.onTick_), this.fetch();
	}
	get rawValue() {
		return this.value_.rawValue;
	}
	set rawValue(e) {
		this.value_.rawValue = e;
	}
	setRawValue(e, t) {
		this.value_.setRawValue(e, t);
	}
	fetch() {
		this.value_.rawValue = fa(this.value_.rawValue, this.binding.read());
	}
	onTick_() {
		this.fetch();
	}
	onValueBeforeChange_(e) {
		this.emitter.emit("beforechange", Object.assign(Object.assign({}, e), { sender: this }));
	}
	onValueChange_(e) {
		this.emitter.emit("change", Object.assign(Object.assign({}, e), { sender: this }));
	}
};
function ma(e) {
	if (!("binding" in e)) return !1;
	let t = e.binding;
	return mr(t) && "read" in t && !("write" in t);
}
var ha = class extends aa {
	exportState() {
		return K(() => super.exportState(), { binding: { readonly: !0 } });
	}
};
function ga(e) {
	return Ai(e) && ma(e.value);
}
var _a = class extends hi {
	get label() {
		return this.controller.labelController.props.get("label");
	}
	set label(e) {
		this.controller.labelController.props.set("label", e);
	}
	get title() {
		return this.controller.buttonController.props.get("title") ?? "";
	}
	set title(e) {
		this.controller.buttonController.props.set("title", e);
	}
	on(e, t) {
		let n = t.bind(this);
		return this.controller.buttonController.emitter.on(e, (e) => {
			n(new bi(this, e.nativeEvent));
		}), this;
	}
	off(e, t) {
		return this.controller.buttonController.emitter.off(e, t), this;
	}
};
function va(e, t, n) {
	n ? e.classList.add(t) : e.classList.remove(t);
}
function ya(e, t) {
	return (n) => {
		va(e, t, n);
	};
}
function ba(e, t) {
	Ki(e, (e) => {
		t.textContent = e ?? "";
	});
}
var xa = q("btn"), Sa = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(xa()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("button");
		n.classList.add(xa("b")), t.viewProps.bindDisabled(n), this.element.appendChild(n), this.buttonElement = n;
		let r = e.createElement("div");
		r.classList.add(xa("t")), ba(t.props.value("title"), r), this.buttonElement.appendChild(r);
	}
}, Ca = class {
	constructor(e, t) {
		this.emitter = new R(), this.onClick_ = this.onClick_.bind(this), this.props = t.props, this.viewProps = t.viewProps, this.view = new Sa(e, {
			props: this.props,
			viewProps: this.viewProps
		}), this.view.buttonElement.addEventListener("click", this.onClick_);
	}
	importProps(e) {
		return G(e, null, (e) => ({ title: e.optional.string }), (e) => (this.props.set("title", e.title), !0));
	}
	exportProps() {
		return K(null, { title: this.props.get("title") });
	}
	onClick_(e) {
		this.emitter.emit("click", {
			nativeEvent: e,
			sender: this
		});
	}
}, wa = class extends na {
	constructor(e, t) {
		let n = new Ca(e, {
			props: t.buttonProps,
			viewProps: t.viewProps
		}), r = new Qi(e, {
			blade: t.blade,
			props: t.labelProps,
			valueController: n
		});
		super({
			blade: t.blade,
			view: r.view,
			viewProps: t.viewProps
		}), this.buttonController = n, this.labelController = r;
	}
	importState(e) {
		return G(e, (e) => super.importState(e) && this.buttonController.importProps(e) && this.labelController.importProps(e), () => ({}), () => !0);
	}
	exportState() {
		return K(() => super.exportState(), Object.assign(Object.assign({}, this.buttonController.exportProps()), this.labelController.exportProps()));
	}
}, Ta = class {
	constructor(e) {
		let [t, n] = e.split("-"), r = t.split(".");
		this.major = parseInt(r[0], 10), this.minor = parseInt(r[1], 10), this.patch = parseInt(r[2], 10), this.prerelease = n ?? null;
	}
	toString() {
		let e = [
			this.major,
			this.minor,
			this.patch
		].join(".");
		return this.prerelease === null ? e : [e, this.prerelease].join("-");
	}
}, Ea = new Ta("2.0.5");
function J(e) {
	return Object.assign({ core: Ea }, e);
}
var Da = J({
	id: "button",
	type: "blade",
	accept(e) {
		let t = W(e, (e) => ({
			title: e.required.string,
			view: e.required.constant("button"),
			label: e.optional.string
		}));
		return t ? { params: t } : null;
	},
	controller(e) {
		return new wa(e.document, {
			blade: e.blade,
			buttonProps: B.fromObject({ title: e.params.title }),
			labelProps: B.fromObject({ label: e.params.label }),
			viewProps: e.viewProps
		});
	},
	api(e) {
		return e.controller instanceof wa ? new _a(e.controller) : null;
	}
});
function Oa(e, t) {
	return e.addBlade(Object.assign(Object.assign({}, t), { view: "button" }));
}
function ka(e, t) {
	return e.addBlade(Object.assign(Object.assign({}, t), { view: "folder" }));
}
function Aa(e, t) {
	return e.addBlade(Object.assign(Object.assign({}, t), { view: "tab" }));
}
function ja(e) {
	return ur(e) ? "refresh" in e && typeof e.refresh == "function" : !1;
}
function Ma(e, t) {
	if (!gr.isBindable(e)) throw L.notBindable();
	return new gr(e, t);
}
var Na = class {
	constructor(e, t) {
		this.onRackValueChange_ = this.onRackValueChange_.bind(this), this.controller_ = e, this.emitter_ = new R(), this.pool_ = t, this.controller_.rack.emitter.on("valuechange", this.onRackValueChange_);
	}
	get children() {
		return this.controller_.rack.children.map((e) => this.pool_.createApi(e));
	}
	addBinding(e, t, n) {
		let r = n ?? {}, i = this.controller_.element.ownerDocument, a = this.pool_.createBinding(i, Ma(e, t), r), o = this.pool_.createBindingApi(a);
		return this.add(o, r.index);
	}
	addFolder(e) {
		return ka(this, e);
	}
	addButton(e) {
		return Oa(this, e);
	}
	addTab(e) {
		return Aa(this, e);
	}
	add(e, t) {
		let n = e.controller;
		return this.controller_.rack.add(n, t), e;
	}
	remove(e) {
		this.controller_.rack.remove(e.controller);
	}
	addBlade(e) {
		let t = this.controller_.element.ownerDocument, n = this.pool_.createBlade(t, e), r = this.pool_.createApi(n);
		return this.add(r, e.index);
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
	refresh() {
		this.children.forEach((e) => {
			ja(e) && e.refresh();
		});
	}
	onRackValueChange_(e) {
		let t = e.bladeController, n = this.pool_.createApi(t), r = ji(t.value) ? t.value.binding : null;
		this.emitter_.emit("change", new _i(n, r ? r.target.read() : t.value.rawValue, e.options.last));
	}
}, Pa = class extends hi {
	constructor(e, t) {
		super(e), this.rackApi_ = new Na(e.rackController, t);
	}
	refresh() {
		this.rackApi_.refresh();
	}
}, Fa = class extends na {
	constructor(e) {
		super({
			blade: e.blade,
			view: e.view,
			viewProps: e.rackController.viewProps
		}), this.rackController = e.rackController;
	}
	importState(e) {
		return G(e, (e) => super.importState(e), (e) => ({ children: e.required.array(e.required.raw) }), (e) => this.rackController.rack.children.every((t, n) => t.importState(e.children[n])));
	}
	exportState() {
		return K(() => super.exportState(), { children: this.rackController.rack.children.map((e) => e.exportState()) });
	}
};
function Ia(e) {
	return "rackController" in e;
}
var La = class {
	constructor(e) {
		this.emitter = new R(), this.items_ = [], this.cache_ = /* @__PURE__ */ new Set(), this.onSubListAdd_ = this.onSubListAdd_.bind(this), this.onSubListRemove_ = this.onSubListRemove_.bind(this), this.extract_ = e;
	}
	get items() {
		return this.items_;
	}
	allItems() {
		return Array.from(this.cache_);
	}
	find(e) {
		for (let t of this.allItems()) if (e(t)) return t;
		return null;
	}
	includes(e) {
		return this.cache_.has(e);
	}
	add(e, t) {
		if (this.includes(e)) throw L.shouldNeverHappen();
		let n = t === void 0 ? this.items_.length : t;
		this.items_.splice(n, 0, e), this.cache_.add(e);
		let r = this.extract_(e);
		r && (r.emitter.on("add", this.onSubListAdd_), r.emitter.on("remove", this.onSubListRemove_), r.allItems().forEach((e) => {
			this.cache_.add(e);
		})), this.emitter.emit("add", {
			index: n,
			item: e,
			root: this,
			target: this
		});
	}
	remove(e) {
		let t = this.items_.indexOf(e);
		if (t < 0) return;
		this.items_.splice(t, 1), this.cache_.delete(e);
		let n = this.extract_(e);
		n && (n.allItems().forEach((e) => {
			this.cache_.delete(e);
		}), n.emitter.off("add", this.onSubListAdd_), n.emitter.off("remove", this.onSubListRemove_)), this.emitter.emit("remove", {
			index: t,
			item: e,
			root: this,
			target: this
		});
	}
	onSubListAdd_(e) {
		this.cache_.add(e.item), this.emitter.emit("add", {
			index: e.index,
			item: e.item,
			root: this,
			target: e.target
		});
	}
	onSubListRemove_(e) {
		this.cache_.delete(e.item), this.emitter.emit("remove", {
			index: e.index,
			item: e.item,
			root: this,
			target: e.target
		});
	}
};
function Ra(e, t) {
	for (let n = 0; n < e.length; n++) {
		let r = e[n];
		if (Ai(r) && r.value === t) return r;
	}
	return null;
}
function za(e) {
	return Ia(e) ? e.rackController.rack.bcSet_ : null;
}
var Ba = class {
	constructor(e) {
		var t;
		this.emitter = new R(), this.onBladePositionsChange_ = this.onBladePositionsChange_.bind(this), this.onSetAdd_ = this.onSetAdd_.bind(this), this.onSetRemove_ = this.onSetRemove_.bind(this), this.onChildDispose_ = this.onChildDispose_.bind(this), this.onChildPositionsChange_ = this.onChildPositionsChange_.bind(this), this.onChildValueChange_ = this.onChildValueChange_.bind(this), this.onChildViewPropsChange_ = this.onChildViewPropsChange_.bind(this), this.onRackLayout_ = this.onRackLayout_.bind(this), this.onRackValueChange_ = this.onRackValueChange_.bind(this), this.blade_ = e.blade ?? null, (t = this.blade_) == null || t.value("positions").emitter.on("change", this.onBladePositionsChange_), this.viewProps = e.viewProps, this.bcSet_ = new La(za), this.bcSet_.emitter.on("add", this.onSetAdd_), this.bcSet_.emitter.on("remove", this.onSetRemove_);
	}
	get children() {
		return this.bcSet_.items;
	}
	add(e, t) {
		var n;
		(n = e.parent) == null || n.remove(e), e.parent = this, this.bcSet_.add(e, t);
	}
	remove(e) {
		e.parent = null, this.bcSet_.remove(e);
	}
	find(e) {
		return this.bcSet_.allItems().filter(e);
	}
	onSetAdd_(e) {
		this.updatePositions_();
		let t = e.target === e.root;
		if (this.emitter.emit("add", {
			bladeController: e.item,
			index: e.index,
			root: t,
			sender: this
		}), !t) return;
		let n = e.item;
		if (n.viewProps.emitter.on("change", this.onChildViewPropsChange_), n.blade.value("positions").emitter.on("change", this.onChildPositionsChange_), n.viewProps.handleDispose(this.onChildDispose_), Ai(n)) n.value.emitter.on("change", this.onChildValueChange_);
		else if (Ia(n)) {
			let e = n.rackController.rack;
			if (e) {
				let t = e.emitter;
				t.on("layout", this.onRackLayout_), t.on("valuechange", this.onRackValueChange_);
			}
		}
	}
	onSetRemove_(e) {
		this.updatePositions_();
		let t = e.target === e.root;
		if (this.emitter.emit("remove", {
			bladeController: e.item,
			root: t,
			sender: this
		}), !t) return;
		let n = e.item;
		if (Ai(n)) n.value.emitter.off("change", this.onChildValueChange_);
		else if (Ia(n)) {
			let e = n.rackController.rack;
			if (e) {
				let t = e.emitter;
				t.off("layout", this.onRackLayout_), t.off("valuechange", this.onRackValueChange_);
			}
		}
	}
	updatePositions_() {
		let e = this.bcSet_.items.filter((e) => !e.viewProps.get("hidden")), t = e[0], n = e[e.length - 1];
		this.bcSet_.items.forEach((e) => {
			let r = [];
			e === t && (r.push("first"), (!this.blade_ || this.blade_.get("positions").includes("veryfirst")) && r.push("veryfirst")), e === n && (r.push("last"), (!this.blade_ || this.blade_.get("positions").includes("verylast")) && r.push("verylast")), e.blade.set("positions", r);
		});
	}
	onChildPositionsChange_() {
		this.updatePositions_(), this.emitter.emit("layout", { sender: this });
	}
	onChildViewPropsChange_(e) {
		this.updatePositions_(), this.emitter.emit("layout", { sender: this });
	}
	onChildDispose_() {
		this.bcSet_.items.filter((e) => e.viewProps.get("disposed")).forEach((e) => {
			this.bcSet_.remove(e);
		});
	}
	onChildValueChange_(e) {
		let t = Ra(this.find(Ai), e.sender);
		if (!t) throw L.alreadyDisposed();
		this.emitter.emit("valuechange", {
			bladeController: t,
			options: e.options,
			sender: this
		});
	}
	onRackLayout_(e) {
		this.updatePositions_(), this.emitter.emit("layout", { sender: this });
	}
	onRackValueChange_(e) {
		this.emitter.emit("valuechange", {
			bladeController: e.bladeController,
			options: e.options,
			sender: this
		});
	}
	onBladePositionsChange_() {
		this.updatePositions_();
	}
}, Va = class {
	constructor(e) {
		this.onRackAdd_ = this.onRackAdd_.bind(this), this.onRackRemove_ = this.onRackRemove_.bind(this), this.element = e.element, this.viewProps = e.viewProps;
		let t = new Ba({
			blade: e.root ? void 0 : e.blade,
			viewProps: e.viewProps
		});
		t.emitter.on("add", this.onRackAdd_), t.emitter.on("remove", this.onRackRemove_), this.rack = t, this.viewProps.handleDispose(() => {
			for (let e = this.rack.children.length - 1; e >= 0; e--) this.rack.children[e].viewProps.set("disposed", !0);
		});
	}
	onRackAdd_(e) {
		e.root && Vi(this.element, e.bladeController.view.element, e.index);
	}
	onRackRemove_(e) {
		e.root && Hi(e.bladeController.view.element);
	}
};
function Ha() {
	return new B({ positions: z([], { equals: fr }) });
}
var Ua = class e extends B {
	constructor(e) {
		super(e);
	}
	static create(t) {
		let n = {
			completed: !0,
			expanded: t,
			expandedHeight: null,
			shouldFixHeight: !1,
			temporaryExpanded: null
		}, r = B.createCore(n);
		return new e(r);
	}
	get styleExpanded() {
		return this.get("temporaryExpanded") ?? this.get("expanded");
	}
	get styleHeight() {
		if (!this.styleExpanded) return "0";
		let e = this.get("expandedHeight");
		return this.get("shouldFixHeight") && !I(e) ? `${e}px` : "auto";
	}
	bindExpandedClass(e, t) {
		let n = () => {
			this.styleExpanded ? e.classList.add(t) : e.classList.remove(t);
		};
		qi(this, "expanded", n), qi(this, "temporaryExpanded", n);
	}
	cleanUpTransition() {
		this.set("shouldFixHeight", !1), this.set("expandedHeight", null), this.set("completed", !0);
	}
};
function Wa(e, t) {
	let n = 0;
	return Pi(t, () => {
		e.set("expandedHeight", null), e.set("temporaryExpanded", !0), Ni(t), n = t.clientHeight, e.set("temporaryExpanded", null), Ni(t);
	}), n;
}
function Ga(e, t) {
	t.style.height = e.styleHeight;
}
function Ka(e, t) {
	e.value("expanded").emitter.on("beforechange", () => {
		if (e.set("completed", !1), I(e.get("expandedHeight"))) {
			let n = Wa(e, t);
			n > 0 && e.set("expandedHeight", n);
		}
		e.set("shouldFixHeight", !0), Ni(t);
	}), e.emitter.on("change", () => {
		Ga(e, t);
	}), Ga(e, t), t.addEventListener("transitionend", (t) => {
		t.propertyName === "height" && e.cleanUpTransition();
	});
}
var qa = class extends Pa {
	constructor(e, t) {
		super(e, t), this.emitter_ = new R(), this.controller.foldable.value("expanded").emitter.on("change", (e) => {
			this.emitter_.emit("fold", new vi(this, e.sender.rawValue));
		}), this.rackApi_.on("change", (e) => {
			this.emitter_.emit("change", e);
		});
	}
	get expanded() {
		return this.controller.foldable.get("expanded");
	}
	set expanded(e) {
		this.controller.foldable.set("expanded", e);
	}
	get title() {
		return this.controller.props.get("title");
	}
	set title(e) {
		this.controller.props.set("title", e);
	}
	get children() {
		return this.rackApi_.children;
	}
	addBinding(e, t, n) {
		return this.rackApi_.addBinding(e, t, n);
	}
	addFolder(e) {
		return this.rackApi_.addFolder(e);
	}
	addButton(e) {
		return this.rackApi_.addButton(e);
	}
	addTab(e) {
		return this.rackApi_.addTab(e);
	}
	add(e, t) {
		return this.rackApi_.add(e, t);
	}
	remove(e) {
		this.rackApi_.remove(e);
	}
	addBlade(e) {
		return this.rackApi_.addBlade(e);
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
}, Ja = q("cnt"), Ya = class {
	constructor(e, t) {
		this.className_ = q(t.viewName ?? "fld"), this.element = e.createElement("div"), this.element.classList.add(this.className_(), Ja()), t.viewProps.bindClassModifiers(this.element), this.foldable_ = t.foldable, this.foldable_.bindExpandedClass(this.element, this.className_(void 0, "expanded")), qi(this.foldable_, "completed", ya(this.element, this.className_(void 0, "cpl")));
		let n = e.createElement("button");
		n.classList.add(this.className_("b")), qi(t.props, "title", (e) => {
			I(e) ? this.element.classList.add(this.className_(void 0, "not")) : this.element.classList.remove(this.className_(void 0, "not"));
		}), t.viewProps.bindDisabled(n), this.element.appendChild(n), this.buttonElement = n;
		let r = e.createElement("div");
		r.classList.add(this.className_("i")), this.element.appendChild(r);
		let i = e.createElement("div");
		i.classList.add(this.className_("t")), ba(t.props.value("title"), i), this.buttonElement.appendChild(i), this.titleElement = i;
		let a = e.createElement("div");
		a.classList.add(this.className_("m")), this.buttonElement.appendChild(a);
		let o = e.createElement("div");
		o.classList.add(this.className_("c")), this.element.appendChild(o), this.containerElement = o;
	}
}, Xa = class extends Fa {
	constructor(e, t) {
		let n = Ua.create(t.expanded ?? !0), r = new Ya(e, {
			foldable: n,
			props: t.props,
			viewName: t.root ? "rot" : void 0,
			viewProps: t.viewProps
		});
		super(Object.assign(Object.assign({}, t), {
			rackController: new Va({
				blade: t.blade,
				element: r.containerElement,
				root: t.root,
				viewProps: t.viewProps
			}),
			view: r
		})), this.onTitleClick_ = this.onTitleClick_.bind(this), this.props = t.props, this.foldable = n, Ka(this.foldable, this.view.containerElement), this.rackController.rack.emitter.on("add", () => {
			this.foldable.cleanUpTransition();
		}), this.rackController.rack.emitter.on("remove", () => {
			this.foldable.cleanUpTransition();
		}), this.view.buttonElement.addEventListener("click", this.onTitleClick_);
	}
	get document() {
		return this.view.element.ownerDocument;
	}
	importState(e) {
		return G(e, (e) => super.importState(e), (e) => ({
			expanded: e.required.boolean,
			title: e.optional.string
		}), (e) => (this.foldable.set("expanded", e.expanded), this.props.set("title", e.title), !0));
	}
	exportState() {
		return K(() => super.exportState(), {
			expanded: this.foldable.get("expanded"),
			title: this.props.get("title")
		});
	}
	onTitleClick_() {
		this.foldable.set("expanded", !this.foldable.get("expanded"));
	}
}, Za = J({
	id: "folder",
	type: "blade",
	accept(e) {
		let t = W(e, (e) => ({
			title: e.required.string,
			view: e.required.constant("folder"),
			expanded: e.optional.boolean
		}));
		return t ? { params: t } : null;
	},
	controller(e) {
		return new Xa(e.document, {
			blade: e.blade,
			expanded: e.params.expanded,
			props: B.fromObject({ title: e.params.title }),
			viewProps: e.viewProps
		});
	},
	api(e) {
		return e.controller instanceof Xa ? new qa(e.controller, e.pool) : null;
	}
}), Qa = q("");
function $a(e, t) {
	return ya(e, Qa(void 0, t));
}
var eo = class e extends B {
	constructor(e) {
		var t;
		super(e), this.onDisabledChange_ = this.onDisabledChange_.bind(this), this.onParentChange_ = this.onParentChange_.bind(this), this.onParentGlobalDisabledChange_ = this.onParentGlobalDisabledChange_.bind(this), [this.globalDisabled_, this.setGlobalDisabled_] = br(z(this.getGlobalDisabled_())), this.value("disabled").emitter.on("change", this.onDisabledChange_), this.value("parent").emitter.on("change", this.onParentChange_), (t = this.get("parent")) == null || t.globalDisabled.emitter.on("change", this.onParentGlobalDisabledChange_);
	}
	static create(t) {
		let n = t ?? {};
		return new e(B.createCore({
			disabled: n.disabled ?? !1,
			disposed: !1,
			hidden: n.hidden ?? !1,
			parent: n.parent ?? null
		}));
	}
	get globalDisabled() {
		return this.globalDisabled_;
	}
	bindClassModifiers(e) {
		Ki(this.globalDisabled_, $a(e, "disabled")), qi(this, "hidden", $a(e, "hidden"));
	}
	bindDisabled(e) {
		Ki(this.globalDisabled_, (t) => {
			e.disabled = t;
		});
	}
	bindTabIndex(e) {
		Ki(this.globalDisabled_, (t) => {
			e.tabIndex = t ? -1 : 0;
		});
	}
	handleDispose(e) {
		this.value("disposed").emitter.on("change", (t) => {
			t && e();
		});
	}
	importState(e) {
		this.set("disabled", e.disabled), this.set("hidden", e.hidden);
	}
	exportState() {
		return {
			disabled: this.get("disabled"),
			hidden: this.get("hidden")
		};
	}
	getGlobalDisabled_() {
		let e = this.get("parent");
		return (e ? e.globalDisabled.rawValue : !1) || this.get("disabled");
	}
	updateGlobalDisabled_() {
		this.setGlobalDisabled_(this.getGlobalDisabled_());
	}
	onDisabledChange_() {
		this.updateGlobalDisabled_();
	}
	onParentGlobalDisabledChange_() {
		this.updateGlobalDisabled_();
	}
	onParentChange_(e) {
		var t;
		e.previousRawValue?.globalDisabled.emitter.off("change", this.onParentGlobalDisabledChange_), (t = this.get("parent")) == null || t.globalDisabled.emitter.on("change", this.onParentGlobalDisabledChange_), this.updateGlobalDisabled_();
	}
}, to = q("tbp"), no = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(to()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(to("c")), this.element.appendChild(n), this.containerElement = n;
	}
}, ro = q("tbi"), io = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(ro()), t.viewProps.bindClassModifiers(this.element), qi(t.props, "selected", (e) => {
			e ? this.element.classList.add(ro(void 0, "sel")) : this.element.classList.remove(ro(void 0, "sel"));
		});
		let n = e.createElement("button");
		n.classList.add(ro("b")), t.viewProps.bindDisabled(n), this.element.appendChild(n), this.buttonElement = n;
		let r = e.createElement("div");
		r.classList.add(ro("t")), ba(t.props.value("title"), r), this.buttonElement.appendChild(r), this.titleElement = r;
	}
}, ao = class {
	constructor(e, t) {
		this.emitter = new R(), this.onClick_ = this.onClick_.bind(this), this.props = t.props, this.viewProps = t.viewProps, this.view = new io(e, {
			props: t.props,
			viewProps: t.viewProps
		}), this.view.buttonElement.addEventListener("click", this.onClick_);
	}
	onClick_() {
		this.emitter.emit("click", { sender: this });
	}
}, oo = class extends Fa {
	constructor(e, t) {
		let n = new no(e, { viewProps: t.viewProps });
		super(Object.assign(Object.assign({}, t), {
			rackController: new Va({
				blade: t.blade,
				element: n.containerElement,
				viewProps: t.viewProps
			}),
			view: n
		})), this.onItemClick_ = this.onItemClick_.bind(this), this.ic_ = new ao(e, {
			props: t.itemProps,
			viewProps: eo.create()
		}), this.ic_.emitter.on("click", this.onItemClick_), this.props = t.props, qi(this.props, "selected", (e) => {
			this.itemController.props.set("selected", e), this.viewProps.set("hidden", !e);
		});
	}
	get itemController() {
		return this.ic_;
	}
	importState(e) {
		return G(e, (e) => super.importState(e), (e) => ({
			selected: e.required.boolean,
			title: e.required.string
		}), (e) => (this.ic_.props.set("selected", e.selected), this.ic_.props.set("title", e.title), !0));
	}
	exportState() {
		return K(() => super.exportState(), {
			selected: this.ic_.props.get("selected"),
			title: this.ic_.props.get("title")
		});
	}
	onItemClick_() {
		this.props.set("selected", !0);
	}
}, so = class extends Pa {
	constructor(e, t) {
		super(e, t), this.emitter_ = new R(), this.onSelect_ = this.onSelect_.bind(this), this.pool_ = t, this.rackApi_.on("change", (e) => {
			this.emitter_.emit("change", e);
		}), this.controller.tab.selectedIndex.emitter.on("change", this.onSelect_);
	}
	get pages() {
		return this.rackApi_.children;
	}
	addPage(e) {
		let t = this.controller.view.element.ownerDocument, n = new oo(t, {
			blade: Ha(),
			itemProps: B.fromObject({
				selected: !1,
				title: e.title
			}),
			props: B.fromObject({ selected: !1 }),
			viewProps: eo.create()
		}), r = this.pool_.createApi(n);
		return this.rackApi_.add(r, e.index);
	}
	removePage(e) {
		this.rackApi_.remove(this.rackApi_.children[e]);
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
	onSelect_(e) {
		this.emitter_.emit("select", new yi(this, e.rawValue));
	}
}, co = class extends Pa {
	get title() {
		return this.controller.itemController.props.get("title") ?? "";
	}
	set title(e) {
		this.controller.itemController.props.set("title", e);
	}
	get selected() {
		return this.controller.props.get("selected");
	}
	set selected(e) {
		this.controller.props.set("selected", e);
	}
	get children() {
		return this.rackApi_.children;
	}
	addButton(e) {
		return this.rackApi_.addButton(e);
	}
	addFolder(e) {
		return this.rackApi_.addFolder(e);
	}
	addTab(e) {
		return this.rackApi_.addTab(e);
	}
	add(e, t) {
		this.rackApi_.add(e, t);
	}
	remove(e) {
		this.rackApi_.remove(e);
	}
	addBinding(e, t, n) {
		return this.rackApi_.addBinding(e, t, n);
	}
	addBlade(e) {
		return this.rackApi_.addBlade(e);
	}
}, lo = -1, uo = class {
	constructor() {
		this.onItemSelectedChange_ = this.onItemSelectedChange_.bind(this), this.empty = z(!0), this.selectedIndex = z(lo), this.items_ = [];
	}
	add(e, t) {
		let n = t ?? this.items_.length;
		this.items_.splice(n, 0, e), e.emitter.on("change", this.onItemSelectedChange_), this.keepSelection_();
	}
	remove(e) {
		let t = this.items_.indexOf(e);
		t < 0 || (this.items_.splice(t, 1), e.emitter.off("change", this.onItemSelectedChange_), this.keepSelection_());
	}
	keepSelection_() {
		if (this.items_.length === 0) {
			this.selectedIndex.rawValue = lo, this.empty.rawValue = !0;
			return;
		}
		let e = this.items_.findIndex((e) => e.rawValue);
		e < 0 ? (this.items_.forEach((e, t) => {
			e.rawValue = t === 0;
		}), this.selectedIndex.rawValue = 0) : (this.items_.forEach((t, n) => {
			t.rawValue = n === e;
		}), this.selectedIndex.rawValue = e), this.empty.rawValue = !1;
	}
	onItemSelectedChange_(e) {
		if (e.rawValue) {
			let t = this.items_.findIndex((t) => t === e.sender);
			this.items_.forEach((e, n) => {
				e.rawValue = n === t;
			}), this.selectedIndex.rawValue = t;
		} else this.keepSelection_();
	}
}, fo = q("tab"), po = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(fo(), Ja()), t.viewProps.bindClassModifiers(this.element), Ki(t.empty, ya(this.element, fo(void 0, "nop")));
		let n = e.createElement("div");
		n.classList.add(fo("t")), this.element.appendChild(n), this.itemsElement = n;
		let r = e.createElement("div");
		r.classList.add(fo("i")), this.element.appendChild(r);
		let i = e.createElement("div");
		i.classList.add(fo("c")), this.element.appendChild(i), this.contentsElement = i;
	}
}, mo = class extends Fa {
	constructor(e, t) {
		let n = new uo(), r = new po(e, {
			empty: n.empty,
			viewProps: t.viewProps
		});
		super({
			blade: t.blade,
			rackController: new Va({
				blade: t.blade,
				element: r.contentsElement,
				viewProps: t.viewProps
			}),
			view: r
		}), this.onRackAdd_ = this.onRackAdd_.bind(this), this.onRackRemove_ = this.onRackRemove_.bind(this);
		let i = this.rackController.rack;
		i.emitter.on("add", this.onRackAdd_), i.emitter.on("remove", this.onRackRemove_), this.tab = n;
	}
	add(e, t) {
		this.rackController.rack.add(e, t);
	}
	remove(e) {
		this.rackController.rack.remove(this.rackController.rack.children[e]);
	}
	onRackAdd_(e) {
		if (!e.root) return;
		let t = e.bladeController;
		Vi(this.view.itemsElement, t.itemController.view.element, e.index), t.itemController.viewProps.set("parent", this.viewProps), this.tab.add(t.props.value("selected"));
	}
	onRackRemove_(e) {
		if (!e.root) return;
		let t = e.bladeController;
		Hi(t.itemController.view.element), t.itemController.viewProps.set("parent", null), this.tab.remove(t.props.value("selected"));
	}
}, ho = J({
	id: "tab",
	type: "blade",
	accept(e) {
		let t = W(e, (e) => ({
			pages: e.required.array(e.required.object({ title: e.required.string })),
			view: e.required.constant("tab")
		}));
		return !t || t.pages.length === 0 ? null : { params: t };
	},
	controller(e) {
		let t = new mo(e.document, {
			blade: e.blade,
			viewProps: e.viewProps
		});
		return e.params.pages.forEach((n) => {
			let r = new oo(e.document, {
				blade: Ha(),
				itemProps: B.fromObject({
					selected: !1,
					title: n.title
				}),
				props: B.fromObject({ selected: !1 }),
				viewProps: eo.create()
			});
			t.add(r);
		}), t;
	},
	api(e) {
		return e.controller instanceof mo ? new so(e.controller, e.pool) : e.controller instanceof oo ? new co(e.controller, e.pool) : null;
	}
});
function go(e, t) {
	let n = e.accept(t.params);
	if (!n) return null;
	let r = W(t.params, (e) => ({
		disabled: e.optional.boolean,
		hidden: e.optional.boolean
	}));
	return e.controller({
		blade: Ha(),
		document: t.document,
		params: F(Object.assign(Object.assign({}, n.params), {
			disabled: r?.disabled,
			hidden: r?.hidden
		})),
		viewProps: eo.create({
			disabled: r?.disabled,
			hidden: r?.hidden
		})
	});
}
var _o = class extends xi {
	get options() {
		return this.controller.valueController.props.get("options");
	}
	set options(e) {
		this.controller.valueController.props.set("options", e);
	}
}, vo = class {
	constructor() {
		this.disabled = !1, this.emitter = new R();
	}
	dispose() {}
	tick() {
		this.disabled || this.emitter.emit("tick", { sender: this });
	}
}, yo = class {
	constructor(e, t) {
		this.disabled_ = !1, this.timerId_ = null, this.onTick_ = this.onTick_.bind(this), this.doc_ = e, this.emitter = new R(), this.interval_ = t, this.setTimer_();
	}
	get disabled() {
		return this.disabled_;
	}
	set disabled(e) {
		this.disabled_ = e, this.disabled_ ? this.clearTimer_() : this.setTimer_();
	}
	dispose() {
		this.clearTimer_();
	}
	clearTimer_() {
		if (this.timerId_ === null) return;
		let e = this.doc_.defaultView;
		e && e.clearInterval(this.timerId_), this.timerId_ = null;
	}
	setTimer_() {
		if (this.clearTimer_(), this.interval_ <= 0) return;
		let e = this.doc_.defaultView;
		e && (this.timerId_ = e.setInterval(this.onTick_, this.interval_));
	}
	onTick_() {
		this.disabled_ || this.emitter.emit("tick", { sender: this });
	}
}, bo = class {
	constructor(e) {
		this.constraints = e;
	}
	constrain(e) {
		return this.constraints.reduce((e, t) => t.constrain(e), e);
	}
};
function xo(e, t) {
	if (e instanceof t) return e;
	if (e instanceof bo) {
		let n = e.constraints.reduce((e, n) => e || (n instanceof t ? n : null), null);
		if (n) return n;
	}
	return null;
}
var So = class {
	constructor(e) {
		this.values = B.fromObject({ options: e });
	}
	constrain(e) {
		let t = this.values.get("options");
		return t.length === 0 || t.filter((t) => t.value === e).length > 0 ? e : t[0].value;
	}
};
function Co(e) {
	let t = ki;
	if (Array.isArray(e)) return W({ items: e }, (e) => ({ items: e.required.array(e.required.object({
		text: e.required.string,
		value: e.required.raw
	})) }))?.items;
	if (typeof e == "object") return t.required.raw(e).value;
}
function wo(e) {
	if (Array.isArray(e)) return e;
	let t = [];
	return Object.keys(e).forEach((n) => {
		t.push({
			text: n,
			value: e[n]
		});
	}), t;
}
function To(e) {
	return I(e) ? null : new So(wo(F(e)));
}
var Eo = q("lst"), Do = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), this.props_ = t.props, this.element = e.createElement("div"), this.element.classList.add(Eo()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("select");
		n.classList.add(Eo("s")), t.viewProps.bindDisabled(n), this.element.appendChild(n), this.selectElement = n;
		let r = e.createElement("div");
		r.classList.add(Eo("m")), r.appendChild(Bi(e, "dropdown")), this.element.appendChild(r), t.value.emitter.on("change", this.onValueChange_), this.value_ = t.value, qi(this.props_, "options", (t) => {
			Ui(this.selectElement), t.forEach((t) => {
				let n = e.createElement("option");
				n.textContent = t.text, this.selectElement.appendChild(n);
			}), this.update_();
		});
	}
	update_() {
		let e = this.props_.get("options").map((e) => e.value);
		this.selectElement.selectedIndex = e.indexOf(this.value_.rawValue);
	}
	onValueChange_() {
		this.update_();
	}
}, Oo = class {
	constructor(e, t) {
		this.onSelectChange_ = this.onSelectChange_.bind(this), this.props = t.props, this.value = t.value, this.viewProps = t.viewProps, this.view = new Do(e, {
			props: this.props,
			value: this.value,
			viewProps: this.viewProps
		}), this.view.selectElement.addEventListener("change", this.onSelectChange_);
	}
	onSelectChange_(e) {
		let t = F(e.currentTarget);
		this.value.rawValue = this.props.get("options")[t.selectedIndex].value;
	}
	importProps(e) {
		return G(e, null, (e) => ({ options: e.required.custom(Co) }), (e) => (this.props.set("options", wo(e.options)), !0));
	}
	exportProps() {
		return K(null, { options: this.props.get("options") });
	}
}, ko = q("pop"), Ao = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(ko()), t.viewProps.bindClassModifiers(this.element), Ki(t.shows, ya(this.element, ko(void 0, "v")));
	}
}, jo = class {
	constructor(e, t) {
		this.shows = z(!1), this.viewProps = t.viewProps, this.view = new Ao(e, {
			shows: this.shows,
			viewProps: this.viewProps
		});
	}
}, Mo = q("txt"), No = class {
	constructor(e, t) {
		this.onChange_ = this.onChange_.bind(this), this.element = e.createElement("div"), this.element.classList.add(Mo()), t.viewProps.bindClassModifiers(this.element), this.props_ = t.props, this.props_.emitter.on("change", this.onChange_);
		let n = e.createElement("input");
		n.classList.add(Mo("i")), n.type = "text", t.viewProps.bindDisabled(n), this.element.appendChild(n), this.inputElement = n, t.value.emitter.on("change", this.onChange_), this.value_ = t.value, this.refresh();
	}
	refresh() {
		let e = this.props_.get("formatter");
		this.inputElement.value = e(this.value_.rawValue);
	}
	onChange_() {
		this.refresh();
	}
}, Po = class {
	constructor(e, t) {
		this.onInputChange_ = this.onInputChange_.bind(this), this.parser_ = t.parser, this.props = t.props, this.value = t.value, this.viewProps = t.viewProps, this.view = new No(e, {
			props: t.props,
			value: this.value,
			viewProps: this.viewProps
		}), this.view.inputElement.addEventListener("change", this.onInputChange_);
	}
	onInputChange_(e) {
		let t = F(e.currentTarget).value, n = this.parser_(t);
		I(n) || (this.value.rawValue = n), this.view.refresh();
	}
};
function Fo(e) {
	return String(e);
}
function Io(e) {
	return e !== "false" && !!e;
}
function Lo(e) {
	return Fo(e);
}
function Ro(e) {
	return (t) => e.reduce((e, n) => e === null ? n(t) : e, null);
}
var zo = V(0);
function Bo(e) {
	return zo(e) + "%";
}
function Vo(e) {
	return String(e);
}
function Ho(e) {
	return e;
}
function Uo({ primary: e, secondary: t, forward: n, backward: r }) {
	let i = !1;
	function a(e) {
		i ||= (i = !0, e(), !1);
	}
	e.emitter.on("change", (r) => {
		a(() => {
			t.setRawValue(n(e.rawValue, t.rawValue), r.options);
		});
	}), t.emitter.on("change", (i) => {
		a(() => {
			e.setRawValue(r(e.rawValue, t.rawValue), i.options);
		}), a(() => {
			t.setRawValue(n(e.rawValue, t.rawValue), i.options);
		});
	}), a(() => {
		t.setRawValue(n(e.rawValue, t.rawValue), {
			forceEmit: !1,
			last: !0
		});
	});
}
function Y(e, t) {
	let n = e * (t.altKey ? .1 : 1) * (t.shiftKey ? 10 : 1);
	return t.upKey ? +n : t.downKey ? -n : 0;
}
function Wo(e) {
	return {
		altKey: e.altKey,
		downKey: e.key === "ArrowDown",
		shiftKey: e.shiftKey,
		upKey: e.key === "ArrowUp"
	};
}
function Go(e) {
	return {
		altKey: e.altKey,
		downKey: e.key === "ArrowLeft",
		shiftKey: e.shiftKey,
		upKey: e.key === "ArrowRight"
	};
}
function Ko(e) {
	return e === "ArrowUp" || e === "ArrowDown";
}
function qo(e) {
	return Ko(e) || e === "ArrowLeft" || e === "ArrowRight";
}
function Jo(e, t) {
	let n = t.ownerDocument.defaultView, r = t.getBoundingClientRect();
	return {
		x: e.pageX - (((n && n.scrollX) ?? 0) + r.left),
		y: e.pageY - (((n && n.scrollY) ?? 0) + r.top)
	};
}
var Yo = class {
	constructor(e) {
		this.lastTouch_ = null, this.onDocumentMouseMove_ = this.onDocumentMouseMove_.bind(this), this.onDocumentMouseUp_ = this.onDocumentMouseUp_.bind(this), this.onMouseDown_ = this.onMouseDown_.bind(this), this.onTouchEnd_ = this.onTouchEnd_.bind(this), this.onTouchMove_ = this.onTouchMove_.bind(this), this.onTouchStart_ = this.onTouchStart_.bind(this), this.elem_ = e, this.emitter = new R(), e.addEventListener("touchstart", this.onTouchStart_, { passive: !1 }), e.addEventListener("touchmove", this.onTouchMove_, { passive: !0 }), e.addEventListener("touchend", this.onTouchEnd_), e.addEventListener("mousedown", this.onMouseDown_);
	}
	computePosition_(e) {
		let t = this.elem_.getBoundingClientRect();
		return {
			bounds: {
				width: t.width,
				height: t.height
			},
			point: e ? {
				x: e.x,
				y: e.y
			} : null
		};
	}
	onMouseDown_(e) {
		var t;
		e.preventDefault(), (t = e.currentTarget) == null || t.focus();
		let n = this.elem_.ownerDocument;
		n.addEventListener("mousemove", this.onDocumentMouseMove_), n.addEventListener("mouseup", this.onDocumentMouseUp_), this.emitter.emit("down", {
			altKey: e.altKey,
			data: this.computePosition_(Jo(e, this.elem_)),
			sender: this,
			shiftKey: e.shiftKey
		});
	}
	onDocumentMouseMove_(e) {
		this.emitter.emit("move", {
			altKey: e.altKey,
			data: this.computePosition_(Jo(e, this.elem_)),
			sender: this,
			shiftKey: e.shiftKey
		});
	}
	onDocumentMouseUp_(e) {
		let t = this.elem_.ownerDocument;
		t.removeEventListener("mousemove", this.onDocumentMouseMove_), t.removeEventListener("mouseup", this.onDocumentMouseUp_), this.emitter.emit("up", {
			altKey: e.altKey,
			data: this.computePosition_(Jo(e, this.elem_)),
			sender: this,
			shiftKey: e.shiftKey
		});
	}
	onTouchStart_(e) {
		e.preventDefault();
		let t = e.targetTouches.item(0), n = this.elem_.getBoundingClientRect();
		this.emitter.emit("down", {
			altKey: e.altKey,
			data: this.computePosition_(t ? {
				x: t.clientX - n.left,
				y: t.clientY - n.top
			} : void 0),
			sender: this,
			shiftKey: e.shiftKey
		}), this.lastTouch_ = t;
	}
	onTouchMove_(e) {
		let t = e.targetTouches.item(0), n = this.elem_.getBoundingClientRect();
		this.emitter.emit("move", {
			altKey: e.altKey,
			data: this.computePosition_(t ? {
				x: t.clientX - n.left,
				y: t.clientY - n.top
			} : void 0),
			sender: this,
			shiftKey: e.shiftKey
		}), this.lastTouch_ = t;
	}
	onTouchEnd_(e) {
		let t = e.targetTouches.item(0) ?? this.lastTouch_, n = this.elem_.getBoundingClientRect();
		this.emitter.emit("up", {
			altKey: e.altKey,
			data: this.computePosition_(t ? {
				x: t.clientX - n.left,
				y: t.clientY - n.top
			} : void 0),
			sender: this,
			shiftKey: e.shiftKey
		});
	}
}, X = q("txt"), Xo = class {
	constructor(e, t) {
		this.onChange_ = this.onChange_.bind(this), this.props_ = t.props, this.props_.emitter.on("change", this.onChange_), this.element = e.createElement("div"), this.element.classList.add(X(), X(void 0, "num")), t.arrayPosition && this.element.classList.add(X(void 0, t.arrayPosition)), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("input");
		n.classList.add(X("i")), n.type = "text", t.viewProps.bindDisabled(n), this.element.appendChild(n), this.inputElement = n, this.onDraggingChange_ = this.onDraggingChange_.bind(this), this.dragging_ = t.dragging, this.dragging_.emitter.on("change", this.onDraggingChange_), this.element.classList.add(X()), this.inputElement.classList.add(X("i"));
		let r = e.createElement("div");
		r.classList.add(X("k")), this.element.appendChild(r), this.knobElement = r;
		let i = e.createElementNS(Mi, "svg");
		i.classList.add(X("g")), this.knobElement.appendChild(i);
		let a = e.createElementNS(Mi, "path");
		a.classList.add(X("gb")), i.appendChild(a), this.guideBodyElem_ = a;
		let o = e.createElementNS(Mi, "path");
		o.classList.add(X("gh")), i.appendChild(o), this.guideHeadElem_ = o;
		let s = e.createElement("div");
		s.classList.add(q("tt")()), this.knobElement.appendChild(s), this.tooltipElem_ = s, t.value.emitter.on("change", this.onChange_), this.value = t.value, this.refresh();
	}
	onDraggingChange_(e) {
		if (e.rawValue === null) {
			this.element.classList.remove(X(void 0, "drg"));
			return;
		}
		this.element.classList.add(X(void 0, "drg"));
		let t = e.rawValue / this.props_.get("pointerScale"), n = t + (t > 0 ? -1 : +(t < 0)), r = U(-n, -4, 4);
		this.guideHeadElem_.setAttributeNS(null, "d", [`M ${n + r},0 L${n},4 L${n + r},8`, `M ${t},-1 L${t},9`].join(" ")), this.guideBodyElem_.setAttributeNS(null, "d", `M 0,4 L${t},4`);
		let i = this.props_.get("formatter");
		this.tooltipElem_.textContent = i(this.value.rawValue), this.tooltipElem_.style.left = `${t}px`;
	}
	refresh() {
		let e = this.props_.get("formatter");
		this.inputElement.value = e(this.value.rawValue);
	}
	onChange_() {
		this.refresh();
	}
}, Zo = class {
	constructor(e, t) {
		this.originRawValue_ = 0, this.onInputChange_ = this.onInputChange_.bind(this), this.onInputKeyDown_ = this.onInputKeyDown_.bind(this), this.onInputKeyUp_ = this.onInputKeyUp_.bind(this), this.onPointerDown_ = this.onPointerDown_.bind(this), this.onPointerMove_ = this.onPointerMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.parser_ = t.parser, this.props = t.props, this.sliderProps_ = t.sliderProps ?? null, this.value = t.value, this.viewProps = t.viewProps, this.dragging_ = z(null), this.view = new Xo(e, {
			arrayPosition: t.arrayPosition,
			dragging: this.dragging_,
			props: this.props,
			value: this.value,
			viewProps: this.viewProps
		}), this.view.inputElement.addEventListener("change", this.onInputChange_), this.view.inputElement.addEventListener("keydown", this.onInputKeyDown_), this.view.inputElement.addEventListener("keyup", this.onInputKeyUp_);
		let n = new Yo(this.view.knobElement);
		n.emitter.on("down", this.onPointerDown_), n.emitter.on("move", this.onPointerMove_), n.emitter.on("up", this.onPointerUp_);
	}
	constrainValue_(e) {
		let t = this.sliderProps_?.get("min"), n = this.sliderProps_?.get("max"), r = e;
		return t !== void 0 && (r = Math.max(r, t)), n !== void 0 && (r = Math.min(r, n)), r;
	}
	onInputChange_(e) {
		let t = F(e.currentTarget).value, n = this.parser_(t);
		I(n) || (this.value.rawValue = this.constrainValue_(n)), this.view.refresh();
	}
	onInputKeyDown_(e) {
		let t = Y(this.props.get("keyScale"), Wo(e));
		t !== 0 && this.value.setRawValue(this.constrainValue_(this.value.rawValue + t), {
			forceEmit: !1,
			last: !1
		});
	}
	onInputKeyUp_(e) {
		Y(this.props.get("keyScale"), Wo(e)) !== 0 && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
	onPointerDown_() {
		this.originRawValue_ = this.value.rawValue, this.dragging_.rawValue = 0;
	}
	computeDraggingValue_(e) {
		if (!e.point) return null;
		let t = e.point.x - e.bounds.width / 2;
		return this.constrainValue_(this.originRawValue_ + t * this.props.get("pointerScale"));
	}
	onPointerMove_(e) {
		let t = this.computeDraggingValue_(e.data);
		t !== null && (this.value.setRawValue(t, {
			forceEmit: !1,
			last: !1
		}), this.dragging_.rawValue = this.value.rawValue - this.originRawValue_);
	}
	onPointerUp_(e) {
		let t = this.computeDraggingValue_(e.data);
		t !== null && (this.value.setRawValue(t, {
			forceEmit: !0,
			last: !0
		}), this.dragging_.rawValue = null);
	}
}, Qo = q("sld"), $o = class {
	constructor(e, t) {
		this.onChange_ = this.onChange_.bind(this), this.props_ = t.props, this.props_.emitter.on("change", this.onChange_), this.element = e.createElement("div"), this.element.classList.add(Qo()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Qo("t")), t.viewProps.bindTabIndex(n), this.element.appendChild(n), this.trackElement = n;
		let r = e.createElement("div");
		r.classList.add(Qo("k")), this.trackElement.appendChild(r), this.knobElement = r, t.value.emitter.on("change", this.onChange_), this.value = t.value, this.update_();
	}
	update_() {
		let e = U(H(this.value.rawValue, this.props_.get("min"), this.props_.get("max"), 0, 100), 0, 100);
		this.knobElement.style.width = `${e}%`;
	}
	onChange_() {
		this.update_();
	}
}, es = class {
	constructor(e, t) {
		this.onKeyDown_ = this.onKeyDown_.bind(this), this.onKeyUp_ = this.onKeyUp_.bind(this), this.onPointerDownOrMove_ = this.onPointerDownOrMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.props = t.props, this.view = new $o(e, {
			props: this.props,
			value: this.value,
			viewProps: this.viewProps
		}), this.ptHandler_ = new Yo(this.view.trackElement), this.ptHandler_.emitter.on("down", this.onPointerDownOrMove_), this.ptHandler_.emitter.on("move", this.onPointerDownOrMove_), this.ptHandler_.emitter.on("up", this.onPointerUp_), this.view.trackElement.addEventListener("keydown", this.onKeyDown_), this.view.trackElement.addEventListener("keyup", this.onKeyUp_);
	}
	handlePointerEvent_(e, t) {
		e.point && this.value.setRawValue(H(U(e.point.x, 0, e.bounds.width), 0, e.bounds.width, this.props.get("min"), this.props.get("max")), t);
	}
	onPointerDownOrMove_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerUp_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !0,
			last: !0
		});
	}
	onKeyDown_(e) {
		let t = Y(this.props.get("keyScale"), Go(e));
		t !== 0 && this.value.setRawValue(this.value.rawValue + t, {
			forceEmit: !1,
			last: !1
		});
	}
	onKeyUp_(e) {
		Y(this.props.get("keyScale"), Go(e)) !== 0 && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
}, ts = q("sldtxt"), ns = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(ts());
		let n = e.createElement("div");
		n.classList.add(ts("s")), this.sliderView_ = t.sliderView, n.appendChild(this.sliderView_.element), this.element.appendChild(n);
		let r = e.createElement("div");
		r.classList.add(ts("t")), this.textView_ = t.textView, r.appendChild(this.textView_.element), this.element.appendChild(r);
	}
}, rs = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.sliderC_ = new es(e, {
			props: t.sliderProps,
			value: t.value,
			viewProps: this.viewProps
		}), this.textC_ = new Zo(e, {
			parser: t.parser,
			props: t.textProps,
			sliderProps: t.sliderProps,
			value: t.value,
			viewProps: t.viewProps
		}), this.view = new ns(e, {
			sliderView: this.sliderC_.view,
			textView: this.textC_.view
		});
	}
	get sliderController() {
		return this.sliderC_;
	}
	get textController() {
		return this.textC_;
	}
	importProps(e) {
		return G(e, null, (e) => ({
			max: e.required.number,
			min: e.required.number
		}), (e) => {
			let t = this.sliderC_.props;
			return t.set("max", e.max), t.set("min", e.min), !0;
		});
	}
	exportProps() {
		let e = this.sliderC_.props;
		return K(null, {
			max: e.get("max"),
			min: e.get("min")
		});
	}
};
function is(e) {
	return {
		sliderProps: new B({
			keyScale: e.keyScale,
			max: e.max,
			min: e.min
		}),
		textProps: new B({
			formatter: z(e.formatter),
			keyScale: e.keyScale,
			pointerScale: z(e.pointerScale)
		})
	};
}
var as = { containerUnitSize: "cnt-usz" };
function os(e) {
	return `--${as[e]}`;
}
function ss(e) {
	return pi(e);
}
function cs(e) {
	if (dr(e)) return W(e, ss);
}
function ls(e, t) {
	if (!e) return;
	let n = [], r = ui(e, t);
	r && n.push(r);
	let i = di(e);
	return i && n.push(i), new bo(n);
}
function us(e) {
	return e ? e.major === Ea.major : !1;
}
function ds(e) {
	if (e === "inline" || e === "popup") return e;
}
function fs(e, t) {
	e.write(t);
}
var ps = q("ckb"), ms = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), this.element = e.createElement("div"), this.element.classList.add(ps()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("label");
		n.classList.add(ps("l")), this.element.appendChild(n), this.labelElement = n;
		let r = e.createElement("input");
		r.classList.add(ps("i")), r.type = "checkbox", this.labelElement.appendChild(r), this.inputElement = r, t.viewProps.bindDisabled(this.inputElement);
		let i = e.createElement("div");
		i.classList.add(ps("w")), this.labelElement.appendChild(i);
		let a = Bi(e, "check");
		i.appendChild(a), t.value.emitter.on("change", this.onValueChange_), this.value = t.value, this.update_();
	}
	update_() {
		this.inputElement.checked = this.value.rawValue;
	}
	onValueChange_() {
		this.update_();
	}
}, hs = class {
	constructor(e, t) {
		this.onInputChange_ = this.onInputChange_.bind(this), this.onLabelMouseDown_ = this.onLabelMouseDown_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.view = new ms(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.view.inputElement.addEventListener("change", this.onInputChange_), this.view.labelElement.addEventListener("mousedown", this.onLabelMouseDown_);
	}
	onInputChange_(e) {
		let t = F(e.currentTarget);
		this.value.rawValue = t.checked, e.preventDefault(), e.stopPropagation();
	}
	onLabelMouseDown_(e) {
		e.preventDefault();
	}
};
function gs(e) {
	let t = [], n = To(e.options);
	return n && t.push(n), new bo(t);
}
var _s = J({
	id: "input-bool",
	type: "input",
	accept: (e, t) => {
		if (typeof e != "boolean") return null;
		let n = W(t, (e) => ({
			options: e.optional.custom(Co),
			readonly: e.optional.constant(!1)
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: (e) => Io,
		constraint: (e) => gs(e.params),
		writer: (e) => fs
	},
	controller: (e) => {
		let t = e.document, n = e.value, r = e.constraint, i = r && xo(r, So);
		return i ? new Oo(t, {
			props: new B({ options: i.values.value("options") }),
			value: n,
			viewProps: e.viewProps
		}) : new hs(t, {
			value: n,
			viewProps: e.viewProps
		});
	},
	api(e) {
		return typeof e.controller.value.rawValue == "boolean" && e.controller.valueController instanceof Oo ? new _o(e.controller) : null;
	}
}), vs = q("col"), ys = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(vs()), t.foldable.bindExpandedClass(this.element, vs(void 0, "expanded")), qi(t.foldable, "completed", ya(this.element, vs(void 0, "cpl")));
		let n = e.createElement("div");
		n.classList.add(vs("h")), this.element.appendChild(n);
		let r = e.createElement("div");
		r.classList.add(vs("s")), n.appendChild(r), this.swatchElement = r;
		let i = e.createElement("div");
		if (i.classList.add(vs("t")), n.appendChild(i), this.textElement = i, t.pickerLayout === "inline") {
			let t = e.createElement("div");
			t.classList.add(vs("p")), this.element.appendChild(t), this.pickerElement = t;
		} else this.pickerElement = null;
	}
};
function bs(e, t, n) {
	let r = U(e / 255, 0, 1), i = U(t / 255, 0, 1), a = U(n / 255, 0, 1), o = Math.max(r, i, a), s = Math.min(r, i, a), c = o - s, l = 0, u = 0, d = (s + o) / 2;
	return c !== 0 && (u = c / (1 - Math.abs(o + s - 1)), l = r === o ? (i - a) / c : i === o ? 2 + (a - r) / c : 4 + (r - i) / c, l = l / 6 + +(l < 0)), [
		l * 360,
		u * 100,
		d * 100
	];
}
function xs(e, t, n) {
	let r = (e % 360 + 360) % 360, i = U(t / 100, 0, 1), a = U(n / 100, 0, 1), o = (1 - Math.abs(2 * a - 1)) * i, s = o * (1 - Math.abs(r / 60 % 2 - 1)), c = a - o / 2, l, u, d;
	return r >= 0 && r < 60 ? [l, u, d] = [
		o,
		s,
		0
	] : r >= 60 && r < 120 ? [l, u, d] = [
		s,
		o,
		0
	] : r >= 120 && r < 180 ? [l, u, d] = [
		0,
		o,
		s
	] : r >= 180 && r < 240 ? [l, u, d] = [
		0,
		s,
		o
	] : r >= 240 && r < 300 ? [l, u, d] = [
		s,
		0,
		o
	] : [l, u, d] = [
		o,
		0,
		s
	], [
		(l + c) * 255,
		(u + c) * 255,
		(d + c) * 255
	];
}
function Ss(e, t, n) {
	let r = U(e / 255, 0, 1), i = U(t / 255, 0, 1), a = U(n / 255, 0, 1), o = Math.max(r, i, a), s = o - Math.min(r, i, a), c;
	c = s === 0 ? 0 : o === r ? 60 * (((i - a) / s % 6 + 6) % 6) : o === i ? 60 * ((a - r) / s + 2) : 60 * ((r - i) / s + 4);
	let l = o === 0 ? 0 : s / o, u = o;
	return [
		c,
		l * 100,
		u * 100
	];
}
function Cs(e, t, n) {
	let r = oi(e, 360), i = U(t / 100, 0, 1), a = U(n / 100, 0, 1), o = a * i, s = o * (1 - Math.abs(r / 60 % 2 - 1)), c = a - o, l, u, d;
	return r >= 0 && r < 60 ? [l, u, d] = [
		o,
		s,
		0
	] : r >= 60 && r < 120 ? [l, u, d] = [
		s,
		o,
		0
	] : r >= 120 && r < 180 ? [l, u, d] = [
		0,
		o,
		s
	] : r >= 180 && r < 240 ? [l, u, d] = [
		0,
		s,
		o
	] : r >= 240 && r < 300 ? [l, u, d] = [
		s,
		0,
		o
	] : [l, u, d] = [
		o,
		0,
		s
	], [
		(l + c) * 255,
		(u + c) * 255,
		(d + c) * 255
	];
}
function ws(e, t, n) {
	let r = n + t * (100 - Math.abs(2 * n - 100)) / 200;
	return [
		e,
		r === 0 ? 0 : t * (100 - Math.abs(2 * n - 100)) / r,
		n + t * (100 - Math.abs(2 * n - 100)) / 200
	];
}
function Ts(e, t, n) {
	let r = 100 - Math.abs(n * (200 - t) / 100 - 100);
	return [
		e,
		r === 0 ? 0 : t * n / r,
		n * (200 - t) / 200
	];
}
function Es(e) {
	return [
		e[0],
		e[1],
		e[2]
	];
}
function Ds(e, t) {
	return [
		e[0],
		e[1],
		e[2],
		t
	];
}
var Os = {
	hsl: {
		hsl: (e, t, n) => [
			e,
			t,
			n
		],
		hsv: ws,
		rgb: xs
	},
	hsv: {
		hsl: Ts,
		hsv: (e, t, n) => [
			e,
			t,
			n
		],
		rgb: Cs
	},
	rgb: {
		hsl: bs,
		hsv: Ss,
		rgb: (e, t, n) => [
			e,
			t,
			n
		]
	}
};
function ks(e, t) {
	return [
		t === "float" ? 1 : e === "rgb" ? 255 : 360,
		t === "float" ? 1 : e === "rgb" ? 255 : 100,
		t === "float" ? 1 : e === "rgb" ? 255 : 100
	];
}
function As(e, t) {
	return e === t ? t : oi(e, t);
}
function js(e, t, n) {
	let r = ks(t, n);
	return [
		t === "rgb" ? U(e[0], 0, r[0]) : As(e[0], r[0]),
		U(e[1], 0, r[1]),
		U(e[2], 0, r[2]),
		U(e[3] ?? 1, 0, 1)
	];
}
function Ms(e, t, n, r) {
	let i = ks(t, n), a = ks(t, r);
	return e.map((e, t) => e / i[t] * a[t]);
}
function Ns(e, t, n) {
	let r = Ms(e, t.mode, t.type, "int");
	return Ms(Os[t.mode][n.mode](...r), n.mode, "int", n.type);
}
var Z = class e {
	static black() {
		return new e([
			0,
			0,
			0
		], "rgb");
	}
	constructor(e, t) {
		this.type = "int", this.mode = t, this.comps_ = js(e, t, this.type);
	}
	getComponents(e) {
		return Ds(Ns(Es(this.comps_), {
			mode: this.mode,
			type: this.type
		}, {
			mode: e ?? this.mode,
			type: this.type
		}), this.comps_[3]);
	}
	toRgbaObject() {
		let e = this.getComponents("rgb");
		return {
			r: e[0],
			g: e[1],
			b: e[2],
			a: e[3]
		};
	}
}, Ps = q("colp"), Fs = class {
	constructor(e, t) {
		this.alphaViews_ = null, this.element = e.createElement("div"), this.element.classList.add(Ps()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Ps("hsv"));
		let r = e.createElement("div");
		r.classList.add(Ps("sv")), this.svPaletteView_ = t.svPaletteView, r.appendChild(this.svPaletteView_.element), n.appendChild(r);
		let i = e.createElement("div");
		i.classList.add(Ps("h")), this.hPaletteView_ = t.hPaletteView, i.appendChild(this.hPaletteView_.element), n.appendChild(i), this.element.appendChild(n);
		let a = e.createElement("div");
		if (a.classList.add(Ps("rgb")), this.textsView_ = t.textsView, a.appendChild(this.textsView_.element), this.element.appendChild(a), t.alphaViews) {
			this.alphaViews_ = {
				palette: t.alphaViews.palette,
				text: t.alphaViews.text
			};
			let n = e.createElement("div");
			n.classList.add(Ps("a"));
			let r = e.createElement("div");
			r.classList.add(Ps("ap")), r.appendChild(this.alphaViews_.palette.element), n.appendChild(r);
			let i = e.createElement("div");
			i.classList.add(Ps("at")), i.appendChild(this.alphaViews_.text.element), n.appendChild(i), this.element.appendChild(n);
		}
	}
	get allFocusableElements() {
		let e = [
			this.svPaletteView_.element,
			this.hPaletteView_.element,
			this.textsView_.modeSelectElement,
			...this.textsView_.inputViews.map((e) => e.inputElement)
		];
		return this.alphaViews_ && e.push(this.alphaViews_.palette.element, this.alphaViews_.text.inputElement), e;
	}
};
function Is(e) {
	return e === "int" ? "int" : e === "float" ? "float" : void 0;
}
function Ls(e) {
	return W(e, (e) => ({
		color: e.optional.object({
			alpha: e.optional.boolean,
			type: e.optional.custom(Is)
		}),
		expanded: e.optional.boolean,
		picker: e.optional.custom(ds),
		readonly: e.optional.constant(!1)
	}));
}
function Rs(e) {
	return e ? .1 : 1;
}
function zs(e) {
	return e.color?.type;
}
var Bs = class {
	constructor(e, t) {
		this.type = "float", this.mode = t, this.comps_ = js(e, t, this.type);
	}
	getComponents(e) {
		return Ds(Ns(Es(this.comps_), {
			mode: this.mode,
			type: this.type
		}, {
			mode: e ?? this.mode,
			type: this.type
		}), this.comps_[3]);
	}
	toRgbaObject() {
		let e = this.getComponents("rgb");
		return {
			r: e[0],
			g: e[1],
			b: e[2],
			a: e[3]
		};
	}
}, Vs = {
	int: (e, t) => new Z(e, t),
	float: (e, t) => new Bs(e, t)
};
function Hs(e, t, n) {
	return Vs[n](e, t);
}
function Us(e) {
	return e.type === "float";
}
function Ws(e) {
	return e.type === "int";
}
function Gs(e) {
	let t = e.getComponents(), n = ks(e.mode, "int");
	return new Z([
		Math.round(H(t[0], 0, 1, 0, n[0])),
		Math.round(H(t[1], 0, 1, 0, n[1])),
		Math.round(H(t[2], 0, 1, 0, n[2])),
		t[3]
	], e.mode);
}
function Ks(e) {
	let t = e.getComponents(), n = ks(e.mode, "int");
	return new Bs([
		H(t[0], 0, n[0], 0, 1),
		H(t[1], 0, n[1], 0, 1),
		H(t[2], 0, n[2], 0, 1),
		t[3]
	], e.mode);
}
function Q(e, t) {
	if (e.type === t) return e;
	if (Ws(e) && t === "float") return Ks(e);
	if (Us(e) && t === "int") return Gs(e);
	throw L.shouldNeverHappen();
}
function qs(e, t) {
	return e.alpha === t.alpha && e.mode === t.mode && e.notation === t.notation && e.type === t.type;
}
function $(e, t) {
	let n = e.match(/^(.+)%$/);
	return Math.min(n ? parseFloat(n[1]) * .01 * t : parseFloat(e), t);
}
var Js = {
	deg: (e) => e,
	grad: (e) => e * 360 / 400,
	rad: (e) => e * 360 / (2 * Math.PI),
	turn: (e) => e * 360
};
function Ys(e) {
	let t = e.match(/^([0-9.]+?)(deg|grad|rad|turn)$/);
	if (!t) return parseFloat(e);
	let n = parseFloat(t[1]);
	return Js[t[2]](n);
}
function Xs(e) {
	let t = e.match(/^rgb\(\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*\)$/);
	if (!t) return null;
	let n = [
		$(t[1], 255),
		$(t[2], 255),
		$(t[3], 255)
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) ? null : n;
}
function Zs(e) {
	let t = Xs(e);
	return t ? new Z(t, "rgb") : null;
}
function Qs(e) {
	let t = e.match(/^rgba\(\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*\)$/);
	if (!t) return null;
	let n = [
		$(t[1], 255),
		$(t[2], 255),
		$(t[3], 255),
		$(t[4], 1)
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) || isNaN(n[3]) ? null : n;
}
function $s(e) {
	let t = Qs(e);
	return t ? new Z(t, "rgb") : null;
}
function ec(e) {
	let t = e.match(/^hsl\(\s*([0-9A-Fa-f.]+(?:deg|grad|rad|turn)?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*\)$/);
	if (!t) return null;
	let n = [
		Ys(t[1]),
		$(t[2], 100),
		$(t[3], 100)
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) ? null : n;
}
function tc(e) {
	let t = ec(e);
	return t ? new Z(t, "hsl") : null;
}
function nc(e) {
	let t = e.match(/^hsla\(\s*([0-9A-Fa-f.]+(?:deg|grad|rad|turn)?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*,\s*([0-9A-Fa-f.]+%?)\s*\)$/);
	if (!t) return null;
	let n = [
		Ys(t[1]),
		$(t[2], 100),
		$(t[3], 100),
		$(t[4], 1)
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) || isNaN(n[3]) ? null : n;
}
function rc(e) {
	let t = nc(e);
	return t ? new Z(t, "hsl") : null;
}
function ic(e) {
	let t = e.match(/^#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$/);
	if (t) return [
		parseInt(t[1] + t[1], 16),
		parseInt(t[2] + t[2], 16),
		parseInt(t[3] + t[3], 16)
	];
	let n = e.match(/^(?:#|0x)([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/);
	return n ? [
		parseInt(n[1], 16),
		parseInt(n[2], 16),
		parseInt(n[3], 16)
	] : null;
}
function ac(e) {
	let t = ic(e);
	return t ? new Z(t, "rgb") : null;
}
function oc(e) {
	let t = e.match(/^#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$/);
	if (t) return [
		parseInt(t[1] + t[1], 16),
		parseInt(t[2] + t[2], 16),
		parseInt(t[3] + t[3], 16),
		H(parseInt(t[4] + t[4], 16), 0, 255, 0, 1)
	];
	let n = e.match(/^(?:#|0x)?([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$/);
	return n ? [
		parseInt(n[1], 16),
		parseInt(n[2], 16),
		parseInt(n[3], 16),
		H(parseInt(n[4], 16), 0, 255, 0, 1)
	] : null;
}
function sc(e) {
	let t = oc(e);
	return t ? new Z(t, "rgb") : null;
}
function cc(e) {
	let t = e.match(/^\{\s*r\s*:\s*([0-9A-Fa-f.]+%?)\s*,\s*g\s*:\s*([0-9A-Fa-f.]+%?)\s*,\s*b\s*:\s*([0-9A-Fa-f.]+%?)\s*\}$/);
	if (!t) return null;
	let n = [
		parseFloat(t[1]),
		parseFloat(t[2]),
		parseFloat(t[3])
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) ? null : n;
}
function lc(e) {
	return (t) => {
		let n = cc(t);
		return n ? Hs(n, "rgb", e) : null;
	};
}
function uc(e) {
	let t = e.match(/^\{\s*r\s*:\s*([0-9A-Fa-f.]+%?)\s*,\s*g\s*:\s*([0-9A-Fa-f.]+%?)\s*,\s*b\s*:\s*([0-9A-Fa-f.]+%?)\s*,\s*a\s*:\s*([0-9A-Fa-f.]+%?)\s*\}$/);
	if (!t) return null;
	let n = [
		parseFloat(t[1]),
		parseFloat(t[2]),
		parseFloat(t[3]),
		parseFloat(t[4])
	];
	return isNaN(n[0]) || isNaN(n[1]) || isNaN(n[2]) || isNaN(n[3]) ? null : n;
}
function dc(e) {
	return (t) => {
		let n = uc(t);
		return n ? Hs(n, "rgb", e) : null;
	};
}
var fc = [
	{
		parser: ic,
		result: {
			alpha: !1,
			mode: "rgb",
			notation: "hex"
		}
	},
	{
		parser: oc,
		result: {
			alpha: !0,
			mode: "rgb",
			notation: "hex"
		}
	},
	{
		parser: Xs,
		result: {
			alpha: !1,
			mode: "rgb",
			notation: "func"
		}
	},
	{
		parser: Qs,
		result: {
			alpha: !0,
			mode: "rgb",
			notation: "func"
		}
	},
	{
		parser: ec,
		result: {
			alpha: !1,
			mode: "hsl",
			notation: "func"
		}
	},
	{
		parser: nc,
		result: {
			alpha: !0,
			mode: "hsl",
			notation: "func"
		}
	},
	{
		parser: cc,
		result: {
			alpha: !1,
			mode: "rgb",
			notation: "object"
		}
	},
	{
		parser: uc,
		result: {
			alpha: !0,
			mode: "rgb",
			notation: "object"
		}
	}
];
function pc(e) {
	return fc.reduce((t, { parser: n, result: r }) => t || (n(e) ? r : null), null);
}
function mc(e, t = "int") {
	let n = pc(e);
	return n ? n.notation === "hex" && t !== "float" ? Object.assign(Object.assign({}, n), { type: "int" }) : n.notation === "func" ? Object.assign(Object.assign({}, n), { type: t }) : null : null;
}
function hc(e) {
	let t = [
		ac,
		sc,
		Zs,
		$s,
		tc,
		rc
	];
	e === "int" && t.push(lc("int"), dc("int")), e === "float" && t.push(lc("float"), dc("float"));
	let n = Ro(t);
	return (t) => {
		let r = n(t);
		return r ? Q(r, e) : null;
	};
}
function gc(e) {
	let t = hc("int");
	return typeof e == "string" ? t(e) ?? Z.black() : Z.black();
}
function _c(e) {
	let t = U(Math.floor(e), 0, 255).toString(16);
	return t.length === 1 ? `0${t}` : t;
}
function vc(e, t = "#") {
	return `${t}${Es(e.getComponents("rgb")).map(_c).join("")}`;
}
function yc(e, t = "#") {
	let n = e.getComponents("rgb");
	return `${t}${[
		n[0],
		n[1],
		n[2],
		n[3] * 255
	].map(_c).join("")}`;
}
function bc(e) {
	let t = V(0);
	return `rgb(${Es(Q(e, "int").getComponents("rgb")).map((e) => t(e)).join(", ")})`;
}
function xc(e) {
	let t = V(2), n = V(0);
	return `rgba(${Q(e, "int").getComponents("rgb").map((e, r) => (r === 3 ? t : n)(e)).join(", ")})`;
}
function Sc(e) {
	let t = [
		V(0),
		Bo,
		Bo
	];
	return `hsl(${Es(Q(e, "int").getComponents("hsl")).map((e, n) => t[n](e)).join(", ")})`;
}
function Cc(e) {
	let t = [
		V(0),
		Bo,
		Bo,
		V(2)
	];
	return `hsla(${Q(e, "int").getComponents("hsl").map((e, n) => t[n](e)).join(", ")})`;
}
function wc(e, t) {
	let n = V(t === "float" ? 2 : 0), r = [
		"r",
		"g",
		"b"
	];
	return `{${Es(Q(e, t).getComponents("rgb")).map((e, t) => `${r[t]}: ${n(e)}`).join(", ")}}`;
}
function Tc(e) {
	return (t) => wc(t, e);
}
function Ec(e, t) {
	let n = V(2), r = V(t === "float" ? 2 : 0), i = [
		"r",
		"g",
		"b",
		"a"
	];
	return `{${Q(e, t).getComponents("rgb").map((e, t) => {
		let a = t === 3 ? n : r;
		return `${i[t]}: ${a(e)}`;
	}).join(", ")}}`;
}
function Dc(e) {
	return (t) => Ec(t, e);
}
var Oc = [
	{
		format: {
			alpha: !1,
			mode: "rgb",
			notation: "hex",
			type: "int"
		},
		stringifier: vc
	},
	{
		format: {
			alpha: !0,
			mode: "rgb",
			notation: "hex",
			type: "int"
		},
		stringifier: yc
	},
	{
		format: {
			alpha: !1,
			mode: "rgb",
			notation: "func",
			type: "int"
		},
		stringifier: bc
	},
	{
		format: {
			alpha: !0,
			mode: "rgb",
			notation: "func",
			type: "int"
		},
		stringifier: xc
	},
	{
		format: {
			alpha: !1,
			mode: "hsl",
			notation: "func",
			type: "int"
		},
		stringifier: Sc
	},
	{
		format: {
			alpha: !0,
			mode: "hsl",
			notation: "func",
			type: "int"
		},
		stringifier: Cc
	},
	...["int", "float"].reduce((e, t) => [
		...e,
		{
			format: {
				alpha: !1,
				mode: "rgb",
				notation: "object",
				type: t
			},
			stringifier: Tc(t)
		},
		{
			format: {
				alpha: !0,
				mode: "rgb",
				notation: "object",
				type: t
			},
			stringifier: Dc(t)
		}
	], [])
];
function kc(e) {
	return Oc.reduce((t, n) => t || (qs(n.format, e) ? n.stringifier : null), null);
}
var Ac = q("apl"), jc = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), this.value = t.value, this.value.emitter.on("change", this.onValueChange_), this.element = e.createElement("div"), this.element.classList.add(Ac()), t.viewProps.bindClassModifiers(this.element), t.viewProps.bindTabIndex(this.element);
		let n = e.createElement("div");
		n.classList.add(Ac("b")), this.element.appendChild(n);
		let r = e.createElement("div");
		r.classList.add(Ac("c")), n.appendChild(r), this.colorElem_ = r;
		let i = e.createElement("div");
		i.classList.add(Ac("m")), this.element.appendChild(i), this.markerElem_ = i;
		let a = e.createElement("div");
		a.classList.add(Ac("p")), this.markerElem_.appendChild(a), this.previewElem_ = a, this.update_();
	}
	update_() {
		let e = this.value.rawValue, t = e.getComponents("rgb"), n = new Z([
			t[0],
			t[1],
			t[2],
			0
		], "rgb"), r = new Z([
			t[0],
			t[1],
			t[2],
			255
		], "rgb"), i = [
			"to right",
			xc(n),
			xc(r)
		];
		this.colorElem_.style.background = `linear-gradient(${i.join(",")})`, this.previewElem_.style.backgroundColor = xc(e);
		let a = H(t[3], 0, 1, 0, 100);
		this.markerElem_.style.left = `${a}%`;
	}
	onValueChange_() {
		this.update_();
	}
}, Mc = class {
	constructor(e, t) {
		this.onKeyDown_ = this.onKeyDown_.bind(this), this.onKeyUp_ = this.onKeyUp_.bind(this), this.onPointerDown_ = this.onPointerDown_.bind(this), this.onPointerMove_ = this.onPointerMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.view = new jc(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.ptHandler_ = new Yo(this.view.element), this.ptHandler_.emitter.on("down", this.onPointerDown_), this.ptHandler_.emitter.on("move", this.onPointerMove_), this.ptHandler_.emitter.on("up", this.onPointerUp_), this.view.element.addEventListener("keydown", this.onKeyDown_), this.view.element.addEventListener("keyup", this.onKeyUp_);
	}
	handlePointerEvent_(e, t) {
		if (!e.point) return;
		let n = e.point.x / e.bounds.width, [r, i, a] = this.value.rawValue.getComponents("hsv");
		this.value.setRawValue(new Z([
			r,
			i,
			a,
			n
		], "hsv"), t);
	}
	onPointerDown_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerMove_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerUp_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !0,
			last: !0
		});
	}
	onKeyDown_(e) {
		let t = Y(Rs(!0), Go(e));
		if (t === 0) return;
		let [n, r, i, a] = this.value.rawValue.getComponents("hsv");
		this.value.setRawValue(new Z([
			n,
			r,
			i,
			a + t
		], "hsv"), {
			forceEmit: !1,
			last: !1
		});
	}
	onKeyUp_(e) {
		Y(Rs(!0), Go(e)) !== 0 && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
}, Nc = q("coltxt");
function Pc(e) {
	let t = e.createElement("select");
	return t.appendChild([
		{
			text: "RGB",
			value: "rgb"
		},
		{
			text: "HSL",
			value: "hsl"
		},
		{
			text: "HSV",
			value: "hsv"
		},
		{
			text: "HEX",
			value: "hex"
		}
	].reduce((t, n) => {
		let r = e.createElement("option");
		return r.textContent = n.text, r.value = n.value, t.appendChild(r), t;
	}, e.createDocumentFragment())), t;
}
var Fc = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(Nc()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Nc("m")), this.modeElem_ = Pc(e), this.modeElem_.classList.add(Nc("ms")), n.appendChild(this.modeSelectElement), t.viewProps.bindDisabled(this.modeElem_);
		let r = e.createElement("div");
		r.classList.add(Nc("mm")), r.appendChild(Bi(e, "dropdown")), n.appendChild(r), this.element.appendChild(n);
		let i = e.createElement("div");
		i.classList.add(Nc("w")), this.element.appendChild(i), this.inputsElem_ = i, this.inputViews_ = t.inputViews, this.applyInputViews_(), Ki(t.mode, (e) => {
			this.modeElem_.value = e;
		});
	}
	get modeSelectElement() {
		return this.modeElem_;
	}
	get inputViews() {
		return this.inputViews_;
	}
	set inputViews(e) {
		this.inputViews_ = e, this.applyInputViews_();
	}
	applyInputViews_() {
		Ui(this.inputsElem_);
		let e = this.element.ownerDocument;
		this.inputViews_.forEach((t) => {
			let n = e.createElement("div");
			n.classList.add(Nc("c")), n.appendChild(t.element), this.inputsElem_.appendChild(n);
		});
	}
};
function Ic(e) {
	return V(e === "float" ? 2 : 0);
}
function Lc(e, t, n) {
	let r = ks(e, t)[n];
	return new xr({
		min: 0,
		max: r
	});
}
function Rc(e, t, n) {
	return new Zo(e, {
		arrayPosition: n === 0 ? "fst" : n === 2 ? "lst" : "mid",
		parser: t.parser,
		props: B.fromObject({
			formatter: Ic(t.colorType),
			keyScale: Rs(!1),
			pointerScale: t.colorType === "float" ? .01 : 1
		}),
		value: z(0, { constraint: Lc(t.colorMode, t.colorType, n) }),
		viewProps: t.viewProps
	});
}
function zc(e, t) {
	let n = {
		colorMode: t.colorMode,
		colorType: t.colorType,
		parser: ni,
		viewProps: t.viewProps
	};
	return [
		0,
		1,
		2
	].map((r) => {
		let i = Rc(e, n, r);
		return Uo({
			primary: t.value,
			secondary: i.value,
			forward(e) {
				return Q(e, t.colorType).getComponents(t.colorMode)[r];
			},
			backward(e, n) {
				let i = t.colorMode, a = Q(e, t.colorType).getComponents(i);
				return a[r] = n, Q(Hs(Ds(Es(a), a[3]), i, t.colorType), "int");
			}
		}), i;
	});
}
function Bc(e, t) {
	let n = new Po(e, {
		parser: hc("int"),
		props: B.fromObject({ formatter: vc }),
		value: z(Z.black()),
		viewProps: t.viewProps
	});
	return Uo({
		primary: t.value,
		secondary: n.value,
		forward: (e) => new Z(Es(e.getComponents()), e.mode),
		backward: (e, t) => new Z(Ds(Es(t.getComponents(e.mode)), e.getComponents()[3]), e.mode)
	}), [n];
}
function Vc(e) {
	return e !== "hex";
}
var Hc = class {
	constructor(e, t) {
		this.onModeSelectChange_ = this.onModeSelectChange_.bind(this), this.colorType_ = t.colorType, this.value = t.value, this.viewProps = t.viewProps, this.colorMode = z(this.value.rawValue.mode), this.ccs_ = this.createComponentControllers_(e), this.view = new Fc(e, {
			mode: this.colorMode,
			inputViews: [
				this.ccs_[0].view,
				this.ccs_[1].view,
				this.ccs_[2].view
			],
			viewProps: this.viewProps
		}), this.view.modeSelectElement.addEventListener("change", this.onModeSelectChange_);
	}
	createComponentControllers_(e) {
		let t = this.colorMode.rawValue;
		return Vc(t) ? zc(e, {
			colorMode: t,
			colorType: this.colorType_,
			value: this.value,
			viewProps: this.viewProps
		}) : Bc(e, {
			value: this.value,
			viewProps: this.viewProps
		});
	}
	onModeSelectChange_(e) {
		let t = e.currentTarget;
		this.colorMode.rawValue = t.value, this.ccs_ = this.createComponentControllers_(this.view.element.ownerDocument), this.view.inputViews = this.ccs_.map((e) => e.view);
	}
}, Uc = q("hpl"), Wc = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), this.value = t.value, this.value.emitter.on("change", this.onValueChange_), this.element = e.createElement("div"), this.element.classList.add(Uc()), t.viewProps.bindClassModifiers(this.element), t.viewProps.bindTabIndex(this.element);
		let n = e.createElement("div");
		n.classList.add(Uc("c")), this.element.appendChild(n);
		let r = e.createElement("div");
		r.classList.add(Uc("m")), this.element.appendChild(r), this.markerElem_ = r, this.update_();
	}
	update_() {
		let [e] = this.value.rawValue.getComponents("hsv");
		this.markerElem_.style.backgroundColor = bc(new Z([
			e,
			100,
			100
		], "hsv"));
		let t = H(e, 0, 360, 0, 100);
		this.markerElem_.style.left = `${t}%`;
	}
	onValueChange_() {
		this.update_();
	}
}, Gc = class {
	constructor(e, t) {
		this.onKeyDown_ = this.onKeyDown_.bind(this), this.onKeyUp_ = this.onKeyUp_.bind(this), this.onPointerDown_ = this.onPointerDown_.bind(this), this.onPointerMove_ = this.onPointerMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.view = new Wc(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.ptHandler_ = new Yo(this.view.element), this.ptHandler_.emitter.on("down", this.onPointerDown_), this.ptHandler_.emitter.on("move", this.onPointerMove_), this.ptHandler_.emitter.on("up", this.onPointerUp_), this.view.element.addEventListener("keydown", this.onKeyDown_), this.view.element.addEventListener("keyup", this.onKeyUp_);
	}
	handlePointerEvent_(e, t) {
		if (!e.point) return;
		let n = H(U(e.point.x, 0, e.bounds.width), 0, e.bounds.width, 0, 360), [, r, i, a] = this.value.rawValue.getComponents("hsv");
		this.value.setRawValue(new Z([
			n,
			r,
			i,
			a
		], "hsv"), t);
	}
	onPointerDown_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerMove_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerUp_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !0,
			last: !0
		});
	}
	onKeyDown_(e) {
		let t = Y(Rs(!1), Go(e));
		if (t === 0) return;
		let [n, r, i, a] = this.value.rawValue.getComponents("hsv");
		this.value.setRawValue(new Z([
			n + t,
			r,
			i,
			a
		], "hsv"), {
			forceEmit: !1,
			last: !1
		});
	}
	onKeyUp_(e) {
		Y(Rs(!1), Go(e)) !== 0 && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
}, Kc = q("svp"), qc = 64, Jc = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), this.value = t.value, this.value.emitter.on("change", this.onValueChange_), this.element = e.createElement("div"), this.element.classList.add(Kc()), t.viewProps.bindClassModifiers(this.element), t.viewProps.bindTabIndex(this.element);
		let n = e.createElement("canvas");
		n.height = qc, n.width = qc, n.classList.add(Kc("c")), this.element.appendChild(n), this.canvasElement = n;
		let r = e.createElement("div");
		r.classList.add(Kc("m")), this.element.appendChild(r), this.markerElem_ = r, this.update_();
	}
	update_() {
		let e = Ri(this.canvasElement);
		if (!e) return;
		let t = this.value.rawValue.getComponents("hsv"), n = this.canvasElement.width, r = this.canvasElement.height, i = e.getImageData(0, 0, n, r), a = i.data;
		for (let e = 0; e < r; e++) for (let i = 0; i < n; i++) {
			let o = H(i, 0, n, 0, 100), s = H(e, 0, r, 100, 0), c = Cs(t[0], o, s), l = (e * n + i) * 4;
			a[l] = c[0], a[l + 1] = c[1], a[l + 2] = c[2], a[l + 3] = 255;
		}
		e.putImageData(i, 0, 0);
		let o = H(t[1], 0, 100, 0, 100);
		this.markerElem_.style.left = `${o}%`;
		let s = H(t[2], 0, 100, 100, 0);
		this.markerElem_.style.top = `${s}%`;
	}
	onValueChange_() {
		this.update_();
	}
}, Yc = class {
	constructor(e, t) {
		this.onKeyDown_ = this.onKeyDown_.bind(this), this.onKeyUp_ = this.onKeyUp_.bind(this), this.onPointerDown_ = this.onPointerDown_.bind(this), this.onPointerMove_ = this.onPointerMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.view = new Jc(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.ptHandler_ = new Yo(this.view.element), this.ptHandler_.emitter.on("down", this.onPointerDown_), this.ptHandler_.emitter.on("move", this.onPointerMove_), this.ptHandler_.emitter.on("up", this.onPointerUp_), this.view.element.addEventListener("keydown", this.onKeyDown_), this.view.element.addEventListener("keyup", this.onKeyUp_);
	}
	handlePointerEvent_(e, t) {
		if (!e.point) return;
		let n = H(e.point.x, 0, e.bounds.width, 0, 100), r = H(e.point.y, 0, e.bounds.height, 100, 0), [i, , , a] = this.value.rawValue.getComponents("hsv");
		this.value.setRawValue(new Z([
			i,
			n,
			r,
			a
		], "hsv"), t);
	}
	onPointerDown_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerMove_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerUp_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !0,
			last: !0
		});
	}
	onKeyDown_(e) {
		qo(e.key) && e.preventDefault();
		let [t, n, r, i] = this.value.rawValue.getComponents("hsv"), a = Rs(!1), o = Y(a, Go(e)), s = Y(a, Wo(e));
		(o !== 0 || s !== 0) && this.value.setRawValue(new Z([
			t,
			n + o,
			r + s,
			i
		], "hsv"), {
			forceEmit: !1,
			last: !1
		});
	}
	onKeyUp_(e) {
		let t = Rs(!1), n = Y(t, Go(e)), r = Y(t, Wo(e));
		(n !== 0 || r !== 0) && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
}, Xc = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.hPaletteC_ = new Gc(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.svPaletteC_ = new Yc(e, {
			value: this.value,
			viewProps: this.viewProps
		}), this.alphaIcs_ = t.supportsAlpha ? {
			palette: new Mc(e, {
				value: this.value,
				viewProps: this.viewProps
			}),
			text: new Zo(e, {
				parser: ni,
				props: B.fromObject({
					pointerScale: .01,
					keyScale: .1,
					formatter: V(2)
				}),
				value: z(0, { constraint: new xr({
					min: 0,
					max: 1
				}) }),
				viewProps: this.viewProps
			})
		} : null, this.alphaIcs_ && Uo({
			primary: this.value,
			secondary: this.alphaIcs_.text.value,
			forward: (e) => e.getComponents()[3],
			backward: (e, t) => {
				let n = e.getComponents();
				return n[3] = t, new Z(n, e.mode);
			}
		}), this.textsC_ = new Hc(e, {
			colorType: t.colorType,
			value: this.value,
			viewProps: this.viewProps
		}), this.view = new Fs(e, {
			alphaViews: this.alphaIcs_ ? {
				palette: this.alphaIcs_.palette.view,
				text: this.alphaIcs_.text.view
			} : null,
			hPaletteView: this.hPaletteC_.view,
			supportsAlpha: t.supportsAlpha,
			svPaletteView: this.svPaletteC_.view,
			textsView: this.textsC_.view,
			viewProps: this.viewProps
		});
	}
	get textsController() {
		return this.textsC_;
	}
}, Zc = q("colsw"), Qc = class {
	constructor(e, t) {
		this.onValueChange_ = this.onValueChange_.bind(this), t.value.emitter.on("change", this.onValueChange_), this.value = t.value, this.element = e.createElement("div"), this.element.classList.add(Zc()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Zc("sw")), this.element.appendChild(n), this.swatchElem_ = n;
		let r = e.createElement("button");
		r.classList.add(Zc("b")), t.viewProps.bindDisabled(r), this.element.appendChild(r), this.buttonElement = r, this.update_();
	}
	update_() {
		let e = this.value.rawValue;
		this.swatchElem_.style.backgroundColor = yc(e);
	}
	onValueChange_() {
		this.update_();
	}
}, $c = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.view = new Qc(e, {
			value: this.value,
			viewProps: this.viewProps
		});
	}
}, el = class {
	constructor(e, t) {
		this.onButtonBlur_ = this.onButtonBlur_.bind(this), this.onButtonClick_ = this.onButtonClick_.bind(this), this.onPopupChildBlur_ = this.onPopupChildBlur_.bind(this), this.onPopupChildKeydown_ = this.onPopupChildKeydown_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.foldable_ = Ua.create(t.expanded), this.swatchC_ = new $c(e, {
			value: this.value,
			viewProps: this.viewProps
		});
		let n = this.swatchC_.view.buttonElement;
		n.addEventListener("blur", this.onButtonBlur_), n.addEventListener("click", this.onButtonClick_), this.textC_ = new Po(e, {
			parser: t.parser,
			props: B.fromObject({ formatter: t.formatter }),
			value: this.value,
			viewProps: this.viewProps
		}), this.view = new ys(e, {
			foldable: this.foldable_,
			pickerLayout: t.pickerLayout
		}), this.view.swatchElement.appendChild(this.swatchC_.view.element), this.view.textElement.appendChild(this.textC_.view.element), this.popC_ = t.pickerLayout === "popup" ? new jo(e, { viewProps: this.viewProps }) : null;
		let r = new Xc(e, {
			colorType: t.colorType,
			supportsAlpha: t.supportsAlpha,
			value: this.value,
			viewProps: this.viewProps
		});
		r.view.allFocusableElements.forEach((e) => {
			e.addEventListener("blur", this.onPopupChildBlur_), e.addEventListener("keydown", this.onPopupChildKeydown_);
		}), this.pickerC_ = r, this.popC_ ? (this.view.element.appendChild(this.popC_.view.element), this.popC_.view.element.appendChild(r.view.element), Uo({
			primary: this.foldable_.value("expanded"),
			secondary: this.popC_.shows,
			forward: (e) => e,
			backward: (e, t) => t
		})) : this.view.pickerElement && (this.view.pickerElement.appendChild(this.pickerC_.view.element), Ka(this.foldable_, this.view.pickerElement));
	}
	get textController() {
		return this.textC_;
	}
	onButtonBlur_(e) {
		if (!this.popC_) return;
		let t = this.view.element, n = F(e.relatedTarget);
		n && t.contains(n) || (this.popC_.shows.rawValue = !1);
	}
	onButtonClick_() {
		this.foldable_.set("expanded", !this.foldable_.get("expanded")), this.foldable_.get("expanded") && this.pickerC_.view.allFocusableElements[0].focus();
	}
	onPopupChildBlur_(e) {
		if (!this.popC_) return;
		let t = this.popC_.view.element, n = Gi(e);
		n && t.contains(n) || (!n || n !== this.swatchC_.view.buttonElement || Fi(t.ownerDocument)) && (this.popC_.shows.rawValue = !1);
	}
	onPopupChildKeydown_(e) {
		this.popC_ ? e.key === "Escape" && (this.popC_.shows.rawValue = !1) : this.view.pickerElement && e.key === "Escape" && this.swatchC_.view.buttonElement.focus();
	}
};
function tl(e) {
	return Es(e.getComponents("rgb")).reduce((e, t) => e << 8 | Math.floor(t) & 255, 0);
}
function nl(e) {
	return e.getComponents("rgb").reduce((e, t, n) => {
		let r = Math.floor(n === 3 ? t * 255 : t) & 255;
		return e << 8 | r;
	}, 0) >>> 0;
}
function rl(e) {
	return new Z([
		e >> 16 & 255,
		e >> 8 & 255,
		e & 255
	], "rgb");
}
function il(e) {
	return new Z([
		e >> 24 & 255,
		e >> 16 & 255,
		e >> 8 & 255,
		H(e & 255, 0, 255, 0, 1)
	], "rgb");
}
function al(e) {
	return typeof e == "number" ? rl(e) : Z.black();
}
function ol(e) {
	return typeof e == "number" ? il(e) : Z.black();
}
function sl(e, t) {
	return typeof e != "object" || I(e) ? !1 : t in e && typeof e[t] == "number";
}
function cl(e) {
	return sl(e, "r") && sl(e, "g") && sl(e, "b");
}
function ll(e) {
	return cl(e) && sl(e, "a");
}
function ul(e) {
	return cl(e);
}
function dl(e, t) {
	if (e.mode !== t.mode || e.type !== t.type) return !1;
	let n = e.getComponents(), r = t.getComponents();
	for (let e = 0; e < n.length; e++) if (n[e] !== r[e]) return !1;
	return !0;
}
function fl(e) {
	return "a" in e ? [
		e.r,
		e.g,
		e.b,
		e.a
	] : [
		e.r,
		e.g,
		e.b
	];
}
function pl(e) {
	let t = kc(e);
	return t ? (e, n) => {
		fs(e, t(n));
	} : null;
}
function ml(e) {
	let t = e ? nl : tl;
	return (e, n) => {
		fs(e, t(n));
	};
}
function hl(e, t, n) {
	let r = Q(t, n).toRgbaObject();
	e.writeProperty("r", r.r), e.writeProperty("g", r.g), e.writeProperty("b", r.b), e.writeProperty("a", r.a);
}
function gl(e, t, n) {
	let r = Q(t, n).toRgbaObject();
	e.writeProperty("r", r.r), e.writeProperty("g", r.g), e.writeProperty("b", r.b);
}
function _l(e, t) {
	return (n, r) => {
		e ? hl(n, r, t) : gl(n, r, t);
	};
}
function vl(e) {
	return !!e?.color?.alpha;
}
function yl(e) {
	return e ? (e) => yc(e, "0x") : (e) => vc(e, "0x");
}
function bl(e) {
	return "color" in e || e.view === "color";
}
var xl = J({
	id: "input-color-number",
	type: "input",
	accept: (e, t) => {
		if (typeof e != "number" || !bl(t)) return null;
		let n = Ls(t);
		return n ? {
			initialValue: e,
			params: Object.assign(Object.assign({}, n), { supportsAlpha: vl(t) })
		} : null;
	},
	binding: {
		reader: (e) => e.params.supportsAlpha ? ol : al,
		equals: dl,
		writer: (e) => ml(e.params.supportsAlpha)
	},
	controller: (e) => new el(e.document, {
		colorType: "int",
		expanded: e.params.expanded ?? !1,
		formatter: yl(e.params.supportsAlpha),
		parser: hc("int"),
		pickerLayout: e.params.picker ?? "popup",
		supportsAlpha: e.params.supportsAlpha,
		value: e.value,
		viewProps: e.viewProps
	})
});
function Sl(e, t) {
	return ul(e) ? t === "int" ? new Z(fl(e), "rgb") : t === "float" ? new Bs(fl(e), "rgb") : Q(Z.black(), "int") : Q(Z.black(), t);
}
function Cl(e) {
	return ll(e);
}
function wl(e) {
	return (t) => Q(Sl(t, e), "int");
}
function Tl(e, t) {
	return (n) => e ? Ec(n, t) : wc(n, t);
}
var El = J({
	id: "input-color-object",
	type: "input",
	accept: (e, t) => {
		if (!ul(e)) return null;
		let n = Ls(t);
		return n ? {
			initialValue: e,
			params: Object.assign(Object.assign({}, n), { colorType: zs(t) ?? "int" })
		} : null;
	},
	binding: {
		reader: (e) => wl(e.params.colorType),
		equals: dl,
		writer: (e) => _l(Cl(e.initialValue), e.params.colorType)
	},
	controller: (e) => {
		let t = ll(e.initialValue);
		return new el(e.document, {
			colorType: e.params.colorType,
			expanded: e.params.expanded ?? !1,
			formatter: Tl(t, e.params.colorType),
			parser: hc("int"),
			pickerLayout: e.params.picker ?? "popup",
			supportsAlpha: t,
			value: e.value,
			viewProps: e.viewProps
		});
	}
}), Dl = J({
	id: "input-color-string",
	type: "input",
	accept: (e, t) => {
		if (typeof e != "string" || t.view === "text") return null;
		let n = mc(e, zs(t));
		if (!n) return null;
		let r = kc(n);
		if (!r) return null;
		let i = Ls(t);
		return i ? {
			initialValue: e,
			params: Object.assign(Object.assign({}, i), {
				format: n,
				stringifier: r
			})
		} : null;
	},
	binding: {
		reader: () => gc,
		equals: dl,
		writer: (e) => {
			let t = pl(e.params.format);
			if (!t) throw L.notBindable();
			return t;
		}
	},
	controller: (e) => new el(e.document, {
		colorType: e.params.format.type,
		expanded: e.params.expanded ?? !1,
		formatter: e.params.stringifier,
		parser: hc("int"),
		pickerLayout: e.params.picker ?? "popup",
		supportsAlpha: e.params.format.alpha,
		value: e.value,
		viewProps: e.viewProps
	})
}), Ol = class {
	constructor(e) {
		this.components = e.components, this.asm_ = e.assembly;
	}
	constrain(e) {
		let t = this.asm_.toComponents(e).map((e, t) => this.components[t]?.constrain(e) ?? e);
		return this.asm_.fromComponents(t);
	}
}, kl = q("pndtxt"), Al = class {
	constructor(e, t) {
		this.textViews = t.textViews, this.element = e.createElement("div"), this.element.classList.add(kl()), this.textViews.forEach((t) => {
			let n = e.createElement("div");
			n.classList.add(kl("a")), n.appendChild(t.element), this.element.appendChild(n);
		});
	}
};
function jl(e, t, n) {
	return new Zo(e, {
		arrayPosition: n === 0 ? "fst" : n === t.axes.length - 1 ? "lst" : "mid",
		parser: t.parser,
		props: t.axes[n].textProps,
		value: z(0, { constraint: t.axes[n].constraint }),
		viewProps: t.viewProps
	});
}
var Ml = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.acs_ = t.axes.map((n, r) => jl(e, t, r)), this.acs_.forEach((e, n) => {
			Uo({
				primary: this.value,
				secondary: e.value,
				forward: (e) => t.assembly.toComponents(e)[n],
				backward: (e, r) => {
					let i = t.assembly.toComponents(e);
					return i[n] = r, t.assembly.fromComponents(i);
				}
			});
		}), this.view = new Al(e, { textViews: this.acs_.map((e) => e.view) });
	}
	get textControllers() {
		return this.acs_;
	}
}, Nl = class extends xi {
	get max() {
		return this.controller.valueController.sliderController.props.get("max");
	}
	set max(e) {
		this.controller.valueController.sliderController.props.set("max", e);
	}
	get min() {
		return this.controller.valueController.sliderController.props.get("min");
	}
	set min(e) {
		this.controller.valueController.sliderController.props.set("min", e);
	}
};
function Pl(e, t) {
	let n = [], r = ui(e, t);
	r && n.push(r);
	let i = di(e);
	i && n.push(i);
	let a = To(e.options);
	return a && n.push(a), new bo(n);
}
var Fl = J({
	id: "input-number",
	type: "input",
	accept: (e, t) => {
		if (typeof e != "number") return null;
		let n = W(t, (e) => Object.assign(Object.assign({}, pi(e)), {
			options: e.optional.custom(Co),
			readonly: e.optional.constant(!1)
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: (e) => ri,
		constraint: (e) => Pl(e.params, e.initialValue),
		writer: (e) => fs
	},
	controller: (e) => {
		let t = e.value, n = e.constraint, r = n && xo(n, So);
		if (r) return new Oo(e.document, {
			props: new B({ options: r.values.value("options") }),
			value: t,
			viewProps: e.viewProps
		});
		let i = fi(e.params, t.rawValue), a = n && xo(n, xr);
		return a ? new rs(e.document, Object.assign(Object.assign({}, is(Object.assign(Object.assign({}, i), {
			keyScale: z(i.keyScale),
			max: a.values.value("max"),
			min: a.values.value("min")
		}))), {
			parser: ni,
			value: t,
			viewProps: e.viewProps
		})) : new Zo(e.document, {
			parser: ni,
			props: B.fromObject(i),
			value: t,
			viewProps: e.viewProps
		});
	},
	api(e) {
		return typeof e.controller.value.rawValue == "number" ? e.controller.valueController instanceof rs ? new Nl(e.controller) : e.controller.valueController instanceof Oo ? new _o(e.controller) : null : null;
	}
}), Il = class {
	constructor(e = 0, t = 0) {
		this.x = e, this.y = t;
	}
	getComponents() {
		return [this.x, this.y];
	}
	static isObject(e) {
		if (I(e)) return !1;
		let t = e.x, n = e.y;
		return typeof t == "number" && typeof n == "number";
	}
	static equals(e, t) {
		return e.x === t.x && e.y === t.y;
	}
	toObject() {
		return {
			x: this.x,
			y: this.y
		};
	}
}, Ll = {
	toComponents: (e) => e.getComponents(),
	fromComponents: (e) => new Il(...e)
}, Rl = q("p2d"), zl = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(Rl()), t.viewProps.bindClassModifiers(this.element), Ki(t.expanded, ya(this.element, Rl(void 0, "expanded")));
		let n = e.createElement("div");
		n.classList.add(Rl("h")), this.element.appendChild(n);
		let r = e.createElement("button");
		r.classList.add(Rl("b")), r.appendChild(Bi(e, "p2dpad")), t.viewProps.bindDisabled(r), n.appendChild(r), this.buttonElement = r;
		let i = e.createElement("div");
		if (i.classList.add(Rl("t")), n.appendChild(i), this.textElement = i, t.pickerLayout === "inline") {
			let t = e.createElement("div");
			t.classList.add(Rl("p")), this.element.appendChild(t), this.pickerElement = t;
		} else this.pickerElement = null;
	}
}, Bl = q("p2dp"), Vl = class {
	constructor(e, t) {
		this.onFoldableChange_ = this.onFoldableChange_.bind(this), this.onPropsChange_ = this.onPropsChange_.bind(this), this.onValueChange_ = this.onValueChange_.bind(this), this.props_ = t.props, this.props_.emitter.on("change", this.onPropsChange_), this.element = e.createElement("div"), this.element.classList.add(Bl()), t.layout === "popup" && this.element.classList.add(Bl(void 0, "p")), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("div");
		n.classList.add(Bl("p")), t.viewProps.bindTabIndex(n), this.element.appendChild(n), this.padElement = n;
		let r = e.createElementNS(Mi, "svg");
		r.classList.add(Bl("g")), this.padElement.appendChild(r), this.svgElem_ = r;
		let i = e.createElementNS(Mi, "line");
		i.classList.add(Bl("ax")), i.setAttributeNS(null, "x1", "0"), i.setAttributeNS(null, "y1", "50%"), i.setAttributeNS(null, "x2", "100%"), i.setAttributeNS(null, "y2", "50%"), this.svgElem_.appendChild(i);
		let a = e.createElementNS(Mi, "line");
		a.classList.add(Bl("ax")), a.setAttributeNS(null, "x1", "50%"), a.setAttributeNS(null, "y1", "0"), a.setAttributeNS(null, "x2", "50%"), a.setAttributeNS(null, "y2", "100%"), this.svgElem_.appendChild(a);
		let o = e.createElementNS(Mi, "line");
		o.classList.add(Bl("l")), o.setAttributeNS(null, "x1", "50%"), o.setAttributeNS(null, "y1", "50%"), this.svgElem_.appendChild(o), this.lineElem_ = o;
		let s = e.createElement("div");
		s.classList.add(Bl("m")), this.padElement.appendChild(s), this.markerElem_ = s, t.value.emitter.on("change", this.onValueChange_), this.value = t.value, this.update_();
	}
	get allFocusableElements() {
		return [this.padElement];
	}
	update_() {
		let [e, t] = this.value.rawValue.getComponents(), n = this.props_.get("max"), r = H(e, -n, +n, 0, 100), i = H(t, -n, +n, 0, 100), a = this.props_.get("invertsY") ? 100 - i : i;
		this.lineElem_.setAttributeNS(null, "x2", `${r}%`), this.lineElem_.setAttributeNS(null, "y2", `${a}%`), this.markerElem_.style.left = `${r}%`, this.markerElem_.style.top = `${a}%`;
	}
	onValueChange_() {
		this.update_();
	}
	onPropsChange_() {
		this.update_();
	}
	onFoldableChange_() {
		this.update_();
	}
};
function Hl(e, t, n) {
	return [Y(t[0], Go(e)), Y(t[1], Wo(e)) * (n ? 1 : -1)];
}
var Ul = class {
	constructor(e, t) {
		this.onPadKeyDown_ = this.onPadKeyDown_.bind(this), this.onPadKeyUp_ = this.onPadKeyUp_.bind(this), this.onPointerDown_ = this.onPointerDown_.bind(this), this.onPointerMove_ = this.onPointerMove_.bind(this), this.onPointerUp_ = this.onPointerUp_.bind(this), this.props = t.props, this.value = t.value, this.viewProps = t.viewProps, this.view = new Vl(e, {
			layout: t.layout,
			props: this.props,
			value: this.value,
			viewProps: this.viewProps
		}), this.ptHandler_ = new Yo(this.view.padElement), this.ptHandler_.emitter.on("down", this.onPointerDown_), this.ptHandler_.emitter.on("move", this.onPointerMove_), this.ptHandler_.emitter.on("up", this.onPointerUp_), this.view.padElement.addEventListener("keydown", this.onPadKeyDown_), this.view.padElement.addEventListener("keyup", this.onPadKeyUp_);
	}
	handlePointerEvent_(e, t) {
		if (!e.point) return;
		let n = this.props.get("max"), r = H(e.point.x, 0, e.bounds.width, -n, +n), i = H(this.props.get("invertsY") ? e.bounds.height - e.point.y : e.point.y, 0, e.bounds.height, -n, +n);
		this.value.setRawValue(new Il(r, i), t);
	}
	onPointerDown_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerMove_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !1,
			last: !1
		});
	}
	onPointerUp_(e) {
		this.handlePointerEvent_(e.data, {
			forceEmit: !0,
			last: !0
		});
	}
	onPadKeyDown_(e) {
		qo(e.key) && e.preventDefault();
		let [t, n] = Hl(e, [this.props.get("xKeyScale"), this.props.get("yKeyScale")], this.props.get("invertsY"));
		(t !== 0 || n !== 0) && this.value.setRawValue(new Il(this.value.rawValue.x + t, this.value.rawValue.y + n), {
			forceEmit: !1,
			last: !1
		});
	}
	onPadKeyUp_(e) {
		let [t, n] = Hl(e, [this.props.get("xKeyScale"), this.props.get("yKeyScale")], this.props.get("invertsY"));
		(t !== 0 || n !== 0) && this.value.setRawValue(this.value.rawValue, {
			forceEmit: !0,
			last: !0
		});
	}
}, Wl = class {
	constructor(e, t) {
		var n, r;
		this.onPopupChildBlur_ = this.onPopupChildBlur_.bind(this), this.onPopupChildKeydown_ = this.onPopupChildKeydown_.bind(this), this.onPadButtonBlur_ = this.onPadButtonBlur_.bind(this), this.onPadButtonClick_ = this.onPadButtonClick_.bind(this), this.value = t.value, this.viewProps = t.viewProps, this.foldable_ = Ua.create(t.expanded), this.popC_ = t.pickerLayout === "popup" ? new jo(e, { viewProps: this.viewProps }) : null;
		let i = new Ul(e, {
			layout: t.pickerLayout,
			props: new B({
				invertsY: z(t.invertsY),
				max: z(t.max),
				xKeyScale: t.axes[0].textProps.value("keyScale"),
				yKeyScale: t.axes[1].textProps.value("keyScale")
			}),
			value: this.value,
			viewProps: this.viewProps
		});
		i.view.allFocusableElements.forEach((e) => {
			e.addEventListener("blur", this.onPopupChildBlur_), e.addEventListener("keydown", this.onPopupChildKeydown_);
		}), this.pickerC_ = i, this.textC_ = new Ml(e, {
			assembly: Ll,
			axes: t.axes,
			parser: t.parser,
			value: this.value,
			viewProps: this.viewProps
		}), this.view = new zl(e, {
			expanded: this.foldable_.value("expanded"),
			pickerLayout: t.pickerLayout,
			viewProps: this.viewProps
		}), this.view.textElement.appendChild(this.textC_.view.element), (n = this.view.buttonElement) == null || n.addEventListener("blur", this.onPadButtonBlur_), (r = this.view.buttonElement) == null || r.addEventListener("click", this.onPadButtonClick_), this.popC_ ? (this.view.element.appendChild(this.popC_.view.element), this.popC_.view.element.appendChild(this.pickerC_.view.element), Uo({
			primary: this.foldable_.value("expanded"),
			secondary: this.popC_.shows,
			forward: (e) => e,
			backward: (e, t) => t
		})) : this.view.pickerElement && (this.view.pickerElement.appendChild(this.pickerC_.view.element), Ka(this.foldable_, this.view.pickerElement));
	}
	get textController() {
		return this.textC_;
	}
	onPadButtonBlur_(e) {
		if (!this.popC_) return;
		let t = this.view.element, n = F(e.relatedTarget);
		n && t.contains(n) || (this.popC_.shows.rawValue = !1);
	}
	onPadButtonClick_() {
		this.foldable_.set("expanded", !this.foldable_.get("expanded")), this.foldable_.get("expanded") && this.pickerC_.view.allFocusableElements[0].focus();
	}
	onPopupChildBlur_(e) {
		if (!this.popC_) return;
		let t = this.popC_.view.element, n = Gi(e);
		n && t.contains(n) || (!n || n !== this.view.buttonElement || Fi(t.ownerDocument)) && (this.popC_.shows.rawValue = !1);
	}
	onPopupChildKeydown_(e) {
		this.popC_ ? e.key === "Escape" && (this.popC_.shows.rawValue = !1) : this.view.pickerElement && e.key === "Escape" && this.view.buttonElement.focus();
	}
};
function Gl(e) {
	return Il.isObject(e) ? new Il(e.x, e.y) : new Il();
}
function Kl(e, t) {
	e.writeProperty("x", t.x), e.writeProperty("y", t.y);
}
function ql(e, t) {
	return new Ol({
		assembly: Ll,
		components: [ls(Object.assign(Object.assign({}, e), e.x), t.x), ls(Object.assign(Object.assign({}, e), e.y), t.y)]
	});
}
function Jl(e, t) {
	if (!I(e.min) || !I(e.max)) return Math.max(Math.abs(e.min ?? 0), Math.abs(e.max ?? 0));
	let n = ci(e);
	return Math.max(Math.abs(n) * 10, Math.abs(t) * 10);
}
function Yl(e, t) {
	let n = Jl(pr(e, e.x ?? {}), t.x), r = Jl(pr(e, e.y ?? {}), t.y);
	return Math.max(n, r);
}
function Xl(e) {
	if (!("y" in e)) return !1;
	let t = e.y;
	return t ? "inverted" in t && !!t.inverted : !1;
}
var Zl = J({
	id: "input-point2d",
	type: "input",
	accept: (e, t) => {
		if (!Il.isObject(e)) return null;
		let n = W(t, (e) => Object.assign(Object.assign({}, ss(e)), {
			expanded: e.optional.boolean,
			picker: e.optional.custom(ds),
			readonly: e.optional.constant(!1),
			x: e.optional.custom(cs),
			y: e.optional.object(Object.assign(Object.assign({}, ss(e)), { inverted: e.optional.boolean }))
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: () => Gl,
		constraint: (e) => ql(e.params, e.initialValue),
		equals: Il.equals,
		writer: () => Kl
	},
	controller: (e) => {
		let t = e.document, n = e.value, r = e.constraint, i = [e.params.x, e.params.y];
		return new Wl(t, {
			axes: n.rawValue.getComponents().map((t, n) => mi({
				constraint: r.components[n],
				initialValue: t,
				params: pr(e.params, i[n] ?? {})
			})),
			expanded: e.params.expanded ?? !1,
			invertsY: Xl(e.params),
			max: Yl(e.params, n.rawValue),
			parser: ni,
			pickerLayout: e.params.picker ?? "popup",
			value: n,
			viewProps: e.viewProps
		});
	}
}), Ql = class {
	constructor(e = 0, t = 0, n = 0) {
		this.x = e, this.y = t, this.z = n;
	}
	getComponents() {
		return [
			this.x,
			this.y,
			this.z
		];
	}
	static isObject(e) {
		if (I(e)) return !1;
		let t = e.x, n = e.y, r = e.z;
		return typeof t == "number" && typeof n == "number" && typeof r == "number";
	}
	static equals(e, t) {
		return e.x === t.x && e.y === t.y && e.z === t.z;
	}
	toObject() {
		return {
			x: this.x,
			y: this.y,
			z: this.z
		};
	}
}, $l = {
	toComponents: (e) => e.getComponents(),
	fromComponents: (e) => new Ql(...e)
};
function eu(e) {
	return Ql.isObject(e) ? new Ql(e.x, e.y, e.z) : new Ql();
}
function tu(e, t) {
	e.writeProperty("x", t.x), e.writeProperty("y", t.y), e.writeProperty("z", t.z);
}
function nu(e, t) {
	return new Ol({
		assembly: $l,
		components: [
			ls(Object.assign(Object.assign({}, e), e.x), t.x),
			ls(Object.assign(Object.assign({}, e), e.y), t.y),
			ls(Object.assign(Object.assign({}, e), e.z), t.z)
		]
	});
}
var ru = J({
	id: "input-point3d",
	type: "input",
	accept: (e, t) => {
		if (!Ql.isObject(e)) return null;
		let n = W(t, (e) => Object.assign(Object.assign({}, ss(e)), {
			readonly: e.optional.constant(!1),
			x: e.optional.custom(cs),
			y: e.optional.custom(cs),
			z: e.optional.custom(cs)
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: (e) => eu,
		constraint: (e) => nu(e.params, e.initialValue),
		equals: Ql.equals,
		writer: (e) => tu
	},
	controller: (e) => {
		let t = e.value, n = e.constraint, r = [
			e.params.x,
			e.params.y,
			e.params.z
		];
		return new Ml(e.document, {
			assembly: $l,
			axes: t.rawValue.getComponents().map((t, i) => mi({
				constraint: n.components[i],
				initialValue: t,
				params: pr(e.params, r[i] ?? {})
			})),
			parser: ni,
			value: t,
			viewProps: e.viewProps
		});
	}
}), iu = class {
	constructor(e = 0, t = 0, n = 0, r = 0) {
		this.x = e, this.y = t, this.z = n, this.w = r;
	}
	getComponents() {
		return [
			this.x,
			this.y,
			this.z,
			this.w
		];
	}
	static isObject(e) {
		if (I(e)) return !1;
		let t = e.x, n = e.y, r = e.z, i = e.w;
		return typeof t == "number" && typeof n == "number" && typeof r == "number" && typeof i == "number";
	}
	static equals(e, t) {
		return e.x === t.x && e.y === t.y && e.z === t.z && e.w === t.w;
	}
	toObject() {
		return {
			x: this.x,
			y: this.y,
			z: this.z,
			w: this.w
		};
	}
}, au = {
	toComponents: (e) => e.getComponents(),
	fromComponents: (e) => new iu(...e)
};
function ou(e) {
	return iu.isObject(e) ? new iu(e.x, e.y, e.z, e.w) : new iu();
}
function su(e, t) {
	e.writeProperty("x", t.x), e.writeProperty("y", t.y), e.writeProperty("z", t.z), e.writeProperty("w", t.w);
}
function cu(e, t) {
	return new Ol({
		assembly: au,
		components: [
			ls(Object.assign(Object.assign({}, e), e.x), t.x),
			ls(Object.assign(Object.assign({}, e), e.y), t.y),
			ls(Object.assign(Object.assign({}, e), e.z), t.z),
			ls(Object.assign(Object.assign({}, e), e.w), t.w)
		]
	});
}
var lu = J({
	id: "input-point4d",
	type: "input",
	accept: (e, t) => {
		if (!iu.isObject(e)) return null;
		let n = W(t, (e) => Object.assign(Object.assign({}, ss(e)), {
			readonly: e.optional.constant(!1),
			w: e.optional.custom(cs),
			x: e.optional.custom(cs),
			y: e.optional.custom(cs),
			z: e.optional.custom(cs)
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: (e) => ou,
		constraint: (e) => cu(e.params, e.initialValue),
		equals: iu.equals,
		writer: (e) => su
	},
	controller: (e) => {
		let t = e.value, n = e.constraint, r = [
			e.params.x,
			e.params.y,
			e.params.z,
			e.params.w
		];
		return new Ml(e.document, {
			assembly: au,
			axes: t.rawValue.getComponents().map((t, i) => mi({
				constraint: n.components[i],
				initialValue: t,
				params: pr(e.params, r[i] ?? {})
			})),
			parser: ni,
			value: t,
			viewProps: e.viewProps
		});
	}
});
function uu(e) {
	let t = [], n = To(e.options);
	return n && t.push(n), new bo(t);
}
var du = J({
	id: "input-string",
	type: "input",
	accept: (e, t) => {
		if (typeof e != "string") return null;
		let n = W(t, (e) => ({
			readonly: e.optional.constant(!1),
			options: e.optional.custom(Co)
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		reader: (e) => Vo,
		constraint: (e) => uu(e.params),
		writer: (e) => fs
	},
	controller: (e) => {
		let t = e.document, n = e.value, r = e.constraint, i = r && xo(r, So);
		return i ? new Oo(t, {
			props: new B({ options: i.values.value("options") }),
			value: n,
			viewProps: e.viewProps
		}) : new Po(t, {
			parser: (e) => e,
			props: B.fromObject({ formatter: Ho }),
			value: n,
			viewProps: e.viewProps
		});
	},
	api(e) {
		return typeof e.controller.value.rawValue == "string" && e.controller.valueController instanceof Oo ? new _o(e.controller) : null;
	}
}), fu = { monitor: {
	defaultInterval: 200,
	defaultRows: 3
} }, pu = q("mll"), mu = class {
	constructor(e, t) {
		this.onValueUpdate_ = this.onValueUpdate_.bind(this), this.formatter_ = t.formatter, this.element = e.createElement("div"), this.element.classList.add(pu()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("textarea");
		n.classList.add(pu("i")), n.style.height = `calc(var(${os("containerUnitSize")}) * ${t.rows})`, n.readOnly = !0, t.viewProps.bindDisabled(n), this.element.appendChild(n), this.textareaElem_ = n, t.value.emitter.on("change", this.onValueUpdate_), this.value = t.value, this.update_();
	}
	update_() {
		let e = this.textareaElem_, t = e.scrollTop === e.scrollHeight - e.clientHeight, n = [];
		this.value.rawValue.forEach((e) => {
			e !== void 0 && n.push(this.formatter_(e));
		}), e.textContent = n.join("\n"), t && (e.scrollTop = e.scrollHeight);
	}
	onValueUpdate_() {
		this.update_();
	}
}, hu = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.view = new mu(e, {
			formatter: t.formatter,
			rows: t.rows,
			value: this.value,
			viewProps: this.viewProps
		});
	}
}, gu = q("sgl"), _u = class {
	constructor(e, t) {
		this.onValueUpdate_ = this.onValueUpdate_.bind(this), this.formatter_ = t.formatter, this.element = e.createElement("div"), this.element.classList.add(gu()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("input");
		n.classList.add(gu("i")), n.readOnly = !0, n.type = "text", t.viewProps.bindDisabled(n), this.element.appendChild(n), this.inputElement = n, t.value.emitter.on("change", this.onValueUpdate_), this.value = t.value, this.update_();
	}
	update_() {
		let e = this.value.rawValue, t = e[e.length - 1];
		this.inputElement.value = t === void 0 ? "" : this.formatter_(t);
	}
	onValueUpdate_() {
		this.update_();
	}
}, vu = class {
	constructor(e, t) {
		this.value = t.value, this.viewProps = t.viewProps, this.view = new _u(e, {
			formatter: t.formatter,
			value: this.value,
			viewProps: this.viewProps
		});
	}
}, yu = J({
	id: "monitor-bool",
	type: "monitor",
	accept: (e, t) => {
		if (typeof e != "boolean") return null;
		let n = W(t, (e) => ({
			readonly: e.required.constant(!0),
			rows: e.optional.number
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: { reader: (e) => Io },
	controller: (e) => e.value.rawValue.length === 1 ? new vu(e.document, {
		formatter: Lo,
		value: e.value,
		viewProps: e.viewProps
	}) : new hu(e.document, {
		formatter: Lo,
		rows: e.params.rows ?? fu.monitor.defaultRows,
		value: e.value,
		viewProps: e.viewProps
	})
}), bu = class extends xi {
	get max() {
		return this.controller.valueController.props.get("max");
	}
	set max(e) {
		this.controller.valueController.props.set("max", e);
	}
	get min() {
		return this.controller.valueController.props.get("min");
	}
	set min(e) {
		this.controller.valueController.props.set("min", e);
	}
}, xu = q("grl"), Su = class {
	constructor(e, t) {
		this.onCursorChange_ = this.onCursorChange_.bind(this), this.onValueUpdate_ = this.onValueUpdate_.bind(this), this.element = e.createElement("div"), this.element.classList.add(xu()), t.viewProps.bindClassModifiers(this.element), this.formatter_ = t.formatter, this.props_ = t.props, this.cursor_ = t.cursor, this.cursor_.emitter.on("change", this.onCursorChange_);
		let n = e.createElementNS(Mi, "svg");
		n.classList.add(xu("g")), n.style.height = `calc(var(${os("containerUnitSize")}) * ${t.rows})`, this.element.appendChild(n), this.svgElem_ = n;
		let r = e.createElementNS(Mi, "polyline");
		this.svgElem_.appendChild(r), this.lineElem_ = r;
		let i = e.createElement("div");
		i.classList.add(xu("t"), q("tt")()), this.element.appendChild(i), this.tooltipElem_ = i, t.value.emitter.on("change", this.onValueUpdate_), this.value = t.value, this.update_();
	}
	get graphElement() {
		return this.svgElem_;
	}
	update_() {
		let { clientWidth: e, clientHeight: t } = this.element, n = this.value.rawValue.length - 1, r = this.props_.get("min"), i = this.props_.get("max"), a = [];
		this.value.rawValue.forEach((o, s) => {
			if (o === void 0) return;
			let c = H(s, 0, n, 0, e), l = H(o, r, i, t, 0);
			a.push([c, l].join(","));
		}), this.lineElem_.setAttributeNS(null, "points", a.join(" "));
		let o = this.tooltipElem_, s = this.value.rawValue[this.cursor_.rawValue];
		if (s === void 0) {
			o.classList.remove(xu("t", "a"));
			return;
		}
		let c = H(this.cursor_.rawValue, 0, n, 0, e), l = H(s, r, i, t, 0);
		o.style.left = `${c}px`, o.style.top = `${l}px`, o.textContent = `${this.formatter_(s)}`, o.classList.contains(xu("t", "a")) || (o.classList.add(xu("t", "a"), xu("t", "in")), Ni(o), o.classList.remove(xu("t", "in")));
	}
	onValueUpdate_() {
		this.update_();
	}
	onCursorChange_() {
		this.update_();
	}
}, Cu = class {
	constructor(e, t) {
		if (this.onGraphMouseMove_ = this.onGraphMouseMove_.bind(this), this.onGraphMouseLeave_ = this.onGraphMouseLeave_.bind(this), this.onGraphPointerDown_ = this.onGraphPointerDown_.bind(this), this.onGraphPointerMove_ = this.onGraphPointerMove_.bind(this), this.onGraphPointerUp_ = this.onGraphPointerUp_.bind(this), this.props = t.props, this.value = t.value, this.viewProps = t.viewProps, this.cursor_ = z(-1), this.view = new Su(e, {
			cursor: this.cursor_,
			formatter: t.formatter,
			rows: t.rows,
			props: this.props,
			value: this.value,
			viewProps: this.viewProps
		}), !Fi(e)) this.view.element.addEventListener("mousemove", this.onGraphMouseMove_), this.view.element.addEventListener("mouseleave", this.onGraphMouseLeave_);
		else {
			let e = new Yo(this.view.element);
			e.emitter.on("down", this.onGraphPointerDown_), e.emitter.on("move", this.onGraphPointerMove_), e.emitter.on("up", this.onGraphPointerUp_);
		}
	}
	importProps(e) {
		return G(e, null, (e) => ({
			max: e.required.number,
			min: e.required.number
		}), (e) => (this.props.set("max", e.max), this.props.set("min", e.min), !0));
	}
	exportProps() {
		return K(null, {
			max: this.props.get("max"),
			min: this.props.get("min")
		});
	}
	onGraphMouseLeave_() {
		this.cursor_.rawValue = -1;
	}
	onGraphMouseMove_(e) {
		let { clientWidth: t } = this.view.element;
		this.cursor_.rawValue = Math.floor(H(e.offsetX, 0, t, 0, this.value.rawValue.length));
	}
	onGraphPointerDown_(e) {
		this.onGraphPointerMove_(e);
	}
	onGraphPointerMove_(e) {
		e.data.point ? this.cursor_.rawValue = Math.floor(H(e.data.point.x, 0, e.data.bounds.width, 0, this.value.rawValue.length)) : this.cursor_.rawValue = -1;
	}
	onGraphPointerUp_() {
		this.cursor_.rawValue = -1;
	}
};
function wu(e) {
	return I(e.format) ? V(2) : e.format;
}
function Tu(e) {
	return e.value.rawValue.length === 1 ? new vu(e.document, {
		formatter: wu(e.params),
		value: e.value,
		viewProps: e.viewProps
	}) : new hu(e.document, {
		formatter: wu(e.params),
		rows: e.params.rows ?? fu.monitor.defaultRows,
		value: e.value,
		viewProps: e.viewProps
	});
}
function Eu(e) {
	return new Cu(e.document, {
		formatter: wu(e.params),
		rows: e.params.rows ?? fu.monitor.defaultRows,
		props: B.fromObject({
			max: e.params.max ?? 100,
			min: e.params.min ?? 0
		}),
		value: e.value,
		viewProps: e.viewProps
	});
}
function Du(e) {
	return e.view === "graph";
}
var Ou = J({
	id: "monitor-number",
	type: "monitor",
	accept: (e, t) => {
		if (typeof e != "number") return null;
		let n = W(t, (e) => ({
			format: e.optional.function,
			max: e.optional.number,
			min: e.optional.number,
			readonly: e.required.constant(!0),
			rows: e.optional.number,
			view: e.optional.string
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: {
		defaultBufferSize: (e) => Du(e) ? 64 : 1,
		reader: (e) => ri
	},
	controller: (e) => Du(e.params) ? Eu(e) : Tu(e),
	api: (e) => e.controller.valueController instanceof Cu ? new bu(e.controller) : null
}), ku = J({
	id: "monitor-string",
	type: "monitor",
	accept: (e, t) => {
		if (typeof e != "string") return null;
		let n = W(t, (e) => ({
			multiline: e.optional.boolean,
			readonly: e.required.constant(!0),
			rows: e.optional.number
		}));
		return n ? {
			initialValue: e,
			params: n
		} : null;
	},
	binding: { reader: (e) => Vo },
	controller: (e) => {
		let t = e.value;
		return t.rawValue.length > 1 || e.params.multiline ? new hu(e.document, {
			formatter: Ho,
			rows: e.params.rows ?? fu.monitor.defaultRows,
			value: t,
			viewProps: e.viewProps
		}) : new vu(e.document, {
			formatter: Ho,
			value: t,
			viewProps: e.viewProps
		});
	}
}), Au = class {
	constructor() {
		this.map_ = /* @__PURE__ */ new Map();
	}
	get(e) {
		return this.map_.get(e) ?? null;
	}
	has(e) {
		return this.map_.has(e);
	}
	add(e, t) {
		return this.map_.set(e, t), e.viewProps.handleDispose(() => {
			this.map_.delete(e);
		}), t;
	}
}, ju = class {
	constructor(e) {
		this.target = e.target, this.reader_ = e.reader, this.writer_ = e.writer;
	}
	read() {
		return this.reader_(this.target.read());
	}
	write(e) {
		this.writer_(this.target, e);
	}
	inject(e) {
		this.write(this.reader_(e));
	}
};
function Mu(e, t) {
	let n = e.accept(t.target.read(), t.params);
	if (I(n)) return null;
	let r = {
		target: t.target,
		initialValue: n.initialValue,
		params: n.params
	}, i = W(t.params, (e) => ({
		disabled: e.optional.boolean,
		hidden: e.optional.boolean,
		label: e.optional.string,
		tag: e.optional.string
	})), a = e.binding.reader(r), o = e.binding.constraint ? e.binding.constraint(r) : void 0, s = new ju({
		reader: a,
		target: t.target,
		writer: e.binding.writer(r)
	}), c = new Si(z(a(n.initialValue), {
		constraint: o,
		equals: e.binding.equals
	}), s), l = e.controller({
		constraint: o,
		document: t.document,
		initialValue: n.initialValue,
		params: n.params,
		value: c,
		viewProps: eo.create({
			disabled: i?.disabled,
			hidden: i?.hidden
		})
	});
	return new sa(t.document, {
		blade: Ha(),
		props: B.fromObject({ label: "label" in t.params ? i?.label ?? null : t.target.key }),
		tag: i?.tag,
		value: c,
		valueController: l
	});
}
var Nu = class {
	constructor(e) {
		this.target = e.target, this.reader_ = e.reader;
	}
	read() {
		return this.reader_(this.target.read());
	}
};
function Pu(e, t) {
	return t === 0 ? new vo() : new yo(e, t ?? fu.monitor.defaultInterval);
}
function Fu(e, t) {
	let n = e.accept(t.target.read(), t.params);
	if (I(n)) return null;
	let r = {
		target: t.target,
		initialValue: n.initialValue,
		params: n.params
	}, i = W(t.params, (e) => ({
		bufferSize: e.optional.number,
		disabled: e.optional.boolean,
		hidden: e.optional.boolean,
		interval: e.optional.number,
		label: e.optional.string
	})), a = e.binding.reader(r), o = i?.bufferSize ?? (e.binding.defaultBufferSize && e.binding.defaultBufferSize(n.params)) ?? 1, s = new pa({
		binding: new Nu({
			reader: a,
			target: t.target
		}),
		bufferSize: o,
		ticker: Pu(t.document, i?.interval)
	}), c = e.controller({
		document: t.document,
		params: n.params,
		value: s,
		viewProps: eo.create({
			disabled: i?.disabled,
			hidden: i?.hidden
		})
	});
	return c.viewProps.bindDisabled(s.ticker), c.viewProps.handleDispose(() => {
		s.ticker.dispose();
	}), new ha(t.document, {
		blade: Ha(),
		props: B.fromObject({ label: "label" in t.params ? i?.label ?? null : t.target.key }),
		value: s,
		valueController: c
	});
}
var Iu = class {
	constructor(e) {
		this.pluginsMap_ = {
			blades: [],
			inputs: [],
			monitors: []
		}, this.apiCache_ = e;
	}
	getAll() {
		return [
			...this.pluginsMap_.blades,
			...this.pluginsMap_.inputs,
			...this.pluginsMap_.monitors
		];
	}
	register(e, t) {
		if (!us(t.core)) throw L.notCompatible(e, t.id);
		t.type === "blade" ? this.pluginsMap_.blades.unshift(t) : t.type === "input" ? this.pluginsMap_.inputs.unshift(t) : t.type === "monitor" && this.pluginsMap_.monitors.unshift(t);
	}
	createInput_(e, t, n) {
		return this.pluginsMap_.inputs.reduce((r, i) => r ?? Mu(i, {
			document: e,
			target: t,
			params: n
		}), null);
	}
	createMonitor_(e, t, n) {
		return this.pluginsMap_.monitors.reduce((r, i) => r ?? Fu(i, {
			document: e,
			params: n,
			target: t
		}), null);
	}
	createBinding(e, t, n) {
		if (I(t.read())) throw new L({
			context: { key: t.key },
			type: "nomatchingcontroller"
		});
		let r = this.createInput_(e, t, n);
		if (r) return r;
		let i = this.createMonitor_(e, t, n);
		if (i) return i;
		throw new L({
			context: { key: t.key },
			type: "nomatchingcontroller"
		});
	}
	createBlade(e, t) {
		let n = this.pluginsMap_.blades.reduce((n, r) => n ?? go(r, {
			document: e,
			params: t
		}), null);
		if (!n) throw new L({
			type: "nomatchingview",
			context: { params: t }
		});
		return n;
	}
	createInputBindingApi_(e) {
		let t = this.pluginsMap_.inputs.reduce((t, n) => t || (n.api?.call(n, { controller: e }) ?? null), null);
		return this.apiCache_.add(e, t ?? new xi(e));
	}
	createMonitorBindingApi_(e) {
		let t = this.pluginsMap_.monitors.reduce((t, n) => t || (n.api?.call(n, { controller: e }) ?? null), null);
		return this.apiCache_.add(e, t ?? new xi(e));
	}
	createBindingApi(e) {
		if (this.apiCache_.has(e)) return this.apiCache_.get(e);
		if (ca(e)) return this.createInputBindingApi_(e);
		if (ga(e)) return this.createMonitorBindingApi_(e);
		throw L.shouldNeverHappen();
	}
	createApi(e) {
		if (this.apiCache_.has(e)) return this.apiCache_.get(e);
		if (oa(e)) return this.createBindingApi(e);
		let t = this.pluginsMap_.blades.reduce((t, n) => t ?? n.api({
			controller: e,
			pool: this
		}), null);
		if (!t) throw L.shouldNeverHappen();
		return this.apiCache_.add(e, t);
	}
}, Lu = new Au();
function Ru() {
	let e = new Iu(Lu);
	return [
		Zl,
		ru,
		lu,
		du,
		Fl,
		Dl,
		El,
		xl,
		_s,
		yu,
		ku,
		Ou,
		Da,
		Za,
		ho
	].forEach((t) => {
		e.register("core", t);
	}), e;
}
var zu = class extends hi {
	constructor(e) {
		super(e), this.emitter_ = new R(), this.controller.value.emitter.on("change", (e) => {
			this.emitter_.emit("change", new _i(this, e.rawValue));
		});
	}
	get label() {
		return this.controller.labelController.props.get("label");
	}
	set label(e) {
		this.controller.labelController.props.set("label", e);
	}
	get options() {
		return this.controller.valueController.props.get("options");
	}
	set options(e) {
		this.controller.valueController.props.set("options", e);
	}
	get value() {
		return this.controller.value.rawValue;
	}
	set value(e) {
		this.controller.value.rawValue = e;
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
}, Bu = class extends hi {}, Vu = class extends hi {
	constructor(e) {
		super(e), this.emitter_ = new R(), this.controller.value.emitter.on("change", (e) => {
			this.emitter_.emit("change", new _i(this, e.rawValue));
		});
	}
	get label() {
		return this.controller.labelController.props.get("label");
	}
	set label(e) {
		this.controller.labelController.props.set("label", e);
	}
	get max() {
		return this.controller.valueController.sliderController.props.get("max");
	}
	set max(e) {
		this.controller.valueController.sliderController.props.set("max", e);
	}
	get min() {
		return this.controller.valueController.sliderController.props.get("min");
	}
	set min(e) {
		this.controller.valueController.sliderController.props.set("min", e);
	}
	get value() {
		return this.controller.value.rawValue;
	}
	set value(e) {
		this.controller.value.rawValue = e;
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
}, Hu = class extends hi {
	constructor(e) {
		super(e), this.emitter_ = new R(), this.controller.value.emitter.on("change", (e) => {
			this.emitter_.emit("change", new _i(this, e.rawValue));
		});
	}
	get label() {
		return this.controller.labelController.props.get("label");
	}
	set label(e) {
		this.controller.labelController.props.set("label", e);
	}
	get formatter() {
		return this.controller.valueController.props.get("formatter");
	}
	set formatter(e) {
		this.controller.valueController.props.set("formatter", e);
	}
	get value() {
		return this.controller.value.rawValue;
	}
	set value(e) {
		this.controller.value.rawValue = e;
	}
	on(e, t) {
		let n = t.bind(this);
		return this.emitter_.on(e, (e) => {
			n(e);
		}, { key: t }), this;
	}
	off(e, t) {
		return this.emitter_.off(e, t), this;
	}
}, Uu = (function() {
	return {
		id: "list",
		type: "blade",
		core: Ea,
		accept(e) {
			let t = W(e, (e) => ({
				options: e.required.custom(Co),
				value: e.required.raw,
				view: e.required.constant("list"),
				label: e.optional.string
			}));
			return t ? { params: t } : null;
		},
		controller(e) {
			let t = new So(wo(e.params.options)), n = z(e.params.value, { constraint: t }), r = new Oo(e.document, {
				props: new B({ options: t.values.value("options") }),
				value: n,
				viewProps: e.viewProps
			});
			return new ra(e.document, {
				blade: e.blade,
				props: B.fromObject({ label: e.params.label }),
				value: n,
				valueController: r
			});
		},
		api(e) {
			return !(e.controller instanceof ra) || !(e.controller.valueController instanceof Oo) ? null : new zu(e.controller);
		}
	};
})(), Wu = class extends qa {
	constructor(e, t) {
		super(e, t);
	}
	get element() {
		return this.controller.view.element;
	}
}, Gu = class extends Xa {
	constructor(e, t) {
		super(e, {
			expanded: t.expanded,
			blade: t.blade,
			props: t.props,
			root: !0,
			viewProps: t.viewProps
		});
	}
}, Ku = q("spr"), qu = class {
	constructor(e, t) {
		this.element = e.createElement("div"), this.element.classList.add(Ku()), t.viewProps.bindClassModifiers(this.element);
		let n = e.createElement("hr");
		n.classList.add(Ku("r")), this.element.appendChild(n);
	}
}, Ju = class extends na {
	constructor(e, t) {
		super(Object.assign(Object.assign({}, t), { view: new qu(e, { viewProps: t.viewProps }) }));
	}
}, Yu = {
	id: "separator",
	type: "blade",
	core: Ea,
	accept(e) {
		let t = W(e, (e) => ({ view: e.required.constant("separator") }));
		return t ? { params: t } : null;
	},
	controller(e) {
		return new Ju(e.document, {
			blade: e.blade,
			viewProps: e.viewProps
		});
	},
	api(e) {
		return e.controller instanceof Ju ? new Bu(e.controller) : null;
	}
}, Xu = {
	id: "slider",
	type: "blade",
	core: Ea,
	accept(e) {
		let t = W(e, (e) => ({
			max: e.required.number,
			min: e.required.number,
			view: e.required.constant("slider"),
			format: e.optional.function,
			label: e.optional.string,
			value: e.optional.number
		}));
		return t ? { params: t } : null;
	},
	controller(e) {
		let t = e.params.value ?? 0, n = new xr({
			max: e.params.max,
			min: e.params.min
		}), r = z(t, { constraint: n }), i = new rs(e.document, Object.assign(Object.assign({}, is({
			formatter: e.params.format ?? ii,
			keyScale: z(1),
			max: n.values.value("max"),
			min: n.values.value("min"),
			pointerScale: li(e.params, t)
		})), {
			parser: ni,
			value: r,
			viewProps: e.viewProps
		}));
		return new ra(e.document, {
			blade: e.blade,
			props: B.fromObject({ label: e.params.label }),
			value: r,
			valueController: i
		});
	},
	api(e) {
		return !(e.controller instanceof ra) || !(e.controller.valueController instanceof rs) ? null : new Vu(e.controller);
	}
}, Zu = (function() {
	return {
		id: "text",
		type: "blade",
		core: Ea,
		accept(e) {
			let t = W(e, (e) => ({
				parse: e.required.function,
				value: e.required.raw,
				view: e.required.constant("text"),
				format: e.optional.function,
				label: e.optional.string
			}));
			return t ? { params: t } : null;
		},
		controller(e) {
			let t = z(e.params.value), n = new Po(e.document, {
				parser: e.params.parse,
				props: B.fromObject({ formatter: e.params.format ?? ((e) => String(e)) }),
				value: t,
				viewProps: e.viewProps
			});
			return new ra(e.document, {
				blade: e.blade,
				props: B.fromObject({ label: e.params.label }),
				value: t,
				valueController: n
			});
		},
		api(e) {
			return !(e.controller instanceof ra) || !(e.controller.valueController instanceof Po) ? null : new Hu(e.controller);
		}
	};
})();
function Qu(e) {
	let t = e.createElement("div");
	return t.classList.add(q("dfw")()), e.body && e.body.appendChild(t), t;
}
function $u(e, t, n) {
	if (e.querySelector(`style[data-tp-style=${t}]`)) return;
	let r = e.createElement("style");
	r.dataset.tpStyle = t, r.textContent = n, e.head.appendChild(r);
}
var ed = class extends Wu {
	constructor(e) {
		let t = e ?? {}, n = t.document ?? Li(), r = Ru(), i = new Gu(n, {
			expanded: t.expanded,
			blade: Ha(),
			props: B.fromObject({ title: t.title }),
			viewProps: eo.create()
		});
		super(i, r), this.pool_ = r, this.containerElem_ = t.container ?? Qu(n), this.containerElem_.appendChild(this.element), this.doc_ = n, this.usesDefaultWrapper_ = !t.container, this.setUpDefaultPlugins_();
	}
	get document() {
		if (!this.doc_) throw L.alreadyDisposed();
		return this.doc_;
	}
	dispose() {
		let e = this.containerElem_;
		if (!e) throw L.alreadyDisposed();
		if (this.usesDefaultWrapper_) {
			let t = e.parentElement;
			t && t.removeChild(e);
		}
		this.containerElem_ = null, this.doc_ = null, super.dispose();
	}
	registerPlugin(e) {
		e.css && $u(this.document, `plugin-${e.id}`, e.css), ("plugin" in e ? [e.plugin] : "plugins" in e ? e.plugins : []).forEach((t) => {
			this.pool_.register(e.id, t);
		});
	}
	setUpDefaultPlugins_() {
		this.registerPlugin({
			id: "default",
			css: ".tp-tbiv_b,.tp-coltxtv_ms,.tp-colswv_b,.tp-ckbv_i,.tp-sglv_i,.tp-mllv_i,.tp-grlv_g,.tp-txtv_i,.tp-p2dpv_p,.tp-colswv_sw,.tp-rotv_b,.tp-fldv_b,.tp-p2dv_b,.tp-btnv_b,.tp-lstv_s{-webkit-appearance:none;-moz-appearance:none;appearance:none;background-color:rgba(0,0,0,0);border-width:0;font-family:inherit;font-size:inherit;font-weight:inherit;margin:0;outline:none;padding:0}.tp-p2dv_b,.tp-btnv_b,.tp-lstv_s{background-color:var(--btn-bg);border-radius:var(--bld-br);color:var(--btn-fg);cursor:pointer;display:block;font-weight:bold;height:var(--cnt-usz);line-height:var(--cnt-usz);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.tp-p2dv_b:hover,.tp-btnv_b:hover,.tp-lstv_s:hover{background-color:var(--btn-bg-h)}.tp-p2dv_b:focus,.tp-btnv_b:focus,.tp-lstv_s:focus{background-color:var(--btn-bg-f)}.tp-p2dv_b:active,.tp-btnv_b:active,.tp-lstv_s:active{background-color:var(--btn-bg-a)}.tp-p2dv_b:disabled,.tp-btnv_b:disabled,.tp-lstv_s:disabled{opacity:.5}.tp-rotv_c>.tp-cntv.tp-v-lst,.tp-tbpv_c>.tp-cntv.tp-v-lst,.tp-fldv_c>.tp-cntv.tp-v-lst{margin-bottom:calc(-1*var(--cnt-vp))}.tp-rotv_c>.tp-fldv.tp-v-lst .tp-fldv_c,.tp-tbpv_c>.tp-fldv.tp-v-lst .tp-fldv_c,.tp-fldv_c>.tp-fldv.tp-v-lst .tp-fldv_c{border-bottom-left-radius:0}.tp-rotv_c>.tp-fldv.tp-v-lst .tp-fldv_b,.tp-tbpv_c>.tp-fldv.tp-v-lst .tp-fldv_b,.tp-fldv_c>.tp-fldv.tp-v-lst .tp-fldv_b{border-bottom-left-radius:0}.tp-rotv_c>*:not(.tp-v-fst),.tp-tbpv_c>*:not(.tp-v-fst),.tp-fldv_c>*:not(.tp-v-fst){margin-top:var(--cnt-usp)}.tp-rotv_c>.tp-sprv:not(.tp-v-fst),.tp-tbpv_c>.tp-sprv:not(.tp-v-fst),.tp-fldv_c>.tp-sprv:not(.tp-v-fst),.tp-rotv_c>.tp-cntv:not(.tp-v-fst),.tp-tbpv_c>.tp-cntv:not(.tp-v-fst),.tp-fldv_c>.tp-cntv:not(.tp-v-fst){margin-top:var(--cnt-vp)}.tp-rotv_c>.tp-sprv+*:not(.tp-v-hidden),.tp-tbpv_c>.tp-sprv+*:not(.tp-v-hidden),.tp-fldv_c>.tp-sprv+*:not(.tp-v-hidden),.tp-rotv_c>.tp-cntv+*:not(.tp-v-hidden),.tp-tbpv_c>.tp-cntv+*:not(.tp-v-hidden),.tp-fldv_c>.tp-cntv+*:not(.tp-v-hidden){margin-top:var(--cnt-vp)}.tp-rotv_c>.tp-sprv:not(.tp-v-hidden)+.tp-sprv,.tp-tbpv_c>.tp-sprv:not(.tp-v-hidden)+.tp-sprv,.tp-fldv_c>.tp-sprv:not(.tp-v-hidden)+.tp-sprv,.tp-rotv_c>.tp-cntv:not(.tp-v-hidden)+.tp-cntv,.tp-tbpv_c>.tp-cntv:not(.tp-v-hidden)+.tp-cntv,.tp-fldv_c>.tp-cntv:not(.tp-v-hidden)+.tp-cntv{margin-top:0}.tp-tbpv_c>.tp-cntv,.tp-fldv_c>.tp-cntv{margin-left:4px}.tp-tbpv_c>.tp-fldv>.tp-fldv_b,.tp-fldv_c>.tp-fldv>.tp-fldv_b{border-top-left-radius:var(--bld-br);border-bottom-left-radius:var(--bld-br)}.tp-tbpv_c>.tp-fldv.tp-fldv-expanded>.tp-fldv_b,.tp-fldv_c>.tp-fldv.tp-fldv-expanded>.tp-fldv_b{border-bottom-left-radius:0}.tp-tbpv_c .tp-fldv>.tp-fldv_c,.tp-fldv_c .tp-fldv>.tp-fldv_c{border-bottom-left-radius:var(--bld-br)}.tp-tbpv_c>.tp-cntv+.tp-fldv>.tp-fldv_b,.tp-fldv_c>.tp-cntv+.tp-fldv>.tp-fldv_b{border-top-left-radius:0}.tp-tbpv_c>.tp-cntv+.tp-tabv>.tp-tabv_t,.tp-fldv_c>.tp-cntv+.tp-tabv>.tp-tabv_t{border-top-left-radius:0}.tp-tbpv_c>.tp-tabv>.tp-tabv_t,.tp-fldv_c>.tp-tabv>.tp-tabv_t{border-top-left-radius:var(--bld-br)}.tp-tbpv_c .tp-tabv>.tp-tabv_c,.tp-fldv_c .tp-tabv>.tp-tabv_c{border-bottom-left-radius:var(--bld-br)}.tp-rotv_b,.tp-fldv_b{background-color:var(--cnt-bg);color:var(--cnt-fg);cursor:pointer;display:block;height:calc(var(--cnt-usz) + 4px);line-height:calc(var(--cnt-usz) + 4px);overflow:hidden;padding-left:var(--cnt-hp);padding-right:calc(4px + var(--cnt-usz) + var(--cnt-hp));position:relative;text-align:left;text-overflow:ellipsis;white-space:nowrap;width:100%;transition:border-radius .2s ease-in-out .2s}.tp-rotv_b:hover,.tp-fldv_b:hover{background-color:var(--cnt-bg-h)}.tp-rotv_b:focus,.tp-fldv_b:focus{background-color:var(--cnt-bg-f)}.tp-rotv_b:active,.tp-fldv_b:active{background-color:var(--cnt-bg-a)}.tp-rotv_b:disabled,.tp-fldv_b:disabled{opacity:.5}.tp-rotv_m,.tp-fldv_m{background:linear-gradient(to left, var(--cnt-fg), var(--cnt-fg) 2px, transparent 2px, transparent 4px, var(--cnt-fg) 4px);border-radius:2px;bottom:0;content:\"\";display:block;height:6px;right:calc(var(--cnt-hp) + (var(--cnt-usz) + 4px - 6px)/2 - 2px);margin:auto;opacity:.5;position:absolute;top:0;transform:rotate(90deg);transition:transform .2s ease-in-out;width:6px}.tp-rotv.tp-rotv-expanded .tp-rotv_m,.tp-fldv.tp-fldv-expanded>.tp-fldv_b>.tp-fldv_m{transform:none}.tp-rotv_c,.tp-fldv_c{box-sizing:border-box;height:0;opacity:0;overflow:hidden;padding-bottom:0;padding-top:0;position:relative;transition:height .2s ease-in-out,opacity .2s linear,padding .2s ease-in-out}.tp-rotv.tp-rotv-cpl:not(.tp-rotv-expanded) .tp-rotv_c,.tp-fldv.tp-fldv-cpl:not(.tp-fldv-expanded)>.tp-fldv_c{display:none}.tp-rotv.tp-rotv-expanded .tp-rotv_c,.tp-fldv.tp-fldv-expanded>.tp-fldv_c{opacity:1;padding-bottom:var(--cnt-vp);padding-top:var(--cnt-vp);transform:none;overflow:visible;transition:height .2s ease-in-out,opacity .2s linear .2s,padding .2s ease-in-out}.tp-txtv_i,.tp-p2dpv_p,.tp-colswv_sw{background-color:var(--in-bg);border-radius:var(--bld-br);box-sizing:border-box;color:var(--in-fg);font-family:inherit;height:var(--cnt-usz);line-height:var(--cnt-usz);min-width:0;width:100%}.tp-txtv_i:hover,.tp-p2dpv_p:hover,.tp-colswv_sw:hover{background-color:var(--in-bg-h)}.tp-txtv_i:focus,.tp-p2dpv_p:focus,.tp-colswv_sw:focus{background-color:var(--in-bg-f)}.tp-txtv_i:active,.tp-p2dpv_p:active,.tp-colswv_sw:active{background-color:var(--in-bg-a)}.tp-txtv_i:disabled,.tp-p2dpv_p:disabled,.tp-colswv_sw:disabled{opacity:.5}.tp-lstv,.tp-coltxtv_m{position:relative}.tp-lstv_s{padding:0 20px 0 4px;width:100%}.tp-lstv_m,.tp-coltxtv_mm{bottom:0;margin:auto;pointer-events:none;position:absolute;right:2px;top:0}.tp-lstv_m svg,.tp-coltxtv_mm svg{bottom:0;height:16px;margin:auto;position:absolute;right:0;top:0;width:16px}.tp-lstv_m svg path,.tp-coltxtv_mm svg path{fill:currentColor}.tp-sglv_i,.tp-mllv_i,.tp-grlv_g{background-color:var(--mo-bg);border-radius:var(--bld-br);box-sizing:border-box;color:var(--mo-fg);height:var(--cnt-usz);scrollbar-color:currentColor rgba(0,0,0,0);scrollbar-width:thin;width:100%}.tp-sglv_i::-webkit-scrollbar,.tp-mllv_i::-webkit-scrollbar,.tp-grlv_g::-webkit-scrollbar{height:8px;width:8px}.tp-sglv_i::-webkit-scrollbar-corner,.tp-mllv_i::-webkit-scrollbar-corner,.tp-grlv_g::-webkit-scrollbar-corner{background-color:rgba(0,0,0,0)}.tp-sglv_i::-webkit-scrollbar-thumb,.tp-mllv_i::-webkit-scrollbar-thumb,.tp-grlv_g::-webkit-scrollbar-thumb{background-clip:padding-box;background-color:currentColor;border:rgba(0,0,0,0) solid 2px;border-radius:4px}.tp-pndtxtv,.tp-coltxtv_w{display:flex}.tp-pndtxtv_a,.tp-coltxtv_c{width:100%}.tp-pndtxtv_a+.tp-pndtxtv_a,.tp-coltxtv_c+.tp-pndtxtv_a,.tp-pndtxtv_a+.tp-coltxtv_c,.tp-coltxtv_c+.tp-coltxtv_c{margin-left:2px}.tp-rotv{--bs-bg: var(--tp-base-background-color, hsl(230, 7%, 17%));--bs-br: var(--tp-base-border-radius, 6px);--bs-ff: var(--tp-base-font-family, Roboto Mono, Source Code Pro, Menlo, Courier, monospace);--bs-sh: var(--tp-base-shadow-color, rgba(0, 0, 0, 0.2));--bld-br: var(--tp-blade-border-radius, 2px);--bld-hp: var(--tp-blade-horizontal-padding, 4px);--bld-vw: var(--tp-blade-value-width, 160px);--btn-bg: var(--tp-button-background-color, hsl(230, 7%, 70%));--btn-bg-a: var(--tp-button-background-color-active, #d6d7db);--btn-bg-f: var(--tp-button-background-color-focus, #c8cad0);--btn-bg-h: var(--tp-button-background-color-hover, #bbbcc4);--btn-fg: var(--tp-button-foreground-color, hsl(230, 7%, 17%));--cnt-bg: var(--tp-container-background-color, rgba(187, 188, 196, 0.1));--cnt-bg-a: var(--tp-container-background-color-active, rgba(187, 188, 196, 0.25));--cnt-bg-f: var(--tp-container-background-color-focus, rgba(187, 188, 196, 0.2));--cnt-bg-h: var(--tp-container-background-color-hover, rgba(187, 188, 196, 0.15));--cnt-fg: var(--tp-container-foreground-color, hsl(230, 7%, 75%));--cnt-hp: var(--tp-container-horizontal-padding, 4px);--cnt-vp: var(--tp-container-vertical-padding, 4px);--cnt-usp: var(--tp-container-unit-spacing, 4px);--cnt-usz: var(--tp-container-unit-size, 20px);--in-bg: var(--tp-input-background-color, rgba(187, 188, 196, 0.1));--in-bg-a: var(--tp-input-background-color-active, rgba(187, 188, 196, 0.25));--in-bg-f: var(--tp-input-background-color-focus, rgba(187, 188, 196, 0.2));--in-bg-h: var(--tp-input-background-color-hover, rgba(187, 188, 196, 0.15));--in-fg: var(--tp-input-foreground-color, hsl(230, 7%, 75%));--lbl-fg: var(--tp-label-foreground-color, rgba(187, 188, 196, 0.7));--mo-bg: var(--tp-monitor-background-color, rgba(0, 0, 0, 0.2));--mo-fg: var(--tp-monitor-foreground-color, rgba(187, 188, 196, 0.7));--grv-fg: var(--tp-groove-foreground-color, rgba(187, 188, 196, 0.1))}.tp-btnv_b{width:100%}.tp-btnv_t{text-align:center}.tp-ckbv_l{display:block;position:relative}.tp-ckbv_i{left:0;opacity:0;position:absolute;top:0}.tp-ckbv_w{background-color:var(--in-bg);border-radius:var(--bld-br);cursor:pointer;display:block;height:var(--cnt-usz);position:relative;width:var(--cnt-usz)}.tp-ckbv_w svg{display:block;height:16px;inset:0;margin:auto;opacity:0;position:absolute;width:16px}.tp-ckbv_w svg path{fill:none;stroke:var(--in-fg);stroke-width:2}.tp-ckbv_i:hover+.tp-ckbv_w{background-color:var(--in-bg-h)}.tp-ckbv_i:focus+.tp-ckbv_w{background-color:var(--in-bg-f)}.tp-ckbv_i:active+.tp-ckbv_w{background-color:var(--in-bg-a)}.tp-ckbv_i:checked+.tp-ckbv_w svg{opacity:1}.tp-ckbv.tp-v-disabled .tp-ckbv_w{opacity:.5}.tp-colv{position:relative}.tp-colv_h{display:flex}.tp-colv_s{flex-grow:0;flex-shrink:0;width:var(--cnt-usz)}.tp-colv_t{flex:1;margin-left:4px}.tp-colv_p{height:0;margin-top:0;opacity:0;overflow:hidden;transition:height .2s ease-in-out,opacity .2s linear,margin .2s ease-in-out}.tp-colv.tp-colv-expanded.tp-colv-cpl .tp-colv_p{overflow:visible}.tp-colv.tp-colv-expanded .tp-colv_p{margin-top:var(--cnt-usp);opacity:1}.tp-colv .tp-popv{left:calc(-1*var(--cnt-hp));right:calc(-1*var(--cnt-hp));top:var(--cnt-usz)}.tp-colpv_h,.tp-colpv_ap{margin-left:6px;margin-right:6px}.tp-colpv_h{margin-top:var(--cnt-usp)}.tp-colpv_rgb{display:flex;margin-top:var(--cnt-usp);width:100%}.tp-colpv_a{display:flex;margin-top:var(--cnt-vp);padding-top:calc(var(--cnt-vp) + 2px);position:relative}.tp-colpv_a::before{background-color:var(--grv-fg);content:\"\";height:2px;left:calc(-1*var(--cnt-hp));position:absolute;right:calc(-1*var(--cnt-hp));top:0}.tp-colpv.tp-v-disabled .tp-colpv_a::before{opacity:.5}.tp-colpv_ap{align-items:center;display:flex;flex:3}.tp-colpv_at{flex:1;margin-left:4px}.tp-svpv{border-radius:var(--bld-br);outline:none;overflow:hidden;position:relative}.tp-svpv.tp-v-disabled{opacity:.5}.tp-svpv_c{cursor:crosshair;display:block;height:calc(var(--cnt-usz)*4);width:100%}.tp-svpv_m{border-radius:100%;border:rgba(255,255,255,.75) solid 2px;box-sizing:border-box;filter:drop-shadow(0 0 1px rgba(0, 0, 0, 0.3));height:12px;margin-left:-6px;margin-top:-6px;pointer-events:none;position:absolute;width:12px}.tp-svpv:focus .tp-svpv_m{border-color:#fff}.tp-hplv{cursor:pointer;height:var(--cnt-usz);outline:none;position:relative}.tp-hplv.tp-v-disabled{opacity:.5}.tp-hplv_c{background-image:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAAABCAYAAABubagXAAAAQ0lEQVQoU2P8z8Dwn0GCgQEDi2OK/RBgYHjBgIpfovFh8j8YBIgzFGQxuqEgPhaDOT5gOhPkdCxOZeBg+IDFZZiGAgCaSSMYtcRHLgAAAABJRU5ErkJggg==);background-position:left top;background-repeat:no-repeat;background-size:100% 100%;border-radius:2px;display:block;height:4px;left:0;margin-top:-2px;position:absolute;top:50%;width:100%}.tp-hplv_m{border-radius:var(--bld-br);border:rgba(255,255,255,.75) solid 2px;box-shadow:0 0 2px rgba(0,0,0,.1);box-sizing:border-box;height:12px;left:50%;margin-left:-6px;margin-top:-6px;position:absolute;top:50%;width:12px}.tp-hplv:focus .tp-hplv_m{border-color:#fff}.tp-aplv{cursor:pointer;height:var(--cnt-usz);outline:none;position:relative;width:100%}.tp-aplv.tp-v-disabled{opacity:.5}.tp-aplv_b{background-color:#fff;background-image:linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%),linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%);background-size:4px 4px;background-position:0 0,2px 2px;border-radius:2px;display:block;height:4px;left:0;margin-top:-2px;overflow:hidden;position:absolute;top:50%;width:100%}.tp-aplv_c{inset:0;position:absolute}.tp-aplv_m{background-color:#fff;background-image:linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%),linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%);background-size:12px 12px;background-position:0 0,6px 6px;border-radius:var(--bld-br);box-shadow:0 0 2px rgba(0,0,0,.1);height:12px;left:50%;margin-left:-6px;margin-top:-6px;overflow:hidden;position:absolute;top:50%;width:12px}.tp-aplv_p{border-radius:var(--bld-br);border:rgba(255,255,255,.75) solid 2px;box-sizing:border-box;inset:0;position:absolute}.tp-aplv:focus .tp-aplv_p{border-color:#fff}.tp-colswv{background-color:#fff;background-image:linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%),linear-gradient(to top right, #ddd 25%, transparent 25%, transparent 75%, #ddd 75%);background-size:10px 10px;background-position:0 0,5px 5px;border-radius:var(--bld-br);overflow:hidden}.tp-colswv.tp-v-disabled{opacity:.5}.tp-colswv_sw{border-radius:0}.tp-colswv_b{cursor:pointer;display:block;height:var(--cnt-usz);left:0;position:absolute;top:0;width:var(--cnt-usz)}.tp-colswv_b:focus::after{border:rgba(255,255,255,.75) solid 2px;border-radius:var(--bld-br);content:\"\";display:block;inset:0;position:absolute}.tp-coltxtv{display:flex;width:100%}.tp-coltxtv_m{margin-right:4px}.tp-coltxtv_ms{border-radius:var(--bld-br);color:var(--lbl-fg);cursor:pointer;height:var(--cnt-usz);line-height:var(--cnt-usz);padding:0 18px 0 4px}.tp-coltxtv_ms:hover{background-color:var(--in-bg-h)}.tp-coltxtv_ms:focus{background-color:var(--in-bg-f)}.tp-coltxtv_ms:active{background-color:var(--in-bg-a)}.tp-coltxtv_mm{color:var(--lbl-fg)}.tp-coltxtv.tp-v-disabled .tp-coltxtv_mm{opacity:.5}.tp-coltxtv_w{flex:1}.tp-dfwv{position:absolute;top:8px;right:8px;width:256px}.tp-fldv{position:relative}.tp-fldv_t{padding-left:4px}.tp-fldv_b:disabled .tp-fldv_m{display:none}.tp-fldv_c{padding-left:4px}.tp-fldv_i{bottom:0;color:var(--cnt-bg);left:0;overflow:hidden;position:absolute;top:calc(var(--cnt-usz) + 4px);width:max(var(--bs-br),4px)}.tp-fldv_i::before{background-color:currentColor;bottom:0;content:\"\";left:0;position:absolute;top:0;width:4px}.tp-fldv_b:hover+.tp-fldv_i{color:var(--cnt-bg-h)}.tp-fldv_b:focus+.tp-fldv_i{color:var(--cnt-bg-f)}.tp-fldv_b:active+.tp-fldv_i{color:var(--cnt-bg-a)}.tp-fldv.tp-v-disabled>.tp-fldv_i{opacity:.5}.tp-grlv{position:relative}.tp-grlv_g{display:block;height:calc(var(--cnt-usz)*3)}.tp-grlv_g polyline{fill:none;stroke:var(--mo-fg);stroke-linejoin:round}.tp-grlv_t{margin-top:-4px;transition:left .05s,top .05s;visibility:hidden}.tp-grlv_t.tp-grlv_t-a{visibility:visible}.tp-grlv_t.tp-grlv_t-in{transition:none}.tp-grlv.tp-v-disabled .tp-grlv_g{opacity:.5}.tp-grlv .tp-ttv{background-color:var(--mo-fg)}.tp-grlv .tp-ttv::before{border-top-color:var(--mo-fg)}.tp-lblv{align-items:center;display:flex;line-height:1.3;padding-left:var(--cnt-hp);padding-right:var(--cnt-hp)}.tp-lblv.tp-lblv-nol{display:block}.tp-lblv_l{color:var(--lbl-fg);flex:1;-webkit-hyphens:auto;hyphens:auto;overflow:hidden;padding-left:4px;padding-right:16px}.tp-lblv.tp-v-disabled .tp-lblv_l{opacity:.5}.tp-lblv.tp-lblv-nol .tp-lblv_l{display:none}.tp-lblv_v{align-self:flex-start;flex-grow:0;flex-shrink:0;width:var(--bld-vw)}.tp-lblv.tp-lblv-nol .tp-lblv_v{width:100%}.tp-lstv_s{padding:0 20px 0 var(--bld-hp);width:100%}.tp-lstv_m{color:var(--btn-fg)}.tp-sglv_i{padding-left:var(--bld-hp);padding-right:var(--bld-hp)}.tp-sglv.tp-v-disabled .tp-sglv_i{opacity:.5}.tp-mllv_i{display:block;height:calc(var(--cnt-usz)*3);line-height:var(--cnt-usz);padding-left:var(--bld-hp);padding-right:var(--bld-hp);resize:none;white-space:pre}.tp-mllv.tp-v-disabled .tp-mllv_i{opacity:.5}.tp-p2dv{position:relative}.tp-p2dv_h{display:flex}.tp-p2dv_b{height:var(--cnt-usz);margin-right:4px;position:relative;width:var(--cnt-usz)}.tp-p2dv_b svg{display:block;height:16px;left:50%;margin-left:-8px;margin-top:-8px;position:absolute;top:50%;width:16px}.tp-p2dv_b svg path{stroke:currentColor;stroke-width:2}.tp-p2dv_b svg circle{fill:currentColor}.tp-p2dv_t{flex:1}.tp-p2dv_p{height:0;margin-top:0;opacity:0;overflow:hidden;transition:height .2s ease-in-out,opacity .2s linear,margin .2s ease-in-out}.tp-p2dv.tp-p2dv-expanded .tp-p2dv_p{margin-top:var(--cnt-usp);opacity:1}.tp-p2dv .tp-popv{left:calc(-1*var(--cnt-hp));right:calc(-1*var(--cnt-hp));top:var(--cnt-usz)}.tp-p2dpv{padding-left:calc(var(--cnt-usz) + 4px)}.tp-p2dpv_p{cursor:crosshair;height:0;overflow:hidden;padding-bottom:100%;position:relative}.tp-p2dpv.tp-v-disabled .tp-p2dpv_p{opacity:.5}.tp-p2dpv_g{display:block;height:100%;left:0;pointer-events:none;position:absolute;top:0;width:100%}.tp-p2dpv_ax{opacity:.1;stroke:var(--in-fg);stroke-dasharray:1}.tp-p2dpv_l{opacity:.5;stroke:var(--in-fg);stroke-dasharray:1}.tp-p2dpv_m{border:var(--in-fg) solid 1px;border-radius:50%;box-sizing:border-box;height:4px;margin-left:-2px;margin-top:-2px;position:absolute;width:4px}.tp-p2dpv_p:focus .tp-p2dpv_m{background-color:var(--in-fg);border-width:0}.tp-popv{background-color:var(--bs-bg);border-radius:var(--bs-br);box-shadow:0 2px 4px var(--bs-sh);display:none;max-width:var(--bld-vw);padding:var(--cnt-vp) var(--cnt-hp);position:absolute;visibility:hidden;z-index:1000}.tp-popv.tp-popv-v{display:block;visibility:visible}.tp-sldv.tp-v-disabled{opacity:.5}.tp-sldv_t{box-sizing:border-box;cursor:pointer;height:var(--cnt-usz);margin:0 6px;outline:none;position:relative}.tp-sldv_t::before{background-color:var(--in-bg);border-radius:1px;content:\"\";display:block;height:2px;inset:0;margin:auto;position:absolute}.tp-sldv_k{height:100%;left:0;position:absolute;top:0}.tp-sldv_k::before{background-color:var(--in-fg);border-radius:1px;content:\"\";display:block;height:2px;inset:0;margin-bottom:auto;margin-top:auto;position:absolute}.tp-sldv_k::after{background-color:var(--btn-bg);border-radius:var(--bld-br);bottom:0;content:\"\";display:block;height:12px;margin-bottom:auto;margin-top:auto;position:absolute;right:-6px;top:0;width:12px}.tp-sldv_t:hover .tp-sldv_k::after{background-color:var(--btn-bg-h)}.tp-sldv_t:focus .tp-sldv_k::after{background-color:var(--btn-bg-f)}.tp-sldv_t:active .tp-sldv_k::after{background-color:var(--btn-bg-a)}.tp-sldtxtv{display:flex}.tp-sldtxtv_s{flex:2}.tp-sldtxtv_t{flex:1;margin-left:4px}.tp-tabv{position:relative}.tp-tabv_t{align-items:flex-end;color:var(--cnt-bg);display:flex;overflow:hidden;position:relative}.tp-tabv_t:hover{color:var(--cnt-bg-h)}.tp-tabv_t:has(*:focus){color:var(--cnt-bg-f)}.tp-tabv_t:has(*:active){color:var(--cnt-bg-a)}.tp-tabv_t::before{background-color:currentColor;bottom:0;content:\"\";height:2px;left:0;pointer-events:none;position:absolute;right:0}.tp-tabv.tp-v-disabled .tp-tabv_t::before{opacity:.5}.tp-tabv.tp-tabv-nop .tp-tabv_t{height:calc(var(--cnt-usz) + 4px);position:relative}.tp-tabv.tp-tabv-nop .tp-tabv_t::before{background-color:var(--cnt-bg);bottom:0;content:\"\";height:2px;left:0;position:absolute;right:0}.tp-tabv_i{bottom:0;color:var(--cnt-bg);left:0;overflow:hidden;position:absolute;top:calc(var(--cnt-usz) + 4px);width:max(var(--bs-br),4px)}.tp-tabv_i::before{background-color:currentColor;bottom:0;content:\"\";left:0;position:absolute;top:0;width:4px}.tp-tabv_t:hover+.tp-tabv_i{color:var(--cnt-bg-h)}.tp-tabv_t:has(*:focus)+.tp-tabv_i{color:var(--cnt-bg-f)}.tp-tabv_t:has(*:active)+.tp-tabv_i{color:var(--cnt-bg-a)}.tp-tabv.tp-v-disabled>.tp-tabv_i{opacity:.5}.tp-tbiv{flex:1;min-width:0;position:relative}.tp-tbiv+.tp-tbiv{margin-left:2px}.tp-tbiv+.tp-tbiv.tp-v-disabled::before{opacity:.5}.tp-tbiv_b{display:block;padding-left:calc(var(--cnt-hp) + 4px);padding-right:calc(var(--cnt-hp) + 4px);position:relative;width:100%}.tp-tbiv_b:disabled{opacity:.5}.tp-tbiv_b::before{background-color:var(--cnt-bg);content:\"\";inset:0 0 2px;pointer-events:none;position:absolute}.tp-tbiv_b:hover::before{background-color:var(--cnt-bg-h)}.tp-tbiv_b:focus::before{background-color:var(--cnt-bg-f)}.tp-tbiv_b:active::before{background-color:var(--cnt-bg-a)}.tp-tbiv_t{color:var(--cnt-fg);height:calc(var(--cnt-usz) + 4px);line-height:calc(var(--cnt-usz) + 4px);opacity:.5;overflow:hidden;position:relative;text-overflow:ellipsis}.tp-tbiv.tp-tbiv-sel .tp-tbiv_t{opacity:1}.tp-tbpv_c{padding-bottom:var(--cnt-vp);padding-left:4px;padding-top:var(--cnt-vp)}.tp-txtv{position:relative}.tp-txtv_i{padding-left:var(--bld-hp);padding-right:var(--bld-hp)}.tp-txtv.tp-txtv-fst .tp-txtv_i{border-bottom-right-radius:0;border-top-right-radius:0}.tp-txtv.tp-txtv-mid .tp-txtv_i{border-radius:0}.tp-txtv.tp-txtv-lst .tp-txtv_i{border-bottom-left-radius:0;border-top-left-radius:0}.tp-txtv.tp-txtv-num .tp-txtv_i{text-align:right}.tp-txtv.tp-txtv-drg .tp-txtv_i{opacity:.3}.tp-txtv_k{cursor:pointer;height:100%;left:calc(var(--bld-hp) - 5px);position:absolute;top:0;width:12px}.tp-txtv_k::before{background-color:var(--in-fg);border-radius:1px;bottom:0;content:\"\";height:calc(var(--cnt-usz) - 4px);left:50%;margin-bottom:auto;margin-left:-1px;margin-top:auto;opacity:.1;position:absolute;top:0;transition:border-radius .1s,height .1s,transform .1s,width .1s;width:2px}.tp-txtv_k:hover::before,.tp-txtv.tp-txtv-drg .tp-txtv_k::before{opacity:1}.tp-txtv.tp-txtv-drg .tp-txtv_k::before{border-radius:50%;height:4px;transform:translateX(-1px);width:4px}.tp-txtv_g{bottom:0;display:block;height:8px;left:50%;margin:auto;overflow:visible;pointer-events:none;position:absolute;top:0;visibility:hidden;width:100%}.tp-txtv.tp-txtv-drg .tp-txtv_g{visibility:visible}.tp-txtv_gb{fill:none;stroke:var(--in-fg);stroke-dasharray:1}.tp-txtv_gh{fill:none;stroke:var(--in-fg)}.tp-txtv .tp-ttv{margin-left:6px;visibility:hidden}.tp-txtv.tp-txtv-drg .tp-ttv{visibility:visible}.tp-ttv{background-color:var(--in-fg);border-radius:var(--bld-br);color:var(--bs-bg);padding:2px 4px;pointer-events:none;position:absolute;transform:translate(-50%, -100%)}.tp-ttv::before{border-color:var(--in-fg) rgba(0,0,0,0) rgba(0,0,0,0) rgba(0,0,0,0);border-style:solid;border-width:2px;box-sizing:border-box;content:\"\";font-size:.9em;height:4px;left:50%;margin-left:-2px;position:absolute;top:100%;width:4px}.tp-rotv{background-color:var(--bs-bg);border-radius:var(--bs-br);box-shadow:0 2px 4px var(--bs-sh);font-family:var(--bs-ff);font-size:11px;font-weight:500;line-height:1;text-align:left}.tp-rotv_b{border-bottom-left-radius:var(--bs-br);border-bottom-right-radius:var(--bs-br);border-top-left-radius:var(--bs-br);border-top-right-radius:var(--bs-br);padding-left:calc(4px + var(--cnt-usz) + var(--cnt-hp));text-align:center}.tp-rotv.tp-rotv-expanded .tp-rotv_b{border-bottom-left-radius:0;border-bottom-right-radius:0;transition-delay:0s;transition-duration:0s}.tp-rotv.tp-rotv-not>.tp-rotv_b{display:none}.tp-rotv_b:disabled .tp-rotv_m{display:none}.tp-rotv_c>.tp-fldv.tp-v-lst>.tp-fldv_c{border-bottom-left-radius:var(--bs-br);border-bottom-right-radius:var(--bs-br)}.tp-rotv_c>.tp-fldv.tp-v-lst>.tp-fldv_i{border-bottom-left-radius:var(--bs-br)}.tp-rotv_c>.tp-fldv.tp-v-lst:not(.tp-fldv-expanded)>.tp-fldv_b{border-bottom-left-radius:var(--bs-br);border-bottom-right-radius:var(--bs-br)}.tp-rotv_c>.tp-fldv.tp-v-lst.tp-fldv-expanded>.tp-fldv_b{transition-delay:0s;transition-duration:0s}.tp-rotv_c .tp-fldv.tp-v-vlst:not(.tp-fldv-expanded)>.tp-fldv_b{border-bottom-right-radius:var(--bs-br)}.tp-rotv.tp-rotv-not .tp-rotv_c>.tp-fldv.tp-v-fst{margin-top:calc(-1*var(--cnt-vp))}.tp-rotv.tp-rotv-not .tp-rotv_c>.tp-fldv.tp-v-fst>.tp-fldv_b{border-top-left-radius:var(--bs-br);border-top-right-radius:var(--bs-br)}.tp-rotv_c>.tp-tabv.tp-v-lst>.tp-tabv_c{border-bottom-left-radius:var(--bs-br);border-bottom-right-radius:var(--bs-br)}.tp-rotv_c>.tp-tabv.tp-v-lst>.tp-tabv_i{border-bottom-left-radius:var(--bs-br)}.tp-rotv.tp-rotv-not .tp-rotv_c>.tp-tabv.tp-v-fst{margin-top:calc(-1*var(--cnt-vp))}.tp-rotv.tp-rotv-not .tp-rotv_c>.tp-tabv.tp-v-fst>.tp-tabv_t{border-top-left-radius:var(--bs-br);border-top-right-radius:var(--bs-br)}.tp-rotv.tp-v-disabled,.tp-rotv .tp-v-disabled{pointer-events:none}.tp-rotv.tp-v-hidden,.tp-rotv .tp-v-hidden{display:none}.tp-sprv_r{background-color:var(--grv-fg);border-width:0;display:block;height:2px;margin:0;width:100%}.tp-sprv.tp-v-disabled .tp-sprv_r{opacity:.5}",
			plugins: [
				Uu,
				Yu,
				Xu,
				ho,
				Zu
			]
		});
	}
};
new Ta("4.0.5");
// Tune.svelte
function td(e, t) {
	Ve(t, !0);
	let n = rr(t, "params", 7), r = rr(t, "target", 7), i = rr(t, "field", 7), a = (e) => ({
		label: e.label,
		...e.kind === "number" && {
			min: e.min,
			max: e.max,
			step: e.step
		},
		...e.kind === "color" && { view: "color" },
		...e.kind === "choice" && { options: e.values.map((e) => ({
			text: e,
			value: e
		})) }
	});
	return Qt(() => {
		let e = Object.fromEntries(n().map((e) => [e.id, e.value])), o = new ed({ container: t.$$host });
		for (let t of n()) o.addBinding(e, t.id, a(t));
		let s = document.getElementById(r()), c = () => {
			let t = document.getElementById(i());
			t && (t.value = JSON.stringify(e)), s?.contentWindow?.postMessage({
				type: "wr:params",
				params: e
			}, location.origin);
		};
		return o.on("change", c), s?.addEventListener("load", c), () => {
			s?.removeEventListener("load", c), o.dispose();
		};
	}), He({
		get params() {
			return n();
		},
		set params(e) {
			n(e), _t();
		},
		get target() {
			return r();
		},
		set target(e) {
			r(e), _t();
		},
		get field() {
			return i();
		},
		set field(e) {
			i(e), _t();
		}
	});
}
customElements.define("wr-tune", lr(td, {
	params: {
		attribute: "data-params",
		type: "Array"
	},
	target: { attribute: "data-target" },
	field: { attribute: "data-field" }
}, [], []));
