# Kaiditya sizzle reel: music and SFX

This is an original trailer cue plus SFX. All of it is synthesized in numpy by `build_music.py`; no samples or downloaded audio are used.
The style mixes chiptune with orchestral pop, at 128 BPM in 4/4 (beat 0.46875 s, bar 1.875 s), in C major and A minor.
The music runs 24 bars (45.0 s), then a reverb ring-out that is silent by 47.5 s.

## Files
| file | what |
|---|---|
| `sizzle_music.wav` | Mastered track. 47.5 s, 48 kHz / 24-bit stereo, about -14 LUFS integrated, true peak -1.3 dBTP |
| `sizzle_music_nomaster.wav` | Pre-master mix, peak-normalised to -3 dBFS, with no compression or limiting |
| `whoosh_short.wav` `whoosh_long.wav` `impact_big.wav` `impact_small.wav` `riser_1bar.wav` `pop.wav` `sparkle.wav` `coin.wav` `swoosh_up.wav` | SFX stems. 48k/24-bit stereo, trimmed, true peak -3 dBFS. `riser_1bar` is exactly 1.875 s and peaks at its end |
| `cues.json` | Sections, stabs, impacts, button, silence gap, and every beat and downbeat time |
| `spectrogram.png` | Log-frequency spectrogram of the master, with an RMS strip and markers for sections and events |
| `build_music.py` | The full generator. Run it again to re-render everything |

## Re-render
```
/usr/bin/python3 build_music.py            # ~1 min, writes into this folder
/usr/bin/python3 build_music.py --no-sfx   # music only
KAI_DEBUG=1 /usr/bin/python3 build_music.py  # also prints stem balance per section
```
It needs numpy and PIL. It uses ffmpeg (`/opt/homebrew/bin/ffmpeg`) only for a final loudness cross-check.

## Hit points (seconds)
- The cold-open stabs land at 0.0, 0.9375, 1.875 and 2.8125.
- A short gap with a reverse-cymbal suck-in runs from 3.516 to 3.75.
- The impacts land at 3.75 (logo), 28.125 (boss drop) and 39.375 (end card).
- The silence gap runs from 27.656 to 28.125, holding only a reverse cymbal.
- The button lands at 43.125.

## Structure
The hero motif is C-G-A-G. Its minor form is A-E-F-E.
1. **Cold open (bars 1-2):** A filtered A1 bass pulses in 16ths while its filter opens. Clock ticks and hats play under a noise and pitch riser. Four orchestral stabs play on Am, Am, F and G, each made of brass, strings, timpani, a kick and a crash tick.
2. **Logo slam (bar 3):** A layered impact hits: a boom, a sub drop, a filtered noise burst and a crash. With it comes a C-major brass, supersaw and string chord, a C1 sub, and a glock shimmer arpeggio with a high string halo.
3. **Tagline (bars 4-5, C to Gsus4 to G):** The kick plays on beats 1 and 3, with soft hats and a shaker. A chip pulse lead states the motif, doubled by a glock an octave up. A bouncy triangle bass runs underneath.
4. **Sneak (bars 6-7, Am to F and G):** Pizzicato plays an oom-pah figure while a staccato pizz melody states the minor motif, echoed by chip blips. A muted sub, a soft kick, rim clicks, ticks and a dark pad sit underneath.
5. **Rescue (bars 8-9, F to G):** The full groove comes in, with warm 8th bass, strings and an arp. The motif returns with chip, soft supersaw and glock layers, plus a brass harmony a third below.
6. **Chase (bars 10-11, Am to F):** Four-on-the-floor kick, snare and clap on 2 and 4, and 16th hats. The bass drives in octave 8ths. A chip riff in a 3-3-2 pattern plays over syncopated brass stabs.
7. **Grapple / rooftops (bars 12-13, C to G):** A 16th saw-pluck arp enters through a ping-pong delay. Brass and chip play the motif, and a snare and tom fill closes bar 13.
8. **Build (bars 14-15, F to G):** A riser with a rising tone plays over a snare roll that speeds up from 8ths to 16ths to 32nds, rising in pitch. Pads and a supersaw arp pass through a resonant low-pass that opens from 350 Hz to 16 kHz. Beat 4 of bar 15 is hard silence except for a reverse cymbal.
9. **Boss drop (bars 16-19, Am to F to C to G):** The impact hits, then full drums with an orchestral hit and crash on every downbeat. The bass is a sub plus off-beat saw, and pads and bass pump under sidechain. A supersaw lead, doubled by brass an octave down and chip an octave up, plays the motif in minor (A-E-F-E) and then in major (C-G-A-G). It climbs A-B to C6.
10. **Hero City (bars 20-21, C to F to G):** Lighter, bouncy drums with claps and a shaker. A glock plays 16th arps, chip chords stab on the off-beats, a bass bounces in octaves, and a chip counter-melody plays over it.
11. **End card (bars 22-24):** The impact hits with a C chord. The motif plays triumphantly over C, F, Gsus4 and G, followed by a tom fill and a 16th-note breath. The button on C lands on bar 24 beat 1. It is a stab with an impact, crash, glock and string halo, and it rings out into a large hall.

## Signal chain
All saws, squares and pulses are band-limited additive oscillators, so there is no aliasing. Filter envelopes work by weighting each harmonic.
Drums are fully synthesized:
- The kick layers a pitch-swept body, a click and a sub.
- The snare layers a tonal body, band-passed noise and a snap.
- The clap is built from multiple bursts.
- The hats mix noise with metallic partials.

Every voice has an attack of at least 2 ms and a release of at least 5 ms, apart from deliberate drum transients.

Reverb is FFT convolution with synthetic IRs whose decay depends on frequency. There are three: a hall, a room, and a big hall used for the impacts and the button. There is also a dotted-8th ping-pong delay.
Sidechain ducking follows the kick, with a different depth in each section.

The master chain runs in this order:
1. A 28 Hz high-pass (minimum-phase)
2. Mono below about 140 Hz
3. A tilt EQ
4. A 1.8:1 RMS glue compressor, with about 4 dB of gain reduction at most
5. A soft clipper, 2x oversampled
6. A true-peak lookahead limiter at -1.3 dBTP, detecting at 4x
7. Iteration of the gain until integrated loudness reaches -14 LUFS (BS.1770)
