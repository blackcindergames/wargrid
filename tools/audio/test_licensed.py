# SPDX-License-Identifier: GPL-3.0-or-later
import re
import unittest
from pathlib import Path

import licensed

CUES = Path(__file__).resolve().parents[2] / "game" / "scripts" / "presentation" / "sound_cues.gd"


class LicensedTest(unittest.TestCase):
    def test_every_cue_stem_is_built(self) -> None:
        stems = set(re.findall(r'"licensed": "(\w+)"', CUES.read_text()))
        self.assertEqual(stems, set(licensed.SFX))

    def test_every_music_path_is_built(self) -> None:
        player = (CUES.parent / "music_player.gd").read_text()
        self.assertEqual(set(re.findall(r"res://audio/licensed/music/(\w+)\.ogg", player)), set(licensed.MUSIC))

    def test_gain_never_clips(self) -> None:
        self.assertEqual(licensed.gain(-40.0, -20.0, -30.0), 10.0)
        self.assertEqual(licensed.gain(-40.0, -3.0, -30.0), 2.0)

    def test_shape_bakes_pitch_then_cuts(self) -> None:
        self.assertEqual(
            licensed.shape(1.2, 1.3),
            "aformat=channel_layouts=mono,asetrate=44100*1.3,aresample=44100,atrim=0:1.2,afade=t=out:st=0.9:d=0.3",
        )
        self.assertNotIn("asetrate", licensed.shape(2.0, 1.0))


if __name__ == "__main__":
    unittest.main()
