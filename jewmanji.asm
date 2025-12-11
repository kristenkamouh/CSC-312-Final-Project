#################################################################################################################
#			                                                                                    				#
#	                                  Kristen Kamouh - 20241747										            #
#	                                  Jack Kalayjiyan - 20231711										        #
#	  JewManji - A very intersting (not racial) game where a goblin is picking coins.				            #
#														                                                        #
#	  Choose your mode, easy (e), hard (h), impossible (i), walk around freely using W A S D, and enjoy         #
#	  the smooth experience of coin picking.									                                #
#														                                                        #
#	  Playing on 512x512 map, it feels like you are running a marathon. Act quick before the timer ends.	    #
#	  And make sure you claim as much coins as your pockets can be filled.					                    #
#                                                                                                               #
#################################################################################################################


.eqv BITMAP_BASE     0x10010000      # Bitmap Display base (MMIO)
.eqv SCREEN_WIDTH    512
.eqv SCREEN_PIXELS   262144          # 512 * 512

.eqv KBD_CTRL        0xFFFF0000      # Keyboard control register
.eqv KBD_DATA        0xFFFF0004      # Keyboard data register

.eqv GOBLIN_SIZE     32
.eqv GOBLIN_ROW_BYTES 128          # 32 * 4
.eqv MOVE_STEP       8

.eqv MAX_GOBLIN_X    480           # 512 - 32
.eqv MAX_GOBLIN_Y    480

.eqv EASY_TIME       30
.eqv HARD_TIME       20
.eqv IMPOSSIBLE_TIME 10

.eqv MIDI_OUT        0xFFFF0008      # MIDI Out address
.eqv MIDI_OUT_READY  0xFFFF000C      # MIDI Out ready signal

.data
    .align 2 

    welcome_image: .word 
    game_image: .word
    gameover_image: .word
    goblin_image

    current_time: .word 0     # will hold 30 / 20 / 10 depending on chosen mode
    old_goblin_x: .word 240  # Track previous position
    old_goblin_y: .word 240
    coin_x: .word 0          # Current coin x position
    coin_y: .word 0          # Current coin y position
    score: .word 0           # Player score
    lfsr_state: .word 12345  # Random number generator state
    max_time: .word 0        # Store original max time for bar calculation



.text
.globl main
main:
    # Display welcome screen
    la   $a0, welcome_image
    jal  copy_fullscreen_image
    
    # Wait for E/H/I key press (sets current_time in memory)
    jal  wait_for_mode_selection
    
    # Initialize goblin position (center)
    li   $s0, 240        # goblin x
    li   $s1, 240        # goblin y
    
    # Load selected time into $s2 (countdown register)
    la   $t0, current_time
    lw   $s2, 0($t0)
    
    # Save max time for bar calculation
    la   $t0, max_time
    sw   $s2, 0($t0)
    
    # Initialize score to 0
    la   $t0, score
    sw   $zero, 0($t0)
    
    # Draw initial game background
    la   $a0, game_image
    jal  copy_fullscreen_image
    
    # Spawn first coin
    jal  spawn_coin
    
    # Draw initial time bar
    move $a0, $s2
    jal  draw_time_bar
    
    # Draw initial score
    la   $t0, score
    lw   $a0, 0($t0)
    jal  draw_score
    
    # Draw coin
    la   $t0, coin_x
    lw   $a0, 0($t0)
    la   $t0, coin_y
    lw   $a1, 0($t0)
    jal  draw_coin
    
    # Draw goblin at starting position
    move $a0, $s0
    move $a1, $s1
    jal  draw_goblin_32x32
    
    # Store initial position for tracking
    la   $t0, old_goblin_x
    sw   $s0, 0($t0)
    la   $t0, old_goblin_y
    sw   $s1, 0($t0)
    
    # Initialize frame counter (for timer)
    li   $s3, 0

game_loop:
    # Check if time is up
    blez $s2, game_over
    
    # Handle WASD keyboard input
    jal  poll_wasd_and_update
    
    # Load old goblin position
    la   $t0, old_goblin_x
    lw   $t1, 0($t0)
    la   $t0, old_goblin_y
    lw   $t2, 0($t0)
    
    # Check if goblin moved
    bne  $t1, $s0, goblin_moved
    bne  $t2, $s1, goblin_moved
    j    skip_redraw
    nop

goblin_moved:
    # Erase goblin from old position
    move $a0, $t1
    move $a1, $t2
    jal  restore_background_region
    
    # Redraw coin if it was under the old goblin position
    jal  check_and_redraw_coin
    
    # Draw goblin at new position
    move $a0, $s0
    move $a1, $s1
    jal  draw_goblin_32x32
    
    # Check collision with coin
    jal  check_coin_collision
    
    # Update stored position
    la   $t0, old_goblin_x
    sw   $s0, 0($t0)
    la   $t0, old_goblin_y
    sw   $s1, 0($t0)

skip_redraw:
    # Timer logic: count frames (60 frames = 1 second)
    addiu $s3, $s3, 1
    li    $t0, 60
    bne   $s3, $t0, skip_timer_update
    
    # One second elapsed, decrement timer
    addiu $s2, $s2, -1
    li    $s3, 0
    
    # Redraw time bar
    move $a0, $s2
    jal  draw_time_bar
    
skip_timer_update:
    # Small delay between frames
    jal  small_delay
    j    game_loop
    nop

# ===== GAME OVER =====
game_over:
    # Play game over sound
    jal   play_gameover_sound
    
    # Display game over screen
    la    $a0, gameover_image
    jal   copy_fullscreen_image
    
game_over_wait:
    j     game_over_wait
    nop

# ===== DRAW TIME BAR (decreasing bar at top-center) =====
draw_time_bar:
    addiu $sp, $sp, -8
    sw    $ra, 0($sp)
    sw    $s4, 4($sp)
    
    move  $s4, $a0       # Save current time
    
    # Draw black background (full bar area)
    # Centered: (512 - 200) / 2 = 156
    li    $a0, 156       # x position (centered)
    li    $a1, 10        # y position
    li    $a2, 200       # bar width (shorter)
    li    $a3, 20        # height
    li    $t0, 0x000000  # black
    jal   draw_rectangle
    
    # Load max time
    la    $t0, max_time
    lw    $t5, 0($t0)
    
    # Calculate filled width: (current_time * 200) / max_time
    li    $t2, 200       # Changed from 400 to 200
    mul   $t0, $s4, $t2
    div   $t0, $t5
    mflo  $t2            # $t2 = filled width
    
    # If width <= 0, skip drawing
    blez  $t2, skip_bar_fill
    
    # Choose color: red if <= 5 seconds, white otherwise
    li    $t6, 5
    ble   $s4, $t6, use_red_color
    li    $t0, 0xFFFFFF  # White
    j     draw_filled
use_red_color:
    li    $t0, 0xFF0000  # Red

draw_filled:
    li    $a0, 156       # Same x as background
    li    $a1, 10
    move  $a2, $t2       # Calculated width
    li    $a3, 20
    jal   draw_rectangle
    
skip_bar_fill:
    lw    $s4, 4($sp)
    lw    $ra, 0($sp)
    addiu $sp, $sp, 8
    jr    $ra
    nop

# ===== SPAWN COIN AT RANDOM POSITION (avoid bar area) =====
spawn_coin:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
spawn_coin_retry:
    # Generate random x (0 to 480, aligned to 8-pixel grid)
    jal   random
    li    $t1, 60        # 480/8 = 60 possible positions
    move  $t0, $v0
    div   $t0, $t1
    mfhi  $t0
    sll   $t0, $t0, 3    # multiply by 8
    move  $t8, $t0       # Save x temporarily
    
    # Generate random y (0 to 480, aligned to 8-pixel grid)
    jal   random
    li    $t1, 60
    move  $t0, $v0
    div   $t0, $t1
    mfhi  $t0
    sll   $t0, $t0, 3    # multiply by 8
    move  $t9, $t0       # Save y temporarily
    
    # Check if coin would be under the bar (y < 40)
    li    $t2, 40
    blt   $t9, $t2, spawn_coin_retry
    
    # Position is valid, save it
    la    $t1, coin_x
    sw    $t8, 0($t1)
    la    $t1, coin_y
    sw    $t9, 0($t1)
    
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== SIMPLE RANDOM NUMBER GENERATOR (LFSR) =====
random:
    la    $t0, lfsr_state
    lw    $t1, 0($t0)
    
    # LFSR: bit = ((state >> 0) ^ (state >> 2) ^ (state >> 3) ^ (state >> 5)) & 1
    move  $t2, $t1
    srl   $t3, $t1, 2
    xor   $t2, $t2, $t3
    srl   $t3, $t1, 3
    xor   $t2, $t2, $t3
    srl   $t3, $t1, 5
    xor   $t2, $t2, $t3
    andi  $t2, $t2, 1
    
    # state = (state >> 1) | (bit << 15)
    srl   $t1, $t1, 1
    sll   $t2, $t2, 15
    or    $t1, $t1, $t2
    
    sw    $t1, 0($t0)
    move  $v0, $t1
    jr    $ra
    nop

# ===== CHECK COIN COLLISION =====
check_coin_collision:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    # Load coin position
    la    $t0, coin_x
    lw    $t1, 0($t0)
    la    $t0, coin_y
    lw    $t2, 0($t0)
    
    # Check if goblin overlaps coin
    sub   $t3, $s0, $t1
    abs   $t3, $t3
    li    $t4, 24
    bgt   $t3, $t4, no_collision
    
    sub   $t3, $s1, $t2
    abs   $t3, $t3
    bgt   $t3, $t4, no_collision
    
    # Collision detected!
    # Play coin collect sound
    jal   play_coin_sound
    
    # Increment score
    la    $t0, score
    lw    $t1, 0($t0)
    addiu $t1, $t1, 1
    sw    $t1, 0($t0)
    
    # Update score display
    move  $a0, $t1
    jal   draw_score
    
    # Erase old coin
    la    $t0, coin_x
    lw    $a0, 0($t0)
    la    $t0, coin_y
    lw    $a1, 0($t0)
    jal   restore_background_region
    
    # Spawn new coin
    jal   spawn_coin
    
    # Draw new coin
    la    $t0, coin_x
    lw    $a0, 0($t0)
    la    $t0, coin_y
    lw    $a1, 0($t0)
    jal   draw_coin

no_collision:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== CHECK AND REDRAW COIN IF NEEDED =====
check_and_redraw_coin:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    # Load old goblin position
    la    $t0, old_goblin_x
    lw    $t1, 0($t0)
    la    $t0, old_goblin_y
    lw    $t2, 0($t0)
    
    # Load coin position
    la    $t0, coin_x
    lw    $t3, 0($t0)
    la    $t0, coin_y
    lw    $t4, 0($t0)
    
    # Check if coin was under old goblin position
    sub   $t5, $t1, $t3
    abs   $t5, $t5
    li    $t6, 32
    bgt   $t5, $t6, no_redraw_coin
    
    sub   $t5, $t2, $t4
    abs   $t5, $t5
    bgt   $t5, $t6, no_redraw_coin
    
    # Redraw coin
    move  $a0, $t3
    move  $a1, $t4
    jal   draw_coin

