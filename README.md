SADDAM BATTLE

FINAL MASTER DEVELOPMENT SPECIFICATION

Ultra 3D Military Action Game – Android – Offline – Local Multiplayer

1. PROJECT OBJECTIVE

Build a complete, professional, playable 3D military action and shooting game for Android named SADDAM BATTLE.

The game must include:

- A complete single-player campaign.
- Offline gameplay without internet.
- Local multiplayer for up to 5 players using Wi-Fi or a mobile hotspot.
- Military weapons, vehicles, motorcycles and helicopters.
- Multiple maps, missions, enemy AI and combat systems.
- High-quality 3D graphics with scalable performance settings.
- A complete Android APK build pipeline using GitHub Actions.

This must be a real playable game, not a prototype made of placeholder screens or nonfunctional buttons.

2. PROJECT TECHNOLOGY

Use:

- Godot Engine 4 stable release.
- GDScript.
- Godot 3D rendering.
- Android export using ARM64 support.
- APK output.
- GitHub Actions for automated validation and APK building.

Pin exact compatible versions of Godot, export templates, Java, Android SDK and required build tools.

Do not mix incompatible versions.

3. OFFLINE REQUIREMENT

The entire game must work without an internet connection.

Requirements:

- No mandatory login.
- No external game servers.
- No online account.
- No remote asset downloads.
- No online dependency for single-player.
- Save progress locally.
- Local multiplayer must work without internet through Wi-Fi or mobile hotspot.

Do not introduce online multiplayer in this version.

4. GRAPHICS AND QUALITY SETTINGS

Create a detailed 3D military environment with:

- Realistic lighting and shadows.
- High-quality materials and textures.
- Detailed characters and weapons.
- Realistic environmental effects.
- Sand, dust, smoke, fire and explosions.
- Day and night environments.
- Weather effects where performance permits.

Provide three graphics presets:

1. ULTRA:
   
   - High-resolution textures.
   - Advanced shadows.
   - High-quality lighting.
   - Detailed effects.
   - Maximum supported rendering quality.

2. HIGH:
   
   - Balanced textures and lighting.
   - Medium-to-high shadows.
   - Optimized effects.

3. PERFORMANCE:
   
   - Reduced shadows.
   - Lower rendering resolution when necessary.
   - Optimized textures and effects.
   - Reduced GPU and memory usage.

Automatically recommend settings according to device capabilities.

Do not promise identical Ultra performance on every Android phone. Use real licensed or original 3D assets and optimize them for mobile devices.

5. LANGUAGE SUPPORT

Support:

- Arabic with correct RTL layout.
- English with LTR layout.
- Language switching from settings.
- All menus, subtitles and gameplay instructions translated.

6. PLAYER CHARACTER

Create a fully animated third-person military soldier.

Required animations:

- Idle.
- Walking.
- Running.
- Sprinting.
- Jumping.
- Crouching.
- Aiming.
- Shooting.
- Reloading.
- Weapon switching.
- Grenade throwing.
- Healing.
- Taking damage.
- Death.
- Entering and exiting vehicles.

Include:

- Military uniforms.
- Helmets.
- Tactical equipment.
- Character shadows.
- Realistic movement and collision.

7. THIRD-PERSON CAMERA

Implement:

- Third-person follow camera.
- Touch-based camera rotation.
- Camera zoom.
- Aim mode.
- Scope view.
- Smooth camera transitions.
- Collision detection to prevent camera clipping through walls.
- Different camera modes for vehicles.

8. ANDROID TOUCH CONTROLS

Create a complete mobile control interface.

Required controls:

- Left movement joystick.
- Camera rotation area.
- Fire button.
- Aim button.
- Jump button.
- Sprint button.
- Crouch button.
- Reload button.
- Weapon switching.
- Grenade button.
- Healing button.
- Interaction button.

Allow users to:

- Change button positions.
- Resize buttons.
- Adjust transparency.
- Adjust sensitivity.
- Save custom control layouts.

Controls must adapt automatically when entering a vehicle or helicopter.

9. WEAPON SYSTEM

Implement functional weapons:

- Assault rifles.
- Light machine guns.
- Heavy machine guns.
- Sniper rifles.
- Pistols.
- Shotguns.
- Rocket launchers.
- Grenades.
- Combat knives.

Each weapon must have:

- Damage.
- Range.
- Accuracy.
- Recoil.
- Fire rate.
- Magazine capacity.
- Reserve ammunition.
- Reload duration.
- Shooting sound.
- Reload animation.
- Weapon-specific behavior.

Support scopes:

- 2x.
- 4x.
- 8x.

