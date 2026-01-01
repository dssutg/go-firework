package main

import "core:fmt"
import "core:math/rand"
import "core:os"

import SDL "vendor:sdl2"
import SDL_Mixer "vendor:sdl2/mixer"

window_width :: 1920
window_height :: 1080

renderer: ^SDL.Renderer

// All alive particles
particles: [dynamic]Particle

main :: proc() {
	if SDL.Init(SDL.INIT_EVERYTHING) != 0 ||
	   SDL.Init(SDL.INIT_AUDIO) == -1 ||
	   SDL_Mixer.OpenAudio(44100, SDL_Mixer.DEFAULT_FORMAT, 2, 4096) == -1 {
		fatalf("can't init SDL: %v", SDL.GetError())
	}
	defer SDL.Quit()

	SDL_Mixer.AllocateChannels(128)

	window := SDL.CreateWindow(
		"Firework",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		window_width,
		window_height,
		SDL.WindowFlags{},
	)
	if window == nil {
		fatalf("can't create window: %v", SDL.GetError())
	}
	defer SDL.DestroyWindow(window)

	renderer = SDL.CreateRenderer(
		window,
		-1,
		SDL.RENDERER_ACCELERATED | SDL.RENDERER_TARGETTEXTURE,
	)
	if renderer == nil {
		fatalf("can't create renderer: %v", SDL.GetError())
	}

	fill_sincos_table()

	firework_explosion0 = new_sound_effect("sfx/firewok_explosion0.ogg")
	firework_explosion1 = new_sound_effect("sfx/firewok_explosion1.ogg")
	firework_explosion2 = new_sound_effect("sfx/firewok_explosion2.ogg")
	firework_explosion3 = new_sound_effect("sfx/firewok_explosion3.ogg")

	// In practice, the maximum number of particles is around 10K.
	// Preallocate the memory for them but allow more if needed.
	reserve(&particles, 10_000)

	for i in 0 ..< 80 {
		x := f32(rand.int_range(0, window_width))
		y := f32(rand.int_range(0, window_height / 2))
		add_star_particle(x, y)
	}

	launch_time := 0

	profiler_info_time := 0

	running := true

	for running {
		event: SDL.Event
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				running = false
			}
		}

		launch_time -= 1
		if launch_time <= 0 {
			root_count := 3
			for i in 0 ..< root_count {
				x0 := window_width * i / root_count
				x1 := window_width * (i + 1) / root_count
				x := x0 + (x1 - x0) / 2

				delay_dist := rand.int_range(100, 800)

				add_moving_particle(
					f32(x),
					f32(window_height + delay_dist),
					0,
					-8,
					f32(window_height * 3 / 4 + delay_dist),
					random_color(),
					sub_explosions = 3,
				)
			}
			launch_time = 5 * 60
		}

		profiler_info_time += 1
		if profiler_info_time >= 30 {
			profiler_info_time = 0
			fmt.println("particles:", len(particles))
		}

		for _, i in particles {
			// Copy the particle being updated to avoid use-after-free.
			// The tick function creates new particles reallocating the particle array.
			// This invalidates the pointer to the current particle.
			p := particles[i]
			particle_tick(&p)
			particles[i] = p
		}

		// Remove all particles marked as removed in a single pass
		for i := 0; i < len(particles); i += 1 {
			if particles[i].removed {
				// We don't really care about the particle order
				// so we can simply swap the removed particle with
				// the last element, and decrease the length of the particle
				// array. This helps to avoid moving all the rest array elements
				// by one element. Since the current particle is replaced with
				// the last one, we also have to decrement the index
				// to not skip it in the next iteration.
				unordered_remove(&particles, i)
				i -= 1
			}
		}

		SDL.SetRenderDrawColor(renderer, 0, 0, 0, 0)
		SDL.RenderClear(renderer)

		for &p in particles {
			particle_render(&p)
		}

		SDL.RenderPresent(renderer)
		SDL.Delay(1000 / 60)
	}
}

new_sound_effect :: proc(filename: string) -> ^SDL_Mixer.Chunk {
	sound := SDL_Mixer.LoadWAV(cstring(raw_data(filename)))
	if sound == nil {
		fatalf("can't load %v: %v", filename, SDL.GetError())
	}
	return sound
}

play_sound :: proc(sound: ^SDL_Mixer.Chunk, volume: i32) {
	SDL_Mixer.VolumeChunk(sound, volume)
	SDL_Mixer.PlayChannel(-1, sound, 0)
}

fatalf :: proc(format: string, args: ..any) {
	fmt.printfln(format, ..args)
	os.exit(1)
}