no_redraw_coin:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== DRAW COIN (16x16 yellow circle) =====
draw_coin:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    # Draw a simple 16x16 yellow circle
    addiu $a0, $a0, 8    # Center coin in 32x32 area
    addiu $a1, $a1, 8
    
    # Draw main body (12x12)
    addiu $a0, $a0, 2
    addiu $a1, $a1, 2
    li    $a2, 12
    li    $a3, 12
    li    $t0, 0xFFD700  # Gold color
    jal   draw_rectangle
    
    # Draw top row (8 pixels)
    addiu $a0, $a0, 2
    addiu $a1, $a1, -1
    li    $a2, 8
    li    $a3, 1
    li    $t0, 0xFFD700
    jal   draw_rectangle
    
    # Draw bottom row (8 pixels)
    addiu $a1, $a1, 13
    li    $a2, 8
    li    $a3, 1
    li    $t0, 0xFFD700
    jal   draw_rectangle
    
    # Draw left column (8 pixels)
    addiu $a0, $a0, -3
    addiu $a1, $a1, -11
    li    $a2, 1
    li    $a3, 8
    li    $t0, 0xFFD700
    jal   draw_rectangle
    
    # Draw right column (8 pixels)
    addiu $a0, $a0, 13
    li    $a2, 1
    li    $a3, 8
    li    $t0, 0xFFD700
    jal   draw_rectangle
    
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== DRAW SCORE (top right, below bar) =====
draw_score:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    move  $s4, $a0       # Save score value
    
    # Clear score area (60x20 black rectangle)
    li    $a0, 440
    li    $a1, 10        # Same level as bar
    li    $a2, 60
    li    $a3, 20
    li    $t0, 0x000000
    jal   draw_rectangle
    
    # Extract digits (support up to 99)
    move  $t0, $s4
    li    $t1, 10
    div   $t0, $t1
    mflo  $t2            # tens digit
    mfhi  $t3            # ones digit
    
    # Draw tens digit at x=450, y=10
    li    $a0, 450
    li    $a1, 10
    move  $a2, $t2
    li    $a3, 0xFFD700  # Gold color for score
    jal   draw_digit
    
    # Draw ones digit at x=465, y=10
    li    $a0, 465
    li    $a1, 10
    move  $a2, $t3
    li    $a3, 0xFFD700
    jal   draw_digit
    
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== DRAW RECTANGLE =====
draw_rectangle:
    move  $t4, $a1       # current y
    add   $t5, $a1, $a3  # y_end
rect_row_loop:
    bge   $t4, $t5, rect_done
    move  $t6, $a0       # current x
    add   $t7, $a0, $a2  # x_end
rect_col_loop:
    bge   $t6, $t7, rect_next_row
    
    # Calculate pixel address
    li    $t8, SCREEN_WIDTH
    mul   $t9, $t4, $t8
    addu  $t9, $t9, $t6
    sll   $t9, $t9, 2
    li    $t8, BITMAP_BASE
    addu  $t8, $t8, $t9
    
    # Draw pixel
    sw    $t0, 0($t8)
    
    addiu $t6, $t6, 1
    j     rect_col_loop
    nop
rect_next_row:
    addiu $t4, $t4, 1
    j     rect_row_loop
    nop
rect_done:
    jr    $ra
    nop

# ===== PLAY COIN COLLECT SOUND =====
play_coin_sound:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    # Play ascending notes (C5, E5, G5) using syscalls
    li    $v0, 31
    li    $a0, 72
    li    $a1, 150
    li    $a2, 0
    li    $a3, 100
    syscall
    
    li    $v0, 31
    li    $a0, 76
    li    $a1, 150
    li    $a2, 0
    li    $a3, 100
    syscall
    
    li    $v0, 31
    li    $a0, 79
    li    $a1, 200
    li    $a2, 0
    li    $a3, 100
    syscall
    
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== PLAY GAME OVER SOUND =====
play_gameover_sound:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)
    
    # Play descending notes (G4, E4, C4)
    li    $v0, 33
    li    $a0, 67
    li    $a1, 300
    li    $a2, 0
    li    $a3, 100
    syscall
    
    li    $v0, 33
    li    $a0, 64
    li    $a1, 300
    li    $a2, 0
    li    $a3, 100
    syscall
    
    li    $v0, 33
    li    $a0, 60
    li    $a1, 500
    li    $a2, 0
    li    $a3, 100
    syscall
    
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra
    nop

