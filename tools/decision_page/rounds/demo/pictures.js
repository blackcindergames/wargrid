DP.step({
  key: 'pictures',
  kind: 'pictures',
  question: 'Which backdrop reads better behind the HUD?',
  why: 'A pictures step: up to four options on one stage. Flip with A to D, or W for side by side. Letters are blind here: which one is today\'s look shows after you pick.',
  look: 'Where to look: the ground under the bottom-right slab.',
  rec: 'B',
  recWhy: 'demo only; any answer is fine.',
  blind: true,
  neutral: 'No difference',
  options: {
    A: { name: 'Backdrop one', img: 'docs/images/hud-v5/source/worlds/w-factory.png', reveal: 'today\'s look', notes: 'A picture recipe: a still image.' },
    B: { name: 'Backdrop two', img: 'docs/images/hud-v5/source/worlds/w-many.png', reveal: 'the candidate', notes: 'Another still.' },
    C: { name: 'Live render', render: { state: 'slab' }, reveal: 'a live render', notes: 'A live-render recipe: the states page in an iframe, so fonts and layout are real.' },
  },
});
