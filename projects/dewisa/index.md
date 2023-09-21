---
layout: page
title: Klipsch de-WiSA-fying
---

I have a Klipsch Reference Premiere HD Wireless system comprised of:

* 1×[RP-440WC](RP-440WC-Spec-Sheet.pdf) (center)
* 2×[RP-440WF](RP-440WF-Spec-Sheet.pdf) (floorstanding)
* 2×[RP-140WM](RP-140WM-Spec-Sheet.pdf) (bookshelf)
* 1×[RP-110WSW](RP-110WSW-Spec-Sheet.pdf) (subwoofer)

The biggest selling points of the system for us were 1) no cables running from the receiver to each speaker 2) the small size of the [receiver](RP-HUB1-Spec-Sheet.pdf). Also, the speakers were three or four orders of magnitude smaller than my [outgoing Cornwalls](IMG_9676.jpeg)[^marriage].

We first bought Fry's' floor models on clearance, a 2.1 system (2×floorstanding speakers and a subwoofer) plus the hub all marked "DEMO ONLY NOT FOR SALE", which we liked well enough to add factory-refurbished center and rear channels after we moved.

The system sounds great, the receiver's form factor really is awesome[^rack], I even like the remote. But WiSA never worked right for us. It uses 24 bands in the 5GHz spectrum that's shared with weather-radar and military applications which you might think was our problem, but it also obviously suffered interference from our Apple TV operating on a completely non-overlapping band. Despite wiring our input sources into ethernet, and after multiple rounds of firmware updates over the years, the system still suffered drops even when we played records.

I'm sad to say goodbye to the receiver, but it didn't support 4K anyway so its fate was inevitable. The speakers, on the other hand, still have a future if they can be converted into powered monitors.

## Reverse Engineering: Boards

These speakers use identical topologies: A power supply board feeds into an amplifier board, onto which a <abbr title="Digital Signal Processor">DSP</abbr> board is mounted, which itself carries a WiSA radio board.

Across all speakers, the DSP and WiSA radio boards appear identical. Other than the sub, the power supplies are identical as are the amplifier <abbr title="Printed Circuit Board">PCB</abbr>s (though their component population differs between models).

### WiSA Radio

This board appears to have been produced by Summit for Klipsch. It mounts directly to the DSP board, to which it outputs 8 digital audio streams.

_To investigate:_ Does it receive any information from the DSP board? Something to identify the speaker's model? Because the RP-HUB1 definitely knows what it's talking to.

### DSP

This PCB sits between the WiSA radio and the amplifier. It powers the LED at the front of the speaker and has a ribbon cable that connects to the control panel (or button, in the subwoofer's case) from which the user selects which speaker position (each corresponding to one of the WiSA radio's digital audio streams). The DSP also implements the crossover network, resulting in three differential pairs of output that are passed to the amplifier board.

_To investigate:_ Is the DSP hardware- and software- identical between all speakers? Does the amplifier board vary between models in a way that can be detected from the header and passed up to the WiSA radio board? That would allow for production of only one variant of both the WiSA radio and DSP boards, which seems like an outcome this topology was optimized for.

### Amplifier

The amplifier boards in the non-subwoofer models are populated with between 1 and 3 TI [TPA3116D2](tpa3116d2.pdf) amplifiers. They are configured to receive differential audio from the DSP board, but it may be practical to ground the cold side and use them single-ended:

> ### 7.3.7 Differential Inputs
>
> … To use the TPA31xxD2 family with a single-ended source, ac ground the negative input through a capacitor equal in value to the input capacitor on positive and apply the audio source to either input. In a single-ended input application, the unused input should be ac grounded at the audio source instead of at the device input for best noise performance.

## The Plan

With this knowledge, it seems like the best plan of action is to design a new PCB that can act as a drop-in replacement for the DSP board. It would:

1. Receive input from an XLR connector
1. Convert the balanced signal to single-ended with a Burr-Brown [INA134](ina134.pdf) or [INA137](ina137.pdf)[^dip]
1. Process the resulting signal into three bands of output (20-200Hz, 20-1,800Hz, 1.8-20kHz) for the amplifier board using an Analog Devices [ADAU1701](ADAU1701.pdf)
1. If using the amplifier board in a single-ended configuration isn't practical[^extra], each output channel will also need a TI [DRV134/DRV135](drv134.pdf)

[^marriage]: I'm still sad to have seen them go, but they outlived one of my dad's marriages followed by my own; keeping them wasn't worth the risk.
[^rack]: I don't understand why receivers are still 19" wide; no normal person is racking their stereo!
[^dip]: It might make sense to use a 8-pin DIP socket for these in combination with jumper(s) so the same board can handle a variety of line levels, though a 2-gang potentiometer wired as a [balanced attenuator](balanced-attenuator.jpg) would probably do just as well
[^extra]: Or I decide to go for extra credit?
