// Round 6 step 3: how a building and a defence show no power (F21). Overlay only; no shape or palette changes.
window.CAND6.power = (function () {
  const POWERED = ['usa_defence', 'china_defence'];
  const BOLT = [[0.04, -1], [0.36, -1], [0.08, -0.56], [0.3, -0.56], [-0.24, 0], [-0.06, -0.42], [-0.3, -0.42]];
  const UNDER = 'rgba(14,27,35,0.9)';

  function boltPath(ctx, x, y, h) {
    ctx.beginPath();
    BOLT.forEach(([bx, by], i) => (i ? ctx.lineTo : ctx.moveTo).call(ctx, x + bx * h, y + by * h));
    ctx.closePath();
  }
  function bolt(ctx, x, y, h, hollow) {
    ctx.lineJoin = 'round';
    boltPath(ctx, x, y, h);
    ctx.strokeStyle = UNDER; ctx.lineWidth = hollow ? 4 : 3; ctx.stroke();
    if (hollow) { ctx.strokeStyle = '#ffffff'; ctx.lineWidth = 1.5; ctx.stroke(); return; }
    ctx.fillStyle = '#ffffff'; ctx.fill();
  }
  // The local player's base is the one whose Headquarters is selected; only that player is short of power.
  const marks = (slowed) => (ctx, scene) => {
    const hq = scene.items.find((it) => it.selected && it.bld), z = scene.zoom;
    if (!hq) return;
    const done = new Set(); // a construction site is three items (back posts, body, front posts) at one anchor
    scene.items.filter((it) => it.bld && it.shape && it.owner === hq.owner).forEach((it) => {
      const id = it.shape.id || '', dark = POWERED.includes(id), at = it.ax + ',' + it.ay;
      if ((!dark && (!slowed || /_power_plant$/.test(id))) || done.has(at)) return;
      done.add(at);
      const h = dark ? 11 + 8 * z : 8 + 5 * z, top = it.ay + bboxPx(it.shape, z, it.variant).y0;
      // A rim bolt floating above a low building lands on the taller one behind it, so it sits on its own body.
      bolt(ctx, it.ax, dark ? top - 3 - 2 * z : (top + it.ay) / 2 + h / 2, h, !dark);
    });
  };

  return {
    q: 'How should a defence that has no power, and a building that low power slows, show it on the map?',
    why: 'Playtest finding F21: a Missile Battery held fire because its owner was short of power, and nothing on the map said so. '
      + 'Zero Hour default: only powered objects (the Patriot, the Gattling Cannon) go dark when demand exceeds supply; they stop firing, '
      + 'freeze their animation and show a looping lightning icon above the health bar (GameEngine/Source/GameClient/Drawable.cpp:3648-3687, '
      + 'Zero Hour source @ 0a05454). Its production buildings are not powered, keep working and show nothing. Wargrid also slows every '
      + 'production and construction to 50-80 % while power is short, a rule Zero Hour does not have. The page picks a favourite; '
      + 'the art lab confirms it in the game and F21 stays open until then. Here the left (USA) base is short of power, the right one is not.',
    look: 'A: a white lightning bolt with a dark under-stroke stands above each dark defence (Missile Battery, Rotary Gun Tower), '
      + 'steady, not blinking; every other building looks as today, and the slowdown shows only in the HUD power readout. '
      + 'B: the same bolt over each dark defence, plus a smaller dark bolt with a white rim (slowed, not stopped) over every building low power slows '
      + '(Headquarters, Supply Depot, Factory, Barracks, construction sites); power plants stay unmarked. '
      + 'Both are drawn marks over the world, not shape or colour changes; the tunnel hub (FRC) uses no power and never shows one.',
    rec: 'A',
    recWhy: 'The defence is the only piece that stops outright and needs a mark at the spot; a bolt over every building turns a short base into a field of icons for a slowdown the HUD already shows.',
    pics: { zoom: 1, today: {}, picked: {} },
    A: { name: 'Bolt over dark defences', data: { overlay: marks(false) } },
    B: { name: 'Bolt over defences and slowed buildings', data: { overlay: marks(true) } },
  };
})();
