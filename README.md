# MaUI

Sakura plum/pink theme by default, a full design-system token set, and zero asset dependencies.

## Features

| Area | What you get |
|---|---|
| Shell | Window with sidebar (branding, nav items, badges, separators, session card), header with page icon, search, fullscreen, collapse and close; responsive compact sidebar; drag and resize with screen clamping |
| Pages | Cards (Standard, Compact, Large, Statistic, Settings, Action, Info), accordions, responsive columns, horizontal sub-tabs, header search that filters the current page |
| Controls | Toggle, Slider, Button (5 styles, loading, two-click confirm), searchable Dropdown, TextBox (validation, numeric), ColorPicker, Keybind, Keycap, Label, Paragraph, Metric (live mini charts), DataRow |
| Built-in Settings tab | Sidebar mode, animation mode, window size, UI scale, show/hide and collapse keybinds, theme editor, config manager. Added automatically (`Settings = false` to disable) |
| Themes | Sakura (default), Dark, Light, custom themes saved to disk, live token editing |
| Configs | Save, load, rename, delete, reset, autoload, import/export as a shareable string |
| Home tab | User profile (avatar, display name, username, user id), changelog, key time left |
| Key system | Key window with cooldown, saved key revalidation, expiring keys, `Wait()` |
| Dynamic Island | Draggable status pill that expands on hover; linked to a window it appears only while the window is hidden and reopens it on click |
| Overlay window | Optional floating panel the script author controls (logs, stats). Independent of the main window |
| Notifications | Success, Info, Warning, Error and Loading toasts with update and close handles |
| Quality | States never rely on color alone, animations Full/Reduced/Off, no per-frame UI loops, popups built on open and freed on close |

## Quick start

```lua
local MaUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/MaUI/main/dist/MaUI.lua"))()
local ui = MaUI.new({ ConfigFolder = "MyHub" })

local window = ui:CreateWindow({ Title = "My Hub", Version = "v1.0" })
window:AddHome({})

local tab = window:AddTab({ Name = "Main", Icon = "home" })
local card = tab:AddCard({ Name = "Player" })
card:AddToggle({ Name = "Enabled", Flag = "enabled", Callback = print })
card:AddSlider({ Name = "Speed", Min = 16, Max = 100, Default = 32, Flag = "speed" })

-- show a pill when the window is hidden; click it to come back
ui:CreateIsland({ Window = window, Text = "My Hub" })
```

[`Example.lua`](Example.lua) is a full script (movement, ESP, fullbright, live FPS and ping, server tools).

## Notes for script authors

- **Flags**: give an element a `Flag` and it is saved and restored by configs. Buttons, labels, metrics and other display-only elements are never saved.
- **Live stats**: `metric:Push(value)` adds a sample to the mini chart. Sample on a timer (for example every 0.25 s) instead of every frame.
- **Icons** are text glyphs by default (no asset upload). Register your own with `MaUI.Icons.Register("name", "rbxassetid://123")`.
- **Cleanup**: `ui:Destroy()` removes every window, island, overlay and popup. Add your own cleanup with `ui.Maid:Give(fn)`.

## Key system: important limitation

The key system runs **on the client**. It is a convenience gate, not real protection: anyone who can run the
script can bypass it. For real enforcement pass a `Validate(key)` callback that queries your own server and
keep the protected logic server-side.

## Development

```
python3 build.py          # bundle src/ -> dist/MaUI.lua
python3 tests/run.py      # run all specs (source + bundle) in a headless Roblox mock
python3 tools/report.py   # refresh the analytics below
```

The test mock rejects properties that do not exist on a class, like real Roblox. It still cannot reproduce
rendering, input sinking or executor differences, so test in a real client before releasing.

## Test results and analytics

<!-- ANALYTICS:START -->
| Metric | Value |
|---|---|
| Checks (source modules) | **633 passed**, 0 failed |
| Checks (bundled `dist/MaUI.lua`) | **549 passed**, 0 failed |
| Test sections | 62 |
| Line coverage | **83.3%** (6053/7265 executable lines) |
| Modules | 44 |
| Bundle size | 329.1 KB |

### Benchmarks (headless Roblox mock, not real client numbers)

| Benchmark | Result |
|---|---|
| `add_40_tabs_ms` | 4.1 ms |
| `build_100_elements_ms` | 10.9 ms |
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
| `Components/ControlKit` | 95.8% | 48 |
| `Components/DataRow` | 77.4% | 124 |
| `Components/Dropdown` | 91.7% | 266 |
| `Components/DynamicIsland` | 91.0% | 800 |
| `Components/KeyStatus` | 88.9% | 72 |
| `Components/KeySystem` | 77.4% | 327 |
| `Components/Keybind` | 73.7% | 137 |
| `Components/Keycap` | 88.6% | 35 |
| `Components/Label` | 73.1% | 52 |
| `Components/Metric` | 51.1% | 319 |
| `Components/Notifications` | 74.5% | 263 |
| `Components/Overlay` | 84.6% | 201 |
| `Components/OverlayWindow` | 92.2% | 373 |
| `Components/Paragraph` | 20.4% | 49 |
| `Components/Profile` | 67.5% | 117 |
| `Components/SearchBox` | 68.5% | 89 |
| `Components/Section` | 75.5% | 241 |
| `Components/SessionCard` | 88.8% | 98 |
| `Components/Slider` | 91.9% | 185 |
| `Components/SubTabs` | 82.1% | 117 |
| `Components/Tab` | 89.0% | 163 |
| `Components/TextBox` | 92.6% | 189 |
| `Components/ThemeEditor` | 74.4% | 90 |
| `Components/Toggle` | 95.1% | 103 |
| `Components/Window` | 83.9% | 541 |
| `Core/Element` | 95.1% | 81 |
| `Core/Env` | 72.9% | 70 |
| `Core/Icons` | 74.1% | 54 |
| `Core/Input` | 96.3% | 109 |
| `Core/Kit` | 76.2% | 269 |
| `Core/Maid` | 93.8% | 32 |
| `Core/Signal` | 98.2% | 57 |
| `Core/Theme` | 92.2% | 153 |
| `Core/Tokens` | 100.0% | 15 |
| `Core/Tween` | 100.0% | 39 |
| `Core/Util` | 86.4% | 103 |
| `init` | 87.0% | 461 |
<!-- ANALYTICS:END -->

## License

MIT
