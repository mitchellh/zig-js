// The prefix we use for all special NaN values. We use 7FFC because
// JS seems to use 7FF8. This lets us detect our own values.
export const NAN_PREFIX = 0x7FFC_0000;

export const PREDEFINED_ID_MAX = 5;

/**
 * Predefined references.
 * */
export const predefined = {
  "nan": 0,
  "null": 1,
  "true": 2,
  "false": 3,
  "undefined": 4,
  "globalThis": 5,
};
