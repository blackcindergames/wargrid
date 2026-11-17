// Base view scene: two bases facing each other, built from definition footprints. Cells: x runs screen down-right, y screen down-left.
// The west base is laid out in its own frame, the east base is the same frame transposed (x and y swapped), so the layout is symmetric
// about the diagonal. Buildings are not mirrored themselves (doors face +y in both).
window.SCENES = (function () {
  // The east base sits SHIFT cells further along both axes: straight down the screen, so a zoom 0.5 camera can put one base near the top strip and the other near the dock.
  const SHIFT = 18;
  const WEST_ORIGIN = [4, 16], EAST_ORIGIN = [16 + SHIFT, 4 + SHIFT];
  // role -> [x, y] top-left cell in the base frame; key suffix = definition id suffix, "power_plant" and "defence" may repeat.
  const LAYOUT = [
    ['command_center', 0, 0], ['supply_center', 4, 0], ['power_plant', 8, 0], ['power_plant', 8, 3],
    ['factory', 0, 4], ['barracks', 4, 4], ['defence', 7, 6], ['defence', 3, 8],
  ];
  const TANKS = Array.from({ length: 8 }, (_, i) => [16.3, 16.5 + 0.95 * i]); // west frame, absolute world cells
  // Round 2 armies, west frame, absolute world cells: 36 infantry in one crowd (every third a rocket soldier), 6 light vehicles, 2 builders, 8 tanks.
  const ARMY = [];
  for (let j = 0; j < 6; j++) for (let i = 0; i < 6; i++) ARMY.push([(i + j) % 3 === 0 ? 'rocket' : 'rifle', 16.3 + 0.6 * i, 16.5 + 0.6 * j]);
  for (let k = 0; k < 6; k++) ARMY.push(['light', 20.6, 16.6 + k]);
  ARMY.push(['dozer', 16.3, 21.3], ['dozer', 16.3, 22.3]);
  for (let i = 0; i < 8; i++) ARMY.push(['tank', 18.4 + (i % 2), 21.2 + 0.95 * Math.floor(i / 2)]);
  // Round 3 extras, west frame unless noted. Piles: world cells (top-left), fill 100/60/25/5/0 %. Crates: west-frame world cells beside the west army
  // (transposed for the east army). Sites: base-frame position of a building under construction. Air: world cells under the two helicopters.
  const PILES = [{ size: 'big', cell: [22, 22], pct: 60 }, { size: 'big', cell: [29, 16], pct: 100 }, { size: 'small', cell: [27, 28], pct: 100 }, { size: 'small', cell: [30, 26], pct: 25 }, { size: 'small', cell: [24, 19], pct: 5 }, { size: 'small', cell: [33, 27], pct: 0 }];
  const CRATES = [[22.4, 16.8], [23.4, 17.6], [22.2, 19], [23.6, 19.8], [22.6, 20.8], [21.8, 17.9]];
  const SITES = [{ side: 'west', role: 'factory', local: [1, 10], rise: 0.5 }, { side: 'east', role: 'barracks', local: [1, 10], rise: 0.9 }];
  const AIR = [[24.5, 20], [31, 24.5]];
  const TRUCKS = [[21.8, 26.2, 0], [27.6, 21.4, 0], [28.8, 25.2, 1]];
  const transpose = ([x, y]) => [y + SHIFT, x + SHIFT];

  // fpOf(id) -> [fx, fy] or null when the faction has no such definition. Returns buildings with absolute top-left cells.
  function buildings(fpOf, west, east) {
    const out = [];
    for (const [side, faction, origin] of [['west', west, WEST_ORIGIN], ['east', east, EAST_ORIGIN]]) {
      for (const [suffix, x, y] of LAYOUT) {
        const id = faction + '_' + suffix, fp = fpOf(id);
        if (!fp) continue;
        const cell = side === 'west' ? [origin[0] + x, origin[1] + y] : [origin[0] + y, origin[1] + x];
        out.push({ id, side, suffix, cell, fp: side === 'west' ? fp : [fp[1], fp[0]] });
      }
    }
    return out;
  }
  function overlaps(items) {
    const bad = [];
    for (let i = 0; i < items.length; i++) for (let j = i + 1; j < items.length; j++) {
      const a = items[i], b = items[j];
      if (a.cell[0] < b.cell[0] + b.fp[0] && b.cell[0] < a.cell[0] + a.fp[0] && a.cell[1] < b.cell[1] + b.fp[1] && b.cell[1] < a.cell[1] + a.fp[1]) bad.push(a.id + ' x ' + b.id);
    }
    return bad;
  }
  const centreOf = (b) => [b.cell[0] + b.fp[0] / 2, b.cell[1] + b.fp[1] / 2];
  // Camera focus in cells: 0 = west base, 1 = east base, 2 = middle.
  const FOCUS = [[9.5, 20.5], [20.5 + SHIFT, 9.5 + SHIFT], [24, 24]];
  // Stage px the focus cell is drawn at: low on purpose so the front buildings reach the dock when zoomed in.
  const ANCHOR = [640, 395];
  return { ORIGINS: { west: WEST_ORIGIN, east: EAST_ORIGIN }, PILES, CRATES, SITES, AIR, TRUCKS, ARMY, ANCHOR, buildings, overlaps, centreOf, TANKS, transpose, FOCUS };
})();
