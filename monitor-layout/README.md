# Monitor Layout

Monitor Layout is a Noctalia Shell plugin for visually arranging multiple monitors and changing their resolutions, with support for both Sway and Hyprland compositors.

## Features

- Auto-detects and supports both Sway (`swaymsg`) and Hyprland (`hyprctl`) backends
- Drag monitors in a panel to change their positions
- Change each monitor's resolution, scale, and transform from the inspector
- Apply the draft layout back to your compositor from the same panel
- Backend and command paths are configurable

## Usage

1. Add the bar widget to your panel.
2. Open the Monitor Layout panel.
3. Drag display tiles to rearrange them visually.
4. Pick a resolution, scale, or transform for the selected output.
5. Click **Apply** to send the layout to your compositor (Sway or Hyprland).


## Notes

- Requires `swaymsg` for Sway or `hyprctl` for Hyprland to be available in PATH (or set custom command in settings)
- All user-facing text is translatable; see `i18n/`
- The plugin applies position, resolution, scale, and transform values as reported by your compositor

## Extending

To add support for a new compositor:
1. Implement a backend in `backends/` with the required interface (see SwayBackend.js, HyprlandBackend.js)
2. Import and register the backend in `Main.qml`
3. Add backend selection to settings if needed