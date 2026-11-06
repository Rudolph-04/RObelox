# Rhythm "Game Feel", Rhythm-Command Design and Onboarding (for Laskar Kendang)

Research date: 2026-11-07. Scope: design principles only (no engine audio APIs, no networking).
Laskar Kendang reference: 120 BPM (500 ms/beat), 4-beat player input phase + 4-beat squad answer phase (= 2 s each), 5 chained commands -> "Semangat".

Source-quality legend used below: [primary] = developer's own words/official; [review] = critic review; [fan] = wiki/forum/player post; [3rd-party summary] = someone else's notes of a talk.

---

## Q1. What makes hitting notes/drums feel good: audio feedback timing, juice, hit sounds, forgiving vs strict windows, early/late indicators

### Takeaway
Developers of games where rhythm drives a character (NecroDancer, Rhythm Quest, Hi-Fi Rush, Patapon) mostly agree on wide, forgiving windows for "did the action happen". They put precision grading only on things that pay off (damage, score, fever), and they make the result of each press audible right away (a drum or clack sound that changes with hit quality). Strict windows (~20-45 ms) belong to score-chasing games like DDR/Rhythm Doctor/Taiko. Applying them to a game where you command characters causes stress and makes players drift off the beat.

### Cited Findings
**Window size: forgiving vs strict (with numbers)**
- Crypt of the NecroDancer's first build used ~20% leeway around the beat. At 120 BPM (500 ms/beat) that means a move had to land within ~100 ms of the beat. Clark later found the window "worked best at 100% leeway" and called copying traditional rhythm-game strictness an error: "I think I was unwise to emulate rhythm games here," "Requiring accuracy is just frustrating." He argues the challenge should come from tactics, not precise execution. [primary, Ryan Clark, 2014-09-17] — [Game Developer: Finding the beat in Crypt of the NecroDancer](https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-)
- NecroDancer logs showed players "naturally drift away from the beat when stressed" and drift back afterwards. A missed beat made the move fail, which got players killed in tense moments and caused frustration. That was the reason for the wider window plus autocalibration. [primary, 2014-09-17] — [Game Developer (Clark)](https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-)
- NecroDancer autocalibration: a "leaky integrator" slowly shifts the effective beat position toward the player's actual tempo. The shift is capped so the effective beat never moves more than half a beat from the true beat. Clark: "A player hits the key when they perceive the beat to be. They might be wrong, but that's where they feel that the beat is!" [primary, 2014] — [Game Developer (Clark)](https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-)
- NecroDancer: moving player and enemies simultaneously on the beat (instead of enemies moving between beats) "makes the whole game feel more unified on the beat". [primary, 2014] — [Game Developer (Clark)](https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-)
- Rhythm Quest (DDRKirby(ISQ)) made obstacle windows "a bit more lenient across the board" to "remove 'feel bad' experiences" and to tolerate an "inaccurate or skipped" latency calibration. The intended challenge is reading obstacles and pressing to the right general rhythm, not sub-fraction-of-a-second precision. The game deliberately has no Perfect/Good/Bad judgements, because they would detract from the "tactile and synesthetic" experience. [primary, Devlog 11, 2021-08-23] — [Rhythm Quest Devlog 11](https://rhythmquestgame.com/devlog/11.html)
- Rhythm Quest's windows are generous enough that a press ~125 ms off can still count. The developer contrasts this with DDR, where that timing would barely earn a "good". [primary, Devlog 14, ~2021] — [Rhythm Quest Devlog 14 (Medium)](https://ddrkirbyisq.medium.com/rhythm-quest-devlog-14-closed-alpha-test-feedback-5df7e1e46347)
- Rhythm Quest rejected buffering early inputs and freezing the character on late ones, because empty jumps and attacks felt "sluggish and awkward". It kept an immediate response to every press, and later added a window-leniency modifier implemented by resizing obstacle colliders. [primary, devlogs 14/56; from search excerpts] — [Devlog 56](https://rhythmquestgame.com/devlog/56.html); [Devlog 14](https://ddrkirbyisq.medium.com/rhythm-quest-devlog-14-closed-alpha-test-feedback-5df7e1e46347)
- Rhythm Quest late-jump correction: jump duration is stretched or shortened so the player lands on the intended beat, applied at 50% strength because full correction "felt unnatural". [primary, 2021-08-23] — [Rhythm Quest Devlog 11](https://rhythmquestgame.com/devlog/11.html)
- Strict end, for comparison. StepMania 3.9 default judge windows (± seconds): Marvelous 0.0225, Perfect 0.045, Great 0.09, Good 0.135, Boo 0.18. StepMania 5.3 added an even tighter ~0.01125 s tier. [fan/forum, unverified against source code] — [FlashFlashRevolution: SM5 timing windows](https://www.flashflashrevolution.com/vbz/node/100084); [atwiki (JP)](https://w.atwiki.jp/iamkenzen/pages/203.html)
- osu!taiko (fan-made Taiko-like game; NOT official Taiko no Tatsujin): GREAT half-window = 50 − 3×OD ms (≈ ±50 ms down to ±20 ms), OK = 120 − 8×OD ms for OD ≤ 5, or 110 − 6×OD ms for OD ≥ 5 (≈ ±120 ms down to ±50 ms). [fan/official osu! wiki] — [osu! wiki: osu!taiko judgement](https://osu.ppy.sh/wiki/en/Gameplay/Judgement/osu%21taiko)
- Taiko no Tatsujin (Switch) "Easier Hit Timing" option reportedly ~triples the Good window and widens OK by ~25%. In Taiko, a "Bad" hit breaks the combo even though the drum registered. [fan, Reddit FAQ 2021-04-22; Timezone blog] — [r/taikonotatsujin FAQ](https://lr.sudovanilla.org/r/taikonotatsujin/comments/mvz94m/frequently_asked_questions_edition_v4); [Timezone blog](https://www.timezonegames.com/en-sg/blog/beat-the-boredom-10-tips-to-level-up-your-taiko-no-tatsujin-game-at-timezone/)
- Rhythm Doctor (one-button, score-strict): an early dev forum thread reportedly set the hit window at about 0.02 s and rejected widening it for lag, because that would make it feel like Guitar Hero/Rock Band. It relies on calibration instead. [fan/forum, 2013-14 thread; number unverified] — [TIGSource Rhythm Doctor thread](https://forums.tigsource.com/index.php?topic=37677.0)

**Snap the action to the beat (Hi-Fi Rush model)**
- Hi-Fi Rush: attacking on rhythm is not required, because actions automatically sync to the music. [Wikipedia] — [Hi-Fi Rush](https://en.wikipedia.org/wiki/Hi-Fi_Rush). Reviewers say an off-beat press still goes through but the attack lands on the next beat. On-beat attacks deal more damage, and the only negative reinforcement is "a slight hit to your score". [review, 2023] — [GameSpot review](https://www.gamespot.com/reviews/hi-fi-rush-review-good-vibes-only/1900-6418023/); [VideoGameLizard](https://videogamelizard.com/reviews/hi-fi-rush-review/)
- John Johanas' GDC 2024 talk: "Developing 'Hi-Fi RUSH' Backwards and Finding Our Positive Gameplay Loop". [primary listing, GDC 2024] — [GDC Vault](https://gdcvault.com/play/1034256/Developing-Hi-Fi-RUSH-Backwards)
- A third-party developer's notes on that talk list these rules: a press snaps to its nearest beat and the impact lands a set number of beats later (late press → animation plays faster, early → slower); reward on-beat play; no "miss" text; grade timing only where timing changes the outcome; rumble only on impact beats; optional beat indicator; test with players who have no musical training. [3rd-party summary, unverified; notes misdate the talk as "probably 2023"] — [GitHub PR notes](https://github.com/nick-vas/Godot_TestSuite/pull/60)

**Hit sound design and audio feedback**
- Patapon (Kemmei Adachi, sound): he wanted each button press "to feel good and to sound commanding". Congas and bongos alone felt unsatisfying, so the team blended African instruments with percussion from many countries. Kotani said "pata" was especially hard to get right. Adachi: "I have to admit I'm a little obsessed with the 'don' sound." [primary, 2017-08-01] — [PlayStation Blog: complete story behind Patapon](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- In Patapon each beat is graded normal/good/perfect, and you can hear the difference: perfect drum hits sound louder and fuller, weak ones flat. Patapon 2 gave miss, good and perfect their own drum sounds. [fan, GameFAQs] — [GameFAQs: I don't understand Fever Mode](https://gamefaqs.gamespot.com/boards/942065-patapon/41832944); [GameFAQs: Fever Mode](https://gamefaqs.gamespot.com/boards/942065-patapon/42247824)
- Rhythm Doctor: pressing produces an audible clack, and players use their own press sound to judge whether they are on the beat. A softer click option exists. [review] — [GameGrin Rhythm Doctor review](https://www.gamegrin.com/reviews/rhythm-doctor-review/)
- Thumper (Marc Flury): the goal was to make "the rhythmic stuff feel super impactful in a way that rhythm games usually don't". A good-enough turn gives "pleasant but muted musical feedback", while mistakes get harsh audio. [primary quote via coverage; exact outlet not verified] — [Superjump: The Helpful, Harmful Sounds of Thumper](https://superjumpmagazine.com/the-helpful-harmful-sounds-of-thumper); GDC 2017 postmortem listing: [GDC Vault: Seven Years in Alpha – Thumper](https://gdcvault.com/play/1024291/Seven-Years-in-Alpha-Thumper)
- Rhythm Heaven: the team wanted "sound [with] impact, sound that would spin around in your head after you play" (Yone, sound staff). [primary, Iwata Asks: Rhythm Heaven Fever, 2011/12] — [Iwata Asks: Rhythm Heaven Fever](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/1)

**Visual "life" on the beat**
- Patapon: a programmer independently added Patapons raising their spears to the beat. Kotani said this made them "feel alive". [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)

### Inferences
- For Laskar Kendang, split the two jobs a window does. (a) A wide "command counts" window: inference from NecroDancer/Rhythm Quest, roughly ±150-200 ms at 500 ms/beat, i.e. 30-40% of a beat. (b) Narrower "quality" tiers that only affect Semangat/damage. Example: PERFECT ≈ ±50-60 ms, GOOD ≈ ±100-120 ms. These match the StepMania "Perfect/Great" and osu!taiko lenient values, adapted. This mirrors Patapon's normal/good/perfect, where normal still issues a command, and Hi-Fi Rush's "grade only where it changes the outcome". These specific numbers are a proposal, not taken from any single source.
- Play the drum sound on the press itself (immediate, never quantized), but snap the squad's action and animation to the beat. This is the Hi-Fi Rush pattern. The press feels responsive and the world still looks perfectly in time.
- Vary the hit sound with judgement, the way Patapon does (fuller or louder for PERFECT, flatter for GOOD, a dull "thud" for off-window). The ear then learns timing without reading text.
- Consider a NecroDancer-style autocalibration (slow, capped drift) during play. It is especially useful on Roblox mobile, where device latency varies a lot.
- The unit hop on answer beats matches the "spears raised to the beat made them feel alive" observation. Extend it so units also bob or ready-pose during the input phase, so the world is always on the beat.

### Gaps
- I found no first-party millisecond window values for Patapon, Hi-Fi Rush, Metal: Hellsinger or official Taiko no Tatsujin. Commonly quoted ITG values (Fantastic ~21.5 ms, Excellent ~43 ms, Great ~102 ms) could not be verified in this session.
- I found no developer source with specific guidance on early/late text indicators ("EARLY/LATE"). The only related item: the Finger Dance research game (audio-only rhythm game for visually impaired players) records early vs late per keystroke ([a11y-paradise summary](https://a11y-paradise.onrender.com/reviews/69e1038385fefedddb62b3ad)). Whether to show early/late in-game is still a design call.
- The "Juice it or lose it" talk (Jonasson & Purho) and other general juice talks were not retrieved and are not cited here.
- I could not retrieve the Hi-Fi Rush GDC talk content directly; the rules above rely on a third-party summary.

---

## Q2. Rhythm-command games (Patapon and similar): teaching the beat, listen/answer phases, streak rewards (fever), failure handling, and criticisms

### Takeaway
Patapon runs everything at 120 BPM. It uses a pulsing screen border as its main beat signal, call-and-response singing (the units sing the command back) for the "answer" phase, and a Fever state reached by combo (faster with perfect timing) that boosts stats and makes the music livelier. Its creator explicitly designs to "praise, not scold". Criticism has targeted grinding and random drops, repetition, and a missing pause/save. In the 2025 remaster, critics added input latency and a crude 1-10 calibration slider. For the 2025-26 successor Ratatan, critics cited a confusing tutorial/UI at demo stage, frame drops hurting timing, and repetition.

### Cited Findings
**Core loop, tempo and call-and-response**
- All Patapon tracks share a 120 BPM marching tempo. Adachi found this constraining because rhythm games usually vary tempo, so he worked to keep tracks from sounding alike. [primary, 2017-08-01] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Call-and-response became central. Early on, Patapons repeated commands back. Developer Pyramid suggested having them *sing* back, Kotani wrote the lyrics, and Adachi built the melodies. Many voice types (weak, angry, etc.) were recorded so the swarm felt large. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- No on-screen command prompts. Kotani wanted "the game [to] be about communicating with this tribe that don't understand your words." The march command's name doubles as its rhythm ("pata pata pata pon"), which makes it easy to remember. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Simplicity: colleagues asked whether a good game could work with "only three commands". Kotani stuck with "simpler games are better". [primary, 2008-12-04] — [Game Developer: Kotani – Praise Players, Don't Scold Them](https://www.gamedeveloper.com/game-platforms/-i-patapon-s-i-kotani-praise-players-don-t-scold-them). Search excerpts also describe a two-tier depth: a layer clearable with three commands, plus a deeper layer of weapons and equipment. [search excerpt, not fully read] — [Game Developer: The Rhythm of Creation](https://www.gamedeveloper.com/audio/the-rhythm-of-creation-hiroyuki-kotani-and-patapon)
- Prototyping took all but ~3 months of Patapon's ~2-year development. [primary, 2008/2017] — [Game Developer (Kotani)](https://www.gamedeveloper.com/game-platforms/-i-patapon-s-i-kotani-praise-players-don-t-scold-them)
- Decision pressure: players have about two seconds to choose between attack, defend and retreat. Kotani sees this time pressure as both the difficulty and the appeal. Getting hit can throw off a player's rhythm ("Don't underestimate the value of chaka chaka!"). [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)

**Signalling the beat and phases**
- "A pulsating border shows the rhythm to input commands." Stopping commands or inputting off-beat loses the combo and Fever. [Wikipedia] — [Patapon (Wikipedia)](https://en.wikipedia.org/wiki/Patapon)
- When Fever music starts it no longer clearly cues the next drum hit, so players watch the blinking border, which keeps a steady rhythm. Players report being thrown by a brief rhythmic pause right before Fever, and counting "1,2,3,4" aloud or tapping a foot through the transition. In Patapon 2/3 the word "Fever" is sung on the beat every half second (= every beat at 120 BPM), which helps keep time. [fan, GameFAQs] — [GameFAQs: trouble keeping rhythm when fever comes](https://gamefaqs.gamespot.com/boards/942065-patapon/41278278); [GameFAQs: Fever Mode](https://gamefaqs.gamespot.com/boards/942065-patapon/42247824)

**Fever (streak reward)**
- Wikipedia: Fever starts after a 10-command combo, or earlier if a combo of 3+ is performed perfectly in sync. It raises attack and defense and enables "Miracles" (weather effects). [Wikipedia] — [Patapon](https://en.wikipedia.org/wiki/Patapon)
- Conflicting fan and guide details: the Patapon 3 guide says Fever comes with perfect timing on all four beats while combo > 3. A GameFAQs poster says four perfect beats at combo ≥ 2 can trigger it early. Normal-quality beats still issue commands but don't keep Fever; good/perfect beats do. [fan/guide] — [StrategyWiki: Patapon 3 Controls](https://strategywiki.org/wiki/Patapon_3/Controls); [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/41832944). One review says a single mistimed beat ends Fever immediately. [review, 2025] — [Final Weapon: Patapon 1+2 Replay review](https://finalweapon.net/2025/07/10/patapon-12-replay-review-move-to-the-beat-of-the-drums/)
- In Patapon Remastered (PS4), Fever needs only a 3-combo, making it easier to reach than on PSP. The team also worked to reduce display lag on modern TVs. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Fever makes the music "more lively" (a method used in LocoRoco). Music was built from two mixes split across three tracks that respond to game state. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)

**Failure handling and difficulty philosophy**
- Kotani, a former teacher: players, like students, should be praised rather than scolded, and happy students "would learn more". "I have to make the users happier, so they would feel like they are encouraged to go to the next stage." [primary, 2008-12-04] — [Game Developer](https://www.gamedeveloper.com/game-platforms/-i-patapon-s-i-kotani-praise-players-don-t-scold-them)
- Kotani admitted the irregular "don, dodon, dodon" Miracle rhythm was too hard for some: "I wanted to make a game anyone could enjoy, but it seems I made Patapon a little too hard." [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)

**Criticisms (original, 2008)**
- No pause during missions (Luke Mitchell, PALGN, 2008-03-03; Jeff Hayes, IGN, 2008-02-15). Reliance on random drops for materials (Bryan Vore, Game Informer, 2008-03-03). Replaying earlier missions for resources (IGN; Dave McCarthy, Eurogamer, 2008-01-09). Grindy, with minigames needing up to three songs for one item (Gus Mastrapa, X-Play, 2008-03-11). "Some reviewers" cited repetition. [review, via Wikipedia] — [Patapon (Wikipedia)](https://en.wikipedia.org/wiki/Patapon)

**Criticisms (Patapon 1+2 Replay, July 2025)**
- OpenCritic: 77 average from 69 critics, 65% recommend. [aggregator] — [OpenCritic](https://opencritic.com/game/18881/patapon-1-2-replay)
- The Sixth Axis (2025-07-10): it feels harder than on PSP because of input latency, and the "ten-point input timing scale" offers "no additional help" to tune it. [review] — [The Sixth Axis](https://www.thesixthaxis.com/2025/07/10/patapon-12-replay-review-rhythm-action-repeat/). ConsoleCreatures: a 1-10 slider "doesn't offer enough choice" versus a proper calibration tool. [review] — [ConsoleCreatures](https://www.consolecreatures.com/patapon-1-2-replay-review/). Nintendo World Report: a tedious loop of change setting → relaunch → test, and difficulty tiers mainly change how exact command timing must be. [review] — [NWR](http://www.nintendoworldreport.com/review/71788/patapon-12-replay-switch-eshop-review). Nintendo Insider: the tiers mainly make Fever more forgiving, and it wants separate timing settings for docked and handheld. [review] — [Nintendo Insider](https://www.nintendo-insider.com/patapon-1-and-2-replay-review/)
- Praised additions: a command list display, input adjustment, and difficulty options as quality-of-life (NookGaming). Repetitive gameplay and random loot remain criticized. [review] — [NookGaming](https://www.nookgaming.com/patapon-12-replay-review/). Vooks: the latency slider helps Bluetooth headphone users. [review] — [Vooks](https://www.vooks.net/patapon-1-2-replay-switch-review/)

**Ratatan (Kotani + Adachi's spiritual successor, roguelite, 2025 EA / 2026 full)**
- Demo feedback: the tutorial and UI were hard to understand, and visuals and gameplay rewards felt underwhelming. The Early Access release was delayed to improve them. [news, via search excerpt; article body not retrievable] — [Automaton](https://automaton-media.com/en/news/patapon-spiritual-successors-early-access-release-delayed-in-response-to-harsh-demo-feedback/)
- Frame-rate drops in busy late stages make hitting perfect notes tough (Switch 2). [review] — [Nintendo Everything](https://nintendoeverything.com/?p=926897). Repetition and "borrowing too many ideas" were also cited (OpenCritic excerpts). The Sixth Axis (2026-10-26) called it "largely successful". [review] — [OpenCritic Ratatan](https://opencritic.com/game/21523/ratatan/reviews); [The Sixth Axis Ratatan review](https://www.thesixthaxis.com/2026/10/26/ratatan-review-banging-the-drum/)

### Inferences
- Laskar's structure (120 BPM, 4-beat call + 4-beat answer, ~2 s decision window) is very close to the proven Patapon tempo and phase structure. The 120 BPM choice is validated. The differentiators have to come from theme, sound and visuals.
- The answer phase should be a sung or chanted response in the squad's own voice, e.g. units chanting the drum syllables back in a local style. This is what made Patapon's phases readable by ear, not just by the gold border.
- Keep the beat audibly and visually continuous through the Semangat transition. No gap or pause before the Semangat music; Patapon players stumble exactly there. Keep the border pulse and a sung beat-marker running.
- Semangat at 5 chained commands sits between Patapon PSP (10, or ~3 if perfect) and the Remaster (3). A "faster entry with PERFECTs" rule, plus GOOD-or-better needed to *stay* in Semangat, would copy Patapon's proven tiering. Consider softening "one miss ends Semangat" (e.g., drop one level or drain a meter). The Replay reviews show difficulty settings were mostly used to make Fever more forgiving.
- Failure messaging: follow Kotani's "praise, not scold" and Hi-Fi Rush's "no miss text". Replace a harsh "MISS" with a neutral sound plus a soft cue. When the player hits during the answer phase, cue "listen" (e.g., units shush or point at their ears) instead of a red failure.
- To avoid grind and repetition criticism, vary missions or rhythms instead of farming. Add pause and mid-run saves. Show a command list on screen (praised in Replay). Keep the tutorial and UI very simple (Ratatan demo lesson).
- Performance is part of timing feel: frame drops cost perfects (Ratatan). Keep VFX budgets low on Roblox mobile.

### Gaps
- No official Patapon document gives the exact Fever rules per game. Fan sources conflict (see above).
- No first-party Patapon timing-window numbers were found.
- I found no source describing exactly what the original Patapon does when the player drums during the Patapons' response (players commonly report it breaks the combo, but I did not find a citable statement).
- I could not read the full Ratatan Automaton article or Ratatan developer interviews about tutorial changes.

---

## Q3. Communicating the beat visually (sound off, laggy/mobile devices): beat indicators, metronome visuals, anticipation cues

### Takeaway
Every successful game in this set gives a non-audio beat channel. Patapon uses a pulsing border, NecroDancer a beat meter showing upcoming beats, Hi-Fi Rush an optional companion pulse or bottom beat bar (an accessibility setting), and Metal: Hellsinger a rhythm indicator on the reticle with a custom color. Laggy setups also need a real calibration flow, not a blind slider. Audio-visual offset should be measured with a tap test.

### Cited Findings
- Patapon: a "pulsating border shows the rhythm to input commands". [Wikipedia] — [Patapon](https://en.wikipedia.org/wiki/Patapon). Players use it when Fever music masks the cue. [fan] — [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/41278278)
- Crypt of the NecroDancer: with outside music, players "would then be forced to watch the 'beat meter' at the bottom of the screen to see the upcoming beat pattern, rather than just relying on their ears". [primary interview, Road to the IGF; date not verified] — [Game Developer: Road to the IGF – NecroDancer](https://www.gamedeveloper.com/business/road-to-the-igf-brace-yourself-games-i-crypt-of-the-necrodancer-i-)
- Hi-Fi Rush Accessibility menu: "Rhythm Visualization (808)". The cat companion near Chai's shoulder pulses a ring or flashes on each beat (several styles). A separate option shows a horizontal beat bar at the bottom of the screen. A "Single Button" option makes rhythm minigames playable with one button (timing still required). [review/guide, 2023] — [Game Rant](https://gamerant.com/hi-fi-rush-rhyjthm-challenges-minigames-skip-beat-robot-settings-accessibility/); [Dot Esports](https://dotesports.com/indies/news/how-to-turn-on-rhythm-assist-in-hi-fi-rush); [Kotaku AU (2023-02)](https://www.kotaku.com.au/2023/02/you-can-still-play-hi-fi-rush-if-you-suck-at-rhythm-games/)
- Metal: Hellsinger 2022 accessibility patch: changes to the rhythm indicator and reticle, and a custom color picker for both (helps colorblind players). A player asked for a high-contrast mode because the Beat Tracker blended into snow. [primary patch notes + forum, 2022] — [Funcom forum: Accessibility Patch 2022](https://forums.funcom.com/t/metal-hellsinger-accessibility-patch-2022/211854); [Funcom forum: Accessibility options](https://forums.funcom.com/t/accessibility-options/206142)
- Metal: Hellsinger beat offset is calibrated by timing clicks with the beat and a flash, automatically finding the offset. [review] — [Boiling Steam](https://boilingsteam.com/metal-hellsinger/)
- Rhythm Quest calibration: latency splits into audio (usually the largest; "Android devices are notorious" for high audio latency), visual (render queue, monitor), and input (debounce, frame-based polling, wireless). Tapping to an audio signal measures audio+input. Tapping to a visual signal measures visual+input. The difference is the A/V offset. Calibration taps play no sound (scheduled sound would carry latency). Only 4 tap samples are used because the eye can see small differences between flashing squares. [primary, 2021-08-06] — [Rhythm Quest Devlog 10](https://rhythmquestgame.com/devlog/10.html)
- Rhythm Quest pre-schedules hit/jump sounds at their correct time so they play on time despite audio latency. Side effect: the sound plays even if the player misses. Visuals cannot be pre-scheduled this way without jarring rewinds. [primary, 2021] — [Rhythm Quest Devlog 10](https://rhythmquestgame.com/devlog/10.html)
- Rhythm Quest: early testers found calibration hard to understand. The purest calibration is eyes closed, matching the sound of your tap to the sound of the beat. The calibration flow was redone in Devlog 80 (Oct 2025), and demo v0.39.0 uses 25 ms steps. [primary, via search excerpts] — [Devlog 14](https://ddrkirbyisq.medium.com/rhythm-quest-devlog-14-closed-alpha-test-feedback-5df7e1e46347); [Demo v0.39.0](https://ddrkirbyisq.itch.io/rhythm-quest/devlog/1087168/demo-v0390-released)
- Rhythm Doctor setup: players first match visuals to sounds, then set an input delay. [review] — [GameGrin](https://www.gamegrin.com/reviews/rhythm-doctor-review/)
- Patapon 1+2 Replay was criticized for exposing only a 1-10 timing slider with no test tool (see Q2). [review, 2025] — [The Sixth Axis](https://www.thesixthaxis.com/2025/07/10/patapon-12-replay-review-rhythm-action-repeat/); [ConsoleCreatures](https://www.consolecreatures.com/patapon-1-2-replay-review/)
- Human A/V sync perception (broadcast lip-sync research): ITU-R BT.1359-1 (1998) puts the detectability threshold at audio +45 ms early / −125 ms late relative to picture, and acceptability at about +90 / −185 ms. EBU R37 recommends +40 / −60 ms. People are much more tolerant of sound lagging the picture than leading it. [standards, via secondary source; derived from newsreader clips] — [Wikipedia: Audio-to-video synchronization](https://en.wikipedia.org/wiki/Audio-to-video_synchronization)

### Inferences
- Laskar's border pulse (white for input, gold for answer) matches Patapon's main cue. Add an *anticipation* cue, such as a NecroDancer/Hi-Fi Rush-style beat bar or ring where markers travel toward a hit line, or a ring that shrinks onto each beat. A pulse that fires *on* the beat only tells players they are already late. Also show beat numbers 1-2-3-4, plus a distinct downbeat ("1") marker so players know where the next command must start.
- Since people tolerate audio lagging visuals far more than the reverse, when visual and audio can't be perfectly aligned on a device, err toward visuals slightly early rather than late. This is an extrapolation from TV lip-sync research.
- Offer a proper tap-calibration screen (Rhythm Quest/Hellsinger style) with separate audio and visual offsets in ms (10-25 ms steps), not a 1-10 slider. Remember it per device type (mobile vs PC), as Nintendo Insider requested per-mode settings.
- On Roblox, many players are on phones with high audio latency (Rhythm Quest flags Android specifically). A strong visual metronome plus wide "command" windows is the main defence. Precise audio-based play should be optional.

### Gaps
- I found no data on what share of Roblox players play with sound off. This would need Roblox analytics or creator surveys (not found).
- No measured typical touch-input latency numbers for Roblox mobile were found (out of scope for this researcher; other researchers cover engine/network).

---

## Q4. Onboarding and tutorial patterns for rhythm games

### Takeaway
The proven pattern is a short, skippable, single-mechanic lesson on a simpler backing track before the real song. Introduce one input at a time, build on call-and-response, cue by sound first, and review mechanics cumulatively in "remix" stages. Practice without failure is an accessibility guideline. The failure case (Ratatan's demo) was a tutorial and UI that players found confusing.

### Cited Findings
- Rhythm Heaven: each minigame opens with a short tutorial so the player understands the task before the song. Every fifth stage is a remix combining the previous four. [review, Engadget 2009-03-25] — [Engadget/Joystiq Rhythm Heaven review](https://www.engadget.com/2009/03/25/joystiq-review-rhythm-heaven/)
- Rhythm Heaven tutorials can be skipped at any time. [fan wiki] — [Giant Bomb: Rhythm Heaven](https://giantbomb.com/wiki/Games/Rhythm_Heaven). Rhythm Heaven Fever's intro segment uses a simpler backing track so players learn each game's visual cues before the real song. [analysis] — [Mechanics of Magic critical play](https://mechanicsofmagic.com/?p=16005)
- Rhythm Heaven Miracle Stars (2026) opens with "Ring Toss", a one-button game that serves as the tutorial. Its practice section reportedly has no music, only the whoosh of rings. [review, Inven Global] — [Inven Global](https://www.invenglobal.com/articles/23007/heaven-is-found-in-the-beat-rhythm-heaven-miracle-stars-returns-after-10-years)
- Criticism of Rhythm Heaven Fever practice: "you'll get the moves but not always the rhythm", and players can't practise a specific troublesome section. [user review] — [Giant Bomb user review](https://giantbomb.com/rhythm-heaven-fever/3030-35607/user-reviews/2200-22108/)
- Tsunku's design rules: "Just make it simple. Controls easy. Don't lean on the characters. If the games themselves have rhythm and are fun that's all you need." Also: "Rhythm can be trained." [primary, Iwata Asks (written) for Megamix] — [Nintendo World Report: Iwata Asks Megamix](https://nintendoworldreport.com/feature/43066/iwata-asks-in-commemoration-part-3-rhythm-heaven-megamix-iwata-asks-in-writing-rhythm-heaven-megamix)
- Tsunku's original 2004 pitch was a rhythm game that does not rely on visual indicators for its rhythm. [Wikipedia] — [Rhythm Tengoku](https://en.wikipedia.org/wiki/Rhythm_Tengoku)
- Patapon taught through the command names themselves ("pata pata pata pon" is both name and rhythm) and avoided on-screen command prompts. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/). The 2025 Replay added a command list display, which was praised as QoL. [review] — [NookGaming](https://www.nookgaming.com/patapon-12-replay-review/)
- Ratatan's demo was criticized for a tutorial and UI that were hard to understand, which led to a release delay. [news excerpt] — [Automaton](https://automaton-media.com/en/news/patapon-spiritual-successors-early-access-release-delayed-in-response-to-harsh-demo-feedback/)
- BPM: Bullets Per Minute: a player credits its "beat sensitivity: low" setting as great onboarding to rhythm shooters. [fan, Steam] — [Steam discussion](https://steamcommunity.com/app/1286350/discussions/0/3874842132567745278)
- Game Accessibility Guidelines: "Include interactive tutorials" (Basic). "Include a means of practicing without failure, such as a practice level or sandbox mode" (Intermediate). [guideline] — [Game Accessibility Guidelines full list](https://gameaccessibilityguidelines.com/full-list/)
- Hi-Fi Rush design (third-party notes): test with players who have no musical training. [3rd-party summary] — [GitHub notes](https://github.com/nick-vas/Godot_TestSuite/pull/60)

### Inferences
Suggested Laskar onboarding ladder, synthesized from the above:
1. Free-drum the four drums with no beat, then on a beat with a visible metronome. A one-input-at-a-time drill like Ring Toss: DUNG only on every beat, then alternate.
2. "Follow me": the elder or drummer NPC plays a 4-beat pattern and the player copies it (call-and-response, like Patapon). Start with the march command only.
3. Introduce the answer phase explicitly: the squad chants back, and the player is told to "listen" (no input). Show this with a distinct visual (gold border plus a "listening" icon) and a voice.
4. Introduce chaining (start right on the next beat), then the remaining commands one at a time. End with a "remix" combining all four commands.
5. Unlock Semangat last, with a short scripted demo of the music change, so the transition doesn't surprise players.
- A practice mode with no failure (GAG) and an optional slower tempo (e.g., 90-100 BPM) for the first lessons. This tempo is an inference: the 86-120 BPM preferred-tempo range (Q6) supports starting slower and ramping to 120.
- Keep text minimal (Roblox players skew young). Teach mainly by example and sound.

### Gaps
- No developer-authored Patapon tutorial breakdown was found. I don't know exactly how Patapon 1's opening teaches the first commands from a first-party source.
- No hard data (retention or completion rates) on tutorial formats in rhythm games was found.

---

## Q5. Accessibility in rhythm games: timing assist, difficulty, colorblind-friendly colors, one-hand play, haptics

### Takeaway
Rhythm games now ship "beat assist" (Hellsinger: everything counts as on beat, leaderboards disabled), timing leniency toggles (Taiko "Easier Hit Timing", Rhythm Quest leniency modifier), visual beat aids (Hi-Fi Rush 808/bar), single-button modes, custom indicator colors, and calibration. The Game Accessibility Guidelines add: never convey information by color or sound alone, offer game speed and difficulty options, allow remapping, and add haptic toggles.

### Cited Findings
- Metal: Hellsinger "Beat Assist": "A mode to always stay on beat and ignore all penalties." Achievements are not affected. [primary patch notes, 2022] — [Funcom forum](https://forums.funcom.com/t/metal-hellsinger-accessibility-patch-2022/211854). The always-on-beat option disables leaderboards. [review] — [NookGaming Hellsinger VR review](https://nookgaming.com/metal-hellsinger-vr-review/). Without it, mistiming crushes the combo, damage and score multiplier. [news] — [Inverse](https://www.inverse.com/gaming/metal-hellsinger-playstation-plus-extra)
- Hellsinger: custom color picker for the rhythm indicator and reticle (colorblind help). Controller dead-zones and remapping were also added. [primary, 2022] — [Funcom forum](https://forums.funcom.com/t/metal-hellsinger-accessibility-patch-2022/211854); [TechRaptor](https://techraptor.net/gaming/news/metal-hellsinger-accessibility-update-is-totally-metal)
- Hi-Fi Rush: Rhythm Visualization (808 or beat bar) and a Single Button mode for rhythm minigames. [review/guide, 2023] — [Game Rant](https://gamerant.com/hi-fi-rush-rhyjthm-challenges-minigames-skip-beat-robot-settings-accessibility/)
- Taiko (Switch): "Easier Hit Timing" ≈ triples the Good window and widens OK by ~25%. [fan FAQ, 2021] — [r/taikonotatsujin FAQ](https://lr.sudovanilla.org/r/taikonotatsujin/comments/mvz94m/frequently_asked_questions_edition_v4)
- Rhythm Quest: a gameplay modifier for window leniency (implemented via collider size). [primary, via search excerpt] — [Devlog 56](https://rhythmquestgame.com/devlog/56.html)
- Patapon 1+2 Replay: three difficulty tiers (reviewers disagree whether they change timing strictness, Fever leniency, or damage) and a timing slider. [review, 2025] — [NWR](http://www.nintendoworldreport.com/review/71788/patapon-12-replay-switch-eshop-review); [Nintendo Insider](https://www.nintendo-insider.com/patapon-1-and-2-replay-review/); [Siliconera](https://www.siliconera.com/review-patapon-12-replay-keeps-the-beat-alive/)
- Rhythm Doctor: visual indicators for audio events, and audio for visual progress events. [accessibility database] — [Family Gaming Database: Rhythm Doctor](https://www.familygamingdatabase.com/accessibility/Rhythm+Doctor). Removing button prompts made it easier to adapt for blind players. [search excerpt of developer interview] — [Game Developer: Rhythm Doctor medical stories](https://www.gamedeveloper.com/design/using-medical-stories-and-heart-conditions-to-create-musical-challenges-in-rhythm-doctor)
- Game Accessibility Guidelines (living document) [guideline] — [GAG full list](https://gameaccessibilityguidelines.com/full-list/):
  - Basic: "Include an option to adjust the game speed"; "Offer a wide choice of difficulty levels"; "Ensure no essential information is conveyed by a fixed colour alone"; "Ensure no essential information is conveyed by sounds alone"; "Allow controls to be remapped / reconfigured"; "Include toggle/slider for any haptics"; "Ensure controls are as simple as possible, or provide a simpler alternative"; "Avoid flickering images and repetitive patterns"; "Include interactive tutorials".
  - Intermediate: "Allow difficulty level to be altered during gameplay…"; "Include a means of practicing without failure…"; "Provide an option to turn off / hide background movement"; "Avoid repeated inputs (button-mashing/quick time events)".
  - Advanced: "Do not make precise timing essential to gameplay" (with alternatives); "Include a cool-down period (post acceptance delay) of 0.5 seconds between inputs".
  - No GAG entry mentions rhythm explicitly, and none addresses one-handed play directly.
- AbleGamers Includification: all audio cues accompanied by visual cues; the game can be completed without sound. [guideline, ~2012] — [AbleGamers Includification PDF](https://accessible.games/wp-content/uploads/2018/11/AbleGamers_Includification.pdf)
- Xbox Accessibility Guideline XAG 103 covers "additional channels for visual and audio cues", and XAG's background material covers speed and controlling game speed. [guideline] — [Xbox Accessibility Guidelines version history](https://learn.microsoft.com/ar-sa/xbox/accessibility/xag-version-history)
- Hi-Fi Rush (third-party notes): rumble only on impact beats. [3rd-party summary] — [GitHub notes](https://github.com/nick-vas/Godot_TestSuite/pull/60)

### Inferences
- Laskar's four drums should be distinguishable by position, shape/icon and label (DUNG/TAK/PAK/TUNG), with color only as reinforcement. Use a palette that survives red-green deficiency (e.g., avoid pairing pure red/green drums) and let the player recolor. This follows GAG "not by colour alone" and the Hellsinger color picker.
- Offer an "Ritme Santai" (relaxed timing) toggle that widens windows (Taiko/Rhythm Quest), and a full "beat assist" that snaps every press to the beat (Hellsinger/Hi-Fi Rush). Exclude assist runs from any leaderboard, as Hellsinger does.
- One-hand and mobile: four large on-screen pads reachable by thumbs, plus a one-hand layout option. Optional: a "two-drum mode" where commands are simplified for accessibility. That last one is speculative; no source tested it.
- Haptics: a short vibration on a successful hit (and possibly a faint tick on the downbeat), with a toggle or slider. Roblox supports haptics on some mobile devices, but implementation is out of scope here.
- The 2 Hz border flash at 120 BPM is a "repetitive pattern". Provide an option to reduce the border pulse to a gentle glow and to turn off background movement (GAG).

### Gaps
- I found no sourced data on haptic feedback improving timing accuracy in rhythm games specifically.
- Photosensitivity flash thresholds (e.g., WCAG "three flashes") were not retrieved in this session. Check before finalizing border-pulse intensity.
- I found no rhythm-game-specific colorblind palette recommendations from a primary source.

---

## Q6. Music design for gameplay: carrying the beat, tempo ranges, fever/powered-up layers

### Takeaway
Patapon locks every song to 120 BPM. Its music is adaptive (two mixes over three state-driven tracks) and turns "more lively" in Fever. Its response chants double as beat markers ("Fever" sung on every beat). Research on human tempo preference puts the comfortable zone at roughly 86-120 BPM (500-700 ms), so 120 BPM is at the upper, energetic end and fits a marching/drumming feel. The main musical risk is a powered-up track that masks the beat; Patapon players lean on the border when the Fever song stops cueing the next drum.

### Cited Findings
- Patapon: all tracks are 120 BPM. Music uses two mixes split across three tracks that respond to game state. Fever makes it more lively (a LocoRoco technique). The sound team focused on representing swarms musically. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Patapon 2/3 sing "Fever" on the beat every half second during Fever. The Fever song does not cue the next drum hit reliably, so players watch the border. [fan] — [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/42247824); [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/41278278)
- Kotani's team listened to "a lot of drum-based music" while the look was still forming. [search excerpt of interview] — [PlayStation Blog 2017 interview](https://blog.playstation.com/2017/08/01/marching-to-the-beat-of-their-own-drum-an-interview-with-the-creators-of-patapon/)
- Rhythm Heaven treats background music as the timing source ("use background music as cues to perform actions", StrategyWiki via fan site). [fan] — [How Rhythm Heaven Works (fan site)](https://rhythm-heaven-groove.pages.dev/how-it-works). Tsunku wants players to keep the beat with their body (feet/chest). [fan summary of Iwata Asks] — [GoNintendo summary](https://www.gonintendo.com/archives/170735-iwata-asks-rhythm-heaven-fever-full-summary)
- Rhythm Doctor: a commenter noted audio cues became less reliable at bar changes. [fan/forum] — [TIGSource thread](https://forums.tigsource.com/index.php?topic=37677.0)
- Tempo perception. Preferred metronome tempo ("neither too fast nor too slow") falls mostly between 500-700 ms, about 86-120 BPM (Fraisse 1982, cited in a 2023 Frontiers paper), with wide individual variation. Spontaneous motor tempo was classically ~600 ms (100 BPM) but ranges 300-800 ms. Children (~4-7 years) have the fastest spontaneous tempo, older adults the slowest (~700 ms ≈ 86 BPM). A 2023 systematic review (Desbernats et al.) argues against treating 600 ms as a universal standard. McAuley et al. found strong coupling between preferred motor and auditory tempo. [academic, via search excerpts] — [Frontiers in Psychology 2023](https://frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1161052/text); [PMC article](https://pmc.ncbi.nlm.nih.gov/articles/PMC6987525)
- Thumper's audio gives restrained musical reward for adequate hits and stronger punishment for mistakes. [analysis] — [Superjump](https://superjumpmagazine.com/the-helpful-harmful-sounds-of-thumper)

### Inferences
- Keep the beat carriers in the mix in *every* state: a low drum or gong on beat 1 and a steady pulse on all four beats. Semangat must add layers (melody, extra percussion, choir or chant) on top of the same pulse, never replace it with syncopated material that hides the downbeat.
- Make the input phase and answer phase musically different (e.g., sparse accompaniment while the player drums, full squad chant during the answer). The ear then knows the phase without looking. Mark the last answer beat ("beat 8") with a pickup fill so the next downbeat (where the next command must start) is predictable.
- Because the player's drum sounds are part of the music, tune the four drums to sit *above* the backing mix (distinct timbres, little overlap with backing percussion). The player's own hits must stay audible as feedback (Rhythm Doctor clack, Patapon fuller perfect hits).
- 120 BPM fits: it's at the upper edge of the comfortable 86-120 BPM range, matches Patapon, and suits a young Roblox audience (children's natural tempo is faster). For tutorials, a slower 90-100 BPM is a reasonable ramp (inference).
- Adaptive Semangat music should change at a bar boundary, with a sung or drummed count-in. Don't insert a pause; Patapon players report the pre-Fever pause disrupts them.

### Gaps
- No primary source gave specific tempo ranges "that feel good for drumming" in games beyond Patapon's 120 BPM choice and the general perception research.
- I didn't retrieve composer talks on adaptive music layering for rhythm games (e.g., Hi-Fi Rush audio talks, Hellsinger's stem-based intensity system). Their specifics are unverified here.

---

## Q7. Common pitfalls that make rhythm games feel "off"

### Takeaway
The recurring failure modes are: latency nobody calibrated (or a crude slider), windows too strict for a non-score game, input sound or visual that lags the press, phase or music transitions that hide the beat, frame drops, confusing tutorials and UI, punishing failure states, and grind or repetition.

### Cited Findings
- Uncalibrated latency makes a game feel harder than the original: Patapon 1+2 Replay "feels harder than on PSP" due to input latency the handheld never had. A 1-10 slider with no test tool was widely criticized, as was having to relaunch to test settings. [review, 2025] — [The Sixth Axis](https://www.thesixthaxis.com/2025/07/10/patapon-12-replay-review-rhythm-action-repeat/); [NWR](http://www.nintendoworldreport.com/review/71788/patapon-12-replay-switch-eshop-review); [ConsoleCreatures](https://www.consolecreatures.com/patapon-1-2-replay-review/)
- Display lag on modern TVs makes rhythm games harder; the Patapon Remastered team worked to reduce it. [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Strict windows in a game where you control a character cause stress-induced drift and frustrating deaths (NecroDancer's original ~±100 ms at 120 BPM). [primary, 2014] — [Game Developer (Clark)](https://www.gamedeveloper.com/audio/game-design-deep-dive-finding-the-beat-in-i-crypt-of-the-necrodancer-i-)
- Delaying or freezing the character to "fix" off-beat input feels sluggish and awkward (Rhythm Quest rejected this). Full timing correction felt unnatural, while 50% felt right. [primary, 2021] — [Rhythm Quest Devlog 11](https://rhythmquestgame.com/devlog/11.html); [Devlog 14](https://ddrkirbyisq.medium.com/rhythm-quest-devlog-14-closed-alpha-test-feedback-5df7e1e46347)
- Three separate latencies (audio, visual, input) must be treated separately. Pre-scheduled sounds are on time but play even on misses, and visuals can't be pre-scheduled without rewinds. [primary, 2021-08-06] — [Rhythm Quest Devlog 10](https://rhythmquestgame.com/devlog/10.html)
- A/V offset becomes noticeable at about +45 ms (audio early) or −125 ms (audio late) per ITU-R BT.1359. [standard via secondary] — [Wikipedia: Audio-to-video synchronization](https://en.wikipedia.org/wiki/Audio-to-video_synchronization)
- Music transitions that drop the cue: Patapon Fever music stops cueing the next drum, and a pause before Fever trips players. [fan] — [GameFAQs](https://gamefaqs.gamespot.com/boards/942065-patapon/41278278)
- Frame drops cost perfect hits (Ratatan, Switch 2). [review] — [Nintendo Everything](https://nintendoeverything.com/?p=926897)
- Visual clutter over notes (story text or art covering cues) hurts timing (Rhythm Doctor critique). [review] — [note.com review](https://note.com/yusuke3rd/n/n6f4851e2c746?hl=en). Hellsinger's beat tracker blending into snowy backgrounds is a contrast problem. [fan] — [Funcom forum](https://forums.funcom.com/t/accessibility-options/206142)
- Irregular rhythms in otherwise regular games can be too hard (Patapon's "don, dodon, dodon" Miracle). [primary, 2017] — [PlayStation Blog](https://blog.playstation.com/archive/2017/08/01/the-complete-story-behind-rhythm-action-classic-patapon-as-told-by-the-games-creators/)
- Meta-level pitfalls: grind, random loot, repetition, no pause (Patapon reviews 2008 and 2025); confusing tutorial and UI, underwhelming rewards (Ratatan demo). [review] — [Patapon (Wikipedia)](https://en.wikipedia.org/wiki/Patapon); [NookGaming](https://www.nookgaming.com/patapon-12-replay-review/); [Automaton](https://automaton-media.com/en/news/patapon-spiritual-successors-early-access-release-delayed-in-response-to-harsh-demo-feedback/)
- Hi-Fi Rush player anecdote: if the first hit in a chain is missed, re-pressing when it would have landed puts later hits on beat. The engine re-anchors to the player's timing. [fan, Steam] — [Steam discussion](https://steamcommunity.com/app/1817230/discussions/0/3785876820735552611)

### Inferences
Checklist for Laskar Kendang, inferred from the above:
- **Judgement centering:** judge against the beat time as *perceived* by this device (song position minus calibrated offset), not raw engine time. Verify that the mean error of good players is ~0 ms. If PERFECTs cluster on one side, the window center is wrong.
- **Never delay the hit sound or pad pulse to wait for judgement.** Play them on press, then show the judgement text. The text can arrive slightly later because it is not a timing cue.
- **Border pulse and beat visuals must be driven by the music clock, not frame timers,** and offset by the visual calibration. Pulses that drift from the music are the most visible "off" feeling.
- **Phase boundaries:** make beat 1 of each new command phase unmistakable (a downbeat marker plus a sound), because the "start right on the next beat" rule is the hardest moment in this loop.
- **Inputs during the answer phase:** treat them gently, e.g. ignore the first stray tap or give a soft "listen" cue. Never a harsh penalty that also wipes Semangat on a single slip, unless at a high difficulty.
- **Performance:** cap particles and effects on mobile. Frame drops read as timing errors.

### Gaps
- I found no published quantitative threshold for "how late can the hit sound be before the drum feels laggy". The A/V sync numbers are the closest proxy but come from TV lip-sync, not interactive input.
- I didn't verify how Patapon, Hi-Fi Rush or Hellsinger center their windows (symmetric vs biased early/late).
