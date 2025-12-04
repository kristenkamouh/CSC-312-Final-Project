################################
# CSC 312 - december 2025      #
# Kristen Kamouh - 20241747    #
################################

.eqv KEYBD_CTRL 0xffff0000
.eqv KEYBD_DATA 0xffff0004

.data
# image_backg: .word ... in the actual file there is the image

.align 2  
# Enemy 1 (top band)
enemy1_x:       .word 120
enemy1_y:       .word 10
enemy1_dir:     .word 1     # +1 = down, -1 = up

e1_active:      .word 0
e1_x:           .word 0
e1_y:           .word 0
e1_counter:     .word 0

# Enemy 2 (middle band)
enemy2_x:       .word 120
enemy2_y:       .word 60
enemy2_dir:     .word 1

e2_active:      .word 0
e2_x:           .word 0
e2_y:           .word 0
e2_counter:     .word 0

# Enemy 3 (bottom band)
enemy3_x:       .word 120
enemy3_y:       .word 105
enemy3_dir:     .word 1

e3_active:      .word 0
e3_x:           .word 0
e3_y:           .word 0
e3_counter:     .word 0

.text
.globl main

main:
    ########################################################
    # 1) Copy 128x128 background image_backg -> framebuffer
    ########################################################

    # source = image_backg
    la   $t0, image_backg
    # dest = 0x10040000 (heap / "video memory")
    li   $t1, 0x10040000

    # 128x128 words = 16384
    li   $t2, 16384

copy_loop_init:
    lw   $t3, 0($t0)
    sw   $t3, 0($t1)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez  $t2, copy_loop_init

    ########################################################
    # 2) Init game state
    ########################################################

    li   $s6, 0x10040000      # framebuffer base
    li   $s7, 128             # logical width in pixels

    # player start (center-ish)
    li   $s0, 64              # player_x
    li   $s1, 64              # player_y

    # player bullet state
    li   $s2, 0               # p_bullet_active = 0
    li   $s3, 0               # p_bullet_x
    li   $s4, 0               # p_bullet_y

############################################################
# 3) Main game loop (MMIO input, continuous update)
############################################################
game_loop:

    ########################################################
    # 3.1 Non-blocking keyboard input via MMIO
    ########################################################

    lw   $t9, KEYBD_CTRL      # read keyboard control
    andi $t9, $t9, 1          # bit0 = 1 if key available
    beqz $t9, no_key          # no key -> skip handling

    lw   $t0, KEYBD_DATA      # ASCII key

    # 'q' to quit
    li   $t1, 'q'
    beq  $t0, $t1, exit

    # movement keys
    li   $t1, 'w'
    beq  $t0, $t1, move_up
    li   $t1, 's'
    beq  $t0, $t1, move_down
    li   $t1, 'a'
    beq  $t0, $t1, move_left
    li   $t1, 'd'
    beq  $t0, $t1, move_right

    # fire bullet (player)
    li   $t1, 'f'
    beq  $t0, $t1, fire_bullet

    j    no_key

########################
# movement handlers
########################

move_up:
    addi $s1, $s1, -1          # y--
    bltz $s1, mu_clamp
    j    no_key
mu_clamp:
    li   $s1, 0
    j    no_key

move_down:
    addi $s1, $s1, 1           # y++
    li   $t0, 127
    ble  $s1, $t0, no_key
    li   $s1, 127
    j    no_key

move_left:
    addi $s0, $s0, -1          # x--
    bltz $s0, ml_clamp
    j    no_key
ml_clamp:
    li   $s0, 0
    j    no_key

move_right:
    addi $s0, $s0, 1           # x++
    li   $t0, 127
    ble  $s0, $t0, no_key
    li   $s0, 127
    j    no_key

########################
# fire bullet (player)
########################
fire_bullet:
    # only spawn if bullet not already active
    bnez $s2, no_key

    li   $s2, 1            # activate bullet
    move $s3, $s0          # bullet_x = player_x
    move $s4, $s1          # bullet_y = player_y
    j    no_key

