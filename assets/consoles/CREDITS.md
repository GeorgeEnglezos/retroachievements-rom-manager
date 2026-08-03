# Console logo credits

The console logos in this folder (`<consoleId>.png`) are full-color brand
logos sourced from **Wikimedia Commons** (freely reusable media). See
`SOURCES.txt` for the exact file and URL used for each console id.

- Style: full-color logos on transparency. In `lib/widgets/folder_card.dart`
  each card uses one fixed light background in both themes, and the logo is
  drawn in its own colors on it. Three light-colored logos are tinted to ink so
  they stay legible: Atari Lynx (13, yellow), Wii (19, grey), and Arcade (27).
  That set is `ConsoleImage.tintedLogos` in `lib/services/console_image.dart`.
- Terms: these are brand logos and trademarks of their respective owners, used
  here for identification of each system only.

Exceptions:

- **Arcade (27)** keeps the earlier white monochrome joystick icon from the
  **Monochrome Gaming Logos** collection by **HVR88**
  (https://github.com/HVR88/Monochrome-Gaming-Logos); there is no single brand
  logo for "arcade". Tinted to ink on the light card.
- Pokémon mini (24) has no usable dedicated wordmark, so it uses the franchise
  Pokémon logo as a stand-in.
- Systems still without a logo fall back to the default folder icon. Nintendo
  Switch is not a RetroAchievements console, so it has no id and no card.
