<CsoundSynthesizer>
<CsOptions>
-+rtaudio=pulse -o dac -d ; policy: REAPER owns the Scarlett on ALSA,
; everything else plays the current Pulse default sink (analog out)
</CsOptions>
<CsInstruments>

; Rain-Over-Slaughterhouse12-recall template. Static resynthesis: NO conductor, NO random
; calls, NO file I/O. Grain events come from a logged take assembled at
; the marker line in the score section (see Rain-Over-Slaughterhouse12.csd header).
; i99 length must stay conductor_len + 6 (instr 99 recovers LFO periods).

sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

gaRevL init 0
gaRevR init 0

instr 2 ; grain: pitched stereo slice, own pitch wobble
  iDur = p3
  iAmp = ampdb(p4)
  iSkip = p5
  iCentsBase = p6
  iWobAmp = p7
  iWobPeriod = p8
  iRevSend = p9
  iDir = p10 ; +1 forwards, -1 backwards
  iPhs = p11 ; logged wobble phase, no randomness left in this instrument
  xtratim 0.01 ; note-off lands in digital silence (envelope already 0),
                ; so score vs schedkwhen end-rounding cannot differ audibly

  kWob oscil3 iWobAmp, 1 / iWobPeriod, 1, iPhs
  kCents limit iCentsBase + kWob, -1200, 1200
  kRatio = iDir * 2 ^ (kCents / 1200)
  a1, a2 diskin2 "/mnt/bigdrive/CSOUND/Rain-Over-Slaughterhouse/Media/Rain-Over-Slaughterhouse.wav", kRatio, iSkip, 0
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
i99 0 3606
;__EVENTS__
</CsScore>
</CsoundSynthesizer>
