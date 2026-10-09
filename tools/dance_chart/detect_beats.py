"""Detect the Seni Tari track's tempo and beats for BuildDanceChart.gd.

Usage: python tools/dance_chart/detect_beats.py Assets/Audio/BGM/minigame_senibudaya_menari.mp3
Writes tools/dance_chart/beats.json: {bpm, first_beat_offset, song_length, beats}
where beats are beat indices (0, 1, 2, ...) relative to the first beat.
"""
import json
import pathlib
import sys

import librosa

path = sys.argv[1]
y, sr = librosa.load(path, sr=None, mono=True)
tempo, frames = librosa.beat.beat_track(y=y, sr=sr)
times = librosa.frames_to_time(frames, sr=sr)
bpm = float(tempo)
offset = float(times[0]) if len(times) else 0.0
period = 60.0 / bpm
beats = [round((t - offset) / period, 2) for t in times]
out = {"bpm": bpm, "first_beat_offset": offset,
       "song_length": float(librosa.get_duration(y=y, sr=sr)), "beats": beats}
target = pathlib.Path(__file__).with_name("beats.json")
target.write_text(json.dumps(out, indent=1))
print(f"{target}: {bpm:.1f} bpm, offset {offset:.3f}s, {len(beats)} beats")
