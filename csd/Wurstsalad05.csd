<CsoundSynthesizer>
<CsOptions>
-odac -d
</CsOptions>
<CsInstruments>

sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

; Wurstsalad05 — changes vs 04: random pitch center drifts on a piece-length
; sine (1 cycle); width fixed +-600, clamped to +-1200.
; Otherwise same as 04: density 4x, stereo grains, bounds ride sines.
; Conductor (instr 1) schedules grains (instr 2) into global reverb (instr 99).
; Change iTotal in the score to change piece length; LFO periods follow p3.
; Change `seed 12345` for a new variant with the same modulation shape.

gaRevL init 0
gaRevR init 0

instr 1 ; conductor
  iTotal = p3
  seed 12345
  iFileLen = 306.49 ; Media/Wurstsalad.wav, stereo 48k
  iTwoPi = 6.2831853

  kT timeinsts ; seconds since this note started

  ; --- modulators: one sine each, periods locked to piece length ---
  kSinT   oscil3 1, 1 / iTotal, 1            ; 1 cycle per piece
  kSin2T  oscil3 1, 2 / iTotal, 1, 0           ; 2 cycles
  kSin3T  oscil3 1, 3 / iTotal, 1, 0.5        ; 3 cycles
  kSin5T  oscil3 1, 5 / iTotal, 1, 0.75       ; 5 cycles
  kSinH   oscil3 1, 2 / iTotal, 1, 0.125      ; reverb: 2 cycles (period T/2)

  ; --- event density: ~0.02..0.26 grains/sec over one sine (4x v01) ---
  ; (60-120 s grains, so ~4-16 voices overlap; troughs go sparse)
  kRate = 0.14 + 0.12 * kSinT
  kTrig metro kRate

  ; --- per-grain bounds, all time-varying ---
  kDurLo = 60 + 10 * kSin3T                  ; 50..70 s
  kDurHi = 105 + 15 * kSin5T                 ; 90..120 s
  kDur random kDurLo, kDurHi

  kAmpHi = -12 + 4 * kSin3T                  ; -16..-8 dB
  kAmpW  = 20 + 8 * (0.5 + 0.5 * kSin5T)     ; width 20..28 dB
  kAmpDb random kAmpHi - kAmpW, kAmpHi

  kCentsCtr = 600 * kSinT                     ; drift -600..+600, 1 cycle/piece
  kCentsRnd random -600, 600
  kCents limit kCentsCtr + kCentsRnd, -1200, 1200
  kRatio = 2 ^ (kCents / 1200)               ; 0.5..2.0 playback rate

  kRevCtr = 0.4 + 0.25 * kSinH               ; 0.15..0.65, period T/2
  kRevRnd random -1, 1
  kRevSend limit kRevCtr + 0.2 * kRevRnd, 0, 0.9

  kSkipMax = iFileLen - kDur * kRatio - 0.1
  if kSkipMax < 0.1 then
    kSkipMax = 0.1
  endif
  kSkip random 0, kSkipMax

  schedkwhen kTrig, 0, 0, 2, 0, kDur, kAmpDb, kSkip, kRatio, kRevSend
endin

instr 2 ; grain: pitched stereo slice, mono-summed dead center
  iDur = p3
  iAmp = ampdb(p4)
  iSkip = p5
  iRatio = p6
  iRevSend = p7

  a1, a2 diskin2 "/home/frank/Wurstsalad/Media/Wurstsalad.wav", iRatio, iSkip, 0
  iAtt = 0.3 * iDur
  iRel = 0.3 * iDur
  kEnv linseg 0, iAtt, iAmp, iDur - iAtt - iRel, iAmp, iRel, 0
  aL = a1 * kEnv
  aR = a2 * kEnv
  outch 1, aL, 2, aR
  gaRevL = gaRevL + aL * iRevSend
  gaRevR = gaRevR + aR * iRevSend
endin

instr 99 ; global reverb, wet mix rides the same T/2 sine as send center
  iTotal = p3 - 6 ; score gives 6 s tail; recover conductor length
  kT timeinsts
  kMix oscil3 0.5, 2 / iTotal, 1, 0.125
  kWet = 0.2 + 0.6 * (0.5 + 0.5 * kMix)
  aWL, aWR reverbsc gaRevL, gaRevR, 0.8, 12000
  outch 1, aWL * kWet, 2, aWR * kWet
  gaRevL = 0
  gaRevR = 0
endin

</CsInstruments>
<CsScore>
f1 0 16384 10 1
i1 0 3600
i99 0 3606
</CsScore>
</CsoundSynthesizer>
