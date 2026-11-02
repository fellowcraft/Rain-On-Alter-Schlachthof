<CsoundSynthesizer>
<CsOptions>
-odac -d
</CsOptions>
<CsInstruments>

sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

; Wurstsalad09 — changes vs 08: -1.6 dB trim (ceiling -9.6..-1.6 dB) so the
; full mix lands at -2 dB peak. Otherwise same as 08.
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

  kAmpHi = -5.6 + 4 * kSin3T                 ; -9.6..-1.6 dB
  kAmpW  = 16 + 8 * (0.5 + 0.5 * kSin5T)     ; width 16..24 dB
  kAmpDb random kAmpHi - kAmpW, kAmpHi

  kCentsBase random -600, 600                ; static offset per grain
  kWobAmp random 100, 600                   ; wobble depth in cents
  kWobPeriod random 20, 600                 ; 20 s..10 min, independent each grain

  kRevCtr = 0.4 + 0.25 * kSinH               ; 0.15..0.65, period T/2
  kRevRnd random -1, 1
  kRevSend limit kRevCtr + 0.2 * kRevRnd, 0, 0.9

  kDirRnd random 0, 1
  if kDirRnd < 0.5 then
    kSign = 1 ; forwards
    kSkipMax = iFileLen - kDur * 2.0 - 0.1
    kSkipMin = 0
  else
    kSign = -1 ; backwards, read toward file start
    kSkipMax = iFileLen - 0.1
    kSkipMin = kDur * 2.0 + 0.1
  endif
  if kSkipMax < kSkipMin then
    kSkipMax = kSkipMin
  endif
  kSkip random kSkipMin, kSkipMax
  kDir = kSign ; +1 fwd / -1 bwd, applied to rate in instr 2

  schedkwhen kTrig, 0, 0, 2, 0, kDur, kAmpDb, kSkip, kCentsBase, kWobAmp, kWobPeriod, kRevSend, kDir
endin

instr 2 ; grain: pitched stereo slice, own pitch wobble
  iDur = p3
  iAmp = ampdb(p4)
  iSkip = p5
  iCentsBase = p6
  iWobAmp = p7
  iWobPeriod = p8
  iRevSend = p9
  iDir = p10 ; +1 forwards, -1 backwards
  iPhs random 0, 1

  kWob oscil3 iWobAmp, 1 / iWobPeriod, 1, iPhs
  kCents limit iCentsBase + kWob, -1200, 1200
  kRatio = iDir * 2 ^ (kCents / 1200)
  a1, a2 diskin2 "/home/frank/Wurstsalad/Media/Wurstsalad.wav", kRatio, iSkip, 0
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
