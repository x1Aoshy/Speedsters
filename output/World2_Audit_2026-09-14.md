# World 2 technical audit

**14 September 2026 · Current local source and place files · Review only**

The speed complaint is supported by the current code. World 2 uses the same movement scale as World 1, and its flight speeds inherit that scale. The win-pad complaints have several concrete explanations: silent reward gates, a final-pad cooldown, and a purchase flow that does not resume when the upgrade arrives while the player is still standing on the pad. The statement that x2 pads have no developer-product connection is not supported by this version: the connection exists, but existing permanent wins ownership bypasses it.

There is enough evidence to justify targeted repairs. There is not enough evidence to justify replacing all network replication. This audit did not measure live frame times, network traffic, or the reported failure rate.

## 1. Answers to the player feedback

| Feedback | Finding | Confidence |
|---|---|---|
| “World 2 walk speed is the same as World 1.” | At equal stored speed and selector setting, the active World 2 movement multiplier is `1`, just like World 1. | Confirmed in source and math probes. |
| “World 2 used to be slower.” | A separate, older math helper still contains a `1/3` World 2 rule. The active adapter does not use that helper. The inspected older World 2 files also have Config set to `1`, so the exact historical change/date is unresolved. | Strong evidence of conflicting rules; historical deployment unverified. |
| “Parkour is harder and flight is easier.” | The current setting increases movement relative to the one-third rule. Flight directly scales from selected running speed. Actual course difficulty still needs route testing. | Mechanism confirmed; playability assessment pending. |
| “You don’t need to level up in World 2.” | Arriving with high stored speed already gives high movement speed. Progression still increases speed; whether it is economically worthwhile is a balance question requiring completion-time data. | Plausible balance consequence, not proof that leveling has no effect. |
| “Win pads work 50/50.” | Multiple deterministic rejection paths can look like missed contact. A three-minute final cooldown and Studio/live validation differences are confirmed. | Failure mechanisms confirmed; no measured 50% failure rate. |
| “x2 pads just give double wins; no dev product.” | New unowned players are prompted for product `3712435111`. Players already entitled through a pass or permanent multiplier skip the prompt. | Confirmed source flow; live product configuration unverified. |
| “The whole world is laggy and buggy.” | World 2 has more map parts and additional hazard workloads. Specific script consistency problems exist. The dominant lag bottleneck is still unknown. | Inventory confirmed; performance causes need profiling. |
| “Replace all network replication.” | Too broad for the evidence. Start with reward correctness, movement rules, and controlled profiling of individual systems. | Engineering recommendation based on this audit. |

## 2. What was inspected and what was actually tested

I inspected canonical `src` files, the source manifest, both `NewestStable` place files, the older World 2 place at the project root, and the World 2 input place referenced by the manifest. The comparison covered all 230 script containers in World 1 and all 277 in World 2. Every script in each newest place matched a manifest entry, and its source matched canonical source after newline normalization.

This matters because there is no local source-versus-newest-place mismatch to explain these findings. It does **not** establish which version is currently published to Roblox or running in an existing server.

The local checks used Lune to execute production math, production movement validation with mocked services, and production pad/claim modules with mocked characters and persistence. One new probe also executes the actual World 2 `connectRewardPad` function extracted from its source. These are behavioral code tests, not Roblox physics or Marketplace end-to-end tests.

| Local artifact | SHA-256 |
|---|---|
| World1NewestStable.rbxl | `2decf74bdc6b0473f89c2f15d2023cb18e80a111572c8dfeca058e953f2baca5` |
| World2NewestStable.rbxl | `5d4dd436e668c4375e5484de62b7a04eb97809bc907b75d3b94667fbc278039c` |

