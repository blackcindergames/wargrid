# Zoom levels

Raised by the owner (user, 2026-11-25, inbox): of today's three zoom steps only the furthest is useful, and the right set may depend on window size versus fullscreen. Questions not written yet: a research run fills them in the [RULES](RULES.md) shape.

## Findings (short, cited)
- Wargrid: three fixed steps, `game/scripts/match/match_screen.gd:17` `ZOOMS = [0.5, 1.0, 2.0]`, changed from the wheel (`orders.gd:440`) and pinch (`mouse_pan.gd:63`); the detail level is keyed on zoom (`graphics_settings.gd:34`). P3 already plans steps eased over 150 ms toward the cursor ([packages](../packages.md)). **source**
- Zero Hour default: continuous camera height between a minimum and a maximum, about 0.52x to 1.34x of the default height (retail `GameData.ini` `CameraHeight`, `MinCameraHeight`, `MaxCameraHeight`, via `tools/zh_ini.py`). **source**
- OpenRA: continuous zoom between `MinZoom` and `MaxZoom` (`OpenRA.Game/Graphics/Viewport.cs:92-105`), with the default preset picked by window height (`WorldViewportSizes.cs:17-24`). **source**
- 0 A.D.: continuous keys, stepped wheel, limits `zoom.min`/`zoom.max` (`default.cfg:272-275`, `:656-659`). **source**
- Beyond All Reason: not checked.
