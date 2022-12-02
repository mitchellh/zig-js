import { ZigJS } from '../src';
import { idToRef, refToId, predefined } from '../src/ref';

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

test('valueGet: string', () => {
  const st = new ZigJS();
  const obj = st.importObject();

  // Set our memory
  const memory = new ArrayBuffer(128);
  st.memory = new DataView(memory);

  // Write our string
  const key = "__zigjs_string";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our key into the global value
  globalThis[key] = "hello";

  // Read it
    const f = obj["zig-js"].valueGet;
    const result = f(refToId(predefined.globalThis), 0, write.written ?? 0);
    expect(result).toBeNaN();
    expect(st.loadValue(refToId(result))).toEqual("hello");

  // Read the string length
  {
    const stringLen = obj["zig-js"].valueStringLen;
    const ref = stringLen(refToId(result));
    expect(ref).not.toBeNaN();
    expect(ref).toEqual(5);
  }
});

test('valueStringCreate', () => {
  const st = new ZigJS();
  const obj = st.importObject();

  // Set our memory
  const memory = new ArrayBuffer(128);
  st.memory = new DataView(memory);

  // Write our string into memory
  const value = "hello, world!";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(value, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Read it
  let f = obj["zig-js"].valueStringCreate;
  const ref = f(0, write.written ?? 0);
  expect(ref).toBeNaN();
  expect(st.loadValue(refToId(ref))).toEqual(value);
});

// We need to extend our global value for test keys
declare global {
  var __zigjs_number: number;
  var __zigjs_string: string;
}
