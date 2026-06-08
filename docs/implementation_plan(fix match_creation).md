# Match Creation and display enhancements

We need to implement rules that ensure safe, conflict-free matchmaking around the campus facilities.

## Proposed Changes

### 1. Data Layer & Conflict Resolution
To prevent scheduling conflicts for the same field, `MatchRepository` will be updated to query the Firestore database prior to creating a match.
- Query Firestore for any existing match matching the exact `location` and `dateTime` (e.g. `location == "INPT field"` AND `dateTime == 18:30`).
- If an overlap is found, the UI will warn the user and abort creation.

### 2. Match Creation Features (`create_match_screen.dart`)
- **[MODIFY] `lib/presentation/screens/match/create_match_screen.dart`**
  - **Dynamic Locations Options:** Remove the text input for location and replace it with toggleable dropdowns or ChoiceChips mapped to the selected sport:
    - *Football*: INPT field, Terrain l9orb
    - *Basketball*: INPT field 1, INPT field 2
    - *Volleyball*: INPT Volleyball field
    - *Table Tennis*: table1, table2, table3
  - **Constrained Date Picker:** Limit dates to `DateTime.now()` to `DateTime.now() + 7 days`.
  - **Constrained Time Options:** Replace TimePicker with grid of buttons from 17:30 (5:30 PM) to 21:30 (9:30 PM) with 30-min intervals.
  - **Player Number Toggling:** Replace simple counter with grouped sizes, e.g. "5v5", "6v6", etc.

### 3. Match Views & Format updates
- **[MODIFY] `lib/presentation/widgets/match_card.dart`**, **`lib/presentation/screens/match/match_detail_screen.dart`**, **`lib/core/constants/app_constants.dart`**
  - Translate integer sizes (10, 12, 4) into visually friendly versus text (e.g. `5v5`, `6v6`, `2v2`, `1v1`).
- **[MODIFY] `lib/features/matches/match_provider.dart`**
  - Ensure the filtered matches feed prioritizes showing ALL available matches up-front so all users have a fair chance to view and join them natively.

## User Review Required
> [!IMPORTANT]
> The conflict checking mechanism works by matching the string names exactly. If someone manually modifies the database to bypass this, it could overlap, but through the app it will be strictly guarded. Also, restricting date selection to 7 days out is simple using Flutter's `lastDate` attribute. Does viewing the player counts as "5v5" instead of "10 players" look correct for your needs?

## Verification Plan

### Automated Tests
_None requested currently_

### Manual Verification
- Attempt to create 2 football matches on "INPT field" at "5:30 PM". The second attempt should display a clear error.
- Verify creation layout strictly shows ONLY the relevant fields.
