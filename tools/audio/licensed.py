# SPDX-License-Identifier: GPL-3.0-or-later
"""Builds the licensed sound effects from the owner's packs; their files never enter this repository.

Usage: licensed.py PACKS_DIR OUT_DIR  (OUT_DIR/sfx/<stem>.wav imported as QOA, OUT_DIR/music/<stem>.ogg at Vorbis q5;
for builds: game/audio/licensed)
"""

import re
import subprocess
import sys
from pathlib import Path

from process import encode

LIGHT, HEAVY = "Sound Effects/Sci-Fi/Weapon/Light/", "Sound Effects/Sci-Fi/Weapon/Heavy/"
GUNSHOTS = "Sound Effects/Sci-Fi III/Weapon/Gunshots/"
GUN, CANNON, LAUNCH, IMPACT = -29.6, -25.8, -33.0, -30.8  # LUFS of the free sounds they replace
# stem: (pack file, LUFS, longest seconds, pitch); stems match `licensed` in sound_cues.gd.
SFX = {
    "usa_rifle": (LIGHT + "Laser Pistol Shot Automatic C.wav", GUN, 1.4, 1.0),
    "frc_rifle": (LIGHT + "Electro Rifle Shot Automatic C.wav", GUN, 1.4, 1.0),
    "china_militia": (LIGHT + "Pulse Shot Single A.wav", GUN, 1.2, 1.0),
    "usa_mg": (LIGHT + "Electromagnetic Rifle Shot Automatic D.wav", GUN, 1.4, 1.0),
    "frc_mg": (LIGHT + "Electro Rifle Shot Automatic D.wav", GUN, 2.0, 1.0),
    "china_rotary": (GUNSHOTS + "Plasma Turret Short Burst 001.wav", GUN, 2.5, 1.0),
    "china_rotary_tower": (GUNSHOTS + "Plasma Turret Long Burst 001.wav", GUN, 3.5, 1.0),
    "usa_cannon": (HEAVY + "Particle Gun A.wav", CANNON, 2.0, 1.0),
    "china_cannon": (HEAVY + "Proton Heavy Gun A.wav", CANNON, 2.0, 1.0),
    "frc_cannon": (HEAVY + "Plasmagun A.wav", CANNON, 1.5, 1.0),
    "usa_launch": (HEAVY + "Missile Launch B.wav", LAUNCH, 2.0, 1.0),
    "china_launch": (HEAVY + "Missile Launch A.wav", LAUNCH, 2.0, 1.0),
    "frc_launch": (HEAVY + "Missile Launch C.wav", LAUNCH, 2.0, 1.0),
    "usa_battery": (HEAVY + "Missile Launch C.wav", LAUNCH, 1.2, 1.3),
    "impact": (HEAVY + "Rocket Explosion A.wav", IMPACT, 2.5, 1.0),
}
MUSIC_DIR = "Music/Assault - Modern Warfare Music Pack/Tracks/MUS_"
INDUSTRIAL = "Music/Industrial Music Pack Vol. 1/"
# stem: pack file; names match LICENSED_MENU and LICENSED_PLAYLIST in music_player.gd.
MUSIC = {
    "night_infiltration": MUSIC_DIR + "Tension_NightInfiltration_Full_80BPM.wav",
    "assault_main_theme": MUSIC_DIR + "Combat_Assault_MainTheme_Full_85BPM.wav",
    "incoming": MUSIC_DIR + "Combat_Incoming_Full_100BPM.wav",
    "knuckles": INDUSTRIAL + "Knuckles (RT 1.164)/Industrial Knuckles Main.wav",
}
FADE_S = 0.3
PEAK_DB = -1.0


# shortcut: asetrate assumes a 44.1 kHz source (every pitched pack file is); read the rate before pitching others.
def shape(seconds: float, pitch: float) -> str:
    stages = ["aformat=channel_layouts=mono"]  # measured as written, so the level lands on target
    stages += [f"asetrate=44100*{pitch}", "aresample=44100"] if pitch != 1.0 else ["aresample=44100"]
    stages += [f"atrim=0:{seconds}", f"afade=t=out:st={round(seconds - FADE_S, 3)}:d={FADE_S}"]
    return ",".join(stages)


def measure(src: Path, chain: str) -> tuple[float, float]:
    err = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(src), "-af", f"{chain},ebur128=peak=true", "-f", "null", "-"],
        capture_output=True,
        text=True,
        check=True,
    ).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1]), float(re.findall(r"Peak:\s+(-?[\d.]+) dBFS", err)[-1])


def gain(lufs: float, peak: float, target: float) -> float:
    # A clipped file is worse than a slightly quiet one.
    return min(target - lufs, PEAK_DB - peak)


def build(packs: Path, out: Path) -> None:
    (out / "sfx").mkdir(parents=True, exist_ok=True)
    for stem, (rel, target, seconds, pitch) in SFX.items():
        src = packs / rel
        chain = shape(seconds, pitch)
        db = gain(*measure(src, chain), target)
        dest = out / "sfx" / f"{stem}.wav"
        af = f"{chain},volume={db:.2f}dB"
        cmd = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(src),
            "-af",
            af,
            "-c:a",
            "pcm_s16le",
            str(dest),
        ]
        subprocess.run(cmd, check=True)
        print(f"{stem}: {rel} {db:+.1f} dB")
    for stem, rel in MUSIC.items():
        encode(packs / rel, out / "music" / f"{stem}.ogg", stem, ("-q", "5"))
        print(f"{stem}: {rel}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    build(Path(sys.argv[1]).expanduser(), Path(sys.argv[2]))
