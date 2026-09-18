# Koperasi polish — design

**Branch target:** `feat/koperasi-rework`
**Scope:** four coordinated polish passes on `Scenes/Koperasi/koprasi.tscn`.
No new persistence, no changes to Cart/inventory contracts, no minigame code.

## Motivation

The Koperasi screen reads flat: stock is invisible, Pak Herman's greeting is a
static bubble that never reacts, the basket tray covers a third of the shelf
even when empty, and the back button is anchored to the shelf art rather than
the interactive furniture below it. Four small changes make the scene feel
alive without touching the purchase pipeline.

---

## 1. Visible per-slot stock (1–3 copies)

**Where the data already is:** `GameState.roll_shop_stock(names, size,
max_copies)` builds a bag with each name repeated `max_copies` times and picks
`size` of them, so a shelf can already show a name two or three times. Each
duplicate is a *separate slot* and sells once — `rakbarang_1.gd`'s
`_taken_slots` handles that.

**Changes**

- `Scripts/GameState.gd`
  - `const SHOP_MAX_COPIES: int = 2` → **`3`**.
- `Scripts/Koperasi/rakbarang_1.gd`
  - After `setup_shelf()`, count how many copies of each `_stock_names[i]` sit
    on the shelf and pass that to a new **stock pip badge** on the slot's
    `ShelfItem`. Three tiny filled/hollow dots in the top-right (`●●●`,
    `●●○`, `●○○`), driven by `remaining_of(name)`:
    `stock_count(name) − shop_sold.count(name) − Cart.units_of(name)`.
  - Recompute on every `cart_changed` / `money_changed` and on `_on_cart_changed`.
- `Scripts/Koperasi/ShelfItem.gd`
  - New method `set_stock_pips(remaining: int, total: int)`.
  - New child `PipRow` (HBoxContainer of 3 small `TextureRect`s, filled/hollow
    swap by `visible` on a duplicate node — no runtime `TextureRect` creation;
    respect the "no visual is built at runtime" rule).
- `Scenes/Koperasi/koprasi.tscn` — under each shelf button, add the `PipRow`
  as a static child once. `ThemeFactory` variation `MicroLabel` for count text
  fallback if we later swap dots for `×N` text.

**Test additions** (`tests/test_koperasi_stock_pips.gd`)

- `SHOP_MAX_COPIES == 3`.
- After rolling stock with fixed seed, at least one week produces a name with
  count ≥ 2 within 20 rolls.
- Pip count decreases when a duplicate is added to Cart; goes back up on
  hold-to-return.

---

## 2. Contextual dialogue bubble

**Current:** a static Panel with a fixed line. **Target:** a state machine
that speaks on events and idles silent between them.

**New script** `Scripts/Koperasi/ChatBubble.gd` (attached to the existing
bubble node, renamed `ChatBubble`).

```
enum State { IDLE, SHOWING, LINGERING, HIDING }

const LINGER_S := 2.2
const FADE_IN_S := 0.18
const FADE_OUT_S := 0.28

signal line_finished

func say(event: StringName) -> void  # queues; interrupts LINGERING
func say_sticky(text: String) -> void # stays until cleared (sold-out)
func clear_sticky() -> void
```