Evidence: [place inventory](<C:/Users/Aoshy´/Desktop/Update2/audit/world2_review_2026_09_14/place_inventory.json>), [inventory script](<C:/Users/Aoshy´/Desktop/Update2/audit/world2_inventory_review.luau>), [behavior results](<C:/Users/Aoshy´/Desktop/Update2/audit/world2_review_2026_09_14/behavior_probes.json>), [movement probes](<C:/Users/Aoshy´/Desktop/Update2/audit/world2_review_probes.luau>), [purchase/pad probes](<C:/Users/Aoshy´/Desktop/Update2/audit/world2_pad_prompt_probe.luau>), and [existing pad contract checks](<C:/Users/Aoshy´/Desktop/Update2/audit/test_pad_claim_contract.luau>).

No game source, place file, published experience, player data, or commerce setting was changed for this review.

## 3. Speed and progression

### Finding S1 — World 2’s active slowdown is absent

**Priority: P1 · Confirmed configuration/behavior mismatch with the requested design.**

`Config.World2WalkSpeedMultiplier = 1`. The active `CharacterStatsAdapter` reads that setting, passes it into `StatsService.CalculateWalkSpeed`, and publishes `RealWalkSpeedMax`, `RealWalkSpeedSelected`, and `WorldMovementSpeedScale`. `StatsProjection` calls the adapter when projecting the player’s profile.

Sources: [Config](<C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:16>), [movement factors](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau:23>), [adapter update](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau:38>), [projection](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/StatsProjection.luau:286>).

There is also a separate `CalculateMaxWalkSpeed(..., true)` helper with a hardcoded `1/3` factor. The active adapter calls `CalculateWalkSpeed` with factors instead. Changing only the older helper will not fix the current path. This is a maintenance problem: two public calculations can give different answers for “World 2 speed.” [Older helper and constant](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/StatsService.luau:93>), [active calculation](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/StatsService.luau:256>).

The current smooth curve is:

`8 + 292 × (log10(max(1, stored speed)) / log10(3.37 × 10^15))²`

The world scale and selector are then applied. The following values were obtained from the production math module. They assume the Red selector and exclude sprint, temporary effects, and acceleration behavior.

| Stored speed | World 1 now | World 2 now | World 2 with a candidate 1/3 scale |
|---:|---:|---:|---:|
| 1 | 8.00 | 8.00 | 2.67 |
| 1 million | 51.60 | 51.60 | 17.20 |
| 1 billion | 106.10 | 106.10 | 35.37 |
| 1 trillion | 182.40 | 182.40 | 60.80 |
| 3.37 quadrillion | 300.00 | 300.00 | 100.00 |
| 1 quintillion | 400.39 | 400.39 | 133.46 |

Units in the last three columns are studs per second. The smooth formula is not capped by `MaxWalkSpeed = 120`; the cap code belongs to the alternative linear formula branch. Merely changing that cap would not constrain this curve. [Smooth calculation and branches](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/StatsService.luau:162>).

**Recommended repair:** consolidate the world factor into one authoritative configuration path. Use `1/3` as the first balance candidate because the existing helper provides a concrete precedent. Validate it with actual World 2 entry profiles before treating it as the historical intended value. Decide whether very low profiles need a post-scale minimum: blindly multiplying the minimum of 8 by one third yields 2.67. Check Green, Yellow, Red, and Custom modes as well as Red.

This review cannot identify when the regression was introduced. Config in the inspected old/root and manifest-input World 2 places is also `1`; restoring an exact previous live behavior requires a known-good published version or dated source snapshot.

### Finding S2 — Flight inherits the same balance problem

**Priority: P1 · Confirmed coupling.**

World 2 flight reads `RealWalkSpeedSelected`. Its powered horizontal speed is `max(35, selectedSpeed × 0.3151)`. Its base glide forward speed is `max(45, selectedSpeed × 1.2519)`. Looking downward can increase glide forward speed further. Vertical movement has its own minimums and limits. [Flight calculation](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Movement/World2FlightAbility.client.luau:838>).

