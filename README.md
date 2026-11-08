**English** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [日本語](README.ja.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md)

# alan

A body made of data that sounds like a drone. A script for
[monome norns](https://monome.org/docs/norns/): the screen shows a 3D human
figure built from points, a wire mesh and falling digits. Every part of the
body is a voice. Move it and the sound changes.

![alan](docs/sheet.png)

- **6 drone voices** that never stop: torso, head, two arms and two legs
- **20 joints** to move from the encoders, one body part at a time
- **self-motion**: the body moves on its own, like a wave running through
  the joints
- **free camera**: zoom, orbit and height; you can fly right through the figure
- **breath and heartbeat**: the chest swells and the heart speeds up with effort
- **dissolve**: body and sound break apart into particles and grains
- **8 pose slots** (7 factory poses) to save and recall
- 6 scales and an adjustable root, so everything stays in tune

## Requirements

- norns (any: shield, standard or fates)
- no MIDI keyboard or controller needed: it is played with the encoders and keys

## Install

From maiden:

```
;install https://github.com/buenosairesfront/alan
```

Then **restart norns** (SYSTEM > RESTART) so the new `Turing` engine
compiles, and load **alan** from SELECT.

## Intro

![intro](docs/1_title.png)

When the script opens you get the U-MA intro, then a close-up of Alan's head
with his name. The camera pulls back until the whole body is in view. Any key
or encoder skips ahead.

## Controls

### Moving the body

![choosing a part](docs/3_select.png)

| control | action |
|---|---|
| E1 | choose a body part (a small map in the top left shows which one) |
| E2 / E3 | move the chosen part (each part has two movements) |
| hold K3 | dissolve: the body falls apart into particles; release to bring it back |
| hold K2 + E2 | self-motion speed |
| hold K2 + E3 | self-motion amount |

The parts, in order: head (turn / nod), left shoulder, left elbow, left hip,
left knee and ankle, right knee and ankle, right hip, right elbow, right
shoulder and waist (bend / twist).

With self-motion on, the part you touch stays in your hands for a couple of
seconds and then rejoins the wave.

### Camera

![camera](docs/5_camera.png)

Tap **K2** to enter or leave camera mode (the screen corners are marked).

| control | action |
|---|---|
| E1 | zoom: up close the camera aims at the head; keep going and it passes through the figure to look from the other side |
| E2 | orbit around the body |
| E3 | height (goes all the way around) |

If nothing is touched for 8 seconds the camera orbits by itself (this can be
turned off in PARAMS).

### Poses and tuning (hold K1)

![a pose](docs/4_pose.png)

| control | action |
|---|---|
| K1 + E1 | choose a pose (1 to 8): the body moves through each one as you turn |
| K1 + K2 | save the current pose to that slot |
| K1 + K3 | load the pose in that slot |
| K1 + E2 | breath |
| K1 + E3 | root note |

Saved poses live in `data/alan/poses.tab` and replace the factory pose in
that slot.

## How it sounds

![the body in motion](docs/2_body.png)

Each body part drives one voice. Notes always land on the chosen scale.

| voice | sound | what changes it |
|---|---|---|
| torso | deep sub, heartbeat and air | bending darkens it; twisting opens a chorus of saws |
| head | a choir singing vowels | looking up raises the pitch; turning the head changes the vowel (a e i o u) |
| arms | resonant tendon (noise bowed through resonators) | hand height is the note, reach opens the filter, a bent elbow makes the tone inharmonic |
| legs | low bone and wood | foot height is the note, opening the hip opens the filter, a bent knee crackles |

- The further a part is from its resting position, the louder its voice.
- Moving fast makes it louder and brighter, and throws particles on screen.
- Pan and reverb come from the camera: what is on the left of the screen
  sounds on the left, and what is far away sounds distant.
- The heartbeat speeds up with the effort of the pose and with movement.

![dissolve](docs/6_dissolve.png)

## Parameters

In PARAMS > alan:

| parameter | what it does |
|---|---|
| tonica | root note, from E1 to E3 |
| escala | scale: dorian, aeolian, phrygian, lydian, pentatonic or fifths |
| respiracion | how much the body (and the sound) breathes |
| movimiento solo | amount of self-motion |
| movimiento velocidad | from one cycle every 50 s to one every 2.4 s |
| desintegracion base | keeps the body always slightly dissolved |
| auto orbita | the camera turns by itself after 8 s without input |
| espacio (reverb) | reverb size |
| volumen | overall volume |
| cuerpo | all 20 joints, one by one (handy for MIDI mapping) |

Parameter names are in Spanish on the device. Settings are saved when you
leave the script.

## Files

- `alan.lua`: the script
- `lib/Engine_Turing.sc`: the SuperCollider sound engine
- `lib/alan_title.bin`: the intro title
- `lib/uma_splash*.lua`, `lib/uma_particles.wav`: the U-MA intro

<!-- u-ma:more -->
**More from U-MA:** every instrument and tool in one place → [U-MA showcase](https://github.com/buenosairesfront/U-ma)
<!-- /u-ma:more -->

## Credits

Made by [Buenos Aires Front](https://github.com/buenosairesfront) / U-MA.
Released under the MIT license.
