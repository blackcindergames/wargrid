// Round 5 scene data, added next to scenes.js (not edited). World cells in the scenes.js frame (west base origin [4,16]).
window.SCENES5 = (function () {
  // A cliff line of raised (blocked) cells, two wide, along the front edge of the west base. Nothing stands on it, as in the game.
  const PLATEAU = { x: [0, 15], y: [30, 31] };
  const cells = [];
  for (let x = PLATEAU.x[0]; x <= PLATEAU.x[1]; x++) for (let y = PLATEAU.y[0]; y <= PLATEAU.y[1]; y++) cells.push([x, y]);
  // [role, x, y]: units in front of the line (y > 32) and beside it on the base side (y < 30). None on top: raised cells are blocked in the game.
  const UP = [];
  const DOWN = [['rifle', 3.0, 33.0], ['tank', 6.5, 33.2], ['rifle', 9.5, 32.8], ['rifle', 11.0, 33.5], ['rocket', 13.5, 32.6], ['rifle', 1.5, 32.7],
    ['rifle', 9.5, 28.6], ['rifle', 11.5, 28.9], ['tank', 13.5, 29.2], ['rifle', 2.5, 29.3]];
  // Focus (cells) of the zoomed-in camera for the terrain steps, and the cell where the fog edge stands (screen-x of this cell).
  const PATCH_FOCUS = [7, 31], DECOR_FOCUS = [17, 41];
  const FOG_EDGE = [24, 24];
  // Where the terrain agent's decoration patch (18 x 14 cells, its own frame) has its top-left corner in the world: in front of the west base, below the cliff patch.
  const DECOR_ORIGIN = [8, 34];
  const FOG_FOCUS = [24, 24];
  // Enemy (east) units placed on both sides of the fog edge: only those left of the edge are seen.
  const FOG_UNITS = [['tank', 25.2, 23.1], ['rifle', 26.0, 24.4], ['rifle', 27.0, 25.4], ['light', 28.6, 26.5], ['rifle', 23.2, 22.6], ['rocket', 25.6, 27.6]];
  return { PLATEAU, CELLS: cells, UP, DOWN, PATCH_FOCUS, DECOR_FOCUS, DECOR_ORIGIN, FOG_EDGE, FOG_FOCUS, FOG_UNITS };
})();