At the reference stored speed, current selected movement is 300. That produces powered horizontal movement of 94.53 and base glide of 375.57. With the one-third candidate, selected movement becomes 100, powered movement reaches its floor of 35, and base glide becomes 125.19.

That directly supports the reported “flight is easier when you are so fast.” However, lowering the running multiplier does not uniformly divide flight by three: the minimum speeds remain. At one billion stored speed, both current and candidate powered flight remain at 35. Any repair must test the flight floors, available altitude, stamina, and route length together.

Ground sprint also multiplies selected speed by 1.7 in the local movement controller, and an active confetti effect can add another multiplier. The raw-speed table is therefore not the highest speed a player can reach. [Ground movement modifiers](<C:/Users/Aoshy´/Desktop/Update2/src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau:892>).

**Recommended repair:** restore a coherent World 2 running curve first, then calibrate flight against it. Record completion times for entering players, mid-progression players, and highly progressed players. Keep leveling visibly beneficial while preserving meaningful obstacle timing. A network rewrite would not correct these formulas.

## 4. Win-pad reliability

### Finding W1 — Final wins have a hidden 180-second cooldown

**Priority: P1 · Behavior reproduced; whether to retain the policy is a design decision.**

`MovementGuard` rejects final claims made less than 180 seconds after the previous successful final claim. The cooldown is recorded after a durable reward commit. Resetting the character does not clear it. This is separate from the World 2 pad’s 1.5-second per-pad debounce.

Sources: [final cooldown](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:53>), [claim gate](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:194>), [World 2 debounce](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:342>).

The probe accepted a first final claim, rejected another at 179.9 seconds, accepted at 180 seconds, and confirmed that character reset does not erase the cooldown. The pad flow provides no specific client-facing explanation for this rejection. A player who completes another fast run can reach the correct pad and receive no reward, making a policy rejection look like broken contact detection.

**Recommended repair:** choose the intended repeat-win policy explicitly. If fast legitimate repeat runs should pay, revise this timer while retaining exactly-once run rewards and exploit checks. If the timer is required, display the remaining cooldown and distinguish it from an unavailable pad. Do not simply remove every guard.

### Finding W2 — Studio bypasses the validator that can reject live claims

**Priority: P1 · Reproduced testing blind spot.**

`MovementGuard.CanClaim` immediately returns `true` when `RunService:IsStudio()` is true. This bypasses its state, suspicious-movement, stage-progress, and final-cooldown checks. Other pad checks still run; the entire reward system is not bypassed. [Studio branch](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:195>).

The same mocked player rejected under live-mode validation passed when Studio mode was enabled. Consequently, repeated successful Studio pad tests do not demonstrate that these live rejection conditions are working correctly.

**Recommended repair:** provide a controlled test mode that runs the real validator in Studio, and include an unpublished/private test-place session using the live path before release. Keep any administrative bypass explicit and separate from default testing behavior.

### Finding W3 — Missing one sampled stage can produce a renewing block

**Priority: P1 · State-machine behavior reproduced; legitimate-player incidence unmeasured.**

The validator advances trusted progress one stage at a time. A nearest stage more than one ahead is treated as an anomaly and sets a 45-second block. Remaining near that skipped stage can keep triggering the same anomaly and extend the block. Waiting 45 seconds on the pad is therefore not necessarily enough.

The probe initialized progress at stage 1, presented stage 3 after the teleport grace period, and confirmed rejection without progress advancing. Presenting stage 3 again after 46 seconds renewed the block. This reproduces the logic; it does not prove that the sampled jump represented a legitimate route.

Sources: [sampling and stage progression](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:80>), [anomaly renewal](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:126>), [sampling interval](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/MovementGuard.luau:280>).

