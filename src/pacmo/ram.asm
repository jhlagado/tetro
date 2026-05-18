; RAM layout for the Pacmo scrolling experiment.
RamStart:
PlayerX:
        DB      0
PlayerY:
        DB      0
Monsters:
Monster0:
        DS      MonsterSize
Monster1:
        DS      MonsterSize
Monster2:
        DS      MonsterSize
EnemyX EQU Monster0 + MonsterX
EnemyY EQU Monster0 + MonsterY
EnemyDir EQU Monster0 + MonsterDir
EnemyTimer EQU Monster0 + MonsterTimer
EnemyRespTimer EQU Monster0 + MonRespTimer
EnemyState EQU Monster0 + MonsterState
Enemy2X EQU Monster1 + MonsterX
Enemy2Y EQU Monster1 + MonsterY
Enemy2Dir EQU Monster1 + MonsterDir
Enemy2Timer EQU Monster1 + MonsterTimer
Enemy2RespTimer EQU Monster1 + MonRespTimer
Enemy2State EQU Monster1 + MonsterState
Enemy3X EQU Monster2 + MonsterX
Enemy3Y EQU Monster2 + MonsterY
Enemy3Dir EQU Monster2 + MonsterDir
Enemy3Timer EQU Monster2 + MonsterTimer
Enemy3RespTimer EQU Monster2 + MonRespTimer
Enemy3State EQU Monster2 + MonsterState
EnemyPeriodCur:
        DB      0
ViewX:
        DB      0
ViewY:
        DB      0
MoveCooldown:
        DB      0
LastKey:
        DB      0
PacSplashActive:
        DB      0
PacPaused:
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
PacScore:
        DW      0
HudSegBuffer:
        DS      6
FramePhase:
        DB      0
LogicSlice:
        DB      0
RenderEatenPtr:
        DW      0
PacPwrPillsEat:
        DB      0
PacPowerTimer:
        DW      0
PacPowerTimerLo EQU PacPowerTimer
PacPowerTimerHi EQU PacPowerTimer + 1
PacRoundDone:
        DB      0
PacPlayerCaught:
        DB      0
PacGameOver:
        DB      0
PacLevel:
        DB      0
PacLives:
        DB      0
PacLvlDoneGate:
        DW      0
PacLvlDoneLo EQU PacLvlDoneGate
PacLvlDoneHi EQU PacLvlDoneGate + 1
PacGOverGate:
        DW      0
PacGOverGateLo EQU PacGOverGate
PacGOverGateHi EQU PacGOverGate + 1
ScanMask:
        DB      0
ScanPtr:
        DW      0
Framebuffer:
        DS      FramebufferBytes
FramebufferBack:
        DS      FramebufferBytes
PacEatenRows:
        DS      PacEatenBytes
RamEnd:
