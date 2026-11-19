DP.step({
  key: 'wording',
  kind: 'wording',
  question: 'Edit the notice wording',
  why: 'A wording step: each field is recorded as you type (no Save button).',
  fields: [
    { id: 'waiting', label: 'Online notice', text: 'Waiting for player 2' },
    { id: 'freeze', label: 'Freeze card title', text: 'Match stopped' },
  ],
});