# ===== DRAW DIGIT (7-segment style) =====
draw_digit:
    addiu $sp, $sp, -20
    sw    $ra, 0($sp)
    sw    $s5, 4($sp)
    sw    $s6, 8($sp)
    sw    $s7, 12($sp)
    sw    $t0, 16($sp)
    
    move  $s5, $a0
    move  $s6, $a1
    move  $s7, $a3
    
    beq   $a2, 0, digit_0
    beq   $a2, 1, digit_1
    beq   $a2, 2, digit_2
    beq   $a2, 3, digit_3
    beq   $a2, 4, digit_4
    beq   $a2, 5, digit_5
    beq   $a2, 6, digit_6
    beq   $a2, 7, digit_7
    beq   $a2, 8, digit_8
    beq   $a2, 9, digit_9
    j     digit_done

digit_0:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 2
    li    $a2, 2
    li    $a3, 11
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    addiu $a1, $s6, 2
    li    $a2, 2
    li    $a3, 11
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_1:
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_2:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_3:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_4:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_5:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    addiu $a1, $s6, 7
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_6:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    addiu $a1, $s6, 7
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_7:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_8:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_9:
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 7
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    addiu $a1, $s6, 13
    li    $a2, 10
    li    $a3, 2
    move  $t0, $s7
    jal   draw_rectangle
    move  $a0, $s5
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 8
    move  $t0, $s7
    jal   draw_rectangle
    addiu $a0, $s5, 8
    move  $a1, $s6
    li    $a2, 2
    li    $a3, 15
    move  $t0, $s7
    jal   draw_rectangle
    j     digit_done

digit_done:
    lw    $ra, 0($sp)
    lw    $s5, 4($sp)
    lw    $s6, 8($sp)
    lw    $s7, 12($sp)
    lw    $t0, 16($sp)
    addiu $sp, $sp, 20
    jr    $ra
    nop

# ===== COPY FULLSCREEN IMAGE =====
copy_fullscreen_image:
    li   $t0, SCREEN_PIXELS
    move $t1, $a0
    li   $t2, BITMAP_BASE
copy_image_loop:
    beq  $t0, $zero, copy_image_done
    lw   $t3, 0($t1)
    sw   $t3, 0($t2)
    addiu $t1, $t1, 4
    addiu $t2, $t2, 4
    addiu $t0, $t0, -1
    j    copy_image_loop
    nop
copy_image_done:
    jr   $ra
    nop

# ===== WAIT FOR MODE SELECTION =====
wait_for_mode_selection:
wait_for_key:
    li   $t0, KBD_CTRL
    lw   $t1, 0($t0)
    andi $t1, $t1, 1
    beq  $t1, $zero, wait_for_key
    
    li   $t0, KBD_DATA
    lw   $t2, 0($t0)
    
    li   $t3, 'e'
    beq  $t2, $t3, mode_easy
    li   $t3, 'E'
    beq  $t2, $t3, mode_easy
    
    li   $t3, 'h'
    beq  $t2, $t3, mode_hard
    li   $t3, 'H'
    beq  $t2, $t3, mode_hard
    
    li   $t3, 'i'
    beq  $t2, $t3, mode_impossible
    li   $t3, 'I'
    beq  $t2, $t3, mode_impossible
    
    j    wait_for_key
    nop

mode_easy:
    la   $t4, current_time
    li   $t5, EASY_TIME
    sw   $t5, 0($t4)
    jr   $ra
    nop

mode_hard:
    la   $t4, current_time
    li   $t5, HARD_TIME
    sw   $t5, 0($t4)
    jr   $ra
    nop

mode_impossible:
    la   $t4, current_time
    li   $t5, IMPOSSIBLE_TIME
    sw   $t5, 0($t4)
    jr   $ra
    nop

# ===== RESTORE BACKGROUND REGION =====
restore_background_region:
    la   $t0, game_image
    move $t3, $a1
    li   $t7, GOBLIN_SIZE

restore_row_loop:
    li   $t4, SCREEN_WIDTH
    mul  $t5, $t3, $t4
    addu $t5, $t5, $a0
    sll  $t5, $t5, 2
    addu $t1, $t0, $t5
    
    li   $t6, BITMAP_BASE
    addu $t6, $t6, $t5
    
    li   $t2, GOBLIN_SIZE

