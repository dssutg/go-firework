package main

import (
	"fmt"
	"log"
	"math/rand/v2"
	"slices"

	"github.com/veandco/go-sdl2/mix"
	"github.com/veandco/go-sdl2/sdl"
)

const (
	windowWidth  = 1920
	windowHeight = 1080
)

var (
	renderer      *sdl.Renderer
	launchTimer   int
	profilerTimer int
)

func main() {
	if err := initAudio(); err != nil {
		log.Fatal("audio init failed:", err)
	}
	defer mix.Quit()
	defer sdl.Quit()

	if err := sdl.Init(sdl.INIT_EVERYTHING); err != nil {
		log.Fatal("SDL init failed:", err)
	}

	// In practice, the maximum number of particles is around 10K.
	// Preallocate the memory for them but allow more if needed.
	particles = make([]Particle, 0, 10_000)

	for range 80 {
		x := float32(rand.IntN(windowWidth))
		y := float32(rand.IntN(windowHeight / 2))
		addStarParticle(x, y)
	}

	window, err := sdl.CreateWindow(
		"Firework",
		sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
		windowWidth, windowHeight,
		sdl.WINDOW_SHOWN,
	)
	if err != nil {
		log.Fatal("window create failed:", err)
	}
	defer window.Destroy()

	renderer, err = sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED|sdl.RENDERER_TARGETTEXTURE)
	if err != nil {
		log.Fatal("renderer create failed:", err)
	}
	defer renderer.Destroy()

	running := true
	for running {
		for event := sdl.PollEvent(); event != nil; event = sdl.PollEvent() {
			if _, ok := event.(*sdl.QuitEvent); ok {
				running = false
			}
		}

		launchTimer--
		if launchTimer <= 0 {
			rootCount := 3
			for i := range rootCount {
				x0 := windowWidth * i / rootCount
				x1 := windowWidth * (i + 1) / rootCount
				x := x0 + (x1-x0)/2

				delayDist := rand.IntN(701) + 100

				addMovingParticle(
					float32(x),
					float32(windowHeight+delayDist),
					0,
					-8,
					float32(windowHeight*3/4+delayDist),
					randomColor(),
					3,
				)
			}
			launchTimer = 5 * 60
		}

		profilerTimer++
		if profilerTimer >= 30 {
			profilerTimer = 0
			fmt.Println("particles:", len(particles))
		}

		for i := range particles {
			p := particles[i]
			p.tick()
			particles[i] = p
		}

		// Remove all particles marked as removed in a single pass
		particles = slices.DeleteFunc(particles, func(p Particle) bool {
			return p.removed
		})

		renderer.SetDrawColor(0, 0, 0, 255)
		renderer.Clear()

		for i := range particles {
			particles[i].render(renderer)
		}

		renderer.Present()
		sdl.Delay(1000 / 60)
	}
}
