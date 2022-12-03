// The prefix we use for all special NaN values. We use 7FFC because
// JS seems to use 7FF8. This lets us detect our own values.
export const NAN_PREFIX = 0x7FFC_0000;

export const PREDEFINED_ID_MAX = 5;

/**
 * Predefined references.
 * */
export const predefined = {
  "nan": idToRef(0),
  "null": idToRef(1),
  "true": idToRef(2),
  "false": idToRef(3),
  "undefined": idToRef(4),
  "globalThis": idToRef(5),
};

/**
 * Convert an id to a ref. These are only exported so they can be tested.
 * */
export function idToRef(id: number): number {
  let bytes = new Uint32Array(2);
  bytes[0] = id;
  bytes[1] = NAN_PREFIX;
  return new Float64Array(bytes.buffer)[0];
}

/**
 * Convert an ref to an ID. This is only exported so it can be tested.
 * */
export function refToId(ref: number): number {
  // Okay, well, this is weird as hell. For some reason in my tests,
  // refToId would sometimes just see a plain-old nan (prefix 0x7FF8).
  // But if I looked at the value again it'd fix itself. I don't understand
  // the core problem (maybe a transpiler issue? jest issue?) so instead I'm
  // just going to wrap this in a for loop and look for our proper NaN header.
  for (let i = 0; i < 10; i++) {
    let floats = new Float64Array([ref]);
    let bytes = new Uint32Array(floats.buffer);
    if ((bytes[1] & NAN_PREFIX) != NAN_PREFIX) continue;
    return bytes[0];
  }

  return 0;
}
