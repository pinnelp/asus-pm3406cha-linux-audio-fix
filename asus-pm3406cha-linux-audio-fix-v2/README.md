# ASUS ExpertBook PM3406CHA ALC256 Linux audio fix

Experimental userspace workaround for silent **internal speakers and 3.5 mm headphones** on the ASUS ExpertBook PM3406CHA with the Realtek ALC256 codec.

## Tested hardware

- ASUS ExpertBook P3 / `PM3406CHA`
- Realtek ALC256
- codec vendor: `0x10ec0256`
- ASUS subsystem: `0x10433541`
- tested during development on Parrot OS 7 / kernel `7.0.13+parrot7-amd64`

**Do not use this on a different codec/subsystem ID.** The scripts also enforce this check before writing HDA state.

## Status

The live workaround was validated with both outputs:

- internal speakers produce audio;
- ordinary 3.5 mm headphones produce audio;
- unplugging/replugging the headset and resuming playback switches between the two outputs.

The workaround is based on codec/GPIO states captured from a working Windows installation on the same laptop.

## What v2 fixes

Candidate v1 treated every Windows coefficient readback as a hard invariant. Live Linux testing showed that this was wrong for at least two values:

- coefficient `0x18` can remain at `0x003c` instead of the Windows headphone reference `0x0003`;
- coefficient `0x23` can remain at `0x8804` instead of `0x88f4`.

Those mismatches do **not** by themselves mean audio is broken. v2 therefore:

- does not write coefficient `0x18`;
- writes `0x23` only as a best-effort part of the tested sequence;
- does not abort a profile transition because of those two readbacks;
- treats EAPD readback as informational because it can change asynchronously;
- verifies only the controls that proved stable/relevant in the working Linux state;
- debounces jack transitions and applies the complete profile without aborting halfway through;
- removes the unused early-firmware/kernel experiments from the release.

See `EVIDENCE.md` and `windows-profiles.csv` for the derivation.

## Requirements

Debian/Parrot/Ubuntu-family systems:

```bash
sudo apt update
sudo apt install alsa-tools
```

The key utility is `hda-verb`.

## Live test first

Clone/extract the repository and run:

```bash
sudo ./apply-profile.sh auto
sudo ./verify-state.sh auto
```

Then test normal playback on the currently selected output.

You can also force a mode for diagnosis:

```bash
sudo ./apply-profile.sh speaker
sudo ./apply-profile.sh headphone
```

`verify-state.sh` separates **required state** from **dynamic Windows-reference fields**. Informational mismatches for `0x18`, `0x23`, or EAPD are not automatically failures.

## Persistent installation

Only after the live test works:

```bash
sudo ./install.sh --confirmed
```

The systemd service watches jack sense, debounces plug/unplug transitions and reapplies the corresponding tested profile. It also reapplies the current profile if the codec disappears/reappears across suspend/resume.

Check it with:

```bash
systemctl status pm3406cha-audio-fix.service --no-pager
journalctl -u pm3406cha-audio-fix.service -b
```

## Remove

```bash
sudo ./uninstall.sh
sudo reboot
```

## Safety

The workaround writes undocumented Realtek vendor coefficients. The scripts are hard-gated to `10ec:0256 / 1043:3541`, but this is still experimental hardware control. Keep volume low during first testing and do not adapt these coefficient values to another codec simply because it is also called ALC256.

## Technical summary

Speaker profile uses GPIO2 high (`0x04`) for the speaker path, speaker pin `0x14` as OUT, and disables headphone pin `0x21`.

Headphone profile keeps GPIO2 low, leaves `0x14` as OUT, selects connection 1 on pin `0x21`, and enables it as `OUT|HP` (`0xc0`). A small set of Realtek coefficients is switched between the Windows-derived speaker/headphone values.

This repository is deliberately a userspace workaround rather than pretending to be an upstream-quality kernel quirk. A future kernel fix should encode only the minimum proven initialization/state changes for subsystem `1043:3541`.

## License

No license is selected in this bundle. Add the license you want before publishing if you intend others to reuse or redistribute the code.