World 2 stage references come from its authored resolver. SafeZone1.2 corresponds to logical stage 2, through SafeZone9.2 corresponding to logical stage 10. The nearest-stage calculation uses horizontal distance plus a small vertical contribution. The guard accepts proximity within 170 studs. It samples current positions rather than sweeping the full trajectory through checkpoint regions. [World 2 delegation](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/StageTeleportService.luau:9>), [reference resolution](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2StageTeleportService.luau:202>), [distance calculation](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2StageTeleportService.luau:326>).

Flight paths, movement near the edges of checkpoint regions, or delayed samples need testing against this model. Faster movement increases the importance of those tests, but speed alone does not prove a legitimate stage will be missed.

**Recommended repair:** validate legitimate course progress using explicit checkpoint regions and bounded movement segments. Define how authorized flight, skips, revives, and teleports advance progress. Return a reason such as `MissingCheckpoint` or `SuspiciousMovement` to diagnostics and a useful message to the player. Preserve detection of unauthorized jumps.

### Finding W4 — Returning to spawn happens before the reward commit succeeds

**Priority: P1 · Failure behavior reproduced with a rejected persistence result.**

`RewardPadClaims` checks contact and eligibility, calls the return-to-start function, verifies the character left the pad, and then submits the durable reward transaction. A successful commit produces feedback. Pending commits and thrown errors retry with the same operation ID while the session remains valid. A rejected result clears the pending claim and warns, but does not restore the completed run or provide specific client feedback.

The injected rejection test confirmed that the character had already returned to start while wins remained unchanged. This is a possible explanation for “the pad teleported me but didn’t pay,” distinct from “the pad did nothing.” It is not evidence that live persistence routinely rejects claims. [Claim ordering and retry logic](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/RewardPadClaims.luau:18>).

**Recommended repair:** define a recoverable reward transaction with explicit pending, granted, and failed states. Preserve a validated completed-run entitlement across the return flow, and settle it idempotently. Handle disconnect/session-loss cases deliberately. Simply swapping the two calls can introduce a different bug—payment followed by a failed return—so the completion state needs a coherent design.

### Finding W5 — Contact detection is already more sophisticated than plain Touched

**Priority: P2 · Important constraint on any proposed fix.**

The shared pad service already uses a spatial grid and bounded segment sweeps. It excludes discontinuous movement from sweep claims, invalidates contact across teleport serial changes and respawns, and supports retries after callbacks reject. The existing contract checks passed for fast crossings, reward multiplication, proof invalidation, arrival grace, respawn boundaries, retries, competing pads, and cleanup.

The current trigger defaults to 14 studs high and adds four studs to the pad’s total X/Z dimensions. For a 7-by-7 pad, this makes an 11-by-11 footprint. That is intentionally more generous than the visible surface and can register an airborne player. The service chooses one candidate per sample, preferring the earliest intersection, then distance, then registration order. [Geometry](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/PadTouchService.luau:40>), [sweep and selection](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/PadTouchService.luau:127>).

Most authored World 2 normal/x2 pairs are approximately 12 studs apart. A sufficiently long movement segment can encounter both, and the earlier one wins. This deserves a visual Studio test from both approach directions. I have not established overlapping live trigger volumes as the cause of the reported failure rate.

Swept-contact evidence also expires after one second or more than one stud of subsequent root movement. An ownership lookup that yields before a crossing-only claim is checked could invalidate that proof. Ownership is usually cached, so this is a conditional race to test with an empty cache and delayed lookup, not a demonstrated common failure. [Contact evidence](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/PadTouchService.luau:55>), [ownership lookup before claim](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:484>).

**Recommended repair:** instrument contact and rejection reasons before replacing detection. Test trigger height and approach direction at supported running, sprinting, and flight speeds. Validate contact before any yielding ownership operation, and use a bounded pending interaction if the purchase/ownership result arrives later.

## 5. The x2 developer-product flow

### Finding C1 — Product wiring exists, but the ownership semantics differ from a paid claim

**Priority: P1 for clarifying intended behavior; current product connection confirmed.**