Add weapon pickup, weapon switching and ammunition management.

10. COMBAT AND DAMAGE SYSTEM

Implement:

- Player health.
- Armor.
- Healing.
- Damage calculations.
- Headshots.
- Body hits.
- Explosion damage.
- Bullet impacts.
- Hit indicators.
- Death and respawn rules where applicable.
- Checkpoints.
- Ammunition pickups.

All combat calculations must be functional and consistent.

11. ENEMY ARTIFICIAL INTELLIGENCE

Create enemies with these behavior states:

- Patrol.
- Suspicious.
- Alert.
- Investigate.
- Chase.
- Find cover.
- Aim.
- Attack.
- Reload.
- Flank.
- Retreat.
- Dead.

Enemies must:

- Detect players through vision and hearing.
- React to gunfire.
- Search for suspicious activity.
- Use cover.
- Coordinate attacks.
- Move between tactical positions.
- Request reinforcements when appropriate.
- Have different difficulty levels.

12. GAME MAPS

Create four main detailed maps:

Map 1: Desert Village

- Desert houses.
- Streets.
- Buildings.
- Military checkpoints.
- Enemy positions.

Map 2: Military Base

- Barracks.
- Guard towers.
- Warehouses.
- Vehicle parking.
- Military equipment.

Map 3: Mountain Battlefield

- Mountains.
- Narrow roads.
- Rocky terrain.
- Sniper positions.
- Military outposts.

Map 4: Abandoned Industrial Zone

- Factories.
- Warehouses.
- Industrial buildings.
- Metal structures.
- Abandoned vehicles.

Each map must support suitable single-player missions and local multiplayer matches.

13. SINGLE-PLAYER CAMPAIGN

Create a campaign containing 12 missions:

1. Military training.
2. Entering an enemy village.
3. Eliminating enemy forces.
4. Rescuing hostages.
5. Securing a military convoy.
6. Capturing a surveillance point.
7. Assaulting an enemy base.
8. Destroying an ammunition warehouse.
9. Sniper operation.
10. Mountain combat operation.
11. Abandoned factory operation.
12. Final confrontation with the enemy commander.

Each mission must have:

- Objectives.
- Start and completion conditions.
- Enemy placement.
- Rewards.
- Mission results.
- Save checkpoints.

14. VEHICLE AND TRANSPORT SYSTEM

Implement a complete vehicle system.

A. Cars and Military Vehicles

Include:

- Military 4x4 vehicles.
- Civilian cars.
- Military transport trucks.
- Reconnaissance vehicles.
- Armored vehicles.
- Military cargo trucks.
- Weapon-equipped vehicles.

Driving features:

- Steering.
- Acceleration.
- Braking.
- Reverse.
- Suspension.
- Wheel rotation.
- Collision.
- Vehicle damage.
- Engine sounds.
- Multiple camera views.

B. Motorcycles

Include:

- Military motorcycles.
- Civilian motorcycles.

Features:

- Acceleration.
- Braking.
- Steering.
- Leaning during turns.
- Wheel animation.
- Balance.
- Falling and collision.
- Engine sounds.
- Camera views.

C. Helicopters

Include:

- Military transport helicopters.
- Reconnaissance helicopters.
- Attack helicopters.

Flight features:

- Vertical takeoff.
- Vertical landing.
- Ascending and descending.
- Forward and backward movement.
- Sideways movement.
- Turning.
- Banking and tilting.
- Rotor animation.
- Engine and rotor sounds.
- Cockpit and external cameras.
- Flight indicators.
- Damage and safe landing behavior.

D. Entering and Exiting Vehicles

Implement:

- Interaction button near vehicles.
- Entering and exiting animations.
- Driver and passenger seats.
- Automatic control layout changes.
- Camera transitions.
- Vehicle occupancy management.
- Safe helicopter exit conditions.
- Handling overturned or damaged vehicles.

E. Vehicle Damage

Support:

- Body damage.
- Engine damage.
- Wheel damage.
- Smoke.
- Fire where appropriate.
- Vehicle breakdown.

F. Vehicle Missions

Include missions involving:

- Driving military convoys.
- Vehicle pursuits.
- Escape missions.
- Helicopter reconnaissance.
- Soldier rescue.
- Mountain transportation.

15. LOCAL MULTIPLAYER – WIFI AND HOTSPOT

This is a mandatory feature.

Support local multiplayer for 2 to 5 Android devices without internet.

Connection methods

- Same Wi-Fi network.
- Mobile hotspot created by one player's phone.
- Automatic local room discovery when supported.
- Manual IP connection.
- Private room code.

