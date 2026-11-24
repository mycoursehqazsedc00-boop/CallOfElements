# Call Of Elements (Patched for WoW 1.12 / Turtle WoW)

> All-in-one Shaman totem bar, timer, healing, and Totem Twisting addon for Vanilla WoW 1.12.x and Turtle WoW.

## Client Mods Used
| Mod | Purpose in this addon | Required? |
|---|---|---|
| Nampower | Accurate totem cast confirmation (`SPELL_GO_SELF`, `GetSpellNameAndRankForId`) and active-cast guard (`GetCastInfo`) for Totem Twisting | Optional |
| SuperWoW | Real-time totem cast tracking (`UNIT_CASTEVENT`, `SpellInfo`) for Totem Twisting | Optional |
| UnitXP SP3 | Optional OS taskbar notification (`UnitXP("notify", "taskbarIcon")`) when Windfury Totem is about to expire during manual twisting | Optional |

*(The addon runs in strict Lua 5.0 and works without any optional DLLs; when optional mods are absent, it falls back to stock `SPELLCAST_STOP` / `ActivatePendingTotem` tracking.)*

## Features
- **Totem Bars & Dynamic Sets:** Configurable Earth, Fire, Water, and Air bars with Anchor/Flex/Timers-Only modes, totem ordering, PvP class auto-switching, and custom totem sets.
- **Totem Timers & Destruction Alerts:** Tracks remaining duration, cooldowns, and incoming damage to totems.
- **Totem Advisor:** Scans party members and pets for Poison, Disease, and Fear/Sleep/Charm debuffs and highlights the cleansing totem to drop.
- **Smart Healing (`BestHeal` / `BattleHeal`):** Selects the lowest-health party/raid/friendly target and chooses a mana-efficient rank of Healing Wave or Lesser Healing Wave.
- **Totem Twisting Module (`COE_Twist`):** Built-in Windfury ↔ Grace of Air / Tranquil Air rotation manager with Menu UI and Minimap Button.

## Totem Twisting
Totem Twisting lets you maintain the Windfury weapon buff (`~9–10s` linger duration) while keeping **Grace of Air Totem** (or **Tranquil Air Totem**) active for the rest of the window.

### Modes & Controls
1. **Auto Totem Twisting:**
   - Enable **Auto Totem Twisting** in the Twist Menu (or `/coe autotwist`).
   - Automatically drops **Windfury Totem**, immediately twists to your chosen **Secondary Air Totem**, and refreshes **Windfury Totem** once the configured `WF Refresh` timer (`7.0s–10.0s`, default `9.0s`) elapses.
   - Includes an **Auto Twist in Combat Only** toggle (enabled by default) so totems are not dropped automatically out of combat.
2. **Manual Twist Alerts:**
   - Enable **Manual Twist Alerts** (or `/coe twistalert`) if you prefer twisting manually.
   - Notifies you on-screen right after dropping **Windfury Totem** (`Twist -> Grace of Air Totem!`) and alerts you with a sound + visual warning (`Recast Windfury Totem!`) when `<= 1.5s` remain before refresh.
3. **One-Button / Macro Twist (`/coe twist`):**
   - Click the **Twist Now** button in the Twist Menu, press **Shift + Left-Click** on the Minimap Button, use `/coe twist`, or bind `Twist Totem (Windfury / Air)` in Key Bindings.
   - Automatically casts the next totem in the current rotation (**Windfury Totem** → **Secondary Air Totem** → **Windfury Totem**).

### Menu UI & Minimap Button
- **Minimap Button (`COEMinimapButton`):**
  - **Left-Click:** Toggle the **Totem Twisting** menu (`COE_TwistFrame`).
  - **Right-Click:** Toggle the main **Call Of Elements** configuration dialog.
  - **Shift + Left-Click:** Execute `Twist Now` immediately.
  - **Drag:** Reposition the button around the minimap.
- **Twist Menu (`COE_TwistFrame`):**
  - Live icon preview of the next totem in rotation and a real-time Windfury duration status bar.
  - Quick toggles for **Auto Totem Twisting**, **Auto Twist in Combat Only**, and **Manual Twist Alerts**.
  - **Secondary Totem** switcher (`Grace of Air Totem` / `Tranquil Air Totem`) and `WF Refresh` slider (`7.0s–10.0s`).

## What Was Added / Improved
- **Added (`COE_Twist.lua` / `COE_Twist.xml`):**
  - Totem Twisting engine with Auto Twist, Manual Twist Alerts, `/coe twist` rotation button/slash command, and `COETWISTNOW` / `COETWISTMENU` keybindings.
  - Draggable `COE_TwistFrame` menu UI and movable `COEMinimapButton` with persistent `COE_Saved.Twist` settings.
  - Optional `Nampower`, `SuperWoW`, and `UnitXP SP3` integration with strict Lua 5.0 fallbacks.
- **Fixed:**
  - **FPS / `OnUpdate` throttling:** Fixed `COE_Totem:UpdateFrame()` resetting `COETotemFrame.UpdateTime` instead of `this.UpdateTime`, and added missing `this.UpdateTime = 0` in `COE_Totem:UpdateTimerFrame()`.
  - **Cast hook compatibility:** Preserved the second argument (`onSelf` / unit) in the `CastSpellByName` hook so self-cast macros and client-mod targeted casts work properly.
  - **Cross-faction & Healing safety:** Added `"PALADIN"` and unknown-class/boss-level fallbacks in `COE_Heal`, guarded `maxHealth == 0`, dead/offline/invisible units, empty spell tables, and avoided duplicate party+raid scans in raids.
  - **Advisor & Tooltip parsing:** Fixed `COESTR_TREMOR` debuff check being skipped when `debuffType` is `nil` (physical/untyped fears); fixed decimal minute duration parsing (`tonumber(minutetext) * 60`); removed per-hit table allocations in `TotemDamage` and `GetTotemDurationAndHealth`.
  - **Crash & leak fixes:** Fixed `ReorderNewTotems()` infinite recursion risk, `SwitchToPriorSet()` crash when no custom sets exist, `this.IsMoving` casing typo, global `text`/`icon` leaks, and `nil` guards across `COE_TotemData.lua`, `COE_TotemLogic.lua`, and `COE_TotemVisual.lua`.

## Usage
- `/coe` or `/coe config` — Open main configuration dialog.
- `/coe twist` — Cast Windfury or Secondary Air Totem based on current rotation.
- `/coe twistmenu` — Toggle the Totem Twisting menu UI.
- `/coe autotwist` — Toggle Auto Totem Twisting.
- `/coe twistalert` — Toggle Manual Twist Alerts.
- `/coe list` — Print all available `/coe` commands.

## Credits & License
- Original addon: **Wyverex** (2006) — Call Of Elements v2.7
- Bug fixes, Totem Twisting module, Menu UI & Minimap Button: Community fork patch
- License: Same as original addon.