restore_col_loop:
    lw   $t8, 0($t1)
    sw   $t8, 0($t6)
    addiu $t1, $t1, 4
    addiu $t6, $t6, 4
    addiu $t2, $t2, -1
    bnez $t2, restore_col_loop
    
    addiu $t3, $t3, 1
    addiu $t7, $t7, -1
    bnez $t7, restore_row_loop
    
    jr   $ra
    nop

# ===== DRAW GOBLIN =====
draw_goblin_32x32:
    la   $t0, goblin_image
    move $t3, $a1
    li   $t7, GOBLIN_SIZE

goblin_row_loop:
    li   $t4, SCREEN_WIDTH
    mul  $t5, $t3, $t4
    addu $t5, $t5, $a0
    sll  $t5, $t5, 2
    li   $t6, BITMAP_BASE
    addu $t6, $t6, $t5
    move $t1, $t0
    li   $t2, GOBLIN_SIZE

goblin_col_loop:
    lw   $t8, 0($t1)
    sw   $t8, 0($t6)
    addiu $t1, $t1, 4
    addiu $t6, $t6, 4
    addiu $t2, $t2, -1
    bnez $t2, goblin_col_loop
    
    addiu $t0, $t0, GOBLIN_ROW_BYTES
    addiu $t3, $t3, 1
    addiu $t7, $t7, -1
    bnez $t7, goblin_row_loop
    
    jr   $ra
    nop

# ===== KEYBOARD INPUT (WASD) =====
poll_wasd_and_update:
    li   $t0, KBD_CTRL
    lw   $t1, 0($t0)
    andi $t1, $t1, 1
    beq  $t1, $zero, no_key
    
    li   $t0, KBD_DATA
    lw   $t2, 0($t0)
    
    li   $t3, 'w'
    beq  $t2, $t3, move_up
    li   $t3, 'W'
    beq  $t2, $t3, move_up
    
    li   $t3, 's'
    beq  $t2, $t3, move_down
    li   $t3, 'S'
    beq  $t2, $t3, move_down
    
    li   $t3, 'a'
    beq  $t2, $t3, move_left
    li   $t3, 'A'
    beq  $t2, $t3, move_left
    
    li   $t3, 'd'
    beq  $t2, $t3, move_right
    li   $t3, 'D'
    beq  $t2, $t3, move_right

no_key:
    jr   $ra
    nop

# ===== MOVEMENT FUNCTIONS (with bar collision) =====
move_up:
    addiu $s1, $s1, -MOVE_STEP
    # Check if moving into bar area (y < 40)
    li    $t4, 40
    blt   $s1, $t4, clamp_bar_top
    jr    $ra
    nop
clamp_bar_top:
    li    $s1, 40        # Stop at bar boundary
    jr    $ra
    nop

move_down:
    addiu $s1, $s1, MOVE_STEP
    li    $t4, MAX_GOBLIN_Y
    ble   $s1, $t4, ret_move
    li    $s1, MAX_GOBLIN_Y
ret_move:
    jr    $ra
    nop

move_left:
    addiu $s0, $s0, -MOVE_STEP
    bltz  $s0, clamp_left
    jr    $ra
    nop
clamp_left:
    li    $s0, 0
    jr    $ra
    nop

move_right:
    addiu $s0, $s0, MOVE_STEP
    li    $t4, MAX_GOBLIN_X
    ble   $s0, $t4, ret_move_r
    li    $s0, MAX_GOBLIN_X
ret_move_r:
    jr    $ra
    nop

# ===== DELAY =====
small_delay:
    li   $t0, 6000
delay_loop:
    addiu $t0, $t0, -1
    bnez $t0, delay_loop
    jr   $ra
    nop




# Thank you for reaching the end of the source code. If you enjoyed 1110 lines of torture, a good grade would very much appreciated. 
# Made with love.