Host system

One player creates a room and becomes the Host.

Other players join the host's game.

The host manages:

- Room settings.
- Map selection.
- Game mode.
- Player readiness.
- Match start.
- Match results.

Multiplayer requirements

All players must appear in the same game world.

Synchronize:

- Player movement.
- Position and rotation.
- Animations.
- Shooting.
- Hit detection.
- Health.
- Armor.
- Ammunition.
- Weapon switching.
- Death and respawn.
- Vehicles.
- Match objectives.
- Scores.

Use a network architecture appropriate for mobile local networks, with authoritative host-side gameplay validation and interpolation/prediction where necessary.

Multiplayer modes

1. FREE FOR ALL:
   Every player competes individually.

2. TEAM DEATHMATCH:
   Two teams compete, including uneven teams such as 2 versus 3.

3. DOMINATION:
   Teams compete to capture and control locations.

Multiplayer features

- Player names.
- Team assignment.
- Kill count.
- Death count.
- Scoreboard.
- Match timer.
- Match results.
- Private rooms.
- Room password or code.
- Ready status.
- Player disconnect handling.
- Host migration when technically possible.
- Reconnection support when possible.

Multiplayer Vehicles

Allow players to:

- Drive cars together.
- Ride motorcycles.
- Pilot helicopters.
- Enter passenger seats.
- Transport teammates.
- Use supported vehicle weapons.

Multiplayer Chat

Provide optional local text chat.

Network Reliability

- Handle weak Wi-Fi.
- Handle hotspot disconnections.
- Detect disconnected players.
- Avoid duplicate player identities.
- Validate critical gameplay events on the host.
- Display clear connection status.
- Do not require internet access.

Do not claim host migration or reconnection works unless implemented and tested.

16. PROGRESSION SYSTEM

Implement:

- XP.
- Player levels.
- Mission rewards.
- Weapon unlocks.
- Weapon upgrades.
- Achievements.
- Mission replay.
- Local progress saving.

17. GAME INTERFACE

Create functional screens:

- Main menu.
- Continue campaign.
- New campaign.
- Mission selection.
- Multiplayer.
- Create room.
- Join room.
- Lobby.
- Map selection.
- Weapon selection.
- Settings.
- Graphics settings.
- Audio settings.
- Control customization.
- Pause menu.
- Game HUD.
- Mission results.
- Scoreboard.

Every visible button must have a working action.

18. AUDIO SYSTEM

Include:

- 3D weapon sounds.
- Reload sounds.
- Footsteps.
- Vehicle engines.
- Motorcycle engines.
- Helicopter rotor sounds.
- Explosions.
- Environmental ambience.
- Background music.
- UI sounds.

Provide independent volume controls.

19. LOCAL SAVE SYSTEM

Save locally:

- Campaign progress.
- Completed missions.
- Player level.
- XP.
- Unlocked weapons.
- Settings.
- Control layouts.
- Audio settings.
- Graphics settings.

Handle interrupted sessions and invalid save data safely.

20. ANDROID PERFORMANCE

Optimize for Android hardware.

Implement:

- Level of Detail.
- Occlusion culling.
- Texture compression.
- Efficient lighting.
- Efficient shadows.
- Object pooling.
- Memory management.
- Optimized physics.
- Optimized AI.
- Network bandwidth management.

Provide adjustable frame-rate targets, including 30 FPS and 60 FPS where supported.

Do not promise performance without device testing.

21. SECURITY AND PRIVACY

- No unnecessary Android permissions.
- No hardcoded passwords or API keys.
- No external accounts.
- No internet dependency.
- Local multiplayer must not expose unrelated personal data.
- Validate network messages.
- Prevent basic cheating through host-authoritative validation.

22. PROJECT STRUCTURE

Use a clean, maintainable structure similar to:

Saddam-Battle/
├── .github/
│   └── workflows/
│       ├── android-build.yml
│       └── project-validation.yml
├── project.godot
├── export_presets.cfg
├── README.md
├── LICENSE
├── assets/
│   ├── characters/
│   ├── weapons/
│   ├── vehicles/
│   ├── environments/
│   ├── textures/
│   ├── animations/
│   ├── audio/
│   ├── effects/
│   └── ui/
├── scenes/
│   ├── main/
│   ├── player/
│   ├── enemies/
│   ├── weapons/
│   ├── vehicles/
│   ├── helicopters/
│   ├── maps/
│   ├── missions/
│   ├── multiplayer/
│   └── interface/
├── scripts/
│   ├── player/
│   ├── combat/
│   ├── ai/
│   ├── weapons/
│   ├── vehicles/
│   ├── helicopters/
│   ├── missions/
│   ├── multiplayer/
│   ├── progression/
│   ├── save/
│   ├── audio/
│   └── settings/
├── data/
│   ├── weapons/
│   ├── vehicles/
│   ├── missions/
│   └── enemies/
└── tests/
├── project-check/
├── gameplay/
├── multiplayer/
└── android/

