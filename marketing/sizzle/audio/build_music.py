#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kaiditya -- sizzle-reel trailer music + SFX generator.

100% synthesized with numpy (no samples, no downloaded audio). 48 kHz stereo, 24-bit WAV.
Style: chiptune-meets-orchestral-pop, 128 BPM, C major / A minor, one 4-note hero motif
(C-G-A-G, minor form A-E-F-E) threaded through every section.

Usage:
    /usr/bin/python3 build_music.py            # renders everything into this script's folder
    /usr/bin/python3 build_music.py --outdir X

Outputs: sizzle_music.wav (mastered, 47.5 s), sizzle_music_nomaster.wav, SFX stems, cues.json,
spectrogram.png.  Needs only numpy + PIL (ffmpeg optional, used for a loudness cross-check).
"""
import os
import sys
import json
import wave
import argparse
import subprocess
import numpy as np

# ----------------------------------------------------------------------------------------------
# Global timing
# ----------------------------------------------------------------------------------------------
SR = 48000
BPM = 128.0
BEAT = 60.0 / BPM            # 0.46875
BAR = 4 * BEAT               # 1.875
MUSIC_END = 24 * BAR         # 45.0
TOTAL = 47.5
N = int(round(TOTAL * SR))
FFMPEG = '/opt/homebrew/bin/ffmpeg'
SQ2 = np.sqrt(2.0)
RNG = np.random.default_rng(20260928)


def S(t):
    return int(round(t * SR))


def T(bar, beat=0.0):
    """bar is 1-indexed, beat is 0-indexed (float)."""
    return (bar - 1) * BAR + beat * BEAT


def mtof(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


_NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def nm(s):
    """'C5' -> 72, 'F#4' -> 66, 'Bb3' -> 58"""
    name, rest, acc = s[0], s[1:], 0
    if rest and rest[0] in '#b':
        acc = 1 if rest[0] == '#' else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + _NOTE[name] + acc


# ----------------------------------------------------------------------------------------------
# DSP helpers (numpy only)
# ----------------------------------------------------------------------------------------------
def nextpow2(n):
    return 1 << int(np.ceil(np.log2(max(n, 2))))


def fft_filter(x, gain_fn, pad=None):
    """Zero-phase filtering with an arbitrary magnitude response gain_fn(freqs)."""
    x = np.asarray(x, dtype=float)
    n = x.shape[-1]
    if pad is None:
        pad = min(max(n, 256), SR // 2)
    nfft = nextpow2(n + pad)
    X = np.fft.rfft(x, nfft, axis=-1)
    f = np.fft.rfftfreq(nfft, 1.0 / SR)
    X *= gain_fn(f)
    return np.fft.irfft(X, nfft, axis=-1)[..., :n]


def minphase_filter(x, gain_fn, pad=None):
    """Causal (minimum-phase) filtering with magnitude gain_fn(freqs): no pre-echo on transients.
    The minimum-phase spectrum is derived from the magnitude via the folded real cepstrum."""
    x = np.asarray(x, dtype=float)
    n = x.shape[-1]
    if pad is None:
        pad = SR
    nfft = nextpow2(n + pad)
    f = np.fft.rfftfreq(nfft, 1.0 / SR)
    logm = np.log(np.maximum(gain_fn(f), 1e-7))
    full = np.concatenate([logm, logm[-2:0:-1]])
    cep = np.fft.ifft(full).real
    w = np.zeros(nfft)
    w[0] = 1.0
    w[1:nfft // 2] = 2.0
    w[nfft // 2] = 1.0
    hmin = np.exp(np.fft.fft(cep * w))[:nfft // 2 + 1]
    X = np.fft.rfft(x, nfft, axis=-1) * hmin
    return np.fft.irfft(X, nfft, axis=-1)[..., :n]


def g_lp(fc, order=2):
    return lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def g_hp(fc, order=2):
    return lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))


def g_bp(lo, hi, order=2):
    a, b = g_hp(lo, order), g_lp(hi, order)
    return lambda f: a(f) * b(f)


def g_peak(fc, gain_db, bw_oct=1.0):
    return lambda f: 10.0 ** (gain_db / 20.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1.0) / fc) / (bw_oct / 2.0)) ** 2))


def g_shelf(fc, gain_db, high=True, slope=1.2):
    sgn = 1.0 if high else -1.0
    return lambda f: 10.0 ** (gain_db / 20.0 * 0.5 * (1 + np.tanh(sgn * slope * np.log2(np.maximum(f, 1.0) / fc))))


def g_mul(*gs):
    def fn(f):
        out = np.ones_like(f)
        for g in gs:
            out = out * g(f)
        return out
    return fn


def lpmag(r, q=0.707, poles=2):
    """Magnitude of a resonant 2-pole (or 4-pole) lowpass at normalised frequency r=f/fc."""
    r2 = r * r
    h = 1.0 / np.sqrt((1.0 - r2) ** 2 + (r / q) ** 2)
    if poles == 4:
        h = h / np.sqrt(1.0 + r2 * r2)
    return h


def tv_filter(x, mask_fn, nfft=1024, hop=256):
    """Time-varying spectral filter (STFT / overlap-add). mask_fn(freqs, times)->(frames, bins)."""
    x2 = np.atleast_2d(np.asarray(x, dtype=float))
    ch, n = x2.shape
    win = np.hanning(nfft + 1)[:-1]
    pad = nfft
    xp = np.pad(x2, ((0, 0), (pad, pad + nfft)))
    nfr = (xp.shape[1] - nfft) // hop + 1
    starts = hop * np.arange(nfr)
    times = (starts + nfft / 2 - pad) / SR
    freqs = np.fft.rfftfreq(nfft, 1.0 / SR)
    M = mask_fn(freqs, times)
    idx = starts[:, None] + np.arange(nfft)[None, :]
    out = np.zeros_like(xp)
    wsum = np.zeros(xp.shape[1])
    for c in range(ch):
        fr = xp[c][idx] * win
        F = np.fft.rfft(fr, axis=1) * M
        y = np.fft.irfft(F, nfft, axis=1) * win
        for i in range(nfr):
            out[c, starts[i]:starts[i] + nfft] += y[i]
    for i in range(nfr):
        wsum[starts[i]:starts[i] + nfft] += win ** 2
    out /= np.maximum(wsum, 1e-3)
    out = out[:, pad:pad + n]
    return out if np.asarray(x).ndim == 2 else out[0]


def pan_st(sig, pan=0.0):
    sig = np.asarray(sig, dtype=float)
    th = (pan + 1.0) * np.pi / 4.0
    gl, gr = np.cos(th) * SQ2, np.sin(th) * SQ2
    if sig.ndim == 2:
        if pan == 0.0:
            return sig
        return np.stack([sig[0] * min(1.0, gl), sig[1] * min(1.0, gr)])
    return np.stack([sig * gl, sig * gr])


def noise(n, ch=1):
    return RNG.standard_normal((ch, n)) if ch > 1 else RNG.standard_normal(n)


def fade_edges(x, a=0.0005, r=0.005):
    x = np.array(x, dtype=float)
    n = x.shape[-1]
    na, nr = min(S(a), n // 2), min(S(r), n // 2)
    if na > 0:
        x[..., :na] *= np.linspace(0, 1, na)
    if nr > 0:
        x[..., -nr:] *= np.linspace(1, 0, nr) ** 2
    return x


def adsr(dur, a=0.003, d=0.1, s=0.8, r=0.05):
    a = max(a, 0.002)
    r = max(r, 0.005)
    ng = max(S(dur), 2)
    nr = S(r)
    n = ng + nr
    t = np.arange(n) / SR
    e = np.empty(n)
    na = min(S(a), ng)
    e[:na] = 0.5 - 0.5 * np.cos(np.pi * t[:na] / a)
    e[na:] = s + (1 - s) * np.exp(-(t[na:] - a) / max(d, 1e-4))
    eg = e[ng - 1]
    x = np.arange(nr) / nr
    e[ng:] = eg * (1 - x) ** 2
    return e


def vibrato(n, rate=5.5, cents=10.0, delay=0.2, ramp=0.25):
    t = np.arange(n) / SR
    depth = np.clip((t - delay) / ramp, 0, 1) * cents
    return 2.0 ** (depth * np.sin(2 * np.pi * rate * t + RNG.uniform(0, 6.28)) / 1200.0)


# Harmonic tables for band-limited additive oscillators
_K = np.arange(1, 1025, dtype=float)
H_SAW = 1.0 / _K
H_SQR = np.where(_K % 2 == 1, 1.0 / _K, 0.0)
H_TRI = np.where(_K % 2 == 1, ((-1.0) ** ((_K - 1) // 2)) / _K ** 2, 0.0) * (8 / np.pi ** 2) * (np.pi / 2)


def H_PULSE(w):
    return np.sin(np.pi * _K * w) / _K


def osc_add(freq, n, H, fc=None, q=0.707, poles=2, fmax=18500.0, thresh=2.5e-4, phases=None):
    """Band-limited additive oscillator.  freq and fc may be scalars or per-sample arrays.
    No aliasing: harmonics above fmax (at the highest instantaneous pitch) are never generated."""
    if np.isscalar(freq):
        phi = 2 * np.pi * freq * np.arange(n) / SR
        fpk = fmean = float(freq)
        farr = False
    else:
        freq = np.asarray(freq, dtype=float)[:n]
        phi = 2 * np.pi * np.cumsum(freq) / SR
        fpk, fmean = float(freq.max()), float(freq.mean())
        farr = True
    fc_arr = fc is not None and not np.isscalar(fc)
    fce = None if fc is None else (float(np.max(fc)) if fc_arr else float(fc))
    out = np.zeros(n)
    kmax = min(len(H), int(fmax / fpk))
    if phases is None:
        phases = RNG.uniform(0, 2 * np.pi, kmax + 1)
    for k in range(1, kmax + 1):
        a = H[k - 1]
        if a == 0:
            continue
        if fc is None:
            g = a
        else:
            ge = abs(a) * lpmag(k * fmean / fce, q, poles)
            if ge < thresh:
                if k * fmean > fce:
                    break
                continue
            if fc_arr or farr:
                g = a * lpmag(k * (freq if farr else fpk) / fc, q, poles)
            else:
                g = a * lpmag(k * fpk / fc, q, poles)
        out += g * np.sin(k * phi + phases[k])
    return out


# ----------------------------------------------------------------------------------------------
# Instruments (all return mono (n,) or stereo (2,n) arrays at ~unit scale for vel=1)
# ----------------------------------------------------------------------------------------------
def supersaw(m, dur, vel=1.0, fc=7000.0, voices=7, rel=0.14, a=0.006, s=0.8, vib=True, sub=0.3):
    f0 = mtof(m)
    env = adsr(dur, a=a, d=0.3, s=s, r=rel)
    n = len(env)
    det = np.array([-24, -15, -7, 0, 7, 14, 23][:voices] if voices == 7 else np.linspace(-18, 18, voices))
    pans = np.linspace(-0.85, 0.85, len(det))
    vb = vibrato(n, 5.4, 9.0, 0.25, 0.3) if vib else 1.0
    out = np.zeros((2, n))
    for d, p in zip(det, pans):
        f = f0 * 2 ** ((d + RNG.uniform(-1.5, 1.5)) / 1200.0) * vb
        out += pan_st(osc_add(f, n, H_SAW, fc=fc, q=0.9), p)
    out /= np.sqrt(len(det)) * 1.6
    if sub:
        out += pan_st(osc_add(f0 / 2 * vb, n, H_SQR, fc=2200.0), 0) * sub * 0.6
    return out * env * vel


def chip_lead(m, dur, vel=1.0, rel=0.08, vib=True, width=0.25):
    f0 = mtof(m)
    env = adsr(dur, a=0.003, d=0.25, s=0.72, r=rel)
    n = len(env)
    H = H_PULSE(width) * 0.75 + H_PULSE(0.125) * 0.35
    t = np.arange(n) / SR
    bend = 2 ** (-25 * np.exp(-t / 0.012) / 1200.0)     # tiny chip "blip" into pitch
    vb = vibrato(n, 5.8, 14.0, 0.18, 0.2) if vib else 1.0
    out = np.zeros((2, n))
    for d, p in ((-4, -0.3), (4, 0.3)):
        f = f0 * 2 ** (d / 1200.0) * bend * vb
        out += pan_st(osc_add(f, n, H, fc=9000.0, q=0.6), p)
    return out * 0.45 * env * vel


def brass(m, dur, vel=1.0, bright=1.0, rel=0.18, a=0.012):
    f0 = mtof(m)
    env = adsr(dur, a=a, d=0.25, s=0.78, r=rel)
    n = len(env)
    t = np.arange(n) / SR
    swell = 1 - np.exp(-t / max(a * 1.5, 0.004))
    fc = (450 + (3200 * np.exp(-t / 0.16) + 1300) * bright * (0.55 + 0.45 * vel)) * (0.25 + 0.75 * swell)
    out = np.zeros((2, n))
    for d, p in ((-7, -0.35), (0, 0.0), (7, 0.35)):
        f = f0 * 2 ** ((d + RNG.uniform(-1, 1)) / 1200.0)
        out += pan_st(osc_add(f, n, H_SAW, fc=fc, q=1.1), p)
    return out * 0.42 * env * vel


def strings(m, dur, vel=1.0, fc=2600.0, a=0.15, rel=0.45, s=0.9):
    f0 = mtof(m)
    env = adsr(dur, a=a, d=0.4, s=s, r=rel)
    n = len(env)
    det = (-13, -5, 4, 12)
    pans = (-0.7, -0.25, 0.25, 0.7)
    out = np.zeros((2, n))
    for d, p in zip(det, pans):
        vb = vibrato(n, 4.8 + RNG.uniform(-0.3, 0.3), 6.0, 0.15, 0.4)
        f = f0 * 2 ** (d / 1200.0) * vb
        out += pan_st(osc_add(f, n, H_SAW, fc=fc, q=0.7, poles=4, thresh=4e-4), p)
    return out * 0.2 * env * vel


def pizz(m, dur, vel=1.0, bright=1.0):
    """Pizzicato / plucked string: additive with per-harmonic decay (brighter partials die first)."""
    f0 = mtof(m)
    ring = 0.55 * (220.0 / f0) ** 0.35
    n = S(min(dur, ring * 3) + 0.03)
    t = np.arange(n) / SR
    out = np.zeros(n)
    kmax = int(min(30, 14000 / f0))
    for k in range(1, kmax + 1):
        amp = k ** -1.4 * np.exp(-t * (1.0 / ring + 11.0 * k / bright))
        out += amp * np.sin(2 * np.pi * k * f0 * t + RNG.uniform(0, 6.28))
    tick = fft_filter(noise(n), g_bp(1500, 7000)) * np.exp(-t / 0.002) * 0.08
    out = out + tick
    gate = np.ones(n)
    ng = S(dur)
    if ng < n:
        nr = min(S(0.025), n - ng)
        gate[ng:ng + nr] = np.linspace(1, 0, nr) ** 2
        gate[ng + nr:] = 0
    return fade_edges(out * gate, 0.0015, 0.004) * 0.8 * vel


def arp_pluck(m, dur, vel=1.0, fc0=4200.0, decay=0.08):
    f0 = mtof(m)
    env = adsr(dur, a=0.002, d=0.13, s=0.22, r=0.07)
    n = len(env)
    t = np.arange(n) / SR
    fc = 450 + fc0 * np.exp(-t / decay)
    H = H_SAW * 0.65 + H_SQR * 0.45
    out = np.zeros((2, n))
    for d, p in ((-5, -0.45), (5, 0.45)):
        out += pan_st(osc_add(f0 * 2 ** (d / 1200.0), n, H, fc=fc, q=1.3), p)
    return out * 0.38 * env * vel


def glock(m, dur=1.4, vel=1.0):
    f0 = mtof(m)
    n = S(max(dur, 0.3))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in ((1.0, 1.0, 0.9), (2.0, 0.14, 0.45), (2.756, 0.38, 0.3),
                            (5.404, 0.16, 0.12), (8.933, 0.07, 0.06)):
        f = f0 * ratio
        if f < 19000:
            out += amp * np.exp(-t / dec) * np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))
    out += fft_filter(noise(n), g_hp(3000, 2)) * np.exp(-t / 0.0015) * 0.05
    return fade_edges(out, 0.0015, 0.02) * 0.55 * vel


def bass_sub(m, dur, vel=1.0, rel=0.04, a=0.004):
    f0 = mtof(m)
    env = adsr(dur, a=a, d=0.4, s=0.9, r=rel)
    n = len(env)
    t = np.arange(n) / SR
    ph = 2 * np.pi * f0 * t
    return (np.sin(ph) + 0.12 * np.sin(2 * ph)) * env * vel


def bass_saw(m, dur, vel=1.0, fc=800.0, env_amt=1200.0, q=1.0, sub=0.7, rel=0.035):
    f0 = mtof(m)
    env = adsr(dur, a=0.003, d=0.2, s=0.8, r=rel)
    n = len(env)
    t = np.arange(n) / SR
    fcv = fc + env_amt * np.exp(-t / 0.07)
    x = osc_add(f0, n, H_SAW, fc=fcv, q=q) * 0.55
    x += np.sin(2 * np.pi * f0 * t) * sub
    return np.tanh(1.2 * x) * env * vel


def bass_tri(m, dur, vel=1.0):
    f0 = mtof(m)
    env = adsr(dur, a=0.003, d=0.15, s=0.6, r=0.03)
    n = len(env)
    return osc_add(f0, n, H_TRI, fc=3000.0) * env * vel * 0.9


# ---------------------------------- drums ------------------------------------------------------
_cache = {}


def cached(key, fn, variants=1):
    if key not in _cache:
        _cache[key] = [fn() for _ in range(variants)]
    lst = _cache[key]
    return lst[RNG.integers(len(lst))]


def _norm(x, pk=1.0):
    return x * (pk / (np.max(np.abs(x)) + 1e-12))


def kick_gen(decay=0.30, punch=1.0, drive=2.0, f_end=47.0):
    n = S(decay * 2.6 + 0.05)
    t = np.arange(n) / SR
    f = f_end + 155 * np.exp(-t / 0.026) + 300 * np.exp(-t / 0.003)
    phi = 2 * np.pi * np.cumsum(f) / SR
    amp = np.where(t < 0.025, 1.0, np.exp(-(t - 0.025) / decay))
    body = np.tanh(drive * np.sin(phi) * amp) / np.tanh(drive)
    click = fft_filter(noise(n), g_bp(1800, 9000)) * np.exp(-t / 0.0022) * 0.28 * punch
    tick = np.sin(2 * np.pi * 2600 * t) * np.exp(-t / 0.0012) * 0.18 * punch
    return _norm(fade_edges(body + click + tick, 0.0003, 0.012))


def kick(kind='std'):
    params = {'std': dict(decay=0.24), 'big': dict(decay=0.34, drive=2.6, f_end=46.0),
              'soft': dict(decay=0.22, punch=0.5, drive=1.5), 'stab': dict(decay=0.35, drive=3.0)}[kind]
    return cached(('kick', kind), lambda: kick_gen(**params))


def snare_gen(tune=1.0, decay=0.17):
    n = S(0.7)
    t = np.arange(n) / SR
    f1 = (178 + 90 * np.exp(-t / 0.01)) * tune
    body = np.sin(2 * np.pi * np.cumsum(f1) / SR) * np.exp(-t / 0.065) * 0.75
    body += np.sin(2 * np.pi * 332 * tune * t) * np.exp(-t / 0.04) * 0.3
    nz = fft_filter(noise(n), g_mul(g_hp(1000, 2), g_lp(12000, 1), g_peak(4800, 4, 1.6)))
    nz = _norm(nz) * np.exp(-t / decay) * 0.8
    snap = _norm(fft_filter(noise(n), g_bp(2500, 9000))) * np.exp(-t / 0.004) * 0.5
    return _norm(fade_edges(np.tanh(1.4 * (body + nz + snap)), 0.0003, 0.02))


def snare(tune=1.0):
    tq = round(tune, 2)
    return cached(('snare', tq), lambda: snare_gen(tune=tq), 4)


def clap_gen():
    n = S(0.55)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for c in range(2):
        nz = _norm(fft_filter(noise(n), g_mul(g_bp(900, 7000, 2), g_peak(1600, 5, 1.2))))
        env = np.zeros(n)
        for i, o in enumerate((0.0, 0.0085, 0.0165, 0.026)):
            o2 = o + (0.0007 * c)
            env += (t >= o2) * np.exp(-np.maximum(t - o2, 0) / 0.0045) * (0.8 + 0.1 * i)
        env += (t >= 0.026) * np.exp(-np.maximum(t - 0.026, 0) / 0.14) * 0.55
        out[c] = nz * env
    return _norm(fade_edges(out, 0.0002, 0.02))


def clap():
    return cached('clap', clap_gen, 3)


def hat_gen(open_=False):
    n = S(0.7 if open_ else 0.14)
    t = np.arange(n) / SR
    nz = _norm(fft_filter(noise(n), g_mul(g_hp(7000, 3), g_peak(10500, 3, 1.2))))
    metal = np.zeros(n)
    for f in (3520, 4970, 6340, 7900, 9150, 11300):
        metal += np.sign(np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28))) * 0.2
    metal = _norm(fft_filter(metal, g_mul(g_hp(7500, 3), g_lp(16000, 2))))
    dec = 0.3 if open_ else 0.032
    env = np.exp(-t / dec)
    return _norm(fade_edges((nz * 0.75 + metal * 0.35) * env, 0.0003, 0.01))


def hat(open_=False):
    return cached(('hat', open_), lambda: hat_gen(open_), 6)


def shaker():
    def g():
        n = S(0.12)
        t = np.arange(n) / SR
        nz = _norm(fft_filter(noise(n), g_bp(4500, 11000, 2)))
        env = (1 - np.exp(-t / 0.008)) * np.exp(-t / 0.04)
        return _norm(fade_edges(nz * env, 0.001, 0.01))
    return cached('shaker', g, 6)


def rim():
    def g():
        n = S(0.1)
        t = np.arange(n) / SR
        x = np.sin(2 * np.pi * 1720 * t) * np.exp(-t / 0.009) + 0.6 * np.sin(2 * np.pi * 830 * t) * np.exp(-t / 0.014)
        x += _norm(fft_filter(noise(n), g_bp(2000, 7000))) * np.exp(-t / 0.003) * 0.5
        return _norm(fade_edges(x, 0.0002, 0.01))
    return cached('rim', g, 2)


def tick(hi=True):
    def g():
        n = S(0.05)
        t = np.arange(n) / SR
        f = 3300 if hi else 2500
        x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.004)
        x += _norm(fft_filter(noise(n), g_hp(5000, 2))) * np.exp(-t / 0.0015) * 0.4
        return _norm(fade_edges(x, 0.0002, 0.005))
    return cached(('tick', hi), g, 2)


def tom(f0=110.0, decay=0.35):
    def g():
        n = S(decay * 3)
        t = np.arange(n) / SR
        f = f0 * (1 + 0.55 * np.exp(-t / 0.035))
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)
        x += 0.25 * np.sin(2 * np.pi * np.cumsum(f * 1.6) / SR) * np.exp(-t / (decay * 0.5))
        x += _norm(fft_filter(noise(n), g_bp(300, 4000))) * np.exp(-t / 0.012) * 0.35
        return _norm(fade_edges(np.tanh(1.5 * x), 0.0003, 0.02))
    return cached(('tom', round(f0), decay), g, 1)


def timpani(m, decay=1.2):
    def g():
        f0 = mtof(m)
        n = S(decay * 3)
        t = np.arange(n) / SR
        f = f0 * (1 + 0.04 * np.exp(-t / 0.06))
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = np.zeros(n)
        for r, a, d in ((1.0, 1.0, 1.0), (1.504, 0.5, 0.7), (1.742, 0.25, 0.5), (2.0, 0.3, 0.5), (2.44, 0.12, 0.3)):
            x += a * np.sin(r * ph + RNG.uniform(0, 6.28)) * np.exp(-t / (decay * d))
        x += _norm(fft_filter(noise(n), g_bp(150, 2500))) * np.exp(-t / 0.02) * 0.5
        return _norm(fade_edges(x, 0.0005, 0.05))
    return cached(('timp', m, decay), g, 1)


def crash(length=3.0, bright=1.0, seed=None):
    n = S(length)
    t = np.arange(n) / SR
    out = np.zeros((2, n))
    for c in range(2):
        nz = _norm(fft_filter(noise(n), g_mul(g_hp(3200 * bright, 2), g_peak(7500, 4, 1.5), g_lp(16000, 2))))
        part = np.zeros(n)
        for _ in range(28):
            f = RNG.uniform(2500, 11000)
            part += np.sin(2 * np.pi * f * t + RNG.uniform(0, 6.28)) * np.exp(-t / RNG.uniform(0.3, 1.4))
        part = _norm(part)
        env = np.exp(-t / (0.85 * length / 3.0)) * 0.8 + np.exp(-t / 0.06) * 0.4
        out[c] = (nz * 0.8 + part * 0.25) * env
    return _norm(fade_edges(out, 0.0008, 0.3))


def rev_cymbal(length=1.2):
    c = crash(length + 0.3)
    r = c[:, ::-1][:, -S(length):]
    r = r * np.linspace(0, 1, r.shape[1]) ** 1.5     # extra swell shape
    return fade_edges(_norm(r), 0.02, 0.0015)


# ---------------------------------- FX designers ----------------------------------------------
def impact_big_gen(length=3.0):
    n = S(length)
    t = np.arange(n) / SR
    f = 33 + 75 * np.exp(-t / 0.07) + 230 * np.exp(-t / 0.006)
    boom = np.tanh(2.2 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.75)) * 0.9
    fd = 26 + 55 * np.exp(-t / 0.55)
    subdrop = np.sin(2 * np.pi * np.cumsum(fd) / SR) * np.exp(-t / 1.3) * (1 - np.exp(-t / 0.01)) * 0.55
    nzs = noise(n, 2)
    fcf = lambda tt: 300 + 9000 * np.exp(-np.maximum(tt, 0) / 0.18)
    body = tv_filter(nzs, lambda fr, tt: lpmag(fr[None, :] / fcf(tt)[:, None], 0.8, 2))
    body = _norm(body) * np.exp(-t / 0.35) * 0.55
    cr = crash(length) * 0.35
    click = np.sin(2 * np.pi * 1900 * t) * np.exp(-t / 0.0015) * 0.3
    mono = boom + subdrop + click
    out = body + cr + mono[None, :]
    return _norm(fade_edges(out, 0.0003, 0.4))


def impact_small_gen(length=0.7):
    n = S(length)
    t = np.arange(n) / SR
    f = 50 + 90 * np.exp(-t / 0.04) + 250 * np.exp(-t / 0.004)
    boom = np.tanh(2.0 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18))
    nzs = noise(n, 2)
    body = _norm(fft_filter(nzs, g_mul(g_lp(4500, 2), g_hp(200, 1)))) * np.exp(-t / 0.08) * 0.5
    click = np.sin(2 * np.pi * 2200 * t) * np.exp(-t / 0.0012) * 0.25
    out = body + (boom * 0.9 + click)[None, :]
    return _norm(fade_edges(out, 0.0003, 0.15))


def riser_gen(length, f_lo=220.0, f_hi=9000.0, tone_lo=110.0, tone_hi=880.0, curve=2.2, tone_amt=0.35):
    """Filtered-noise riser + pitch-rising tone.  Peaks at its final sample."""
    n = S(length)
    t = np.arange(n) / SR
    x = t / length
    nz = noise(n, 2)

    def mask(fr, tt):
        xx = np.clip(tt / length, 0, 1)
        c = f_lo * (f_hi / f_lo) ** (xx ** 1.3)
        lf = np.log2(np.maximum(fr[None, :], 20) / c[:, None])
        bp = np.exp(-0.5 * (lf / 0.75) ** 2)
        floor = 0.12 * (lf < 0)
        return bp + floor
    nzf = _norm(tv_filter(nz, mask))
    amp = x ** curve
    out = nzf * amp
    if tone_amt:
        ftone = tone_lo * (tone_hi / tone_lo) ** (x ** 1.4)
        fct = 400 + 5000 * x ** 1.5
        tl = osc_add(ftone * 2 ** (-6 / 1200), n, H_SAW, fc=fct, q=2.0)
        tr = osc_add(ftone * 2 ** (6 / 1200), n, H_SAW, fc=fct, q=2.0)
        tone = _norm(np.stack([tl, tr])) * (x ** 1.6)
        out = out + tone * tone_amt
    out = fade_edges(out, 0.05, 0.0015)
    return _norm(out)


def whoosh_gen(length, f_peak=4000.0, f_lo=400.0, peak_pos=0.45, pan_sweep=0.8):
    n = S(length)
    t = np.arange(n) / SR
    x = t / length

    def shape(xx):
        xx = np.clip(xx, 0, 1)
        up = np.clip(xx / peak_pos, 0, 1)
        dn = np.clip((1 - xx) / (1 - peak_pos), 0, 1)
        return np.where(xx < peak_pos, np.sin(up * np.pi / 2) ** 2, np.sin(dn * np.pi / 2) ** 1.5)
    nz = noise(n, 2)

    def mask(fr, tt):
        s = shape(tt / length)
        c = f_lo * (f_peak / f_lo) ** s
        lf = np.log2(np.maximum(fr[None, :], 20) / c[:, None])
        return np.exp(-0.5 * (lf / 0.9) ** 2)
    y = _norm(tv_filter(nz, mask)) * shape(x)
    p = -pan_sweep + 2 * pan_sweep * x
    th = (p + 1) * np.pi / 4
    y = np.stack([y[0] * np.cos(th), y[1] * np.sin(th)]) * SQ2
    return _norm(fade_edges(y, 0.003, 0.01))


# ----------------------------------------------------------------------------------------------
# Effects
# ----------------------------------------------------------------------------------------------
def make_ir(length=3.0, t60_lo=2.4, t60_hi=0.9, predelay=0.022, seed=7, hp=160.0, lp=11000.0):
    rng = np.random.default_rng(seed)
    n = S(length)
    t = np.arange(n) / SR
    nz = rng.standard_normal((2, n))
    nfft = nextpow2(n)
    F = np.fft.rfft(nz, nfft, axis=1)
    fr = np.fft.rfftfreq(nfft, 1.0 / SR)
    centers = np.array([150.0, 600.0, 2400.0, 9000.0])
    lf = np.log2(np.maximum(fr, 10.0))
    W = np.exp(-0.5 * ((lf[None, :] - np.log2(centers)[:, None]) / 1.0) ** 2)
    W /= W.sum(axis=0, keepdims=True)
    ir = np.zeros((2, n))
    for i in range(len(centers)):
        t60 = t60_lo * (t60_hi / t60_lo) ** (i / (len(centers) - 1))
        band = np.fft.irfft(F * W[i], nfft, axis=1)[:, :n]
        ir += band * np.exp(-6.9078 * t / t60)
    ir *= 1 - np.exp(-t / 0.012)
    ir = fft_filter(ir, g_mul(g_hp(hp, 2), g_lp(lp, 1)))
    ir = np.pad(ir, ((0, 0), (S(predelay), 0)))
    ir /= np.sqrt(np.mean(np.sum(ir ** 2, axis=1)))
    return ir


def convolve(x, ir):
    n, m = x.shape[1], ir.shape[1]
    nfft = nextpow2(n + m)
    X = np.fft.rfft(x, nfft, axis=1)
    H = np.fft.rfft(ir, nfft, axis=1)
    return np.fft.irfft(X * H, nfft, axis=1)[:, :n]


def pingpong(x, delay_s, fb=0.45, taps=7, hp=350.0, lp=5500.0):
    d = S(delay_s)
    n = x.shape[1]
    src = x.mean(axis=0)
    y = np.zeros_like(x)
    for k in range(1, taps + 1):
        sh = k * d
        if sh >= n:
            break
        y[(k - 1) % 2, sh:] += src[:n - sh] * fb ** (k - 1)
    return fft_filter(y, g_bp(hp, lp, 1))


def running_min_centered(x, w):
    """out[i] = min(x[i-h .. i+h]), w = 2h+1 (van Herk / Gil-Werman, vectorised)."""
    h = w // 2
    xp = np.pad(x, (h, h), constant_values=np.inf)
    n = len(xp)
    m = int(np.ceil(n / w)) * w
    xp2 = np.pad(xp, (0, m - n), constant_values=np.inf).reshape(-1, w)
    pre = np.minimum.accumulate(xp2, axis=1).ravel()
    suf = np.minimum.accumulate(xp2[:, ::-1], axis=1)[:, ::-1].ravel()
    j = np.arange(len(x))
    return np.minimum(suf[j], pre[j + w - 1])


def movavg_centered(x, w, edge=1.0):
    h = w // 2
    xp = np.pad(x, (h + 1, h), constant_values=edge)
    c = np.cumsum(xp)
    return (c[w:] - c[:-w])[:len(x)] / w


def oversample(x, factor):
    n = x.shape[-1]
    X = np.fft.rfft(x, axis=-1)
    return np.fft.irfft(X, n * factor, axis=-1) * factor


def downsample(y, factor, n):
    Y = np.fft.rfft(y, axis=-1)
    return np.fft.irfft(Y[..., :n // 2 + 1], n, axis=-1) / factor


def true_peak_env(x, factor=4):
    y = oversample(x, factor)
    n = x.shape[-1]
    pk = np.abs(y[..., :n * factor]).reshape(x.shape[0], n, factor).max(axis=2).max(axis=0)
    return pk


def true_peak_db(x):
    return 20 * np.log10(np.max(true_peak_env(x)) + 1e-12)


def glue_comp(x, thr_db=-14.0, ratio=2.0, att=0.012, rel=0.16, knee=6.0, blk=64):
    n = x.shape[1]
    pw = (x[0] ** 2 + x[1] ** 2) / 2
    nb = int(np.ceil(n / blk))
    pw = np.pad(pw, (0, nb * blk - n)).reshape(nb, blk).mean(axis=1)
    pw = np.convolve(pw, np.ones(6) / 6, mode='same')          # ~8 ms RMS window
    lvl = 10 * np.log10(pw + 1e-12) + 3.0                        # sine-ish crest compensation
    over = lvl - thr_db
    s = 1 - 1 / ratio
    gr = np.where(over <= -knee / 2, 0.0,
                  np.where(over >= knee / 2, over * s, s * (over + knee / 2) ** 2 / (2 * knee)))
    aa = np.exp(-blk / (SR * att))
    ar = np.exp(-blk / (SR * rel))
    g = 0.0
    sm = np.empty(nb)
    for i, v in enumerate(gr):
        c = aa if v > g else ar
        g = c * g + (1 - c) * v
        sm[i] = g
    centers = (np.arange(nb) + 0.5) * blk
    gdb = -np.interp(np.arange(n), centers, sm)
    return x * 10 ** (gdb / 20.0), float(np.max(sm))


def soft_clip(x, knee_db=-4.0, ceil_db=-0.6):
    t = 10 ** (knee_db / 20.0)
    c = 10 ** (ceil_db / 20.0)
    a = np.abs(x)
    y = np.where(a <= t, a, t + (c - t) * np.tanh((a - t) / (c - t)))
    return np.sign(x) * y


def limiter(x, ceil_db=-1.3, look=0.0025, hold=0.035):
    pk = true_peak_env(x)
    c = 10 ** (ceil_db / 20.0)
    g = np.minimum(1.0, c / np.maximum(pk, 1e-9))
    w1 = 2 * S(look) + 1
    g = movavg_centered(running_min_centered(g, w1), w1)
    w2 = 2 * S(hold) + 1
    g = movavg_centered(running_min_centered(g, w2), w2)
    return x * g[None, :], float(20 * np.log10(np.min(g)))


# ---------------------------------- loudness (ITU-R BS.1770-4) ---------------------------------
def lufs_integrated(x):
    n = x.shape[1]
    nfft = nextpow2(n)
    X = np.fft.rfft(x, nfft, axis=1)
    w = 2 * np.pi * np.fft.rfftfreq(nfft, 1.0 / SR) / SR
    z1, z2 = np.exp(-1j * w), np.exp(-2j * w)
    h1 = (1.53512485958697 - 2.69169618940638 * z1 + 1.19839281085285 * z2) / (1 - 1.69065929318241 * z1 + 0.73248077421585 * z2)
    h2 = (1 - 2 * z1 + z2) / (1 - 1.99004745483398 * z1 + 0.99007225036621 * z2)
    y = np.fft.irfft(X * np.abs(h1 * h2), nfft, axis=1)[:, :n]
    blk, hop = S(0.4), S(0.1)
    c = np.cumsum(np.pad(y ** 2, ((0, 0), (1, 0))), axis=1)
    starts = np.arange(0, n - blk + 1, hop)
    ms = ((c[:, starts + blk] - c[:, starts]) / blk).sum(axis=0)
    ld = -0.691 + 10 * np.log10(ms + 1e-20)
    g1 = ms[ld > -70]
    rel = -0.691 + 10 * np.log10(g1.mean()) - 10
    g2 = ms[(ld > -70) & (ld > rel)]
    return -0.691 + 10 * np.log10(g2.mean())


def short_term_lufs(x, t0, t1):
    seg = x[:, S(t0):S(t1)]
    return lufs_integrated(np.pad(seg, ((0, 0), (0, max(0, S(0.5) - seg.shape[1])))))


# ----------------------------------------------------------------------------------------------
# Mixer
# ----------------------------------------------------------------------------------------------
class Mix:
    BUSES = ('drums', 'bass', 'music', 'lead', 'fx', 'sweep', 'post', 'hall', 'room', 'delay', 'bighall')

    def __init__(self):
        self.b = {k: np.zeros((2, N)) for k in self.BUSES}
        self.kicks = []

    def add(self, bus, sig, t, gain=1.0, pan=0.0, sends=()):
        st = pan_st(sig, pan) * gain
        i0 = S(t)
        if i0 < 0:
            st = st[:, -i0:]
            i0 = 0
        i1 = min(N, i0 + st.shape[1])
        if i1 <= i0:
            return
        seg = st[:, :i1 - i0]
        self.b[bus][:, i0:i1] += seg
        for name, amt in sends:
            self.b[name][:, i0:i1] += seg * amt


def hv(v, spread=0.08):
    """humanised velocity"""
    return v * (1 + RNG.uniform(-spread, spread))


# ----------------------------------------------------------------------------------------------
# Score
# ----------------------------------------------------------------------------------------------
# chord voicings: pad (4 notes around C4), brass (wide), bass root (octave 1)
CH = {
    'Am':    dict(pad=[57, 60, 64, 69], brass=[45, 52, 57, 60, 64, 69], root=33, tones=[57, 60, 64]),
    'F':     dict(pad=[57, 60, 65, 69], brass=[41, 48, 53, 57, 60, 65], root=29, tones=[53, 57, 60]),
    'C':     dict(pad=[55, 60, 64, 67], brass=[48, 55, 60, 64, 67, 72], root=36, tones=[60, 64, 67]),
    'G':     dict(pad=[55, 59, 62, 67], brass=[43, 50, 55, 59, 62, 67], root=31, tones=[55, 59, 62]),
    'Gsus4': dict(pad=[55, 60, 62, 67], brass=[43, 50, 55, 60, 62, 67], root=31, tones=[55, 60, 62]),
}

# Hero motif (beats relative to phrase start, durations in beats)
MOTIF = [('C5', 0, 1.5), ('G5', 1.5, 1.5), ('A5', 3, 1.0), ('G5', 4, 4.0)]
MOTIF_MIN = [('A4', 0, 1.5), ('E5', 1.5, 1.5), ('F5', 3, 1.0), ('E5', 4, 2.5),
             ('G4', 6.5, 0.5), ('A4', 7, 0.5), ('B4', 7.5, 0.5)]

HALL = 'hall'
BIG = 'bighall'
ROOM = 'room'
DLY = 'delay'


def play_pad(mx, chord, bar, beat, beats, vel=0.6, fc=2600.0, a=0.15, rel=0.45, bus='music', sends=((HALL, 0.25),)):
    for m in CH[chord]['pad']:
        mx.add(bus, strings(m, beats * BEAT, vel, fc=fc, a=a, rel=rel), T(bar, beat), sends=sends)


def orch_hit(mx, t, chord, vel=1.0, length=0.2, timp=True, kick_kind='stab', rel=0.3, gain=1.0, big=0.0, timp_decay=0.8):
    """Short orchestral stab: brass + string chord + timpani + kick + noise snap."""
    for i, m in enumerate(CH[chord]['brass']):
        mx.add('music', brass(m, length, vel, bright=1.3, rel=rel, a=0.004), t, gain=0.55 * gain,
               pan=(i - 2.5) * 0.12, sends=((HALL, 0.35), (BIG, big)))
    for m in CH[chord]['pad']:
        mx.add('music', strings(m + 12, length, vel, fc=4500, a=0.004, rel=rel), t, gain=0.5 * gain,
               sends=((HALL, 0.35), (BIG, big)))
    if timp:
        mx.add('drums', timpani(CH[chord]['root'] + 12, timp_decay), t, gain=0.7 * gain, sends=((HALL, 0.2),))
    mx.add('drums', kick(kick_kind), t, gain=0.9 * gain)
    snap = cached('orchsnap', lambda: _norm(fade_edges(
        fft_filter(noise(S(0.3), 2), g_bp(500, 7000)) * np.exp(-np.arange(S(0.3)) / SR / 0.05), 0.0003, 0.02)), 2)
    mx.add('fx', snap, t, gain=0.3 * gain, sends=((HALL, 0.4),))


def lead_line(mx, notes, bar, inst='saw', vel=1.0, gain=1.0, oct_shift=0, legato=0.96, sends=((HALL, 0.22), (DLY, 0.18))):
    for name, b0, dur in notes:
        m = nm(name) + 12 * oct_shift
        t = T(bar, b0)
        d = dur * BEAT * legato
        if inst == 'saw':
            sig = supersaw(m, d, vel, fc=7500.0)
        elif inst == 'sawsoft':
            sig = supersaw(m, d, vel, fc=4200.0, voices=5, sub=0.15)
        elif inst == 'chip':
            sig = chip_lead(m, d, vel)
        elif inst == 'brass':
            sig = brass(m, d, vel, bright=1.1)
        elif inst == 'glock':
            sig = glock(m, 1.4, vel)
        elif inst == 'pizz':
            sig = pizz(m, min(d, 0.22), vel)
        else:
            raise ValueError(inst)
        mx.add('lead', sig, t, gain=gain, sends=sends)


def drum_hats_16(mx, bar, vel=0.5, open_off=False, pat=(1.0, 0.45, 0.7, 0.5), beats=4, swing=0.006):
    for i in range(int(beats * 4)):
        t = T(bar, i / 4.0) + (swing if i % 2 == 1 else 0)
        mx.add('drums', hat(), t, gain=hv(vel * pat[i % 4]), pan=0.25)
    if open_off:
        for b in range(int(beats)):
            mx.add('drums', hat(True), T(bar, b + 0.5), gain=hv(vel * 0.55), pan=-0.2, sends=((ROOM, 0.15),))


def K(mx, t, vel=1.0, kind='std'):
    mx.add('drums', kick(kind), t, gain=hv(vel * 0.8, 0.03))
    mx.kicks.append(t)


def SN(mx, t, vel=1.0, tune=1.0, clapv=0.0):
    mx.add('drums', snare(tune), t, gain=hv(vel, 0.04), pan=0.05, sends=((ROOM, 0.25), (HALL, 0.1)))
    if clapv:
        mx.add('drums', clap(), t + 0.003, gain=hv(clapv, 0.04), sends=((ROOM, 0.3), (HALL, 0.08)))


def build_score():
    mx = Mix()
    GAP1 = (T(3) - BEAT / 2, T(3))                 # 3.515625 - 3.75
    GAP2 = (T(15, 3), T(16))                       # 27.65625 - 28.125
    STABS = [T(1, 0), T(1, 2), T(2, 0), T(2, 2)]
    IMPACTS = [T(3), T(16), T(22)]
    BUTTON = T(24)

    # ============ Bars 1-2 : COLD OPEN (A minor tension) =========================================
    nsx = int(round(GAP1[0] / (BEAT / 4)))
    for i in range(nsx):
        t = i * BEAT / 4
        x = t / GAP1[0]
        acc = 1.0 if i % 4 == 0 else (0.72 if i % 2 == 0 else 0.55)
        sig = bass_saw(33, BEAT / 4 * 0.55, 1.0, fc=150 + 650 * x ** 1.5, env_amt=250 + 1000 * x, q=1.6, sub=0.5)
        mx.add('bass', sig, t, gain=0.55 * acc * (0.55 + 0.45 * x))
    for i in range(nsx // 2):
        t = i * BEAT / 2
        mx.add('drums', tick(i % 2 == 0), t, gain=hv(0.16 + 0.1 * (t / GAP1[0])), pan=0.35)
    for i in range(16, nsx):                                   # hats join in bar 2
        t = i * BEAT / 4
        mx.add('drums', hat(), t, gain=hv(0.12 + 0.18 * (t / GAP1[0])) * (1.0 if i % 2 == 0 else 0.6), pan=-0.3)
    mx.add('fx', riser_gen(GAP1[0], 200, 8000, 55, 440, curve=2.4, tone_amt=0.3), 0.0, gain=0.42,
           sends=((HALL, 0.2),))
    for t, ch, v in zip(STABS, ['Am', 'Am', 'F', 'G'], [0.85, 0.85, 0.92, 1.0]):
        orch_hit(mx, t, ch, vel=v, length=0.18, gain=0.9, timp_decay=0.5)
        mx.add('fx', crash(1.2, 1.2), t, gain=0.12, sends=((HALL, 0.2),))
    mx.add('post', rev_cymbal(1.4), GAP1[1] - 1.4, gain=0.35)

    # ============ Bar 3 : LOGO SLAM =============================================================
    t = T(3)
    mx.add('fx', impact_big_gen(3.2), t, gain=0.9, sends=((BIG, 0.3),))
    orch_hit(mx, t, 'C', vel=1.0, length=0.9, rel=0.8, kick_kind='big', gain=1.0, big=0.25)
    for i, m in enumerate([60, 64, 67, 72, 76]):
        mx.add('music', supersaw(m, 1.1, 0.8, fc=6500.0, rel=0.9, sub=0.0), t, gain=0.32, sends=((HALL, 0.4),))
    play_pad(mx, 'C', 3, 0, 3.6, vel=0.55, fc=3500, a=0.05, rel=0.9, sends=((HALL, 0.35),))
    mx.add('bass', bass_sub(24, 1.3, 1.0, rel=0.5), t, gain=0.55)
    for i, m in enumerate([84, 88, 91, 96, 91, 88, 96, 100, 103]):     # shimmer glock sparkle
        mx.add('lead', glock(m, 1.5, 0.55 - 0.03 * i), T(3, 0.5 + i * 0.25), gain=0.5,
               pan=np.sin(i * 1.3) * 0.5, sends=((HALL, 0.5), (DLY, 0.35)))
    for m in (84, 91):                                                    # airy high pad
        mx.add('music', strings(m, 1.3, 0.35, fc=9000, a=0.35, rel=0.8), T(3, 0.5), gain=0.35, sends=((HALL, 0.6),))
    mx.add('post', rev_cymbal(0.47), T(4) - 0.47, gain=0.18)             # little suck-in into the groove

    # ============ Bars 4-5 : TAGLINE (C | Gsus4 G) ==============================================
    for b in (4, 5):
        K(mx, T(b, 0), 0.8)
        K(mx, T(b, 2), 0.72)
        for i in range(8):
            mx.add('drums', hat(), T(b, i / 2), gain=hv(0.22 if i % 2 == 0 else 0.32), pan=0.25)
        for i in range(16):
            mx.add('drums', shaker(), T(b, i / 4), gain=hv(0.08 if i % 2 else 0.12), pan=-0.35)
    mx.add('drums', rim(), T(5, 3.5), gain=0.22, pan=-0.2, sends=((ROOM, 0.3),))
    bass_pat = [(0, 0.75, 0), (1.5, 0.4, 0), (2, 0.75, 0), (3, 0.4, 12), (3.5, 0.4, 7)]
    for b, ch in ((4, 'C'), (5, 'G')):
        r = CH[ch]['root'] + 12
        for bt, d, iv in bass_pat:
            mx.add('bass', bass_tri(r + iv, d * BEAT, 1.0), T(b, bt), gain=0.5)
            mx.add('bass', bass_sub(r - 12 + iv if iv != 12 else r, d * BEAT, 1.0), T(b, bt), gain=0.25)
    play_pad(mx, 'C', 4, 0, 4, vel=0.45, fc=2400)
    play_pad(mx, 'Gsus4', 5, 0, 2, vel=0.45, fc=2400)
    play_pad(mx, 'G', 5, 2, 2, vel=0.45, fc=2400)
    lead_line(mx, MOTIF, 4, 'chip', vel=1.0, gain=0.62)
    lead_line(mx, MOTIF, 4, 'glock', vel=0.6, gain=0.28, oct_shift=1, sends=((HALL, 0.4), (DLY, 0.25)))

    # ============ Bars 6-7 : SNEAK (Am | F G) ===================================================
    oom = [(6, 0, 45), (6, 1, 52), (6, 2, 45), (6, 3, 52), (7, 0, 41), (7, 1, 48), (7, 2, 43), (7, 3, 50)]
    for b, bt, m in oom:
        mx.add('music', pizz(m, 0.16, 0.9), T(b, bt), gain=0.4, pan=-0.25, sends=((HALL, 0.18),))
    sneak_mel = [(6, 0, 'A4'), (6, 1.5, 'E5'), (6, 3, 'F5'), (6, 3.5, 'E5'),
                 (7, 0, 'C5'), (7, 0.5, 'B4'), (7, 1.5, 'A4'), (7, 2, 'G4'), (7, 3, 'B4'), (7, 3.5, 'D5')]
    for b, bt, name in sneak_mel:
        mx.add('lead', pizz(nm(name), 0.14, 1.0, bright=1.3), T(b, bt), gain=0.6, pan=0.2,
               sends=((HALL, 0.2), (DLY, 0.25)))
        mx.add('lead', chip_lead(nm(name) + 12, 0.07, 0.35, vib=False, width=0.5), T(b, bt), gain=0.25,
               pan=0.35, sends=((DLY, 0.35),))
    for b, bt, m in ((6, 0, 33), (6, 2, 33), (7, 0, 29), (7, 2, 31)):
        mx.add('bass', bass_sub(m + 12, 0.28 * BEAT * 2, 1.0), T(b, bt), gain=0.5)
    for b in (6, 7):
        K(mx, T(b, 0), 0.55, 'soft')
        K(mx, T(b, 2.5), 0.32, 'soft')
        for bt in (1, 3):
            mx.add('drums', rim(), T(b, bt), gain=hv(0.3), pan=-0.15, sends=((ROOM, 0.35),))
        for i in range(8):
            mx.add('drums', shaker(), T(b, i / 2), gain=hv(0.1 if i % 2 == 0 else 0.15), pan=0.4)
        for i in range(16):
            mx.add('drums', tick(i % 4 == 0), T(b, i / 4), gain=hv(0.05 if i % 2 else 0.08), pan=-0.45)
    play_pad(mx, 'Am', 6, 0, 4, vel=0.3, fc=1200, a=0.3)
    play_pad(mx, 'F', 7, 0, 2, vel=0.3, fc=1200, a=0.2)
    play_pad(mx, 'G', 7, 2, 2, vel=0.3, fc=1400, a=0.2)
    mx.add('fx', riser_gen(BAR * 0.5, 400, 6000, tone_amt=0.0, curve=2.0), T(7, 2), gain=0.12)

    # ============ Bars 8-9 : RESCUE (F | G) =====================================================
    mx.add('fx', crash(2.5), T(8), gain=0.22, sends=((HALL, 0.2),))
    for b in (8, 9):
        K(mx, T(b, 0), 0.85)
        K(mx, T(b, 2), 0.8)
        K(mx, T(b, 2.5), 0.4)
        SN(mx, T(b, 1), 0.45, clapv=0.35)
        SN(mx, T(b, 3), 0.45, clapv=0.35)
        for i in range(8):
            mx.add('drums', hat(), T(b, i / 2) + (0.004 if i % 2 else 0), gain=hv(0.28 if i % 2 == 0 else 0.4), pan=0.25)
    for bt in (3.5, 3.75):
        SN(mx, T(9, bt), 0.35 + 0.15 * (bt - 3.5) * 4)
    for b, ch in ((8, 'F'), (9, 'G')):
        r = CH[ch]['root'] + 12
        for i in range(8):
            iv = 12 if i in (3, 7) else 0
            mx.add('bass', bass_saw(r + iv, 0.42 * BEAT, 1.0, fc=500, env_amt=700, sub=0.8), T(b, i / 2),
                   gain=0.42 if i % 2 == 0 else 0.33)
        tones = CH[ch]['tones']
        seq = [tones[0], tones[1], tones[2], tones[1] + 12, tones[2], tones[1], tones[0] + 12, tones[2]]
        for i, m in enumerate(seq):
            mx.add('music', arp_pluck(m, 0.4 * BEAT, 0.7, fc0=2500), T(b, i / 2), gain=0.35,
                   sends=((DLY, 0.25), (HALL, 0.15)))
    play_pad(mx, 'F', 8, 0, 4, vel=0.5, fc=3200)
    play_pad(mx, 'G', 9, 0, 4, vel=0.5, fc=3400)
    lead_line(mx, MOTIF, 8, 'chip', vel=1.0, gain=0.5)
    lead_line(mx, MOTIF, 8, 'sawsoft', vel=0.8, gain=0.4)
    lead_line(mx, MOTIF, 8, 'glock', vel=0.7, gain=0.3, oct_shift=1, sends=((HALL, 0.4), (DLY, 0.3)))
    harm = [('A4', 0, 1.5), ('E5', 1.5, 1.5), ('F5', 3, 1.0), ('D5', 4, 4.0)]
    lead_line(mx, harm, 8, 'brass', vel=0.6, gain=0.3, sends=((HALL, 0.3),))

    # ============ Bars 10-11 : CHASE (Am | F) ===================================================
    mx.add('fx', crash(2.5), T(10), gain=0.3, sends=((HALL, 0.2),))
    for b in (10, 11):
        for bt in range(4):
            K(mx, T(b, bt), 0.95)
        SN(mx, T(b, 1), 0.8, clapv=0.45)
        SN(mx, T(b, 3), 0.8, clapv=0.45)
        drum_hats_16(mx, b, 0.44, open_off=(b == 11))
    for b, ch in ((10, 'Am'), (11, 'F')):
        r = CH[ch]['root'] + 12
        for i in range(8):
            mx.add('bass', bass_saw(r + (12 if i % 2 else 0), 0.45 * BEAT, 1.0, fc=700, env_amt=1500, q=1.3),
                   T(b, i / 2), gain=0.46 if i % 2 == 0 else 0.36)
        orch_hit(mx, T(b, 0), ch, vel=0.8, length=0.2, timp=True, gain=0.45)
        for i, m in enumerate(CH[ch]['brass'][2:]):
            mx.add('music', brass(m, 0.18, 0.8, a=0.004), T(b, 2.5), gain=0.3, pan=(i - 1.5) * 0.2,
                   sends=((HALL, 0.25),))
    riff = {10: ['A4', 'C5', 'E5', 'A4', 'C5', 'E5', 'A5', 'G5'], 11: ['F4', 'A4', 'C5', 'F4', 'A4', 'C5', 'F5', 'E5']}
    for b, ns in riff.items():
        for i, name in enumerate(ns):
            mx.add('lead', chip_lead(nm(name), 0.38 * BEAT, 0.9 if i in (0, 3, 6) else 0.7, vib=False),
                   T(b, i / 2), gain=0.42, sends=((DLY, 0.2), (HALL, 0.12)))
    play_pad(mx, 'Am', 10, 0, 4, vel=0.55, fc=3000)
    play_pad(mx, 'F', 11, 0, 4, vel=0.55, fc=3000)

    # ============ Bars 12-13 : GRAPPLE / ROOFTOPS (C | G) =======================================
    for b in (12, 13):
        for bt in range(4):
            K(mx, T(b, bt), 0.95)
        SN(mx, T(b, 1), 0.8, clapv=0.45)
        if b == 12:
            SN(mx, T(b, 3), 0.8, clapv=0.45)
        drum_hats_16(mx, b, 0.44, open_off=True, beats=4 if b == 12 else 2)
    fill = [(13, 2 + i / 4) for i in range(8)]
    for j, (b, bt) in enumerate(fill):
        SN(mx, T(b, bt), 0.4 + 0.55 * j / 7, tune=1.0 + 0.02 * j)
    for j, (bt, f) in enumerate(((3.0, 200), (3.25, 160), (3.5, 125), (3.75, 95))):
        mx.add('drums', tom(f, 0.25), T(13, bt), gain=0.36 + 0.05 * j, pan=0.4 - 0.25 * j, sends=((ROOM, 0.2),))
    for b, ch in ((12, 'C'), (13, 'G')):
        r = CH[ch]['root'] + 12
        for i in range(8):
            mx.add('bass', bass_saw(r + (12 if i % 2 else 0), 0.45 * BEAT, 1.0, fc=750, env_amt=1500, q=1.3),
                   T(b, i / 2), gain=0.46 if i % 2 == 0 else 0.36)
        tones = CH[ch]['tones']
        up = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24, tones[2] + 12]
        seq = up + up[::-1]
        for i in range(16):
            mx.add('music', arp_pluck(seq[i], 0.22 * BEAT, 0.75 if i % 4 == 0 else 0.55, fc0=5000), T(b, i / 4),
                   gain=0.34, pan=np.sin(i * 0.8) * 0.3, sends=((DLY, 0.3), (HALL, 0.12)))
    play_pad(mx, 'C', 12, 0, 4, vel=0.55, fc=3200)
    play_pad(mx, 'G', 13, 0, 4, vel=0.55, fc=3200)
    lead_line(mx, MOTIF[:3] + [('G5', 4, 2.0)], 12, 'brass', vel=0.95, gain=0.45, sends=((HALL, 0.3),))
    lead_line(mx, MOTIF[:3] + [('G5', 4, 2.0)], 12, 'chip', vel=0.8, gain=0.3, oct_shift=0)

    # ============ Bars 14-15 : BUILD (F | Gsus4 G) ==============================================
    mx.add('fx', crash(2.2), T(14), gain=0.2, sends=((HALL, 0.2),))
    build_len = GAP2[0] - T(14)
    mx.add('fx', riser_gen(build_len, 180, 11000, 87.3, 698.5, curve=2.3, tone_amt=0.4), T(14), gain=0.55,
           sends=((HALL, 0.15),))
    roll = [(14, i / 2) for i in range(8)] + [(15, i / 4) for i in range(8)] + [(15, 2 + i / 8) for i in range(8)]
    for j, (b, bt) in enumerate(roll):
        x = j / (len(roll) - 1)
        SN(mx, T(b, bt), 0.3 + 0.62 * x ** 1.3, tune=1.0 + 0.4 * x, clapv=0.0)
    for bt in range(4):
        K(mx, T(14, bt), 0.85)
    for i in range(6):
        K(mx, T(15, i / 2), 0.7 + 0.05 * i)
    for i in range(16):
        mx.add('drums', hat(), T(14, i / 4), gain=hv(0.2 + 0.1 * (i % 2 == 0)), pan=0.25)
    for i in range(24):
        mx.add('drums', hat(), T(15, i / 8), gain=hv(0.15 + 0.2 * i / 23), pan=0.25)
    r = CH['F']['root'] + 12
    for i in range(8):
        mx.add('bass', bass_saw(r, 0.45 * BEAT, 1.0, fc=600, env_amt=900), T(14, i / 2), gain=0.42)
    mx.add('bass', bass_saw(CH['G']['root'] + 12, 2.5 * BEAT, 1.0, fc=400, env_amt=600, rel=0.2), T(15), gain=0.35)
    # swept bus: pads + arp through a resonant lowpass opening 350 Hz -> 16 kHz
    for m in CH['F']['pad']:
        mx.add('sweep', strings(m, BAR, 0.8, fc=6000, a=0.1, rel=0.1), T(14))
    for m in CH['Gsus4']['pad']:
        mx.add('sweep', strings(m, 2 * BEAT, 0.8, fc=6000, a=0.05, rel=0.05), T(15))
    for m in CH['G']['pad']:
        mx.add('sweep', strings(m, BEAT, 0.8, fc=6000, a=0.05, rel=0.03), T(15, 2))
    for b, ch in ((14, 'F'), (15, 'G')):
        tones = CH[ch]['tones']
        up = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24, tones[2] + 12]
        seq = up + up[::-1]
        for i in range(16 if b == 14 else 12):
            mx.add('sweep', supersaw(seq[i], 0.2 * BEAT, 0.8, fc=9000, voices=5, rel=0.04, sub=0.0), T(b, i / 4),
                   gain=0.7)

    mx.add('post', rev_cymbal(1.2), GAP2[1] - 1.2, gain=0.33)

    # ============ Bars 16-19 : BOSS DROP (Am | F | C | G) =======================================
    t = T(16)
    mx.add('fx', impact_big_gen(3.0), t, gain=0.9, sends=((BIG, 0.3),))
    prog = [(16, 'Am'), (17, 'F'), (18, 'C'), (19, 'G')]
    for b, ch in prog:
        orch_hit(mx, T(b), ch, vel=1.0, length=0.25, kick_kind='big', gain=0.75 if b > 16 else 1.0)
        if b > 16:
            mx.add('fx', crash(2.5), T(b), gain=0.3, sends=((HALL, 0.2),))
        for bt in range(4):
            K(mx, T(b, bt), 1.0, 'big')
        SN(mx, T(b, 1), 0.95, clapv=0.6)
        SN(mx, T(b, 3), 0.95, clapv=0.6)
        drum_hats_16(mx, b, 0.52, open_off=True, beats=4 if b != 19 else 3)
        r = CH[ch]['root']
        mx.add('bass', bass_sub(r + 12, BAR - 0.03, 1.0, rel=0.03), T(b), gain=0.55)
        for i in range(8):
            if i % 2 == 1:
                mx.add('bass', bass_saw(r + 24, 0.42 * BEAT, 1.0, fc=900, env_amt=2200, q=1.4, sub=0.3),
                       T(b, i / 2), gain=0.42)
        play_pad(mx, ch, b, 0, 4, vel=0.8, fc=4200, a=0.03, rel=0.2, sends=((HALL, 0.25),))
        for m in CH[ch]['pad']:
            mx.add('music', supersaw(m, BAR - 0.05, 0.55, fc=3500, voices=5, a=0.01, rel=0.1, sub=0.0, vib=False),
                   T(b), gain=0.3)
        tones = CH[ch]['tones']
        up = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[0] + 24]
        for i in range(16):
            mx.add('music', arp_pluck(up[i % 4] if (i // 4) % 2 == 0 else up[3 - i % 4], 0.2 * BEAT, 0.5, fc0=5500),
                   T(b, i / 4), gain=0.22, pan=0.3 * (1 if i % 2 else -1), sends=((DLY, 0.2),))
    # snare fill end of bar 19 into the pull-back
    for j, bt in enumerate((3.0, 3.25, 3.5, 3.75)):
        SN(mx, T(19, bt), 0.55 + 0.12 * j, tune=1.05 + 0.04 * j)
    drop_lead = [(16, n, b0, d) for n, b0, d in MOTIF_MIN] + \
                [(18, 'C5', 0, 1.5), (18, 'G5', 1.5, 1.5), (18, 'A5', 3, 1.0),
                 (18, 'G5', 4, 2.5), (18, 'A5', 6.5, 0.5), (18, 'B5', 7, 1.0), (18, 'C6', 8, 1.0)]
    for bar0, name, b0, d in drop_lead:
        lead_line(mx, [(name, b0, d)], bar0, 'saw', vel=1.0, gain=0.62)
        lead_line(mx, [(name, b0, d)], bar0, 'chip', vel=0.8, gain=0.2, oct_shift=1)
        lead_line(mx, [(name, b0, d)], bar0, 'brass', vel=0.85, gain=0.3, oct_shift=-1, sends=((HALL, 0.2),))

    # ============ Bars 20-21 : HERO CITY / UNLOCKS (C | F G) ====================================
    mx.add('lead', glock(96, 1.5, 0.6), T(20), gain=0.35, sends=((HALL, 0.4), (DLY, 0.3)))
    for b in (20, 21):
        K(mx, T(b, 0), 0.8)
        K(mx, T(b, 1.75), 0.45)
        K(mx, T(b, 2), 0.75)
        for bt in (1, 3):
            mx.add('drums', clap(), T(b, bt), gain=hv(0.5), sends=((ROOM, 0.3), (HALL, 0.1)))
        for i in range(16):
            mx.add('drums', shaker(), T(b, i / 4), gain=hv(0.14 if i % 2 else 0.2), pan=-0.35)
        for i in range(4):
            mx.add('drums', hat(), T(b, i + 0.5), gain=hv(0.3), pan=0.3)
    for j, bt in enumerate((3.0, 3.25, 3.5, 3.75)):
        SN(mx, T(21, bt), 0.35 + 0.15 * j, tune=1.1)
    city = [(20, 0, 'C'), (21, 0, 'F'), (21, 2, 'G')]
    for b, bt0, ch in city:
        nb = 4 if ch == 'C' else 2
        r = CH[ch]['root'] + 12
        for i in range(nb * 2):
            mx.add('bass', bass_tri(r + (12 if i % 2 else 0), 0.3 * BEAT, 1.0), T(b, bt0 + i / 2), gain=0.55)
            mx.add('bass', bass_sub(r + (12 if i % 2 else 0), 0.3 * BEAT, 1.0), T(b, bt0 + i / 2), gain=0.22)
        tones = CH[ch]['tones']
        g = [tones[0] + 24, tones[1] + 24, tones[2] + 24, tones[1] + 24]
        for i in range(nb * 4):
            mx.add('lead', glock(g[i % 4] + (12 if (i % 8) == 3 else 0), 0.8, 0.55 if i % 2 else 0.7),
                   T(b, bt0 + i / 4), gain=0.3, pan=0.35 * np.sin(i), sends=((HALL, 0.25), (DLY, 0.15)))
        for i in range(nb):
            for m in tones:
                mx.add('music', chip_lead(m, 0.2 * BEAT, 0.6, vib=False, width=0.5), T(b, bt0 + i + 0.5),
                       gain=0.2, pan=-0.2, sends=((ROOM, 0.2),))
        play_pad(mx, ch, b, bt0, nb, vel=0.4, fc=2800)
    counter = [(20, 0, 'C6', 1.0), (20, 1.5, 'G5', 0.5), (20, 2, 'A5', 0.5), (20, 2.5, 'C6', 1.0),
               (20, 3.5, 'D6', 0.5), (21, 0, 'C6', 0.5), (21, 0.5, 'A5', 1.0), (21, 2, 'B5', 0.5),
               (21, 2.5, 'D6', 1.0)]
    for b, b0, name, d in counter:
        lead_line(mx, [(name, b0, d)], b, 'chip', vel=0.8, gain=0.33)
    mx.add('post', rev_cymbal(0.9), T(22) - 0.9, gain=0.3)

    # ============ Bars 22-24 : END CARD =========================================================
    t = T(22)
    mx.add('fx', impact_big_gen(3.2), t, gain=0.9, sends=((BIG, 0.3),))
    orch_hit(mx, t, 'C', vel=1.0, length=0.9, rel=0.6, kick_kind='big', gain=1.0, big=0.25)
    end_ch = [(22, 0, 2, 'C'), (22, 2, 2, 'F'), (23, 0, 2, 'Gsus4'), (23, 2, 1.75, 'G')]   # 16th breath before button
    for b, bt, nb, ch in end_ch:
        play_pad(mx, ch, b, bt, nb, vel=0.8, fc=4000, a=0.04, rel=0.25 if nb == 2 else 0.05, sends=((HALL, 0.3),))
        for m in CH[ch]['brass'][1:]:
            mx.add('music', brass(m, nb * BEAT - 0.03, 0.7, bright=0.8, a=0.02, rel=0.1), T(b, bt), gain=0.22,
                   sends=((HALL, 0.3),))
        r = CH[ch]['root'] + 12
        mx.add('bass', bass_sub(r, nb * BEAT - 0.02, 1.0), T(b, bt), gain=0.55)
        for i in range(int(nb * 2)):
            if i % 2 == 1:
                mx.add('bass', bass_saw(r + 12, 0.42 * BEAT, 0.9, fc=900, env_amt=1800), T(b, bt + i / 2), gain=0.35)
    end_lead = [(22, 'C5', 0, 1.5), (22, 'G5', 1.5, 1.5), (22, 'A5', 3, 1.0),
                (23, 'G5', 0, 1.5), (23, 'E5', 1.5, 0.5), (23, 'G5', 2, 1.0), (23, 'B5', 3, 0.72)]
    for b, name, b0, d in end_lead:
        lead_line(mx, [(name, b0, d)], b, 'saw', vel=1.0, gain=0.6)
        lead_line(mx, [(name, b0, d)], b, 'brass', vel=0.9, gain=0.32, oct_shift=-1, sends=((HALL, 0.25),))
        lead_line(mx, [(name, b0, d)], b, 'glock', vel=0.6, gain=0.22, oct_shift=1, sends=((HALL, 0.4),))
    for b in (22, 23):
        K(mx, T(b, 0), 1.0, 'big')
        K(mx, T(b, 2), 0.9, 'big')
        SN(mx, T(b, 1), 0.9, clapv=0.55)
        if b == 22:
            SN(mx, T(b, 3), 0.9, clapv=0.55)
        for i in range(8 if b == 22 else 6):
            mx.add('drums', hat(), T(b, i / 2), gain=hv(0.3 if i % 2 else 0.22), pan=0.25)
    mx.add('fx', crash(2.5), T(23), gain=0.25, sends=((HALL, 0.2),))
    for j in range(7):                                               # tom + snare fill, 16th rest, button
        f = [240, 210, 180, 150, 130, 110, 95, 80][j]
        mx.add('drums', tom(f, 0.22), T(23, 2 + j / 4), gain=0.26 + 0.03 * j, pan=0.5 - 0.14 * j, sends=((ROOM, 0.25),))
        if j >= 4:
            SN(mx, T(23, 2 + j / 4), 0.3 + 0.07 * (j - 4))
    # --- button (bar 24 beat 1) ---
    tb = BUTTON
    orch_hit(mx, tb, 'C', vel=1.0, length=0.22, rel=0.35, kick_kind='big', gain=1.05, big=0.45)
    mx.add('fx', impact_small_gen(0.9), tb, gain=0.7, sends=((BIG, 0.35),))
    mx.add('fx', crash(3.5), tb, gain=0.32, sends=((BIG, 0.3),))
    mx.add('lead', supersaw(84, 0.25, 1.0, fc=8000, rel=0.35), tb, gain=0.5, sends=((BIG, 0.5),))
    for m in (72, 76, 79, 84):   # soft string halo that blooms out of the button and rings away
        mx.add('music', strings(m, 0.3, 0.45, fc=7000, a=0.02, rel=2.2), tb, gain=0.3, sends=((BIG, 0.5),))
    mx.add('lead', glock(96, 2.0, 0.7), tb, gain=0.35, sends=((BIG, 0.6), (DLY, 0.3)))
    mx.add('bass', bass_sub(24, 0.35, 1.0, rel=0.25), tb, gain=0.6)
    mx.kicks.append(tb)

    cues = dict(gaps=[GAP1, GAP2], stabs=STABS, impacts=IMPACTS, button=BUTTON)
    return mx, cues


# ----------------------------------------------------------------------------------------------
# Mixdown + master
# ----------------------------------------------------------------------------------------------
SIDECHAIN_DEPTH = [  # (start, end, depth for music, depth for bass)
    (T(4), T(6), 0.25, 0.35), (T(6), T(8), 0.12, 0.2), (T(8), T(10), 0.35, 0.5), (T(10), T(14), 0.4, 0.55),
    (T(14), T(16), 0.35, 0.5), (T(16), T(20), 0.6, 0.7), (T(20), T(22), 0.28, 0.4), (T(22), T(24), 0.35, 0.5),
]


def sidechain_env(kicks, which):
    t = np.arange(N) / SR
    k = np.array(sorted(set(kicks)))
    idx = np.searchsorted(k, t, side='right') - 1
    dt = np.where(idx >= 0, t - k[np.maximum(idx, 0)], 10.0)
    rel = 0.8 * BEAT
    shape = np.clip(1 - dt / rel, 0, 1) ** 2 * np.clip(dt / 0.003, 0, 1)
    depth = np.zeros(N)
    for a, b, dm, db in SIDECHAIN_DEPTH:
        depth[S(a):S(b)] = dm if which == 'music' else db
    depth = movavg_centered(depth, 2 * S(0.01) + 1, 0.0)
    return 1 - depth * shape


def mixdown(mx, cues):
    b = mx.b
    # build filter sweep (bars 14-15)
    t0, t1 = T(14) - 0.2, cues['gaps'][1][0] + 0.2
    seg = b['sweep'][:, S(t0):S(t1)]
    L = T(15, 3) - T(14)

    def mask(fr, tt):
        x = np.clip((tt - 0.2) / L, 0, 1)
        fc = 350.0 * (16000.0 / 350.0) ** (x ** 1.5)
        return lpmag(fr[None, :] / fc[:, None], 1.6, 4)
    swept = tv_filter(seg, mask)
    b['music'][:, S(t0):S(t0) + swept.shape[1]] += swept * 0.5
    b['hall'][:, S(t0):S(t0) + swept.shape[1]] += swept * 0.5 * 0.2

    sc_m = sidechain_env(mx.kicks, 'music')
    sc_b = sidechain_env(mx.kicks, 'bass')

    hall_ir = make_ir(3.0, 2.6, 1.0, 0.025, seed=11)
    room_ir = make_ir(1.0, 0.7, 0.35, 0.008, seed=12, hp=250)
    dly = pingpong(b['delay'], 0.75 * BEAT, fb=0.42)
    hall_in = b['hall'] + dly * 0.3
    hall = convolve(hall_in, hall_ir)
    room = convolve(b['room'], room_ir)
    big_ir = make_ir(4.5, 3.8, 1.9, 0.03, seed=13, hp=120, lp=13000)
    hall = hall + convolve(b['bighall'], big_ir) * 1.1

    G = dict(drums=0.9, bass=0.75, music=0.8, lead=1.25, fx=0.75, hall=0.23, room=0.2, delay=0.38)
    mix = (b['drums'] * G['drums'] + b['bass'] * sc_b * G['bass'] + b['music'] * sc_m * G['music']
           + b['lead'] * (1 - 0.35 * (1 - sc_m)) * G['lead'] + b['fx'] * G['fx']
           + hall * (1 - 0.3 * (1 - sc_m)) * G['hall'] + room * G['room'] + dly * G['delay'])
    stems = dict(drums=b['drums'] * G['drums'], bass=b['bass'] * sc_b * G['bass'], music=b['music'] * sc_m * G['music'],
                 lead=b['lead'] * G['lead'], fx=b['fx'] * G['fx'], verb=hall * G['hall'] + room * G['room'] + dly * G['delay'])

    if os.environ.get('KAI_DEBUG'):
        secs = [(0, T(3)), (T(3), T(4)), (T(4), T(6)), (T(6), T(8)), (T(8), T(10)), (T(10), T(12)), (T(12), T(14)),
                (T(14), T(16)), (T(16), T(20)), (T(20), T(22)), (T(22), T(24)), (T(24), TOTAL)]
        print('stem RMS dB relative to mix, per section')
        print('          ' + ' '.join(f'{k:>6s}' for k in stems))
        for a, e in secs:
            ref = np.sqrt(np.mean(mix[:, S(a):S(e)] ** 2)) + 1e-12
            print(f'{a:6.2f}   mix {20*np.log10(ref):6.1f} | ' + ' '.join(
                f'{20*np.log10(np.sqrt(np.mean(v[:, S(a):S(e)] ** 2)) / ref + 1e-12):6.1f}' for v in stems.values()))
    # silence gaps (everything incl. reverb returns), then add the post-gate suck-ins
    gate = np.ones(N)
    for a, e in cues['gaps']:
        ia, ie = S(a), S(e)
        nf = S(0.004)
        gate[ia - nf:ia] = np.linspace(1, 0, nf) ** 2
        gate[ia:ie] = 0.0
        nu = S(0.001)
        gate[ie - nu:ie] = np.linspace(0, 1, nu)
    mix *= gate[None, :]
    mix += b['post'] * 0.9

    # low-end hygiene: HP 28 Hz, mono below ~120 Hz
    mix = minphase_filter(mix, g_hp(28, 2))
    mid, side = (mix[0] + mix[1]) / 2, (mix[0] - mix[1]) / 2
    side = minphase_filter(side, g_hp(140, 2))
    mix = np.stack([mid + side, mid - side])

    # end: after the music (45.0) let it ring, then fade so it is silent by 47.5
    t = np.arange(N) / SR
    fade = np.clip((TOTAL - 0.02 - t) / (TOTAL - 0.02 - 45.4), 0, 1)
    fade = np.where(t < 45.4, 1.0, 0.5 - 0.5 * np.cos(np.pi * fade))
    mix *= fade[None, :]
    mix -= mix.mean(axis=1, keepdims=True) * 0      # (DC handled by HP)
    return mix, stems


def master(pre, target=-14.0, ceil_db=-1.3):
    x0 = pre / (10 ** (lufs_integrated(pre) / 20.0)) * 10 ** (-18.0 / 20.0)   # normalise to -18 LUFS
    gain = target + 18.0 - 1.0
    info = {}
    for it in range(5):
        x = x0 * 10 ** (gain / 20.0)
        x = minphase_filter(x, g_mul(g_shelf(70, -2.0, high=False), g_shelf(4500, 2.5), g_peak(250, -1.0, 1.5)))
        x, gr = glue_comp(x, thr_db=-13.0, ratio=1.8, att=0.015, rel=0.18)
        up = oversample(x, 2)
        up = soft_clip(up, -3.5, -0.4)
        x = downsample(up, 2, x.shape[1])
        x, lim = limiter(x, ceil_db)
        L = lufs_integrated(x)
        info = dict(iter=it, gain=gain, comp_max_gr_db=gr, limiter_max_gr_db=lim, lufs=L)
        print('   master pass', info)
        if abs(L - target) < 0.05:
            break
        gain += (target - L)
    tp = true_peak_db(x)
    if tp > ceil_db:
        x *= 10 ** ((ceil_db - tp) / 20.0)
    info['true_peak_db'] = true_peak_db(x)
    return x, info


# ----------------------------------------------------------------------------------------------
# I/O + reports
# ----------------------------------------------------------------------------------------------
def write_wav(path, x, bits=24):
    x = np.asarray(x, dtype=float)
    if x.ndim == 1:
        x = np.stack([x, x])
    x = np.clip(x, -1.0, 1.0)
    if bits == 24:
        ints = np.ascontiguousarray(np.round(x.T * 8388607.0).astype("<i4"))
        raw = ints.view(np.uint8).reshape(-1, 4)[:, :3].tobytes()
        sw = 3
    else:
        raw = np.round(x.T * 32767.0).astype('<i2').tobytes()
        sw = 2
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(sw)
        w.setframerate(SR)
        w.writeframes(raw)


def spectrogram_png(x, path, cues, sections):
    from PIL import Image, ImageDraw
    mono = x.mean(axis=0)
    nfft, hop = 4096, 480
    nfr = (len(mono) - nfft) // hop
    win = np.hanning(nfft)
    idx = np.arange(nfft)[None, :] + hop * np.arange(nfr)[:, None]
    spec = np.abs(np.fft.rfft(mono[idx] * win, axis=1)) + 1e-9
    db = 20 * np.log10(spec / spec.max())
    H, W = 560, nfr
    freqs = np.fft.rfftfreq(nfft, 1 / SR)
    fr_rows = 25 * (20000 / 25) ** (np.arange(H)[::-1] / (H - 1))
    img = np.empty((H, W))
    for j in range(W):
        img[:, j] = np.interp(fr_rows, freqs, db[j])
    v = np.clip((img + 100) / 100, 0, 1)
    anchors = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66],
                        [245, 125, 21], [250, 193, 39], [252, 255, 164]]) / 255.0
    pos = np.linspace(0, 1, len(anchors))
    rgb = np.stack([np.interp(v, pos, anchors[:, c]) for c in range(3)], axis=-1)
    im = Image.fromarray((rgb * 255).astype(np.uint8)).resize((1900, H), Image.BILINEAR)
    # RMS strip
    strip_h = 200
    canvas = Image.new('RGB', (1900, H + strip_h + 40), (12, 12, 16))
    canvas.paste(im, (0, 0))
    d = ImageDraw.Draw(canvas)
    px = lambda tt: int(tt / TOTAL * 1900)
    rms_blk = S(0.01)
    nb = x.shape[1] // rms_blk
    rms = np.sqrt((x[:, :nb * rms_blk] ** 2).mean(axis=0).reshape(nb, rms_blk).mean(axis=1))
    rdb = np.clip((20 * np.log10(rms + 1e-9) + 60) / 60, 0, 1)
    pts = [(int(i / nb * 1900), H + 20 + int((1 - rdb[i]) * (strip_h - 10))) for i in range(nb)]
    d.line(pts, fill=(120, 220, 255), width=1)
    for s in sections:
        d.line([(px(s['start']), 0), (px(s['start']), H + strip_h + 40)], fill=(255, 255, 255), width=1)
        d.text((px(s['start']) + 3, 3), s['name'], fill=(255, 255, 255))
    for tt in cues['impacts'] + [cues['button']]:
        d.line([(px(tt), H), (px(tt), H + strip_h + 20)], fill=(255, 80, 80), width=2)
    for tt in cues['stabs']:
        d.line([(px(tt), H), (px(tt), H + strip_h + 20)], fill=(255, 200, 80), width=1)
    for a, e in cues['silence_gaps']:
        d.rectangle([px(a), H + 5, px(e), H + 15], fill=(80, 255, 120))
    for f in (50, 100, 200, 500, 1000, 2000, 5000, 10000):
        y = int((1 - np.log(f / 25) / np.log(20000 / 25)) * (H - 1))
        d.text((1860, y - 6), f'{f // 1000}k' if f >= 1000 else str(f), fill=(200, 200, 200))
    d.text((5, H + strip_h + 24), 'RMS (-60..0 dBFS)  red=impacts/button  yellow=stabs  green=silence gaps', fill=(200, 200, 200))
    canvas.save(path)


def ffmpeg_loudness(path):
    try:
        r = subprocess.run([FFMPEG, '-hide_banner', '-nostats', '-i', path, '-af',
                            'loudnorm=I=-14:TP=-1:print_format=json', '-f', 'null', '-'],
                           capture_output=True, text=True, timeout=120)
        txt = r.stderr
        js = json.loads(txt[txt.rfind('{'):txt.rfind('}') + 1])
        r2 = subprocess.run([FFMPEG, '-hide_banner', '-nostats', '-i', path, '-af', 'ebur128=peak=true',
                             '-f', 'null', '-'], capture_output=True, text=True, timeout=120)
        tail = r2.stderr[r2.stderr.rfind('Summary:'):]
        return js, tail
    except Exception as e:  # ffmpeg optional
        return None, str(e)


# ----------------------------------------------------------------------------------------------
# SFX stems
# ----------------------------------------------------------------------------------------------
def trim_norm(x, peak_db=-3.0, tail_db=-66.0):
    x = np.atleast_2d(x)
    if x.shape[0] == 1:
        x = np.vstack([x, x])
    x = minphase_filter(x, g_hp(22, 2), pad=S(0.5))          # DC / infrasonic cleanup
    env = np.max(np.abs(x), axis=0)
    thr = env.max() * 10 ** (tail_db / 20.0)
    nz = np.nonzero(env > thr)[0]
    end = min(x.shape[1], nz[-1] + S(0.01)) if len(nz) else x.shape[1]
    x = x[:, :end]
    x = fade_edges(x, 0.0, 0.01)
    tp = np.max(true_peak_env(x))
    return x * (10 ** (peak_db / 20.0) / tp)


def sfx_all(outdir):
    hall = make_ir(2.2, 1.8, 0.7, 0.015, seed=21)
    room = make_ir(0.8, 0.5, 0.25, 0.005, seed=22, hp=300)

    def wet(x, ir, amt, tail=1.5):
        x = np.atleast_2d(x)
        if x.shape[0] == 1:
            x = np.vstack([x, x])
        xp = np.pad(x, ((0, 0), (0, S(tail))))
        return xp + convolve(xp, ir) * amt

    out = {}
    out['whoosh_short'] = wet(whoosh_gen(0.3, 5500, 500, 0.4), room, 0.1, 0.08)
    out['whoosh_long'] = wet(whoosh_gen(0.72, 3800, 300, 0.5, 0.9), room, 0.12, 0.12)
    ib = impact_big_gen(2.4)
    out['impact_big'] = wet(ib, hall, 0.22, 1.2)[:, :S(2.6)]
    out['impact_small'] = wet(impact_small_gen(0.55), room, 0.2, 0.2)[:, :S(0.62)]
    out['riser_1bar'] = riser_gen(BAR, 250, 10000, 110, 880, curve=2.2, tone_amt=0.35)   # peak at final sample

    # pop: bubbly upward blip + tiny second bubble
    def pop_gen():
        n = S(0.2)
        t = np.arange(n) / SR
        f = 380 + 900 * (1 - np.exp(-t / 0.018))
        a = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.035) * (1 - np.exp(-t / 0.0015))
        t2 = np.maximum(t - 0.045, 0)
        f2 = 700 + 1300 * (1 - np.exp(-t2 / 0.012))
        b = np.sin(2 * np.pi * np.cumsum(f2) / SR) * np.exp(-t2 / 0.03) * (t >= 0.045) * 0.45
        b *= np.clip((t - 0.045) / 0.002, 0, 1)
        x = a + b
        x = x + 0.25 * np.sin(2 * np.pi * np.cumsum(2 * f) / SR) * np.exp(-t / 0.02) * (1 - np.exp(-t / 0.0015))
        return fade_edges(x, 0.0005, 0.01)
    out['pop'] = wet(pop_gen(), room, 0.08, 0.05)

    # sparkle: pentatonic glass pings with falling density + airy shimmer
    def sparkle_gen():
        n = S(1.1)
        t = np.arange(n) / SR
        x = np.zeros((2, n))
        pent = [84, 86, 88, 91, 93, 96, 98, 100, 103]
        tt = 0.0
        i = 0
        while tt < 0.75:
            m = pent[(i * 3 + RNG.integers(0, 3)) % len(pent)] + (0 if tt < 0.4 else 0)
            g = glock(m, 0.6, 0.9 * (1 - tt / 0.9))
            x += pan_st(np.pad(g, (S(tt), n))[:n], RNG.uniform(-0.7, 0.7))
            tt += 0.025 + 0.06 * (tt / 0.75) ** 1.5 + RNG.uniform(0, 0.015)
            i += 1
        air = _norm(fft_filter(noise(n, 2), g_hp(7000, 2))) * np.sin(np.pi * np.clip(t / 0.9, 0, 1)) ** 2 * 0.05
        return fade_edges(x / (np.max(np.abs(x)) + 1e-9) + air, 0.001, 0.05)
    out['sparkle'] = wet(sparkle_gen(), hall, 0.25, 0.6)[:, :S(1.3)]

    # coin: two-note chip ding (A5 -> E6), band-limited square
    def coin_gen():
        n1, n2 = S(0.07), S(0.38)
        a = osc_add(mtof(81), n1 + S(0.004), H_SQR, fc=9000.0)
        b = osc_add(mtof(88), n2, H_SQR, fc=9000.0)
        t2 = np.arange(n2) / SR
        a *= adsr(0.07, 0.001, 0.2, 0.9, 0.004)[:len(a)]
        b *= np.exp(-t2 / 0.12) * (1 - np.exp(-t2 / 0.002))
        x = np.zeros(n1 + n2)
        x[:len(a)] += a
        x[n1:] += b
        return fade_edges(x * 0.5, 0.0005, 0.01)
    out['coin'] = wet(coin_gen(), room, 0.12, 0.1)

    # swoosh up: rising band-pass noise + soft rising sine chirp, ends crisp
    def swoosh_up_gen():
        L = 0.5
        n = S(L)
        t = np.arange(n) / SR
        x = t / L
        nz = noise(n, 2)

        def mask(fr, tt):
            xx = np.clip(tt / L, 0, 1)
            c = 350 * (9000 / 350) ** (xx ** 1.2)
            lf = np.log2(np.maximum(fr[None, :], 20) / c[:, None])
            return np.exp(-0.5 * (lf / 0.7) ** 2)
        y = _norm(tv_filter(nz, mask))
        shape = np.sin(np.pi * np.clip(x / 0.85, 0, 1) / 2) ** 2 * np.clip((1 - x) / 0.25, 0, 1) ** 1.2
        y = y * shape
        ch = np.sin(2 * np.pi * np.cumsum(300 * (2400 / 300) ** (x ** 1.3)) / SR) * shape * 0.25
        return fade_edges(y + ch[None, :], 0.003, 0.008)
    out['swoosh_up'] = wet(swoosh_up_gen(), room, 0.12, 0.15)

    info = {}
    for k, v in out.items():
        v = trim_norm(v, tail_db=-52.0 if k.startswith('whoosh') else -66.0)
        write_wav(os.path.join(outdir, k + '.wav'), v)
        info[k] = dict(duration=round(v.shape[1] / SR, 3), peak_dbfs=round(20 * np.log10(np.max(np.abs(v))), 2))
    return info


# ----------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--outdir', default=os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument('--no-sfx', action='store_true')
    args = ap.parse_args()
    out = args.outdir
    os.makedirs(out, exist_ok=True)

    print('scoring...')
    mx, c = build_score()
    print('mixing...')
    pre, stems = mixdown(mx, c)
    np.save(os.path.join(out, '.premix_cache.npy'), pre.astype(np.float32)) if os.environ.get('KAI_CACHE') else None
    pk = np.max(np.abs(pre))
    write_wav(os.path.join(out, 'sizzle_music_nomaster.wav'), pre / pk * 10 ** (-3 / 20.0))
    print('mastering...')
    m, minfo = master(pre)
    write_wav(os.path.join(out, 'sizzle_music.wav'), m)

    sections = [
        dict(name='cold_open', start=0.0, end=T(3)),
        dict(name='logo_slam', start=T(3), end=T(4)),
        dict(name='tagline', start=T(4), end=T(6)),
        dict(name='sneak', start=T(6), end=T(8)),
        dict(name='rescue', start=T(8), end=T(10)),
        dict(name='chase', start=T(10), end=T(12)),
        dict(name='grapple_rooftops', start=T(12), end=T(14)),
        dict(name='build', start=T(14), end=T(16)),
        dict(name='boss_drop', start=T(16), end=T(20)),
        dict(name='hero_city', start=T(20), end=T(22)),
        dict(name='end_card', start=T(22), end=MUSIC_END),
        dict(name='ring_out', start=MUSIC_END, end=TOTAL),
    ]
    cues = dict(bpm=BPM, beat=BEAT, bar=BAR, duration=TOTAL, music_end=MUSIC_END, sample_rate=SR,
                sections=sections, stabs=c['stabs'], impacts=c['impacts'], button=c['button'],
                silence_gaps=[[T(15, 3), T(16)]], cold_open_gap=[T(3) - BEAT / 2, T(3)],
                beats=[round(i * BEAT, 6) for i in range(97)],
                downbeats=[round(i * BAR, 6) for i in range(25)])
    with open(os.path.join(out, 'cues.json'), 'w') as f:
        json.dump(cues, f, indent=1)
    spectrogram_png(m, os.path.join(out, 'spectrogram.png'), cues, sections)

    if not args.no_sfx:
        print('sfx...')
        print(json.dumps(sfx_all(out), indent=1))
    print('master info:', minfo)
    js, tail = ffmpeg_loudness(os.path.join(out, 'sizzle_music.wav'))
    print('ffmpeg loudnorm:', json.dumps(js, indent=1) if js else None)
    print(tail)


if __name__ == '__main__':
    main()
