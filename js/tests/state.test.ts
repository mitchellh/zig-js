import { ZigJS, idToRef, refToId, predefined } from '../src';

test('ref conversion', () => {
  const st = new ZigJS();
  expect(idToRef(0)).toBeNaN();
  expect(refToId(idToRef(0))).toEqual(0);
  expect(refToId(idToRef(2))).toEqual(2);
});

test('predefined values', () => {
  const st = new ZigJS();
  expect(st.loadValue(0)).toBeNaN();
  expect(st.loadValue(1)).toEqual(null);
  expect(st.loadValue(2)).toEqual(true);
  expect(st.loadValue(3)).toEqual(false);
  expect(st.loadValue(4)).toEqual(globalThis);
});

test('valueGet', () => {
  const st = new ZigJS();
  const obj = st.importObject();
  const f = obj["zig-js"].valueGet;

  // Set our memory
  const memory = new ArrayBuffer(128);
  st.memory = new DataView(memory);

  // Write our string
  const key = "__zigjs_number";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our key into the global value
  globalThis[key] = 1234;

  // Read it
  const result = f(refToId(predefined.globalThis), 0, write.written ?? 0);
  expect(result).toEqual(1234);
});

// We need to extend our global value for test keys
declare global {
  var __zigjs_number: number;
}
