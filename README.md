# Cortex ATM Robbery

[![Cortex ATM Robbery](https://raw.githubusercontent.com/IEver3st/gsd-tebex-media/main/heroes/atmrobbery.jpg)](https://gsdmods.com/scripts/cortex-atm-robbery?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery)

**[Download Latest Release (v1.0.0)](https://github.com/IEver3st/cortex-atmrobbery/releases/latest)** · [Product Page](https://gsdmods.com/scripts/cortex-atm-robbery?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [All 36 Cortex Scripts](https://gsdmods.com/scripts?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [Docs](https://gsdmods.com/docs?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [Discord](https://discord.com/invite/gsdmods)

> **Free direct download — no Tebex checkout or Asset Escrow required.** Download the ready-to-drop `cortex-atmrobbery-1.0.0.zip` from [GitHub Releases](https://github.com/IEver3st/cortex-atmrobbery/releases/latest) and extract `cortex-atmrobbery` into your FiveM `resources/` folder.

Rob a Cortex Banking ATM with your own hands. Pry the service door off with a crowbar, back the screws out of the cover plate, read the wiring with a multimeter, bridge and cut the right wires, then pull the cash cassette and take the bundles out one by one. Every step happens on the machine itself, close up, with the mouse. Every machine is wired differently, and the server decides what each wire does.

Free addon for [Cortex Banking](https://gsdmods.com/scripts).

## What a robbery looks like

1. **Service door.** Hold a crowbar, face the machine and press **G**. Set the bar in a seam, pull down and hold it in the band until the seam gives. Pull too hard and the bar slips. Three seams and the door comes off.
2. **Cover plate.** Seat the driver on a screw and circle counter-clockwise. Turn too fast and the driver cams out. Four screws and the plate drops.
3. **Wiring.** Six coloured wires and a terminal strip. Probe each wire with the meter (**1**) to read it, cut with the cutters (**2**), and bridge two terminals with a jumper lead (**3**). Readings go in your notes (**Tab**). The aim is to fire the bolt solenoid without tripping the alarm loop, the dye pack or the mains.
4. **Cassette.** Pull the drawer out by its handle (**4** for your hand), then take the bundles one at a time from the top layer down.

Mistakes are strikes. After `Config.Strikes` the machine locks itself down and the alarm goes off. A dyed cassette still pays, at `Config.Reward.dyedShare` of the value.

Other players see the robbery: the door and plate on the floor, the open bay, sparks from a shorted board, dye smoke, the alarm. A robbed machine is out of service for Cortex Banking until it is repaired (`Config.Cooldown.repairMinutes`).

## Requirements

- OneSync.
- [`cortex-lib`](https://github.com/IEver3st/cortex-lib/releases/latest), started first.
- `cortex-banking` 1.1.0 or newer and `cortex-banking-assets` 1.1.0 or newer. The robbery works on Cortex ATMs, the service door and open bay are part of the 1.1.0 models, and Banking 1.1.0 takes a robbed machine out of service.
- `ox_inventory`, or a bridge resource named `ox_inventory` that answers its `GetItemCount`, `Items`, `CanCarryItem` and `AddItem` exports (Cortex Inventory ships one).
- Optional: `cortex-dispatch` for police alerts. Without it the alert goes to `police:server:policeAlert`.

## Install

1. Put `cortex-atmrobbery` in your resources and `ensure cortex-atmrobbery` after `cortex-lib`, `cortex-banking-assets`, `cortex-banking` and `ox_inventory`.
2. Add the kit to `ox_inventory/data/items.lua` (the same entry is in `install/ox_inventory_items.lua`) and copy `install/images/atm_toolkit.png` to `ox_inventory/web/images`:

   ```lua
   ['atm_toolkit'] = {
       label = 'ATM service kit',
       weight = 1200,
       stack = false,
       close = true,
       description = 'Driver, side cutters, a multimeter and jumper leads. For servicing ATMs, officially.',
   },
   ```

3. The crowbar is the game's `WEAPON_CROWBAR`, and the cash is paid as `black_money`. Both come with ox_inventory. Change either in `config.lua`.
4. On Cortex Inventory, add `'cortex-atmrobbery'` to the trusted resources list in `config/suite-trust.lua`, or it refuses the item checks and the payout.
5. Restart the server. Players need to reconnect once to load the new models.

Robbable ATMs are the game's own map ATMs, checked on the server against `server/placements.lua`. If your maps add ATMs, list each one in `Config.ExtraAtms` with its model, its exact position and its heading, as your map file or CodeWalker gives them. An entry without a heading is skipped with a warning in the server console, and an entry more than 25 cm off its ATM is refused:

```lua
Config.ExtraAtms = {
    { model = 'cortex_atm_02', coords = vec3(-56.12, -1752.30, 28.42), heading = 50.0 },
}
```

Machines and cooldowns live in memory. Restarting `cortex-atmrobbery` puts every machine back in service and clears every cooldown. Restarting one of its dependencies stops it, so start it again afterwards.

The robbery needs Cortex Banking's own ATM models, so leave `Config.Atm.CortexModels` on in Cortex Banking. The bands on the cash bundles print $2,000; if you change `Config.Reward.perBundle`, the hover label shows the real value.

## Configuration

Everything is in `config.lua`.

| Setting | What it does |
| --- | --- |
| `Config.Keys.start` | Default key to start or keep working a machine. Players can rebind it under Settings, Key Bindings, FiveM. |
| `Config.Tools` | The crowbar and kit item names. Set `kit = false` to need only the crowbar. |
| `Config.ExtraAtms` | ATMs added by your maps, so they can be robbed too. |
| `Config.Police.required` | Officers on duty (`jobType`) before a machine can be opened. |
| `Config.Police.witnessChance` | Chance that prying a door sends a tampering alert before any alarm. |
| `Config.Police.send` | Where alerts go. Replace it to use your own dispatch. |
| `Config.Cooldown` | Minutes between robberies per player, until a robbed machine is repaired, and until an abandoned one resets. |
| `Config.Strikes` | Mistakes allowed before a machine locks down. |
| `Config.Pry`, `Config.Screws` | How tight the lever band is, how long to hold it, and how fast a screw may turn. |
| `Config.Wires.jumperLeads` | Leads in the kit. |
| `Config.Wires.shockDamage` | Health lost when you cut the mains. |
| `Config.Cassette` | Bundles per cassette (a range) and how long the alarm rings. |
| `Config.Reward` | Item paid, value per bundle and the share a dyed bundle keeps. |
| `Config.Camera` | Field of view and distance of the work camera. |

Players can turn the work light off in the Cortex settings tab (Activities, ATM Robbery).

### Logs

Set a Discord webhook for the audit log in `server.cfg`. It is a convar so it never reaches clients:

```
set cortex_atmrobbery_webhook "https://discord.com/api/webhooks/..."
```

## Admin

`/atmrob` needs the ACE `command.atmrob`.

- `/atmrob list` lists every machine being worked or waiting for repair.
- `/atmrob reset <id|all>` puts machines back in service.
- `/atmrob cooldown <server id>` clears a player's cooldown.

## For developers

Cortex Banking exports `SetMachineOutOfService(key, coords)`. Pass a unique key and the machine's coords to stop players using that ATM, and `nil` coords to put it back. Any player at that machine is sent away from its screen.

The server owns every outcome. A client only asks for an action (pry a seam, turn a screw, cut a wire, bridge two terminals, pull, take a bundle) and the server checks range, the tool in the inventory, the stage, the minimum time for each step and a rate limit before it answers. The wire roles never leave the server.

## Support

[gsdmods.com](https://gsdmods.com)

## More from Cortex

Cortex ATM Robbery is free and stays free. All 36 Cortex scripts share one free library ([`cortex-lib`](https://github.com/IEver3st/cortex-lib)) and one consistent UI, with native cross-script integrations and zero conflicts.

### Flagship Paid Suites & Scripts

| Police & Tactical | Economy & World | Core UI & Vehicles |
| --- | --- | --- |
| [**Cortex MDT**](https://gsdmods.com/scripts/cortex-mdt?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Full police MDT + Dispatch included free | [**Cortex Banking**](https://gsdmods.com/scripts/cortex-banking?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): 4 banks, rebuilt 3D ATMs, cards, credit scores & loans | [**Cortex HUD**](https://gsdmods.com/scripts/cortex-hud?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): HUD Studio with three built-in layouts |
| [**Cortex PolCam**](https://gsdmods.com/scripts/cortex-polcam?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): FLIR helicopter camera with tracking & ground link | [**Cortex Vending**](https://gsdmods.com/scripts/cortex-vending?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Player-owned vending machines with 105 3D products | [**Cortex Handling**](https://gsdmods.com/scripts/cortex-handling?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Live in-game vehicle handling editor & exporter |
| [**Cortex Dispatch**](https://gsdmods.com/scripts/cortex-dispatch?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Live alerts, unit routing & panic calls | [**Cortex Caseboard**](https://gsdmods.com/scripts/cortex-caseboard?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Detective corkboards with red strings & 18 card types | [**Cortex Multicharacter**](https://gsdmods.com/scripts/cortex-multicharacter?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Character roster, dossier & ID registration |
| [**Cortex Radar**](https://gsdmods.com/scripts/cortex-radar?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Handheld 3D police radar gun | [**Cortex Whiteboard**](https://gsdmods.com/scripts/cortex-whiteboard?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): 28 drawable boards with city maps & physics | [**Cortex Rewind**](https://gsdmods.com/scripts/cortex-rewind?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): Forza-style vehicle rewind in FiveM |
| [**Cortex Arges**](https://gsdmods.com/scripts/cortex-arges?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [**Radio**](https://gsdmods.com/scripts/cortex-radio?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [**SceneKit**](https://gsdmods.com/scripts/cortex-scenekit?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) | [**Cortex Computer**](https://gsdmods.com/scripts/cortex-computer?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery): In-world playable computers & monitors | [**Cortex Chat**](https://gsdmods.com/scripts/cortex-chat?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [**Spawn**](https://gsdmods.com/scripts/cortex-spawn?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) · [**Emote Studio**](https://gsdmods.com/scripts/cortex-emote-studio?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) |

### Save with Bundles (One-Time or All-Access)

- [**Cortex Complete**](https://gsdmods.com/scripts/cortex-complete?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) — One-time lifetime bundle, no subscription.
- [**Cortex LEO Kit**](https://gsdmods.com/scripts/cortex-leo-kit?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) — Complete unified police stack (`MDT`, `Dispatch`, `PolCam`, `Radar`, `ALPR`, `Arges`, `Radio`, `SceneKit`, `Caseboard`, `Whiteboard`, `Flashlight`, `Binoculars`).
- [**Cortex Interface Kit**](https://gsdmods.com/scripts/cortex-interface-kit?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) — Complete core UI stack (`HUD`, `Chat`, `Spawn`, `Multicharacter`, `Loading Screen`).
- [**Cortex All-Access**](https://gsdmods.com/scripts/cortex-all-access?utm_source=github&utm_medium=readme&utm_campaign=cortex-atm-robbery) — Every current paid script + every future release on day one.

### All Free Cortex Scripts on GitHub

[`cortex-pause`](https://github.com/IEver3st/cortex-pause) · [`cortex-alpr`](https://github.com/IEver3st/cortex-alpr) · [`cortex-newspaper`](https://github.com/IEver3st/cortex-newspaper) · [`cortex-gunsmith`](https://github.com/IEver3st/cortex-gunsmith) · [`cortex-echo`](https://github.com/IEver3st/cortex-echo) · [`cortex-drone`](https://github.com/IEver3st/cortex-drone) · [`cortex-droneraces`](https://github.com/IEver3st/cortex-droneraces) · [`cortex-thrusters`](https://github.com/IEver3st/cortex-thrusters) · [`cortex-megaphone`](https://github.com/IEver3st/cortex-megaphone) · [`cortex-minigames`](https://github.com/IEver3st/cortex-minigames) · [`cortex-admin`](https://github.com/IEver3st/cortex-admin-releases) · [`cortex-atmrobbery`](https://github.com/IEver3st/cortex-atmrobbery) · [`cortex-vendrobbery`](https://github.com/IEver3st/cortex-vendrobbery) · [`cortex-lib`](https://github.com/IEver3st/cortex-lib)
