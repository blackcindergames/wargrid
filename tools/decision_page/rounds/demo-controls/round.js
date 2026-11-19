DP.round({
  id: 'demo-controls',
  title: 'Demo: stage controls',
  steps: ['hud-window', 'map-ground', 'hud-tier', 'scene', 'clips'],
  render: { pass: { size: 'size', world: 'world', ground: 'ground', hud: 'hud', owner: 'you' } },
});