The current configuration names developer product `3712435111` and legacy game pass `1941409601`. The World 2 pad calls `PromptProductPurchase` for the developer product. The commerce service registers it as a permanent wins multiplier, generates a `PurchaseMultiplier` command, and processes the purchase through `ProcessReceipt` with a receipt-based operation ID.

Sources: [configured IDs and multiplier products](<C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:516>), [pad prompt](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:328>), [product registration](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:127>), [receipt commands](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:1528>), [durable receipt commit](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau:1553>).

The pad treats any of these as ownership: `DoubleWinsPadUnlocked`, permanent wins multiplier at least 2, or the legacy game pass. Saved profile projection also marks the pad unlocked when the permanent wins multiplier is at least 2. [Ownership gate](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:304>), [saved-profile projection](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/Stats/StatsProjection.luau:192>).

| Player state | Current x2-pad behavior |
|---|---|
| No entitlement, multiplier 1 | Prompts the developer product; that contact does not award wins. |
| Permanent multiplier 2 from an earlier purchase | No new prompt; normal reward is multiplied by 2. |
| Permanent multiplier 4, 8, 16, or 32 | No new prompt; the shared claim applies that multiplier. |
| Legacy x2 wins game-pass owner | Ownership path unlocks x2; no developer-product purchase needed. |
| Ownership lookup errors | Current condition takes the prompt path, rather than showing a distinct temporary verification failure. |

Both normal and x2 pads submit the same base reward into `RewardPadClaims`. The permanent multiplier is applied centrally once. At stage 2, the configured base is 50,000: a player with permanent x2 receives 100,000 from either reward pad; a player with permanent x4 receives 200,000. The x2 pad is not an additional multiplier on top of an already multiplied normal pad. [Reward selection](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:494>), [shared multiplier](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/RewardPadClaims.luau:37>), [stage rewards](<C:/Users/Aoshy´/Desktop/Update2/src/common/ReplicatedStorage/Shared/Config.luau:73>).

This explains why an existing customer or an account given a permanent multiplier can report “it never asks me to buy.” It does not explain a genuinely fresh, unowned account receiving paid behavior; that case needs its live attributes and published version checked.

**Recommended repair:** decide whether x2 means a permanent upgrade or a per-run purchase. The code currently implements the permanent-upgrade model. Preserve existing paid entitlements and make labels reflect the actual reward. If the intended product is a paid double reward for one run, it needs a different receipt/run-entitlement design rather than repeated prompts for this permanent upgrade.