Adjust the structure when technically necessary, but keep the project organized.

23. GITHUB REPOSITORY

Create a separate repository:

Repository name: Saddam-Battle

Do not mix files with Saddam-Player or any other project.

Include:

- Complete source code.
- Project configuration.
- Asset licenses and attribution.
- README.
- Build workflows.
- Test workflows.
- Build instructions.
- APK artifact instructions.

Do not upload copyrighted assets without permission.

24. AUTOMATED ANDROID BUILD

Create reliable GitHub Actions workflows.

The Android workflow must:

1. Check out the repository.
2. Install the pinned Godot version.
3. Install the matching export templates.
4. Configure Java and Android SDK.
5. Import project assets.
6. Validate the project.
7. Run available automated tests.
8. Export the Android APK.
9. Verify that the APK exists and is not empty.
10. Verify the APK package and architecture where possible.
11. Upload the APK as a GitHub Actions artifact.
12. Provide useful failure logs.

Use the correct Godot Android export configuration.

Do not invent export commands or incompatible tool versions.

Do not expose signing credentials in repository files.

25. TESTING AND ACCEPTANCE CRITERIA

Do not declare the project complete until the following have been tested.

Single-player tests

- Game launches.
- Main menu works.
- Character movement works.
- Camera works.
- Weapons fire.
- Reload works.
- Weapon switching works.
- Enemy AI works.
- Missions can be completed.
- Save and restore work.
- Game works in airplane mode.

Vehicle tests

- Enter and exit cars.
- Drive and reverse.
- Steering and braking.
- Motorcycle balance and movement.
- Helicopter takeoff.
- Helicopter flight.
- Helicopter landing.
- Passenger seating.
- Vehicle damage.
- Vehicle camera switching.

Multiplayer tests

Test using five actual Android devices when available:

- Host creates room.
- Four players join.
- All five appear in the same map.
- Movement synchronization.
- Shooting synchronization.
- Damage synchronization.
- Player elimination.
- Team assignment.
- Scoreboard.
- Vehicle sharing.
- Motorcycle use.
- Helicopter use.
- Hotspot connection.
- Wi-Fi connection.
- Disconnect handling.
- No internet access during the match.

Android build tests

- APK exports successfully.
- APK installs.
- APK launches.
- ARM64 support.
- Touch controls work.
- Audio works.
- Game survives background and resume where supported.

If physical devices are unavailable, clearly label device tests as not performed. Never claim they passed.

26. STRICT DEVELOPMENT RULES

- No empty source files.
- No fake gameplay.
- No decorative buttons without functionality.
- No placeholder implementation presented as complete.
- No broken scene references.
- No missing assets.
- No invalid APIs.
- No incompatible dependencies.
- No removal of requested features during bug fixes.
- No claiming tests passed without executing them.
- No claiming Ultra graphics are complete when required assets are missing.
- No APK delivery claims unless an APK was actually built and verified.
- Do not replace requested features with mockups.

Use original or properly licensed assets.

27. DEVELOPMENT PHASES

Build in controlled, testable stages:

1. Project foundation and Android export.
2. Player movement and camera.
3. Weapons and combat.
4. Enemy AI.
5. Maps and missions.
6. Cars and motorcycles.
7. Helicopters.
8. Local Wi-Fi multiplayer.
9. Multiplayer vehicles.
10. UI, audio and local saves.
11. Performance optimization.
12. Automated testing and APK release.

Each stage must be validated before proceeding.

Do not mark unfinished stages as completed.

28. FINAL DELIVERABLES

Deliver:

1. Complete Saddam-Battle GitHub repository.
2. All source files with correct paths.
3. Functional Godot project.
4. Original or properly licensed game assets.
5. Complete single-player campaign.
6. Working local multiplayer for up to five players.
7. Cars, motorcycles and helicopters.
8. Android APK.
9. GitHub Actions build workflow.
10. Test reports.
11. Known issues report.
12. Installation instructions.
13. Build instructions.

FINAL PRIORITY

The priority is a real, stable and playable Android game.

Single-player must work entirely offline.

Local multiplayer must work between up to five Android devices through Wi-Fi or mobile hotspot without internet or external servers.

All requested features must be implemented, integrated and tested before being declared complete.
