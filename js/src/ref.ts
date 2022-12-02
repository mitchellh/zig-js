export const NAN_PREFIX = 0x7FF8_0000;
export const PREDEFINED_ID_MAX = 4;

/**
 * Predefined references.
 * */
export const predefined = {
  "nan": idToRef(0),
  "null": idToRef(1),
  "true": idToRef(2),
  "false": idToRef(3),
  "globalThis": idToRef(4),
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
  let floats = new Float64Array([ref]);
  let bytes = new Uint32Array(floats.buffer);
  return bytes[0];
}
