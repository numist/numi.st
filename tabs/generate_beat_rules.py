#! /usr/bin/env python3

def generate_beat_rules():
    grid_position = 3
    output = ""

    # Beats range from 1 to 4.95 (end of beat 4)
    for beat in range(1, 5):  # 4 beats
        for fraction in range(0, 24):  # 0.00 to 0.96 in increments of 0.04
            value = round(beat + fraction / 24, 2)
            output += f'.bar > [data-beat^="{value}"] {{ grid-column-start: {grid_position}; }}\n'
            grid_position += 1

    print(output)

# Generate and display CSS rules
generate_beat_rules()
