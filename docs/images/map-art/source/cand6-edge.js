// Round 6 step 2: the map edge and the canvas beyond it. An overlay; the export carries only the palette values.
(function () {
  const SOUTH = [48, 51]; // the map's south corner in world cells: past every item of the base scene, left of the fog edge
  const FAR = -400; // the map's north edges, never on the stage
  const SHADE_FACE = 0.3;
  const FOG_ALPHA = 0.35; // round 5's picked fog (brightness 0.65); the overlay cannot read the selection
  function edge(ctx, scene, api) {
    const p = api.palette, h = p.EDGE_HEIGHT * api.zoom, [W, H] = SOUTH, P = api.project;
    const north = P(FAR, FAR), east = P(W, FAR), corner = P(W, H), west = P(FAR, H), down = (q) => [q[0], q[1] + h];
    ctx.beginPath();
    ctx.rect(0, 0, 1280, 720);
    [north, east, corner, west].forEach((q, i) => (i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1])));
    ctx.closePath();
    ctx.fillStyle = p.CANVAS;
    ctx.fill('evenodd');
    const lit = [west, corner, down(corner), down(west)], shade = [corner, east, down(east), down(corner)];
    api.fillPoly(ctx, lit, p.EDGE_SIDE, 0.5);
    api.fillPoly(ctx, shade, api.darken(p.EDGE_SIDE, SHADE_FACE), 0.5);
    ctx.beginPath();
    ctx.rect(scene.fogEdge, 0, 1280 - scene.fogEdge, 720);
    ctx.clip();
    [lit, shade].forEach((f) => api.fillPoly(ctx, f, `rgba(0,0,0,${FOG_ALPHA})`, 0));
  }
  window.CAND6.edge = {
    q: 'Which map edge and canvas colour should the board have?',
    why: 'Decided (user, 2026-11-15): slate side faces along the camera-facing map edges, the dark canvas beyond, no lit line on the top edge; open are the edge height and the canvas colour. Zero Hour draws no map edge (its maps carry a border band of terrain outside the playable area), so neither value has a Zero Hour default.',
    look: 'Both: past the two camera-facing map edges (south-west and south-east) the stage is canvas; a slate side face #425463 hangs straight down from each edge, the south-west face lit, the south-east face that colour darkened 0.3 (#2E3B45), the same light direction as unit sides and cliffs; no rim on the top edge. Faces in the fog are darkened like the ground; the canvas is not. Here the map ends one to two cells past the scene; at zoom 0.5 the canvas fills the bottom corners. '
      + 'A, thin edge on slate-black: edge 12 px at zoom 1 (6 at zoom 0.5, 24 at zoom 2; one and a half cliff heights), canvas #0C141A, the HUD v5 well colour, so the canvas and the HUD read as one family. '
      + 'B, deep edge on near-black: edge 24 px at zoom 1 (12 at zoom 0.5, 48 at zoom 2; three cliff heights), canvas #08090A, a hueless near-black, so the slate faces and the HUD panels stand off it.',
    numbers: [
      'Contrast, the page\'s formula; no bar is decided for edge faces or canvas pairs, so values under 3:1 are marked, not failed. Faces #425463 lit, #2E3B45 shaded; sand #A88E5C, dark ground #7B7566, fog factor 0.65, HUD slab #121C24.',
      'Where the map ends, ground on canvas (fogged = factor 0.65): A, canvas #0C141A: sand 5.92 | fogged sand 2.87 below 3:1 (no bar decided) | dark ground 4.05 | fogged dark 2.17 below 3:1 (no bar decided). B, canvas #08090A: sand 6.35 | fogged sand 3.08 | dark ground 4.34 | fogged dark 2.33 below 3:1 (no bar decided).',
      'A, canvas #0C141A: lit face on canvas 2.37 below 3:1 (no bar decided) | shaded 1.62 below 3:1 (no bar decided) | lit in fog 1.52 below 3:1 (no bar decided) | shaded in fog 1.21 below 3:1 (no bar decided) | canvas on HUD slab 1.08 below 3:1 (no bar decided).',
      'B, canvas #08090A: lit face on canvas 2.54 below 3:1 (no bar decided) | shaded 1.73 below 3:1 (no bar decided) | lit in fog 1.64 below 3:1 (no bar decided) | shaded in fog 1.30 below 3:1 (no bar decided) | canvas on HUD slab 1.16 below 3:1 (no bar decided).',
      'Faces on the grounds, both: lit on sand 2.50 below 3:1 (no bar decided) | on dark ground 1.71 below 3:1 (no bar decided) | shaded on sand 3.66 | on dark ground 2.51 below 3:1 (no bar decided); in fog, lit on sand 1.88 below 3:1 (no bar decided) | on dark 1.42 below 3:1 (no bar decided) | shaded on sand 2.37 below 3:1 (no bar decided) | on dark 1.79 below 3:1 (no bar decided).',
    ],
    rec: 'B',
    recWhy: 'At zoom 0.5 the 12 px edge reads as a slab; A\'s 6 px reads as a frame line.',
    view: { focus: [47.5, 50.5], anchor: [640, 600] },
    pics: { zoom: 0.5, today: {}, picked: {} },
    A: { name: 'Thin edge, slate-black canvas', data: { palette: { EDGE_HEIGHT: 12, EDGE_SIDE: '#425463', CANVAS: '#0C141A' }, overlay: edge } },
    B: { name: 'Deep edge, near-black canvas', data: { palette: { EDGE_HEIGHT: 24, EDGE_SIDE: '#425463', CANVAS: '#08090A' }, overlay: edge } },
  };
})();
