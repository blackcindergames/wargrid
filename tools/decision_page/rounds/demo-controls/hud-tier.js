DP.step({
  key: 'hud-tier',
  kind: 'pictures',
  question: 'HUD v5 cell shape, across the states',
  why: 'A controls step on the HUD v5 round 1 page: N and P (or the State list) step through its 13 states with their game-world backdrops, T switches the tier, and the picture takes the mouse: hover a cell to see its card. A click on the picture does not enlarge here; L does.',
  look: 'Where to look: the cells of the card, bottom right.',
  rec: 'A',
  recWhy: 'demo only.',
  interactive: true,
  render: { page: 'docs/images/hud-v5/source/round1.html', w: 1920, h: 1080, hash: 'shot={state}&size=1920&scale=1', pass: { tier: 'tier' } },
  controls: { state: ['build', 'none', 'one', 'many', 'factory', 'plant', 'full', 'builder', 'place', 'blocked', 'enemy', 'pile', 'site'], tier: true, fit: true, cvd: true },
  options: {
    A: { name: 'Round 1 cell A', render: { params: { picks: 'cell:A' } }, notes: '`round1.html#shot=<state>&picks=cell:A`.' },
    B: { name: 'Round 1 cell B', render: { params: { picks: 'cell:B' } }, notes: 'The same with `cell:B`.' },
  },
});
