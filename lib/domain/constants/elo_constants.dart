/// Elo rating constants.
///
/// Single source for valid range and defaults independent of UI/Hive.
const int kEloMinRating = 100;
const int kEloMaxRating = 500;
const int kEloDefaultInitialRating = 400;
const int kEloLegacyInitialRating = 500;
const int kEloDefaultKFactor = 20;

@Deprecated('Use kEloMinRating')
const int kFargoMinRating = kEloMinRating;

@Deprecated('Use kEloMaxRating')
const int kFargoMaxRating = kEloMaxRating;

@Deprecated('Use kEloDefaultInitialRating')
const int kFargoDefaultInitialRating = kEloDefaultInitialRating;

@Deprecated('Use kEloLegacyInitialRating')
const int kFargoLegacyInitialRating = kEloLegacyInitialRating;

@Deprecated('Use kEloDefaultKFactor')
const int kFargoDefaultKFactor = kEloDefaultKFactor;
