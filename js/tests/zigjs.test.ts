import { ZigJS } from '../src';
import { predefined } from '../src/ref';

test('predefined values', () => {
  const st = new ZigJS();
  expect(st.loadValue(0)).toBeNaN();
  expect(st.loadValue(1)).toEqual(null);
  expect(st.loadValue(2)).toEqual(true);
  expect(st.loadValue(3)).toEqual(false);
  expect(st.loadValue(4)).toEqual(undefined);
  expect(st.loadValue(5)).toEqual(globalThis);
});

test('valueGet', () => {
  const st = new ZigJS();
  const obj = st.importObject();
  const f = obj["zig-js"].valueGet;

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Write our string
  const key = "__zigjs_number";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our key into the global value
  globalThis[key] = 1234;

  // Read it
  f(64, predefined.globalThis, 0, write.written ?? 0);
  expect(view.getFloat64(64, true)).toEqual(1234);
});

test('valueGet: string', () => {
  const st = new ZigJS();
  const obj = st.importObject();

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Write our string
  const key = "__zigjs_string";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our key into the global value
  globalThis[key] = "橋本";

  // Read it
  const refAddr = 64;
  const f = obj["zig-js"].valueGet;
  f(refAddr, predefined.globalThis, 0, write.written ?? 0);
  expect(st.loadRef(refAddr)).toEqual("橋本");

  // Read the string length
  {
    const stringLen = obj["zig-js"].valueStringLen;
    const len = stringLen(st.loadRefId(refAddr));
    expect(len).not.toBeNaN();
    expect(len).toEqual(6);
  }

  // Copy the string into memory
  const offset = 12;
  {
    const stringCopy = obj["zig-js"].valueStringCopy;
    stringCopy(st.loadRefId(refAddr), offset, 64);
  }

  // Read it
  const str = new TextDecoder('utf-8').decode(new DataView(memory, 12, 6));
  expect(str).toEqual("橋本");
});

test('valueSet: number', () => {
  const st = new ZigJS();
  const obj = st.importObject();
  const f = obj["zig-js"].valueSet;

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Write our string
  const key = "__zigjs_number";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our argument
  const refAddr = 64;
  view.setFloat64(refAddr, 42, true);

  // Write our key into the global value
  globalThis[key] = 12;

  // Set it
  f(predefined.globalThis, 0, write.written ?? 0, refAddr);
  expect(globalThis[key]).toEqual(42);
});

test('valueSet: ref', () => {
  const st = new ZigJS();
  const obj = st.importObject();
  const f = obj["zig-js"].valueSet;

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Write our string
  const key = "__zigjs_boolean";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(key, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Write our argument
  const refAddr = 64;
  st.storeValue(refAddr, true);

  // Write our key into the global value
  globalThis[key] = false;

  // Set it
  f(predefined.globalThis, 0, write.written ?? 0, refAddr);
  expect(globalThis[key]).toEqual(true);
});

test('valueStringCreate', () => {
  const st = new ZigJS();
  const obj = st.importObject();

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Write our string into memory
  const value = "hello, world!";
  const encoder = new TextEncoder();
  const write = encoder.encodeInto(value, new Uint8Array(memory));
  expect(write.written).toBeGreaterThan(0);

  // Read it
  let f = obj["zig-js"].valueStringCreate;
  const refAddr = 64;
  f(refAddr, 0, write.written ?? 0);
  expect(st.loadValue(st.loadRefId(refAddr))).toEqual(value);
});

test('valueObjectCreate', () => {
  const st = new ZigJS();
  const obj = st.importObject();

  // Set our memory
  const memory = new ArrayBuffer(128);
  const view = new DataView(memory);
  st.memory = view;

  // Read it
  let f = obj["zig-js"].valueObjectCreate;
  const refAddr = 64;
  f(refAddr);
  expect(st.loadValue(st.loadRefId(refAddr))).toEqual({});
});

// We need to extend our global value for test keys
declare global {
  var __zigjs_boolean: boolean;
  var __zigjs_number: number;
  var __zigjs_string: string;
}
