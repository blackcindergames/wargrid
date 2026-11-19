DP.step({
  key: 'gallery',
  kind: 'gallery',
  question: 'Look through every state',
  why: 'A gallery step: one picture at a time, N and P or the thumbnails; a note under any item is optional and marks its thumbnail.',
  items: [
    { id: 'slab', label: 'Slab', caption: 'Live render of the slab state.', render: { state: 'slab' } },
    { id: 'notice', label: 'Notice', caption: 'Live render of the online notice.', render: { state: 'notice' } },
    { id: 'pile-world', label: 'Pile backdrop', caption: 'A still backdrop.', img: 'docs/images/hud-v5/source/worlds/w-pile.png' },
  ],
});
