// Self-check of guide.html's counters: node docs/images/faction-guide-round/check_counters.js; exit 1 on a failure.
// For all 144 pairs of combat units, A lists B under Beats exactly when B lists A under Weak against.
const fs = require('fs');
const path = require('path');
const page = fs.readFileSync(path.join(__dirname, 'guide.html'), 'utf8');
const data = page.split('// data:start')[1].split('// data:end')[0];
const { U, verdict } = new Function(data + '\nreturn {U, verdict};')();
const combat = Object.keys(U).filter((k) => U[k].weapon);
let pairs = 0, failures = 0;
const count = { beats: 0, even: 0, weak: 0 };
for (const a of combat) {
  for (const b of combat) {
    pairs++;
    count[verdict(a, b)]++;
    if ((verdict(a, b) === 'beats') !== (verdict(b, a) === 'weak')) {
      failures++;
      console.log(`not reciprocal: ${a} ${verdict(a, b)} ${b}, ${b} ${verdict(b, a)} ${a}`);
    }
  }
}
console.log(`pairs ${pairs}, beats ${count.beats}, even ${count.even}, weak ${count.weak}, not reciprocal ${failures}`);
process.exit(pairs === 144 && failures === 0 ? 0 : 1);
