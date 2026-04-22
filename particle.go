package main

import (
	"math/rand/v2"

	"github.com/veandco/go-sdl2/sdl"
)

type ParticleVariant uint8

const (
	VariantFireworkMoving ParticleVariant = iota // moving particle head
	VariantFireworkTrail                         // the particle that forms the trail of the moving particle
	VariantFireworkFlash                         // the particle that forms the flash of the firework explosion
	VariantStatic                                // static, not moving particle, e.g., star
)

type Particle struct {
	variant       ParticleVariant
	x             float32
	y             float32
	x0            float32
	y0            float32
	xa            float32
	ya            float32
	maxDist       float32
	color         sdl.Color
	subExplosions int
	removed       bool
	flashTime     int
}

var particles []Particle

var colorPalette = []sdl.Color{
	{R: 255, G: 255, B: 255, A: 255},
	{R: 255, G: 0, B: 0, A: 255},
	{R: 0, G: 255, B: 0, A: 255},
	{R: 0, G: 0, B: 255, A: 255},
	{R: 255, G: 255, B: 0, A: 255},
	{R: 255, G: 0, B: 255, A: 255},
	{R: 0, G: 255, B: 255, A: 255},
}

func randomColor() sdl.Color {
	return colorPalette[rand.IntN(len(colorPalette))]
}

func addMovingParticle(x, y, xa, ya, maxDist float32, c sdl.Color, subExplosions int) {
	particles = append(particles, Particle{
		variant:       VariantFireworkMoving,
		x:             x,
		y:             y,
		x0:            x,
		y0:            y,
		xa:            xa,
		ya:            ya,
		maxDist:       maxDist,
		color:         c,
		subExplosions: subExplosions,
	})

	rnd := rand.IntN(100)

	switch {
	case rnd >= 80:
		playSound(SoundFireworkExplosion2, 15)
	case rnd >= 60:
		playSound(SoundFireworkExplosion1, 15)
	case rnd >= 10:
		playSound(SoundFireworkExplosion0, 15)
	default:
		playSound(SoundFireworkExplosion3, 15)
	}
}

func addTrailParticle(x, y float32, c sdl.Color) {
	particles = append(particles, Particle{
		variant: VariantFireworkTrail,
		x:       x,
		y:       y,
		x0:      x,
		y0:      y,
		color:   c,
	})
}

func addFlashParticle(x, y float32, brightness uint8) {
	particles = append(particles, Particle{
		variant: VariantFireworkFlash,
		x:       x,
		y:       y,
		x0:      x,
		y0:      y,
		color:   sdl.Color{R: brightness, G: brightness, B: brightness, A: 255},
	})
}

func addStarParticle(x, y float32) {
	br := uint8(rand.IntN(51) + 25)
	particles = append(particles, Particle{
		variant: VariantStatic,
		x:       x,
		y:       y,
		x0:      x,
		y0:      y,
		xa:      0,
		ya:      0,
		color:   sdl.Color{R: br, G: br, B: br, A: 255},
	})
}

func (p *Particle) tick() {
	switch p.variant {
	case VariantFireworkMoving:
		p.x += p.xa
		p.y += p.ya

		if rand.IntN(15) == 0 {
			p.ya += 0.3
		}

		xd := p.x - p.x0
		yd := p.y - p.y0
		sqrDist := xd*xd + yd*yd // assume no overflow
		if sqrDist < p.maxDist*p.maxDist {
			addTrailParticle(p.x, p.y, p.color)
			return
		}

		p.removed = true

		if p.subExplosions <= 0 {
			return
		}

		addMovingParticle(p.x, p.y, 0, 10, 300, p.color, 0)

		particleCount := rand.IntN(36) + 5
		commonColor := randomColor()
		manyColors := rand.IntN(3) == 0

		for range particleCount {
			angle := rand.IntN(360)
			sc := sincosTable[angle]

			speed := float32(3)
			deviationXa := float32(rand.IntN(3) - 1)
			deviationYa := float32(rand.IntN(3) - 1)
			deviationSpeed := float32(0.75)

			xa := sc.Cos*speed + deviationXa*deviationSpeed
			ya := sc.Sin*speed + deviationYa*deviationSpeed

			subExplosions := 0
			// reduce the probability of subsequent explosions
			if p.subExplosions > 1 && rand.IntN(6) == 0 {
				subExplosions = rand.IntN(p.subExplosions)
			}

			maxDist := float32(rand.IntN(121) + 80)
			color := commonColor
			if manyColors {
				color = randomColor()
			}

			addMovingParticle(p.x, p.y, xa, ya, maxDist, color, subExplosions)
		}

		for range particleCount * 4 {
			angle := rand.IntN(360)
			sc := sincosTable[angle]

			radius := float32(rand.IntN(20) + 1)

			x := p.x + sc.Cos*radius
			y := p.y + sc.Sin*radius

			brightness := uint8(rand.IntN(197) + 60)

			addFlashParticle(x, y, brightness)
		}

	case VariantFireworkTrail:
		dimColor(&p.color, 10)
		if isGrayscaleBlack(&p.color) {
			p.removed = true
		}

	case VariantFireworkFlash:
		dimColor(&p.color, 5)
		if isGrayscaleBlack(&p.color) {
			p.removed = true
		}

	case VariantStatic:
		// no logic for static particles
	}
}

func (p *Particle) render(r *sdl.Renderer) {
	r.SetDrawColor(p.color.R, p.color.G, p.color.B, p.color.A)
	r.FillRect(&sdl.Rect{X: int32(p.x), Y: int32(p.y), W: 3, H: 3})
}

func dimColor(c *sdl.Color, dim uint8) {
	c.R = sub(c.R, dim)
	c.G = sub(c.G, dim)
	c.B = sub(c.B, dim)
}

func sub(a, b uint8) uint8 {
	if a > b {
		return a - b
	}
	return 0
}

func isGrayscaleBlack(c *sdl.Color) bool {
	return (int(c.R)+int(c.G)+int(c.B))/3 == 0
}