########################################################
# After input: update world + draw everything
########################################################
no_key:

    ########################
    # 4.1 update player bullet (right)
    ########################
    beqz $s2, skip_pbullet_update   # not active -> skip

    addi $s3, $s3, 1                # bullet_x++

    li   $t0, 128                   # off-screen?
    bge  $s3, $t0, pbullet_offscreen
    j    skip_pbullet_update

pbullet_offscreen:
    li   $s2, 0                     # deactivate bullet

skip_pbullet_update:

    ########################
    # 4.2 update enemy 1 (top band ~0..30)
    ########################
    # counter1++
    la   $t0, e1_counter
    lw   $t1, 0($t0)
    addi $t1, $t1, 1
    sw   $t1, 0($t0)

    # maybe fire bullet1
    la   $t2, e1_active
    lw   $t3, 0($t2)
    bnez $t3, e1_skip_fire

    li   $t4, 40                  # fire every 40 frames-ish
    blt  $t1, $t4, e1_skip_fire

    # reset counter
    sw   $zero, 0($t0)

    # activate bullet
    li   $t3, 1
    sw   $t3, 0($t2)

    # bullet starts at enemy1_x, enemy1_y
    la   $t4, enemy1_x
    lw   $t5, 0($t4)
    la   $t6, enemy1_y
    lw   $t7, 0($t6)

    la   $t4, e1_x
    sw   $t5, 0($t4)
    la   $t4, e1_y
    sw   $t7, 0($t4)

e1_skip_fire:

    # update bullet1 (move left)
    la   $t2, e1_active
    lw   $t3, 0($t2)
    beqz $t3, e1_skip_bullet

    la   $t4, e1_x
    lw   $t5, 0($t4)
    addi $t5, $t5, -1

    sw   $t5, 0($t4)
    bltz $t5, e1_bullet_off
    j    e1_skip_bullet

e1_bullet_off:
    sw   $zero, 0($t2)          # deactivate

e1_skip_bullet:

    # move enemy1 vertically between 0 and 25
    la   $t4, enemy1_y
    lw   $t5, 0($t4)

    la   $t6, enemy1_dir
    lw   $t7, 0($t6)

    add  $t5, $t5, $t7          # y += dir

    li   $t8, 0                 # top
    li   $t9, 25                # bottom (top band)

    blt  $t5, $t8, e1_hit_top
    bgt  $t5, $t9, e1_hit_bottom
    j    e1_ok

e1_hit_top:
    move $t5, $t8
    li   $t7, 1                 # dir = down
    j    e1_ok

e1_hit_bottom:
    move $t5, $t9
    li   $t7, -1                # dir = up

e1_ok:
    sw   $t5, 0($t4)            # store y
    sw   $t7, 0($t6)            # store dir

    ########################
    # 4.3 update enemy 2 (middle band ~35..80)
    ########################
    # counter2++
    la   $t0, e2_counter
    lw   $t1, 0($t0)
    addi $t1, $t1, 1
    sw   $t1, 0($t0)

    # maybe fire bullet2
    la   $t2, e2_active
    lw   $t3, 0($t2)
    bnez $t3, e2_skip_fire

    li   $t4, 50                  # different interval
    blt  $t1, $t4, e2_skip_fire

    # reset counter
    sw   $zero, 0($t0)

    # activate bullet
    li   $t3, 1
    sw   $t3, 0($t2)

    # bullet starts at enemy2_x, enemy2_y
    la   $t4, enemy2_x
    lw   $t5, 0($t4)
    la   $t6, enemy2_y
    lw   $t7, 0($t6)

    la   $t4, e2_x
    sw   $t5, 0($t4)
    la   $t4, e2_y
    sw   $t7, 0($t4)