**Catalogue** `Scripts/Koperasi/DialogueCatalog.gd` — a plain static-function
script (mirrors `AnimUtils.gd`'s pattern). Voice: Pak Herman, the koperasi
vendor, talking to the **teacher** (the player). Peer-to-peer — warung
banter between two adults on school grounds — dry, a little sarcastic, mildly
teasing about teacher life (tunjangan, dinas, gaji telat, murid nakal),
never disrespectful. Addresses the player as **Pak Guru** or **Pak**.
Lines are short (≤ 10 words) so the bubble does not eat the shelf.
Use `%s` for the item name where an item line is picked.

> **Teacher is canonically male** — every honorific is `Pak` / `Pak Guru`.

```gdscript
const LINES := {
  # Scene entry
  &"WELCOME": [
    "Selamat datang, Pak Guru~ mau beli apa?",
    "Eh, Pak Guru! mari-mari, dipilih dulu",
    "Wih kebetulan lagi sepi, liat-liat dulu aja",
    "Mari Pak, Bapak baru buka nih~",
    "Wih, langganan Bapak! masuk masuk~",
    "Nyari apa hari ini? bilang aja santai",
    "Habis ngajar ya Pak? capek pasti…",
    "Silakan Pak Guru, Bapak siap layani~",
    "Bapak lagi baik hati loh, mumpung~",
  ],

  # Item added to cart (generic)
  &"ADD": [
    "Pilihan bagus, Pak~",
    "Mantaap! Bapak bungkus ya",
    "Ada lagi yang mau~?",
    "Wih selera guru emang beda…",
    "Sip, satu masuk keranjang!",
    "Oke oke, dicatet ya~",
    "Nah gitu dong, jangan cuma nengok",
    "Bapak setuju sama pilihannya!",
    "Tuh kan, akhirnya milih juga~",
    "Bagus~ yang lain nyusul kan?",
    "Wih, mata Pak jeli ya!",
  ],

  # Item removed from cart (hold-to-return)
  &"REMOVE": [
    "Loh… yakin dikembalikan?",
    "Yah dibalikin, padahal bagus loh~",
    "Oke oke, taruh lagi… Bapak nggak marah kok",
    "Nggak jadi ya? ya udaah~",
    "Ganti pikiran? wajar wajar…",
    "Loh kok balik? baru juga masuk!",
    "Hemat ya Pak? boleh boleh~",
    "Sabar… Bapak sabar aja",
    "Ya udah, taruh baik-baik ya",
    "Nunggu gajian dulu? Bapak paham kok…",
  ],

  # Tapped an item that is now sold out this week
  &"OUT_OF_STOCK": [
    "Yah itu habis, minggu depan ya…",
    "Telat Pak! udah diambil orang tuh",
    "Kosong yang itu~ coba yang sebelah",
    "Ludes dari tadi pagi loh…",
    "Rezekinya orang lain, Pak~",
    "Habis! Bapak juga heran, laku banget",
  ],

  # Purchase succeeded
  &"THANKS": [
    "Terima kasih Pak Guru~!",
    "Semoga bermanfaat buat kelasnya ya!",
    "Mengajar yang semangat yaa~",
    "Nanti balik lagi ya, Bapak tunggu…",
    "Alhamdulillah, laris~",
    "Duitnya Bapak simpen dulu ya!",
    "Hati-hati ke kelas Pak~",
    "Nah gini dong, langganan sejati!",
    "Rejeki nggak ke mana~ makasih ya",
  ],

  # Beli pressed with empty cart
  &"EMPTY": [
    "Loh keranjangnya masih kosong, Pak…",
    "Belum ada yang dipilih, Bapak jual apa?",
    "Mau bayar apa? angin??",
    "Kosong melompong~ milih dulu dong",
    "Loh beli apa? Bapak bingung nih…",
    "Nol koma nol! ayo pilih dulu",
  ],

  # Beli pressed but not enough coins
  &"POOR": [
    "Waduh koinnya kurang… nunggu tunjangan dulu?",
    "Belum cukup nih~ kurangi satu?",
    "Duitnya belum sampai, Bapak nggak kasih utang!",
    "Tunjangan belum cair ya Pak?",
    "Bapak bukan bank sekolah loh~",
    "Kurang dikit… tapi tetep kurang",
    "Balik lagi kalo dompet udah gemuk yaa~",
    "Sabar~ gaji guru bulan depan lagi kan",
  ],

  # Sticky, whole week
  &"SOLD_OUT": [
    "Stok habis~ datang lagi minggu depan ya",
    "Ludes semua Pak… minggu depan ya",
    "Toko kosong~ Bapak juga mau pulang nih",
  ],

  # Idle chatter — see IDLE_CHATTER below
  &"IDLE": [
    "Kok diem aja? Bapak tungguin loh…",
    "Milih yang mana~? Bapak bantu?",
    "Beli sini lebih murah daripada Indomaret depan~",
    "Kelasnya rame ya hari ini?",
    "Yang mahal belum tentu enak~ yang murah juga",
    "Bapak dulu hampir jadi guru loh!",
    "Dagangan Bapak nggak gigit kok~",
    "Woi, bangun woi!!",
    "Haloo? bumi memanggil Pak~",
    "Bapak udah keriput nungguin nih…",
    "Ini toko, bukan ruang guru ya~",
    "Murid Pak nakal ya? sabar sabar…",
    "Ngelamun mulu, nanti kesambet loh~",
    "Bapak juga mau pulang nih…",
    "Kalo bingung, tutup mata aja terus tunjuk~",
    "Jam segini belum balik? rajin banget!",
    "Rapotnya udah kelar belum sih~?",
    "Bapak nggak bayar listrik buat Pak diem loh",
    "Anginnya masuk gratis, barangnya nggak~",
    "Guru lain udah pada bayar loh~",
    "Kopi dulu Pak? eh… nggak jual",
    "Sekolah lagi ngirit ya? Bapak juga…",
  ],
}

# Item-specific quips, keyed by ItemData.item_name. Fallback to ADD lines
# when an item has no entry. Add sparingly — one or two per item is enough
# to feel authored.
const ITEM_LINES := {
  "Bank Soal": [
    "Wih Pak, ngasih tes dadakan ya?",
    "Murid pasti panik liat ini~",
    "Bocoran? bukan bukan, latihan doang…",
    "Isinya soal tahun lalu, aman kok!",
  ],
  "Komik": [
    "Loh, Pak Guru baca komik juga?",
    "Buat hadiah murid rajin ya~",
    "Jangan dibaca pas ngajar Pak…",
    "Bapak juga koleksi loh, diem-diem~",
  ],
  "LKS": [
    "PR wajib nih, murid ngeluh pasti…",
    "Klasik~ LKS emang nggak pernah mati",
    "Bapak dulu benci ini, sekarang jualin",
    "Isinya banyak, murid pusing, Pak senang~",
  ],
  "Lompat Tali": [
    "Buat olahraga pagi ya Pak?",
    "Awas keseleo~ Bapak nggak nanggung",
    "Anak sekarang mah males gerak, cocok ini!",
    "Warna-warni, biar semangat lompatnya~",
  ],
  "Raket": [
    "Wih, mau tanding sama guru lain?",
    "Pinjeman kakak kelas nih, masih enak kok",
    "Awas senarnya putus, Pak…",
    "Buat pelajaran olahraga? sip banget~",
  ],
  "Cilok": [
    "Jajan wajib jam istirahat nih~",
    "Bumbunya nendang! Bapak jamin",
    "Kenyel kenyel~ ati-ati keselek ya",
    "Murid Pak juga suka nih, sogokan halus?",
  ],
  "Mie Instan": [
    "Sarapan guru, klasik~",
    "Ngoreksi tugas sambil ngemil ini enak Pak",
    "3 menit doang, cocok buat jam kosong",
    "Awas darah tinggi Pak, jangan tiap hari…",
  ],
  "Pop Ice": [
    "Panas-panas gini emang paling enak~",
    "Warnanya norak, rasanya lumayan!",
    "Buat nyogok murid biar diem, ampuh nih",
    "Manisnya nendang, awas gula darah Pak…",
  ],
  "Susu Kotak": [
    "Biar fokus pas jam pelajaran pagi~",
    "Tinggi, pinter, kata iklan sih…",
    "Dingin, seger, pas buat siang bolong!",
    "Bapak juga minum ini, biar awet muda~",
  ],
  # Missing entries fall back to generic ADD lines.
}

static func pick(event: StringName) -> String:
    var pool: Array = LINES.get(event, [])
    if pool.is_empty(): return ""
    return pool[randi() % pool.size()]

static func pick_for_item(event: StringName, item_name: String) -> String:
    # ADD/REMOVE with per-item flavour when we have one.
    if event == &"ADD" and ITEM_LINES.has(item_name):
        var pool: Array = ITEM_LINES[item_name]
        return pool[randi() % pool.size()]
    return pick(event)
```

**Wiring** in `koprasi.gd._ready` after existing setup:

- `Cart.item_added.connect(_on_item_added)` →
  `bubble.say_for_item(&"ADD", item_name)`
- `Cart.item_removed.connect(_on_item_removed)` →
  `bubble.say_for_item(&"REMOVE", item_name)`
- Shelf tap on a sold-out slot (new signal from `rakbarang_1.gd`:
  `shelf_dead_tap(item_name)`) → `bubble.say(&"OUT_OF_STOCK")`.
- `_on_beli_pressed` failure paths call `bubble.say(&"POOR")` /
  `bubble.say(&"EMPTY")` instead of writing to `message_label`
  (MessageLabel still shown for the success flash).
- `_on_beli_pressed` success → `bubble.say(&"THANKS")`.
- Scene ready: if `GameState.is_shop_sold_out()` →
  `bubble.say_sticky(catalog SOLD_OUT)`; else `bubble.say(&"WELCOME")`.

**Idle chatter** — the bubble tracks a `Timer` (`IDLE_MIN_S = 8.0`,
`IDLE_MAX_S = 14.0`, randomised each cycle). Whenever the bubble reaches
`IDLE` state, the timer starts; whenever *any* event fires or Cart /
shelf sees interaction, the timer resets. On timeout: `say(&"IDLE")`.
The timer is paused while `SOLD_OUT` sticky is up, and while the tray is
COLLAPSED (Pak Herman doesn't heckle an empty room). No sound effect on
idle lines — they should feel ambient, not demanding.

**Anti-repetition** — `DialogueCatalog.pick()` keeps a per-event
`_last_index` in a static dict; if the pool has ≥ 2 lines, it rerolls
once to avoid the exact same line twice in a row.

**Tap-spam safeguard**

A player mashing the shelf can fire `Cart.item_added` many times per
second — without a guard, `ChatBubble.say()` would re-tween every frame,
`AnimUtils` on the tray would stack, and (worst) the shelf-flight
animation queue backs up. Three layers, cheapest first:

1. **Bubble cooldown.** `ChatBubble.say(event)` drops any event that fires
   within `SAY_COOLDOWN = 0.12s` of the previous accepted `say()` of the
   *same* event. Different events (`ADD` then `REMOVE`) still interrupt
   normally — the cooldown is per-event, not global. Sticky (`SOLD_OUT`)
   ignores the cooldown but is idempotent (same text, no re-tween).
2. **Shelf debounce.** Each `ShelfItem` sets an internal `_locked = true`
   in `_on_pressed()` and clears it on the flight's `finished` signal (or
   after a `FLIGHT_TIMEOUT = 0.6s` failsafe). While locked, subsequent
   taps are ignored — visible as the slot ghosting to 60% alpha for the
   lock's duration so the player sees the tap registered.
3. **Cart per-frame cap.** `Cart.add_item()` tracks `_adds_this_frame`
   (reset in `_process`); more than `MAX_ADDS_PER_FRAME = 3` are dropped
   and logged. This is a belt-and-braces guard for scripted / bot input
   where the shelf debounce is bypassed; a normal player never hits it.

**Tests** (`tests/test_koperasi_tap_spam.gd`)

- Fire `ChatBubble.say(&"ADD")` 10 times in one frame → exactly one
  `say` accepted (state becomes `SHOWING` once).
- Fire `ShelfItem._on_pressed()` 5 times before the flight completes →
  Cart has one added unit.
- Fire `Cart.add_item()` 10 times in one frame → Cart size increases by
  at most `MAX_ADDS_PER_FRAME`.
- After `SAY_COOLDOWN` elapses, a new same-event `say` is accepted.

**Signals to add** (Cart already has `cart_changed`; add granular ones):

- `Scripts/Inventory/Cart.gd`
  - `signal item_added(item_name: String)`
  - `signal item_removed(item_name: String)`
  - emit inside `add_item` / `remove_item` before `cart_changed`.

**Scene** — the current static `Panel` + `Label` becomes `ChatBubble` (Panel
with `Card` variation). No `theme_override_*` — variations only.

**Animation — Pak Herman talks while the bubble is up**

Herman is a single `TextureRect` (`$Stage/PakHerman`) with pivot at his
feet-centre. While `ChatBubble.state ∈ {SHOWING, LINGERING}`, he plays a
tiny looping talk animation via a new `AnimationPlayer` (`herman_ap`) with
one `talk` track and one `idle` track:

| Track | What moves | Cycle |
|---|---|---|
| `idle` | very slow scale breathing (1.0 → 1.01 → 1.0) | 3.4s, loop |
| `talk` | head-bob (position.y ±3px), tiny lean (rotation ±1.2°), mouth-swap between two frames if art has one | 0.42s, loop |

State wiring on `ChatBubble.gd`:

- `state_changed(SHOWING)` → play `talk`
- `state_changed(IDLE)` → play `idle`
- On sticky lines (SOLD_OUT), keep `talk` looping until `clear_sticky()`.

If the art has only one Herman frame at ship time, the mouth-swap track is
omitted — the bob + lean alone read as "he's saying something." Do not
build the AnimationPlayer at runtime; author the tracks in the scene.

**Animation — bubble emerges from Pak Herman**

The bubble's `pivot_offset` is set to its **bottom-right corner** (the tip of
the bubble's tail, which points down at Herman's head). On show, tween from
`scale = Vector2(0.2, 0.2)` and a small offset toward Herman
(`position + Vector2(60, 40)`) to `scale = Vector2.ONE` and its authored
position, `TRANS_BACK`/`EASE_OUT`, `0.32s`. On hide, reverse the tween into
the same shrunk pose so the bubble visually retracts *into* Herman rather
than fading in place. Do not use `Juice.pop_in` here — it pops from centre.

Constants on `ChatBubble.gd`:

```
const HERMAN_ANCHOR_OFFSET := Vector2(60, 40)   # bubble → Herman, in px
const SHRUNK_SCALE := Vector2(0.2, 0.2)
```

**Tests** (`tests/test_koperasi_chat_bubble.gd`)

- Fresh scene → bubble text is one of the `WELCOME` lines.
- After `Cart.add_item(...)` → bubble state becomes `SHOWING` and text ∈
  catalog `ADD` **or** `ITEM_LINES[item_name]` when present.
- After `LINGER_S + FADE_OUT_S + 0.05` seconds (use `await` in an integration
  test, or `process` ticks in a scanned test) the bubble is invisible / IDLE.
- Sold-out sticky is not cleared by a queued event.
- `DialogueCatalog.pick(&"IDLE")` twice never returns the exact same line
  (anti-repetition holds when pool ≥ 2).
- Every catalog pool is non-empty (guards typos on future edits) and every
  line is ≤ 60 characters (fits the bubble at 12 px on two lines).
- `ITEM_LINES` keys all exist in `ItemDatabase.get_all_items()` (dead-name
  guard: renaming an item deletes its quips loudly instead of silently).

---

## 3. Retractable basket tray

**States** on `BasketTray`:

```
enum ViewState { EXPANDED, COLLAPSED }
@export var tray_offset_collapsed: float = 190.0  # px slid down
```

**API** on `BasketTray.gd`

```
signal state_changed(state: ViewState)

func toggle() -> void
func set_state(state: ViewState, animate := true) -> void
func is_expanded() -> bool
```

**Anim** — one `Tween`, `TRANS_CUBIC`/`EASE_OUT`, `0.28s`:

- `EXPANDED → COLLAPSED`: `position.y += tray_offset_collapsed`; small emblem
  fades to 0.
- Simultaneously animate the **big crate icon** (a new node
  `$Stage/CrateHandle`) from its expanded pose (small, sitting at the tray
  header emblem's spot) to its collapsed pose (large, bottom-right of the
  screen). Use a single tween grouping both properties (`parallel()`).
- Reverse on `COLLAPSED → EXPANDED`.

**Handle interactions**

- `BasketTray` header (existing emblem area) becomes a `TextureButton`
  → `toggle()`.
- New `$Stage/CrateHandle` (TextureButton with basket-crate icon) → `toggle()`.
- Both share the same visual asset; only their transform differs.

**CrateHandle idle bounce**

The collapsed crate advertises tappability with a gentle, looping squash-hop.
Attach a new `AnimationPlayer` to `CrateHandle` with an `idle_bounce`
animation, autoplay + looping, ~1.8 s cycle:

| t (s) | scale         | position offset y |
|------:|---------------|-------------------|
| 0.00  | (1.00, 1.00)  | 0                 |
| 0.80  | (0.96, 1.05)  | -6                |
| 1.10  | (1.06, 0.94)  | 0                 |
| 1.35  | (0.99, 1.02)  | -2                |
| 1.80  | (1.00, 1.00)  | 0                 |

Pivot at `Vector2(size.x * 0.5, size.y)` (foot centre) so the squash reads as
a hop. On press, stop `idle_bounce` and play a short `Juice.press` /
`Juice.release`; resume `idle_bounce` after `state_changed`. The bounce only
plays while COLLAPSED — when EXPANDED the crate is the tiny header emblem
and stays still. Gate with `set_process(state == COLLAPSED)` on the
AnimationPlayer.

**Emblem count badge stays on both** (`_emblem_badge` on the tray header when
expanded; a mirrored `CountBadge` on `CrateHandle` when collapsed). Update
both in `refresh()`.

**Ticks driven by state**

- `Cart.item_added` while COLLAPSED → auto-expand for 1.4s then re-collapse
  if untouched? **No** — keep simple: collapsing is a manual gesture, adding
  an item does not force expand. Tapping the crate is the only expand path
  beyond the header emblem tap.
- BeliButton is only reachable when EXPANDED; that's fine — encourages
  reviewing before purchase.

**Scene**

- `koprasi.tscn` adds `$Stage/CrateHandle` (TextureButton, anchored
  bottom-right, initial scale 0.35 for expanded pose). Do not build at runtime.
- `BasketTray.tscn` adds a `HeaderButton` (TextureButton over the existing
  `Body/Emblem`) that emits `pressed` → `toggle()`.

**Tests** (`tests/test_koperasi_tray_retract.gd`)

- `tray.is_expanded()` after `_ready()` is true.
- `tray.set_state(COLLAPSED, false)` moves `position.y` by
  `tray_offset_collapsed` and shows `CrateHandle` at large scale.
- `tray.toggle()` twice returns to original transform (within 0.5 px).
- `state_changed` signal fires with correct arg.
- After collapse, `_emblem_badge.visible == false` and mirrored badge on the
  crate handle shows the same count.

---

## 4. Back button follows the tray

**Behaviour** — the back button's Y anchors to the top edge of whichever
element is on-screen: tray header when EXPANDED, crate handle top edge when
COLLAPSED.

**Implementation**

- `koprasi.gd` listens to `tray.state_changed` and drives one shared tween on
  `back_button` alongside the tray tween (same `duration`, same `trans/ease`,
  same `parallel()` group so they visually move as one piece).
- Two `@export` positions on `koprasi.gd`:

```
@export var back_pos_expanded: Vector2   # near top of tray header
@export var back_pos_collapsed: Vector2  # just above crate handle
```

- On `_ready()` set to `back_pos_expanded`.
- On `state_changed(COLLAPSED)` tween to `back_pos_collapsed`; on
  `state_changed(EXPANDED)` tween back.

**Positioning** — both anchor Ys sit **flush against the top edge of the
element beneath them** (tray header when EXPANDED, crate handle when
COLLAPSED), not floating in negative space above:

- `back_pos_expanded.y` ≈ `tray.position.y - back_button.size.y - 12` (12 px
  breathing gap, not more).
- `back_pos_collapsed.y` ≈ `crate_handle.position.y - back_button.size.y - 12`.

Pin the exact values in `koprasi.tscn`; the tests read them back rather than
recomputing so a tuning change is one file.

**Tests** (`tests/test_koperasi_back_follows_tray.gd`)

- Back button starts at `back_pos_expanded`.
- After `tray.set_state(COLLAPSED, false)` and one frame,
  `back_button.position ≈ back_pos_collapsed`.
- Toggle back → returns to `back_pos_expanded`.

---

## Cross-cutting

**No runtime visuals.** Every new node (pip row, chat bubble, crate handle,
mirrored badge) is placed in the `.tscn`. `ThemeFactory` variations only —
no `theme_override_*`.

**One tween per user gesture.** The retract gesture animates tray, emblems,
crate handle, and back button in a single `parallel()` group so they cannot
desync.

**Signals to add**

- `Cart.item_added(item_name)`
- `Cart.item_removed(item_name)`
- `BasketTray.state_changed(state)`

**No new persistence.** Tray state resets to EXPANDED every scene entry.

**Files touched**

| File | Change |
|---|---|
| `Scripts/GameState.gd` | `SHOP_MAX_COPIES` 2 → 3 |
| `Scripts/Inventory/Cart.gd` | new `item_added` / `item_removed` signals |
| `Scripts/Koperasi/koprasi.gd` | bubble events, tray state signal, back-button tween |
| `Scripts/Koperasi/rakbarang_1.gd` | pip updates on cart / stock change |
| `Scripts/Koperasi/BasketTray.gd` | retract state machine, mirrored badge, toggle API |
| `Scripts/Koperasi/ShelfItem.gd` | `set_stock_pips()` |
| `Scripts/Koperasi/ChatBubble.gd` | **new** |
| `Scripts/Koperasi/DialogueCatalog.gd` | **new** |
| `Scenes/Koperasi/koprasi.tscn` | ChatBubble, CrateHandle, pip rows, back-button exports, Herman `AnimationPlayer` |
| `Scripts/Koperasi/ShelfItem.gd` | `_locked` flag + ghost feedback |
| `Scripts/Inventory/Cart.gd` | per-frame add cap |
| `Scenes/Koperasi/BasketTray.tscn` | HeaderButton, mirrored CountBadge |
| `tests/test_koperasi_stock_pips.gd` | **new** |
| `tests/test_koperasi_chat_bubble.gd` | **new** |
| `tests/test_koperasi_tray_retract.gd` | **new** |
| `tests/test_koperasi_back_follows_tray.gd` | **new** |

**Order of implementation**

1. `Cart` signals + tests — safest, unlocks everything.
2. `DialogueCatalog` + `ChatBubble` script + scene node + tests.
3. Stock pips (data → `ShelfItem` → shelf refresh) + tests.
4. Tray retract state machine + `CrateHandle` scene node + tests.
5. Back-button follower + tests.
6. Full `test_run` and screenshot at both tray states before opening the PR.

**Out of scope**

- Chat lines for random events during the school day.
- Actual crate art (uses a placeholder `TextureRect` at Assets/Images/UI
  path TBD; asset drop-replaces per the visual-system rules).
- Sound effects beyond the existing `popup_open` / `popup_close` reuse for
  tray toggle.

---

## Acceptance

- `test_run` passes all four new suites and the existing koperasi suites.
- Screenshot at EXPANDED matches the current layout modulo the pip badges and
  the new bubble.
- Screenshot at COLLAPSED shows the shelf fully visible, the large crate
  bottom-right, and the back button hovering above it.
- Bubble greets on entry, thanks on successful buy, scolds on error, and
  reacts within one animation cycle to each cart add/remove.
