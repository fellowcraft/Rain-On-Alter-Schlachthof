<CsoundSynthesizer>
<CsOptions>
-+rtaudio=pulse -o dac -d ; policy: REAPER owns the Scarlett on ALSA,
; everything else plays the current Pulse default sink (analog out)
</CsOptions>
<CsInstruments>

sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

; Wurstsalad16 — changes vs 15: seed follows the take number, so every
; take is a different performance (before: fixed seed repeated take01).
; Logs remain the recall mechanism; same take number replays identically.
; scheduled grain to a per-take log Wurstsalad16-takeNN-events.sco (NN = 01, 02, ...;
; next number picked automatically each run) (start dur ampDb skip centsBase
; wobAmp wobPeriod revSend dir phase, full %.17g precision). Grain phase moved to the
; conductor so NOTHING is random inside instr 2: the log plus the recall
; template fully reproduces a take. Assembly:
; Launch takes ONLY via run-take.sh (plain csound run fails: no $TAKE).
; Recall assembly for take NN (e.g. NN=take01):
; awk '/;__EVENTS__/{while((getline l<"/mnt/bigdrive/CSOUND/Wurstsalad/takes/Wurstsalad16-take01-events.sco")>0)print l;next}1' /mnt/bigdrive/CSOUND/Wurstsalad/csd/Wurstsalad16-recall-template.csd > /mnt/bigdrive/CSOUND/Wurstsalad/takes/Wurstsalad16-recall-take01.csd
; Otherwise same as 11.
; Conductor (instr 1) schedules grains (instr 2) into global reverb (instr 99).
; Change iTotal in the score to change piece length; LFO periods follow p3.
; Take number seeds the PRNG: same take always identical, new take new piece.
; MODES (run-take.sh picks correctly; direct csound needs the macros below):
; generate: --omacro:TAKE=N  (logs takeNN, playback include stays empty)
; playback: --omacro:PLAYBACK=1 with Wurstsalad16-playback-events.sco holding
;   the take (run-take.sh copies it there automatically)

gaRevL init 0
gaRevR init 0

#ifdef PLAYBACK
instr 1 ; stub: playback mode, grains come from the score include
  turnoff
endin
#else
instr 1 ; conductor
  iTotal = p3
  ; --- take log: launch via run-take.sh, which passes --omacro:TAKE=N ---
#ifdef TAKE
  iTake = $TAKE
  STakeLog sprintf "/mnt/bigdrive/CSOUND/Wurstsalad/takes/Wurstsalad16-take%02d-events.sco", iTake
  giLog fiopen STakeLog, 0
  printf_i "Wurstsalad16 take %02d logging to %s\n", 1, iTake, STakeLog
#end ; TAKE
  ; --- take seed: run-take.sh passes --omacro:TAKE=N (different take,
  ; different performance; same N replays the same take via its log) ---
#ifdef TAKE
  seed $TAKE
#else
  seed 12345
#end ; TAKE
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
  kDurQ = int(kDur * 750 + 0.5) / 750 ; snap to k-cycle grid so note-off
                                      ; lands identically in live and recall

  kAmpHi = -5.1 + 4 * kSin3T                 ; -9.1..-1.1 dB
  kAmpW  = 28 + 8 * (0.5 + 0.5 * kSin5T)     ; width 28..36 dB
  kAmpDb random kAmpHi - kAmpW, kAmpHi

  kCentsBase random -600, 600                ; static offset per grain
  kWobAmp random 100, 600                   ; wobble depth in cents
  kWobPeriod random 20, 600                 ; 20 s..10 min, independent each grain

  kRevCtr = 0.4 + 0.25 * kSinH               ; 0.15..0.65, period T/2
  kRevRnd random -1, 1
  kRevSend limit kRevCtr + 0.2 * kRevRnd, 0, 0.9

  kDirRnd random 0, 1
  if kDirRnd < 0.75 then
    kSign = 1 ; forwards (75%)
    kSkipMax = iFileLen - kDurQ * 2.0 - 0.1
    kSkipMin = 0
  else
    kSign = -1 ; backwards (25%), read toward file start
    kSkipMax = iFileLen - 0.1
    kSkipMin = kDurQ * 2.0 + 0.1
  endif
  if kSkipMax < kSkipMin then
    kSkipMax = kSkipMin
  endif
  kSkip random kSkipMin, kSkipMax
  kDir = kSign ; +1 fwd / -1 bwd, applied to rate in instr 2
  kPhs random 0, 1 ; wobble start phase, logged so takes recall exactly

  ; snap start to the next k-cycle grid point and schedule exactly there,
  ; so live placement == logged time == recall placement, bit for bit
  kK = int(kT * 750)
  kTq = kK / 750
  if kTq < kT then
    kTq = (kK + 1) / 750
  endif

  if kTrig == 1 then
#ifdef TAKE
    fprintks giLog, "i2 %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g %.17g\\n", kTq, kDurQ, kAmpDb, kSkip, kCentsBase, kWobAmp, kWobPeriod, kRevSend, kDir, kPhs
#end ; TAKE
  endif

  schedkwhen kTrig, 0, 0, 2, kTq - kT, kDurQ, kAmpDb, kSkip, kCentsBase, kWobAmp, kWobPeriod, kRevSend, kDir, kPhs
endin
#end ; PLAYBACK conductor selection

instr 3 ; log closer, scheduled once at score end (generate mode only)
#ifdef TAKE
  ficlose giLog
#end ; TAKE
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
  iPhs = p11 ; logged wobble phase, no randomness left in this instrument
  xtratim 0.01 ; note-off lands in digital silence (envelope already 0),
                ; so score vs schedkwhen end-rounding cannot differ audibly

  kWob oscil3 iWobAmp, 1 / iWobPeriod, 1, iPhs
  kCents limit iCentsBase + kWob, -1200, 1200
  kRatio = iDir * 2 ^ (kCents / 1200)
  a1, a2 diskin2 "/mnt/bigdrive/CSOUND/Wurstsalad/Media/Wurstsalad.wav", kRatio, iSkip, 0
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
#include "/mnt/bigdrive/CSOUND/Wurstsalad/takes/Wurstsalad16-playback-events.sco"
i1 0 3600
i99 0 3606
i3 3606.5 0.5
</CsScore>
</CsoundSynthesizer>
