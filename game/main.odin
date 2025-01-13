package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

Game_State :: struct {
	window_size:         rl.Vector2,
	paddle:              rl.Rectangle,
	paddle_speed:        f32,
	ball:                rl.Rectangle,
	ball_dir:            rl.Vector2,
	ball_speed:          f32,
	ai_paddle:           rl.Rectangle,
	ai_target_y:         f32,
	ai_reaction_delay:   f32,
	ai_reaction_counter: f32,
	score_player:        int,
	score_ai:            int,
	ai_reaction_timer:   f32,
}

main :: proc() {
	gs := Game_State {
		window_size = {1280, 720},
		paddle = {width = 30, height = 80},
		paddle_speed = 10,
		ball = {width = 30, height = 30},
		ball_speed = 10,
		ai_paddle = {width = 30, height = 80},
		ai_reaction_delay = 0.1,
		ai_reaction_timer = 0,
	}

	reset(&gs)

	using gs

	rl.InitWindow(i32(window_size.x), i32(window_size.y), "pong")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		if rl.IsKeyDown(.UP) {
			paddle.y -= paddle_speed
		}

		if rl.IsKeyDown(.DOWN) {
			paddle.y += paddle_speed
		}

		// clamp player paddle within the window so you shall not exit
		paddle.y = linalg.clamp(paddle.y, 0, window_size.y - paddle.height)

		ai_reaction_timer += rl.GetFrameTime()

		// adjust ai target if reaction timer >= delay
		if ai_reaction_timer >= ai_reaction_delay {
			ai_reaction_timer = 0
			ball_mid := ball.y + ball.height / 2
			if ball_dir.x < 0 {
				ai_target_y = ball_mid - ai_paddle.height / 2
			} else {
				ai_target_y = window_size.y / 2 - ai_paddle.height / 2
			}
		}

		// smoother ai movement towards target
		ai_paddle.y = linalg.lerp(ai_paddle.y, ai_target_y, 0.05)
		ai_paddle.y = linalg.clamp(ai_paddle.y, 0, window_size.y - ai_paddle.height)

		diff := ai_paddle.y + ai_paddle.height / 2 - ball.y + ball.height / 2

		if diff < 0 {
			ai_paddle.y += paddle_speed * 0.5
		}

		if diff > 0 {
			ai_paddle.y -= paddle_speed * 0.5
		}

		// make sure ai paddle doesn't escape the bounds
		ai_paddle.y = linalg.clamp(ai_paddle.y, 0, window_size.y - ai_paddle.height)

		next_ball_rect := ball
		next_ball_rect.y += ball_speed * ball_dir.y
		next_ball_rect.x += ball_speed * ball_dir.x

		// check ball collisions with top and bottom of the window to bounce
		if next_ball_rect.y <= 0 || next_ball_rect.y >= window_size.y - ball.height {
			ball_dir.y = -ball_dir.y
		}

		// check ball collisions with player or ai paddle and increase score
		if next_ball_rect.x >= window_size.x - ball.width {
			score_ai += 1
			reset(&gs)
		}

		if next_ball_rect.x < 0 {
			score_player += 1
			reset(&gs)
		}

		ball_dir = ball_dir_calculate(next_ball_rect, paddle) or_else ball_dir
		ball_dir = ball_dir_calculate(next_ball_rect, ai_paddle) or_else ball_dir

		ball.y += ball_speed * ball_dir.y
		ball.x += ball_speed * ball_dir.x

		// render everything
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		rl.DrawText(fmt.ctprintf("{}", score_ai), 12, 12, 32, rl.WHITE)
		rl.DrawText(fmt.ctprintf("{}", score_player), i32(window_size.x) - 28, 12, 32, rl.WHITE)

		rl.DrawRectangleRec(paddle, rl.WHITE)
		rl.DrawRectangleRec(ai_paddle, rl.WHITE)
		rl.DrawRectangleRec(ball, rl.RED)

		rl.EndDrawing()

		// free temp memory (big brain low level stuff)
		free_all(context.temp_allocator)
	}
}

// calculate new ball direction after collision with player or ai
ball_dir_calculate :: proc(ball: rl.Rectangle, paddle: rl.Rectangle) -> (rl.Vector2, bool) {
	if rl.CheckCollisionRecs(ball, paddle) {
		ball_center := rl.Vector2{ball.x + ball.width / 2, ball.y + ball.height / 2}
		paddle_center := rl.Vector2{paddle.x + paddle.width / 2, paddle.y + paddle.height / 2}
		return linalg.normalize0(ball_center - paddle_center), true
	}
	return {}, false
}

// resets everything to initial positions
reset :: proc(using gs: ^Game_State) {
	angle := rand.float32_range(-45, 46)
	if rand.int_max(100) % 2 == 0 do angle += 180
	r := math.to_radians(angle)

	ball_dir.x = math.cos(r)
	ball_dir.y = math.sin(r)

	ball.x = window_size.x / 2 - ball.width / 2
	ball.y = window_size.y / 2 - ball.height / 2

	paddle_margin: f32 = 50

	paddle.x = window_size.x - 80
	paddle.y = window_size.y / 2 - paddle.height / 2

	ai_paddle.x = paddle_margin
	ai_paddle.y = window_size.y / 2 - ai_paddle.height / 2
}
