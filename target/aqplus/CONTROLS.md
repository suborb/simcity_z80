# Aquarius+ controls

The Aquarius+ port uses a pointer and the shared character-cell menu. The
status panel also shows the most useful shortcuts while playing.

## City view

The arrow is the only cursor. The keys move it, and so does a mouse on the
ESP32 (a USB or Bluetooth LE mouse), the two added together; with no mouse the
keys do everything.

| Key | Action |
| --- | --- |
| `Q` / `A` / `O` / `P` | Move the arrow up / down / left / right |
| `Shift` + those | Move it twice as far |
| `Space` or `Enter` | The arrow's button: build or use the tool under it, pick a tool or a mini map spot |
| Mouse left button | The same |
| Mouse right button | Esc: the game menu |

The map scrolls when the arrow rests on its edge. The tool icons along the top
and the mini map are clicked with the arrow.

| Key | Action |
| --- | --- |
| `,` / `.` | Select the previous / next tool |
| `0`–`9` | Select a tool directly |
| `E` | Toggle coal / nuclear power |
| `H` | Toggle pause and running |
| `+` / `-` | Increase / decrease simulation speed |
| `M` | Cycle through the mini-map views |
| `B` | Open the budget screen |
| `V` | Open the evaluation screen |
| `S` | Save the city |
| `L` | Load a city |
| `X` | Open the game menu |

While a mini-map is displayed, `X` returns to the city view. The menu is the
main way to access options such as disasters, auto-budget, auto-bulldoze, sound,
and starting a new city.

## Menu

Use the cursor up/down keys, or `Q` / `A`, to move the selection. Press `Space`
or `Enter` to choose an item. Press `X` to close the menu.

Options that show a current value (for example, `SPEED: NORMAL` or
`POWER: COAL`) toggle or advance immediately and leave the menu open, so the
new value can be seen. Choose `Back` to return to the previous menu.

## Save and load

Choose **Save city** or **Load city** from the menu, or use `S` / `L`. Type the
filename with the keyboard and press `Enter`; cursor-left or delete removes the
last character while editing.