e2_skip_fire:

    # update bullet2 (move left)
    la   $t2, e2_active
    lw   $t3, 0($t2)
    beqz $t3, e2_skip_bullet

    la   $t4, e2_x
    lw   $t5, 0($t4)
    addi $t5, $t5, -1

    sw   $t5, 0($t4)
    bltz $t5, e2_bullet_off
    j    e2_skip_bullet

e2_bullet_off:
    sw   $zero, 0($t2)          # deactivate

e2_skip_bullet:

    # move enemy2 vertically between 35 and 80
    la   $t4, enemy2_y
    lw   $t5, 0($t4)

    la   $t6, enemy2_dir
    lw   $t7, 0($t6)

    add  $t5, $t5, $t7          # y += dir

    li   $t8, 35                # top
    li   $t9, 80                # bottom

    blt  $t5, $t8, e2_hit_top
    bgt  $t5, $t9, e2_hit_bottom
    j    e2_ok

e2_hit_top:
    move $t5, $t8
    li   $t7, 1
    j    e2_ok

e2_hit_bottom:
    move $t5, $t9
    li   $t7, -1

e2_ok:
    sw   $t5, 0($t4)
    sw   $t7, 0($t6)

    ########################
    # 4.4 update enemy 3 (bottom band ~90..125)
    ########################
    # counter3++
    la   $t0, e3_counter
    lw   $t1, 0($t0)
    addi $t1, $t1, 1
    sw   $t1, 0($t0)

    # maybe fire bullet3
    la   $t2, e3_active
    lw   $t3, 0($t2)
    bnez $t3, e3_skip_fire

    li   $t4, 60                  # different interval
    blt  $t1, $t4, e3_skip_fire

    # reset counter
    sw   $zero, 0($t0)

    # activate bullet
    li   $t3, 1
    sw   $t3, 0($t2)

    # bullet starts at enemy3_x, enemy3_y
    la   $t4, enemy3_x
    lw   $t5, 0($t4)
    la   $t6, enemy3_y
    lw   $t7, 0($t6)

    la   $t4, e3_x
    sw   $t5, 0($t4)
    la   $t4, e3_y
    sw   $t7, 0($t4)

e3_skip_fire:

    # update bullet3 (move left)
    la   $t2, e3_active
    lw   $t3, 0($t2)
    beqz $t3, e3_skip_bullet

    la   $t4, e3_x
    lw   $t5, 0($t4)
    addi $t5, $t5, -1

    sw   $t5, 0($t4)
    bltz $t5, e3_bullet_off
    j    e3_skip_bullet

e3_bullet_off:
    sw   $zero, 0($t2)          # deactivate

e3_skip_bullet:

    # move enemy3 vertically between 90 and 125
    la   $t4, enemy3_y
    lw   $t5, 0($t4)

    la   $t6, enemy3_dir
    lw   $t7, 0($t6)

    add  $t5, $t5, $t7          # y += dir

    li   $t8, 90                # top
    li   $t9, 125               # bottom (clamp to screen)
    blt  $t5, $t8, e3_hit_top
    bgt  $t5, $t9, e3_hit_bottom
    j    e3_ok

e3_hit_top:
    move $t5, $t8
    li   $t7, 1
    j    e3_ok

e3_hit_bottom:
    move $t5, $t9
    li   $t7, -1

e3_ok:
    sw   $t5, 0($t4)
    sw   $t7, 0($t6)

    ########################
    # 4.5 redraw background
    ########################
    jal  redraw_background

    ########################
    # 4.6 draw player (3x3 red)
    ########################
    move $a0, $s0                  # x
    move $a1, $s1                  # y
    li   $a2, 0x00FF0000           # red
    li   $a3, 3                    # size
    jal  draw_block

    ########################
    # 4.7 draw player bullet if active (2x2 yellow)
    ########################
    beqz $s2, skip_pbullet_draw

    move $a0, $s3                  # x
    move $a1, $s4                  # y
    li   $a2, 0x00FFFF00           # yellow
    li   $a3, 2                    # size
    jal  draw_block

