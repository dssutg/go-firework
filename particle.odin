package main

import "core:math/rand"

import SDL "vendor:sdl2"
import SDL_Mixer "vendor:sdl2/mixer"

Particle_Variant :: enum u8 {
	FireworkMoving, // moving particle head
	FireworkTrail, // the particle that forms the trail of the moving particle
	FireworkFlash, // the particle that forms the flash of the firework explosion
	Static, // static, not moving particle, e.g., star
}

// Particle fat struct
Particle :: struct {
	variant:        Particle_Variant,
	x:              f32,
	y:              f32,
	x0:             f32,
	y0:             f32,
	xa:             f32,
	ya:             f32,
	max_dist:       f32,
	color:          SDL.Color,
	sub_explosions: int,
	removed:        bool,
	flash_time:     int,
}

// Firework explosion sounds for variety
firework_explosion0: ^SDL_Mixer.Chunk
firework_explosion1: ^SDL_Mixer.Chunk
firework_explosion2: ^SDL_Mixer.Chunk
firework_explosion3: ^SDL_Mixer.Chunk

add_moving_particle :: proc(x, y, xa, ya, max_dist: f32, color: SDL.Color, sub_explosions := 0) {
	p := Particle {
		variant        = .FireworkMoving,
		x              = x,
		y              = y,
		x0             = x,
		y0             = y,
		xa             = xa,
		ya             = ya,
		max_dist       = max_dist,
		color          = color,
		sub_explosions = sub_explosions,
	}

	append(&particles, p)

	rnd := rand.int_max(100)

	switch {
	case rnd >= 80:
		play_sound(firework_explosion2, 15)
	case rnd >= 60:
		play_sound(firework_explosion1, 15)
	case rnd >= 10:
		play_sound(firework_explosion0, 15)
	case:
		play_sound(firework_explosion3, 15)
	}
}

add_trail_particle :: proc(x, y: f32, color: SDL.Color) {
	p := Particle {
		variant = .FireworkTrail,
		x       = x,
		y       = y,
		x0      = x,
		y0      = y,
		color   = color,
	}
	append(&particles, p)
}

add_flash_particle :: proc(x, y: f32, brightness: u8) {
	p := Particle {
		variant = .FireworkFlash,
		x       = x,
		y       = y,
		x0      = x,
		y0      = y,
		color   = SDL.Color{brightness, brightness, brightness, 255},
	}
	append(&particles, p)
}

add_star_particle :: proc(x, y: f32) {
	br := u8(rand.int_range(25, 75))

	p := Particle {
		variant = .Static,
		x = x,
		y = y,
		x0 = x,
		y0 = y,
		xa = 0,
		ya = 0,
		color = SDL.Color{r = br, g = br, b = br, a = 255},
	}

	append(&particles, p)
}

particle_tick :: proc(p: ^Particle) {
	switch p.variant {
	case .FireworkMoving:
		p.x += p.xa
		p.y += p.ya

		if rand.int_max(15) == 0 {
			p.ya += 0.3
		}

		xd := p.x - p.x0
		yd := p.y - p.y0
		sqr_dist := xd * xd + yd * yd // assume no overflow
		if sqr_dist < p.max_dist * p.max_dist {
			add_trail_particle(p.x, p.y, p.color)
			return
		}

		p.removed = true

		if p.sub_explosions <= 0 {
			return
		}

		falling_color := p.color
		add_moving_particle(p.x, p.y, 0, 10, 300, falling_color, 0)

		particle_count := rand.int_range(5, 40)

		common_color := random_color()

		many_colors := rand.int_max(3) == 0

		for i in 0 ..< particle_count {
			angle := rand.int_max(360)

			speed := f32(3)

			deviation_xa := f32(rand.int_range(-1, 1))
			deviation_ya := f32(rand.int_range(-1, 1))
			deviation_speed := f32(0.75)

			sincos := sincos_table[angle]

			xa := sincos.cos * speed + deviation_xa * deviation_speed
			ya := sincos.sin * speed + deviation_ya * deviation_speed

			sub_explosions := 0
			if p.sub_explosions > 1 {
				// reduce the probability of subsequent explosions
				if rand.int_max(6) == 0 {
					sub_explosions = rand.int_max(p.sub_explosions)
				}
			}

			max_dist := f32(rand.int_range(80, 200))

			color := random_color() if many_colors else common_color

			add_moving_particle(p.x, p.y, xa, ya, max_dist, color, sub_explosions = sub_explosions)
		}

		for i in 0 ..< particle_count * 4 {
			angle := rand.int_max(360)
			sincos := sincos_table[angle]

			radius := f32(rand.int_range(1, 20))

			x := p.x + sincos.cos * radius
			y := p.y + sincos.sin * radius

			brightness := u8(rand.int_range(60, 256))

			add_flash_particle(x, y, brightness)
		}

	case .FireworkTrail:
		dim_color(&p.color, 10)
		if is_grayscale_black(&p.color) {
			p.removed = true
		}

	case .FireworkFlash:
		dim_color(&p.color, 5)
		if is_grayscale_black(&p.color) {
			p.removed = true
		}

	case .Static:
	// no logic for static particles
	}
}

particle_render :: proc(p: ^Particle) {
	SDL.SetRenderDrawColor(renderer, p.color.r, p.color.g, p.color.b, p.color.a)
	SDL.RenderFillRect(renderer, &SDL.Rect{x = i32(p.x), y = i32(p.y), w = 3, h = 3})
}

color_palette := [?]SDL.Color {
	{255, 255, 255, 255},
	{255, 000, 000, 255},
	{000, 255, 000, 255},
	{000, 000, 255, 255},
	{255, 255, 000, 255},
	{255, 000, 255, 255},
	{000, 255, 255, 255},
}

random_color :: proc() -> SDL.Color {
	return rand.choice(color_palette[:])
}

dim_color :: proc(color: ^SDL.Color, dim: u8) {
	color.r = u8(max(0, int(color.r) - int(dim)))
	color.g = u8(max(0, int(color.g) - int(dim)))
	color.b = u8(max(0, int(color.b) - int(dim)))
}

is_grayscale_black :: proc(color: ^SDL.Color) -> bool {
	return (int(color.r) + int(color.g) + int(color.b)) / 3 == 0
}
