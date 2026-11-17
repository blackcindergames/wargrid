window.CAND6 = window.CAND6 || {};
CAND6.paused = {
  q: 'A site whose builder has left keeps only its four corner posts, the same as a site just started: is this how a paused site should look?',
  why: 'Round 3 decided that posts alone mean just started or paused, but never drew a site paused part-way. Zero Hour has no paused look: when the dozer walks away the site keeps its risen body at its percent and looks like an active site (Zero Hour source @ 0a05454, DozerAIUpdate.cpp:2166-2173; only a dead dozer removes the working scaffold, :2238-2262). Wargrid today writes "N% paused" on the ground, text round 3 removed. Without this step a paused site looks like an active one, as in Zero Hour.',
  look: 'A: the paused Vehicle Factory (west base, left of the active one at 50 %, same owner) is its footprint and the four dark corner posts at the final height, nothing inside; the body is hidden while no builder works and comes back at the same percent when one returns. The percent of a paused site is read in the selection panel (HUD core). The active site beside it is unchanged. Cost: a site paused at 90 % looks like one just started, and an opponent no longer sees how far a paused site got, which Zero Hour shows. The today picture shows only the active site, because a paused site looks the same today.',
  rec: 'A',
  recWhy: 'It is round 3\'s rule as written: a site nobody is building shows as an empty frame, apart from one being built, though not apart from one just started.',
  view: { focus: [4, 27], place: [{ id: 'usa_factory_paused', cell: [1.5, 26.5] }] },
  pics: { zoom: 1, today: { focus: [4, 27] }, picked: { focus: [4, 27] } },
  A: {
    name: 'Posts alone',
    data: {
      shapes: {
        // Posts as the picked site draws them (postShapes in round6.html): picked usa_factory top 13.2 + 1, at ±(3 / 2 - 0.08).
        usa_factory_paused: {
          id: 'usa_factory_paused', name: 'Vehicle Factory', faction: 'usa', class: 'building', role: 'war_factory', layer: 'ground', footprint: [3, 3], has_turret: false,
          parts: [
            { name: 'post_back', angle: 'fixed', pivot: [0, 0], prims: [{ offset: [-1.42, -1.42, 0], size: [0.09, 0.09, 14.2], slot: 4, type: 'box' }] },
            { name: 'posts', angle: 'fixed', pivot: [0, 0], prims: [{ offset: [1.42, -1.42, 0], size: [0.09, 0.09, 14.2], slot: 4, type: 'box' }, { offset: [-1.42, 1.42, 0], size: [0.09, 0.09, 14.2], slot: 4, type: 'box' }, { offset: [1.42, 1.42, 0], size: [0.09, 0.09, 14.2], slot: 4, type: 'box' }] },
          ],
        },
      },
    },
  },
};
