DP.step({
  key: 'map-ground',
  kind: 'pictures',
  question: 'Map art: which ground surface reads better?',
  why: 'A controls step on the map art page (round 6, step 1, its own step shots): G sand or dark ground and Z zoom go to that page; H lays the HUD states page over the map as a transparent layer (off, the slab, the kind rows).',
  look: 'Where to look: the ground between the buildings.',
  rec: 'A',
  recWhy: 'demo only.',
  render: { page: 'docs/images/map-art/source/round6.html', w: 1280, h: 720, hash: 'step=1&shot=1', pass: { ground: 'ground', zoom: 'zoom' } },
  controls: { ground: true, zoom: true, hud: ['slab', 'rows-footer'], fit: true, cvd: true },
  options: {
    A: { name: 'Option A of round 6 step 1', render: { params: { show: 'A' } }, notes: 'Live render of `round6.html#step=1&show=A&shot=1`.' },
    B: { name: 'Today', render: { params: { show: '0' } }, notes: 'Today\'s drawing (`show=0`).' },
  },
});
