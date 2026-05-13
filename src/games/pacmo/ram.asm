; RAM layout for the Pacmo scrolling experiment.
RAM_START:
PLAYER_X:
        DS      1
PLAYER_Y:
        DS      1
VIEW_X:
        DS      1
VIEW_Y:
        DS      1
MOVE_COOLDOWN:
        DS      1
LAST_KEY:
        DS      1
HUD_SCAN_INDEX:
        DS      1
SPEAKER_PORT_STATE:
        DS      1
SOUND_TIMER:
        DS      1
HUD_SEG_BUFFER:
        DS      6
FRAME_PHASE:
        DS      1
LOGIC_SLICE:
        DS      1
RENDER_EATEN_PTR:
        DS      2
SCAN_MASK:
        DS      1
SCAN_PTR:
        DS      2
FRAMEBUFFER:
        DS      FRAMEBUFFER_BYTES
FRAMEBUFFER_BACK:
        DS      FRAMEBUFFER_BYTES
PACMO_EATEN_ROWS:
        DS      PACMO_EATEN_BYTES
RAM_END:
