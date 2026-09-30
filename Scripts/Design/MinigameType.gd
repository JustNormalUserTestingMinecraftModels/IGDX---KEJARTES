class_name MinigameType
extends RefCounted

## The minigames' type ladder (spec 2026-09-30 minigame hierarchy, 3): four
## rungs, each x1.618 (the golden ratio) of the one below, rounded, starting
## at the house body floor (DesignTokens.font_body_size, 28). Minigames only;
## every other screen keeps the house tokens. ThemeFactory's minigame
## variations and the games' fit exports read these, so each number is
## written once. Constants only; never instanced.

## Hint, captions, planks, badges: the quietest rung.
const T1 := 28
## Answers, buttons, tool names, timer seconds.
const T2 := 45
## Questions, the plaque's score, calculator keys.
const T3 := 73
## Sums and the calculator display.
const T4 := 118
## The four rungs, smallest first.
const LADDER: Array[int] = [T1, T2, T3, T4]