skip_pbullet_draw:

    ########################
    # 4.8 draw enemies + their bullets
    ########################

    # enemy1
    la   $t0, enemy1_x
    lw   $t1, 0($t0)
    la   $t2, enemy1_y
    lw   $t3, 0($t2)

    move $a0, $t1
    move $a1, $t3
    li   $a2, 0x0000FF00           # green
    li   $a3, 3
    jal  draw_block

    # e1 bullet
    la   $t4, e1_active
    lw   $t5, 0($t4)
    beqz $t5, skip_draw_e1b

    la   $t6, e1_x
    lw   $t7, 0($t6)
    la   $t6, e1_y
    lw   $t8, 0($t6)

    move $a0, $t7
    move $a1, $t8
    li   $a2, 0x000000FF           # blue
    li   $a3, 2
    jal  draw_block

skip_draw_e1b:

    # enemy2
    la   $t0, enemy2_x
    lw   $t1, 0($t0)
    la   $t2, enemy2_y
    lw   $t3, 0($t2)

    move $a0, $t1
    move $a1, $t3
    li   $a2, 0x0000FF00           # green
    li   $a3, 3
    jal  draw_block

    # e2 bullet
    la   $t4, e2_active
    lw   $t5, 0($t4)
    beqz $t5, skip_draw_e2b

    la   $t6, e2_x
    lw   $t7, 0($t6)
    la   $t6, e2_y
    lw   $t8, 0($t6)

    move $a0, $t7
    move $a1, $t8
    li   $a2, 0x000000FF           # blue
    li   $a3, 2
    jal  draw_block

skip_draw_e2b:

    # enemy3
    la   $t0, enemy3_x
    lw   $t1, 0($t0)
    la   $t2, enemy3_y
    lw   $t3, 0($t2)

    move $a0, $t1
    move $a1, $t3
    li   $a2, 0x0000FF00           # green
    li   $a3, 3
    jal  draw_block

    # e3 bullet
    la   $t4, e3_active
    lw   $t5, 0($t4)
    beqz $t5, skip_draw_e3b

    la   $t6, e3_x
    lw   $t7, 0($t6)
    la   $t6, e3_y
    lw   $t8, 0($t6)

    move $a0, $t7
    move $a1, $t8
    li   $a2, 0x000000FF           # blue
    li   $a3, 2
    jal  draw_block

skip_draw_e3b:

    ########################
    # 4.9 small delay
    ########################
    li   $a0, 30                   # ms
    li   $v0, 32                   # sleep
    syscall

    j    game_loop

########################
# redraw_background
########################
redraw_background:
    la   $t0, image_backg
    li   $t1, 0x10040000
    li   $t2, 16384

redraw_loop:
    lw   $t3, 0($t0)
    sw   $t3, 0($t1)
    addiu $t0, $t0, 4
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez  $t2, redraw_loop
    jr   $ra

########################
# draw_block
# in: a0 = x, a1 = y, a2 = color, a3 = size
########################
draw_block:
    add  $t4, $zero, $a1      # current row = y
row_loop:
    add  $t5, $zero, $a0      # current col = x
    add  $t6, $zero, $a3      # remaining in row

col_loop:
    # offset = (row * width + col) * 4
    mul  $t0, $t4, $s7        # row * 128
    add  $t0, $t0, $t5        # + col
    sll  $t0, $t0, 2          # * 4 bytes
    add  $t0, $t0, $s6        # + base

    sw   $a2, 0($t0)          # store color

    addi $t5, $t5, 1
    addi $t6, $t6, -1
    bgtz $t6, col_loop

    addi $t4, $t4, 1
    addi $a3, $a3, -1
    bgtz $a3, row_loop

    jr   $ra

########################
# exit
########################
exit:
    li   $v0, 10
    syscall







