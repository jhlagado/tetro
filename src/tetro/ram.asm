; RAM layout.
; Mutable program state. InitState sets explicit
; defaults and clears buffers that need a known
; startup value.
RamStart:
PlayerX:
        DB      0

PlayerY:
        DB      0

MoveCooldown:
        DB      0

GravityCooldown:
        DB      0

CurGravPeriod:
        DB      0

LastKey:
        DB      0

PendingX:
        DB      0

PendingY:
        DB      0

ShiftCount:
        DB      0

CurPiecePtr:
        DW      0

CurPieceIndex:
        DB      0

CurrentRotation:
        DB      0

CurPieceRight:
        DB      0

CurPieceColor:
        DB      0

NextPieceIndex:
        DB      0

PendingRotation:
        DB      0

Paused:
        DB      0

DropLockout:
        DB      0

GameOver:
        DB      0

; 16-bit restart-delay countdown.
; Accessed as a word via LD HL,(GOverKeyGateLo)
; and written back as HL.
GOverKeyGate:
        DW      0
GOverKeyGateLo   EQU     GOverKeyGate
GOverKeyGateHi   EQU     GOverKeyGate + 1

ActPieceEnabled:
        DB      0

ClearPending:
        DB      0

ClearMask:
        DB      0

ClearTimer:
        DB      0

LinesClearTotal:
        DB      0

; 16-bit Score.
; Accessed as a word via LD HL,(ScoreLo);
; ScoreHi is the high byte, cleared by
; InitStateBase.
Score:
        DW      0
ScoreLo        EQU     Score
ScoreHi        EQU     Score + 1

SplashTimer:
        DB      0

RngSeed:
        DB      0

InputLockout:
        DB      0

HudScanIndex:
        DB      0

SpeakerPort:
        DB      0

SoundTimer:
        DB      0

SndDivReload:
        DB      0

SndDivCount:
        DB      0

HudSegBuffer:
        DS      6

; Full-matrix wrap counter.
; ScanNext increments on each framebuffer wrap.
; Used only by SplashState for RNG entropy;
; not used for gravity, input, or pacing timers.
FramePhase:
        DB      0

LogicSlice:
        DB      0

ScanMask:
        DB      0

ScanPtr:
        DW      0

BoardRows:
        DS      RowCount

BoardRed:
        DS      RowCount

BoardGreen:
        DS      RowCount

BoardBlue:
        DS      RowCount

BoardEmpty:
        DB      0

Framebuffer:
        DS      FramebufferBytes

; Off-screen compose buffer.
; The live Framebuffer is updated atomically
; from here in slice 7.
FramebufferBack:
        DS      FramebufferBytes

RamEnd:
