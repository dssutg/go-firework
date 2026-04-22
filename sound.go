package main

import (
	"github.com/veandco/go-sdl2/mix"
)

type SoundID int

const (
	SoundFireworkExplosion0 SoundID = iota
	SoundFireworkExplosion1
	SoundFireworkExplosion2
	SoundFireworkExplosion3
)

type SoundDesc struct {
	Filename string
	Chunk    *mix.Chunk
}

var sounds = map[SoundID]SoundDesc{
	SoundFireworkExplosion0: {Filename: "sfx/firework_explosion0.ogg"},
	SoundFireworkExplosion1: {Filename: "sfx/firework_explosion1.ogg"},
	SoundFireworkExplosion2: {Filename: "sfx/firework_explosion2.ogg"},
	SoundFireworkExplosion3: {Filename: "sfx/firework_explosion3.ogg"},
}

func initAudio() error {
	if err := mix.Init(mix.INIT_OGG); err != nil {
		return err
	}

	if err := mix.OpenAudio(44100, mix.DEFAULT_FORMAT, 2, 1024); err != nil {
		return err
	}

	for id, sound := range sounds {
		chunk, err := mix.LoadWAV(sound.Filename)
		if err != nil {
			return err
		}
		sound.Chunk = chunk
		sounds[id] = sound
	}

	mix.AllocateChannels(128)

	return nil
}

func playSound(id SoundID, volume int) {
	chunk := sounds[id].Chunk
	chunk.Volume(volume)
	chunk.Play(-1, 0)
}
