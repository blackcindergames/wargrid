// The committed pictures: name -> {shot: selection of the picture as it was shot, final: selection for the re-shoot, draw(cfg)}.
// cfg = {sel, scale}. Selections are {steps, fix4b, fix6}; a step left out does not apply (see round6.html).
const P13 = { ...R1, ...R3 };
const WORLD_PICKS = { band: 'A', owners: 'A', neon: '0', cliff: 'A', decor: 'B' };
const world = (r5) => mkSel({ ...P13, ...R4, ...r5 }, { fix4b: true });
const r13 = (extra) => mkSel({ ...P13, ...extra }, { legacy: true });
const TODAY_L = { ...ALL_TODAY, legacy: true };
const pic = (shot, build) => ({ shot, final: shot, draw: (c) => { CUR = c.sel; SCALE = c.scale; return build(); } });
const baseView = (over) => () => baseStage(over);
const worldView = (over) => () => baseStage({ mix: true, ...over });
const rowView = (key, over) => () => rowStage(key, over);

const PICS = {
  'base-usa-china-z05': pic(r13({}), baseView({ zoom: '0.5' })),
  'base-usa-z1': pic(r13({}), baseView({ zoom: '1', cam: 0, noCrates: true, focus: [14, 22], anchor: [640, 360] })),
  'base-china-z1': pic(r13({}), baseView({ zoom: '1', cam: 1, noCrates: true, focus: [34, 28], anchor: [640, 330] })),
  'base-frc-z1': pic(r13({}), baseView({ zoom: '1', owner: 2, pair: 2, cam: 0, focus: [14, 22], anchor: [640, 365] })),
  'buildings-today-z1': pic(TODAY_L, buildingsGrid),
  'buildings-picked-z1': pic(r13({}), buildingsGrid),
  'units-today-z2': pic(TODAY_L, unitsGrid),
  'units-picked-z2': pic(r13({}), unitsGrid),
  'placeholders-today-z1': pic(TODAY_L, placeholdersStage),
  'placeholders-picked-z1': pic(r13({}), placeholdersStage),
  'damage-today-z05': pic(r13({ damage: '0' }), rowView('damage', { zoom: '0.5' })),
  'damage-picked-z05': pic(r13({ damage: 'A' }), rowView('damage', { zoom: '0.5' })),
  'tanks-today-z2': pic(r13({ tanks: '0' }), rowView('tanks', { zoom: '2' })),
  'tanks-picked-z2': pic(r13({ tanks: 'A' }), rowView('tanks', { zoom: '2' })),
  'zoom2-today-z2': pic(r13({ zoom_high: '0' }), rowView('zoom_high', { zoom: '2' })),
  'zoom2-picked-z2': pic(r13({ zoom_high: 'A' }), rowView('zoom_high', { zoom: '2' })),
  'fix-buildings-today-z1': pic(r13({ fix_bldg: '0' }), rowView('fix_bldg', { zoom: '1' })),
  'fix-buildings-picked-z1': pic(r13({ fix_bldg: 'A' }), rowView('fix_bldg', { zoom: '1' })),
  'fix-units-today-z2': pic(r13({ fix_unit: '0' }), rowView('fix_unit', { zoom: '2' })),
  'fix-units-picked-z2': pic(r13({ fix_unit: 'A' }), rowView('fix_unit', { zoom: '2' })),
  'world-today-z05': pic(world(todayOf(R5)), worldView({ zoom: '0.5', dmg: true })),
  'world-picked-z05': pic(world({ ...WORLD_PICKS, fog: '0' }), worldView({ zoom: '0.5', dmg: true })),
  'world-picked-dark-z05': pic(world({ ...WORLD_PICKS, fog: '0' }), worldView({ zoom: '0.5', dmg: true, ground: 'dark' })),
  'world-fog-z1': pic(world({ ...WORLD_PICKS, fog: 'B' }), worldView({ zoom: '1', focusKey: 'fog' })),
  'world-cliff-decor-z1': pic(world({ ...WORLD_PICKS, fog: '0' }), worldView({ zoom: '1', focusKey: 'decor' })),
};
