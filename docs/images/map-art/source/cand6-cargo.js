// Values from the page's own colour maths (contrast, simulate, minDistance), against today's owner set and step 4's two new sets.
window.CAND6.cargo = {
  q: 'Which colour should neutral supplies (pile pallets, the neutral owner) have?',
  why: 'Round 3 picked pale steel #DDE4E6, but it reaches only 2.44:1 on sand and sits 10.9 from today\'s pink owner under simulated deuteranopia (bar 20), so a colour-blind player can read a supply pile as a pink player. Only near-white reaches 3:1 on sand (pure white 3.14). Zero Hour has no neutral cargo colour to copy: its supply piles are textured models.',
  look: 'A Ivory #FFFFE1: pallet tops a faint warm cream, sides #BFBFA9, a shade warmer than the white map marks. B Pure white #FFFFFF: pallet tops white, sides grey #BFBFBF, the brightest a cargo colour can be and the same white as the map marks.',
  rec: 'B',
  recWhy: 'Depends on step 4: with either new owner set white keeps the widest colour-vision margin (28.9 against 21.6 for ivory, and 20.3 in fog); only today\'s set favours ivory (27.5 against 21.1).',
  numbers: [
    'Contrast on sand #A88E5C (bar 3): ivory 3.09, white 3.14, pale steel today 2.44; the ceiling is white.',
    'Contrast on the dark ground #7B7566: ivory 4.51, white 4.59; on the pile base slab and the HUD slab both above 16.',
    'Smallest colour-vision distance (normal, deuteranopia, protanopia; bar 20) to any owner, step 4 option A or B set: white 28.9 (green), ivory 21.6 (green).',
    'Same with today\'s owner set: ivory 27.5 (green), white 21.1 (pink), pale steel 10.9 (pink).',
    'Against the HUD amber: ivory 38.9, white 52.2.',
    'In fog (both x 0.65), against the fogged owners: new sets white 20.3, ivory 15.2; today\'s set ivory 19.4, white 15.0.',
    'Best near-white for the new sets is white itself; best across all three sets is #FFFFEC at 24.7.',
    'Ivory against white: 14.1, so ivory is the one that differs from the map marks.',
  ],
  uses: ['owners'],
  // Green west army beside the piles: green is the nearest owner to both candidates with step 4's sets.
  view: { owner: 1, focus: [25, 23] },
  pics: { zoom: 1, today: { owner: 1, focus: [25, 23] }, picked: { owner: 1, focus: [25, 23] } },
  A: { name: 'Ivory', data: { palette: { CARGO: '#ffffe1' } } },
  B: { name: 'Pure white', data: { palette: { CARGO: '#ffffff' } } },
};
