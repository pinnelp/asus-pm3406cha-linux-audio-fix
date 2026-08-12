# Evidence and scope

## Exact target

This workaround is hard-gated to the codec identity observed on the tested laptop:

- ASUS ExpertBook P3 / PM3406CHA
- Realtek ALC256
- codec vendor ID: `0x10ec0256`
- codec subsystem ID: `0x10433541`

It intentionally refuses to run on other Realtek/ASUS combinations.

## Linux observations before the workaround

On Parrot OS the analog PCM stream reached the ALC256 DACs, jack detection worked, and speaker/headphone pins were visible, yet both internal speakers and ordinary 3.5 mm headphones were silent. PipeWire routing, ALSA routing, mixer mute and simple EAPD/pin-only changes did not solve it.

## Working Windows reference

Working Windows RtHDDump captures showed two codec states.

Speaker state:

- GPIO mask/direction/data: `0x04 / 0x04 / 0x04`
- pin `0x14`: speaker OUT
- pin `0x21`: disabled, selector 1
- Realtek coefficients listed in `windows-profiles.csv`

Headphone state:

- GPIO mask/direction/data: `0x04 / 0x04 / 0x00`
- pin `0x14`: remains OUT
- pin `0x21`: OUT|HP, selector 1
- several Realtek coefficients change with jack state

## What changed from candidate v1

Live testing found that two Windows-reference coefficient values are not reliable hard verification targets under Linux:

- `coef 0x18`: Windows headphone reference is `0x0003`, but Linux could retain/read `0x003c` while the practical speaker/headphone workaround functioned. v2 does not write it.
- `coef 0x23`: a requested headphone write of `0x88f4` could read back as `0x8804`. v2 keeps the write as best-effort because it was part of the tested successful sequence, but does not use the readback as a success condition.

EAPD readback also showed asynchronous behavior during tests, so v2 still writes the measured Windows value (`0`) but treats readback as informational rather than a daemon-fatal invariant.

The remaining coefficient, GPIO and pin-control values in v2 are the subset that matched the working live state and are used as the required diagnostic signature.

## Explicitly not included

This repository does not attempt to:

- port Windows Dirac/APO processing;
- replace AMD ACP/HAP firmware;
- add a CS35L41/TAS/MAX discrete-amplifier quirk without matching hardware evidence;
- write GPIO0/GPIO1;
- install a custom kernel;
- install the earlier experimental early-firmware patch.

The project is a userspace HDA workaround for this exact codec/subsystem combination, pending a proper upstream kernel quirk.