Roblox documents developer products as repeatable purchases and requires server-side receipt handling for grants; application code must supply any permanent entitlement semantics. [Roblox developer-product documentation](https://create.roblox.com/docs/production/monetization/developer-products).

The current local IDs were traced, but their availability, current price, owning experience, and successful purchase behavior were not verified in Creator Dashboard or a live transaction. No purchase was made.

### Finding C2 — Buying while standing does not resume the pad claim

**Priority: P1 · Reproduced against the actual pad callback and shared service.**

When an unowned player enters, the callback opens the prompt and returns `true`. The shared service treats that interaction as handled and leaves the entry latched while the player remains inside. The ownership-change listener updates entitlement but does not request another pad interaction.

The probe prompted an unowned player, changed ownership to true, and advanced 120 samples while the player stood in place: no reward or return happened. Leaving and re-entering then granted the reward without another prompt. Cancellation can similarly leave the player standing on a pad that will not prompt again until re-entry.

Sources: [prompt branch](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:488>), [entry latch](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Services/PadTouchService.luau:171>), [ownership listener](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau:900>).

**Recommended repair:** store the pending pad interaction and resume it after a verified entitlement grant, while rechecking character/session, position or valid contact, run eligibility, and whether a reward already settled. Handle cancellation and verification failure explicitly. Do not grant from a client purchase-finished signal alone.

## 6. Performance and replication assessment

### The actual content difference

| Serialized inventory metric | World 1 | World 2 |
|---|---:|---:|
| BaseParts under Workspace | 4,655 | 8,034 |
| Script containers, including modules and inactive code | 230 | 277 |
| Enabled Script instances under Workspace | 8 | 22 |
| MeshParts, whole place | 205 | 111 |
| UnionOperations, whole place | 834 | 30 |
| ParticleEmitters, whole place | 293 | 275 |
| Beams, whole place | 128 | 136 |
| Sounds, whole place | 50 | 68 |
| Serialized RemoteEvents | 41 | 41 |
| Streaming enabled | Yes | Yes |
| Streaming minimum / target radius | 64 / 1,024 | 64 / 1,024 |

World 2 has 3,379 additional Workspace parts, approximately **72.6% more**. However, World 1 has substantially more unions and mesh parts, so raw part counts do not establish which world costs more to render or simulate. Whole-place asset counts include stored templates; they are not counts of simultaneously visible, playing, or active effects. Runtime-created instances and remotes are not represented in this serialized inventory.

The 22 enabled World 2 Workspace scripts are nine lava-contact scripts and thirteen conveyor setup scripts. They are not 22 perpetual update loops. The conveyor code sets velocity/beam behavior and removes its script. This rules out an easy but misleading conclusion based only on the script count.

### Profiling targets, in useful order

**P1 — Establish whether lag is client rendering, client script time, server simulation, loading, or networking.** Capture the same route, player count, graphics setting, and device class in both worlds. Measure frame-time spikes rather than just average FPS. Roblox’s diagnostics distinguish server health and client performance, and MicroProfiler network captures can separate streaming, property updates, and events. [Performance diagnostics](https://create.roblox.com/docs/performance-optimization/identify), [network capture documentation](https://create.roblox.com/docs/performance-optimization/microprofiler/network).

**P2 — Tree motion is a concrete replication candidate, but the local trees are small.** The server repeatedly writes each tree part’s CFrame and zeroes assembly velocities while tweening the swing. All six authored tree models together contain 12 BaseParts. The animation loop has no nearby-player condition. This is repeated server-driven scene motion worth measuring, but twelve parts alone are not evidence of a catastrophic bandwidth problem. [Tree motion](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2TreeSlammers.server.luau:317>).

If profiling shows a material cost or visible jitter, consider sending a shared swing phase/start time and rendering the swing locally, with a matching authoritative collision model. Preserve agreement between visible contact and accepted damage; a cosmetic rewrite without that agreement can make deaths feel worse.

**P2 — Tree contact checks scale with client frame rate and avatar parts.** Within 105 studs of a tree base, the client rebuilds the filtered tree-part list and runs `GetPartsInPart` for character parts on RenderStepped. Distant or locally protected players exit early. On an avatar with 16 checked parts at 60 FPS, the theoretical ceiling before early contact is roughly 960 queries per second while active; that is an illustrative workload calculation, not measured timing. [Tree contact checks](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau:266>).

Measure the active zone on mobile. A broad phase, stable cached filter, and bounded collision update rate could reduce work, but any lower frequency should preserve fast-contact detection through sweeps or equivalent coverage.

**P2 — Sonic has another per-frame contact path.** Within its area and 18 studs of the boss, the client performs body-part bounds queries on RenderStepped. Boss movement runs on the server Heartbeat, with target selection throttled separately, and the client also renders procedural joints. The distance/area gates already reduce cost. [Client contact](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2SonicEXEBoss.client.luau:361>), [server update](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau:588>).

**P2 — ASMR effects already have distance limits.** The effects client updates on a 0.05-second step, mounts within 160 studs, and unmounts beyond 220. Mounted cells perform local position checks and animate on state changes. Check runtime cell count and mount spikes before changing it; describing this as every effect running everywhere every frame would be incorrect. [ASMR configuration](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau:9>), [update loop](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/AsmrEffectsClient.client.luau:194>).

**P2 — Inspect aggregate shared work at the target player count.** MovementGuard samples at roughly 10 Hz, World 2 safe-zone checks use an 0.08-second interval, and pads inspect movement on Heartbeat. These are individually bounded loops. Profile their aggregate cost with the intended number of players before changing frequency or architecture. [Safe-zone interval](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau:22>).

### Findings that argue against a blanket rewrite

The automatic `World2StageSystem` returns early when authored manual markers exist. Those markers exist in the inspected place. Likewise, the World 1 treadmill-label implementation returns early in World 2. Their presence in the Explorer tree does not prove competing active systems. [Stage-system guard](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Worlds/World2StageSystem.server.luau:24>), [treadmill guard](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Progression/TreadmillOverheadLabels.server.luau:19>).

The legacy stats implementation also returns early because modular data service is enabled. The movement controller yields control while flight is active. The shared flight service has guarded startup; the flight client normally sends active/powered state only when it changes, and the server rate-limits that remote. These inspected paths do not support a claim that duplicate flight services or a per-frame flight remote flood explains the current lag. [Legacy stats guard](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Progression/PlayerStats.server.luau:9>), [movement handoff](<C:/Users/Aoshy´/Desktop/Update2/src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau:373>), [flight state sending](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Movement/World2FlightAbility.client.luau:96>), [server flight validation](<C:/Users/Aoshy´/Desktop/Update2/src/common/ServerScriptService/Core/Abilities/FlightService.luau:274>).

Roblox recommends using measured bottlenecks to guide changes and supports client-side visuals where the server only needs outcome-relevant state. Apply that selectively to demonstrated costs. [Roblox performance guidance](https://create.roblox.com/docs/performance-optimization/improve).

## 7. Additional World 2 consistency issue

**Sonic contact ignores the teleport-protection contract used by other hazards. Priority: P1.**

Tree contact checks `StageTeleportInvulnerable` and local safe-zone state. The extracted lava scripts also respect teleport protection. In contrast, Sonic’s client contact handler directly sets health to zero after area/distance/contact checks, and its server remote handler also kills an alive player inside the boss area without checking teleport invulnerability or arrival grace.

This means a player touching Sonic during an otherwise protected teleport/revive window is not protected by these handlers. It is a static inconsistency, not a reproduced live revive incident. Both sides need the same protection predicate; fixing only the server would leave the client-side death path.

Sources: [tree protection](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau:218>), [Sonic client death](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2SonicEXEBoss.client.luau:339>), [Sonic server death](<C:/Users/Aoshy´/Desktop/Update2/src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau:431>).

The Sonic server contact handler also relies on the client to report contact; its server validation checks the area rather than actual proximity to the boss. That is a trust-boundary review item. It does not let this remote select and kill arbitrary other players—the handler acts on the sender—but it is not authoritative collision verification.

## 8. Proposed repair sequence

| Order | Work | Completion criterion |
|---|---|---|
| 1 | Add structured reward rejection diagnostics and enable realistic validator testing. | Every attempted claim has a traceable accepted, pending, or rejected outcome. |
| 2 | Consolidate and rebalance World 2 movement, including sprint, selectors, and flight floors. | Same profile is intentionally slower in World 2; documented route times still reward progression. |
| 3 | Resolve final cooldown and checkpoint policy; make legitimate flight/teleport routes compatible. | All supported legitimate routes claim successfully; unauthorized skips remain blocked. |
| 4 | Repair purchase-to-pad continuation and clarify permanent versus per-run x2 semantics. | Fresh buyer, existing owner, cancellation, and delayed receipt all have predictable outcomes. |
| 5 | Make completed-run rewards recoverable across return, pending writes, and session loss. | No duplicate grants and no silently discarded completed run after a failed payout. |
| 6 | Align Sonic, tree, and lava damage protection. | Protected arrivals survive; ordinary valid contact remains lethal. |
| 7 | Profile and optimize measured hotspots individually. | Before/after captures show improvement without collision, reward, or purchase regressions. |
| 8 | Build both places from canonical sources and validate a controlled release. | Published build identity is known and matches the reviewed source. |

P1 here means a release-priority correctness or gameplay concern, not a claim that every player encounters the failure. P2 means an important robustness or performance investigation. None of these findings establishes a need for an emergency total-network rewrite.

## 9. Acceptance tests before release

**Movement and progression**

1. Compare the same stored-speed profile in both worlds on every selector, including Custom. Record the configured scale, selected speed, and observed movement.
2. Test low, entering, mid-progression, reference, and very high profiles. Verify sprint and temporary movement effects apply once.
3. Run the course with powered flight and glide, with and without stamina, looking level and downward. Include mobile controls and land/flight transitions.
4. Confirm a lower scale does not create unusably slow minimum movement or flight floors that erase the benefit of early progression.

**Pads and eligibility**

5. Cross every normal/x2/final pad slowly and at maximum supported speed, approaching from both directions. Include stepping, jumping, and valid flight approaches.
6. Complete two legitimate runs less than 180 seconds apart. Verify the chosen repeat-win policy and its visible message.
7. Run the real movement validator, not the automatic Studio bypass. Test every valid checkpoint route and sanctioned skip, revive, and stage teleport.
8. Simulate delayed samples and a character respawn near a pad. Confirm old motion evidence cannot claim and valid new contact still can.
9. Attempt an unauthorized stage jump. It must not grant wins; returning to a valid route must have a defined recovery path.
10. Record at least 100 controlled legitimate pad crossings per selected stress scenario. Require no unexplained misses or duplicate rewards. This is a proposed gate, not a completed live test.

**Purchases and persistence**

11. Use separate fresh/unowned, legacy-pass, x2, and higher-multiplier test profiles. Check both pad labels and exact reward totals.
12. Buy while standing on x2, cancel while standing, leave during the prompt, die during the prompt, and receive a delayed receipt. Grant only after verified receipt/entitlement and valid reward eligibility.
13. Verify product `3712435111` in the intended experience and confirm its live receipt route in a controlled test.
14. Inject pending writes, a final rejection, a disconnect, and a duplicate receipt/operation. The same reward must settle once, with a clear pending or failed outcome rather than silent loss.

**Hazards and performance**

15. Teleport or revive into each hazard area during protection, then repeat after protection expires. Test Sonic client and server behavior together.
16. Record matching World 1/World 2 sessions at one player, a small group, and intended server occupancy. Use the same route and representative desktop/mobile devices.
17. Capture client frame time, server frame time, script/physics costs, memory, instance counts, streaming spikes, data ping, and network traffic. Repeat isolated runs with trees, local contact checks, or effects disabled in a test copy to identify causal costs.
18. Check stream-out and stream-in near trees, Sonic, ASMR effects, and pad labels. Look for duplicate connections, missing visuals, and one-time loading hitches separately from sustained lag.

## 10. Evidence status at handoff

**Completed:** four-place inventory; complete newest-place source comparison; active movement/flight trace; product-to-receipt trace; live-mode guard reproductions with mocks; actual x2 callback/latch reproduction; teleport-before-rejected-commit reproduction; existing pad contract checks for both worlds; inspection of relevant World 2 hazard and update loops.

**Still needed:** confirmation of the published version; live pad failure telemetry; intended repeat-win and x2 purchase policy; known-good historical speed evidence if an exact revert is required; Creator Dashboard product verification; multiplayer, mobile, physics, and MicroProfiler captures.

The most defensible diagnosis is a combination of **movement balance regression, silent eligibility rules, incomplete purchase continuation, and inconsistent hazard protection**. Performance needs its own measurements. Correct those specific behaviors and measure the remaining lag before committing to a larger architecture change.
