# MaUI

A compact, modern Roblox UI library for script executors (`gethui`, `writefile`, `loadstring`).
Sakura plum/pink theme by default, a full design-system token set, and zero asset dependencies.

## Features

- **Shell**: window with sidebar (branding, nav items, badges, separators, session card), header with page icon, search, actions, fullscreen, collapse; responsive compact sidebar
- **Cards**: Standard / Compact / Large / Statistic / Settings / Action / Info, accordions, columns, horizontal sub-tabs
- **Controls**: Toggle, Slider, Button (styles, loading, confirm), searchable Dropdown, TextBox (validation, numeric), ColorPicker, Keybind, Keycap, Label, Metric, DataRow
- **Systems**: toasts (Success/Info/Warning/Error/Loading), global tooltips, popup layer, theme presets and live theme editor, config manager (save/load/rename/delete/reset/autoload/import/export)
- **Extras**: floating overlay window, Dynamic Island, Home tab with user profile and changelog, key system
- **Accessibility and performance**: states never rely on color alone, animations Full/Reduced/Off, no per-frame loops, popups built on open and freed on close

## Quick start

```lua
local MaUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/MaUI/main/dist/MaUI.lua"))()
local ui = MaUI.new({ ConfigFolder = "MyHub" })
local window = ui:CreateWindow({ Title = "My Hub", Version = "v1.0" })
local tab = window:AddTab({ Name = "Main", Icon = "home" })
local card = tab:AddCard({ Name = "Player" })
card:AddToggle({ Name = "Enabled", Flag = "enabled", Callback = print })
card:AddSlider({ Name = "Speed", Min = 0, Max = 100, Default = 16, Flag = "speed" })
```

See [`Example.lua`](Example.lua) for the full tour.

## Icons

Icons are resolved by name to text glyphs (no asset upload needed). Register your own with
`MaUI.Icons.Register("name", "rbxassetid://123")`.

## Key system: important limitation

The key system runs **on the client**. It is a convenience gate, not real protection: anyone who can run the
script can bypass it. For real enforcement pass a `Validate(key)` callback that queries your own server and
keeps the protected logic server-side.

## Development

```
python3 build.py          # bundle src/ -> dist/MaUI.lua
python3 tests/run.py      # run all specs (source + bundle) in a headless Roblox mock
python3 tools/report.py   # refresh the analytics below
```

## Test results and analytics

<!-- ANALYTICS:START -->
| Metric | Value |
|---|---|
| Checks (source modules) | **627 passed**, 0 failed |
| Checks (bundled `dist/MaUI.lua`) | **543 passed**, 0 failed |
| Test sections | 61 |
| Line coverage | **83.3%** (5956/7147 executable lines) |
| Modules | 44 |
| Bundle size | 323.1 KB |

### Benchmarks (headless Roblox mock, not real client numbers)

| Benchmark | Result |
|---|---|
| `add_40_tabs_ms` | 1.7 ms |
| `build_100_elements_ms` | 17.9 ms |
| `dropdown_200_items_open_instances` | 1009 instances |
| `instances_per_slider` | 17 instances |
| `instances_per_toggle` | 9 instances |

### Coverage by module

| Module | Covered | Lines |
|---|---|---|
| `Components/Branding` | 92.7% | 55 |
| `Components/Button` | 85.4% | 199 |
| `Components/Changelog` | 74.3% | 109 |
| `Components/ColorPicker` | 94.8% | 192 |
| `Components/Columns` | 92.9% | 70 |
| `Components/ConfigManager` | 69.0% | 126 |
| `Components/Container` | 97.2% | 72 |
| `Components/ControlKit` | 95.7% | 47 |
| `Components/DataRow` | 77.4% | 124 |
| `Components/Dropdown` | 91.7% | 266 |
| `Components/DynamicIsland` | 91.1% | 751 |
| `Components/KeyStatus` | 88.9% | 72 |
| `Components/KeySystem` | 77.4% | 327 |
| `Components/Keybind` | 73.0% | 137 |
| `Components/Keycap` | 88.6% | 35 |
| `Components/Label` | 73.1% | 52 |
| `Components/Metric` | 51.1% | 319 |
| `Components/Notifications` | 74.5% | 263 |
| `Components/Overlay` | 84.6% | 201 |
| `Components/OverlayWindow` | 92.2% | 370 |
| `Components/Paragraph` | 20.4% | 49 |
| `Components/Profile` | 67.5% | 117 |
| `Components/SearchBox` | 68.5% | 89 |
| `Components/Section` | 75.5% | 241 |
| `Components/SessionCard` | 83.7% | 98 |
| `Components/Slider` | 91.9% | 185 |
| `Components/SubTabs` | 82.1% | 117 |
| `Components/Tab` | 88.3% | 163 |
| `Components/TextBox` | 92.6% | 189 |
| `Components/ThemeEditor` | 74.4% | 90 |
| `Components/Toggle` | 95.1% | 103 |
| `Components/Window` | 86.6% | 479 |
| `Core/Element` | 95.1% | 81 |
| `Core/Env` | 72.9% | 70 |
| `Core/Icons` | 74.1% | 54 |
| `Core/Input` | 96.3% | 109 |
| `Core/Kit` | 76.1% | 268 |
| `Core/Maid` | 93.8% | 32 |
| `Core/Signal` | 98.2% | 57 |
| `Core/Theme` | 92.2% | 153 |
| `Core/Tokens` | 100.0% | 15 |
| `Core/Tween` | 100.0% | 39 |
| `Core/Util` | 86.4% | 103 |
| `init` | 86.9% | 459 |
<!-- ANALYTICS:END -->

## License

MIT
